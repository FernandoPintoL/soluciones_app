import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/marca_provider.dart';
import '../widgets/app_drawer.dart';
import 'marca_form_screen.dart';

class MarcasListScreen extends StatefulWidget {
  const MarcasListScreen({super.key});

  @override
  State<MarcasListScreen> createState() => _MarcasListScreenState();
}

class _MarcasListScreenState extends State<MarcasListScreen> {
  late TextEditingController _searchController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();

    _scrollController.addListener(_onScroll);
    print('✅ [MarcasListScreen] ScrollListener agregado');

    Future.microtask(() {
      context.read<MarcaProvider>().getMarcas();
    });
  }

  void _onScroll() {
    final position = _scrollController.position;
    final isNearEnd = position.pixels >= position.maxScrollExtent * 0.8;

    if (isNearEnd) {
      final provider = context.read<MarcaProvider>();

      if (provider.hasMorePages && !provider.isLoading) {
        provider.loadMoreMarcas();
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
        title: const Text('Eliminar Marca'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta marca?',
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
      final success = await context.read<MarcaProvider>().deleteMarca(id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Marca eliminada correctamente'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<MarcaProvider>().errorMessage ?? 'Error al eliminar',
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
        title: const Text('Marcas'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MarcaProvider>().refresh();
            },
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: 'marcas'),
      body: Column(
        children: [
          // Información de paginación
          Consumer<MarcaProvider>(
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
                hintText: 'Buscar marcas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<MarcaProvider>().getMarcas();
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
                  context.read<MarcaProvider>().getMarcas(search: value);
                } else {
                  context.read<MarcaProvider>().getMarcas();
                }
              },
            ),
          ),
          // Lista de marcas
          Expanded(
            child: Consumer<MarcaProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.marcas.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null && provider.marcas.isEmpty) {
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
                            context.read<MarcaProvider>().refresh();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.marcas.isEmpty) {
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
                        const Text('No hay marcas'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: provider.marcas.length +
                      (provider.hasMorePages ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Indicador de carga al final
                    if (index == provider.marcas.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: provider.isLoading
                            ? const CircularProgressIndicator()
                            : const SizedBox.shrink(),
                      );
                    }

                    final marca = provider.marcas[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.local_offer,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(marca.nombre),
                        subtitle: Text(
                          marca.activo ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            color: marca.activo ? Colors.green : Colors.grey,
                          ),
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Editar'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MarcaFormScreen(
                                      marca: marca,
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
                              onTap: () => _handleDelete(marca.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MarcaFormScreen(
                                marca: marca,
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
            MaterialPageRoute(builder: (_) => const MarcaFormScreen()),
          );
        },
        tooltip: 'Nueva Marca',
        child: const Icon(Icons.add),
      ),
    );
  }
}
