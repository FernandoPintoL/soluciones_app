import 'package:flutter/material.dart';

import '../config/colores_app.dart';

/// Color con el que se resaltan los campos ya completados (solo referencia
/// visual, no es validación).
final Color colorCampoCompletado = AppColores.verde;

/// Decoración común de los campos de formulario: borde redondeado.
/// `compacta` reduce el padding interno. `completado` resalta el campo con
/// borde y fondo verdes mientras no tiene el foco.
InputDecoration decoracionCampo(
  String label, {
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool enabled = true,
  bool compacta = false,
  bool completado = false,
  Color colorCompletado = AppColores.verde,
}) {
  final forma = BorderRadius.circular(12);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    enabled: enabled,
    // Solo cambia el estado "habilitado sin foco": al enfocar se ve el
    // color normal del tema y al deshabilitar, el gris de siempre.
    enabledBorder: completado
        ? OutlineInputBorder(
            borderRadius: forma,
            borderSide: BorderSide(color: colorCompletado, width: 1.5),
          )
        : null,
    filled: completado,
    fillColor: completado ? colorCompletado.withValues(alpha: 0.08) : null,
    contentPadding: compacta
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : null,
  );
}

/// TextField con [decoracionCampo] que se resalta solo cuando su
/// controlador tiene texto.
class CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool compacta;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const CampoTexto({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.compacta = false,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, valor, _) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        decoration: decoracionCampo(
          label,
          hint: hint,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          enabled: enabled,
          compacta: compacta,
          completado: valor.text.trim().isNotEmpty,
          colorCompletado: AppColores.estado(context).verde,
        ),
      ),
    );
  }
}
