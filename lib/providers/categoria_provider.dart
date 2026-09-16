import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../services/service_locator.dart';

class CategoriaProvider extends ChangeNotifier {
  final _apiService = apiService;

  List<Categoria> _categorias = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  String _currentSearch = '';

  // Getters
  List<Categoria> get categorias => _categorias;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMorePages => _currentPage < _lastPage;
  String get paginationInfo =>
      'Página $_currentPage de $_lastPage ($_total categorías)';

  /// Obtener categorías con paginación
  Future<void> getCategorias({int page = 1, String search = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('📄 [CategoriaProvider] getCategorias(page: $page, search: $search)');

      // Guardar el search actual
      _currentSearch = search;

      final result = await _apiService.getCategorias(
        page: page,
        search: search,
      );

      final newCategorias = result['categorias'] as List<Categoria>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      // Si es la primera página o hay búsqueda, reemplazar lista
      if (page == 1) {
        _categorias = newCategorias;
      } else {
        // Si es siguiente página, agregar a la lista
        _categorias.addAll(newCategorias);
      }

      _currentPage = pagination['current_page'] as int;
      _lastPage = pagination['last_page'] as int;
      _total = pagination['total'] as int;

      print('✅ [CategoriaProvider] Categorías cargadas: ${_categorias.length}');
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [CategoriaProvider] Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar más categorías manteniendo la búsqueda actual
  Future<void> loadMoreCategorias() async {
    if (!hasMorePages || _isLoading) return;

    await getCategorias(page: _currentPage + 1, search: _currentSearch);
  }

  /// Crear categoría
  Future<bool> createCategoria(Categoria categoria) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🚀 [CategoriaProvider] Creando categoría...');

      await _apiService.createCategoria(categoria);

      print('✅ [CategoriaProvider] Categoría creada');

      // Recargar lista
      await getCategorias();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [CategoriaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualizar categoría
  Future<bool> updateCategoria(int id, Categoria categoria) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 [CategoriaProvider] Actualizando categoría $id...');

      await _apiService.updateCategoria(id, categoria);

      print('✅ [CategoriaProvider] Categoría actualizada');

      // Recargar lista
      await getCategorias();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [CategoriaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar categoría
  Future<bool> deleteCategoria(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🗑️ [CategoriaProvider] Eliminando categoría $id...');

      await _apiService.deleteCategoria(id);

      print('✅ [CategoriaProvider] Categoría eliminada');

      // Recargar lista
      await getCategorias();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [CategoriaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refrescar lista
  Future<void> refresh() async {
    _currentPage = 1;
    await getCategorias();
  }
}
