import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colores_app.dart';
import '../models/producto.dart';
import '../providers/producto_provider.dart';
import '../widgets/app_drawer.dart';
import 'barcode_scanner_screen.dart';
import 'producto_form_screen.dart';

/// Listado de productos: búsqueda, escaneo de código, paginación al hacer scroll.
/// Cada tarjeta muestra stock (con color según el mínimo), precio, código de barras,
/// almacenes y vencimientos.
class ProductosListScreen extends StatefulWidget {
  const ProductosListScreen({super.key});

  @override
  State<ProductosListScreen> createState() => _ProductosListScreenState();
}

class _ProductosListScreenState extends State<ProductosListScreen> {
  final _buscarCtrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Cargar productos al iniciar
    Future.microtask(() {
      if (mounted) context.read<ProductoProvider>().getProductos();
    });
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Carga la siguiente página al acercarse al final de la lista.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.8) {
      final provider = context.read<ProductoProvider>();
      if (provider.hasMorePages && !provider.isLoading) {
        provider.loadMoreProductos();
      }
    }
  }

  void _volverArriba() {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _buscar(String valor) {
    final provider = context.read<ProductoProvider>();
    final busqueda = valor.trim().isEmpty
        ? provider.getProductos()
        : provider.searchProductos(valor);
    busqueda.then((_) => _volverArriba());
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || codigo.isEmpty || !mounted) return;
    _buscarCtrl.text = codigo;
    setState(() {});
    await context.read<ProductoProvider>().searchProductoByCodigoBarras(codigo);
    _volverArriba();
  }

  Future<void> _confirmarEliminar(int id) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este producto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppColores.estado(context).rojo),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final provider = context.read<ProductoProvider>();
    final ok = await provider.deleteProducto(id);
    if (!mounted) return;
    final colores = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Producto eliminado correctamente'
              : (provider.errorMessage ?? 'Error al eliminar'),
        ),
        backgroundColor: ok ? colores.secondary : colores.error,
      ),
    );
  }

  void _abrirFormulario([Producto? producto]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: producto)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ProductoProvider>().refresh().then(
              (_) => _volverArriba(),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'productos'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(child: _barraBusqueda()),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Escanear código de barras',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _escanear,
                ),
              ],
            ),
          ),
          Consumer<ProductoProvider>(
            builder: (context, provider, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  provider.paginationInfo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<ProductoProvider>(
              builder: (context, provider, _) => _lista(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraBusqueda() {
    return TextField(
      controller: _buscarCtrl,
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        setState(() {});
        _buscar(v);
      },
      decoration: InputDecoration(
        hintText: 'Buscar por nombre, SKU o código',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _buscarCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _buscarCtrl.clear();
                  setState(() {});
                  _buscar('');
                },
              ),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _lista(BuildContext context, ProductoProvider provider) {
    final colores = Theme.of(context).colorScheme;

    if (provider.isLoading && provider.productos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.productos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 56,
                color: AppColores.estado(context).rojo,
              ),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage ?? 'Error desconocido',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => provider.refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: colores.outline),
            const SizedBox(height: 12),
            Text(
              'No hay productos',
              style: TextStyle(color: colores.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final total = provider.productos.length;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: total + (provider.hasMorePages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == total) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: provider.isLoading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const SizedBox.shrink(),
            ),
          );
        }
        final producto = provider.productos[index];
        return _TarjetaProducto(
          producto: producto,
          onEditar: () => _abrirFormulario(producto),
          onEliminar: () => _confirmarEliminar(producto.id),
        );
      },
    );
  }
}

/// Tarjeta plana de producto.
class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _TarjetaProducto({
    required this.producto,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final estado = AppColores.estado(context);

    final stock = producto.stockTotal;
    final colorStock = stock <= 0
        ? estado.rojo
        : (producto.stockMinimo > 0 && stock < producto.stockMinimo
              ? estado.naranja
              : estado.verde);
    final vence = _proximaFechaVencimiento(producto);
    final lotes = _lotesProducto(producto);
    final almacenes = producto.stockLimites;
    // Todos los precios activos, con el nombre de su tipo (los de unidad se marcan)
    final precios = producto.preciosActivos.take(4).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEditar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imagen(colores),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            producto.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: colores.onSurfaceVariant,
                          ),
                          onSelected: (v) =>
                              v == 'editar' ? onEditar() : onEliminar(),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'eliminar',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: estado.rojo,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: estado.rojo),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '#${producto.id} · SKU ${producto.sku ?? 'N/A'}',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: colores.onSurfaceVariant,
                      ),
                    ),
                    if (producto.marcaNombre != null &&
                        producto.marcaNombre!.isNotEmpty)
                      Text(
                        producto.marcaNombre!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: colores.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip('Stock $stock', colorStock, context),
                        for (final p in precios)
                          _chip(
                            '${p.nombre}${p.porUnidad ? ' (unidad)' : ''} '
                            'Bs ${p.monto.toStringAsFixed(2)}',
                            p.porUnidad
                                ? colores.onSurfaceVariant
                                : colores.primary,
                            context,
                          ),
                        if (producto.tieneCodigoBarras)
                          _chip(
                            producto.codigosBarra!,
                            colores.onSurfaceVariant,
                            context,
                            icono: Icons.qr_code_2,
                          ),
                      ],
                    ),
                    if (almacenes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final sl in almacenes.take(2))
                            _chip(
                              '${sl['almacen_nombre'] ?? 'Almacén'} · ${sl['sector_nombre'] ?? 'Sector'}',
                              estado.azul,
                              context,
                              icono: Icons.warehouse_outlined,
                            ),
                          if (almacenes.length > 2)
                            Text(
                              '+${almacenes.length - 2}',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: colores.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (vence != null || lotes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (lotes.isNotEmpty) 'Lotes: $lotes',
                          if (vence != null) 'Vence: $vence',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: vence == null
                              ? colores.onSurfaceVariant
                              : (vence.contains('VENCIDO') ||
                                        vence.contains('HOY')
                                    ? estado.rojo
                                    : (_proximoVencer(producto)
                                          ? estado.naranja
                                          : estado.verde)),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagen(ColorScheme colores) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68,
        height: 68,
        color: colores.surfaceContainerHighest,
        child: producto.imagenPrincipal != null
            ? Image.network(
                producto.imagenPrincipal!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.image_not_supported_outlined,
                  color: colores.outline,
                ),
              )
            : Icon(Icons.inventory_2_outlined, color: colores.outline),
      ),
    );
  }

  /// Chip plano: fondo del mismo color con baja opacidad y texto del color.
  Widget _chip(
    String texto,
    Color color,
    BuildContext context, {
    IconData? icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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

String _lotesProducto(Producto producto) {
  final lotes = producto.stocks
      .where((s) => s['lote'] != null && s['lote'].toString().isNotEmpty)
      .map((s) => s['lote'].toString())
      .toSet()
      .toList();
  if (lotes.isEmpty) return '';
  return lotes.take(3).join(', ') + (lotes.length > 3 ? '...' : '');
}

/// Fecha de vencimiento más próxima de los lotes, con los días que faltan.
String? _proximaFechaVencimiento(Producto producto) {
  DateTime? proximaFecha;
  for (final stock in producto.stocks) {
    final fechaStr = stock['fecha_vencimiento'];
    if (fechaStr != null && fechaStr.toString().isNotEmpty) {
      try {
        final fecha = DateTime.parse(fechaStr.toString());
        if (proximaFecha == null || fecha.isBefore(proximaFecha)) {
          proximaFecha = fecha;
        }
      } catch (_) {
        // Ignorar fechas inválidas
      }
    }
  }
  if (proximaFecha == null) return null;

  final hoy = DateTime.now();
  if (proximaFecha.isBefore(hoy)) return 'VENCIDO';
  final dias = proximaFecha.difference(hoy).inDays;
  if (dias == 0) return 'HOY';
  return '${proximaFecha.day}/${proximaFecha.month}/${proximaFecha.year} ($dias d)';
}

/// Algún lote vence dentro de los próximos 30 días.
bool _proximoVencer(Producto producto) {
  for (final stock in producto.stocks) {
    final fechaStr = stock['fecha_vencimiento'];
    if (fechaStr != null && fechaStr.toString().isNotEmpty) {
      try {
        final fecha = DateTime.parse(fechaStr.toString());
        final dias = fecha.difference(DateTime.now()).inDays;
        if (dias >= 0 && dias <= 30) return true;
      } catch (_) {
        // Ignorar fechas inválidas
      }
    }
  }
  return false;
}
