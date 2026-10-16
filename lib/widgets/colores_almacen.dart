import 'package:flutter/material.dart';

/// Colores fijos por almacén, iguales en todas las pantallas de inventario.
const MaterialColor colorSala = Colors.teal;
const MaterialColor colorPrincipal = Colors.purple;
const MaterialColor colorOtroAlmacen = Colors.blueGrey;

/// Mismo criterio que el backend: "…principal…" y "sala…"/"…venta…".
MaterialColor colorAlmacen(String? nombre) {
  final n = (nombre ?? '').toLowerCase();
  if (n.contains('principal')) return colorPrincipal;
  if (n.contains('sala') || n.contains('venta')) return colorSala;
  return colorOtroAlmacen;
}

IconData iconoAlmacen(String? nombre) {
  final n = (nombre ?? '').toLowerCase();
  if (n.contains('sala') || n.contains('venta')) return Icons.storefront;
  return Icons.warehouse;
}

/// Número sin decimales innecesarios: 12.0 → "12", 2.5 → "2.5".
String formatearCantidad(dynamic v) {
  final n = num.tryParse('$v') ?? 0;
  if (n == n.roundToDouble()) return n.toInt().toString();
  return double.parse(n.toStringAsFixed(4)).toString();
}
