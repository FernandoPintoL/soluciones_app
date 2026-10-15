import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/dropdown_option.dart';
import '../models/producto.dart';
import '../providers/dropdown_provider.dart';
import '../providers/producto_provider.dart';
import '../services/service_locator.dart';
import '../widgets/decoracion_campo.dart';
import '../widgets/marca_search_field.dart';
import '../widgets/overlay_carga.dart';
import '../widgets/producto_form/botones_accion_form.dart';
import '../widgets/producto_form/imagen_producto_card.dart';
import '../widgets/producto_form/stock_form_card.dart';
import '../widgets/producto_form/tabla_stocks.dart';
import '../widgets/search_select_field.dart';
import 'barcode_scanner_screen.dart';

enum _TipoMensaje { exito, error, aviso, neutro }

class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;

  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  // Datos del producto
  late final TextEditingController _nombreController;
  late final TextEditingController _skuController;
  late final TextEditingController _precioCompraController;
  late final TextEditingController _precioVentaController;
  late final TextEditingController _codigoBarrasController;
  int? _marcaId;
  int? _unidadMedidaId;

  // Formulario de stock
  final _cantidadStockController = TextEditingController();
  final _loteController = TextEditingController();
  final _fechaVencimientoController = TextEditingController();
  final _stockMinimoStockController = TextEditingController();
  final _stockMaximoStockController = TextEditingController();
  int? _almacenSeleccionado;
  int? _sectorSeleccionado;
  DateTime? _fechaVencimientoSeleccionada;
  List<Map<String, dynamic>> _stocksAgregados = [];
  int? _stockEditandoIndex; // null = agregando, >= 0 = editando ese índice

  // Imagen
  final ImagePicker _imagePicker = ImagePicker();
  File? _imagenSeleccionada;
  bool _mostrarImagen = false;

  // Producto cargado desde la API (con stocks completos)
  Producto? _productoActual;

  bool get _esNuevo => widget.producto == null;
  Producto? get _productoBase => _productoActual ?? widget.producto;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _precioCompraController = TextEditingController(
      text: p?.precioCompra?.toString() ?? '',
    );
    _precioVentaController = TextEditingController(
      text: p?.precioVenta?.toString() ?? '',
    );
    _codigoBarrasController = TextEditingController(
      text: p?.codigosBarra ?? '',
    );
    _marcaId = p?.marcaId;
    _unidadMedidaId = p?.unidadMedidaId;

    Future.microtask(_cargarDatosIniciales);
  }

  @override
  void dispose() {
    for (final c in [
      _nombreController,
      _skuController,
      _precioCompraController,
      _precioVentaController,
      _codigoBarrasController,
      _cantidadStockController,
      _loteController,
      _fechaVencimientoController,
      _stockMinimoStockController,
      _stockMaximoStockController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers de UI
  // ---------------------------------------------------------------------------

  void _mensaje(
    String texto, {
    _TipoMensaje tipo = _TipoMensaje.exito,
    Duration? duracion,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tipo) {
      _TipoMensaje.exito => scheme.secondary,
      _TipoMensaje.error => scheme.error,
      _TipoMensaje.aviso => Colors.orange,
      _TipoMensaje.neutro => Colors.grey,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: color,
        duration: duracion ?? const Duration(seconds: 4),
      ),
    );
  }

  static String _formatearFecha(DateTime fecha) =>
      fecha.toIso8601String().split('T')[0];

  // ---------------------------------------------------------------------------
  // Carga inicial
  // ---------------------------------------------------------------------------

  /// Carga dropdowns y (si es edición) el producto completo en paralelo, y
  /// recién cuando ambos terminan hace las preselecciones. Así no compiten
  /// dos lógicas distintas por elegir el almacén/sector.
  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;
    final dropdownProvider = context.read<DropdownProvider>();
    final esEdicion = widget.producto != null && widget.producto!.id > 0;

    await Future.wait([
      dropdownProvider.loadDropdownData(),
      if (esEdicion) _loadProductoCompleto(widget.producto!.id),
    ]);
    if (!mounted) return;

    setState(() {
      // Pre-seleccionar unidad con código="UN"
      if (_unidadMedidaId == null) {
        for (final u in dropdownProvider.unidades) {
          if (u.codigo == 'UN') {
            _unidadMedidaId = u.id;
            break;
          }
        }
      }
      _preseleccionarAlmacenYSector(dropdownProvider);
    });

    if (!_esNuevo &&
        _almacenSeleccionado != null &&
        _sectorSeleccionado != null) {
      _loadExistingStock(_almacenSeleccionado!, _sectorSeleccionado!);
    }
  }

  /// Elige almacén y sector iniciales: los del primer stock del producto si
  /// existe; si no, el "Almacén Principal" (o el primero) y su primer sector.
  /// Llamar dentro de setState.
  void _preseleccionarAlmacenYSector(DropdownProvider dropdownProvider) {
    final almacenes = dropdownProvider.almacenes;
    if (almacenes.isEmpty) return;

    final producto = _productoBase;
    final primerStock = (producto != null && producto.stocks.isNotEmpty)
        ? producto.stocks.first
        : null;

    if (_almacenSeleccionado == null) {
      final almacenStock = primerStock?['almacen_id'] as int?;
      _almacenSeleccionado =
          almacenStock ??
          almacenes
              .firstWhere(
                (a) =>
                    a.nombre.toLowerCase().contains('principal') ||
                    a.nombre.toLowerCase().contains('almacen'),
                orElse: () => almacenes.first,
              )
              .id;
    }

    if (_sectorSeleccionado == null) {
      final sectores = dropdownProvider.getSectoresPorAlmacen(
        _almacenSeleccionado!,
      );
      if (sectores.isEmpty) return;
      final sectorStock = primerStock?['sector_id'] as int?;
      final sectorValido =
          sectorStock != null &&
          primerStock?['almacen_id'] == _almacenSeleccionado &&
          sectores.any((s) => s['id'] == sectorStock);
      _sectorSeleccionado = sectorValido
          ? sectorStock
          : sectores.first['id'] as int;
    }
  }

  /// Carga el producto completo desde la API (con stocks y límites).
  Future<void> _loadProductoCompleto(int productoId) async {
    try {
      final producto = await apiService.getProductoById(productoId);
      if (!mounted) return;
      setState(() {
        _productoActual = producto;
        _nombreController.text = producto.nombre;
        _skuController.text = producto.sku ?? '';
        _precioCompraController.text = producto.precioCompra?.toString() ?? '';
        _precioVentaController.text = producto.precioVenta?.toString() ?? '';
        _codigoBarrasController.text = producto.codigosBarra ?? '';
        _marcaId = producto.marcaId;
        _stocksAgregados = _combinarStocksConLimites(producto);
      });
    } catch (e) {
      debugPrint('[ProductoForm] Error cargando producto: $e');
    }
  }

  /// Une cada stock con su límite (stock_minimo/stock_maximo) por almacén+sector.
  List<Map<String, dynamic>> _combinarStocksConLimites(Producto producto) {
    return [
      for (final stock in producto.stocks)
        () {
          final limite = producto.stockLimites.firstWhere(
            (sl) =>
                sl['almacen_id'] == stock['almacen_id'] &&
                sl['sector_id'] == stock['sector_id'],
            orElse: () => <String, dynamic>{},
          );
          return {
            ...stock,
            'stock_minimo': limite['stock_minimo'] ?? 0,
            'stock_maximo': limite['stock_maximo'] ?? 0,
          };
        }(),
    ];
  }

  /// Rellena cantidad, lote y vencimiento con el stock existente del producto
  /// en ese almacén+sector (o solo almacén, para datos antiguos sin sector).
  void _loadExistingStock(int almacenId, int sectorId) {
    final stocks = _productoBase?.stocks ?? const [];
    if (stocks.isEmpty) return;

    final stock = stocks.firstWhere(
      (s) => s['almacen_id'] == almacenId && s['sector_id'] == sectorId,
      orElse: () => stocks.firstWhere(
        (s) => s['almacen_id'] == almacenId,
        orElse: () => {},
      ),
    );

    setState(() {
      if (stock.isEmpty) {
        _cantidadStockController.clear();
        _loteController.clear();
        _fechaVencimientoController.clear();
        _fechaVencimientoSeleccionada = null;
        return;
      }

      _cantidadStockController.text = (stock['cantidad'] ?? 0).toString();
      _loteController.text = stock['lote']?.toString() ?? '';

      final fecha = stock['fecha_vencimiento']?.toString() ?? '';
      _fechaVencimientoController.text = fecha;
      _fechaVencimientoSeleccionada = DateTime.tryParse(fecha);
    });
  }

  // ---------------------------------------------------------------------------
  // Código de barra
  // ---------------------------------------------------------------------------

  void _scanBarcode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (scannerContext) => BarcodeScannerScreen(
          onBarcodeDetected: (codigo) {
            if (mounted) _codigoBarrasController.text = codigo;
            _verifyAndCloseIfExists(scannerContext, codigo);
          },
        ),
      ),
    );
  }

  /// Verifica el código escaneado: si ya pertenece a otro producto avisa,
  /// limpia el campo y cierra el scanner.
  Future<void> _verifyAndCloseIfExists(
    BuildContext scannerContext,
    String codigo,
  ) async {
    if (codigo.isEmpty) return;

    try {
      final producto = await apiService.searchProductoByCodigoBarras(codigo);
      if (!mounted) return;

      if (producto == null) {
        _mensaje(
          'Código de barra disponible para usar',
          duracion: const Duration(seconds: 2),
        );
        return;
      }

      _mensaje(
        'Código de barra ya existe: ${producto.nombre}',
        tipo: _TipoMensaje.error,
        duracion: const Duration(seconds: 3),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _codigoBarrasController.clear();
        if (scannerContext.mounted) Navigator.pop(scannerContext);
      });
    } catch (e) {
      debugPrint('[ProductoForm] Error verificando código: $e');
      if (mounted) _mensaje('Error: $e', tipo: _TipoMensaje.error);
    }
  }

  // ---------------------------------------------------------------------------
  // Stock
  // ---------------------------------------------------------------------------

  void _agregarStock(
    DropdownProvider dropdownProvider,
    int almacenId,
    int sectorId,
  ) {
    final cantidad = int.tryParse(_cantidadStockController.text);
    if (cantidad == null || cantidad < 0) {
      _mensaje('Ingresa una cantidad válida', tipo: _TipoMensaje.error);
      return;
    }

    final stockMinimo = int.tryParse(_stockMinimoStockController.text) ?? 0;
    final stockMaximo = int.tryParse(_stockMaximoStockController.text) ?? 0;
    if (stockMinimo < 0 || stockMaximo < 0) {
      _mensaje(
        'Stock mínimo y máximo no pueden ser negativos',
        tipo: _TipoMensaje.error,
      );
      return;
    }

    final almacen = dropdownProvider.almacenes.firstWhere(
      (a) => a.id == almacenId,
      orElse: () => DropdownOption(id: almacenId, nombre: 'Almacén $almacenId'),
    );
    final sector = dropdownProvider
        .getSectoresPorAlmacen(almacenId)
        .firstWhere((s) => s['id'] == sectorId, orElse: () => {});

    final isEditing = _stockEditandoIndex != null;
    final idExistente = isEditing
        ? _stocksAgregados[_stockEditandoIndex!]['id']
        : null;
    final nuevoStock = <String, dynamic>{
      if (idExistente != null) 'id': idExistente,
      'almacen_id': almacenId,
      'sector_id': sectorId,
      'cantidad': cantidad,
      'stock_minimo': stockMinimo,
      'stock_maximo': stockMaximo,
      'lote': _loteController.text.isNotEmpty ? _loteController.text : null,
      'fecha_vencimiento': _fechaVencimientoSeleccionada != null
          ? _formatearFecha(_fechaVencimientoSeleccionada!)
          : null,
      'almacen_nombre': almacen.nombre,
      'sector_nombre': sector['nombre'] ?? 'Sector $sectorId',
    };

    setState(() {
      if (isEditing) {
        _stocksAgregados[_stockEditandoIndex!] = nuevoStock;
      } else {
        _stocksAgregados.add(nuevoStock);
      }
      _limpiarCamposStock();
    });

    _mensaje(
      isEditing
          ? 'Stock actualizado correctamente'
          : 'Stock agregado correctamente',
    );
  }

  /// Carga un stock de la tabla en el formulario para editarlo.
  void _cargarStockParaEditar(int index) {
    final stock = _stocksAgregados[index];
    final fecha = stock['fecha_vencimiento']?.toString() ?? '';

    setState(() {
      _stockEditandoIndex = index;
      _almacenSeleccionado = stock['almacen_id'];
      _sectorSeleccionado = stock['sector_id'];
      _cantidadStockController.text = stock['cantidad'].toString();
      _stockMinimoStockController.text = (stock['stock_minimo'] ?? 0)
          .toString();
      _stockMaximoStockController.text = (stock['stock_maximo'] ?? 0)
          .toString();
      _loteController.text = stock['lote'] ?? '';
      _fechaVencimientoController.text = fecha;
      _fechaVencimientoSeleccionada = DateTime.tryParse(fecha);
    });

    _mensaje(
      'Editando stock: Almacén ${stock['almacen_nombre']}, '
      'Sector ${stock['sector_nombre']}',
      tipo: _TipoMensaje.aviso,
    );
  }

  /// Deja el formulario de stock vacío y sale del modo edición.
  /// Llamar dentro de setState.
  void _limpiarCamposStock() {
    _stockEditandoIndex = null;
    _almacenSeleccionado = null;
    _sectorSeleccionado = null;
    _cantidadStockController.clear();
    _loteController.clear();
    _fechaVencimientoController.clear();
    _stockMinimoStockController.clear();
    _stockMaximoStockController.clear();
    _fechaVencimientoSeleccionada = null;
  }

  void _cancelarEdicion() {
    setState(_limpiarCamposStock);
    _mensaje('Edición cancelada', tipo: _TipoMensaje.neutro);
  }

  /// Elimina un lote de la lista. Si ya está guardado (tiene id), lo elimina en el servidor
  /// (solo si su stock está en 0). Antes solo se quitaba de la lista y, al guardar, el backend
  /// no lo borraba si el almacén tenía otro lote, así que volvía a aparecer.
  Future<void> _eliminarStock(int idx) async {
    final stock = _stocksAgregados[idx];
    final stockId = stock['id'];
    final descripcion =
        '${stock['almacen_nombre'] ?? 'Almacén'} - ${stock['lote'] ?? 'sin lote'}';

    if (stockId == null) {
      setState(() => _stocksAgregados.removeAt(idx));
      _mensaje('Stock quitado de la lista', tipo: _TipoMensaje.aviso);
      return;
    }

    final cantidad = num.tryParse(stock['cantidad']?.toString() ?? '') ?? 0;
    final tieneStock = cantidad != 0;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tieneStock ? '⚠️ Eliminar lote con stock' : 'Eliminar lote',
        ),
        content: Text(
          tieneStock
              ? 'El lote #$stockId ($descripcion) todavía tiene $cantidad en stock.\n\n'
                    'Al eliminarlo se registrará una SALIDA DE AJUSTE por $cantidad '
                    'y ese stock dejará de estar disponible. Esta acción no se puede deshacer.\n\n'
                    '¿Eliminar de todas formas?'
              : '¿Eliminar el lote #$stockId ($descripcion)?\n\n'
                    'Su historial de movimientos se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(tieneStock ? 'Eliminar con stock' : 'Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final error = await apiService.eliminarStockProducto(
      int.parse(stockId.toString()),
      forzar: tieneStock,
    );
    if (!mounted) return;

    if (error == null) {
      setState(() => _stocksAgregados.removeWhere((s) => s['id'] == stockId));
      _mensaje(
        tieneStock
            ? 'Lote #$stockId eliminado (salida de ajuste por $cantidad)'
            : 'Lote #$stockId eliminado',
        tipo: _TipoMensaje.aviso,
      );
    } else {
      _mensaje(
        error,
        tipo: _TipoMensaje.error,
        duracion: const Duration(seconds: 5),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Imagen
  // ---------------------------------------------------------------------------

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar Imagen'),
        content: const Text('¿De donde deseas tomar la imagen?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _seleccionarImagen(ImageSource.camera);
            },
            child: const Text('Cámara'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _seleccionarImagen(ImageSource.gallery);
            },
            child: const Text('Galería'),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _imagenSeleccionada = File(image.path));
      }
    } catch (e) {
      debugPrint('[ProductoForm] Error seleccionando imagen: $e');
      if (mounted) _mensaje('Error: $e', tipo: _TipoMensaje.error);
    }
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  Future<void> _handleSave() async {
    if (_nombreController.text.isEmpty) {
      _mensaje('El nombre es requerido', tipo: _TipoMensaje.error);
      return;
    }

    // Los campos que no se muestran en el formulario se envían tal como vienen
    final base = widget.producto;
    final descripcion = base?.descripcion;
    final producto = Producto(
      id: base?.id ?? 0,
      nombre: _nombreController.text,
      sku: _skuController.text.isNotEmpty ? _skuController.text : null,
      descripcion: (descripcion?.isNotEmpty ?? false) ? descripcion : null,
      peso: base?.peso,
      unidadMedidaId: _unidadMedidaId,
      marcaId: _marcaId,
      stockMinimo: base?.stockMinimo ?? 0,
      stockMaximo: base?.stockMaximo ?? 0,
      activo: base?.activo ?? true,
      esProductoComida: base?.esProductoComida ?? false,
      permitirVentaSinStock: base?.permitirVentaSinStock ?? false,
      visibleApp: base?.visibleApp ?? true,
      // String vacío en lugar de null para que el backend elimine el código
      codigosBarra: _codigoBarrasController.text,
      limiteventa: base?.limiteventa,
      precioCompra: _precioCompraController.text.isNotEmpty
          ? double.tryParse(_precioCompraController.text)
          : 0.0,
      precioVenta: _precioVentaController.text.isNotEmpty
          ? double.tryParse(_precioVentaController.text)
          : 0.0,
      stocks: _stocksAgregados.isNotEmpty
          ? _stocksAgregados
          : (base?.stocks ?? []),
    );

    final productoProvider = context.read<ProductoProvider>();
    // Id real del producto guardado (en creación lo devuelve la API)
    int? productoId;
    if (_esNuevo) {
      productoId = (await productoProvider.createProducto(producto))?.id;
    } else if (await productoProvider.updateProducto(base!.id, producto)) {
      productoId = base.id;
    }

    if (!mounted) return;

    if (productoId == null) {
      _mensaje(
        productoProvider.errorMessage ?? 'Error al guardar',
        tipo: _TipoMensaje.error,
      );
      return;
    }

    // Los stocks de _stocksAgregados ya viajan en el payload (almacenes).
    // Solo se crea stock aparte si no hay ninguno agregado pero el
    // formulario de stock tiene almacén, sector y cantidad.
    if (_stocksAgregados.isEmpty &&
        _almacenSeleccionado != null &&
        _sectorSeleccionado != null &&
        _cantidadStockController.text.isNotEmpty) {
      final ok = await apiService.crearStockProducto(
        productoId,
        _almacenSeleccionado!,
        _sectorSeleccionado!,
        int.tryParse(_cantidadStockController.text) ?? 0,
        lote: _loteController.text.isNotEmpty ? _loteController.text : null,
        fechaVencimiento: _fechaVencimientoController.text.isNotEmpty
            ? _fechaVencimientoController.text
            : null,
      );
      if (!ok) debugPrint('[ProductoForm] Error creando stock');
    }

    if (_imagenSeleccionada != null) {
      final ok = await apiService.uploadImagenProducto(
        productoId,
        _imagenSeleccionada!.path,
        esPrincipal: true,
        orden: 0,
      );
      if (!ok) debugPrint('[ProductoForm] Error subiendo imagen');
    }

    if (!mounted) return;
    Future.microtask(productoProvider.refresh);
    _mensaje(
      _esNuevo
          ? 'Producto creado correctamente'
          : 'Producto actualizado correctamente',
    );
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esNuevo
              ? 'Nuevo Producto'
              : 'Editar Producto #${widget.producto!.id}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar Categorías, Marcas, Unidades',
            onPressed: () async {
              await context.read<DropdownProvider>().reloadDropdownData();
              if (mounted) {
                _mensaje(
                  'Datos recargados correctamente',
                  duracion: const Duration(seconds: 2),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Consumer2<ProductoProvider, DropdownProvider>(
          builder: (context, provider, dropdownProvider, _) {
            final guardando = provider.isLoading;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nombreController,
                        decoration: decoracionCampo(
                          'Nombre *',
                          enabled: !guardando,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ImagenProductoCard(
                        imagenSeleccionada: _imagenSeleccionada,
                        imagenRemota: widget.producto?.imagenPrincipal,
                        mostrar: _mostrarImagen,
                        habilitado: !guardando,
                        onMostrarChanged: (value) =>
                            setState(() => _mostrarImagen = value),
                        onSeleccionar: _showImageSourceDialog,
                        onQuitar: () =>
                            setState(() => _imagenSeleccionada = null),
                      ),
                      const SizedBox(height: 16),
                      _buildCodigoBarra(guardando),
                      const SizedBox(height: 16),
                      _buildUnidadYMarca(dropdownProvider, guardando),
                      const SizedBox(height: 16),
                      if (!_esNuevo) ...[
                        TextField(
                          controller: _skuController,
                          decoration: decoracionCampo(
                            'SKU',
                            enabled: !guardando,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildPrecios(guardando),
                      const SizedBox(height: 16),
                      StockFormCard(
                        almacenes: dropdownProvider.almacenes,
                        sectores: _almacenSeleccionado != null
                            ? dropdownProvider.getSectoresPorAlmacen(
                                _almacenSeleccionado!,
                              )
                            : const [],
                        almacenSeleccionado: _almacenSeleccionado,
                        sectorSeleccionado: _sectorSeleccionado,
                        onAlmacenChanged: (value) => setState(() {
                          _almacenSeleccionado = value;
                          _sectorSeleccionado = null;
                        }),
                        onSectorChanged: (value) {
                          setState(() => _sectorSeleccionado = value);
                          if (value != null && !_esNuevo) {
                            _loadExistingStock(_almacenSeleccionado!, value);
                          }
                        },
                        cantidadController: _cantidadStockController,
                        stockMinimoController: _stockMinimoStockController,
                        stockMaximoController: _stockMaximoStockController,
                        loteController: _loteController,
                        fechaVencimientoController: _fechaVencimientoController,
                        onElegirFecha: _elegirFechaVencimiento,
                      ),
                      const SizedBox(height: 12),
                      if (_stocksAgregados.isNotEmpty) ...[
                        TablaStocks(
                          stocks: _stocksAgregados,
                          onEditar: _cargarStockParaEditar,
                          onEliminar: _eliminarStock,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildBotonesStock(dropdownProvider),
                      const SizedBox(height: 12),
                      BotonesAccionForm(
                        guardando: guardando,
                        esNuevo: _esNuevo,
                        onCancelar: () => Navigator.pop(context),
                        onGuardar: _handleSave,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                if (guardando || dropdownProvider.isLoading)
                  const OverlayCarga(
                    detalle: 'Por favor espera mientras se cargan\nlas categorias, marcas y otras opciones',
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCodigoBarra(bool guardando) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codigoBarrasController,
            decoration: decoracionCampo('Codigo de Barra', enabled: !guardando),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _codigoBarrasController,
          builder: (context, valor, _) => valor.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: _codigoBarrasController.clear,
                  icon: const Icon(Icons.close, color: Colors.amber),
                  tooltip: 'Limpiar codigo',
                ),
        ),
        IconButton(
          onPressed: _scanBarcode,
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: 'Escanear código de barra',
        ),
      ],
    );
  }

  Widget _buildUnidadYMarca(DropdownProvider dropdownProvider, bool guardando) {
    return Row(
      children: [
        Expanded(
          child: SearchSelectField(
            value: _unidadMedidaId,
            labelText: 'Unidad Medida',
            hintText: 'Buscar unidad...',
            items: [
              for (final uni in dropdownProvider.unidades)
                SearchSelectOption(id: uni.id, nombre: uni.nombre),
            ],
            onChanged: (value) => setState(() => _unidadMedidaId = value),
            enabled: !guardando,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MarcaSearchField(
            value: _marcaId,
            onChanged: (value) => setState(() => _marcaId = value),
          ),
        ),
      ],
    );
  }

  Widget _buildPrecios(bool guardando) {
    const teclado = TextInputType.numberWithOptions(decimal: true);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _precioCompraController,
            decoration: decoracionCampo(
              'Precio Compra',
              hint: '0.00',
              enabled: !guardando,
            ),
            keyboardType: teclado,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _precioVentaController,
            decoration: decoracionCampo(
              'Precio Venta',
              hint: '0.00',
              enabled: !guardando,
            ),
            keyboardType: teclado,
          ),
        ),
      ],
    );
  }

  Widget _buildBotonesStock(DropdownProvider dropdownProvider) {
    final editando = _stockEditandoIndex != null;
    final puedeAgregar =
        _almacenSeleccionado != null && _sectorSeleccionado != null;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(editando ? Icons.save : Icons.add),
            label: Text(
              editando ? 'Actualizar Stock' : 'Agregar Stock a Otro Almacén',
            ),
            onPressed: puedeAgregar
                ? () => _agregarStock(
                    dropdownProvider,
                    _almacenSeleccionado!,
                    _sectorSeleccionado!,
                  )
                : null,
          ),
        ),
        if (editando) ...[
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
    );
  }

  Future<void> _elegirFechaVencimiento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVencimientoSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _fechaVencimientoSeleccionada = picked;
        _fechaVencimientoController.text = _formatearFecha(picked);
      });
    }
  }
}
