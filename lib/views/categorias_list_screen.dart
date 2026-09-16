import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/categoria_provider.dart';
import '../widgets/app_drawer.dart';
import 'categoria_form_screen.dart';

class CategoriasListScreen extends StatefulWidget {
  const CategoriasListScreen({super.key});

  @override
  State<CategoriasListScreen> createState() => _CategoriasListScreenState();
}

class _CategoriasListScreenState extends State<CategoriasListScreen> {
  late TextEditingController _searchController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();

    _scrollController.addListener(_onScroll);
    print('✅ [CategoriasListScreen] ScrollListener agregado');

    Future.microtask(() {
      context.read<CategoriaProvider>().getCategorias();
    });
  }

  void _onScroll() {
    final position = _scrollController.position;
    final isNearEnd = position.pixels >= position.maxScrollExtent * 0.8;

    if (isNearEnd) {
      final provider = context.read<CategoriaProvider>();

      if (provider.hasMorePages && !provider.isLoading) {
        provider.loadMoreCategorias();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta categoría?',
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
      final success =
          await context.read<CategoriaProvider>().deleteCategoria(id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Categoría eliminada correctamente'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<CategoriaProvider>().errorMessage ??
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
        title: const Text('Categorías'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CategoriaProvider>().refresh();
            },
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: 'categorias'),
      body: Column(
        children: [
          // Información de paginación
          Consumer<CategoriaProvider>(
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
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar categorías...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<CategoriaProvider>().getCategorias();
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
                  context.read<CategoriaProvider>().getCategorias(search: value);
                } else {
                  context.read<CategoriaProvider>().getCategorias();
                }
              },
            ),
          ),
          // Lista de categorías
          Expanded(
            child: Consumer<CategoriaProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.categorias.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null &&
                    provider.categorias.isEmpty) {
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
                            context
                                .read<CategoriaProvider>()
                                .refresh();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.categorias.isEmpty) {
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
                        const Text('No hay categorías'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: provider.categorias.length +
                      (provider.hasMorePages ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Indicador de carga al final
                    if (index == provider.categorias.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: provider.isLoading
                            ? const CircularProgressIndicator()
                            : const SizedBox.shrink(),
                      );
                    }

                    final categoria = provider.categorias[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(categoria.nombre),
                        subtitle: categoria.descripcion != null
                            ? Text(categoria.descripcion!)
                            : null,
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Editar'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoriaFormScreen(
                                      categoria: categoria,
                                    ),
                                  ),
                                );
                              },
                            ),
                            PopupMenuItem(
                              child: const Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () => _handleDelete(categoria.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoriaFormScreen(
                                categoria: categoria,
                              ),
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
            MaterialPageRoute(builder: (_) => const CategoriaFormScreen()),
          );
        },
        tooltip: 'Nueva Categoría',
        child: const Icon(Icons.add),
      ),
    );
  }
}
