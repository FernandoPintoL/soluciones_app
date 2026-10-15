import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/unidad_medida.dart';
import '../models/marca.dart';

class ApiService {
  String? _token;
  Map<String, dynamic>? _lastPaginationInfo;

  // Setter para el token
  void setToken(String token) {
    _token = token;
  }

  // Obtener último info de paginación
  Map<String, dynamic>? getPaginationInfo() {
    return _lastPaginationInfo;
  }

  // Obtener headers con autenticación (privado)
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // 🔥 NUEVO: Getter público para headers (accesible desde UI)
  Map<String, String> getHeaders() => _getHeaders();

  // ============== PRODUCTOS ==============

  /// Obtener lista de productos (TODOS sin filtros de empresa/almacén)
  Future<List<Producto>> getProductos({int page = 1, int limit = 20}) async {
    try {
      // Usar endpoint -all para obtener TODOS los productos sin filtros
      final url = '${EnvConfig.baseUrl}/app/productos-all?page=$page&per_page=$limit';
      print('🚀 [ApiService] GET: $url');
      print('📤 [ApiService] Headers: ${_getHeaders()}');

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status Code: ${response.statusCode}');
      print('📥 [ApiService] Response: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // La respuesta tiene estructura anidada: {data: {data: [...], current_page, last_page, total}}
        final List<dynamic> data = json['data']['data'] ?? [];

        // ✅ Guardar info de paginación
        _lastPaginationInfo = {
          'current_page': json['data']['current_page'] ?? 1,
          'last_page': json['data']['last_page'] ?? 1,
          'total': json['data']['total'] ?? 0,
          'per_page': json['data']['per_page'] ?? 20,
        };
        print('✅ [ApiService] Paginación: ${_lastPaginationInfo}');

        print('✅ [ApiService] Productos cargados: ${data.length}');
        return data.map((p) => Producto.fromJson(p)).toList();
      } else if (response.statusCode == 401) {
        print('❌ [ApiService] Error 401: No autorizado');
        throw Exception('No autorizado');
      } else {
        print('❌ [ApiService] Error ${response.statusCode}');
        throw Exception('Error al cargar productos: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ApiService] Excepción: $e');
      throw Exception('Error: $e');
    }
  }

  /// Obtener un producto por ID
  Future<Producto> getProductoById(int id) async {
    try {
      print('🔍 [ApiService] Obteniendo producto: $id');
      final response = await http.get(
        Uri.parse('${EnvConfig.baseUrl}/app/productos/$id'),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');
      print('📥 [ApiService] Response completa: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('📥 [ApiService] json[data] type: ${json['data'].runtimeType}');
        print('📥 [ApiService] json[data] keys: ${json['data'] is Map ? json['data'].keys : 'N/A'}');

        // Manejar estructura anidada
        var productData;

        if (json['data'] is Map) {
          // Si data es un Map, podría ser {data: [...], current_page: ...} o {id: ..., nombre: ...}
          final dataValue = json['data'];
          print('📥 [ApiService] dataValue[stock]: ${dataValue['stock']}');
          print('📥 [ApiService] dataValue[stocks]: ${dataValue['stocks']}');

          if (dataValue['data'] is List && dataValue['data'].isNotEmpty) {
            // Estructura paginada: tomar el primer elemento
            productData = dataValue['data'].first;
            print('📥 [ApiService] Usando estructura paginada');
          } else if (dataValue['id'] != null) {
            // Estructura simple: el producto está directamente en data
            productData = dataValue;
            print('📥 [ApiService] Usando estructura simple (id=${dataValue['id']})');
          }
        } else if (json['data'] is List && json['data'].isNotEmpty) {
          // Si data es un array, tomar el primero
          productData = json['data'].first;
          print('📥 [ApiService] Usando estructura array');
        } else {
          productData = json;
          print('📥 [ApiService] Usando json completo');
        }

        print('✅ [ApiService] Producto obtenido con ${productData['stock']?.length ?? 0} stocks');
        return Producto.fromJson(productData ?? json);
      } else {
        throw Exception('Error al cargar producto: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Crear nuevo producto
  Future<Producto> createProducto(Producto producto) async {
    try {
      final url = '${EnvConfig.baseUrl}/app/productos';
      final body = producto.toJson();
      final bodyJson = jsonEncode(body);

      print('🚀 [ApiService CREATE] ============================================');
      print('🚀 [ApiService CREATE] ENVIANDO NUEVO PRODUCTO');
      print('🚀 [ApiService CREATE] URL: POST $url');
      print('📤 [ApiService CREATE] DATOS ENVIADOS:');
      print('📤 [ApiService CREATE] ${jsonEncode(body)}');
      print('🚀 [ApiService CREATE] ============================================');

      final response = await http.post(
        Uri.parse(url),
        headers: _getHeaders(),
        body: bodyJson,
      );

      print('📥 [ApiService CREATE] ============================================');
      print('📥 [ApiService CREATE] RESPUESTA RECIBIDA');
      print('📥 [ApiService CREATE] Status: ${response.statusCode}');
      print('📥 [ApiService CREATE] DATOS: ${response.body}');
      print('📥 [ApiService CREATE] ============================================');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Manejar estructura anidada
        final productData = json['data'] is Map ? (json['data']['data'] ?? json['data']) : json['data'];
        print('✅ [ApiService CREATE] Producto creado exitosamente (ID: ${productData['id']})');
        return Producto.fromJson(productData ?? json);
      } else if (response.statusCode == 422) {
        final json = jsonDecode(response.body);
        print('❌ [ApiService CREATE] Error de validación: ${json['message']}');
        print('❌ [ApiService CREATE] Errores: ${json['errors'] ?? 'No especificados'}');
        throw Exception(json['message'] ?? 'Error de validación');
      } else {
        print('❌ [ApiService CREATE] Error HTTP ${response.statusCode}');
        throw Exception('Error al crear producto: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ApiService CREATE] Excepción: $e');
      throw Exception('Error: $e');
    }
  }

  /// Actualizar producto
  Future<Producto> updateProducto(int id, Producto producto) async {
    try {
      final url = '${EnvConfig.baseUrl}/app/productos/$id';
      final body = producto.toJson();
      final bodyJson = jsonEncode(body);

      print('🔄 [ApiService UPDATE] ============================================');
      print('🔄 [ApiService UPDATE] ACTUALIZANDO PRODUCTO');
      print('🔄 [ApiService UPDATE] URL: PUT $url');
      print('📤 [ApiService UPDATE] DATOS ENVIADOS:');
      print('📤 [ApiService UPDATE] ${jsonEncode(body)}');
      print('🔄 [ApiService UPDATE] ============================================');

      final response = await http.put(
        Uri.parse(url),
        headers: _getHeaders(),
        body: bodyJson,
      );

      print('📥 [ApiService UPDATE] ============================================');
      print('📥 [ApiService UPDATE] RESPUESTA RECIBIDA');
      print('📥 [ApiService UPDATE] Status: ${response.statusCode}');
      print('📥 [ApiService UPDATE] DATOS: ${response.body}');
      print('📥 [ApiService UPDATE] ============================================');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Manejar estructura anidada
        final productData = json['data'] is Map ? (json['data']['data'] ?? json['data']) : json['data'];
        print('✅ [ApiService UPDATE] Producto actualizado exitosamente (ID: $id)');
        return Producto.fromJson(productData ?? json);
      } else if (response.statusCode == 422) {
        final json = jsonDecode(response.body);
        print('❌ [ApiService UPDATE] Error de validación: ${json['message']}');
        print('❌ [ApiService UPDATE] Errores: ${json['errors'] ?? 'No especificados'}');
        throw Exception(json['message'] ?? 'Error de validación');
      } else {
        print('❌ [ApiService UPDATE] Error HTTP ${response.statusCode}');
        throw Exception('Error al actualizar producto: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ApiService UPDATE] Excepción: $e');
      throw Exception('Error: $e');
    }
  }

  /// Eliminar producto
  Future<void> deleteProducto(int id) async {
    try {
      final url = '${EnvConfig.baseUrl}/app/productos/$id';

      print('🗑️ [ApiService DELETE] ============================================');
      print('🗑️ [ApiService DELETE] ELIMINANDO PRODUCTO');
      print('🗑️ [ApiService DELETE] URL: DELETE $url');
      print('🗑️ [ApiService DELETE] ============================================');

      final response = await http.delete(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      print('📥 [ApiService DELETE] ============================================');
      print('📥 [ApiService DELETE] RESPUESTA RECIBIDA');
      print('📥 [ApiService DELETE] Status: ${response.statusCode}');
      print('📥 [ApiService DELETE] DATOS: ${response.body}');
      print('📥 [ApiService DELETE] ============================================');

      if (response.statusCode != 200 && response.statusCode != 204) {
        print('❌ [ApiService DELETE] Error HTTP ${response.statusCode}');
        throw Exception('Error al eliminar producto: ${response.statusCode}');
      }
      print('✅ [ApiService DELETE] Producto eliminado exitosamente (ID: $id)');
    } catch (e) {
      print('❌ [ApiService DELETE] Excepción: $e');
      throw Exception('Error: $e');
    }
  }

  /// Buscar productos
  Future<List<Producto>> searchProductos(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${EnvConfig.baseUrl}/app/productos/buscar?q=$query'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Manejar estructura anidada
        final List<dynamic> data = json['data'] is Map
          ? (json['data']['data'] ?? [])
          : (json['data'] ?? []);
        return data.map((p) => Producto.fromJson(p)).toList();
      } else {
        throw Exception('Error en búsqueda: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Obtener stocks de un producto
  Future<List<Map<String, dynamic>>> getProductoStocks(int productoId) async {
    try {
      print('📦 [ApiService] Cargando stocks del producto: $productoId');
      final response = await http.get(
        Uri.parse('${EnvConfig.baseUrl}/inventario/stocks?producto_id=$productoId'),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('📥 [ApiService] Response stocks: ${response.body}');

        // Manejar estructura anidada
        List<dynamic> stocksData = [];
        if (json['data'] is List) {
          stocksData = json['data'];
        } else if (json['data'] is Map && json['data']['data'] is List) {
          stocksData = json['data']['data'];
        }

        final stocks = stocksData.map<Map<String, dynamic>>((stock) {
          if (stock is! Map) return {};

          final cantidad = stock['cantidad'] ?? stock['stock_cantidad'] ?? 0;
          final cantidadDisponible = stock['cantidad_disponible'] ?? stock['stock_cantidad'] ?? 0;

          // Convertir cantidad a int de forma segura
          int cantidadInt = 0;
          if (cantidad is int) {
            cantidadInt = cantidad;
          } else if (cantidad is double) {
            cantidadInt = cantidad.toInt();
          } else if (cantidad is String) {
            cantidadInt = (double.tryParse(cantidad) ?? 0).toInt();
          }

          int cantidadDisponibleInt = 0;
          if (cantidadDisponible is int) {
            cantidadDisponibleInt = cantidadDisponible;
          } else if (cantidadDisponible is double) {
            cantidadDisponibleInt = cantidadDisponible.toInt();
          } else if (cantidadDisponible is String) {
            cantidadDisponibleInt = (double.tryParse(cantidadDisponible) ?? 0).toInt();
          }

          return {
            'id': stock['id'],
            'almacen_id': stock['almacen_id'],
            'sector_id': stock['sector_id'],
            'cantidad': cantidadInt,
            'cantidad_disponible': cantidadDisponibleInt,
            'lote': stock['lote'],
            'fecha_vencimiento': stock['fecha_vencimiento'],
            'almacen_nombre': stock['almacen'] != null ? stock['almacen']['nombre'] as String : 'Almacén ${stock['almacen_id']}',
            'sector_nombre': stock['sector'] != null ? stock['sector']['nombre'] as String : 'Sector ${stock['sector_id']}',
          };
        }).toList();

        print('✅ [ApiService] Stocks cargados: ${stocks.length}');
        return stocks;
      } else {
        print('⚠️ [ApiService] No se encontraron stocks: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [ApiService] Error cargando stocks: $e');
      return [];
    }
  }

  /// Buscar producto por código de barra
  Future<Producto?> searchProductoByCodigoBarras(String codigoBarras) async {
    try {
      print('🔍 [ApiService] Buscando producto con código: $codigoBarras');
      final response = await http.get(
        Uri.parse('${EnvConfig.baseUrl}/app/productos/buscar-codigo-barras?codigo=$codigoBarras'),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');
      print('📥 [ApiService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Limpiar la respuesta en caso de que tenga prefijos
        String cleanBody = response.body;
        // Si la respuesta comienza con caracteres no JSON, buscar el inicio del JSON
        final jsonStart = cleanBody.indexOf('{');
        if (jsonStart > 0) {
          cleanBody = cleanBody.substring(jsonStart);
        }

        final json = jsonDecode(cleanBody);

        if (json['success'] == true && json['data'] != null) {
          final productData = json['data'] is Map
            ? (json['data'] is Map && json['data']['data'] != null ? json['data']['data'] : json['data'])
            : json['data'];
          print('✅ [ApiService] Producto encontrado: ${productData['nombre'] ?? 'Sin nombre'}');
          return Producto.fromJson(productData);
        } else if (json['success'] == false) {
          print('⚠️ [ApiService] ${json['message'] ?? 'Producto no encontrado'}');
          return null;
        }
        return null;
      } else if (response.statusCode == 404) {
        print('⚠️ [ApiService] Producto no encontrado (404)');
        return null;
      } else {
        throw Exception('Error en búsqueda: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Productos que pueden ser hijo de un fraccionamiento (busca por ID, SKU,
  /// nombre o código de barras). Cada item trae id, nombre, sku,
  /// unidad_medida_id y unidad_nombre.
  Future<List<Map<String, dynamic>>> buscarProductosParaFraccionar(
    String termino,
  ) async {
    final response = await http.get(
      Uri.parse('${EnvConfig.baseUrl}/app/fraccionamientos/productos-disponibles')
          .replace(queryParameters: {'search': termino}),
      headers: _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Error buscando productos: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    final data = json is Map ? json['data'] : null;
    return data is List
        ? data.whereType<Map>().map((p) => Map<String, dynamic>.from(p)).toList()
        : [];
  }

  /// Factores de conversión típicos entre dos unidades (ej. KG → G = 1000).
  /// Devuelve el factor más común, o null si no hay sugerencia.
  Future<double?> factorConversionSugerido(
    int unidadBaseId,
    int unidadDestinoId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${EnvConfig.baseUrl}/productos/conversiones/comunes').replace(
          queryParameters: {
            'unidad_base_id': '$unidadBaseId',
            'unidad_destino_id': '$unidadDestinoId',
          },
        ),
        headers: _getHeaders(),
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      final data = json is Map && json['success'] == true ? json['data'] : null;
      if (data is List && data.isNotEmpty && data.first is Map) {
        return num.tryParse(data.first['factor_conversion'].toString())
            ?.toDouble();
      }
    } catch (e) {
      print('⚠️ [ApiService] Sin factor sugerido: $e');
    }
    return null;
  }

  // Crear stock de producto
  /// Eliminar un lote (registro de stock_productos) en el servidor.
  /// Solo se permite si el lote está en 0 (soft delete: su historial se conserva).
  /// Devuelve null si se eliminó, o el mensaje de error del servidor.
  /// Con [forzar] = true también elimina un lote con stock: el servidor registra antes
  /// una salida de ajuste que lo deja en 0 (lo reservado nunca se elimina).
  Future<String?> eliminarStockProducto(int stockProductoId, {bool forzar = false}) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '${EnvConfig.baseUrl}/app/productos/stock/$stockProductoId${forzar ? '?forzar=1' : ''}',
        ),
        headers: _getHeaders(),
      );

      print('📥 [ApiService DELETE STOCK] Status: ${response.statusCode}');
      print('📥 [ApiService DELETE STOCK] Response: ${response.body}');

      if (response.statusCode == 200) {
        return null;
      }
      try {
        final json = jsonDecode(response.body);
        return json['message']?.toString() ?? 'Error al eliminar el lote';
      } catch (_) {
        return 'Error al eliminar el lote (${response.statusCode})';
      }
    } catch (e) {
      print('❌ [ApiService DELETE STOCK] Excepción: $e');
      return 'Error de conexión al eliminar el lote';
    }
  }

  Future<bool> crearStockProducto(
    int productoId,
    int almacenId,
    int sectorId,
    int cantidad, {
    String? lote,
    String? fechaVencimiento,
  }) async {
    try {
      print('🔄 [ApiService CREATE STOCK] URL: ${EnvConfig.baseUrl}/inventario/crear-stock-producto');

      final body = {
        'producto_id': productoId,
        'almacen_id': almacenId,
        'sector_id': sectorId,
        'cantidad': cantidad,
        'lote': lote,
        'fecha_vencimiento': fechaVencimiento,
      };

      print('📤 [ApiService CREATE STOCK] Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/inventario/crear-stock-producto'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      print('📥 [ApiService CREATE STOCK] Status: ${response.statusCode}');
      print('📥 [ApiService CREATE STOCK] Response: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ [ApiService CREATE STOCK] Éxito');
        return true;
      } else {
        print('❌ [ApiService CREATE STOCK] Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ [ApiService CREATE STOCK] Error: $e');
      return false;
    }
  }

  // Crear código de barra para producto
  Future<bool> crearCodigoBarraProducto(
    int productoId,
    String codigo, {
    bool esPrincipal = true,
  }) async {
    try {
      print('📛 [ApiService CREATE BARCODE] URL: ${EnvConfig.baseUrl}/app/productos/$productoId/codigos-barra');

      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/app/productos/$productoId/codigos-barra'),
        headers: _getHeaders(),
        body: jsonEncode({
          'codigo': codigo,
          'es_principal': esPrincipal ? 1 : 0,
        }),
      );

      print('📥 [ApiService CREATE BARCODE] Status: ${response.statusCode}');
      print('📥 [ApiService CREATE BARCODE] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [ApiService CREATE BARCODE] Código de barra creado exitosamente');
        return true;
      } else {
        print('⚠️ [ApiService CREATE BARCODE] Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ [ApiService CREATE BARCODE] Error: $e');
      return false;
    }
  }

  // Eliminar todos los códigos de barra de un producto
  Future<bool> eliminarCodigosBarraProducto(int productoId) async {
    try {
      print('🗑️ [ApiService DELETE BARCODE] URL: ${EnvConfig.baseUrl}/app/productos/$productoId/codigos-barra');

      final response = await http.delete(
        Uri.parse('${EnvConfig.baseUrl}/app/productos/$productoId/codigos-barra'),
        headers: _getHeaders(),
      );

      print('📥 [ApiService DELETE BARCODE] Status: ${response.statusCode}');
      print('📥 [ApiService DELETE BARCODE] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ [ApiService DELETE BARCODE] Códigos de barra eliminados exitosamente');
        return true;
      } else {
        print('⚠️ [ApiService DELETE BARCODE] Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ [ApiService DELETE BARCODE] Error: $e');
      return false;
    }
  }

  // Subir imagen de producto
  Future<bool> uploadImagenProducto(
    int productoId,
    String imagePath, {
    bool esPrincipal = true,
    int orden = 0,
  }) async {
    try {
      print('🖼️ [ApiService] Subiendo imagen para producto $productoId');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${EnvConfig.baseUrl}/app/productos/$productoId/imagenes'),
      );

      // Agregar headers de autenticación
      request.headers.addAll(_getHeaders());

      // Agregar archivo
      request.files.add(
        await http.MultipartFile.fromPath('imagen', imagePath),
      );

      // Agregar parámetros
      request.fields['es_principal'] = esPrincipal ? '1' : '0';
      request.fields['orden'] = orden.toString();

      print('📤 [ApiService] Enviando multipart request');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 [ApiService] Status: ${response.statusCode}');
      print('📥 [ApiService] Response: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [ApiService] Imagen subida correctamente');
        return true;
      } else {
        print('❌ [ApiService] Error subiendo imagen: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      return false;
    }
  }

  // ==========================================
  // 📝 CATEGORÍAS CRUD
  // ==========================================

  /// Obtener categorías con paginación
  Future<Map<String, dynamic>> getCategorias({
    int page = 1,
    int perPage = 20,
    String search = '',
  }) async {
    try {
      print('🔄 [ApiService] Obteniendo categorías...');

      final url =
          '${EnvConfig.baseUrl}/app/categorias-crud?page=$page&per_page=$perPage';
      final queryUrl = search.isNotEmpty ? '$url&q=$search' : url;

      final response = await http.get(
        Uri.parse(queryUrl),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] as Map<String, dynamic>;

        return {
          'categorias': (data['data'] as List)
              .map((c) => Categoria.fromJson(c))
              .toList(),
          'pagination': {
            'current_page': data['current_page'],
            'last_page': data['last_page'],
            'total': data['total'],
            'per_page': data['per_page'],
          }
        };
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Crear categoría
  Future<Categoria> createCategoria(Categoria categoria) async {
    try {
      print('🚀 [ApiService] Creando categoría: ${categoria.nombre}');

      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/app/categorias-crud'),
        headers: _getHeaders(),
        body: jsonEncode(categoria.toJson()),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return Categoria.fromJson(json['data']);
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Actualizar categoría
  Future<Categoria> updateCategoria(int id, Categoria categoria) async {
    try {
      print('🔄 [ApiService] Actualizando categoría: $id');

      final response = await http.put(
        Uri.parse('${EnvConfig.baseUrl}/app/categorias-crud/$id'),
        headers: _getHeaders(),
        body: jsonEncode(categoria.toJson()),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Categoria.fromJson(json['data']);
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Eliminar categoría
  Future<bool> deleteCategoria(int id) async {
    try {
      print('🗑️ [ApiService] Eliminando categoría: $id');

      final response = await http.delete(
        Uri.parse('${EnvConfig.baseUrl}/app/categorias-crud/$id'),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ [ApiService] Categoría eliminada');
        return true;
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  // ======================== UNIDADES DE MEDIDA ========================

  /// Obtener unidades de medida con paginación
  Future<Map<String, dynamic>> getUnidadesMedida({
    int page = 1,
    int perPage = 20,
    String search = '',
  }) async {
    try {
      print('🔄 [ApiService] Obteniendo unidades de medida...');

      final url =
          '${EnvConfig.baseUrl}/app/unidades-medida?page=$page&per_page=$perPage';
      final queryUrl = search.isNotEmpty ? '$url&q=$search' : url;

      final response = await http.get(
        Uri.parse(queryUrl),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] as Map<String, dynamic>;

        // Importar UnidadMedida en la parte superior
        return {
          'unidades': (data['data'] as List)
              .map((u) => UnidadMedida.fromJson(u))
              .toList(),
          'pagination': {
            'current_page': data['current_page'],
            'last_page': data['last_page'],
            'total': data['total'],
            'per_page': data['per_page'],
          }
        };
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Crear unidad de medida
  Future<UnidadMedida> createUnidadMedida(UnidadMedida unidad) async {
    try {
      print('🚀 [ApiService] Creando unidad: ${unidad.nombre}');

      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/app/unidades-medida'),
        headers: _getHeaders(),
        body: jsonEncode(unidad.toJson()),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return UnidadMedida.fromJson(json['data']);
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Actualizar unidad de medida
  Future<UnidadMedida> updateUnidadMedida(int id, UnidadMedida unidad) async {
    try {
      print('🔄 [ApiService] Actualizando unidad: $id');

      final response = await http.put(
        Uri.parse('${EnvConfig.baseUrl}/app/unidades-medida/$id'),
        headers: _getHeaders(),
        body: jsonEncode(unidad.toJson()),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return UnidadMedida.fromJson(json['data']);
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Eliminar unidad de medida
  Future<bool> deleteUnidadMedida(int id) async {
    try {
      print('🗑️ [ApiService] Eliminando unidad: $id');

      final response = await http.delete(
        Uri.parse('${EnvConfig.baseUrl}/app/unidades-medida/$id'),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ [ApiService] Unidad eliminada');
        return true;
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  // ======================== MARCAS ========================

  /// Obtener marcas con paginación
  Future<Map<String, dynamic>> getMarcas({
    int page = 1,
    int perPage = 20,
    String search = '',
  }) async {
    try {
      print('🔄 [ApiService] Obteniendo marcas...');

      final url =
          '${EnvConfig.baseUrl}/app/marcas?page=$page&per_page=$perPage';
      final queryUrl = search.isNotEmpty ? '$url&q=$search' : url;

      final response = await http.get(
        Uri.parse(queryUrl),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] as Map<String, dynamic>;

        return {
          'marcas': (data['data'] as List)
              .map((m) => Marca.fromJson(m))
              .toList(),
          'pagination': {
            'current_page': data['current_page'],
            'last_page': data['last_page'],
            'total': data['total'],
            'per_page': data['per_page'],
          }
        };
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Crear marca
  Future<Marca> createMarca(Marca marca) async {
    try {
      print('🚀 [ApiService] Creando marca: ${marca.nombre}');

      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/app/marcas'),
        headers: _getHeaders(),
        body: jsonEncode(marca.toJson()),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return Marca.fromJson(json['data']);
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Actualizar marca
  Future<Marca> updateMarca(int id, Marca marca) async {
    try {
      print('🔄 [ApiService] Actualizando marca: $id');

      final response = await http.put(
        Uri.parse('${EnvConfig.baseUrl}/app/marcas/$id'),
        headers: _getHeaders(),
        body: jsonEncode(marca.toJson()),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Marca.fromJson(json['data']);
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Eliminar marca
  Future<bool> deleteMarca(int id) async {
    try {
      print('🗑️ [ApiService] Eliminando marca: $id');

      final response = await http.delete(
        Uri.parse('${EnvConfig.baseUrl}/app/marcas/$id'),
        headers: _getHeaders(),
      );

      print('📥 [ApiService] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ [ApiService] Marca eliminada');
        return true;
      }

      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      print('❌ [ApiService] Error: $e');
      throw Exception('Error: $e');
    }
  }
}
