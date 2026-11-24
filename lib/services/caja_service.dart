import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import '../models/caja_app.dart';
import 'api_errors.dart';
import 'service_locator.dart';

/// Caja del usuario: estado, apertura y cierre (/api/app/caja/*).
class CajaService {
  Map<String, String> get _headers => apiService.getHeaders();

  Map<String, dynamic> _dataOrThrow(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(json['data'] as Map);
  }

  Future<EstadoCaja> estado() async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/app/caja/estado'),
      headers: _headers,
    );
    return EstadoCaja.fromJson(_dataOrThrow(response));
  }

  Future<EstadoCaja> abrir({
    int? cajaId,
    required double efectivo,
    required double transferencia,
    String? observaciones,
  }) async {
    final response = await http.post(
      Uri.parse('${EnvConfig.baseUrl}/app/caja/abrir'),
      headers: _headers,
      body: jsonEncode({
        if (cajaId != null) 'caja_id': cajaId,
        'monto_apertura_efectivo': efectivo,
        'monto_apertura_transferencia': transferencia,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
      }),
    );
    final data = _dataOrThrow(response);
    return EstadoCaja(
      abierta: data['abierta'] == true,
      apertura: data['apertura'] is Map
          ? AperturaCaja.fromJson(
              Map<String, dynamic>.from(data['apertura'] as Map),
            )
          : null,
      cajas: const [],
    );
  }

  Future<ResultadoCierre> cerrar({
    required double montoReal,
    String? observaciones,
  }) async {
    final response = await http.post(
      Uri.parse('${EnvConfig.baseUrl}/app/caja/cerrar'),
      headers: _headers,
      body: jsonEncode({
        'monto_real': montoReal,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
      }),
    );
    return ResultadoCierre.fromJson(_dataOrThrow(response));
  }
}

final cajaService = CajaService();
