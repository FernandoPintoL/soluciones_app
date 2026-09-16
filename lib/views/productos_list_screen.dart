import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../providers/auth_provider.dart';
import '../providers/producto_provider.dart';
import '../widgets/app_drawer.dart';
import 'login_screen.dart';
import 'producto_form_screen.dart';
import 'categorias_list_screen.dart';
import 'barcode_scanner_screen.dart';

class ProductosListScreen extends StatefulWidget {
  const ProductosListScreen({super.key});

  @override
  State<ProductosListScreen> createState() => _ProductosListScreenState();
}

class _ProductosListScreenState extends State<ProductosListScreen> {
  late TextEditingController _searchController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();

    // Escuchar cuando se llega al final de la lista
    _scrollController.addListener(_onScroll);
    print('✅ [ProductosListScreen] ScrollListener agregado');

    // Cargar productos al iniciar
    Future.microtask(() {
      context.read<ProductoProvider>().getProductos();
    });
  }

  void _onScroll() {
    final position = _scrollController.position;
    // print('📜 [ScrollListener] Scroll: ${position.pixels.toStringAsFixed(2)}/${position.maxScrollExtent.toStringAsFixed(2)}');

    // Si está casi al final (80% del scroll), cargar más
    final isNearEnd = position.pixels >= position.maxScrollExtent * 0.8;

    if (isNearEnd) {
      final provider = context.read<ProductoProvider>();
      // print('📜 [ScrollListener] Near end - hasMorePages: ${provider.hasMorePages}, isLoading: ${provider.isLoading}');

      if (provider.hasMorePages && !provider.isLoading) {
        // print('📜 [ScrollListener] Cargando más productos...');
        provider.loadMoreProductos();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  String _getLotesInfo(Producto producto) {
    final lotes = producto.stocks
        .where((s) => s['lote'] != null && s['lote'].toString().isNotEmpty)
        .map((s) => s['lote'].toString())
        .toSet()
        .toList();

    if (lotes.isEmpty) return '';
    return lotes.take(3).join(', ') + (lotes.length > 3 ? '...' : '');
  }

  String? _getProximaFechaVencimiento(Producto producto) {
    DateTime? proximaFecha;

    for (final stock in producto.stocks) {
      final fechaStr = stock['fecha_vencimiento'];
      if (fechaStr != null && fechaStr.toString().isNotEmpty) {
        try {
          final fecha = DateTime.parse(fechaStr.toString());
          if (proximaFecha == null || fecha.isBefore(proximaFecha)) {
            proximaFecha = fecha;
          }
        } catch (e) {
          // Ignorar fechas inválidas
        }
      }
    }

    if (proximaFecha == null) return null;

    final hoy = DateTime.now();
    if (proximaFecha.isBefore(hoy)) {
      return '❌ VENCIDO';
    }

    final diferencia = proximaFecha.difference(hoy).inDays;
    if (diferencia == 0) return '⚠️ HOY';
    if (diferencia < 0) return '❌ VENCIDO';

    return '${proximaFecha.day}/${proximaFecha.month}/${proximaFecha.year} ($diferencia d)';
  }

  bool _isProximoVencer(Producto producto) {
    for (final stock in producto.stocks) {
      final fechaStr = stock['fecha_vencimiento'];
      if (fechaStr != null && fechaStr.toString().isNotEmpty) {
        try {
          final fecha = DateTime.parse(fechaStr.toString());
          final diferencia = fecha.difference(DateTime.now()).inDays;
          if (diferencia >= 0 && diferencia <= 30) {
            return true;
          }
        } catch (e) {
          // Ignorar fechas inválidas
        }
      }
    }
    return false;
  }

  Future<void> _handleDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este producto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final success = await context.read<ProductoProvider>().deleteProducto(id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Producto eliminado correctamente'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<ProductoProvider>().errorMessage ??
                  'Error al eliminar',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ProductoProvider>().refresh().then((_) {
                // Hacer scroll al inicio después de refrescar
                if (mounted && _scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: 'productos'),
      body: Column(
        children: [
          // ✅ Mostrar info de paginación
          Consumer<ProductoProvider>(
            builder: (context, provider, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  provider.paginationInfo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          // Barra de búsqueda con escaneo
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar productos...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                context
                                    .read<ProductoProvider>()
                                    .getProductos()
                                    .then((_) {
                                      // Hacer scroll al inicio
                                      if (mounted &&
                                          _scrollController.hasClients) {
                                        _scrollController.animateTo(
                                          0,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOut,
                                        );
                                      }
                                    });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      if (value.isNotEmpty) {
                        context
                            .read<ProductoProvider>()
                            .searchProductos(value)
                            .then((_) {
                              // Hacer scroll al inicio después de la búsqueda
                              if (mounted && _scrollController.hasClients) {
                                _scrollController.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                      } else {
                        context.read<ProductoProvider>().getProductos().then((
                          _,
                        ) {
                          // Hacer scroll al inicio después de cargar
                          if (mounted && _scrollController.hasClients) {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Botón para escanear código de barras
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_2),
                    tooltip: 'Escanear código de barras',
                    onPressed: () async {
                      // Navegar a la pantalla de escaneo
                      final scannedCode = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BarcodeScannerScreen(),
                        ),
                      );

                      // Si se escaneó un código, buscar por ese código
                      if (scannedCode != null &&
                          scannedCode.isNotEmpty &&
                          mounted) {
                        print(
                          '🔍 [ProductosListScreen] Código de barras escaneado: $scannedCode',
                        );

                        _searchController.text = scannedCode;
                        setState(() {}); // Actualizar UI con el código

                        // Buscar el producto por código de barras
                        await context
                            .read<ProductoProvider>()
                            .searchProductoByCodigoBarras(scannedCode);

                        // Hacer scroll al inicio para mostrar resultados
                        if (mounted && _scrollController.hasClients) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted && _scrollController.hasClients) {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Lista de productos
          Expanded(
            child: Consumer<ProductoProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.productos.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null &&
                    provider.productos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.errorMessage ?? 'Error desconocido',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ProductoProvider>().refresh();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.productos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text('No hay productos'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount:
                      provider.productos.length +
                      (provider.hasMorePages ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Mostrar indicador de carga al final
                    if (index == provider.productos.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: provider.isLoading
                            ? const CircularProgressIndicator()
                            : const SizedBox.shrink(),
                      );
                    }

                    final producto = provider.productos[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        // ✅ NUEVA: Mostrar imagen del producto
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: producto.imagenPrincipal != null
                                ? Image.network(
                                    producto.imagenPrincipal!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Si la imagen no carga, mostrar icono
                                      return Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.grey.shade400,
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                  )
                                : Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.grey.shade400,
                                  ),
                          ),
                        ),
                        title: Text("#${producto.id} - ${producto.nombre}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'SKU: ${producto.sku ?? "N/A"}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                // Indicador de código de barra
                                Tooltip(
                                  message: producto.tieneCodigoBarras
                                      ? 'Código: ${producto.codigosBarra}'
                                      : 'Sin código de barra',
                                  child: Icon(
                                    producto.tieneCodigoBarras
                                        ? Icons.qr_code
                                        : Icons.qr_code_2_outlined,
                                    size: 18,
                                    color: producto.tieneCodigoBarras
                                        ? Colors.green
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '🏷️ Marca: ${producto.marcaNombre ?? "Sin marca"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Mostrar sectores/almacenes (desde stockLimites)
                            if (producto.stockLimites.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: producto.stockLimites.take(3).map((
                                  sl,
                                ) {
                                  final almacenNombre =
                                      sl['almacen_nombre'] ?? 'Almacén';
                                  final sectorNombre =
                                      sl['sector_nombre'] ?? 'Sector';
                                  // Abreviar nombres largos
                                  final almacenAbrev = almacenNombre.length > 10
                                      ? almacenNombre.substring(0, 10)
                                      : almacenNombre;
                                  final sectorAbrev = sectorNombre.length > 10
                                      ? sectorNombre.substring(0, 10)
                                      : sectorNombre;
                                  final label = '$almacenAbrev - $sectorAbrev';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Tooltip(
                                      message: '$almacenNombre - $sectorNombre',
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.indigo.shade700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (producto.stockLimites.length > 3)
                              Text(
                                '+${producto.stockLimites.length - 3} más',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.indigo.shade600,
                                ),
                              ),
                            const SizedBox(height: 4),
                            // Mostrar código de barra y stock
                            if (producto.tieneCodigoBarras)
                              Text(
                                '🔖 ${producto.codigosBarra}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                ),
                              ),
                            if (producto.stocks.isNotEmpty) ...[
                              Text(
                                '📦 Stock: ${producto.stockTotal}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: producto.stockTotal > 0
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                              // Mostrar lotes
                              if (_getLotesInfo(producto).isNotEmpty)
                                Text(
                                  'Lotes: ${_getLotesInfo(producto)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              // Mostrar próxima fecha de vencimiento
                              if (_getProximaFechaVencimiento(producto) != null)
                                Text(
                                  'Vence: ${_getProximaFechaVencimiento(producto)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _isProximoVencer(producto)
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                            if (producto.precioVenta != null &&
                                producto.precioVenta! > 0)
                              Text(
                                '💰 Venta: ${producto.precioVenta?.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Editar'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductoFormScreen(producto: producto),
                                  ),
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: const Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () => _handleDelete(producto.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductoFormScreen(producto: producto),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductoFormScreen()),
          );
        },
        tooltip: 'Nuevo Producto',
        child: const Icon(Icons.add),
      ),
    );
  }
}
