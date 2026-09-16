import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categoria.dart';
import '../providers/categoria_provider.dart';

class CategoriaFormScreen extends StatefulWidget {
  final Categoria? categoria;

  const CategoriaFormScreen({super.key, this.categoria});

  @override
  State<CategoriaFormScreen> createState() => _CategoriaFormScreenState();
}

class _CategoriaFormScreenState extends State<CategoriaFormScreen> {
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late bool _activo;
  late GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nombreController = TextEditingController(text: widget.categoria?.nombre ?? '');
    _descripcionController = TextEditingController(text: widget.categoria?.descripcion ?? '');
    _activo = widget.categoria?.activo ?? true;

    print('✅ [CategoriaFormScreen] ${widget.categoria == null ? 'Crear' : 'Editar'} categoría');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final categoria = Categoria(
      id: widget.categoria?.id ?? 0,
      nombre: _nombreController.text,
      descripcion: _descripcionController.text,
      activo: _activo,
    );

    if (!mounted) return;

    final provider = context.read<CategoriaProvider>();
    final success = widget.categoria == null
        ? await provider.createCategoria(categoria)
        : await provider.updateCategoria(widget.categoria!.id, categoria);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.categoria == null
                ? 'Categoría creada correctamente'
                : 'Categoría actualizada correctamente',
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al guardar'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoria == null ? 'Nueva Categoría' : 'Editar Categoría',
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nombre
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Ej: Electrónica, Ropa, Alimentos',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Descripción opcional de la categoría',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 16),

              // Activo
              Consumer<CategoriaProvider>(
                builder: (context, provider, _) {
                  return CheckboxListTile(
                    title: const Text('Activo'),
                    value: _activo,
                    onChanged: (value) {
                      setState(() {
                        _activo = value ?? true;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
              const SizedBox(height: 32),

              // Botón guardar
              Consumer<CategoriaProvider>(
                builder: (context, provider, _) {
                  return ElevatedButton(
                    onPressed: provider.isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            widget.categoria == null
                                ? 'Crear Categoría'
                                : 'Guardar Cambios',
                            style: const TextStyle(fontSize: 16),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
