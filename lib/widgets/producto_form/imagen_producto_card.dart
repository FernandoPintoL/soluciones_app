import 'dart:io';

import 'package:flutter/material.dart';

import '../../config/colores_app.dart';

/// Foto principal del producto. Con foto muestra la vista previa grande con
/// acciones encima (cambiar, y quitar si es una foto nueva sin guardar).
/// Sin foto muestra un recuadro para agregarla. Tocar la imagen también la cambia.
class ImagenProductoCard extends StatelessWidget {
  final File? imagenSeleccionada;
  final String? imagenRemota;
  final bool habilitado;
  final VoidCallback onSeleccionar;
  final VoidCallback onQuitar;

  const ImagenProductoCard({
    super.key,
    required this.imagenSeleccionada,
    required this.imagenRemota,
    required this.habilitado,
    required this.onSeleccionar,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final estado = AppColores.estado(context);
    final tieneFoto = imagenSeleccionada != null || imagenRemota != null;
    final sinGuardar = imagenSeleccionada != null;

    return Container(
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colores.outlineVariant),
      ),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: GestureDetector(
          onTap: habilitado ? onSeleccionar : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              tieneFoto ? _imagen(context) : _vacio(context),
              if (tieneFoto)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      _Etiqueta(texto: 'Principal', color: colores.primary),
                      if (sinGuardar)
                        _Etiqueta(texto: 'Sin guardar', color: estado.naranja),
                    ],
                  ),
                ),
              if (tieneFoto && habilitado)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Cambiar foto',
                        onPressed: onSeleccionar,
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                      if (sinGuardar) ...[
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: 'Quitar foto sin guardar',
                          onPressed: onQuitar,
                          style: IconButton.styleFrom(
                            foregroundColor: colores.error,
                          ),
                          icon: const Icon(Icons.close),
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

  Widget _imagen(BuildContext context) {
    if (imagenSeleccionada != null) {
      return Image.file(imagenSeleccionada!, fit: BoxFit.cover);
    }
    return Image.network(
      imagenRemota!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progreso) => progreso == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: (_, _, _) => _vacio(context),
    );
  }

  Widget _vacio(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    return ColoredBox(
      color: colores.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colores.primaryContainer,
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: colores.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            habilitado ? 'Agregar foto del producto' : 'Sin foto',
            style: tema.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Cámara o galería · se guarda como principal',
            style: tema.textTheme.labelSmall?.copyWith(
              color: colores.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta sobre la foto (fondo translúcido, texto del color indicado).
class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const _Etiqueta({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
