import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/dropdown_provider.dart';
import '../campo_formulario.dart';

/// Bottom sheet para agregar o editar una fila de stock (almacén, sector,
/// cantidad, límites, lote y vencimiento).
///
/// Usar con [StockEditorSheet.mostrar]: devuelve la fila lista para la tabla,
/// o null si el usuario cancela. Al editar se conserva el `id` de la fila.
class StockEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? stockInicial;

  const StockEditorSheet({super.key, this.stockInicial});

  static Future<Map<String, dynamic>?> mostrar(
    BuildContext context, {
    Map<String, dynamic>? stockInicial,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => StockEditorSheet(stockInicial: stockInicial),
    );
  }

  @override
  State<StockEditorSheet> createState() => _StockEditorSheetState();
}

class _StockEditorSheetState extends State<StockEditorSheet> {
  final _cantidadController = TextEditingController();
  final _stockMinimoController = TextEditingController();
  final _stockMaximoController = TextEditingController();
  final _loteController = TextEditingController();
  final _fechaController = TextEditingController();
  int? _almacenId;
  int? _sectorId;
  DateTime? _fechaVencimiento;
  String? _error;

  bool get _editando => widget.stockInicial != null;

  @override
  void initState() {
    super.initState();
    final stock = widget.stockInicial;
    if (stock != null) {
      final fecha = stock['fecha_vencimiento']?.toString() ?? '';
      _almacenId = stock['almacen_id'] as int?;
      _sectorId = stock['sector_id'] as int?;
      _cantidadController.text = (stock['cantidad'] ?? '').toString();
      _stockMinimoController.text = (stock['stock_minimo'] ?? 0).toString();
      _stockMaximoController.text = (stock['stock_maximo'] ?? 0).toString();
      _loteController.text = stock['lote']?.toString() ?? '';
      _fechaController.text = fecha;
      _fechaVencimiento = DateTime.tryParse(fecha);
    } else {
      _cantidadController.text = '0';
      _preseleccionarAlmacenYSector(context.read<DropdownProvider>());
    }
  }

  @override
  void dispose() {
    for (final c in [
      _cantidadController,
      _stockMinimoController,
      _stockMaximoController,
      _loteController,
      _fechaController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fila nueva: "Almacén Principal" (o el primero) y su primer sector.
  void _preseleccionarAlmacenYSector(DropdownProvider dropdownProvider) {
    final almacenes = dropdownProvider.almacenes;
    if (almacenes.isEmpty) return;
    _almacenId = almacenes
        .firstWhere(
          (a) =>
              a.nombre.toLowerCase().contains('principal') ||
              a.nombre.toLowerCase().contains('almacen'),
          orElse: () => almacenes.first,
        )
        .id;
    final sectores = dropdownProvider.getSectoresPorAlmacen(_almacenId!);
    if (sectores.isNotEmpty) _sectorId = sectores.first['id'] as int;
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fechaVencimiento = picked;
        _fechaController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _aceptar(DropdownProvider dropdownProvider) {
    // Cantidad vacía = 0: se permite crear el lote sin stock
    final textoCantidad = _cantidadController.text.trim();
    final cantidad = textoCantidad.isEmpty ? 0 : int.tryParse(textoCantidad);
    final stockMinimo = int.tryParse(_stockMinimoController.text) ?? 0;
    final stockMaximo = int.tryParse(_stockMaximoController.text) ?? 0;

    String? error;
    if (_almacenId == null || _sectorId == null) {
      error = 'Selecciona almacén y sector';
    } else if (cantidad == null || cantidad < 0) {
      error = 'Ingresa una cantidad válida';
    } else if (stockMinimo < 0 || stockMaximo < 0) {
      error = 'Stock mínimo y máximo no pueden ser negativos';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final almacenNombre = dropdownProvider.almacenes
        .where((a) => a.id == _almacenId)
        .map((a) => a.nombre)
        .firstOrNull;
    final sectorNombre = dropdownProvider
        .getSectoresPorAlmacen(_almacenId!)
        .where((s) => s['id'] == _sectorId)
        .map((s) => s['nombre'])
        .firstOrNull;
    final id = widget.stockInicial?['id'];

    Navigator.pop(context, <String, dynamic>{
      if (id != null) 'id': id,
      'almacen_id': _almacenId,
      'sector_id': _sectorId,
      'cantidad': cantidad,
      'stock_minimo': stockMinimo,
      'stock_maximo': stockMaximo,
      'lote': _loteController.text.isNotEmpty ? _loteController.text : null,
      'fecha_vencimiento': _fechaController.text.isNotEmpty
          ? _fechaController.text
          : null,
      'almacen_nombre': almacenNombre ?? 'Almacén $_almacenId',
      'sector_nombre': sectorNombre ?? 'Sector $_sectorId',
    });
  }

  @override
  Widget build(BuildContext context) {
    final dropdownProvider = context.watch<DropdownProvider>();
    final almacenes = dropdownProvider.almacenes;
    final sectores = _almacenId != null
        ? dropdownProvider.getSectoresPorAlmacen(_almacenId!)
        : const <Map<String, dynamic>>[];
    final almacenValido = almacenes.any((a) => a.id == _almacenId);
    final sectorValido = sectores.any((s) => s['id'] == _sectorId);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      // Sube el contenido cuando aparece el teclado
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editando ? 'Editar stock' : 'Agregar stock',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: almacenValido ? _almacenId : null,
                    decoration: decoracionCampo(
                      '📦 Almacén *',
                      compacta: true,
                      completado: almacenValido,
                    ),
                    items: [
                      for (final almacen in almacenes)
                        DropdownMenuItem(
                          value: almacen.id,
                          child: Text(almacen.nombre),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _almacenId = value;
                      _sectorId = null;
                    }),
                    hint: const Text('Selecciona almacén'),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // La key recrea el campo al cambiar de almacén
                  // (initialValue solo se lee al crearlo)
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('sector-$_almacenId'),
                    initialValue: sectorValido ? _sectorId : null,
                    decoration: decoracionCampo(
                      '🏢 Sector *',
                      compacta: true,
                      completado: sectorValido,
                    ),
                    items: [
                      for (final sector in sectores)
                        DropdownMenuItem<int>(
                          value: sector['id'] as int,
                          child: Text(sector['nombre'] as String),
                        ),
                    ],
                    onChanged: _almacenId == null
                        ? null
                        : (value) => setState(() => _sectorId = value),
                    hint: Text(
                      _almacenId == null
                          ? 'Selecciona almacén primero'
                          : 'Selecciona sector',
                    ),
                    isExpanded: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CampoTexto(
              controller: _cantidadController,
              label: '📊 Cantidad',
              hint: '0',
              prefixIcon: const Icon(Icons.shopping_cart),
              compacta: true,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CampoTexto(
                    controller: _stockMinimoController,
                    label: '⬇️ Stock Mín',
                    compacta: true,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CampoTexto(
                    controller: _stockMaximoController,
                    label: '⬆️ Stock Máx',
                    compacta: true,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CampoTexto(
                    controller: _loteController,
                    label: '🏷️ Lote (Opcional)',
                    compacta: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CampoTexto(
                    controller: _fechaController,
                    label: '📅 Vencimiento',
                    hint: 'YYYY-MM-DD',
                    compacta: true,
                    suffixIcon: const Icon(Icons.calendar_today),
                    readOnly: true,
                    onTap: _elegirFecha,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: () => _aceptar(dropdownProvider),
                    icon: Icon(_editando ? Icons.check : Icons.add),
                    label: Text(_editando ? 'Guardar cambios' : 'Agregar'),
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
  }
}
