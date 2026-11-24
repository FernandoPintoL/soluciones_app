import 'package:flutter/material.dart';

import '../views/caja_screen.dart';
import '../views/categorias_list_screen.dart';
import '../views/home_screen.dart';
import '../views/marcas_list_screen.dart';
import '../views/movimiento_caja_screen.dart';
import '../views/productos_list_screen.dart';
import '../views/reposicion_screen.dart';
import '../views/stock_movimientos_screen.dart';
import '../views/unidades_list_screen.dart';
import '../views/venta_nueva_screen.dart';
import '../views/ventas_listado_screen.dart';
import 'colores_app.dart';

/// Sección del menú y de los accesos del inicio.
enum SeccionModulo { operacion, inventario, catalogos }

/// Un módulo de la app. Es la única lista de pantallas: el menú lateral y
/// los accesos del inicio se generan desde [modulos]. Para agregar o cambiar
/// una pantalla basta con editar esta lista.
class Modulo {
  /// Identificador: se compara con el currentRoute de cada pantalla.
  final String id;
  final String titulo;
  final IconData icono;
  final Color color;
  final SeccionModulo seccion;
  final Widget Function() pantalla;

  const Modulo({
    required this.id,
    required this.titulo,
    required this.icono,
    required this.color,
    required this.seccion,
    required this.pantalla,
  });
}

// Colores de la paleta compartida (config/colores_app.dart)
const _azul = AppColores.azul;
const _verde = AppColores.verde;
const _naranja = AppColores.naranja;
const _rojo = AppColores.rojo;
const _morado = AppColores.morado;
const _teal = AppColores.teal;
const _gris = AppColores.gris;

final List<Modulo> modulos = [
  Modulo(
    id: 'inicio',
    titulo: 'Inicio',
    icono: Icons.home_outlined,
    color: _azul,
    seccion: SeccionModulo.operacion,
    pantalla: () => const HomeScreen(),
  ),
  Modulo(
    id: 'venta',
    titulo: 'Nueva venta',
    icono: Icons.point_of_sale,
    color: _azul,
    seccion: SeccionModulo.operacion,
    pantalla: () => const VentaNuevaScreen(),
  ),
  Modulo(
    id: 'ventas',
    titulo: 'Ventas',
    icono: Icons.receipt_long,
    color: _teal,
    seccion: SeccionModulo.operacion,
    pantalla: () => const VentasListadoScreen(),
  ),
  Modulo(
    id: 'caja',
    titulo: 'Mi caja',
    icono: Icons.account_balance_wallet_outlined,
    color: _verde,
    seccion: SeccionModulo.operacion,
    pantalla: () => const CajaScreen(),
  ),
  Modulo(
    id: 'egreso',
    titulo: 'Registrar egreso',
    icono: Icons.north_east,
    color: _rojo,
    seccion: SeccionModulo.operacion,
    pantalla: () => const MovimientoCajaScreen(esIngreso: false),
  ),
  Modulo(
    id: 'ingreso',
    titulo: 'Registrar ingreso',
    icono: Icons.south_west,
    color: _naranja,
    seccion: SeccionModulo.operacion,
    pantalla: () => const MovimientoCajaScreen(esIngreso: true),
  ),
  Modulo(
    id: 'productos',
    titulo: 'Productos',
    icono: Icons.shopping_bag,
    color: _morado,
    seccion: SeccionModulo.inventario,
    pantalla: () => const ProductosListScreen(),
  ),
  Modulo(
    id: 'stock',
    titulo: 'Stock y movimientos',
    icono: Icons.inventory,
    color: _gris,
    seccion: SeccionModulo.inventario,
    pantalla: () => const StockMovimientosScreen(),
  ),
  Modulo(
    id: 'reposicion',
    titulo: 'Reposición y compras',
    icono: Icons.swap_horiz,
    color: _teal,
    seccion: SeccionModulo.inventario,
    pantalla: () => const ReposicionScreen(),
  ),
  Modulo(
    id: 'categorias',
    titulo: 'Categorías',
    icono: Icons.category,
    color: _gris,
    seccion: SeccionModulo.catalogos,
    pantalla: () => const CategoriasListScreen(),
  ),
  Modulo(
    id: 'unidades',
    titulo: 'Unidades de Medida',
    icono: Icons.straighten,
    color: _gris,
    seccion: SeccionModulo.catalogos,
    pantalla: () => const UnidadesListScreen(),
  ),
  Modulo(
    id: 'marcas',
    titulo: 'Marcas',
    icono: Icons.local_offer,
    color: _gris,
    seccion: SeccionModulo.catalogos,
    pantalla: () => const MarcasListScreen(),
  ),
];

/// Módulos de una sección, en el orden de la lista.
List<Modulo> modulosDe(SeccionModulo seccion) =>
    modulos.where((m) => m.seccion == seccion).toList();
