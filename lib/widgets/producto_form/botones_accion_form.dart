import 'package:flutter/material.dart';

/// Botones principales del formulario: Cancelar (secundario) y
/// Crear/Actualizar (principal, más ancho). Mientras `guardando` es true
/// ambos se deshabilitan y el principal muestra un spinner.
class BotonesAccionForm extends StatelessWidget {
  final bool guardando;
  final bool esNuevo;
  final VoidCallback onCancelar;
  final VoidCallback onGuardar;

  const BotonesAccionForm({
    super.key,
    required this.guardando,
    required this.esNuevo,
    required this.onCancelar,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const alto = Size.fromHeight(54);
    final colorPrincipal = esNuevo ? Colors.green.shade600 : scheme.primary;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: guardando ? null : onCancelar,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancelar'),
            style: OutlinedButton.styleFrom(
              minimumSize: alto,
              shape: forma,
              foregroundColor: scheme.error,
              side: BorderSide(
                color: scheme.error.withValues(alpha: 0.6),
                width: 1.5,
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: guardando ? null : onGuardar,
            icon: guardando
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.onPrimary,
                    ),
                  )
                : Icon(
                    esNuevo
                        ? Icons.add_circle_outline_rounded
                        : Icons.save_rounded,
                  ),
            label: Text(
              guardando
                  ? 'Guardando...'
                  : esNuevo
                  ? 'Crear producto'
                  : 'Actualizar producto',
            ),
            style: FilledButton.styleFrom(
              minimumSize: alto,
              shape: forma,
              elevation: 2,
              backgroundColor: colorPrincipal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colorPrincipal.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
