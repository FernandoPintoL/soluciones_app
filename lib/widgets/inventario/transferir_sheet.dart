import 'package:flutter/material.dart';

import '../../services/service_locator.dart';
import '../campo_formulario.dart';
import '../colores_almacen.dart';

/// Bottom sheet para transferir stock de un producto a otro almacén.
/// Replica el modal "Transferir" de Actualizar Stock Masivo (web):
///  - En paquetes: mueve el producto tal cual desde un lote/sector.
///  - En unidades del producto hijo: usa primero las unidades sueltas y abre
///    los paquetes que falten (lo hace el backend).
///
/// [filasProducto] son las filas del producto por almacén (respuesta de
/// `getProductosStock`). Devuelve el mensaje del backend o null si se cancela.
class TransferirSheet extends StatefulWidget {
  final List<Map<String, dynamic>> filasProducto;
  final int almacenOrigenId;
  final List<Map<String, dynamic>> almacenes;
  final int? destinoInicialId;
  final num? cantidadInicial;

  const TransferirSheet({
    super.key,
    required this.filasProducto,
    required this.almacenOrigenId,
    required this.almacenes,
    this.destinoInicialId,
    this.cantidadInicial,
  });

  static Future<String?> mostrar(
    BuildContext context, {
    required List<Map<String, dynamic>> filasProducto,
    required int almacenOrigenId,
    required List<Map<String, dynamic>> almacenes,
    int? destinoInicialId,
    num? cantidadInicial,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TransferirSheet(
        filasProducto: filasProducto,
        almacenOrigenId: almacenOrigenId,
        almacenes: almacenes,
        destinoInicialId: destinoInicialId,
        cantidadInicial: cantidadInicial,
      ),
    );
  }

  @override
  State<TransferirSheet> createState() => _TransferirSheetState();
}

class _TransferirSheetState extends State<TransferirSheet> {
  final _cantidadController = TextEditingController();
  int? _registroId;
  int? _destinoId;
  bool _modoUnidades = false;
  int? _conversionId;
  bool _usarSueltas = true;
  bool _guardando = false;
  String? _errorServidor;

  // Filas del producto hijo por almacén (se piden al pasar a modo unidades)
  final Map<int, List<Map<String, dynamic>>> _filasHijo = {};
  bool _cargandoHijo = false;

  Map<String, dynamic> get _origen => widget.filasProducto.firstWhere(
    (f) => f['almacen_id'] == widget.almacenOrigenId,
  );

  List<Map<String, dynamic>> get _registros => [
    for (final s in (_origen['stocks'] as List? ?? const []))
      if ((num.tryParse('${s['cantidad_disponible']}') ?? 0) > 0)
        Map<String, dynamic>.from(s as Map),
  ];

  List<Map<String, dynamic>> get _destinos => [
    for (final a in widget.almacenes)
      if (a['id'] != widget.almacenOrigenId) a,
  ];

  List<Map<String, dynamic>> get _hijos => _origen['es_fraccionado'] == true
      ? [
          for (final c in (_origen['conversiones'] as List? ?? const []))
            if (c['producto_hijo_id'] != null) Map<String, dynamic>.from(c),
        ]
      : const [];

  @override
  void initState() {
    super.initState();
    final registros = [..._registros]
      ..sort(
        (a, b) => (num.tryParse('${b['cantidad_disponible']}') ?? 0).compareTo(
          num.tryParse('${a['cantidad_disponible']}') ?? 0,
        ),
      );
    _registroId = registros.firstOrNull?['id'] as int?;
    final destinos = _destinos;
    _destinoId = destinos.any((d) => d['id'] == widget.destinoInicialId)
        ? widget.destinoInicialId
        : (destinos.length == 1 ? destinos.first['id'] as int : null);
    _conversionId = _hijos.firstOrNull?['id'] as int?;
    if (widget.cantidadInicial != null && widget.cantidadInicial! > 0) {
      _cantidadController.text = formatearCantidad(widget.cantidadInicial);
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarHijo(int hijoId) async {
    if (_filasHijo.containsKey(hijoId)) return;
    setState(() => _cargandoHijo = true);
    try {
      final r = await apiService.getProductosStock(ids: [hijoId], limite: 1);
      _filasHijo[hijoId] = r['filas'] ?? [];
    } catch (e) {
      _filasHijo[hijoId] = [];
      debugPrint('[Transferir] Error cargando producto hijo: $e');
    } finally {
      if (mounted) setState(() => _cargandoHijo = false);
    }
  }

  void _cambiarModo(bool unidades) {
    setState(() => _modoUnidades = unidades);
    final hijoId = _conversion?['producto_hijo_id'] as int?;
    if (unidades && hijoId != null) _cargarHijo(hijoId);
  }

  Map<String, dynamic>? get _conversion =>
      _hijos.where((c) => c['id'] == _conversionId).firstOrNull;

  Map<String, dynamic>? _filaHijoEn(int? almacenId) {
    final hijoId = _conversion?['producto_hijo_id'];
    return _filasHijo[hijoId]
        ?.where((f) => f['almacen_id'] == almacenId)
        .firstOrNull;
  }

  /// Unidades sueltas del hijo: mismo registro que usa el backend (sin lote
  /// ni vencimiento, priorizando el sector del paquete, luego el menor id).
  static num _sueltasDelHijo(
    Map<String, dynamic>? fila,
    String? sectorPaquete,
  ) {
    final candidatos =
        [
          for (final s in (fila?['stocks'] as List? ?? const []))
            if (s['lote'] == null && s['fecha_vencimiento'] == null) s as Map,
        ]..sort((a, b) {
          final porSector =
              ((b['sector'] == sectorPaquete) ? 1 : 0) -
              ((a['sector'] == sectorPaquete) ? 1 : 0);
          return porSector != 0
              ? porSector
              : (a['id'] as int) - (b['id'] as int);
        });
    final n =
        num.tryParse('${candidatos.firstOrNull?['cantidad_disponible']}') ?? 0;
    return n < 0 ? 0 : n;
  }

  static num _stockEn(Map<String, dynamic>? fila) =>
      num.tryParse('${fila?['cantidad_total'] ?? 0}') ?? 0;

  Future<void> _transferir() async {
    final registro = _registros
        .where((r) => r['id'] == _registroId)
        .firstOrNull;
    final valor =
        num.tryParse(_cantidadController.text.replaceAll(',', '.')) ?? 0;
    if (registro == null || _destinoId == null || valor <= 0) return;

    setState(() {
      _guardando = true;
      _errorServidor = null;
    });
    try {
      final mensaje = await apiService.transferirProducto(
        stockProductoId: registro['id'] as int,
        almacenDestinoId: _destinoId!,
        cantidad: valor,
        conversionId: _modoUnidades ? _conversion!['id'] as int : null,
        usarSueltas: _usarSueltas,
      );
      if (mounted) Navigator.pop(context, mensaje);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorServidor = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origen = _origen;
    final registros = _registros;
    final registro = registros.where((r) => r['id'] == _registroId).firstOrNull;
    final destino = _destinos.where((d) => d['id'] == _destinoId).firstOrNull;
    final unidadPaquete = '${origen['unidad_nombre'] ?? ''}';
    final esFraccionado = origen['es_fraccionado'] == true;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _cantidadController,
      builder: (context, texto, _) {
        final valor = num.tryParse(texto.text.replaceAll(',', '.')) ?? 0;
        final disponible =
            num.tryParse('${registro?['cantidad_disponible'] ?? 0}') ?? 0;

        // ── Modo unidades (producto hijo) ──
        final conversion = _conversion;
        final esModoUnidades = _modoUnidades && conversion != null;
        final factor =
            num.tryParse('${conversion?['factor_conversion'] ?? 0}') ?? 0;
        final unidadHijo =
            '${conversion?['unidad_destino_nombre'] ?? 'unidades'}';
        final filaHijoOrigen = _filaHijoEn(widget.almacenOrigenId);
        final filaHijoDestino = _filaHijoEn(_destinoId);
        final sueltas = _sueltasDelHijo(
          filaHijoOrigen,
          registro?['sector'] as String?,
        );
        final sueltasUsables = _usarSueltas ? sueltas : 0;
        final faltante = (valor - sueltasUsables) > 0
            ? valor - sueltasUsables
            : 0;
        final paquetesAbrir = faltante > 0 && factor > 0
            ? (faltante / factor - 1e-9).ceil()
            : 0;
        final sueltasTrasAbrir = sueltas + paquetesAbrir * factor;
        final cocienteCerrado = factor > 0 ? valor / factor : 0;
        final paquetesCerrados =
            valor > 0 && cocienteCerrado == cocienteCerrado.roundToDouble()
            ? cocienteCerrado.toInt()
            : 0;

        // ── Validaciones (las mismas de la web) ──
        String? error;
        if (valor > 0) {
          if (esModoUnidades) {
            if (filaHijoOrigen?['es_fraccionado'] == false &&
                valor != valor.roundToDouble()) {
              error =
                  '${conversion['producto_hijo_nombre'] ?? 'El producto hijo'} solo admite cantidades enteras.';
            } else if (paquetesAbrir > disponible) {
              error =
                  'Se necesitan $paquetesAbrir $unidadPaquete y solo hay ${formatearCantidad(disponible)} disponible(s).';
            }
          } else if (valor > disponible) {
            error = 'Supera el disponible (${formatearCantidad(disponible)}).';
          } else if (!esFraccionado && valor != valor.roundToDouble()) {
            error = 'Este producto no es fraccionado: solo cantidades enteras.';
          }
        }
        final puedeGuardar =
            registro != null &&
            destino != null &&
            valor > 0 &&
            error == null &&
            !_guardando &&
            !(esModoUnidades && _cargandoHijo);

        final nombreOrigen = '${origen['almacen'] ?? 'Origen'}';
        final nombreDestino = '${destino?['nombre'] ?? 'Destino'}';

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '🔁 Transferir',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '#${origen['id']} ${origen['nombre']}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (registros.isEmpty)
                  Text(
                    'Este producto no tiene stock disponible en $nombreOrigen.',
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                else ...[
                  if (_hijos.isNotEmpty) ...[
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text('En $unidadPaquete'),
                        ),
                        const ButtonSegment(
                          value: true,
                          label: Text('En unidades'),
                        ),
                      ],
                      selected: {_modoUnidades},
                      onSelectionChanged: (s) => _cambiarModo(s.first),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: _registroId,
                    isExpanded: true,
                    decoration: decoracionCampo(
                      'Desde (lote / sector)',
                      compacta: true,
                    ),
                    items: [
                      for (final r in registros)
                        DropdownMenuItem(
                          value: r['id'] as int,
                          child: Text(
                            [
                                  r['sector'] ?? 'Sin sector',
                                  if (r['lote'] != null) 'Lote ${r['lote']}',
                                  if (r['fecha_vencimiento'] != null)
                                    'Vence ${r['fecha_vencimiento']}',
                                ].join(' · ') +
                                ' — Disp: ${formatearCantidad(r['cantidad_disponible'])}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _registroId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _destinoId,
                    isExpanded: true,
                    decoration: decoracionCampo(
                      'Hacia (almacén destino)',
                      compacta: true,
                    ),
                    items: [
                      for (final a in _destinos)
                        DropdownMenuItem(
                          value: a['id'] as int,
                          child: Row(
                            children: [
                              Icon(
                                iconoAlmacen(a['nombre']),
                                size: 18,
                                color: colorAlmacen(a['nombre']),
                              ),
                              const SizedBox(width: 8),
                              Text('${a['nombre']}'),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _destinoId = v),
                  ),
                  if (esModoUnidades) ...[
                    const SizedBox(height: 12),
                    if (_hijos.length > 1)
                      DropdownButtonFormField<int>(
                        initialValue: _conversionId,
                        isExpanded: true,
                        decoration: decoracionCampo(
                          'Producto hijo',
                          compacta: true,
                        ),
                        items: [
                          for (final c in _hijos)
                            DropdownMenuItem(
                              value: c['id'] as int,
                              child: Text(
                                '${c['producto_hijo_nombre'] ?? 'Hijo'} (x${formatearCantidad(c['factor_conversion'])})',
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _conversionId = v);
                          final hijoId =
                              _conversion?['producto_hijo_id'] as int?;
                          if (hijoId != null) _cargarHijo(hijoId);
                        },
                      )
                    else
                      Text(
                        '👶 ${conversion['producto_hijo_nombre'] ?? 'Producto hijo'} · '
                        '1 $unidadPaquete = ${formatearCantidad(factor)} $unidadHijo',
                        style: theme.textTheme.bodySmall,
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usar primero las unidades sueltas'),
                      subtitle: Text(
                        _cargandoHijo
                            ? 'Cargando…'
                            : 'Sueltas en $nombreOrigen: ${formatearCantidad(sueltas)} $unidadHijo',
                      ),
                      value: _usarSueltas,
                      onChanged: (v) => setState(() => _usarSueltas = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  CampoTexto(
                    controller: _cantidadController,
                    label: esModoUnidades
                        ? 'Cantidad ($unidadHijo)'
                        : 'Cantidad ($unidadPaquete)',
                    hint: 'Ej: 3',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    compacta: true,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (esModoUnidades &&
                      error == null &&
                      paquetesCerrados > 0 &&
                      paquetesCerrados <= disponible)
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () {
                        _cambiarModo(false);
                        _cantidadController.text = '$paquetesCerrados';
                      },
                      child: Text(
                        '💡 ${formatearCantidad(valor)} $unidadHijo = $paquetesCerrados '
                        '$unidadPaquete completo(s). ¿Transferir el $unidadPaquete cerrado?',
                      ),
                    ),
                  if (valor > 0 &&
                      registro != null &&
                      destino != null &&
                      error == null) ...[
                    const SizedBox(height: 12),
                    _VistaPrevia(
                      lineas: esModoUnidades
                          ? [
                              paquetesAbrir > 0
                                  ? '1. Abrir $paquetesAbrir $unidadPaquete en $nombreOrigen: '
                                        '${formatearCantidad(disponible)} → ${formatearCantidad(disponible - paquetesAbrir)} $unidadPaquete'
                                  : 'No se abre ningún $unidadPaquete: se usan las sueltas.',
                              '${paquetesAbrir > 0 ? '2. ' : ''}Transferir ${formatearCantidad(valor)} $unidadHijo: '
                                  '$nombreOrigen ${formatearCantidad(sueltasTrasAbrir)} → ${formatearCantidad(sueltasTrasAbrir - valor)}'
                                  ' · $nombreDestino ${formatearCantidad(_stockEn(filaHijoDestino))} → '
                                  '${formatearCantidad(_stockEn(filaHijoDestino) + valor)}',
                            ]
                          : [
                              '$nombreOrigen: ${formatearCantidad(disponible)} → '
                                  '${formatearCantidad(disponible - valor)}  (−${formatearCantidad(valor)})',
                              '$nombreDestino: '
                                  '${formatearCantidad(_stockEn(widget.filasProducto.where((f) => f['almacen_id'] == _destinoId).firstOrNull))} → '
                                  '${formatearCantidad(_stockEn(widget.filasProducto.where((f) => f['almacen_id'] == _destinoId).firstOrNull) + valor)}'
                                  '  (+${formatearCantidad(valor)})',
                            ],
                    ),
                  ],
                ],
                if (_errorServidor != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorServidor!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _guardando
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: puedeGuardar ? _transferir : null,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.swap_horiz),
                        label: Text(
                          _guardando ? 'Transfiriendo…' : 'Transferir',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Recuadro "antes → después" de la operación.
class _VistaPrevia extends StatelessWidget {
  final List<String> lineas;

  const _VistaPrevia({required this.lineas});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lineas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
