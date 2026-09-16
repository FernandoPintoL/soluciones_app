import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import '../models/login_response.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  /// Login con email/usernick y contraseña
  Future<LoginResponse> login(String email, String password) async {
    try {
      final loginData = {
        'login': email,  // El backend acepta email O usernick
        'password': password,
      };

      print('🚀 [AuthService] Iniciando login');
      print('📤 [AuthService] URL: ${EnvConfig.baseUrl}/login');
      print('📤 [AuthService] Enviando: ${jsonEncode(loginData)}');

      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(loginData),
      );

      print('📥 [AuthService] Status Code: ${response.statusCode}');
      print('📥 [AuthService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('✅ [AuthService] Login exitoso');
        print('✅ [AuthService] Datos parseados: $json');

        final loginResponse = LoginResponse.fromJson(json);

        // Guardar token y usuario
        await _saveToken(loginResponse.token);
        await _saveUser(loginResponse.user);

        return loginResponse;
      } else if (response.statusCode == 401) {
        print('❌ [AuthService] Error 401: Credenciales inválidas');
        throw Exception('Credenciales inválidas');
      } else if (response.statusCode == 422) {
        final json = jsonDecode(response.body);
        print('❌ [AuthService] Error 422: ${json['message']}');
        throw Exception(json['message'] ?? 'Error de validación');
      } else {
        print('❌ [AuthService] Error ${response.statusCode}');
        throw Exception('Error de login: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AuthService] Excepción: $e');
      throw Exception('Error: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      final token = await getToken();
      await http.post(
        Uri.parse('${EnvConfig.baseUrl}/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      // Ignorar errores de logout en servidor
    }
    // Limpiar datos locales
    await _clearAuth();
  }

  /// Registrar nuevo usuario
  Future<LoginResponse> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(json);

        await _saveToken(loginResponse.token);
        await _saveUser(loginResponse.user);

        return loginResponse;
      } else if (response.statusCode == 422) {
        final json = jsonDecode(response.body);
        throw Exception(json['message'] ?? 'Error de validación');
      } else {
        throw Exception('Error al registrar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Guardar token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Guardar usuario
  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Obtener token guardado
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Obtener usuario guardado
  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  /// Verificar si está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Limpiar datos de autenticación
  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
