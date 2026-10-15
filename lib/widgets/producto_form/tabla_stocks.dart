import 'package:flutter/material.dart';

/// Tabla de los stocks agregados al producto, con acciones editar/eliminar
/// por fila (reciben el índice de la fila).
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stocks Agregados (${stocks.length})',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Almacén')),
                DataColumn(label: Text('Sector')),
                DataColumn(label: Text('Cantidad')),
                DataColumn(label: Text('Stock Mín')),
                DataColumn(label: Text('Stock Máx')),
                DataColumn(label: Text('Lote')),
                DataColumn(label: Text('Vencimiento')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: [
                for (final (idx, stock) in stocks.indexed)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          stock['id'] != null ? '#${stock['id']}' : 'Nuevo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: stock['id'] != null
                                ? scheme.primary
                                : Colors.orange,
                          ),
                        ),
                      ),
                      DataCell(Text(stock['almacen_nombre'] ?? '')),
                      DataCell(Text(stock['sector_nombre'] ?? '')),
                      DataCell(Text(stock['cantidad'].toString())),
                      DataCell(Text((stock['stock_minimo'] ?? 0).toString())),
                      DataCell(Text((stock['stock_maximo'] ?? 0).toString())),
                      DataCell(Text(stock['lote']?.toString() ?? '-')),
                      DataCell(
                        Text(stock['fecha_vencimiento']?.toString() ?? '-'),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.blue,
                              onPressed: () => onEditar(idx),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: scheme.error,
                              onPressed: () => onEliminar(idx),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
