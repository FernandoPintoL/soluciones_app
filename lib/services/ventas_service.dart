import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import '../models/venta_app.dart';
import '../models/venta_listado.dart';
import 'api_errors.dart';
import 'service_locator.dart';

/// Llamadas a la API para la pantalla "Nueva venta".
/// Usa el token de sesión de [apiService] (mismo que el resto de la app).
class VentasService {
  Map<String, String> get _headers => apiService.getHeaders();

  /// Extrae la lista `data` de una respuesta ApiResponse ({success, data}).
  List<dynamic> _listaDesdeRespuesta(dynamic json) {
    if (json is Map && json['data'] is List) return json['data'] as List;
    if (json is Map && json['data'] is Map && json['data']['data'] is List) {
      return json['data']['data'] as List;
    }
    return const [];
  }

  Future<CatalogosVenta> getCatalogos() async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/app/ventas/catalogos'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CatalogosVenta.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<ClienteVenta>> buscarClientes(String q) async {
    final uri = Uri.parse('${EnvConfig.baseUrl}/clientes/buscar')
        .replace(queryParameters: {'q': q, 'limite': '15'});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    return _listaDesdeRespuesta(jsonDecode(response.body))
        .whereType<Map>()
        .map((c) => ClienteVenta.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  /// Listado paginado de clientes (q vacío = todos; con texto filtra). Para scroll infinito.
  Future<({List<ClienteVenta> items, bool hasMore})> listarClientes({
    required int page,
    String q = '',
    int porPagina = 20,
  }) async {
    final uri = Uri.parse('${EnvConfig.baseUrl}/clientes/buscar').replace(
      queryParameters: {'q': q, 'page': '$page', 'limite': '$porPagina'},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body);
    final items = _listaDesdeRespuesta(json)
        .whereType<Map>()
        .map((c) => ClienteVenta.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    final paginacion = json is Map ? json['pagination'] : null;
    final hasMore = paginacion is Map && paginacion['has_more'] == true;
    return (items: items, hasMore: hasMore);
  }

  /// Productos vendibles con precio de VENTA (precio de referencia de la app).
  /// No se envía cliente_id: con ese parámetro el backend usa LICORERIA para el cliente 32.
  /// [exacta] = coincidencia exacta de código de barras / SKU (lo usa el escáner).
  Future<List<ProductoVenta>> buscarProductos(
    String q, {
    bool exacta = false,
  }) async {
    final uri = Uri.parse('${EnvConfig.baseUrl}/app/productos/buscar').replace(
      queryParameters: {
        'q': q,
        'tipo_busqueda': exacta ? 'exacta' : 'parcial',
        'tipo': 'venta',
        'incluir_almacenes_venta': '1',
        'limite': '30',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    return _listaDesdeRespuesta(jsonDecode(response.body))
        .whereType<Map>()
        .map((p) => ProductoVenta.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  Future<List<TipoPagoVenta>> getTiposPago() async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/tipos-pago/activos/listar'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    return _listaDesdeRespuesta(jsonDecode(response.body))
        .whereType<Map>()
        .map((t) => TipoPagoVenta.fromJson(Map<String, dynamic>.from(t)))
        .toList();
  }

  /// Listado paginado de productos de venta, sin texto de búsqueda (scroll infinito).
  Future<({List<ProductoVenta> items, bool hasMore})> listarProductos({
    required int page,
    int porPagina = 20,
  }) async {
    final uri = Uri.parse('${EnvConfig.baseUrl}/app/productos/buscar').replace(
      queryParameters: {
        'q': '',
        'page': '$page',
        'limite': '$porPagina',
        'tipo': 'venta',
        'incluir_almacenes_venta': '1',
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = _listaDesdeRespuesta(json)
        .whereType<Map>()
        .map((p) => ProductoVenta.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    final paginacion = json['pagination'];
    final hasMore = paginacion is Map && paginacion['has_more'] == true;
    return (items: items, hasMore: hasMore);
  }

  /// Listado de ventas con filtros (GET /api/app/ventas), paginado.
  Future<({List<VentaListado> items, bool hasMore})> listarVentas({
    required int page,
    String search = '',
    String? fechaDesde,
    String? fechaHasta,
    String? estadoPago,
    int? tipoPagoId,
    int porPagina = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$porPagina',
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (fechaDesde != null) 'fecha_desde': fechaDesde,
      if (fechaHasta != null) 'fecha_hasta': fechaHasta,
      if (estadoPago != null) 'estado_pago': estadoPago,
      if (tipoPagoId != null) 'tipo_pago_id': '$tipoPagoId',
    };
    final uri = Uri.parse('${EnvConfig.baseUrl}/app/ventas')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = _listaDesdeRespuesta(json)
        .whereType<Map>()
        .map((v) => VentaListado.fromJson(Map<String, dynamic>.from(v)))
        .toList();
    return (items: items, hasMore: json['has_more_pages'] == true);
  }

  /// Detalle de una venta (GET /api/app/ventas/{id}).
  Future<VentaDetalle> getVenta(int id) async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/app/ventas/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return VentaDetalle.fromJson(
      Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  /// Anula una venta (POST /api/app/ventas/{id}/anular). Requiere permiso ventas.anular.
  Future<void> anularVenta(int id, String motivo) async {
    final response = await http.post(
      Uri.parse('${EnvConfig.baseUrl}/app/ventas/$id/anular'),
      headers: _headers,
      body: jsonEncode({'motivo': motivo}),
    );
    if (response.statusCode != 200) {
      throw ApiException(mensajeDeErrorApi(response));
    }
  }

  /// Crédito del cliente: límite y saldo disponible (null si el usuario no puede verlo).
  Future<({double limite, double disponible})?> getCreditoCliente(
    int clienteId,
  ) async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/clientes/$clienteId/credito/detalles'),
      headers: _headers,
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    final data = json is Map ? json['data'] : null;
    final credito = data is Map ? data['credito'] : null;
    if (credito is! Map) return null;
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return (
      limite: d(credito['limite_credito']),
      disponible: d(credito['saldo_disponible']),
    );
  }

  /// Crea la venta. Devuelve los datos de la venta creada (data de la respuesta).
  Future<Map<String, dynamic>> crearVenta(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('${EnvConfig.baseUrl}/app/ventas'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return json is Map && json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{};
    }
    throw ApiException(mensajeDeErrorApi(response));
  }
}

final ventasService = VentasService();
