import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import '../models/dropdown_option.dart';

class DropdownProvider extends ChangeNotifier {
  List<DropdownOption> categorias = [];
  List<DropdownOption> unidades = [];
  List<DropdownOption> marcas = [];
  List<DropdownOption> proveedores = [];
  List<DropdownOption> almacenes = [];
  List<Map<String, dynamic>> sectores = [];

  bool isLoading = false;
  String? errorMessage;

  Future<Map<String, String>> _getHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      print('⚠️ Error obteniendo token: $e');
    }
    return headers;
  }

  // Cargar todas las páginas de un recurso paginado
  Future<List<dynamic>> _loadAllPages(
    String endpoint,
    Map<String, String> headers,
  ) async {
    final allData = <dynamic>[];
    int page = 1;
    bool hasMorePages = true;

    while (hasMorePages) {
      final url = '${EnvConfig.baseUrl}$endpoint?page=$page&per_page=100';
      print('🔄 [DropdownProvider] Cargando página $page: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List<dynamic> pageData = [];

        // Manejar estructura paginada
        if (json['data'] is Map) {
          pageData = json['data']['data'] ?? [];
          final lastPage = json['data']['last_page'] ?? 1;
          hasMorePages = page < lastPage;
        } else {
          pageData = json['data'] ?? [];
          hasMorePages = false;
        }

        allData.addAll(pageData);
        print('✅ Página $page cargada: ${pageData.length} items');
        page++;
      } else {
        hasMorePages = false;
        print('❌ Error en página $page: ${response.statusCode}');
      }
    }

    print('✅ Total de items cargados: ${allData.length}');
    return allData;
  }

  Future<void> loadDropdownData({bool forceRefresh = false}) async {
    if (unidades.isNotEmpty && !forceRefresh) return; // Ya cargados

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      print('📥 [DropdownProvider] Cargando datos de dropdowns...');

      final headers = await _getHeaders();

      // ⏭️ OMITIDO: Categorías (0 items en la empresa actual)

      // Cargar TODAS las unidades de medida (paginadas)
      print('🔄 [DropdownProvider] Cargando todas las unidades...');
      final unidadesData = await _loadAllPages('/app/unidades-medida', headers);
      unidades = unidadesData.map((u) => DropdownOption.fromJson(u as Map<String, dynamic>)).toList();
      print('✅ Unidades cargadas: ${unidades.length}');

      // Cargar TODAS las marcas (paginadas)
      print('🔄 [DropdownProvider] Cargando todas las marcas...');
      final marcasData = await _loadAllPages('/app/marcas', headers);
      marcas = marcasData.map((m) => DropdownOption.fromJson(m as Map<String, dynamic>)).toList();
      print('✅ Marcas cargadas: ${marcas.length}');

      // ⏭️ OMITIDO: Proveedores (no se usan actualmente)

      // Cargar TODOS los almacenes (paginados)
      print('🔄 [DropdownProvider] Cargando todos los almacenes...');
      final almacenesData = await _loadAllPages('/app/almacenes', headers);
      almacenes = almacenesData.map((a) => DropdownOption.fromJson(a as Map<String, dynamic>)).toList();
      print('✅ Almacenes cargados: ${almacenes.length}');

      // Cargar TODOS los sectores (paginados)
      print('🔄 [DropdownProvider] Cargando todos los sectores...');
      final sectoresData = await _loadAllPages('/app/sectores', headers);
      sectores = sectoresData.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      print('✅ Sectores cargados: ${sectores.length}');

      print('✅ [DropdownProvider] Datos de dropdowns cargados correctamente');
    } catch (e) {
      errorMessage = 'Error al cargar datos: $e';
      print('❌ [DropdownProvider] Error: $errorMessage');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Recargar datos forzadamente
  Future<void> reloadDropdownData() async {
    print('🔄 [DropdownProvider] Recargando datos de dropdowns...');
    // Limpiar datos existentes
    categorias = [];
    unidades = [];
    marcas = [];
    proveedores = [];
    almacenes = [];
    sectores = [];
    errorMessage = null;
    notifyListeners();

    // Recargar
    await loadDropdownData(forceRefresh: true);
  }

  // Obtener sectores de un almacén específico (del listado ya cargado)
  List<Map<String, dynamic>> getSectoresPorAlmacen(int almacenId) {
    return sectores.where((s) => s['almacen_id'] == almacenId).toList();
  }

  // ✨ NUEVO: Buscar marcas en tiempo real (lazy loading)
  Future<List<DropdownOption>> searchMarcas(String query) async {
    if (query.isEmpty) {
      return []; // No retornar nada si la búsqueda está vacía
    }

    try {
      final headers = await _getHeaders();
      final url = '${EnvConfig.baseUrl}/app/marcas?q=$query&per_page=20';

      print('🔍 [DropdownProvider] Buscando marcas: $query');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        List<dynamic> marcasData = json['data'] is Map
            ? json['data']['data'] ?? []
            : json['data'] ?? [];

        final resultados = marcasData
            .map((m) => DropdownOption.fromJson(m as Map<String, dynamic>))
            .toList();

        print('✅ Búsqueda de marcas: ${resultados.length} resultados');
        return resultados;
      } else {
        print('❌ Error en búsqueda de marcas: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error buscando marcas: $e');
      return [];
    }
  }

  // ✨ NUEVO: Obtener una marca específica por ID (para edición)
  Future<DropdownOption?> getMarcaById(int marcaId) async {
    try {
      // Buscar del cache (marcas pre-cargadas)
      final enCache = marcas.firstWhere(
        (m) => m.id == marcaId,
        orElse: () => DropdownOption(id: 0, nombre: ''),
      );

      if (enCache.id != 0) {
        print('✅ Marca encontrada en cache: ${enCache.nombre}');
        return enCache;
      }

      // Si no está en cache, buscar por nombre con searchMarcas (sin límite específico)
      // Esto usa el mismo endpoint que la búsqueda lazy pero sin filtro
      print('⚠️ Marca $marcaId no encontrada en cache, buscando...');
      return null; // Retornar null si no está en cache

    } catch (e) {
      print('❌ Error obteniendo marca: $e');
      return null;
    }
  }
}
