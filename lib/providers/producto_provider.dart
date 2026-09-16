import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/service_locator.dart';
import '../models/producto.dart';

class ProductoProvider extends ChangeNotifier {
  final ApiService _apiService = apiService; // Singleton
  final AuthService _authService = authService; // Singleton

  List<Producto> _productos = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMorePages = false;
  int _totalPages = 0;
  int _totalProductos = 0;

  // Getters
  List<Producto> get productos => _productos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  bool get hasMorePages => _hasMorePages;
  int get totalPages => _totalPages;
  int get totalProductos => _totalProductos;
  String get paginationInfo =>
      'Página $_currentPage de $_totalPages (Total: $_totalProductos productos)';

  ProductoProvider() {
    _initService();
  }

  /// Inicializar el token en el servicio
  Future<void> _initService() async {
    final token = await _authService.getToken();
    if (token != null) {
      _apiService.setToken(token);
    }
  }

  /// Obtener lista de productos
  Future<void> getProductos({int page = 1}) async {
    // print('📄 [ProductoProvider] getProductos(page: $page)');

    if (page == 1) {
      _isLoading = true;
      _productos = [];
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final productos = await _apiService.getProductos(page: page);

      // ✅ NUEVO: Obtener información de paginación del backend
      final paginationInfo = _apiService.getPaginationInfo();
      if (paginationInfo != null) {
        _totalPages = paginationInfo['last_page'] ?? 1;
        _totalProductos = paginationInfo['total'] ?? 0;
        _hasMorePages = page < _totalPages;
        // print('📄 [ProductoProvider] Paginación: página $_currentPage de $_totalPages, total: $_totalProductos productos');
      }

      // print('📄 [ProductoProvider] Recibidos ${productos.length} productos');

      if (page == 1) {
        _productos = productos;
      } else {
        _productos.addAll(productos);
      }
      _currentPage = page;
      // print('📄 [ProductoProvider] Total en lista: ${_productos.length}, hasMorePages: $_hasMorePages');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar más productos (paginación)
  Future<void> loadMoreProductos() async {
    // print('📄 [ProductoProvider] loadMoreProductos() - currentPage: $_currentPage, hasMore: $_hasMorePages, isLoading: $_isLoading');
    if (_isLoading || !_hasMorePages) {
      // print('📄 [ProductoProvider] Abortando: isLoading=$_isLoading, hasMorePages=$_hasMorePages');
      return;
    }
    final nextPage = _currentPage + 1;
    // print('📄 [ProductoProvider] Cargando página $nextPage...');
    await getProductos(page: nextPage);
  }

  /// Obtener un producto por ID
  Future<Producto?> getProductoById(int id) async {
    try {
      return await _apiService.getProductoById(id);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Crear producto
  Future<bool> createProducto(Producto producto) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nuevoProducto = await _apiService.createProducto(producto);
      _productos.insert(0, nuevoProducto);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualizar producto
  Future<bool> updateProducto(int id, Producto producto) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final productoActualizado = await _apiService.updateProducto(
        id,
        producto,
      );
      final index = _productos.indexWhere((p) => p.id == id);
      if (index != -1) {
        _productos[index] = productoActualizado;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Eliminar producto
  Future<bool> deleteProducto(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.deleteProducto(id);
      _productos.removeWhere((p) => p.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Buscar productos
  Future<void> searchProductos(String query) async {
    if (query.isEmpty) {
      await getProductos();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _productos = await _apiService.searchProductos(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Buscar producto por código de barras
  Future<void> searchProductoByCodigoBarras(String codigoBarras) async {
    if (codigoBarras.isEmpty) {
      await getProductos();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final producto = await _apiService.searchProductoByCodigoBarras(codigoBarras);

      if (producto != null) {
        _productos = [producto]; // Mostrar solo el producto encontrado
        _isLoading = false;
        notifyListeners();
      } else {
        _productos = [];
        _errorMessage = 'Producto con código $codigoBarras no encontrado';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _productos = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refrescar lista
  Future<void> refresh() async {
    await getProductos(page: 1);
  }
}
