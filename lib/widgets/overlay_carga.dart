import 'package:flutter/material.dart';

/// Capa semitransparente con un indicador de carga centrado.
class OverlayCarga extends StatelessWidget {
  final String titulo;
  final String? detalle;

  const OverlayCarga({
    super.key,
    this.titulo = 'Cargando información...',
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(titulo, style: textTheme.titleMedium),
                if (detalle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    detalle!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
