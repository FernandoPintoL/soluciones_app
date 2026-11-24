import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colores_app.dart';
import '../config/env_config.dart';
import '../config/modulos.dart';
import '../models/indicadores_menu.dart';
import '../providers/auth_provider.dart';
import '../services/inicio_service.dart';
import '../views/splash_screen.dart';

/// Menú lateral. Las opciones salen de [modulos] (config/modulos.dart).
/// Muestra indicadores: estado de la caja y productos con stock bajo.
class AppDrawer extends StatefulWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  IndicadoresMenu? _indicadores;

  @override
  void initState() {
    super.initState();
    _cargarIndicadores();
  }

  /// Si falla, el menú se muestra sin indicadores.
  Future<void> _cargarIndicadores() async {
    try {
      final i = await inicioService.getIndicadores();
      if (mounted) setState(() => _indicadores = i);
    } catch (_) {
      // Sin indicadores: el menú funciona igual
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final usuario = context.watch<AuthProvider>().user?['name']?.toString();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _encabezado(context, usuario),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  _seccion(context, 'OPERACIÓN', SeccionModulo.operacion),
                  _seccion(context, 'INVENTARIO', SeccionModulo.inventario),
                  _seccion(context, 'CATÁLOGOS', SeccionModulo.catalogos),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _ItemMenu(
                icono: Icons.logout,
                titulo: 'Cerrar sesión',
                color: colores.error,
                onTap: () => _handleLogout(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Versión ${EnvConfig.appVersion}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colores.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Logo, nombre del sistema y usuario conectado.
  Widget _encabezado(BuildContext context, String? usuario) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      color: colores.primaryContainer,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icons/icon.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventario',
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colores.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  usuario == null || usuario.isEmpty
                      ? 'Menú principal'
                      : usuario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: colores.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(BuildContext context, String titulo, SeccionModulo seccion) {
    final modulosSeccion = modulosDe(seccion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
          child: Text(
            titulo,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final m in modulosSeccion) _opcion(context, m),
      ],
    );
  }

  /// Una opción del menú, con su indicador si le corresponde.
  Widget _opcion(BuildContext context, Modulo m) {
    final i = _indicadores;
    String? subtitulo;
    int? badge;

    if (i != null && m.id == 'caja') {
      subtitulo = i.cajaAbierta
          ? 'Abierta · Bs ${i.efectivoEnCaja.toStringAsFixed(2)} en efectivo'
          : 'Sin caja abierta';
    }
    if (i != null && m.id == 'productos' && i.stockBajo > 0) {
      badge = i.stockBajo;
    }

    return _ItemMenu(
      icono: m.icono,
      titulo: m.titulo,
      color: m.color,
      activo: widget.currentRoute == m.id,
      subtitulo: subtitulo,
      badge: badge,
      onTap: () => _navigateTo(context, m.pantalla(), m.id),
    );
  }

  void _navigateTo(BuildContext context, Widget screen, String route) {
    Navigator.pop(context); // Cerrar drawer

    // Si ya estamos en esa pantalla, no hacer nada
    if (widget.currentRoute == route) return;

    // El Inicio es la raíz de la navegación: elegirlo vuelve a la raíz,
    // y el resto de pantallas se apila sobre el Inicio. Así "atrás" regresa
    // al Inicio y no cierra la app.
    if (route == 'inicio') {
      Navigator.popUntil(context, (r) => r.isFirst);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (r) => r.isFirst,
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Capturar AuthProvider y Navigator antes del diálogo: el context puede desmontarse
    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    // Cerrar el drawer
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await authProvider.logout();
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      } catch (e) {
        debugPrint('Error en logout: $e');
      }
    }
  }
}

/// Opción del menú: icono en recuadro de color, texto, subtítulo opcional y contador opcional.
class _ItemMenu extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Color color;
  final bool activo;
  final String? subtitulo;
  final int? badge;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.icono,
    required this.titulo,
    required this.color,
    required this.onTap,
    this.activo = false,
    this.subtitulo,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final estado = AppColores.estado(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: activo ? colores.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontWeight: activo
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: activo
                              ? colores.onSecondaryContainer
                              : colores.onSurface,
                        ),
                      ),
                      if (subtitulo != null)
                        Text(
                          subtitulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: subtitulo!.startsWith('Abierta')
                                ? estado.verde
                                : colores.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColores.rojo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
