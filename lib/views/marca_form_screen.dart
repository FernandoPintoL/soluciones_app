import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/marca.dart';
import '../providers/marca_provider.dart';

class MarcaFormScreen extends StatefulWidget {
  final Marca? marca;

  const MarcaFormScreen({super.key, this.marca});

  @override
  State<MarcaFormScreen> createState() => _MarcaFormScreenState();
}

class _MarcaFormScreenState extends State<MarcaFormScreen> {
  late TextEditingController _nombreController;
  late bool _activo;
  late GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nombreController = TextEditingController(text: widget.marca?.nombre ?? '');
    _activo = widget.marca?.activo ?? true;

    print(
      '✅ [MarcaFormScreen] ${widget.marca == null ? 'Crear' : 'Editar'} marca',
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final marca = Marca(
      id: widget.marca?.id ?? 0,
      nombre: _nombreController.text,
      activo: _activo,
    );

    if (!mounted) return;

    final provider = context.read<MarcaProvider>();
    final success = widget.marca == null
        ? await provider.createMarca(marca)
        : await provider.updateMarca(widget.marca!.id, marca);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.marca == null
                ? 'Marca creada correctamente'
                : 'Marca actualizada correctamente',
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
        title: Text(widget.marca == null ? 'Nueva Marca' : 'Editar Marca'),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                    hintText: 'Ej: Sony, Samsung, LG, Canon',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.local_offer),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El nombre es requerido';
                    }
                    if (value.length < 2) {
                      return 'El nombre debe tener al menos 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Activo
                Consumer<MarcaProvider>(
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
                Consumer<MarcaProvider>(
                  builder: (context, provider, _) {
                    return ElevatedButton(
                      onPressed: provider.isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimary,
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.marca == null
                                  ? 'Crear Marca'
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
      ),
    );
  }
}
