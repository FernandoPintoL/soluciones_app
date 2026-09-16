import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'dart:io';

import '../models/dropdown_option.dart';
import '../models/producto.dart';
import '../providers/producto_provider.dart';
import '../providers/dropdown_provider.dart';
import '../services/service_locator.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/search_select_field.dart';

class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;

  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  late TextEditingController _nombreController;
  late TextEditingController _skuController;
  late TextEditingController _descripcionController;
  late TextEditingController _pesoController;
  late TextEditingController _stockMinimoController;
  late TextEditingController _stockMaximoController;
  late TextEditingController _limitVentaController;
  late TextEditingController _precioCompraController;
  late TextEditingController _precioVentaController;
  late TextEditingController _codigoBarrasController;

  bool _activo = true;
  bool _esProductoComida = false;
  bool _permitirVentaSinStock = false;
  bool _visibleApp = true;
  bool _mostrarImagen = false;

  // Relaciones
  // int? _categoriaId; // ⏭️ OMITIDO
  int? _marcaId;
  // int? _proveedorId; // ⏭️ OMITIDO
  int? _unidadMedidaId;

  // Stock
  int? _almacenSeleccionado;
  int? _sectorSeleccionado;
  late TextEditingController _cantidadStockController;
  late TextEditingController _loteController;
  late TextEditingController _fechaVencimientoController;
  late TextEditingController _stockMinimoStockController;  // ✨ NUEVO
  late TextEditingController _stockMaximoStockController;  // ✨ NUEVO
  List<Map<String, dynamic>> _stocksAgregados = [];
  DateTime? _fechaVencimientoSeleccionada;

  // ✨ NUEVO: Rastrear cuál stock está siendo editado
  int? _stockEditandoIndex; // null = crear nuevo, >= 0 = editar existente

  // Imagen
  File? _imagenSeleccionada;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isScanning = false;

  // Producto cargado desde API (con stocks completos)
  Producto? _productoActual;

  @override
  void initState() {
    super.initState();
    _initializeControllers();

    // Si es ediciÃ³n, cargar el producto completo desde la API
    if (widget.producto != null && widget.producto!.id > 0) {
      _loadProductoCompleto(widget.producto!.id);
    }

    // Cargar dropdown data y pre-seleccionar unidad "UN", almacÃ©n y sector
    Future.microtask(() {
      if (mounted) {
        final dropdownProvider = context.read<DropdownProvider>();
        dropdownProvider.loadDropdownData().then((_) {
          if (mounted) {
            setState(() {
              // Pre-seleccionar unidad con cÃ³digo="UN"
              if (_unidadMedidaId == null) {
                try {
                  final unidadUN = dropdownProvider.unidades.firstWhere(
                    (u) => u.codigo == 'UN',
                  );
                  _unidadMedidaId = unidadUN.id;
                } catch (e) {
                  print('Ã¢Å¡Â Ã¯Â¸Â No se encontrÃ³ unidad con cÃ³digo UN');
                }
              }

              // Pre-seleccionar almacÃ©n
              if (dropdownProvider.almacenes.isNotEmpty &&
                  _almacenSeleccionado == null) {
                // Usar producto cargado si estÃ¡ disponible
                final productoParaStock = _productoActual ?? widget.producto;
                // Si es ediciÃ³n y hay stocks, usar el almacÃ©n del primer stock
                if (productoParaStock != null &&
                    productoParaStock.stocks.isNotEmpty) {
                  _almacenSeleccionado =
                      productoParaStock.stocks.first['almacen_id'] as int;
                  print(
                    'Ã¢Åâ¦ [ProductoForm] AlmacÃ©n preseleccionado del stock: ${_almacenSeleccionado}',
                  );
                } else {
                  // Si es nuevo o sin stocks, usar "AlmacÃ©n Principal" o el primero si no existe
                  final almacenPrincipal = dropdownProvider.almacenes
                      .firstWhere(
                        (a) =>
                            a.nombre.toLowerCase().contains('principal') ||
                            a.nombre.toLowerCase().contains('almacen'),
                        orElse: () => dropdownProvider.almacenes.first,
                      );
                  _almacenSeleccionado = almacenPrincipal.id;
                  print(
                    'Ã¢Åâ¦ [ProductoForm] AlmacÃ©n preseleccionado (default): ${_almacenSeleccionado} - ${almacenPrincipal.nombre}',
                  );
                }
              }

              // Pre-seleccionar sector
              if (_almacenSeleccionado != null) {
                final sectores = dropdownProvider.getSectoresPorAlmacen(
                  _almacenSeleccionado!,
                );
                if (sectores.isNotEmpty && _sectorSeleccionado == null) {
                  // Usar producto cargado si estÃ¡ disponible
                  final productoParaStock = _productoActual ?? widget.producto;
                  // Si es ediciÃ³n y hay stocks, usar el sector del primer stock
                  if (productoParaStock != null &&
                      productoParaStock.stocks.isNotEmpty) {
                    _sectorSeleccionado =
                        productoParaStock.stocks.first['sector_id'] as int?;
                  }
                  // Si no se encontrÃ³ en stocks, usar el primer sector disponible
                  if (_sectorSeleccionado == null) {
                    _sectorSeleccionado = sectores.first['id'] as int;
                  }
                  print(
                    'Ã¢Åâ¦ [ProductoForm] Sector preseleccionado: ${_sectorSeleccionado}',
                  );
                }
              }
            });

            // Usar addPostFrameCallback para cargar el stock despuÃ©s del primer frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  _almacenSeleccionado != null &&
                  _sectorSeleccionado != null &&
                  widget.producto != null) {
                _loadExistingStock(_almacenSeleccionado!, _sectorSeleccionado!);
              }
            });
          }
        });
      }
    });
  }

  void _initializeControllers() {
    _nombreController = TextEditingController(
      text: widget.producto?.nombre ?? '',
    );
    _skuController = TextEditingController(text: widget.producto?.sku ?? '');
    _descripcionController = TextEditingController(
      text: widget.producto?.descripcion ?? '',
    );
    _pesoController = TextEditingController(
      text: widget.producto?.peso?.toString() ?? '',
    );
    _stockMinimoController = TextEditingController(
      text: widget.producto?.stockMinimo.toString() ?? '0',
    );
    _stockMaximoController = TextEditingController(
      text: widget.producto?.stockMaximo.toString() ?? '0',
    );
    _limitVentaController = TextEditingController(
      text: widget.producto?.limiteventa?.toString() ?? '',
    );
    _precioCompraController = TextEditingController(
      text: widget.producto?.precioCompra?.toString() ?? '',
    );
    _precioVentaController = TextEditingController(
      text: widget.producto?.precioVenta?.toString() ?? '',
    );
    _codigoBarrasController = TextEditingController(
      text: widget.producto?.codigosBarra ?? '',
    );
    _cantidadStockController = TextEditingController();
    _loteController = TextEditingController();
    _fechaVencimientoController = TextEditingController();
    _stockMinimoStockController = TextEditingController();  // ✨ NUEVO
    _stockMaximoStockController = TextEditingController();  // ✨ NUEVO

    if (widget.producto != null) {
      _activo = widget.producto!.activo;
      _esProductoComida = widget.producto!.esProductoComida;
      _permitirVentaSinStock = widget.producto!.permitirVentaSinStock;
      _visibleApp = widget.producto!.visibleApp;
      // _categoriaId = widget.producto!.categoriaId; // ⏭️ OMITIDO
      _marcaId = widget.producto!.marcaId;
      // _proveedorId = widget.producto!.proveedorId; // ⏭️ OMITIDO
      _unidadMedidaId = widget.producto!.unidadMedidaId;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _skuController.dispose();
    _descripcionController.dispose();
    _pesoController.dispose();
    _stockMinimoController.dispose();
    _stockMaximoController.dispose();
    _limitVentaController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    _codigoBarrasController.dispose();
    _cantidadStockController.dispose();
    _loteController.dispose();
    _fechaVencimientoController.dispose();
    _stockMinimoStockController.dispose();  // ✨ NUEVO
    _stockMaximoStockController.dispose();  // ✨ NUEVO
    super.dispose();
  }

  // Ã¢Åâ¦ NUEVA: Verificar cÃ³digo de barra escaneado y cerrar si existe
  Future<void> _verifyAndCloseIfExists(
    BuildContext scannerContext,
    String codigo,
  ) async {
    if (codigo.isEmpty) return;

    try {
      print('Ã°Å¸âÂ [ProductoForm] Verificando cÃ³digo: $codigo');
      final producto = await apiService.searchProductoByCodigoBarras(codigo);

      if (!mounted) return;

      if (producto != null) {
        // CÃ³digo ya existe en el sistema: mostrar error y cerrar scanner
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Codigo de barra ya existe: ${producto.nombre}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Limpiar el cÃ³digo y cerrar el scanner despuÃ©s de 500ms
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _codigoBarrasController.clear();
            });
            try {
              Navigator.pop(scannerContext);
            } catch (e) {
              print('Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] Error cerrando scanner: $e');
            }
          }
        });
      } else {
        // CÃ³digo nuevo: disponible para usar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('CÃ³digo de barra disponible para usar'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Ã¢ÂÅ [ProductoForm] Error verificando: $e');
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } catch (ex) {
          print('Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] Error mostrando SnackBar: $ex');
        }
      }
    }
  }

  // Ã¢Åâ¦ NUEVA: Abrir scanner de cÃ³digo de barra
  void _scanBarcode() {
    print('Ã°Å¸âÂ¸ [ProductoForm] Abriendo scanner...');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (scannerContext) => BarcodeScannerScreen(
          onBarcodeDetected: (codigo) {
            print('[ProductoForm] Codigo de barra escaneado: $codigo');

            // Cargar el cÃ³digo en el campo
            if (mounted) {
              setState(() {
                _codigoBarrasController.text = codigo;
              });
            }

            // Verificar si existe (y cerrar si existe)
            _verifyAndCloseIfExists(scannerContext, codigo);
          },
        ),
      ),
    );
  }

  // Ã¢Åâ¦ NUEVA: Buscar producto por cÃ³digo de barra
  Future<void> _searchByBarcode() async {
    if (_codigoBarrasController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ingresa un cÃ³digo de barra'),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
      return;
    }

    try {
      print(
        '[ProductoForm] Buscando por codigo: ${_codigoBarrasController.text}',
      );
      final producto = await apiService.searchProductoByCodigoBarras(
        _codigoBarrasController.text,
      );

      if (producto != null) {
        print('Ã¢Åâ¦ [ProductoForm] Producto encontrado: ${producto.nombre}');

        // Cargar datos del producto encontrado
        setState(() {
          _nombreController.text = producto.nombre;
          _skuController.text = producto.sku ?? '';
          _descripcionController.text = producto.descripcion ?? '';
          _pesoController.text = producto.peso?.toString() ?? '';
          _stockMinimoController.text = producto.stockMinimo.toString();
          _stockMaximoController.text = producto.stockMaximo.toString();
          _limitVentaController.text = producto.limiteventa?.toString() ?? '';
          // _categoriaId = producto.categoriaId; // ⏭️ OMITIDO
          _marcaId = producto.marcaId;
          // _proveedorId = producto.proveedorId; // ⏭️ OMITIDO
          _unidadMedidaId = producto.unidadMedidaId;
          _activo = producto.activo;
          _esProductoComida = producto.esProductoComida;
          _permitirVentaSinStock = producto.permitirVentaSinStock;
          _visibleApp = producto.visibleApp;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto encontrado: ${producto.nombre}'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Producto no encontrado'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      print('Ã¢ÂÅ [ProductoForm] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // Cargar producto completo desde API (con stocks)
  Future<void> _loadProductoCompleto(int productoId) async {
    try {
      print('Ã°Å¸âÂ¦ [ProductoForm] Cargando producto completo: $productoId');
      final producto = await apiService.getProductoById(productoId);

      if (mounted) {
        final dropdownProvider = context.read<DropdownProvider>();
        setState(() {
          _productoActual = producto;
          // Actualizar campos con datos del producto cargado desde el API
          _nombreController.text = producto.nombre;
          _skuController.text = producto.sku ?? '';
          _precioCompraController.text = producto.precioCompra?.toString() ?? '';
          _precioVentaController.text = producto.precioVenta?.toString() ?? '';
          _codigoBarrasController.text = producto.codigosBarra ?? '';
          _marcaId = producto.marcaId;
          // Actualizar stocks del producto actual (ya vienen completos desde showApi)
          // ✨ NUEVO: Mezclar stocks con stockLimites
          _stocksAgregados = _combinarStocksConLimites(producto);
          print('✅ [ProductoForm] Stocks cargados con límites: ${_stocksAgregados.length} stocks');

          // Re-seleccionar almacÃ©n y sector basado en el producto cargado
          if (producto.stocks.isNotEmpty && _almacenSeleccionado == null) {
            _almacenSeleccionado = producto.stocks.first['almacen_id'] as int;
            print(
              'Ã¢Åâ¦ [ProductoForm] AlmacÃ©n re-seleccionado del stock cargado: ${_almacenSeleccionado}',
            );

            // Pre-seleccionar sector tambiÃ©n
            final sectores = dropdownProvider.getSectoresPorAlmacen(
              _almacenSeleccionado!,
            );
            if (sectores.isNotEmpty && _sectorSeleccionado == null) {
              _sectorSeleccionado = producto.stocks.first['sector_id'] as int?;
              if (_sectorSeleccionado == null) {
                _sectorSeleccionado = sectores.first['id'] as int;
              }
              print(
                'Ã¢Åâ¦ [ProductoForm] Sector re-seleccionado: ${_sectorSeleccionado}',
              );
            }

            // Cargar el stock existente
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  _almacenSeleccionado != null &&
                  _sectorSeleccionado != null) {
                _loadExistingStock(_almacenSeleccionado!, _sectorSeleccionado!);
              }
            });
          } else if (producto.stocks.isEmpty && _almacenSeleccionado == null) {
            // Si el producto no tiene stocks, usar "AlmacÃ©n Principal" como default
            if (dropdownProvider.almacenes.isNotEmpty) {
              DropdownOption almacenPrincipal =
                  dropdownProvider.almacenes.first;
              try {
                almacenPrincipal = dropdownProvider.almacenes.firstWhere(
                  (a) =>
                      a.nombre.toLowerCase().contains('principal') ||
                      a.nombre.toLowerCase().contains('almacen'),
                );
              } catch (e) {
                // Si no encuentra, usa el primero
              }

              _almacenSeleccionado = almacenPrincipal.id;
              print(
                'Ã¢Åâ¦ [ProductoForm] AlmacÃ©n default (sin stocks): ${_almacenSeleccionado} - ${almacenPrincipal.nombre}',
              );

              // Pre-seleccionar sector
              final sectores = dropdownProvider.getSectoresPorAlmacen(
                _almacenSeleccionado!,
              );
              if (sectores.isNotEmpty && _sectorSeleccionado == null) {
                _sectorSeleccionado = sectores.first['id'] as int;
                print(
                  'Ã¢Åâ¦ [ProductoForm] Sector default: ${_sectorSeleccionado}',
                );
              }
            }
          }
        });
        print(
          'Ã¢Åâ¦ [ProductoForm] Producto cargado con ${producto.stocks.length} stocks',
        );
      }
    } catch (e) {
      print('Ã¢ÂÅ [ProductoForm] Error cargando producto: $e');
    }
  }

  void _loadExistingStock(int almacenId, int sectorId) {
    final producto = _productoActual ?? widget.producto;
    if (producto == null) {
      print('Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] No hay producto para cargar stock');
      return;
    }

    print(
      'Ã°Å¸âÂ¦ [ProductoForm] Buscando stock: almacÃ©n=$almacenId, sector=$sectorId',
    );
    print(
      'Ã°Å¸âÂ¦ [ProductoForm] Stocks disponibles: ${producto.stocks.length}',
    );

    if (producto.stocks.isEmpty) {
      print('Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] Lista de stocks vacÃ­a');
      return;
    }

    try {
      // Mostrar todos los stocks disponibles para debugging
      for (var i = 0; i < producto.stocks.length; i++) {
        final s = producto.stocks[i];
        print(
          '  Stock[$i]: almacen=${s['almacen_id']}, sector=${s['sector_id']}, cantidad=${s['cantidad']}',
        );
      }

      // Primero intenta encontrar por almacÃ©n + sector
      var stock = producto.stocks.firstWhere(
        (s) => s['almacen_id'] == almacenId && s['sector_id'] == sectorId,
        orElse: () => {},
      );

      // Si no encuentra, busca solo por almacÃ©n (para datos antiguos sin sector_id)
      if (stock.isEmpty) {
        stock = producto.stocks.firstWhere(
          (s) => s['almacen_id'] == almacenId,
          orElse: () => {},
        );
        if (stock.isNotEmpty) {
          print(
            'Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] Stock encontrado solo por almacÃ©n (sin sector especÃ­fico)',
          );
        }
      }

      if (stock.isNotEmpty) {
        final cantidad = stock['cantidad'] ?? 0;
        final lote = stock['lote'];
        final fechaVencimiento = stock['fecha_vencimiento'];

        setState(() {
          _cantidadStockController.text = cantidad.toString();
          // Cargar lote si existe
          if (lote != null && lote.toString().isNotEmpty) {
            _loteController.text = lote.toString();
          } else {
            _loteController.clear();
          }
          // Cargar fecha de vencimiento si existe
          if (fechaVencimiento != null &&
              fechaVencimiento.toString().isNotEmpty) {
            _fechaVencimientoController.text = fechaVencimiento.toString();
            // Intentar parsear la fecha para mostrarla en el picker
            try {
              _fechaVencimientoSeleccionada = DateTime.parse(
                fechaVencimiento.toString(),
              );
            } catch (e) {
              print('Error parseando fecha: $e');
            }
          } else {
            _fechaVencimientoController.clear();
            _fechaVencimientoSeleccionada = null;
          }
        });
        print(
          'Ã¢Åâ¦ [ProductoForm] Stock cargado: $cantidad para almacÃ©n $almacenId, sector $sectorId',
        );
      } else {
        // No hay stock para esta combinaciÃ³n
        setState(() {
          _cantidadStockController.clear();
          _loteController.clear();
          _fechaVencimientoController.clear();
          _fechaVencimientoSeleccionada = null;
        });
        print(
          'Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] No hay stock para almacÃ©n $almacenId, sector $sectorId',
        );
      }
    } catch (e) {
      print('Ã¢ÂÅ [ProductoForm] Error cargando stock: $e');
      _cantidadStockController.clear();
    }
  }

  void _agregarStock(
    DropdownProvider dropdownProvider,
    int almacenId,
    int sectorId,
  ) {
    final cantidad = int.tryParse(_cantidadStockController.text);
    print(
      'Ã°Å¸âÂ¦ [ProductoForm] Agregando stock: AlmacÃ©n $almacenId, Sector $sectorId, Cantidad $cantidad',
    );

    if (cantidad == null || cantidad < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ingresa una cantidad vÃ¡lida'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      print('Ã¢ÂÅ [ProductoForm] Cantidad invÃ¡lida');
      return;
    }

    final almacen = dropdownProvider.almacenes.firstWhere(
      (a) => a.id == almacenId,
      orElse: () =>
          DropdownOption(id: almacenId, nombre: 'AlmacÃ©n $almacenId'),
    );

    final sectoresList = dropdownProvider.getSectoresPorAlmacen(almacenId);
    final sectorMap = sectoresList.firstWhere(
      (s) => s['id'] == sectorId,
      orElse: () => {'id': sectorId, 'nombre': 'Sector $sectorId'},
    );
    final sectorNombre = sectorMap['nombre'] ?? 'Sector $sectorId';

    // Validar y parsear stock_minimo y stock_maximo
    final stockMinimo = int.tryParse(_stockMinimoStockController.text) ?? 0;
    final stockMaximo = int.tryParse(_stockMaximoStockController.text) ?? 0;

    if (stockMinimo < 0 || stockMaximo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Stock mínimo y máximo no pueden ser negativos'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final isEditing = _stockEditandoIndex != null;
    final nuevoStock = {
      if (isEditing && _stocksAgregados[_stockEditandoIndex!]['id'] != null)
        'id': _stocksAgregados[_stockEditandoIndex!]['id'], // ✨ Preservar id si está editando
      'almacen_id': almacenId,
      'sector_id': sectorId,
      'cantidad': cantidad,
      'stock_minimo': stockMinimo,  // ✨ NUEVO
      'stock_maximo': stockMaximo,  // ✨ NUEVO
      'lote': _loteController.text.isNotEmpty ? _loteController.text : null,
      'fecha_vencimiento': _fechaVencimientoSeleccionada != null
          ? _fechaVencimientoSeleccionada!.toIso8601String().split('T')[0]
          : null,
      'almacen_nombre': almacen.nombre,
      'sector_nombre': sectorNombre,
    };

    setState(() {
      if (isEditing) {
        _stocksAgregados[_stockEditandoIndex!] = nuevoStock;
        print(
          '[ProductoForm] Stock actualizado en indice $_stockEditandoIndex',
        );
      } else {
        _stocksAgregados.add(nuevoStock);
        print(
          '[ProductoForm] Stock agregado: ${_stocksAgregados.length} stocks en total',
        );
      }
      _stockEditandoIndex = null;
      _almacenSeleccionado = null;
      _sectorSeleccionado = null;
      _cantidadStockController.clear();
      _loteController.clear();
      _fechaVencimientoController.clear();
      _fechaVencimientoSeleccionada = null;
    });

    print(
      'Ã¢Åâ¦ [ProductoForm] Stock agregado: ${_stocksAgregados.length} stocks en total',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Stock actualizado correctamente'
              : 'Stock agregado correctamente',
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  // ✨ NUEVO: Cargar stock existente en los campos para editar
  void _cargarStockParaEditar(int index) {
    final stock = _stocksAgregados[index];
    final dropdownProvider = context.read<DropdownProvider>();

    print('✏️ [ProductoForm] Editando stock [index: $index]');

    setState(() {
      _stockEditandoIndex = index;
      _almacenSeleccionado = stock['almacen_id'];
      _sectorSeleccionado = stock['sector_id'];
      _cantidadStockController.text = stock['cantidad'].toString();
      _stockMinimoStockController.text = (stock['stock_minimo'] ?? 0).toString();  // ✨ NUEVO
      _stockMaximoStockController.text = (stock['stock_maximo'] ?? 0).toString();  // ✨ NUEVO
      _loteController.text = stock['lote'] ?? '';
      _fechaVencimientoController.text = stock['fecha_vencimiento'] ?? '';

      // Parsear fecha si existe
      if (stock['fecha_vencimiento'] != null &&
          stock['fecha_vencimiento'].isNotEmpty) {
        try {
          _fechaVencimientoSeleccionada = DateTime.parse(
            stock['fecha_vencimiento'],
          );
        } catch (e) {
          _fechaVencimientoSeleccionada = null;
        }
      } else {
        _fechaVencimientoSeleccionada = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Editando stock: Almacén ${stock['almacen_nombre']}, Sector ${stock['sector_nombre']}',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ✨ NUEVO: Cancelar edición y limpiar
  void _cancelarEdicion() {
    setState(() {
      _stockEditandoIndex = null;
      _almacenSeleccionado = null;
      _sectorSeleccionado = null;
      _cantidadStockController.clear();
      _loteController.clear();
      _fechaVencimientoController.clear();
      _stockMinimoStockController.clear();  // ✨ NUEVO
      _stockMaximoStockController.clear();  // ✨ NUEVO
      _fechaVencimientoSeleccionada = null;
    });

    print('❌ [ProductoForm] Edición cancelada');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edición cancelada'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  // ✨ NUEVO: Combinar stocks con sus límites asociados
  List<Map<String, dynamic>> _combinarStocksConLimites(Producto producto) {
    final stocksConLimites = <Map<String, dynamic>>[];

    // Recorrer cada stock
    for (final stock in producto.stocks) {
      final almacenId = stock['almacen_id'] as int?;
      final sectorId = stock['sector_id'] as int?;

      // Buscar el límite correspondiente
      final limite = producto.stockLimites.firstWhere(
        (sl) => sl['almacen_id'] == almacenId && sl['sector_id'] == sectorId,
        orElse: () => <String, dynamic>{},
      );

      // Combinar stock con sus límites
      final stockConLimite = {
        ...stock,
        'stock_minimo': limite['stock_minimo'] ?? 0,
        'stock_maximo': limite['stock_maximo'] ?? 0,
      };

      stocksConLimites.add(stockConLimite);

      print('✅ [_combinarStocksConLimites] Stock ${almacenId}/${sectorId}: Mín=${limite['stock_minimo'] ?? 0}, Máx=${limite['stock_maximo'] ?? 0}');
    }

    return stocksConLimites;
  }

  // Mostrar opciones para seleccionar imagen
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Imagen'),
        content: const Text('ÃÂ¿De dÃ³nde deseas tomar la imagen?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _selectImageFromCamera();
            },
            child: const Text('Ã°Å¸âÂ· CÃ¡mara'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _selectImageFromGallery();
            },
            child: const Text('Ã°Å¸âÂ¼Ã¯Â¸Â GalerÃ­a'),
          ),
        ],
      ),
    );
  }

  // Seleccionar imagen de la cÃ¡mara
  Future<void> _selectImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imagenSeleccionada = File(image.path);
        });
        print('Ã¢Åâ¦ [ProductoForm] Foto capturada: ${image.path}');
      }
    } catch (e) {
      print('Ã¢ÂÅ [ProductoForm] Error capturando foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Seleccionar imagen de la galerÃ­a
  Future<void> _selectImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imagenSeleccionada = File(image.path);
        });
        print(
          'Ã¢Åâ¦ [ProductoForm] Imagen seleccionada de galerÃ­a: ${image.path}',
        );
      }
    } catch (e) {
      print('Ã¢ÂÅ [ProductoForm] Error seleccionando imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (_nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('El nombre es requerido'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final producto = Producto(
      id: widget.producto?.id ?? 0,
      nombre: _nombreController.text,
      sku: _skuController.text.isNotEmpty ? _skuController.text : null,
      descripcion: _descripcionController.text.isNotEmpty
          ? _descripcionController.text
          : null,
      peso: _pesoController.text.isNotEmpty
          ? double.tryParse(_pesoController.text)
          : null,
      unidadMedidaId: _unidadMedidaId,
      // categoriaId: _categoriaId, // ⏭️ OMITIDO
      marcaId: _marcaId,
      // proveedorId: _proveedorId, // ⏭️ OMITIDO
      stockMinimo: int.tryParse(_stockMinimoController.text) ?? 0,
      stockMaximo: int.tryParse(_stockMaximoController.text) ?? 0,
      activo: _activo,
      esProductoComida: _esProductoComida,
      permitirVentaSinStock: _permitirVentaSinStock,
      visibleApp: _visibleApp,
      codigosBarra: _codigoBarrasController.text.isNotEmpty
          ? _codigoBarrasController.text
          : '', // Ã°Å¸âÂ¥ Enviar string vacÃ­o en lugar de null para que el backend elimine
      limiteventa: _limitVentaController.text.isNotEmpty
          ? double.tryParse(_limitVentaController.text)
          : null,
      precioCompra: _precioCompraController.text.isNotEmpty
          ? double.tryParse(_precioCompraController.text)
          : 0.0,
      precioVenta: _precioVentaController.text.isNotEmpty
          ? double.tryParse(_precioVentaController.text)
          : 0.0,
      stocks: _stocksAgregados.isNotEmpty
          ? _stocksAgregados
          : (widget.producto?.stocks ?? []),
    );

    bool success = false;
    if (widget.producto == null) {
      success = await context.read<ProductoProvider>().createProducto(producto);
    } else {
      success = await context.read<ProductoProvider>().updateProducto(
        widget.producto!.id,
        producto,
      );
    }

    if (!mounted) return;

    if (success) {
      // ✅ NUEVO: Si se agregaron stocks a través de _stocksAgregados,
      // el backend ya los procesó en el payload de almacenes.
      // Solo crear stock manualmente si NO hay stocks agregados
      // Y hay almacén/sector seleccionados en el formulario
      if (_stocksAgregados.isEmpty &&
          _almacenSeleccionado != null &&
          _sectorSeleccionado != null &&
          _cantidadStockController.text.isNotEmpty) {
        final cantidad = int.tryParse(_cantidadStockController.text) ?? 0;

        final productoProvider = context.read<ProductoProvider>();
        final productosActuales = productoProvider.productos;

        // Obtener el ID del producto creado/actualizado
        int productoId = widget.producto?.id ?? 0;
        if (productoId == 0 && productosActuales.isNotEmpty) {
          productoId = productosActuales.first.id;
        }

        print(
          'Ã°Å¸âÂ¦ [ProductoForm] Creando stock para producto $productoId',
        );
        print(
          'Ã°Å¸âÂ¤ [ProductoForm] AlmacÃ©n: $_almacenSeleccionado, Sector: $_sectorSeleccionado, Cantidad: $cantidad',
        );

        final stockSuccess = await apiService.crearStockProducto(
          productoId,
          _almacenSeleccionado!,
          _sectorSeleccionado!,
          cantidad,
          lote: _loteController.text.isNotEmpty ? _loteController.text : null,
          fechaVencimiento: _fechaVencimientoController.text.isNotEmpty
              ? _fechaVencimientoController.text
              : null,
        );

        if (stockSuccess) {
          print('Ã¢Åâ¦ [ProductoForm] Stock creado exitosamente');
        } else {
          print('Ã¢ÂÅ [ProductoForm] Error creando stock');
        }
      } else {
        print(
          'Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] Falta almacÃ©n, sector o cantidad para crear stock',
        );
      }

      // Crear cÃ³digo de barra si fue ingresado (endpoint separado)
      if (_codigoBarrasController.text.isNotEmpty) {
        final productoProvider = context.read<ProductoProvider>();
        final productosActuales = productoProvider.productos;
        int productoId = widget.producto?.id ?? 0;
        if (productoId == 0 && productosActuales.isNotEmpty) {
          productoId = productosActuales.first.id;
        }

        print(
          'Ã°Å¸ââº [ProductoForm] Guardando cÃ³digo de barra: ${_codigoBarrasController.text}',
        );

        // Intentar con diferentes rutas posibles
        bool codigoBarraSuccess = false;

        // Intento 1: POST /api/productos/{id}/codigos
        try {
          final response = await http.post(
            Uri.parse(
              'http://192.168.100.39:9000/api/productos/$productoId/codigos',
            ),
            headers: apiService.getHeaders(),
            body: jsonEncode({'codigo': _codigoBarrasController.text}),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            codigoBarraSuccess = true;
            print('Ã¢Åâ¦ [ProductoForm] CÃ³digo de barra guardado (ruta 1)');
          }
        } catch (e) {
          print('Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] Ruta 1 fallÃ³: $e');
        }

        if (!codigoBarraSuccess) {
          // Intento 2: PUT /api/productos/{id}
          try {
            final response = await http.put(
              Uri.parse('http://192.168.100.39:9000/api/productos/$productoId'),
              headers: apiService.getHeaders(),
              body: jsonEncode({'codigo_barras': _codigoBarrasController.text}),
            );

            if (response.statusCode == 200) {
              codigoBarraSuccess = true;
              print(
                'Ã¢Åâ¦ [ProductoForm] CÃ³digo de barra guardado (ruta 2)',
              );
            }
          } catch (e) {
            print('Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] Ruta 2 fallÃ³: $e');
          }
        }

        if (!codigoBarraSuccess) {
          print(
            'Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] No se pudo guardar el cÃ³digo de barra',
          );
        }
      }

      // Subir imagen si fue seleccionada
      if (_imagenSeleccionada != null) {
        final productoProvider = context.read<ProductoProvider>();
        final productosActuales = productoProvider.productos;
        int productoId = widget.producto?.id ?? 0;
        if (productoId == 0 && productosActuales.isNotEmpty) {
          productoId = productosActuales.first.id;
        }

        print(
          'Ã°Å¸âÂ¼Ã¯Â¸Â [ProductoForm] Subiendo imagen para producto $productoId',
        );
        final imagenUploadSuccess = await apiService.uploadImagenProducto(
          productoId,
          _imagenSeleccionada!.path,
          esPrincipal: true,
          orden: 0,
        );

        if (imagenUploadSuccess) {
          print('Ã¢Åâ¦ [ProductoForm] Imagen subida correctamente');
        } else {
          print('Ã¢Å¡Â Ã¯Â¸Â [ProductoForm] Error subiendo imagen');
        }
      }

      if (mounted) {
        // Refrescar la lista de productos despuÃ©s de guardar
        Future.microtask(() {
          context.read<ProductoProvider>().refresh();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.producto == null
                  ? 'Producto creado correctamente'
                  : 'Producto actualizado correctamente',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ProductoProvider>().errorMessage ?? 'Error al guardar',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.producto == null
              ? 'Nuevo Producto'
              : 'Editar Producto #${widget.producto!.id}',
        ),
        actions: [
          // BotÃ³n para recargar dropdowns
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar CategorÃ­as, Marcas, Unidades',
            onPressed: () async {
              final dropdownProvider = context.read<DropdownProvider>();
              print('Ã°Å¸ââ [ProductoForm] Recargando dropdowns...');
              await dropdownProvider.reloadDropdownData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Ã¢Åâ¦ Datos recargados correctamente',
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer2<ProductoProvider, DropdownProvider>(
        builder: (context, provider, dropdownProvider, _) {
          final isLoading = provider.isLoading || dropdownProvider.isLoading;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    TextField(
                      controller: _nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabled: !provider.isLoading,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // IMAGEN DEL PRODUCTO
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Imagen del Producto',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Switch(
                                  value: _mostrarImagen,
                                  onChanged: (value) {
                                    setState(() => _mostrarImagen = value);
                                  },
                                ),
                              ],
                            ),
                            if (_mostrarImagen) ...[
                              const SizedBox(height: 12),
                              // Preview de imagen
                              if (_imagenSeleccionada != null)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _imagenSeleccionada!,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: FloatingActionButton(
                                        mini: true,
                                        onPressed: () {
                                          setState(
                                            () => _imagenSeleccionada = null,
                                          );
                                        },
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .error,
                                        child: const Icon(Icons.close),
                                      ),
                                    ),
                                  ],
                                )
                              else if (widget.producto?.imagenPrincipal != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.producto!.imagenPrincipal!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey.shade400,
                                          size: 48,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.grey.shade400,
                                    size: 48,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: provider.isLoading
                                      ? null
                                      : _showImageSourceDialog,
                                  icon: const Icon(Icons.image),
                                  label: Text(
                                    _imagenSeleccionada != null
                                        ? 'Cambiar Imagen'
                                        : 'Seleccionar Imagen',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Ã°Å¸âÂ¦ INFORMACIÃâN ACTUAL (si es editar)
                    /* if (widget.producto != null)
                  Card(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ã°Å¸ââ¹ InformaciÃ³n Actual',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            // CÃ³digo de barra registrado
                            if (widget.producto!.codigosBarra != null)
                              Text(
                                'Ã°Å¸ââ CÃ³digo de Barra: ${widget.producto!.codigosBarra}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (widget.producto!.codigosBarra == null)
                              Text(
                                'Ã°Å¸ââ CÃ³digo de Barra: Sin registrar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            const SizedBox(height: 8),
                            // Stock por almacÃ©n
                            if (widget.producto!.stocks.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ã°Å¸âÂ¦ Stock Total: ${widget.producto!.stockTotal}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...widget.producto!.stocks.map((stock) {
                                    return Text(
                                      '  Ã¢â¬Â¢ ${stock['almacen_nombre']} - ${stock['sector_nombre']}: ${stock['cantidad']} (disponible: ${stock['cantidad_disponible']})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    );
                                  }).toList(),
                                ],
                              ),
                            if (widget.producto!.stocks.isEmpty)
                              Text(
                                'Ã°Å¸âÂ¦ Stock: Sin registrar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                    const SizedBox(height: 16), */
                    // CÃ³digo de Barra (para actualizar/crear)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codigoBarrasController,
                            decoration: InputDecoration(
                              labelText: 'Codigo de Barra',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabled: !provider.isLoading,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Ã°Å¸âÂ¥ BotÃ³n limpiar (solo si hay cÃ³digo)
                        if (_codigoBarrasController.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _codigoBarrasController.clear();
                              });
                            },
                            icon: const Icon(Icons.close, color: Colors.amber),
                            tooltip: 'Limpiar codigo',
                          ),
                        // BotÃ³n escanear
                        IconButton(
                          onPressed: _isScanning ? null : _scanBarcode,
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'Escanear cÃ³digo de barra',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Dropdowns: CategorÃ­a y Unidad de Medida
                    Consumer<DropdownProvider>(
                      builder: (context, dropdownProvider, _) {
                        return Row(
                          children: [
                            /* Expanded(
                              child: SearchSelectField(
                                value: _categoriaId,
                                labelText: 'Categoria',
                                hintText: 'Buscar categoria...',
                                items: dropdownProvider.categorias
                                    .map(
                                      (cat) => SearchSelectOption(
                                        id: cat.id,
                                        nombre: cat.nombre,
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _categoriaId = value);
                                },
                                enabled: !provider.isLoading,
                              ),
                            ), */
                            Expanded(
                              child: SearchSelectField(
                                value: _unidadMedidaId,
                                labelText: 'Unidad Medida',
                                hintText: 'Buscar unidad...',
                                items: dropdownProvider.unidades
                                    .map(
                                      (uni) => SearchSelectOption(
                                        id: uni.id,
                                        nombre: uni.nombre,
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _unidadMedidaId = value);
                                },
                                enabled: !provider.isLoading,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MarcaSearchField(
                                value: _marcaId,
                                onChanged: (value) {
                                  setState(() => _marcaId = value);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    /* const SizedBox(height: 16),
                    // Dropdowns: Marca y Proveedor (opcionales)
                    Consumer<DropdownProvider>(
                      builder: (context, dropdownProvider, _) {
                        return Row(
                          children: [
                            
                            // const SizedBox(width: 12),
                            /* Expanded(
                          child: SearchSelectField(
                            value: _proveedorId,
                            labelText: 'Proveedor',
                            hintText: 'Buscar proveedor...',
                            items: dropdownProvider.proveedores
                                .map(
                                  (prov) => SearchSelectOption(
                                    id: prov.id,
                                    nombre: prov.nombre,
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _proveedorId = value);
                            },
                            enabled: !provider.isLoading,
                          ),
                        ), */
                          ],
                        );
                      },
                    ), */
                    const SizedBox(height: 16),
                    // SKU (solo en edición)
                    if (widget.producto != null) ...[
                      TextField(
                        controller: _skuController,
                        decoration: InputDecoration(
                          labelText: 'SKU',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabled: !provider.isLoading,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // DescripciÃ³n
                    /*TextField(
                  controller: _descripcionController,
                  decoration: InputDecoration(
                    labelText: 'DescripciÃ³n',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabled: !provider.isLoading,
                  ),
                  maxLines: 3,
                    ),*/
                    // const SizedBox(height: 16),
                    // Peso
                    /*TextField(
                  controller: _pesoController,
                  decoration: InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabled: !provider.isLoading,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                    ),
                    const SizedBox(height: 16),*/
                    // Stock MÃ­nimo y MÃ¡ximo
                    /*Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stockMinimoController,
                        decoration: InputDecoration(
                          labelText: 'Stock MÃ­n',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabled: !provider.isLoading,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _stockMaximoController,
                        decoration: InputDecoration(
                          labelText: 'Stock MÃ¡x',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabled: !provider.isLoading,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                    ),
                    const SizedBox(height: 16),*/
                    // LÃ­mite de Venta
                    /*TextField(
                  controller: _limitVentaController,
                  decoration: InputDecoration(
                    labelText: 'LÃ­mite de Venta',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabled: !provider.isLoading,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                    ),
                    const SizedBox(height: 16),*/
                    // Precio Compra y Precio Venta
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _precioCompraController,
                            decoration: InputDecoration(
                              labelText: 'Precio Compra',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabled: !provider.isLoading,
                              hintText: '0.00',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _precioVentaController,
                            decoration: InputDecoration(
                              labelText: 'Precio Venta',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabled: !provider.isLoading,
                              hintText: '0.00',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    /* const SizedBox(height: 24),
                    // Checkboxes
                    CheckboxListTile(
                  title: const Text('Activo'),
                  value: _activo,
                  onChanged: provider.isLoading
                      ? null
                      : (value) {
                          setState(() => _activo = value ?? true);
                        },
                    ), */
                    /*CheckboxListTile(
                  title: const Text('Producto de Comida/Helado'),
                  value: _esProductoComida,
                  onChanged: provider.isLoading
                      ? null
                      : (value) {
                          setState(() => _esProductoComida = value ?? false);
                        },
                    ),
                    CheckboxListTile(
                  title: const Text('Permitir Venta sin Stock'),
                  value: _permitirVentaSinStock,
                  onChanged: provider.isLoading
                      ? null
                      : (value) {
                          setState(
                            () => _permitirVentaSinStock = value ?? false,
                          );
                        },
                    ),*/
                    /* CheckboxListTile(
                  title: const Text('Visible en App'),
                  value: _visibleApp,
                  onChanged: provider.isLoading
                      ? null
                      : (value) {
                          setState(() => _visibleApp = value ?? true);
                        },
                    ),
                 */
                    const SizedBox(height: 16),
                    // ✨ MEJORADO: SECCIÓN DE STOCK POR ALMACÉN
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Stock por Almacén',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Almacén y Sector
                            Consumer<DropdownProvider>(
                              builder: (context, dropdownProvider, _) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<int>(
                                            value:
                                                dropdownProvider.almacenes.any(
                                                  (a) => a.id == _almacenSeleccionado,
                                                )
                                                ? _almacenSeleccionado
                                                : null,
                                            decoration: InputDecoration(
                                              labelText: '📦 Almacén *',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                            ),
                                            items: dropdownProvider.almacenes
                                                .map(
                                                  (almacen) => DropdownMenuItem(
                                                    value: almacen.id,
                                                    child: Text(almacen.nombre),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _almacenSeleccionado = value;
                                                _sectorSeleccionado = null;
                                              });
                                            },
                                            hint: const Text('Selecciona almacén'),
                                            isExpanded: true,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _almacenSeleccionado != null
                                              ? DropdownButtonFormField<int>(
                                                  value: () {
                                                    final sectores = dropdownProvider
                                                        .getSectoresPorAlmacen(
                                                          _almacenSeleccionado!,
                                                        );
                                                    return sectores.any(
                                                          (s) =>
                                                              s['id'] ==
                                                              _sectorSeleccionado,
                                                        )
                                                        ? _sectorSeleccionado
                                                        : null;
                                                  }(),
                                                  decoration: InputDecoration(
                                                    labelText: '🏢 Sector *',
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    contentPadding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                  ),
                                                  items: dropdownProvider
                                                      .getSectoresPorAlmacen(
                                                        _almacenSeleccionado!,
                                                      )
                                                      .map(
                                                        (sector) => DropdownMenuItem<int>(
                                                          value: sector['id'] as int,
                                                          child: Text(
                                                            sector['nombre'] as String,
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (value) {
                                                    setState(
                                                      () => _sectorSeleccionado = value,
                                                    );
                                                    if (value != null &&
                                                        widget.producto != null) {
                                                      _loadExistingStock(
                                                        _almacenSeleccionado!,
                                                        value,
                                                      );
                                                    }
                                                  },
                                                  hint: const Text('Selecciona sector'),
                                                  isExpanded: true,
                                                )
                                              : TextField(
                                                  decoration: InputDecoration(
                                                    labelText: '🏢 Sector',
                                                    hintText: 'Selecciona almacén primero',
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    contentPadding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                  ),
                                                  enabled: false,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            // Cantidad
                            TextField(
                              controller: _cantidadStockController,
                              decoration: InputDecoration(
                                labelText: '📊 Cantidad *',
                                prefixIcon: const Icon(Icons.shopping_cart),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            // Stock Mínimo y Máximo
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _stockMinimoStockController,
                                    decoration: InputDecoration(
                                      labelText: '⬇️ Stock Mín',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _stockMaximoStockController,
                                    decoration: InputDecoration(
                                      labelText: '⬆️ Stock Máx',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            // Lote y Vencimiento
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _loteController,
                                    decoration: InputDecoration(
                                      labelText: '🏷️ Lote (Opcional)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _fechaVencimientoController,
                                    decoration: InputDecoration(
                                      labelText: '📅 Vencimiento',
                                      hintText: 'YYYY-MM-DD',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.calendar_today),
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _fechaVencimientoSeleccionada ??
                                                DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              _fechaVencimientoSeleccionada = picked;
                                              _fechaVencimientoController.text = picked
                                                  .toIso8601String()
                                                  .split('T')[0];
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    readOnly: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ✨ NUEVO: Mostrar stocks agregados
                    if (_stocksAgregados.isNotEmpty) ...[
                      Text(
                        'Stocks Agregados (${_stocksAgregados.length})',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Almacén')),
                              DataColumn(label: Text('Sector')),
                              DataColumn(label: Text('Cantidad')),
                              DataColumn(label: Text('Stock Mín')),  // ✨ NUEVO
                              DataColumn(label: Text('Stock Máx')),  // ✨ NUEVO
                              DataColumn(label: Text('Lote')),
                              DataColumn(label: Text('Vencimiento')),
                              DataColumn(label: Text('Acciones')),
                            ],
                            rows: _stocksAgregados.asMap().entries.map((e) {
                              final idx = e.key;
                              final stock = e.value;
                              return DataRow(
                                cells: [
                                  DataCell(Text(stock['almacen_nombre'] ?? '')),
                                  DataCell(Text(stock['sector_nombre'] ?? '')),
                                  DataCell(Text(stock['cantidad'].toString())),
                                  DataCell(Text((stock['stock_minimo'] ?? 0).toString())),  // ✨ NUEVO
                                  DataCell(Text((stock['stock_maximo'] ?? 0).toString())),  // ✨ NUEVO
                                  DataCell(
                                    Text(stock['lote']?.toString() ?? '-'),
                                  ),
                                  DataCell(
                                    Text(
                                      stock['fecha_vencimiento']?.toString() ??
                                          '-',
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                          ),
                                          color: Colors.blue,
                                          onPressed: () =>
                                              _cargarStockParaEditar(idx),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 18,
                                          ),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          onPressed: () {
                                            setState(() {
                                              _stocksAgregados.removeAt(idx);
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Stock eliminado',
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // ✨ Botones para agregar/actualizar stock
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(
                              _stockEditandoIndex != null
                                  ? Icons.save
                                  : Icons.add,
                            ),
                            label: Text(
                              _stockEditandoIndex != null
                                  ? 'Actualizar Stock'
                                  : 'Agregar Stock a Otro Almacén',
                            ),
                            onPressed:
                                _almacenSeleccionado != null &&
                                    _sectorSeleccionado != null
                                ? () {
                                    _agregarStock(
                                      context.read<DropdownProvider>(),
                                      _almacenSeleccionado!,
                                      _sectorSeleccionado!,
                                    );
                                  }
                                : null,
                          ),
                        ),
                        if (_stockEditandoIndex != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('Cancelar'),
                              onPressed: _cancelarEdicion,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: provider.isLoading
                                ? null
                                : () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Cancelar'),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: provider.isLoading ? null : _handleSave,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: provider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      widget.producto == null
                                          ? 'Crear'
                                          : 'Actualizar',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Indicador de carga
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Cargando informaciÃ³n...',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Por favor espera mientras se cargan\nlas categorias, marcas y otras opciones',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ✨ NUEVO: Widget de búsqueda lazy para marcas
class _MarcaSearchField extends StatefulWidget {
  final int? value;
  final Function(int?) onChanged;

  const _MarcaSearchField({required this.value, required this.onChanged});

  @override
  State<_MarcaSearchField> createState() => _MarcaSearchFieldState();
}

class _MarcaSearchFieldState extends State<_MarcaSearchField> {
  late TextEditingController _controller;
  List<DropdownOption> _resultados = [];
  String? _nombreMarcaActual;
  bool _buscando = false;
  bool _mostrarDropdown = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _cargarMarcaActual();
  }

  @override
  void didUpdateWidget(_MarcaSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el marcaId cambió (cuando se carga el producto completo), recargar
    if (widget.value != oldWidget.value) {
      _cargarMarcaActual();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ✨ Cargar marca actual cuando se edita producto
  Future<void> _cargarMarcaActual() async {
    if (widget.value != null) {
      final dropdownProvider = context.read<DropdownProvider>();
      final marca = await dropdownProvider.getMarcaById(widget.value!);
      if (marca != null && mounted) {
        setState(() {
          _nombreMarcaActual = marca.nombre;
          _controller.text = marca.nombre;
        });
      }
    }
  }

  // ✨ Buscar marcas en tiempo real
  Future<void> _buscarMarcas(String query) async {
    if (query.isEmpty) {
      setState(() {
        _resultados = [];
        _mostrarDropdown = false;
      });
      return;
    }

    setState(() => _buscando = true);

    final dropdownProvider = context.read<DropdownProvider>();
    final resultados = await dropdownProvider.searchMarcas(query);

    if (mounted) {
      setState(() {
        _resultados = resultados;
        _buscando = false;
        _mostrarDropdown = resultados.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Marca',
            hintText: 'Buscar marca...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _buscando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) {
            _buscarMarcas(value);
          },
          onTap: () {
            if (_controller.text.isNotEmpty && _resultados.isNotEmpty) {
              setState(() => _mostrarDropdown = true);
            }
          },
        ),
        // ✨ Dropdown con resultados
        if (_mostrarDropdown && _resultados.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (context, index) {
                final marca = _resultados[index];
                return ListTile(
                  title: Text(marca.nombre),
                  onTap: () {
                    setState(() {
                      _nombreMarcaActual = marca.nombre;
                      _controller.text = marca.nombre;
                      _mostrarDropdown = false;
                      _resultados = [];
                    });
                    widget.onChanged(marca.id);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
