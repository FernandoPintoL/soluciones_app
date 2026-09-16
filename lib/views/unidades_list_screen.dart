import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/unidad_medida_provider.dart';
import '../widgets/app_drawer.dart';
import 'unidad_form_screen.dart';

class UnidadesListScreen extends StatefulWidget {
  const UnidadesListScreen({super.key});

  @override
  State<UnidadesListScreen> createState() => _UnidadesListScreenState();
}

class _UnidadesListScreenState extends State<UnidadesListScreen> {
  late TextEditingController _searchController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();

    _scrollController.addListener(_onScroll);
    print('✅ [UnidadesListScreen] ScrollListener agregado');

    Future.microtask(() {
      context.read<UnidadMedidaProvider>().getUnidades();
    });
  }

  void _onScroll() {
    final position = _scrollController.position;
    final isNearEnd = position.pixels >= position.maxScrollExtent * 0.8;

    if (isNearEnd) {
      final provider = context.read<UnidadMedidaProvider>();

      if (provider.hasMorePages && !provider.isLoading) {
        provider.loadMoreUnidades();
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
        title: const Text('Eliminar Unidad'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta unidad de medida?',
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
          await context.read<UnidadMedidaProvider>().deleteUnidad(id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unidad eliminada correctamente'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<UnidadMedidaProvider>().errorMessage ??
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
        title: const Text('Unidades de Medida'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<UnidadMedidaProvider>().refresh();
            },
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: 'unidades'),
      body: Column(
        children: [
          // Información de paginación
          Consumer<UnidadMedidaProvider>(
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
                hintText: 'Buscar unidades...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<UnidadMedidaProvider>().getUnidades();
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
                  context.read<UnidadMedidaProvider>().getUnidades(search: value);
                } else {
                  context.read<UnidadMedidaProvider>().getUnidades();
                }
              },
            ),
          ),
          // Lista de unidades
          Expanded(
            child: Consumer<UnidadMedidaProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.unidades.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null &&
                    provider.unidades.isEmpty) {
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
                                .read<UnidadMedidaProvider>()
                                .refresh();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.unidades.isEmpty) {
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
                        const Text('No hay unidades de medida'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: provider.unidades.length +
                      (provider.hasMorePages ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Indicador de carga al final
                    if (index == provider.unidades.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: provider.isLoading
                            ? const CircularProgressIndicator()
                            : const SizedBox.shrink(),
                      );
                    }

                    final unidad = provider.unidades[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: Chip(
                          label: Text(
                            unidad.codigo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(unidad.nombre),
                        subtitle: Text(
                          unidad.activo ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            color: unidad.activo
                                ? Colors.green
                                : Colors.grey,
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
                                    builder: (_) => UnidadFormScreen(
                                      unidad: unidad,
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
                              onTap: () => _handleDelete(unidad.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UnidadFormScreen(
                                unidad: unidad,
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
            MaterialPageRoute(builder: (_) => const UnidadFormScreen()),
          );
        },
        tooltip: 'Nueva Unidad',
        child: const Icon(Icons.add),
      ),
    );
  }
}
