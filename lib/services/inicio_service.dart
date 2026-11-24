import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import '../models/indicadores_menu.dart';
import '../models/inicio_resumen.dart';
import 'api_errors.dart';
import 'service_locator.dart';

/// Datos de la pantalla de inicio.
class InicioService {
  Future<ResumenInicio> getResumen() async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/app/inicio'),
      headers: apiService.getHeaders(),
    );
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ResumenInicio.fromJson(
      Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  /// Indicadores del menú lateral: caja abierta y productos con stock bajo.
  Future<IndicadoresMenu> getIndicadores() async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/app/indicadores'),
      headers: apiService.getHeaders(),
    );
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return IndicadoresMenu.fromJson(
      Map<String, dynamic>.from(json['data'] as Map),
    );
  }
}

final inicioService = InicioService();
