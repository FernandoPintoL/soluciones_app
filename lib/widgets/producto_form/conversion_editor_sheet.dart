import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dropdown_option.dart';
import '../../providers/dropdown_provider.dart';
import '../../services/service_locator.dart';
import '../campo_formulario.dart';
import '../search_select_field.dart';

/// "1 KG" / "Kilogramo (KG)" a partir del id de unidad.
String etiquetaUnidad(
  List<DropdownOption> unidades,
  int? id, {
  bool corta = false,
}) {
  final u = unidades.where((u) => u.id == id).firstOrNull;
  if (u == null) return id == null ? '-' : 'Unidad #$id';
  if (corta) return u.codigo ?? u.nombre;
  return u.codigo != null ? '${u.nombre} (${u.codigo})' : u.nombre;
}

/// Factor sin decimales innecesarios: 1000.0 → "1000", 0.25 → "0.25".
String formatearFactor(dynamic factor) {
  final n = num.tryParse(factor.toString());
  if (n == null) return factor.toString();
  if (n == n.roundToDouble()) return n.toInt().toString();
  return double.parse(n.toStringAsFixed(4)).toString();
}

/// Bottom sheet para agregar o editar una conversión de unidad
/// (fraccionamiento): 1 [unidadBaseId] = factor × unidad destino, opcionalmente
/// asociada a un producto hijo.
///
/// Usar con [ConversionEditorSheet.mostrar]: devuelve la conversión o null
/// si se cancela. Replica las validaciones del formulario web.
class ConversionEditorSheet extends StatefulWidget {
  final int unidadBaseId;
  final int? productoId; // para no permitir fraccionar el producto en sí mismo
  final List<Map<String, dynamic>> conversiones;
  final int? indiceEditando;

  const ConversionEditorSheet({
    super.key,
    required this.unidadBaseId,
    required this.productoId,
    required this.conversiones,
    this.indiceEditando,
  });

  static Future<Map<String, dynamic>?> mostrar(
    BuildContext context, {
    required int unidadBaseId,
    required int? productoId,
    required List<Map<String, dynamic>> conversiones,
    int? indiceEditando,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ConversionEditorSheet(
        unidadBaseId: unidadBaseId,
        productoId: productoId,
        conversiones: conversiones,
        indiceEditando: indiceEditando,
      ),
    );
  }

  @override
  State<ConversionEditorSheet> createState() => _ConversionEditorSheetState();
}

class _ConversionEditorSheetState extends State<ConversionEditorSheet> {
  final _factorController = TextEditingController();
  final _nombreVentaController = TextEditingController();
  int? _unidadDestinoId;
  Map<String, dynamic>? _productoHijo; // {id, nombre, sku}
  bool _principal = false;
  bool _activo = true;
  String? _error;

  bool get _editando => widget.indiceEditando != null;

  @override
  void initState() {
    super.initState();
    final conv = _editando ? widget.conversiones[widget.indiceEditando!] : null;
    if (conv != null) {
      _unidadDestinoId = conv['unidad_destino_id'] as int?;
      _factorController.text = formatearFactor(conv['factor_conversion']);
      _nombreVentaController.text =
          conv['nombre_cuando_se_vende_como']?.toString() ?? '';
      _principal = conv['es_conversion_principal'] == true;
      _activo = conv['activo'] != false;
      if (conv['producto_destino_id'] != null) {
        _productoHijo =
            (conv['producto_destino'] as Map?)?.cast<String, dynamic>() ??
            {'id': conv['producto_destino_id']};
      }
    } else {
      // La primera conversión siempre es la principal
      _principal = widget.conversiones.isEmpty;
    }
  }

  @override
  void dispose() {
    _factorController.dispose();
    _nombreVentaController.dispose();
    super.dispose();
  }

  /// Al elegir unidad destino, sugiere el factor típico si el campo está vacío.
  Future<void> _onUnidadDestino(int? unidadId) async {
    setState(() => _unidadDestinoId = unidadId);
    if (unidadId == null || _factorController.text.trim().isNotEmpty) return;
    final factor = await apiService.factorConversionSugerido(
      widget.unidadBaseId,
      unidadId,
    );
    if (factor != null && mounted && _factorController.text.trim().isEmpty) {
      _factorController.text = formatearFactor(factor);
    }
  }

  void _onProductoHijo(Map<String, dynamic>? producto) {
    setState(() {
      _productoHijo = producto == null
          ? null
          : {
              'id': producto['id'],
              'nombre': producto['nombre'],
              'sku': producto['sku'],
            };
      // Igual que la web: el producto hijo define unidad destino y nombre
      if (producto != null) {
        _nombreVentaController.text = producto['nombre']?.toString() ?? '';
      }
    });
    final unidadHijo = producto?['unidad_medida_id'] as int?;
    if (unidadHijo != null) _onUnidadDestino(unidadHijo);
  }

  void _aceptar(List<DropdownOption> unidades) {
    final factor = double.tryParse(
      _factorController.text.trim().replaceAll(',', '.'),
    );

    String? error;
    if (_unidadDestinoId == null) {
      error = 'Selecciona la unidad destino';
    } else if (_unidadDestinoId == widget.unidadBaseId) {
      error = 'La unidad base y destino deben ser diferentes';
    } else if (factor == null || factor <= 0) {
      error = 'El factor de conversión debe ser mayor a 0';
    } else if (_productoHijo != null &&
        _productoHijo!['id'] == widget.productoId) {
      error = 'Un producto no puede fraccionarse en sí mismo';
    } else if (widget.conversiones.indexed.any(
      (e) =>
          e.$1 != widget.indiceEditando &&
          e.$2['unidad_destino_id'] == _unidadDestinoId,
    )) {
      error = 'Ya existe una conversión a esa unidad';
    } else if (!_principal &&
        !widget.conversiones.indexed.any(
          (e) =>
              e.$1 != widget.indiceEditando &&
              e.$2['es_conversion_principal'] == true,
        )) {
      error = 'Debe haber una conversión principal: marca esta como principal';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final destino = unidades.where((u) => u.id == _unidadDestinoId).firstOrNull;
    final nombreVenta = _nombreVentaController.text.trim();
    Navigator.pop(context, <String, dynamic>{
      'unidad_base_id': widget.unidadBaseId,
      'unidad_destino_id': _unidadDestinoId,
      'producto_destino_id': _productoHijo?['id'],
      'factor_conversion': factor,
      'nombre_cuando_se_vende_como': nombreVenta.isEmpty ? null : nombreVenta,
      'activo': _activo,
      'es_conversion_principal': _principal,
      // Solo para mostrar en la lista
      'producto_destino': _productoHijo,
      'unidad_destino': destino == null
          ? null
          : {
              'id': destino.id,
              'nombre': destino.nombre,
              'codigo': destino.codigo,
            },
    });
  }

  @override
  Widget build(BuildContext context) {
    final unidades = context.watch<DropdownProvider>().unidades;
    final theme = Theme.of(context);
    final base = etiquetaUnidad(unidades, widget.unidadBaseId);
    final baseCorta = etiquetaUnidad(
      unidades,
      widget.unidadBaseId,
      corta: true,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editando ? 'Editar fraccionamiento' : 'Nuevo fraccionamiento',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ej: si compras en CAJAS y vendes en UNIDADES: 1 CAJA = 12 UN',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: decoracionCampo(
                'Unidad base (almacenamiento)',
                compacta: true,
                enabled: false,
              ),
              child: Text(base),
            ),
            const SizedBox(height: 12),
            _BuscadorProductoHijo(
              seleccionado: _productoHijo,
              onSeleccionar: _onProductoHijo,
            ),
            const SizedBox(height: 12),
            SearchSelectField(
              value: _unidadDestinoId,
              labelText: 'Unidad destino *',
              hintText: 'Buscar unidad...',
              items: [
                for (final u in unidades)
                  if (u.id != widget.unidadBaseId)
                    SearchSelectOption(
                      id: u.id,
                      nombre: u.codigo != null
                          ? '${u.nombre} (${u.codigo})'
                          : u.nombre,
                    ),
              ],
              onChanged: _onUnidadDestino,
            ),
            const SizedBox(height: 12),
            CampoTexto(
              controller: _factorController,
              label: 'Factor de conversión *',
              hint: 'Ej: 12',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              compacta: true,
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _factorController,
              builder: (context, valor, _) {
                final destino = _unidadDestinoId == null
                    ? '...'
                    : etiquetaUnidad(unidades, _unidadDestinoId, corta: true);
                final factor = valor.text.trim().isEmpty
                    ? '?'
                    : valor.text.trim();
                return Text(
                  '1 $baseCorta = $factor $destino',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            CampoTexto(
              controller: _nombreVentaController,
              label: 'Nombre cuando se vende en esta unidad',
              hint: 'Vacío = automático',
              compacta: true,
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('⭐ Conversión principal'),
              subtitle: const Text('La que se usa por defecto en ventas'),
              value: _principal,
              onChanged: (v) => setState(() => _principal = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activa'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
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
                    onPressed: () => _aceptar(unidades),
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

/// Búsqueda en el servidor del producto hijo (por ID, SKU, nombre o código).
class _BuscadorProductoHijo extends StatefulWidget {
  final Map<String, dynamic>? seleccionado;
  final ValueChanged<Map<String, dynamic>?> onSeleccionar;

  const _BuscadorProductoHijo({
    required this.seleccionado,
    required this.onSeleccionar,
  });

  @override
  State<_BuscadorProductoHijo> createState() => _BuscadorProductoHijoState();
}

class _BuscadorProductoHijoState extends State<_BuscadorProductoHijo> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  Timer? _debounce;
  int _busquedaActual = 0; // descarta respuestas que llegan tarde

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTexto(String texto) {
    _debounce?.cancel();
    final busqueda = ++_busquedaActual;
    if (texto.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _buscando = false;
      });
      return;
    }
    setState(() => _buscando = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await apiService.buscarProductosParaFraccionar(texto.trim());
        if (mounted && busqueda == _busquedaActual) {
          setState(() => _resultados = r);
        }
      } catch (e) {
        debugPrint('[ConversionEditor] Error buscando productos: $e');
      } finally {
        if (mounted && busqueda == _busquedaActual) {
          setState(() => _buscando = false);
        }
      }
    });
  }

  static String _etiqueta(Map<String, dynamic> p) {
    final sku = p['sku'];
    final nombre = p['nombre'] ?? '';
    return '#${p['id']}${sku != null && sku.toString().isNotEmpty ? ' · $sku' : ''} - $nombre';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sel = widget.seleccionado;

    if (sel != null) {
      return InputDecorator(
        decoration: decoracionCampo(
          '👶 Producto hijo (opcional)',
          compacta: true,
          completado: true,
          suffixIcon: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Quitar producto hijo',
            onPressed: () => widget.onSeleccionar(null),
          ),
        ),
        child: Text(
          sel['nombre'] != null ? _etiqueta(sel) : 'Producto #${sel['id']}',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onTexto,
          decoration: decoracionCampo(
            '👶 Producto hijo (opcional)',
            hint: 'Busca por ID, SKU, código o nombre',
            prefixIcon: const Icon(Icons.search),
            compacta: true,
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_resultados.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _resultados.length,
              itemBuilder: (context, i) {
                final p = _resultados[i];
                return ListTile(
                  dense: true,
                  title: Text(_etiqueta(p)),
                  subtitle: Text(p['unidad_nombre']?.toString() ?? ''),
                  onTap: () {
                    _controller.clear();
                    setState(() => _resultados = []);
                    widget.onSeleccionar(p);
                  },
                );
              },
            ),
          )
        else if (!_buscando && _controller.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Sin coincidencias. Intenta otro término.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
