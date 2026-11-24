import 'package:flutter/material.dart';

/// Colores de estado (texto, iconos y tintes) con versión para modo claro y oscuro.
/// En modo claro los tonos son más oscuros para leerse sobre blanco; en modo oscuro,
/// más claros para leerse sobre fondo oscuro.
class EstadoColores {
  final Color verde;
  final Color rojo;
  final Color naranja;
  final Color azul;
  final Color gris;

  const EstadoColores({
    required this.verde,
    required this.rojo,
    required this.naranja,
    required this.azul,
    required this.gris,
  });
}

/// Paleta plana de la app.
/// - Constantes de marca (azul, verde…): para bloques sólidos con texto blanco
///   y para el tema. Son iguales en ambos modos.
/// - [estado]: para texto e iconos de estado. Se adapta al modo claro u oscuro.
abstract final class AppColores {
  // Marca (bloques sólidos y tema)
  static const azul = Color(0xFF2563EB);
  static const verde = Color(0xFF16A34A);
  static const naranja = Color(0xFFF59E0B);
  static const rojo = Color(0xFFDC2626);
  static const morado = Color(0xFF7C3AED);
  static const teal = Color(0xFF0D9488);
  static const gris = Color(0xFF64748B);
  static const fondo = Color(0xFFF8FAFC);

  // Estado en modo claro (sobre fondo blanco)
  static const estadoClaro = EstadoColores(
    verde: Color(0xFF15803D),
    rojo: Color(0xFFB91C1C),
    naranja: Color(0xFFB45309),
    azul: Color(0xFF1D4ED8),
    gris: Color(0xFF475569),
  );

  // Estado en modo oscuro (sobre fondo oscuro)
  static const estadoOscuro = EstadoColores(
    verde: Color(0xFF4ADE80),
    rojo: Color(0xFFF87171),
    naranja: Color(0xFFFBBF24),
    azul: Color(0xFF60A5FA),
    gris: Color(0xFF94A3B8),
  );

  /// Colores de estado según el modo de la app (claro u oscuro).
  static EstadoColores estado(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? estadoOscuro
        : estadoClaro;
  }
}
