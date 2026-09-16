import 'package:flutter/material.dart';
import '../models/marca.dart';
import '../services/service_locator.dart';

class MarcaProvider extends ChangeNotifier {
  final _apiService = apiService;

  List<Marca> _marcas = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  String _currentSearch = '';

  // Getters
  List<Marca> get marcas => _marcas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMorePages => _currentPage < _lastPage;
  String get paginationInfo =>
      'Página $_currentPage de $_lastPage ($_total marcas)';

  /// Obtener marcas con paginación
  Future<void> getMarcas({int page = 1, String search = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('📄 [MarcaProvider] getMarcas(page: $page, search: $search)');

      // Guardar el search actual
      _currentSearch = search;

      final result = await _apiService.getMarcas(
        page: page,
        search: search,
      );

      final newMarcas = result['marcas'] as List<Marca>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      // Si es la primera página o hay búsqueda, reemplazar lista
      if (page == 1) {
        _marcas = newMarcas;
      } else {
        // Si es siguiente página, agregar a la lista
        _marcas.addAll(newMarcas);
      }

      _currentPage = pagination['current_page'] as int;
      _lastPage = pagination['last_page'] as int;
      _total = pagination['total'] as int;

      print('✅ [MarcaProvider] Marcas cargadas: ${_marcas.length}');
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [MarcaProvider] Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar más marcas manteniendo la búsqueda actual
  Future<void> loadMoreMarcas() async {
    if (!hasMorePages || _isLoading) return;

    await getMarcas(page: _currentPage + 1, search: _currentSearch);
  }

  /// Crear marca
  Future<bool> createMarca(Marca marca) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🚀 [MarcaProvider] Creando marca...');

      await _apiService.createMarca(marca);

      print('✅ [MarcaProvider] Marca creada');

      // Recargar lista
      await getMarcas();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [MarcaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualizar marca
  Future<bool> updateMarca(int id, Marca marca) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 [MarcaProvider] Actualizando marca $id...');

      await _apiService.updateMarca(id, marca);

      print('✅ [MarcaProvider] Marca actualizada');

      // Recargar lista
      await getMarcas();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [MarcaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar marca
  Future<bool> deleteMarca(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🗑️ [MarcaProvider] Eliminando marca $id...');

      await _apiService.deleteMarca(id);

      print('✅ [MarcaProvider] Marca eliminada');

      // Recargar lista
      await getMarcas();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [MarcaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refrescar lista
  Future<void> refresh() async {
    _currentPage = 1;
    await getMarcas();
  }
}
