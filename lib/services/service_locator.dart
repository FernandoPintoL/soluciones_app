import 'api_service.dart';
import 'auth_service.dart';

/// Instancias singleton de los servicios
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();

  late final ApiService _apiService;
  late final AuthService _authService;

  factory ServiceLocator() {
    return _instance;
  }

  ServiceLocator._internal() {
    _apiService = ApiService();
    _authService = AuthService();
  }

  ApiService get apiService => _apiService;
  AuthService get authService => _authService;
}

// Acceso rápido a los servicios
final serviceLocator = ServiceLocator();
final apiService = serviceLocator.apiService;
final authService = serviceLocator.authService;
