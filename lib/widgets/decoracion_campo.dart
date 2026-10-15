import 'package:flutter/material.dart';

/// Decoración común de los campos de formulario: borde redondeado.
/// `compacta` reduce el padding interno.
InputDecoration decoracionCampo(
  String label, {
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool enabled = true,
  bool compacta = false,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    enabled: enabled,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: compacta
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : null,
  );
}
