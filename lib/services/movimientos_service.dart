import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import '../models/movimiento_caja_app.dart';
import 'api_errors.dart';
import 'service_locator.dart';

/// Egresos e ingresos de caja desde la app (misma lógica que la web).
class MovimientosService {
  Map<String, String> get _headers => apiService.getHeaders();

  Future<List<TipoOperacionCaja>> getTiposOperacion() async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/tipos-operacion-caja'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body);
    final data = json is Map ? json['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((t) => TipoOperacionCaja.fromJson(Map<String, dynamic>.from(t)))
        .toList();
  }

  /// Registra un egreso (ingreso = false) o un ingreso (ingreso = true).
  /// Devuelve la respuesta del servidor: numero y total.
  Future<Map<String, dynamic>> registrar({
    required bool ingreso,
    required Map<String, dynamic> payload,
  }) async {
    final ruta = ingreso ? 'app/ingresos' : 'app/egresos';
    final response = await http.post(
      Uri.parse('${EnvConfig.baseUrl}/$ruta'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    throw ApiException(mensajeDeErrorApi(response));
  }
}

final movimientosService = MovimientosService();
