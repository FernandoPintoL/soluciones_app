import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

class EnvConfig {
  // Getters que leen desde .env (la fuente de verdad)
  static String get appName => dotenv.env['APP_NAME'] ?? 'Distribuidora Paucara';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static bool get appDebug => (dotenv.env['APP_DEBUG'] ?? 'true').toLowerCase() == 'true';

  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://192.168.100.42:8000/api';
  static String get baseUrlWeb => dotenv.env['BASE_URL_WEB'] ?? 'http://192.168.100.42:8000';
  static String get baseUrlImg => dotenv.env['BASE_URL_IMG'] ?? 'http://192.168.100.42:8000/storage/';

  // API Configuration
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30') ?? 30;
  static int get apiRetryCount => int.tryParse(dotenv.env['API_RETRY_COUNT'] ?? '3') ?? 3;

  // Storage Configuration
  static String get storagePath => dotenv.env['STORAGE_PATH'] ?? 'products';
  static bool get cacheEnabled => (dotenv.env['CACHE_ENABLED'] ?? 'true').toLowerCase() == 'true';
  static int get cacheDuration => int.tryParse(dotenv.env['CACHE_DURATION'] ?? '3600') ?? 3600;

  /// Debug helper para verificar configuración (solo en debug)
  static void printConfig() {
    if (appDebug) {
      developer.log(
        '════════════════════════════════════════\n'
        '⚙️  CONFIGURACIÓN CARGADA DEL .env\n'
        '════════════════════════════════════════\n'
        '📱 App: $appName v$appVersion\n'
        '🌐 Base URL: $baseUrl\n'
        '📸 Images URL: $baseUrlImg\n'
        '⏱️  Timeout: ${apiTimeout}s\n'
        '🔄 Retry: $apiRetryCount intentos\n'
        '💾 Cache: ${cacheEnabled ? 'Habilitado' : 'Deshabilitado'}\n'
        '════════════════════════════════════════',
        name: 'EnvConfig',
      );
    }
  }
}
