import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}
