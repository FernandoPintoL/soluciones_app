import 'dart:async';

import 'package:flutter/material.dart';

import '../config/colores_app.dart';

import '../models/venta_app.dart';
import '../models/venta_listado.dart';
import '../services/api_errors.dart';
import '../services/ventas_service.dart';
import '../widgets/app_drawer.dart';
import 'venta_detalle_screen.dart';

/// Listado de ventas con filtros (número o cliente, fechas, estado de pago, tipo de pago),
/// paginado con scroll infinito. Por defecto muestra las ventas de hoy.
class VentasListadoScreen extends StatefulWidget {
  const VentasListadoScreen({super.key});

  @override
  State<VentasListadoScreen> createState() => _VentasListadoScreenState();
}

/// Filtros elegidos en la hoja de filtros.
typedef _Filtros = ({
  DateTime? desde,
  DateTime? hasta,
  String? estadoPago,
  TipoPagoVenta? tipoPago,
});

class _VentasListadoScreenState extends State<VentasListadoScreen> {
  final _buscarCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<VentaListado> _items = [];
  int _pagina = 0;
  bool _hayMas = true;
  bool _cargando = false;
  int _req = 0;
  String? _error;

  // Filtros
  String _search = '';
  DateTime? _desde;
  DateTime? _hasta;
  String? _estadoPago;
  TipoPagoVenta? _tipoPago;
  List<TipoPagoVenta> _tiposPago = [];

  @override
  void initState() {
    super.initState();
    final hoy = _soloFecha(DateTime.now());
    _desde = hoy;
    _hasta = hoy;
    _scroll.addListener(_onScroll);
    _cargarTipos();
    _recargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscarCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarTipos() async {
    try {
      final tipos = await ventasService.getTiposPago();
      if (mounted) setState(() => _tiposPago = tipos);
    } catch (_) {
      // Sin tipos de pago el filtro queda en "Todos"
    }
  }

  void _onBuscarChanged(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      // "#2122" y "2122" buscan lo mismo: el número de la venta o su id
      final texto = valor.trim().replaceFirst('#', '').trim();
      if (texto != _search) {
        _search = texto;
        _recargar();
      }
    });
  }

  /// Vuelve a la primera página con los filtros actuales.
  Future<void> _recargar() async {
    final req = ++_req;
    setState(() {
      _items.clear();
      _pagina = 0;
      _hayMas = true;
      _cargando = false;
      _error = null;
    });
    await _cargarPagina(req);
  }

  Future<void> _cargarPagina(int req) async {
    if (_cargando || !_hayMas) return;
    setState(() => _cargando = true);
    try {
      final siguiente = _pagina + 1;
      final r = await ventasService.listarVentas(
        page: siguiente,
        search: _search,
        // Con texto de búsqueda se busca en todas las fechas: si no, una venta
        // de otro día (ej. la 2122 de ayer) no aparece
        fechaDesde: _search.isNotEmpty || _desde == null ? null : _iso(_desde!),
        fechaHasta: _search.isNotEmpty || _hasta == null ? null : _iso(_hasta!),
        estadoPago: _estadoPago,
        tipoPagoId: _tipoPago?.id,
      );
      if (!mounted || req != _req) return;
      setState(() {
        _items.addAll(r.items);
        _pagina = siguiente;
        _hayMas = r.hasMore;
      });
    } catch (e) {
      if (mounted && req == _req) setState(() => _error = _texto(e));
    } finally {
      if (mounted && req == _req) {
        setState(() => _cargando = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      }
    }
  }

  void _onScroll() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.extentAfter < 300 || pos.maxScrollExtent == 0) {
      _cargarPagina(_req);
    }
  }

  Future<void> _abrirFiltros() async {
    final r = await showModalBottomSheet<_Filtros>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FiltrosSheet(
        desde: _desde,
        hasta: _hasta,
        estadoPago: _estadoPago,
        tipoPago: _tipoPago,
        tipos: _tiposPago,
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _desde = r.desde;
      _hasta = r.hasta;
      _estadoPago = r.estadoPago;
      _tipoPago = r.tipoPago;
    });
    _recargar();
  }

  Future<void> _abrirDetalle(VentaListado v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VentaDetalleScreen(ventaId: v.id)),
    );
    // La venta pudo anularse: recargar el listado al volver
    if (mounted) _recargar();
  }

  /// Filtros activos, mostrados como chips. Con texto de búsqueda, las fechas no aplican.
  List<String> get _etiquetasFiltros {
    final partes = <String>[];
    if (_search.isNotEmpty) {
      partes.add('Buscando "$_search" en todas las fechas');
    } else if (_desde != null && _hasta != null) {
      final mismoDia = _iso(_desde!) == _iso(_hasta!);
      final hoy = _iso(_soloFecha(DateTime.now()));
      if (mismoDia && _iso(_desde!) == hoy) {
        partes.add('Hoy');
      } else if (mismoDia) {
        partes.add(_fecha(_desde!));
      } else {
        partes.add('${_fecha(_desde!)} – ${_fecha(_hasta!)}');
      }
    } else {
      partes.add('Todas las fechas');
    }
    if (_estadoPago != null) partes.add(_estadoPago!);
    if (_tipoPago != null) partes.add(_tipoPago!.nombre);
    return partes;
  }

  Widget _chipFiltro(String texto) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colores.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, color: colores.onSecondaryContainer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            icon: const Icon(Icons.tune),
            onPressed: _abrirFiltros,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'ventas'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _buscarCtrl,
              builder: (context, valor, _) => TextField(
                controller: _buscarCtrl,
                onChanged: _onBuscarChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Número, ID o cliente',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: valor.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _buscarCtrl.clear();
                            _onBuscarChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in _etiquetasFiltros) _chipFiltro(t)],
            ),
          ),
          Expanded(child: _listado()),
        ],
      ),
    );
  }

  Widget _listado() {
    if (_items.isEmpty) {
      if (_cargando) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Text(
          'No hay ventas con estos filtros',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final conPie = _cargando || _hayMas;
    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: _items.length + (conPie ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _tarjetaVenta(_items[i]);
        },
      ),
    );
  }

  Widget _tarjetaVenta(VentaListado v) {
    final theme = Theme.of(context);
    final estado = AppColores.estado(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDetalle(v),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Opacity(
            opacity: v.anulada ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        v.numero,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      formatearFechaHoraVenta(v.fecha, v.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  v.clienteNombre.isEmpty ? 'Sin cliente' : v.clienteNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (v.anulada)
                      _etiqueta('ANULADA', estado.rojo, Colors.white)
                    else
                      _etiqueta(
                        v.estadoPago.isEmpty ? 'SIN PAGO' : v.estadoPago,
                        _colorEstadoPago(v.estadoPago),
                        Colors.white,
                      ),
                    const SizedBox(width: 8),
                    if (v.tipoPagoNombre.isNotEmpty)
                      Expanded(
                        child: Text(
                          v.tipoPagoNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      'Bs ${v.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _etiqueta(String texto, Color fondo, Color textoColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: textoColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _colorEstadoPago(String estadoPago) {
    final estado = AppColores.estado(context);
    switch (estadoPago) {
      case 'PAGADO':
        return estado.verde;
      case 'PARCIAL':
        return estado.naranja;
      default:
        return estado.rojo;
    }
  }

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  String _iso(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dos(d.month)}-${dos(d.day)}';
  }

  String _fecha(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}';
  }

  String _texto(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');
}

/// Hoja de filtros: rango de fechas, estado de pago y tipo de pago.
class _FiltrosSheet extends StatefulWidget {
  final DateTime? desde;
  final DateTime? hasta;
  final String? estadoPago;
  final TipoPagoVenta? tipoPago;
  final List<TipoPagoVenta> tipos;

  const _FiltrosSheet({
    required this.desde,
    required this.hasta,
    required this.estadoPago,
    required this.tipoPago,
    required this.tipos,
  });

  @override
  State<_FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<_FiltrosSheet> {
  late DateTime? _desde = widget.desde;
  late DateTime? _hasta = widget.hasta;
  late String? _estadoPago = widget.estadoPago;
  late TipoPagoVenta? _tipoPago = widget.tipoPago;

  Future<void> _elegirFecha(bool esDesde) async {
    final inicial = (esDesde ? _desde : _hasta) ?? DateTime.now();
    final r = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (r == null) return;
    setState(() {
      if (esDesde) {
        _desde = r;
        // Mantener el rango válido
        if (_hasta != null && _hasta!.isBefore(r)) _hasta = r;
      } else {
        _hasta = r;
        if (_desde != null && _desde!.isAfter(r)) _desde = r;
      }
    });
  }

  String _fecha(DateTime? d) {
    if (d == null) return 'Elegir';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final soloHoy =
        _desde != null &&
        _hasta != null &&
        _desde!.year == hoy.year &&
        _desde!.month == hoy.month &&
        _desde!.day == hoy.day &&
        _hasta == _desde;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtros',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Hoy'),
                selected: soloHoy,
                onSelected: (_) => setState(() {
                  final h = DateTime(hoy.year, hoy.month, hoy.day);
                  _desde = h;
                  _hasta = h;
                }),
              ),
              ChoiceChip(
                label: const Text('Todas las fechas'),
                selected: _desde == null && _hasta == null,
                onSelected: (_) => setState(() {
                  _desde = null;
                  _hasta = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _elegirFecha(true),
                  child: Text('Desde: ${_fecha(_desde)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _elegirFecha(false),
                  child: Text('Hasta: ${_fecha(_hasta)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Estado de pago',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _estadoPago,
                isExpanded: true,
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                  DropdownMenuItem<String?>(
                    value: 'PAGADO',
                    child: Text('Pagado'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'PARCIAL',
                    child: Text('Parcial'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'PENDIENTE',
                    child: Text('Pendiente'),
                  ),
                ],
                onChanged: (v) => setState(() => _estadoPago = v),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tipo de pago',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TipoPagoVenta?>(
                value: _tipoPago,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<TipoPagoVenta?>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  for (final t in widget.tipos)
                    DropdownMenuItem<TipoPagoVenta?>(
                      value: t,
                      child: Text(t.nombre),
                    ),
                ],
                onChanged: (v) => setState(() => _tipoPago = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, (
                    desde: null,
                    hasta: null,
                    estadoPago: null,
                    tipoPago: null,
                  )),
                  child: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, (
                    desde: _desde,
                    hasta: _hasta,
                    estadoPago: _estadoPago,
                    tipoPago: _tipoPago,
                  )),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
