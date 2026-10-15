import 'package:flutter/material.dart';

import '../../models/dropdown_option.dart';
import '../decoracion_campo.dart';

/// Formulario de stock por almacén: almacén, sector, cantidad, límites,
/// lote y vencimiento. El estado (selección y controladores) vive en la
/// pantalla; este widget solo lo muestra y avisa los cambios.
class StockFormCard extends StatelessWidget {
  final List<DropdownOption> almacenes;
  final List<Map<String, dynamic>> sectores; // del almacén seleccionado
  final int? almacenSeleccionado;
  final int? sectorSeleccionado;
  final ValueChanged<int?> onAlmacenChanged;
  final ValueChanged<int?> onSectorChanged;
  final TextEditingController cantidadController;
  final TextEditingController stockMinimoController;
  final TextEditingController stockMaximoController;
  final TextEditingController loteController;
  final TextEditingController fechaVencimientoController;
  final VoidCallback onElegirFecha;

  const StockFormCard({
    super.key,
    required this.almacenes,
    required this.sectores,
    required this.almacenSeleccionado,
    required this.sectorSeleccionado,
    required this.onAlmacenChanged,
    required this.onSectorChanged,
    required this.cantidadController,
    required this.stockMinimoController,
    required this.stockMaximoController,
    required this.loteController,
    required this.fechaVencimientoController,
    required this.onElegirFecha,
  });

  @override
  Widget build(BuildContext context) {
    final almacenValido = almacenes.any((a) => a.id == almacenSeleccionado);
    final sectorValido = sectores.any((s) => s['id'] == sectorSeleccionado);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Stock por Almacén',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  // La key recrea el campo cuando la selección o los items
                  // cambian desde código (initialValue solo se lee al crearlo)
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(
                      'almacen-$almacenSeleccionado-${almacenes.length}',
                    ),
                    initialValue: almacenValido ? almacenSeleccionado : null,
                    decoration: decoracionCampo('📦 Almacén *', compacta: true),
                    items: [
                      for (final almacen in almacenes)
                        DropdownMenuItem(
                          value: almacen.id,
                          child: Text(almacen.nombre),
                        ),
                    ],
                    onChanged: onAlmacenChanged,
                    hint: const Text('Selecciona almacén'),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: almacenSeleccionado == null
                      ? TextField(
                          decoration: decoracionCampo(
                            '🏢 Sector',
                            hint: 'Selecciona almacén primero',
                            enabled: false,
                            compacta: true,
                          ),
                        )
                      : DropdownButtonFormField<int>(
                          key: ValueKey(
                            'sector-$almacenSeleccionado-$sectorSeleccionado',
                          ),
                          initialValue: sectorValido
                              ? sectorSeleccionado
                              : null,
                          decoration: decoracionCampo(
                            '🏢 Sector *',
                            compacta: true,
                          ),
                          items: [
                            for (final sector in sectores)
                              DropdownMenuItem<int>(
                                value: sector['id'] as int,
                                child: Text(sector['nombre'] as String),
                              ),
                          ],
                          onChanged: onSectorChanged,
                          hint: const Text('Selecciona sector'),
                          isExpanded: true,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            TextField(
              controller: cantidadController,
              decoration: decoracionCampo(
                '📊 Cantidad *',
                prefixIcon: const Icon(Icons.shopping_cart),
                compacta: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: stockMinimoController,
                    decoration: decoracionCampo('⬇️ Stock Mín', compacta: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: stockMaximoController,
                    decoration: decoracionCampo('⬆️ Stock Máx', compacta: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: loteController,
                    decoration: decoracionCampo(
                      '🏷️ Lote (Opcional)',
                      compacta: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: fechaVencimientoController,
                    readOnly: true,
                    decoration: decoracionCampo(
                      '📅 Vencimiento',
                      hint: 'YYYY-MM-DD',
                      compacta: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: onElegirFecha,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
