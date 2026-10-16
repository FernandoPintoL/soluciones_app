import 'package:flutter/material.dart';

import '../../services/service_locator.dart';
import '../campo_formulario.dart';
import '../colores_almacen.dart';

/// Bottom sheet para fraccionar un producto padre en su producto hijo dentro
/// de una ubicación (almacén + sector). Replica el modal "Fraccionar" de la web;
/// la cantidad del hijo la calcula el backend con el factor de la conversión.
///
/// [fila] es la fila del producto en un almacén (respuesta de
/// `getProductosStock`). Devuelve el mensaje del backend o null si se cancela.
class FraccionarSheet extends StatefulWidget {
  final Map<String, dynamic> fila;

  const FraccionarSheet({super.key, required this.fila});

  static Future<String?> mostrar(
    BuildContext context, {
    required Map<String, dynamic> fila,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FraccionarSheet(fila: fila),
    );
  }

  @override
  State<FraccionarSheet> createState() => _FraccionarSheetState();
}

class _FraccionarSheetState extends State<FraccionarSheet> {
  final _cantidadController = TextEditingController();
  int? _conversionId;
  int? _stockId;
  bool _guardando = false;
  String? _errorServidor;

  List<Map<String, dynamic>> get _conversiones => [
    for (final c in (widget.fila['conversiones'] as List? ?? const []))
      if (c['producto_hijo_id'] != null) Map<String, dynamic>.from(c),
  ];

  /// Ubicaciones con sector y stock disponible (el fraccionamiento es por sector).
  List<Map<String, dynamic>> get _ubicaciones => [
    for (final s in (widget.fila['stocks'] as List? ?? const []))
      if (s['sector_id'] != null &&
          (num.tryParse('${s['cantidad_disponible']}') ?? 0) > 0)
        Map<String, dynamic>.from(s as Map),
  ];

  @override
  void initState() {
    super.initState();
    _conversionId = _conversiones.firstOrNull?['id'] as int?;
    final ubicaciones = [..._ubicaciones]
      ..sort(
        (a, b) => (num.tryParse('${b['cantidad_disponible']}') ?? 0).compareTo(
          num.tryParse('${a['cantidad_disponible']}') ?? 0,
        ),
      );
    _stockId = ubicaciones.firstOrNull?['id'] as int?;
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _fraccionar(Map<String, dynamic> ubicacion, num cantidad) async {
    setState(() {
      _guardando = true;
      _errorServidor = null;
    });
    try {
      final mensaje = await apiService.fraccionarProducto(
        productoPadreId: widget.fila['id'] as int,
        conversionId: _conversionId!,
        cantidadPadre: cantidad,
        almacenId: widget.fila['almacen_id'] as int,
        sectorId: ubicacion['sector_id'] as int,
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
    final fila = widget.fila;
    final conversiones = _conversiones;
    final ubicaciones = _ubicaciones;
    final conversion = conversiones
        .where((c) => c['id'] == _conversionId)
        .firstOrNull;
    final ubicacion = ubicaciones.where((u) => u['id'] == _stockId).firstOrNull;
    final unidadPadre = '${fila['unidad_nombre'] ?? ''}';
    final unidadHijo = '${conversion?['unidad_destino_nombre'] ?? 'unidades'}';
    final factor =
        num.tryParse('${conversion?['factor_conversion'] ?? 0}') ?? 0;
    final almacen = '${fila['almacen'] ?? ''}';

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _cantidadController,
      builder: (context, texto, _) {
        final cantidad = num.tryParse(texto.text.replaceAll(',', '.')) ?? 0;
        final disponible =
            num.tryParse('${ubicacion?['cantidad_disponible'] ?? 0}') ?? 0;
        final cantidadHijo = cantidad * factor;
        final excede = ubicacion != null && cantidad > disponible;
        final puedeGuardar =
            conversion != null &&
            ubicacion != null &&
            cantidad > 0 &&
            factor > 0 &&
            !excede &&
            !_guardando;

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
                  '✂️ Fraccionar',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      iconoAlmacen(almacen),
                      size: 16,
                      color: colorAlmacen(almacen),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '#${fila['id']} ${fila['nombre']} · $almacen',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (conversiones.isEmpty)
                  Text(
                    'Este producto no tiene conversiones a un producto hijo. '
                    'Configúralas en el formulario del producto (Fraccionamiento).',
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                else if (ubicaciones.isEmpty)
                  Text(
                    'No hay stock disponible con sector asignado en $almacen.',
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                else ...[
                  DropdownButtonFormField<int>(
                    initialValue: _conversionId,
                    isExpanded: true,
                    decoration: decoracionCampo(
                      'Fraccionar en',
                      compacta: true,
                    ),
                    items: [
                      for (final c in conversiones)
                        DropdownMenuItem(
                          value: c['id'] as int,
                          child: Text(
                            '👶 ${c['producto_hijo_nombre'] ?? 'Producto hijo'} '
                            '(1 $unidadPadre = ${formatearCantidad(c['factor_conversion'])} ${c['unidad_destino_nombre']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _conversionId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _stockId,
                    isExpanded: true,
                    decoration: decoracionCampo(
                      'Desde (sector / lote)',
                      compacta: true,
                    ),
                    items: [
                      for (final u in ubicaciones)
                        DropdownMenuItem(
                          value: u['id'] as int,
                          child: Text(
                            [
                                  u['sector'] ?? 'Sector',
                                  if (u['lote'] != null) 'Lote ${u['lote']}',
                                ].join(' · ') +
                                ' — Stock: ${formatearCantidad(u['cantidad_disponible'])} $unidadPadre',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _stockId = v),
                  ),
                  const SizedBox(height: 12),
                  CampoTexto(
                    controller: _cantidadController,
                    label: 'Cantidad a fraccionar ($unidadPadre)',
                    hint: 'Ej: 1',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    compacta: true,
                  ),
                  if (excede) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Supera el stock disponible en esta ubicación (${formatearCantidad(disponible)}).',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (cantidad > 0 &&
                      ubicacion != null &&
                      conversion != null &&
                      !excede) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unidadPadre: ${formatearCantidad(disponible)} → '
                            '${formatearCantidad(disponible - cantidad)}  (−${formatearCantidad(cantidad)})',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '${conversion['producto_hijo_nombre'] ?? 'Hijo'}: '
                            '+${formatearCantidad(cantidadHijo)} $unidadHijo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
                        onPressed: puedeGuardar
                            ? () => _fraccionar(ubicacion, cantidad)
                            : null,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.call_split),
                        label: Text(
                          _guardando ? 'Fraccionando…' : 'Fraccionar',
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
