import 'package:flutter/material.dart';
import '../models/unidad_medida.dart';
import '../services/service_locator.dart';

class UnidadMedidaProvider extends ChangeNotifier {
  final _apiService = apiService;

  List<UnidadMedida> _unidades = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  String _currentSearch = '';

  // Getters
  List<UnidadMedida> get unidades => _unidades;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMorePages => _currentPage < _lastPage;
  String get paginationInfo =>
      'Página $_currentPage de $_lastPage ($_total unidades)';

  /// Obtener unidades con paginación
  Future<void> getUnidades({int page = 1, String search = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('📄 [UnidadMedidaProvider] getUnidades(page: $page, search: $search)');

      // Guardar el search actual
      _currentSearch = search;

      final result = await _apiService.getUnidadesMedida(
        page: page,
        search: search,
      );

      final newUnidades = result['unidades'] as List<UnidadMedida>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      // Si es la primera página o hay búsqueda, reemplazar lista
      if (page == 1) {
        _unidades = newUnidades;
      } else {
        // Si es siguiente página, agregar a la lista
        _unidades.addAll(newUnidades);
      }

      _currentPage = pagination['current_page'] as int;
      _lastPage = pagination['last_page'] as int;
      _total = pagination['total'] as int;

      print('✅ [UnidadMedidaProvider] Unidades cargadas: ${_unidades.length}');
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [UnidadMedidaProvider] Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar más unidades manteniendo la búsqueda actual
  Future<void> loadMoreUnidades() async {
    if (!hasMorePages || _isLoading) return;

    await getUnidades(page: _currentPage + 1, search: _currentSearch);
  }

  /// Crear unidad
  Future<bool> createUnidad(UnidadMedida unidad) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🚀 [UnidadMedidaProvider] Creando unidad...');

      await _apiService.createUnidadMedida(unidad);

      print('✅ [UnidadMedidaProvider] Unidad creada');

      // Recargar lista
      await getUnidades();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [UnidadMedidaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualizar unidad
  Future<bool> updateUnidad(int id, UnidadMedida unidad) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 [UnidadMedidaProvider] Actualizando unidad $id...');

      await _apiService.updateUnidadMedida(id, unidad);

      print('✅ [UnidadMedidaProvider] Unidad actualizada');

      // Recargar lista
      await getUnidades();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [UnidadMedidaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar unidad
  Future<bool> deleteUnidad(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🗑️ [UnidadMedidaProvider] Eliminando unidad $id...');

      await _apiService.deleteUnidadMedida(id);

      print('✅ [UnidadMedidaProvider] Unidad eliminada');

      // Recargar lista
      await getUnidades();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [UnidadMedidaProvider] Error: $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refrescar lista
  Future<void> refresh() async {
    _currentPage = 1;
    await getUnidades();
  }
}
