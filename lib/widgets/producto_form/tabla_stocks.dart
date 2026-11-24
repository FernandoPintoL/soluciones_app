import 'package:flutter/material.dart';

import '../../config/colores_app.dart';

/// Stock del producto por almacén y sector, en tarjetas. Arriba, un resumen por
/// almacén con el total y su estado frente al mínimo. Cada fila se edita o elimina
/// con su índice; tocar la tarjeta también la edita.
class TablaStocks extends StatelessWidget {
  final List<Map<String, dynamic>> stocks;
  final ValueChanged<int> onEditar;
  final ValueChanged<int> onEliminar;

  const TablaStocks({
    super.key,
    required this.stocks,
    required this.onEditar,
    required this.onEliminar,
  });

  static double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? 0}') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final resumen = <String, ({double cantidad, double minimo})>{};
    for (final s in stocks) {
      final nombre = (s['almacen_nombre'] ?? 'Almacén').toString();
      final previo = resumen[nombre];
      resumen[nombre] = (
        cantidad: (previo?.cantidad ?? 0) + _n(s['cantidad']),
        minimo: (previo?.minimo ?? 0) + _n(s['stock_minimo']),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (resumen.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in resumen.entries)
                _chipAlmacen(context, e.key, e.value.cantidad, e.value.minimo),
            ],
          ),
        if (resumen.isNotEmpty) const SizedBox(height: 12),
        for (final (idx, stock) in stocks.indexed)
          _tarjetaStock(context, idx, stock),
      ],
    );
  }

  /// Total del almacén: rojo sin stock, naranja bajo el mínimo, verde en buen nivel.
  Widget _chipAlmacen(
    BuildContext context,
    String almacen,
    double cantidad,
    double minimo,
  ) {
    final estado = AppColores.estado(context);
    final color = cantidad <= 0
        ? estado.rojo
        : (minimo > 0 && cantidad < minimo ? estado.naranja : estado.verde);
    return _chip(
      context,
      '$almacen · ${cantidad.toStringAsFixed(0)}'
      '${minimo > 0 ? ' / mín ${minimo.toStringAsFixed(0)}' : ''}',
      color,
      icono: Icons.warehouse_outlined,
    );
  }

  Widget _tarjetaStock(
    BuildContext context,
    int idx,
    Map<String, dynamic> stock,
  ) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final estado = AppColores.estado(context);
    final nuevo = stock['id'] == null;
    final cantidad = _n(stock['cantidad']);
    final minimo = _n(stock['stock_minimo']);
    final maximo = _n(stock['stock_maximo']);
    final lote = stock['lote']?.toString();
    final vence = stock['fecha_vencimiento']?.toString();
    final colorCantidad = cantidad <= 0
        ? estado.rojo
        : (minimo > 0 && cantidad < minimo ? estado.naranja : estado.verde);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onEditar(idx),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: colores.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${stock['almacen_nombre'] ?? 'Almacén'} · '
                      '${stock['sector_nombre'] ?? 'Sector'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (nuevo) _chip(context, 'Nuevo', estado.naranja),
                  IconButton(
                    tooltip: 'Editar',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.edit_outlined, color: estado.azul),
                    onPressed: () => onEditar(idx),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, color: colores.error),
                    onPressed: () => onEliminar(idx),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(
                    context,
                    'Cantidad ${cantidad.toStringAsFixed(0)}',
                    colorCantidad,
                  ),
                  _chip(
                    context,
                    'Mín ${minimo.toStringAsFixed(0)}',
                    colores.onSurfaceVariant,
                  ),
                  if (maximo > 0)
                    _chip(
                      context,
                      'Máx ${maximo.toStringAsFixed(0)}',
                      colores.onSurfaceVariant,
                    ),
                  if (lote != null && lote.isNotEmpty)
                    _chip(
                      context,
                      'Lote $lote',
                      colores.onSurfaceVariant,
                      icono: Icons.tag,
                    ),
                  if (vence != null && vence.isNotEmpty)
                    _chip(
                      context,
                      'Vence $vence',
                      _colorVencimiento(vence, estado),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vencido: rojo; vence en 30 días: naranja; si no, verde.
  Color _colorVencimiento(String fecha, EstadoColores estado) {
    final f = DateTime.tryParse(fecha);
    if (f == null) return estado.verde;
    final dias = f.difference(DateTime.now()).inDays;
    if (dias < 0) return estado.rojo;
    if (dias <= 30) return estado.naranja;
    return estado.verde;
  }

  Widget _chip(
    BuildContext context,
    String texto,
    Color color, {
    IconData? icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
