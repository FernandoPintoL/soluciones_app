import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/service_locator.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = authService;  // Singleton
  final ApiService _apiService = apiService;      // Singleton

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  Map<String, dynamic>? _user;
  late Future<void> _initFuture;

  // Getters
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get user => _user;

  // Future que se completa cuando la autenticación se carga
  Future<void> get initializationComplete => _initFuture;

  AuthProvider() {
    _initFuture = _checkAuthStatus();
  }

  /// Verificar estado de autenticación al iniciar
  Future<void> _checkAuthStatus() async {
    _isAuthenticated = await _authService.isAuthenticated();
    if (_isAuthenticated) {
      _user = await _authService.getUser();

      // ✅ IMPORTANTE: Si ya está autenticado, recuperar y pasar el token al ApiService
      final token = await _authService.getToken();
      if (token != null) {
        _apiService.setToken(token);
        print('✅ [AuthProvider] Token recuperado en startup: ${token.substring(0, 20)}...');
      }
    }
    notifyListeners();
  }

  /// Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(email, password);

      // ✅ IMPORTANTE: Pasar el token al ApiService
      _apiService.setToken(response.token);
      print('✅ [AuthProvider] Token asignado al ApiService: ${response.token.substring(0, 20)}...');

      _isAuthenticated = true;
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _isAuthenticated = false;
      _user = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Register
  Future<bool> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        name,
        email,
        password,
        passwordConfirmation,
      );

      // ✅ IMPORTANTE: Pasar el token al ApiService
      _apiService.setToken(response.token);
      print('✅ [AuthProvider] Token asignado al ApiService (register): ${response.token.substring(0, 20)}...');

      _isAuthenticated = true;
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Limpiar mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
