import 'dart:io';

import 'package:flutter/material.dart';

/// Tarjeta con switch para mostrar/ocultar la imagen del producto, su vista
/// previa (archivo local, imagen remota o placeholder) y el botón para elegirla.
class ImagenProductoCard extends StatelessWidget {
  final File? imagenSeleccionada;
  final String? imagenRemota;
  final bool mostrar;
  final bool habilitado;
  final ValueChanged<bool> onMostrarChanged;
  final VoidCallback onSeleccionar;
  final VoidCallback onQuitar;

  const ImagenProductoCard({
    super.key,
    required this.imagenSeleccionada,
    required this.imagenRemota,
    required this.mostrar,
    required this.habilitado,
    required this.onMostrarChanged,
    required this.onSeleccionar,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Imagen del Producto',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Switch(value: mostrar, onChanged: onMostrarChanged),
              ],
            ),
            if (mostrar) ...[
              const SizedBox(height: 12),
              _buildPreview(context),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: habilitado ? onSeleccionar : null,
                  icon: const Icon(Icons.image),
                  label: Text(
                    imagenSeleccionada != null
                        ? 'Cambiar Imagen'
                        : 'Seleccionar Imagen',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (imagenSeleccionada != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              imagenSeleccionada!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: FloatingActionButton(
              mini: true,
              onPressed: onQuitar,
              backgroundColor: Theme.of(context).colorScheme.error,
              child: const Icon(Icons.close),
            ),
          ),
        ],
      );
    }
    if (imagenRemota != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imagenRemota!,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _Placeholder(),
        ),
      );
    }
    return const _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.shade400,
        size: 48,
      ),
    );
  }
}
