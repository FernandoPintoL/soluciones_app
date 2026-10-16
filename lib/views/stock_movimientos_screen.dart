import 'dart:async';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../widgets/app_drawer.dart';
import '../widgets/colores_almacen.dart';
import '../widgets/inventario/abrir_edicion_producto.dart';
import '../widgets/inventario/fraccionar_sheet.dart';
import '../widgets/inventario/transferir_sheet.dart';

/// Stock de cada producto por almacén, con las acciones de Actualizar Stock
/// Masivo (web): transferir entre almacenes y fraccionar en el producto hijo.
class StockMovimientosScreen extends StatefulWidget {
  const StockMovimientosScreen({super.key});

  @override
  State<StockMovimientosScreen> createState() => _StockMovimientosScreenState();
}

class _StockMovimientosScreenState extends State<StockMovimientosScreen> {
  final _buscarController = TextEditingController();
  Timer? _debounce;
  int _busquedaActual = 0; // descarta respuestas que llegan tarde

  List<Map<String, dynamic>> _filas = [];
  List<Map<String, dynamic>> _almacenes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscarController.dispose();
    super.dispose();
  }

  void _onBuscar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _cargar);
  }

  Future<void> _cargar() async {
    final busqueda = ++_busquedaActual;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await apiService.getProductosStock(
        search: _buscarController.text,
      );
      if (!mounted || busqueda != _busquedaActual) return;
      setState(() {
        _filas = r['filas'] ?? [];
        _almacenes = r['almacenes'] ?? [];
      });
    } catch (e) {
      if (mounted && busqueda == _busquedaActual) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && busqueda == _busquedaActual) {
        setState(() => _cargando = false);
      }
    }
  }

  /// Filas agrupadas por producto, conservando el orden del backend (nombre).
  List<List<Map<String, dynamic>>> get _productos {
    final grupos = <int, List<Map<String, dynamic>>>{};
    for (final f in _filas) {
      grupos.putIfAbsent(f['id'] as int, () => []).add(f);
    }
    return grupos.values.toList();
  }

  void _resultado(String? mensaje) {
    if (mensaje == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $mensaje'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
    _cargar();
  }

  Future<void> _transferir(
    List<Map<String, dynamic>> filas,
    Map<String, dynamic> fila,
  ) async {
    final mensaje = await TransferirSheet.mostrar(
      context,
      filasProducto: filas,
      almacenOrigenId: fila['almacen_id'] as int,
      almacenes: _almacenes,
    );
    _resultado(mensaje);
  }

  Future<void> _editar(Map<String, dynamic> fila) async {
    await abrirEdicionProducto(context, fila['id'] as int);
    if (mounted) _cargar(); // pudo cambiar stock, nombre o conversiones
  }

  Future<void> _fraccionar(Map<String, dynamic> fila) async {
    _resultado(await FraccionarSheet.mostrar(context, fila: fila));
  }

  @override
  Widget build(BuildContext context) {
    final productos = _productos;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock y movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'stock'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _buscarController,
                onChanged: _onBuscar,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por ID, nombre, SKU o código de barras',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_cargando) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargar,
                child: _error != null && _filas.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        ],
                      )
                    : productos.isEmpty && !_cargando
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text('Sin productos para esa búsqueda.'),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: productos.length,
                        itemBuilder: (context, i) => _ProductoStockCard(
                          filas: productos[i],
                          hayOtrosAlmacenes: _almacenes.length > 1,
                          onTransferir: (fila) =>
                              _transferir(productos[i], fila),
                          onFraccionar: _fraccionar,
                          onEditar: () => _editar(productos[i].first),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductoStockCard extends StatelessWidget {
  final List<Map<String, dynamic>> filas; // una por almacén
  final bool hayOtrosAlmacenes;
  final ValueChanged<Map<String, dynamic>> onTransferir;
  final ValueChanged<Map<String, dynamic>> onFraccionar;
  final VoidCallback onEditar;

  const _ProductoStockCard({
    required this.filas,
    required this.hayOtrosAlmacenes,
    required this.onTransferir,
    required this.onFraccionar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = filas.first;
    final fraccionable =
        p['es_fraccionado'] == true &&
        (p['conversiones'] as List? ?? const []).any(
          (c) => c['producto_hijo_id'] != null,
        );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tocar la tarjeta abre la edición del producto
        onTap: onEditar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${p['id']}',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          TextSpan(text: '  ${p['nombre']}'),
                        ],
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (p['sku'] != null) p['sku'],
                  p['unidad_nombre'],
                  if (fraccionable) '✂️ fraccionable',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              for (final fila in filas)
                _FilaAlmacen(
                  fila: fila,
                  puedeTransferir: hayOtrosAlmacenes,
                  puedeFraccionar: fraccionable,
                  onTransferir: () => onTransferir(fila),
                  onFraccionar: () => onFraccionar(fila),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaAlmacen extends StatelessWidget {
  final Map<String, dynamic> fila;
  final bool puedeTransferir;
  final bool puedeFraccionar;
  final VoidCallback onTransferir;
  final VoidCallback onFraccionar;

  const _FilaAlmacen({
    required this.fila,
    required this.puedeTransferir,
    required this.puedeFraccionar,
    required this.onTransferir,
    required this.onFraccionar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = '${fila['almacen'] ?? 'Almacén'}';
    final color = colorAlmacen(nombre);
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final tono = oscuro ? color.shade200 : color.shade800;
    final stocks = (fila['stocks'] as List? ?? const []);
    final disponible = stocks.fold<num>(
      0,
      (s, r) => s + (num.tryParse('${r['cantidad_disponible']}') ?? 0),
    );
    final hayStock = disponible > 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: oscuro ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(iconoAlmacen(nombre), size: 16, color: tono),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nombre: ${formatearCantidad(fila['cantidad_total'])}',
                  style: TextStyle(color: tono, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${fila['sector']}'
                  '${stocks.length > 1 ? ' · ${stocks.length} lotes' : ''}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: tono),
                ),
              ],
            ),
          ),
          if (puedeTransferir)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Transferir',
              color: tono,
              onPressed: hayStock ? onTransferir : null,
            ),
          if (puedeFraccionar)
            IconButton(
              icon: const Icon(Icons.call_split),
              tooltip: 'Fraccionar',
              color: tono,
              onPressed: hayStock ? onFraccionar : null,
            ),
        ],
      ),
    );
  }
}
