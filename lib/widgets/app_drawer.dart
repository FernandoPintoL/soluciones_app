import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../views/productos_list_screen.dart';
import '../views/categorias_list_screen.dart';
import '../views/unidades_list_screen.dart';
import '../views/marcas_list_screen.dart';
import '../views/splash_screen.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Inventario',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Menú Principal',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // 📦 Productos
          _DrawerItem(
            icon: Icons.shopping_bag,
            title: 'Productos',
            isActive: currentRoute == 'productos',
            onTap: () => _navigateTo(context, const ProductosListScreen(), 'productos'),
          ),

          const Divider(),

          // 🏷️ Gestión de Catálogos
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'CATÁLOGOS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),

          // 📂 Categorías
          _DrawerItem(
            icon: Icons.category,
            title: 'Categorías',
            isActive: currentRoute == 'categorias',
            onTap: () => _navigateTo(context, const CategoriasListScreen(), 'categorias'),
          ),

          // 📏 Unidades de Medida
          _DrawerItem(
            icon: Icons.straighten,
            title: 'Unidades de Medida',
            isActive: currentRoute == 'unidades',
            onTap: () => _navigateTo(context, const UnidadesListScreen(), 'unidades'),
          ),

          // 🏷️ Marcas
          _DrawerItem(
            icon: Icons.local_offer,
            title: 'Marcas',
            isActive: currentRoute == 'marcas',
            onTap: () => _navigateTo(context, const MarcasListScreen(), 'marcas'),
          ),

          const Divider(),

          // 🚪 Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'SESIÓN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),

          _DrawerItem(
            icon: Icons.logout,
            title: 'Cerrar Sesión',
            color: Theme.of(context).colorScheme.error,
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen, String route) {
    Navigator.pop(context); // Cerrar drawer

    // Si ya estamos en esa pantalla, no hacer nada
    if (currentRoute == route) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    print('🚪 [AppDrawer] onTap EJECUTADO - _handleLogout llamado');

    // ⭐ IMPORTANTE: Capturar AuthProvider y Navigator ANTES del diálogo
    // porque el context podría desmontarse durante el showDialog
    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    // Cerrar el drawer
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      print('🚪 [AppDrawer] Drawer cerrado');
    }

    // Mostrar diálogo de confirmación
    print('🚪 [AppDrawer] Mostrando diálogo de confirmación');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () {
              print('🚪 [AppDrawer] Cancelar presionado');
              Navigator.pop(context, false);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              print('🚪 [AppDrawer] Confirmar logout presionado');
              Navigator.pop(context, true);
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    print('🚪 [AppDrawer] Diálogo cerrado, confirmado: $confirmed');

    if (confirmed == true) {
      print('🚪 [AppDrawer] Iniciando logout...');
      try {
        await authProvider.logout();
        print('✅ [AppDrawer] Logout completado');

        print('🚪 [AppDrawer] Navegando a SplashScreen');
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
        print('✅ [AppDrawer] Navegación completada');
      } catch (e) {
        print('❌ [AppDrawer] Error en logout: $e');
      }
    } else {
      print('🚪 [AppDrawer] Logout cancelado por el usuario');
    }
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.isActive = false,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : color,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      ),
      selected: isActive,
      onTap: onTap,
    );
  }
}
