import 'package:flutter/material.dart';

import '../config/colores_app.dart';

import '../models/movimiento_caja_app.dart';
import '../services/api_errors.dart';
import '../services/caja_service.dart';
import '../services/movimientos_service.dart';
import '../widgets/app_drawer.dart';

/// Registrar egresos o ingresos de caja, con montos en efectivo y transferencia/QR
/// por cada detalle (igual que la web). Requiere caja abierta.
class MovimientoCajaScreen extends StatefulWidget {
  /// true = ingreso (entra dinero a caja), false = egreso (sale dinero de caja)
  final bool esIngreso;

  const MovimientoCajaScreen({super.key, required this.esIngreso});

  @override
  State<MovimientoCajaScreen> createState() => _MovimientoCajaScreenState();
}

/// Un detalle del formulario: tipo de operación, concepto y los dos montos.
class _Detalle {
  TipoOperacionCaja? tipo;
  final concepto = TextEditingController();
  final efectivo = TextEditingController();
  final transferencia = TextEditingController();

  void dispose() {
    concepto.dispose();
    efectivo.dispose();
    transferencia.dispose();
  }
}

class _MovimientoCajaScreenState extends State<MovimientoCajaScreen> {
  final _descripcion = TextEditingController();
  final _observaciones = TextEditingController();
  final List<_Detalle> _detalles = [];

  List<TipoOperacionCaja> _tipos = [];
  bool _cajaAbierta = false;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  String get _direccion => widget.esIngreso ? 'ENTRADA' : 'SALIDA';
  String get _titulo =>
      widget.esIngreso ? 'Registrar ingreso' : 'Registrar egreso';

  /// Tipos de operación de la dirección de esta pantalla (ingreso o egreso).
  List<TipoOperacionCaja> get _tiposDeEsta =>
      _tipos.where((t) => t.direccion == _direccion).toList();

  @override
  void initState() {
    super.initState();
    _detalles.add(_Detalle());
    _descripcion.text = _descripcionPorDefecto();
    _cargar();
  }

  /// "Salida Diaria - 23/11/2026 - 14:35": fecha y hora dan un identificador del movimiento.
  String _descripcionPorDefecto() {
    final ahora = DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    final fecha = '${dos(ahora.day)}/${dos(ahora.month)}/${ahora.year}';
    final hora = '${dos(ahora.hour)}:${dos(ahora.minute)}';
    final base = widget.esIngreso ? 'Entrada Diaria' : 'Salida Diaria';
    return '$base - $fecha - $hora';
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _observaciones.dispose();
    for (final d in _detalles) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final tipos = await movimientosService.getTiposOperacion();
      final estado = await cajaService.estado();
      if (!mounted) return;
      setState(() {
        _tipos = tipos;
        _cajaAbierta = estado.abierta;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _texto(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ───────────────────────── Totales y validación ─────────────────────────

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  double _subtotal(_Detalle d) => _num(d.efectivo) + _num(d.transferencia);

  double get _totalEfectivo =>
      _detalles.fold(0.0, (s, d) => s + _num(d.efectivo));

  double get _totalTransferencia =>
      _detalles.fold(0.0, (s, d) => s + _num(d.transferencia));

  double get _total => _totalEfectivo + _totalTransferencia;

  String? _bloqueo() {
    if (!_cajaAbierta) return 'Abre tu caja para registrar movimientos';
    for (var i = 0; i < _detalles.length; i++) {
      final d = _detalles[i];
      final n = i + 1;
      if (d.tipo == null) return 'Detalle $n: elige el tipo de operación';
      if (d.concepto.text.trim().isEmpty)
        return 'Detalle $n: escribe el concepto';
      if (_num(d.efectivo) < 0 || _num(d.transferencia) < 0) {
        return 'Detalle $n: los montos no pueden ser negativos';
      }
      if (_subtotal(d) <= 0)
        return 'Detalle $n: ingresa un monto en efectivo o transferencia';
    }
    return null;
  }

  // ───────────────────────── Acciones ─────────────────────────

  void _agregarDetalle() {
    setState(() => _detalles.add(_Detalle()));
  }

  void _quitarDetalle(_Detalle d) {
    if (_detalles.length == 1) return;
    setState(() => _detalles.remove(d));
    d.dispose();
  }

  Future<void> _registrar() async {
    if (_guardando) return;
    final bloqueo = _bloqueo();
    if (bloqueo != null) {
      _mensaje(bloqueo, error: true);
      return;
    }

    final payload = <String, dynamic>{
      'descripcion': _descripcion.text.trim().isEmpty
          ? null
          : _descripcion.text.trim(),
      'observaciones': _observaciones.text.trim().isEmpty
          ? null
          : _observaciones.text.trim(),
      'detalles': [
        for (final d in _detalles)
          {
            'concepto': d.concepto.text.trim(),
            'tipo_operacion_caja_id': d.tipo!.id,
            'monto_efectivo': _num(d.efectivo),
            'monto_transferencia': _num(d.transferencia),
          },
      ],
    };

    setState(() => _guardando = true);
    try {
      final r = await movimientosService.registrar(
        ingreso: widget.esIngreso,
        payload: payload,
      );
      if (!mounted) return;
      _limpiar();
      await _mostrarExito(r);
    } catch (e) {
      _mensaje(_texto(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _limpiar() {
    setState(() {
      for (final d in _detalles) {
        d.dispose();
      }
      _detalles
        ..clear()
        ..add(_Detalle());
      _descripcion.text = _descripcionPorDefecto();
      _observaciones.clear();
    });
  }

  Future<void> _mostrarExito(Map<String, dynamic> r) {
    final numero = r['numero']?.toString() ?? '';
    // El backend puede devolver el total como número o como texto ("240.00")
    final total = double.tryParse('${r['total'] ?? 0}') ?? 0;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          color: AppColores.estado(context).verde,
          size: 48,
        ),
        title: Text(
          widget.esIngreso ? 'Ingreso registrado' : 'Egreso registrado',
        ),
        content: Text(
          '${numero.isNotEmpty ? 'N° $numero\n' : ''}'
          'Total: Bs ${total.toStringAsFixed(2)}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: widget.esIngreso ? 'ingreso' : 'egreso'),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _estadoError()
          : _formulario(),
      bottomNavigationBar: _cargando || _error != null
          ? null
          : _barraInferior(),
    );
  }

  Widget _estadoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario() {
    final colores = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_cajaAbierta)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colores.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: colores.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No tienes caja abierta. Ábrela en "Mi caja" para registrar movimientos.',
                    style: TextStyle(color: colores.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        _bloqueMov('Datos generales', Icons.notes_outlined, [
          TextField(
            controller: _descripcion,
            decoration: const InputDecoration(
              labelText: 'Descripción general (opcional)',
            ),
          ),
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < _detalles.length; i++) ...[
          _tarjetaDetalle(i + 1, _detalles[i]),
          const SizedBox(height: 12),
        ],
        FilledButton.tonalIcon(
          onPressed: _agregarDetalle,
          icon: const Icon(Icons.add),
          label: const Text('Agregar detalle'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 12),
        _bloqueMov('Observaciones', Icons.edit_note_outlined, [
          TextField(
            controller: _observaciones,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
            ),
          ),
        ]),
        const SizedBox(height: 96),
      ],
    );
  }

  /// Bloque plano con título e icono, igual que en Nueva venta y en Productos.
  Widget _bloqueMov(
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

  /// Chip plano para montos: fondo del mismo color con baja opacidad.
  Widget _chipMonto(String texto, Color color, {bool grande = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: grande ? 12 : 10,
        vertical: grande ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: grande ? 15 : 12,
        ),
      ),
    );
  }

  Widget _tarjetaDetalle(int n, _Detalle d) {
    final estado = AppColores.estado(context);
    final colorMonto = widget.esIngreso ? estado.verde : estado.rojo;
    return _bloqueMov(
      'Detalle $n',
      widget.esIngreso ? Icons.south_west : Icons.north_east,
      [
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Tipo de operación'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TipoOperacionCaja>(
              value: d.tipo,
              isExpanded: true,
              hint: const Text('Elige un tipo'),
              items: [
                for (final t in _tiposDeEsta)
                  DropdownMenuItem(value: t, child: Text(t.nombre)),
              ],
              onChanged: (t) => setState(() {
                // El concepto toma el nombre del tipo, salvo que el usuario ya lo haya escrito
                final anterior = d.tipo?.nombre ?? '';
                final concepto = d.concepto.text.trim();
                if (t != null && (concepto.isEmpty || concepto == anterior)) {
                  d.concepto.text = t.nombre;
                }
                d.tipo = t;
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: d.concepto,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Concepto'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: d.efectivo,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Efectivo (Bs)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: d.transferencia,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Transferencia (Bs)',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _chipMonto(
            'Subtotal Bs ${_subtotal(d).toStringAsFixed(2)}',
            colorMonto,
          ),
        ),
      ],
      accion: _detalles.length > 1
          ? IconButton(
              tooltip: 'Quitar detalle',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _quitarDetalle(d),
            )
          : null,
    );
  }

  Widget _barraInferior() {
    final bloqueo = _bloqueo();
    final colores = Theme.of(context).colorScheme;
    final estado = AppColores.estado(context);
    final colorTotal = widget.esIngreso ? estado.verde : estado.rojo;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: colores.surface,
          border: Border(top: BorderSide(color: colores.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _chipMonto(
                    'Efectivo Bs ${_totalEfectivo.toStringAsFixed(2)}',
                    colores.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _chipMonto(
                    'Transf. Bs ${_totalTransferencia.toStringAsFixed(2)}',
                    colores.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  'Bs ${_total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorTotal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: (_guardando || bloqueo != null) ? null : _registrar,
              icon: _guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      widget.esIngreso ? Icons.south_west : Icons.north_east,
                    ),
              label: Text(
                widget.esIngreso ? 'Registrar ingreso' : 'Registrar egreso',
              ),
            ),
          ],
        ),
      ),
    );
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
}
