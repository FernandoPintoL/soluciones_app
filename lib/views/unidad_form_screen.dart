import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/unidad_medida.dart';
import '../providers/unidad_medida_provider.dart';

class UnidadFormScreen extends StatefulWidget {
  final UnidadMedida? unidad;

  const UnidadFormScreen({super.key, this.unidad});

  @override
  State<UnidadFormScreen> createState() => _UnidadFormScreenState();
}

class _UnidadFormScreenState extends State<UnidadFormScreen> {
  late TextEditingController _nombreController;
  late TextEditingController _codigoController;
  late bool _activo;
  late GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nombreController = TextEditingController(
      text: widget.unidad?.nombre ?? '',
    );
    _codigoController = TextEditingController(
      text: widget.unidad?.codigo ?? '',
    );
    _activo = widget.unidad?.activo ?? true;

    print(
      '✅ [UnidadFormScreen] ${widget.unidad == null ? 'Crear' : 'Editar'} unidad',
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final unidad = UnidadMedida(
      id: widget.unidad?.id ?? 0,
      nombre: _nombreController.text,
      codigo: _codigoController.text,
      activo: _activo,
    );

    if (!mounted) return;

    final provider = context.read<UnidadMedidaProvider>();
    final success = widget.unidad == null
        ? await provider.createUnidad(unidad)
        : await provider.updateUnidad(widget.unidad!.id, unidad);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.unidad == null
                ? 'Unidad creada correctamente'
                : 'Unidad actualizada correctamente',
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
        title: Text(widget.unidad == null ? 'Nueva Unidad' : 'Editar Unidad'),
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
                    hintText: 'Ej: Kilogramo, Litro, Unidad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.straighten),
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

                // Código
                TextFormField(
                  controller: _codigoController,
                  decoration: InputDecoration(
                    labelText: 'Código *',
                    hintText: 'Ej: KG, LT, UN',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El código es requerido';
                    }
                    if (value.length < 2 || value.length > 10) {
                      return 'El código debe tener entre 2 y 10 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Activo
                Consumer<UnidadMedidaProvider>(
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
                Consumer<UnidadMedidaProvider>(
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
                              widget.unidad == null
                                  ? 'Crear Unidad'
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
