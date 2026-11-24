import 'dart:async';

import 'package:flutter/material.dart';

import '../config/colores_app.dart';

import '../models/venta_app.dart';
import '../services/api_errors.dart';
import '../services/caja_service.dart';
import '../services/ventas_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dialogo_monto.dart';
import '../widgets/selector_cliente.dart';
import 'barcode_scanner_screen.dart';
import 'caja_screen.dart';

/// Nueva venta estilo tienda: buscas productos en una cuadrícula, armas el carrito
/// y confirmas el cobro. Cliente por defecto: CLIENTE GENERAL. Requiere caja abierta.
/// El cobro puede dividirse en efectivo y transferencia/QR, igual que la web.
/// Fuera de esta versión: combos, fraccionados, adiciones, crédito, entregas,
/// preventistas y envíos.
class VentaNuevaScreen extends StatefulWidget {
  const VentaNuevaScreen({super.key});

  @override
  State<VentaNuevaScreen> createState() => _VentaNuevaScreenState();
}

class _VentaNuevaScreenState extends State<VentaNuevaScreen> {
  final _buscarCtrl = TextEditingController();
  final _efectivoCtrl = TextEditingController();
  final _transferenciaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  // Transferencia de caja que acompaña al servicio (no suma al total)
  final _transfMontoCtrl = TextEditingController();
  String? _transfTipo; // ENTRADA | SALIDA

  Timer? _debounce;
  int _reqProductos = 0;

  CatalogosVenta? _catalogos;
  List<TipoPagoVenta> _tiposPago = [];

  bool _cajaAbierta = false;

  // Venta a crédito (solo si el cliente tiene crédito habilitado)
  bool _ventaCredito = false;
  ({double limite, double disponible})? _credito;

  ClienteVenta? _cliente;
  final List<ItemVenta> _items = [];
  List<ProductoVenta> _resultados = [];
  String _consulta = '';

  // Listado paginado de productos (cuando no hay texto de búsqueda)
  final _scroll = ScrollController();
  List<ProductoVenta> _productos = [];
  int _paginaActual = 0;
  bool _hayMas = true;
  bool _cargandoPagina = false;
  int _reqListado = 0;

  // Cambia en cada modificación para que la hoja del carrito se redibuje
  final _carritoRev = ValueNotifier<int>(0);

  bool _cargandoInicial = true;
  bool _buscando = false;
  bool _guardando = false;
  String? _errorInicial;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _cargarInicial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _carritoRev.dispose();
    _buscarCtrl.dispose();
    _efectivoCtrl.dispose();
    _transferenciaCtrl.dispose();
    _obsCtrl.dispose();
    _transfMontoCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── Carga ─────────────────────────

  Future<void> _cargarInicial() async {
    setState(() {
      _cargandoInicial = true;
      _errorInicial = null;
    });
    try {
      final catalogos = await ventasService.getCatalogos();
      final tipos = await ventasService.getTiposPago();
      await _cargarCaja(silencioso: true);
      if (!mounted) return;

      setState(() {
        _catalogos = catalogos;
        _tiposPago = tipos;
        // Cliente por defecto: CLIENTE GENERAL (solo si no hay uno elegido)
        _cliente ??= catalogos.clienteGeneral;
        _cargandoInicial = false;
      });
      _cargarPrimeraPagina();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorInicial = _texto(e);
        _cargandoInicial = false;
      });
    }
  }

  Future<void> _cargarCaja({bool silencioso = false}) async {
    try {
      final estado = await cajaService.estado();
      if (!mounted) return;
      setState(() => _cajaAbierta = estado.abierta);
    } catch (e) {
      if (!silencioso) _mensaje(_texto(e), error: true);
      if (mounted) setState(() => _cajaAbierta = false);
    }
  }

  Future<void> _abrirPantallaCaja() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CajaScreen()),
    );
    await _cargarCaja();
  }

  // ───────────────────────── Productos ─────────────────────────

  void _onBuscarChanged(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _buscar(valor));
  }

  Future<void> _buscar(String q) async {
    final req = ++_reqProductos;
    final texto = q.trim();
    if (texto.length < 2) {
      final veniaDeBusqueda = _consulta.length >= 2;
      setState(() {
        _consulta = texto;
        _resultados = [];
        _buscando = false;
      });
      if (veniaDeBusqueda || (_productos.isEmpty && !_cargandoPagina)) {
        _cargarPrimeraPagina();
      }
      return;
    }
    setState(() {
      _consulta = texto;
      _buscando = true;
    });
    try {
      final resultados = await ventasService.buscarProductos(texto);
      if (!mounted || req != _reqProductos) return;
      setState(() => _resultados = resultados);
    } catch (e) {
      _mensaje(_texto(e), error: true);
    } finally {
      if (mounted && req == _reqProductos) setState(() => _buscando = false);
    }
  }

  /// Abre el escáner y busca el código leído (coincidencia exacta).
  Future<void> _escanear() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || codigo.trim().isEmpty || !mounted) return;
    await _buscarPorCodigo(codigo.trim());
  }

  Future<void> _buscarPorCodigo(String codigo) async {
    final req = ++_reqProductos;
    _debounce?.cancel();
    _buscarCtrl.text = codigo;
    setState(() {
      _consulta = codigo;
      _resultados = [];
      _buscando = true;
    });
    try {
      final encontrados = await ventasService.buscarProductos(
        codigo,
        exacta: true,
      );
      if (!mounted || req != _reqProductos) return;

      if (encontrados.isEmpty) {
        _mensaje('No hay producto con el código $codigo', error: true);
        setState(() => _resultados = []);
      } else if (encontrados.length == 1) {
        // Un solo producto: directo al carrito y de vuelta al listado para seguir escaneando
        await _agregar(encontrados.first);
        _buscarCtrl.clear();
        setState(() {
          _consulta = '';
          _resultados = [];
        });
      } else {
        setState(() => _resultados = encontrados);
      }
    } catch (e) {
      _mensaje(_texto(e), error: true);
    } finally {
      if (mounted && req == _reqProductos) setState(() => _buscando = false);
    }
  }

  /// Reinicia el listado y carga la primera página (también al refrescar o tras vender).
  Future<void> _cargarPrimeraPagina() async {
    final req = ++_reqListado;
    setState(() {
      _productos = [];
      _paginaActual = 0;
      _hayMas = true;
      _cargandoPagina = false;
    });
    await _cargarPagina(req);
  }

  Future<void> _cargarPagina(int req) async {
    if (_cargandoPagina || !_hayMas) return;
    setState(() => _cargandoPagina = true);
    try {
      final siguiente = _paginaActual + 1;
      final r = await ventasService.listarProductos(page: siguiente);
      if (!mounted || req != _reqListado) return;
      setState(() {
        _productos = [..._productos, ...r.items];
        _paginaActual = siguiente;
        _hayMas = r.hasMore;
      });
    } catch (e) {
      if (mounted && req == _reqListado) _mensaje(_texto(e), error: true);
    } finally {
      if (mounted && req == _reqListado)
        setState(() => _cargandoPagina = false);
    }
  }

  /// Carga la siguiente página cuando el usuario se acerca al final del listado.
  void _onScroll() {
    if (!_scroll.hasClients || _consulta.length >= 2) return;
    if (_scroll.position.extentAfter < 400) {
      _cargarPagina(_reqListado);
    }
  }

  Future<void> _agregar(ProductoVenta p) async {
    if (p.esServicio) {
      await _agregarServicio(p);
      return;
    }
    if (p.esCombo) {
      _mensaje('Los combos todavía no se venden desde la app', error: true);
      return;
    }
    if (p.precioVenta <= 0) {
      _mensaje('"${p.nombre}" no tiene precio de venta', error: true);
      return;
    }
    if (!p.permiteVentaSinStock && p.stockDisponible <= 0) {
      _mensaje('"${p.nombre}" está agotado', error: true);
      return;
    }
    _mutar(() {
      final idx = _items.indexWhere((i) => i.producto.id == p.id);
      if (idx >= 0) {
        _items[idx].cantidad += 1;
      } else {
        _items.add(ItemVenta(producto: p, precioUnitario: p.precioVenta));
      }
    });
  }

  /// Servicio (ej. comisión de transferencias): cantidad fija en 1 y precio escrito a mano.
  Future<void> _agregarServicio(ProductoVenta p) async {
    if (_items.any((i) => i.producto.id == p.id)) {
      _mensaje('"${p.nombre}" ya está en el carrito (cantidad fija en 1)');
      return;
    }
    final precio = await DialogoMonto.mostrar(
      context,
      titulo: p.nombre,
      etiqueta: 'Comisión / precio (Bs)',
      valorInicial: p.precioVenta > 0 ? p.precioVenta.toStringAsFixed(2) : '',
      textoConfirmar: 'Agregar',
    );
    if (precio == null) return;
    if (precio <= 0) {
      _mensaje('El precio debe ser mayor a 0', error: true);
      return;
    }
    _mutar(() {
      _items.add(ItemVenta(producto: p, cantidad: 1, precioUnitario: precio));
      // Por defecto: el cliente transfirió y sale efectivo de caja (se puede cambiar)
      _transfTipo ??= 'SALIDA';
    });
  }

  bool get _hayServicio => _items.any((i) => i.producto.esServicio);

  double? get _transfMonto => _numero(_transfMontoCtrl.text);

  /// Transferencia de caja que acompaña al servicio: efectivo que pasa por caja (no suma al total).
  Widget _seccionTransferencia(StateSetter setSheet) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Transferencia (efectivo por caja, no suma al total)',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tipo',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _transfTipo,
                isExpanded: true,
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin transferencia'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'SALIDA',
                    child: Text('Cliente transfirió → sale de caja'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'ENTRADA',
                    child: Text('Cliente pagó efectivo → entra a caja'),
                  ),
                ],
                onChanged: (v) => _mutar(() => _transfTipo = v, setSheet),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _transfMontoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _mutar(() {}, setSheet),
            decoration: const InputDecoration(
              labelText: 'Monto transferencia (Bs)',
            ),
          ),
        ],
      ),
    );
  }

  ItemVenta? _itemDe(int productoId) {
    for (final i in _items) {
      if (i.producto.id == productoId) return i;
    }
    return null;
  }

  void _cambiarCantidad(ItemVenta item, double delta, [StateSetter? setSheet]) {
    final nueva = item.cantidad + delta;
    if (nueva < 1) {
      _quitar(item, setSheet);
      return;
    }
    _mutar(() => item.cantidad = nueva, setSheet);
  }

  void _quitar(ItemVenta item, [StateSetter? setSheet]) {
    _mutar(() => _items.remove(item), setSheet);
  }

  Future<void> _editarPrecio(ItemVenta item, [StateSetter? setSheet]) async {
    final nuevo = await DialogoMonto.mostrar(
      context,
      titulo: item.producto.nombre,
      etiqueta: 'Precio unitario (Bs)',
      valorInicial: item.precioUnitario.toStringAsFixed(2),
    );
    if (nuevo == null) return;
    if (nuevo <= 0) {
      _mensaje('El precio debe ser mayor a 0', error: true);
      return;
    }
    _mutar(() => item.precioUnitario = nuevo, setSheet);
  }

  // ───────────────────────── Cliente ─────────────────────────

  Future<void> _elegirCliente([StateSetter? setSheet]) async {
    final elegido = await showModalBottomSheet<ClienteVenta>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SelectorCliente(),
    );
    if (elegido == null || !mounted) return;
    _mutar(() {
      _cliente = elegido;
      _ventaCredito = false;
      _credito = null;
    }, setSheet);
    _cargarCredito(elegido.id);
  }

  // ───────────────────────── Totales y cobro ─────────────────────────

  /// Límite y disponible de crédito del cliente (si no se puede consultar, queda en null).
  Future<void> _cargarCredito(int clienteId) async {
    try {
      final credito = await ventasService.getCreditoCliente(clienteId);
      if (!mounted || _cliente?.id != clienteId) return;
      _mutar(() => _credito = credito);
    } catch (_) {
      // Sin crédito disponible para mostrar: la venta a crédito sigue permitida
    }
  }

  /// Interruptor de venta a crédito (solo si el cliente tiene crédito habilitado).
  Widget _seccionCredito(StateSetter setSheet) {
    final theme = Theme.of(context);
    final puede = _cliente?.puedeTenerCredito == true;
    final credito = _credito;
    // Límite 0 = sin límite de crédito (no se compara contra el disponible)
    final sinLimite = credito != null && credito.limite <= 0;
    final excede =
        _ventaCredito &&
        credito != null &&
        !sinLimite &&
        _total > credito.disponible;

    String detalle;
    if (!puede) {
      detalle = 'Este cliente no tiene crédito habilitado';
    } else if (credito == null) {
      detalle = 'Crédito del cliente no disponible';
    } else if (sinLimite) {
      detalle = 'Sin límite de crédito';
    } else {
      detalle =
          'Límite Bs ${credito.limite.toStringAsFixed(2)} · '
          'Disponible Bs ${credito.disponible.toStringAsFixed(2)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Venta a crédito'),
          subtitle: Text(detalle),
          value: _ventaCredito,
          onChanged: puede
              ? (v) => _mutar(() => _ventaCredito = v, setSheet)
              : null,
        ),
        if (_ventaCredito)
          Text(
            'Se registra como cuenta por cobrar: no se cobra en caja.',
            style: theme.textTheme.bodySmall,
          ),
        if (excede)
          Text(
            '⚠️ La venta supera el crédito disponible. Puedes registrarla igual.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
      ],
    );
  }

  double get _total => _r2(_items.fold(0.0, (s, i) => s + i.subtotal));

  int get _cantidadTotal => _items.fold(0, (s, i) => s + i.cantidad.round());

  /// Sin montos escritos = todo el total en efectivo (como la venta por defecto).
  bool get _sinDesglose =>
      _efectivoCtrl.text.trim().isEmpty &&
      _transferenciaCtrl.text.trim().isEmpty;

  double get _montoEfectivo =>
      _sinDesglose ? _total : (_numero(_efectivoCtrl.text) ?? 0);

  double get _montoTransferencia =>
      _sinDesglose ? 0 : (_numero(_transferenciaCtrl.text) ?? 0);

  double get _pagado => _r2(_montoEfectivo + _montoTransferencia);

  double get _cambio =>
      _r2((_pagado - _total).clamp(0, double.infinity).toDouble());

  double get _faltante =>
      _r2((_total - _pagado).clamp(0, double.infinity).toDouble());

  /// Tipo de pago derivado del desglose (EFECTIVO, TRANSFERENCIA/QR o MIXTO), igual que la web.
  TipoPagoVenta? _tipoPagoPorCodigo(String codigo) {
    for (final t in _tiposPago) {
      if (t.codigo == codigo) return t;
    }
    return null;
  }

  int _idTipoPago(String codigo, int respaldo) =>
      _tipoPagoPorCodigo(codigo)?.id ?? respaldo;

  String get _codigoTipoPago {
    final efectivo = _montoEfectivo > 0;
    final transferencia = _montoTransferencia > 0;
    if (efectivo && transferencia) return 'MIXTO';
    if (transferencia) return 'TRANSFERENCIA/QR';
    return 'EFECTIVO';
  }

  String get _nombreTipoPago =>
      _tipoPagoPorCodigo(_codigoTipoPago)?.nombre ??
      switch (_codigoTipoPago) {
        'MIXTO' => 'Mixto',
        'TRANSFERENCIA/QR' => 'Transferencia / QR',
        _ => 'Efectivo',
      };

  /// Motivo por el que no se puede confirmar, o null si está listo.
  String? _bloqueoConfirmacion() {
    if (_catalogos == null) return 'No se cargaron los datos de venta';
    if (_catalogos!.usuarioId == null)
      return 'No se pudo identificar el usuario';
    if (_catalogos!.estadoDocumentoId == 0)
      return 'No existe el estado APROBADO en el sistema';
    if (!_cajaAbierta) return 'Abre tu caja para registrar ventas';
    if (_cliente == null) return 'Elige un cliente';
    if (_items.isEmpty) return 'Agrega al menos un producto';
    for (final item in _items) {
      if (item.superaStock) {
        return 'Stock insuficiente de "${item.producto.nombre}" '
            '(disponible: ${item.producto.stockDisponible.toStringAsFixed(0)})';
      }
    }
    if (_ventaCredito) {
      if (_cliente?.puedeTenerCredito != true) {
        return 'Este cliente no tiene crédito habilitado';
      }
      return null; // A crédito: no hay cobro en caja
    }
    if (_montoEfectivo < 0 || _montoTransferencia < 0)
      return 'Los montos no pueden ser negativos';
    if (_hayServicio && (_transfTipo != null || (_transfMonto ?? 0) > 0)) {
      if (_transfTipo == null) return 'Elige el tipo de transferencia';
      if ((_transfMonto ?? 0) <= 0)
        return 'Indica el monto de la transferencia';
    }
    if (_faltante > 0.005) {
      return 'Faltan Bs ${_faltante.toStringAsFixed(2)} para cubrir el total';
    }
    return null;
  }

  // ───────────────────────── Registrar ─────────────────────────

  /// Registra la venta. Devuelve los datos para mostrar el éxito, o null si falló (ya avisado).
  Future<({Map<String, dynamic> venta, double total, double cambio})?>
  _registrarVenta([StateSetter? setSheet]) async {
    if (_guardando) return null;
    final bloqueo = _bloqueoConfirmacion();
    if (bloqueo != null) {
      _mensaje(bloqueo, error: true);
      return null;
    }

    final catalogos = _catalogos!;
    final total = _total;
    final cambio = _cambio;
    final obs = _obsCtrl.text.trim();

    // Desglose de pagos como en la web: EFECTIVO (1) y TRANSFERENCIA/QR (2)
    // A crédito no se registran pagos: la venta queda como cuenta por cobrar
    final pagos = _ventaCredito
        ? <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[
            if (_montoEfectivo > 0)
              {
                'tipo_pago_id': _idTipoPago('EFECTIVO', 1),
                'monto': _r2(_montoEfectivo),
              },
            if (_montoTransferencia > 0)
              {
                'tipo_pago_id': _idTipoPago('TRANSFERENCIA/QR', 2),
                'monto': _r2(_montoTransferencia),
              },
          ];

    final payload = <String, dynamic>{
      'cliente_id': _cliente!.id,
      'fecha': _fechaHoy(),
      'subtotal': total,
      'descuento': 0,
      'impuesto': 0,
      'total': total,
      'observaciones': obs.isEmpty ? null : obs,
      'usuario_id': catalogos.usuarioId,
      'almacen_id': catalogos.almacenId,
      'estado_documento_id': catalogos.estadoDocumentoId,
      'moneda_id': catalogos.monedaId,
      'tipo_documento_id': catalogos.tipoDocumentoId,
      'tipo_pago_id': _ventaCredito
          ? _idTipoPago('CREDITO', 3)
          : _idTipoPago(
              _codigoTipoPago,
              _montoTransferencia > 0 && _montoEfectivo > 0 ? 4 : 1,
            ),
      'pagos': pagos,
      if (!_ventaCredito &&
          _hayServicio &&
          _transfTipo != null &&
          (_transfMonto ?? 0) > 0) ...{
        'transferencia_monto': _r2(_transfMonto!),
        'transferencia_tipo': _transfTipo,
      },
      'monto_pagado_inicial': _ventaCredito ? 0 : _pagado,
      'canal_origen': 'PRESENCIAL',
      'estado_pago': 'PAGADO',
      'politica_pago': _ventaCredito ? 'CREDITO' : 'ANTICIPADO_100',
      'requiere_envio': false,
      'detalles': _items
          .map(
            (i) => {
              'producto_id': i.producto.id,
              'cantidad': i.cantidad,
              'precio_unitario': i.precioUnitario,
              'descuento': 0,
              'subtotal': _r2(i.subtotal),
              'tipo_precio_id': i.tipoPrecioId,
              'tipo_precio_nombre': i.tipoPrecioNombre,
            },
          )
          .toList(),
    };

    _mutar(() => _guardando = true, setSheet);
    try {
      final venta = await ventasService.crearVenta(payload);
      if (!mounted) return null;
      _limpiar();
      return (venta: venta, total: total, cambio: cambio);
    } catch (e) {
      _mensaje(_texto(e), error: true);
      return null;
    } finally {
      if (mounted) _mutar(() => _guardando = false, setSheet);
    }
  }

  void _limpiar() {
    setState(() {
      _items.clear();
      _cliente = _catalogos?.clienteGeneral;
      _efectivoCtrl.clear();
      _transferenciaCtrl.clear();
      _obsCtrl.clear();
      _transfTipo = null;
      _transfMontoCtrl.clear();
      _ventaCredito = false;
      _credito = null;
    });
    // El stock cambió con la venta: recargar el listado
    _cargarPrimeraPagina();
  }

  Future<void> _mostrarExito(
    Map<String, dynamic> venta, {
    required double total,
    required double cambio,
  }) {
    final numero = venta['numero']?.toString() ?? '';
    final tema = Theme.of(context);
    final estado = AppColores.estado(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle, color: estado.verde, size: 48),
        title: const Text('¡Venta registrada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (numero.isNotEmpty)
              Text(
                'N° $numero',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Bs ${total.toStringAsFixed(2)}',
              style: tema.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: tema.colorScheme.primary,
              ),
            ),
            if (cambio > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Cambio: Bs ${cambio.toStringAsFixed(2)}',
                style: tema.textTheme.titleMedium?.copyWith(
                  color: estado.verde,
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nueva venta'),
          ),
        ],
      ),
    );
  }

  void _abrirCarrito() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: _carritoRev,
        builder: (ctx, _, __) => StatefulBuilder(
          builder: (ctx, setSheet) => _contenidoCarrito(ctx, setSheet),
        ),
      ),
    );
  }

  Widget _contenidoCarrito(BuildContext ctx, StateSetter setSheet) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final bloqueo = _bloqueoConfirmacion();
    final maxAlto = MediaQuery.sizeOf(ctx).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxAlto),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tu carrito',
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_items.isNotEmpty)
                    Text(
                      '$_cantidadTotal artículo${_cantidadTotal == 1 ? '' : 's'}',
                      style: tema.textTheme.labelLarge?.copyWith(
                        color: colores.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _bloqueVenta('Cliente', Icons.person_outline, [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: colores.primaryContainer,
                    foregroundColor: colores.onPrimaryContainer,
                    child: const Icon(Icons.person),
                  ),
                  title: Text(
                    _cliente?.nombre ?? 'Sin cliente seleccionado',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Toca para cambiar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _elegirCliente(setSheet),
                ),
              ]),
              const SizedBox(height: 12),
              _bloqueVenta(
                'Productos',
                Icons.shopping_basket_outlined,
                [
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Tu carrito está vacío',
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: colores.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final item in _items) _filaCarrito(item, setSheet),
                ],
                accion: TextButton.icon(
                  onPressed: _items.isEmpty
                      ? null
                      : () => _mutar(_items.clear, setSheet),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Vaciar'),
                ),
              ),
              if (_hayServicio) ...[
                const SizedBox(height: 12),
                _seccionTransferencia(setSheet),
              ],
              if (_cliente?.puedeTenerCredito == true) ...[
                const SizedBox(height: 12),
                _bloqueVenta('Crédito', Icons.credit_score_outlined, [
                  _seccionCredito(setSheet),
                ]),
              ],
              const SizedBox(height: 12),
              _bloqueVenta('Cobro', Icons.payments_outlined, [
                if (!_ventaCredito) ...[
                  TextField(
                    controller: _efectivoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _mutar(() {}, setSheet),
                    decoration: InputDecoration(
                      labelText: 'Efectivo (Bs)',
                      hintText: _total.toStringAsFixed(2),
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _transferenciaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _mutar(() {}, setSheet),
                    decoration: const InputDecoration(
                      labelText: 'Transferencia / QR (Bs)',
                      prefixIcon: Icon(Icons.qr_code_2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      _sinDesglose
                          ? 'Vacío = todo en efectivo. Puedes dividir el cobro entre efectivo y transferencia.'
                          : 'Tipo de pago: $_nombreTipoPago',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _resumenTotales(),
              ]),
              if (bloqueo != null) ...[
                const SizedBox(height: 12),
                Text(bloqueo, style: TextStyle(color: colores.error)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: (_guardando || bloqueo != null)
                    ? null
                    : () async {
                        final r = await _registrarVenta(setSheet);
                        if (r != null && ctx.mounted) {
                          Navigator.pop(ctx);
                          await _mostrarExito(
                            r.venta,
                            total: r.total,
                            cambio: r.cambio,
                          );
                        }
                      },
                icon: _guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  'Confirmar venta · Bs ${_total.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bloque plano con título e icono, igual que el formulario de productos.
  Widget _bloqueVenta(
    String titulo,
    IconData icono,
    List<Widget> hijos, {
    Widget? accion,
  }) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    return Material(
      color: colores.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colores.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: colores.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (accion != null) accion,
              ],
            ),
            const SizedBox(height: 10),
            ...hijos,
          ],
        ),
      ),
    );
  }

  /// Precio de la lista que corresponde al tipo elegido en la línea (para el selector).
  PrecioVenta? _precioDeLinea(ItemVenta item) {
    for (final p in item.producto.preciosVenta) {
      if (p.tipoPrecioId == item.tipoPrecioId) return p;
    }
    return null;
  }

  Widget _filaCarrito(ItemVenta item, StateSetter setSheet) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _miniatura(item.producto.imagenUrl, 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (item.producto.preciosVenta.length > 1)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<PrecioVenta>(
                      isDense: true,
                      value: _precioDeLinea(item),
                      items: [
                        for (final p in item.producto.preciosVenta)
                          DropdownMenuItem(
                            value: p,
                            child: Text(
                              '${p.nombre} · Bs ${p.precio.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                      onChanged: (p) {
                        if (p == null) return;
                        _mutar(() {
                          item.tipoPrecioId = p.tipoPrecioId;
                          item.tipoPrecioNombre = p.nombre;
                          item.precioUnitario = p.precio;
                        }, setSheet);
                      },
                    ),
                  ),
                GestureDetector(
                  onTap: () => _editarPrecio(item, setSheet),
                  child: Text(
                    'Bs ${item.precioUnitario.toStringAsFixed(2)} c/u · editar',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (item.superaStock)
                  Text(
                    'Supera el stock (${item.producto.stockDisponible.toStringAsFixed(0)})',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs ${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _stepper(item, setSheet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resumenTotales() {
    if (_ventaCredito) {
      return Column(
        children: [
          _filaTotal('Artículos', '$_cantidadTotal'),
          _filaTotal(
            'Total',
            'Bs ${_total.toStringAsFixed(2)}',
            destacado: true,
          ),
          _filaTotal('Pago', 'A crédito'),
        ],
      );
    }
    final theme = Theme.of(context);
    return Column(
      children: [
        _filaTotal('Artículos', '$_cantidadTotal'),
        _filaTotal('Total', 'Bs ${_total.toStringAsFixed(2)}', destacado: true),
        _filaTotal('Pagado', 'Bs ${_pagado.toStringAsFixed(2)}'),
        if (_faltante > 0)
          _filaTotal(
            'Faltante',
            'Bs ${_faltante.toStringAsFixed(2)}',
            color: theme.colorScheme.error,
          )
        else
          _filaTotal(
            'Cambio',
            'Bs ${_cambio.toStringAsFixed(2)}',
            color: _cambio > 0 ? theme.colorScheme.primary : null,
          ),
      ],
    );
  }

  Widget _filaTotal(
    String etiqueta,
    String valor, {
    bool destacado = false,
    Color? color,
  }) {
    final estilo = TextStyle(
      fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
      fontSize: destacado ? 18 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo),
          Text(valor, style: estilo),
        ],
      ),
    );
  }

  // ───────────────────────── UI principal ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargandoInicial ? null : _cargarInicial,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'venta'),
      body: _cargandoInicial
          ? const Center(child: CircularProgressIndicator())
          : _errorInicial != null
          ? _estadoError()
          : Column(
              children: [
                if (!_cajaAbierta) _bannerCaja(),
                _barraCliente(),
                _barraBusqueda(),
                Expanded(child: _cuadriculaProductos()),
              ],
            ),
      bottomNavigationBar:
          _items.isEmpty || _cargandoInicial || _errorInicial != null
          ? null
          : _barraCarrito(),
    );
  }

  Widget _estadoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(_errorInicial!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cargarInicial,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerCaja() {
    final colores = Theme.of(context).colorScheme;
    return Material(
      color: colores.errorContainer,
      child: InkWell(
        onTap: _abrirPantallaCaja,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: colores.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No tienes caja abierta. Ábrela para poder vender.',
                  style: TextStyle(color: colores.onErrorContainer),
                ),
              ),
              Text(
                'Abrir',
                style: TextStyle(
                  color: colores.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraCliente() {
    final cliente = _cliente;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: const Icon(Icons.person_outline),
        ),
        title: Text(
          cliente?.nombre ?? 'Elegir cliente',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          cliente == null
              ? 'Elige un cliente'
              : (cliente.nit != null && cliente.nit!.isNotEmpty
                    ? 'NIT: ${cliente.nit}'
                    : 'Toca para cambiar'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _elegirCliente(),
      ),
    );
  }

  Widget _barraBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _buscarCtrl,
        onChanged: _onBuscarChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar producto, código o SKU',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_buscarCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _buscarCtrl.clear();
                    _buscar('');
                  },
                ),
              IconButton(
                tooltip: 'Escanear código de barras',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _escanear,
              ),
            ],
          ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _cuadriculaProductos() {
    final busqueda = _consulta.length >= 2;

    if (busqueda) {
      if (_buscando) return const Center(child: CircularProgressIndicator());
      if (_resultados.isEmpty) {
        return _vacio(Icons.search_off, 'Sin resultados para "$_consulta"');
      }
    } else {
      if (_productos.isEmpty && _cargandoPagina) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_productos.isEmpty) {
        return _vacio(
          Icons.inventory_2_outlined,
          'No hay productos disponibles para vender',
        );
      }
    }

    final lista = busqueda ? _resultados : _productos;
    final mostrarPie = !busqueda;

    return RefreshIndicator(
      onRefresh: _cargarPrimeraPagina,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: lista.length,
              itemBuilder: (_, i) => _tarjetaProducto(lista[i]),
            ),
          ),
          if (mostrarPie && _cargandoPagina)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (mostrarPie && !_hayMas)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: Center(
                  child: Text(
                    'Fin del listado',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _vacio(IconData icono, String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaProducto(ProductoVenta p) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final estado = AppColores.estado(context);
    final item = _itemDe(p.id);
    final agotado =
        !p.esServicio && !p.permiteVentaSinStock && p.stockDisponible <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _miniatura(p.imagenUrl, null),
                if (agotado)
                  ColoredBox(
                    color: colores.surface.withValues(alpha: 0.75),
                    child: Center(
                      child: Text(
                        'AGOTADO',
                        style: tema.textTheme.labelLarge?.copyWith(
                          color: estado.rojo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _chipProducto(
                    p.esServicio
                        ? 'Servicio'
                        : 'Stock ${p.stockDisponible.toStringAsFixed(0)}',
                    p.esServicio
                        ? colores.primary
                        : (agotado ? estado.rojo : estado.verde),
                    sobreImagen: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'ID ${p.id}',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: colores.onSurfaceVariant,
                  ),
                ),
                if (p.codigosBarra.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        size: 12,
                        color: colores.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          p.codigosBarra.length > 1
                              ? '${p.codigosBarra.first} +${p.codigosBarra.length - 1}'
                              : p.codigosBarra.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: colores.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (p.preciosVenta.length > 1)
                  Text(
                    '${p.preciosVenta.length} tipos de precio · elige en el carrito',
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: colores.primary,
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _chipProducto(
                    'Bs ${p.precioVenta.toStringAsFixed(2)}',
                    colores.primary,
                    grande: true,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: item == null
                      ? FilledButton.tonal(
                          onPressed: agotado ? null : () => _agregar(p),
                          child: const Text('Agregar'),
                        )
                      : _stepper(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chip plano de la tarjeta de producto. Sobre la imagen usa fondo de superficie
  /// para que se lea en claro y en oscuro.
  Widget _chipProducto(
    String texto,
    Color color, {
    bool sobreImagen = false,
    bool grande = false,
  }) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: grande ? 10 : 8,
        vertical: grande ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: sobreImagen
            ? colores.surface.withValues(alpha: 0.9)
            : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: grande ? 15 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Escribir la cantidad directamente (ej. 20, 50, 90) en vez de tocar + muchas veces.
  Future<void> _editarCantidad(ItemVenta item, [StateSetter? setSheet]) async {
    final nueva = await DialogoMonto.mostrar(
      context,
      titulo: item.producto.nombre,
      etiqueta: 'Cantidad',
      valorInicial: item.cantidad.toStringAsFixed(0),
      textoConfirmar: 'Aplicar',
    );
    if (nueva == null) return;
    if (nueva < 1 || nueva != nueva.roundToDouble()) {
      _mensaje('Ingresa una cantidad entera mayor a 0', error: true);
      return;
    }
    if (!item.producto.permiteVentaSinStock &&
        nueva > item.producto.stockDisponible) {
      _mensaje(
        'Stock disponible: ${item.producto.stockDisponible.toStringAsFixed(0)}',
        error: true,
      );
      return;
    }
    _mutar(() => item.cantidad = nueva, setSheet);
  }

  /// Control − cantidad + para una línea del carrito.
  Widget _stepper(ItemVenta item, [StateSetter? setSheet]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _botonCantidad(
          Icons.remove,
          item.producto.esServicio
              ? null
              : () => _cambiarCantidad(item, -1, setSheet),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: item.producto.esServicio
              ? null
              : () => _editarCantidad(item, setSheet),
          child: Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Text(
              item.cantidad.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        _botonCantidad(
          Icons.add,
          !item.producto.esServicio &&
                  (item.producto.permiteVentaSinStock ||
                      item.cantidad + 1 <= item.producto.stockDisponible)
              ? () => _cambiarCantidad(item, 1, setSheet)
              : null,
        ),
      ],
    );
  }

  /// Botón plano de cantidad (− / +), del tema.
  Widget _botonCantidad(IconData icono, VoidCallback? onTap) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icono, size: 18),
      visualDensity: VisualDensity.compact,
      tooltip: icono == Icons.add ? 'Más' : 'Menos',
    );
  }

  Widget _miniatura(String? url, double? lado) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, size: 32),
    );
    final imagen = url == null
        ? placeholder
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (_, child, progreso) =>
                progreso == null ? child : placeholder,
          );
    if (lado == null) return imagen;
    return SizedBox(
      width: lado,
      height: lado,
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: imagen),
    );
  }

  Widget _barraCarrito() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _abrirCarrito,
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(
            'Ver carrito · $_cantidadTotal artículo${_cantidadTotal == 1 ? '' : 's'} · '
            'Bs ${_total.toStringAsFixed(2)}',
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Helpers ─────────────────────────

  /// Cambia estado de la pantalla y, si hay una hoja abierta, también su contenido.
  void _mutar(VoidCallback fn, [StateSetter? setSheet]) {
    setState(fn);
    // La hoja del carrito escucha este contador: así siempre refleja el cambio
    _carritoRev.value++;
    setSheet?.call(() {});
  }

  void _mensaje(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  String _texto(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  double _r2(double v) => double.parse(v.toStringAsFixed(2));

  double? _numero(String s) {
    final limpio = s.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    return double.tryParse(limpio);
  }

  String _fechaHoy() {
    final hoy = DateTime.now();
    final mm = hoy.month.toString().padLeft(2, '0');
    final dd = hoy.day.toString().padLeft(2, '0');
    return '${hoy.year}-$mm-$dd';
  }
}
