import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error devuelto por la API, con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Extrae el mensaje de una respuesta de error de Laravel
/// (`errors` de validación o `message`), o uno genérico con el código HTTP.
String mensajeDeErrorApi(http.Response response) {
  try {
    final json = jsonDecode(response.body);
    if (json is Map) {
      if (json['errors'] is Map) {
        final errores = (json['errors'] as Map).values
            .expand((v) => v is List ? v : [v])
            .toList();
        if (errores.isNotEmpty) return errores.first.toString();
      }
      if (json['message'] != null) return json['message'].toString();
    }
  } catch (_) {}
  return 'Error del servidor (${response.statusCode})';
}
