import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'config/colores_app.dart';
import 'config/env_config.dart';
import 'providers/auth_provider.dart';
import 'providers/producto_provider.dart';
import 'providers/dropdown_provider.dart';
import 'providers/categoria_provider.dart';
import 'providers/unidad_medida_provider.dart';
import 'providers/marca_provider.dart';
import 'views/splash_screen.dart';

Future<void> main() async {
  // Cargar configuración desde .env (fuente de verdad)
  await dotenv.load(fileName: '.env');

  // Debug: Imprimir configuración cargada
  EnvConfig.printConfig();

  runApp(const MyApp());
}

/// Estilo plano: sin sombras, tarjetas con borde fino y esquinas redondeadas,
/// barra superior sin elevación.
ThemeData _temaPlano(Brightness brillo) {
  final esquema = ColorScheme.fromSeed(
    seedColor: AppColores.azul,
    brightness: brillo,
  );
  return ThemeData(
    colorScheme: esquema,
    useMaterial3: true,
    scaffoldBackgroundColor: brillo == Brightness.light
        ? AppColores.fondo
        : esquema.surface,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: esquema.surface,
      foregroundColor: esquema.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: esquema.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: esquema.outlineVariant),
    // Menú lateral plano: fondo de superficie, sin sombra, esquina derecha redondeada
    drawerTheme: DrawerThemeData(
      backgroundColor: esquema.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      width: 300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
    ),
    // Botones planos y con esquinas redondeadas
    filledButtonTheme: FilledButtonThemeData(style: _estiloBoton(radio: 12)),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _estiloBoton(radio: 12),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _estiloBoton(radio: 12),
    ),
    textButtonTheme: TextButtonThemeData(style: _estiloBoton(radio: 12)),
    // Campos de texto: relleno suave, borde fino, sin subrayado
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainerHighest,
      border: _bordeCampo(esquema.outlineVariant),
      enabledBorder: _bordeCampo(esquema.outlineVariant),
      disabledBorder: _bordeCampo(esquema.outlineVariant),
      focusedBorder: _bordeCampo(esquema.primary, grosor: 1.5),
      errorBorder: _bordeCampo(esquema.error),
      focusedErrorBorder: _bordeCampo(esquema.error, grosor: 1.5),
    ),
    // Diálogos y hojas: sin sombra, esquinas redondeadas
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: esquema.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      backgroundColor: esquema.surface,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 0,
      highlightElevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      elevation: 0,
      color: esquema.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
  );
}

ButtonStyle _estiloBoton({required double radio}) {
  return ButtonStyle(
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radio)),
    ),
  );
}

OutlineInputBorder _bordeCampo(Color color, {double grosor = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: grosor),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductoProvider()),
        ChangeNotifierProvider(create: (_) => DropdownProvider()),
        ChangeNotifierProvider(create: (_) => CategoriaProvider()),
        ChangeNotifierProvider(create: (_) => UnidadMedidaProvider()),
        ChangeNotifierProvider(create: (_) => MarcaProvider()),
      ],
      child: MaterialApp(
        title: EnvConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: _temaPlano(Brightness.light),
        darkTheme: _temaPlano(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}
