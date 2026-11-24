import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/colores_app.dart';

import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/dropdown_option.dart';
import '../models/producto.dart';
import '../models/tipo_precio_opcion.dart';
import '../providers/dropdown_provider.dart';
import '../providers/producto_provider.dart';
import '../services/service_locator.dart';
import '../widgets/campo_formulario.dart';
import '../widgets/marca_search_field.dart';
import '../widgets/overlay_carga.dart';
import '../widgets/producto_form/botones_accion_form.dart';
import '../widgets/producto_form/imagen_producto_card.dart';
import '../widgets/producto_form/conversion_editor_sheet.dart';
import '../widgets/producto_form/stock_editor_sheet.dart';
import '../widgets/producto_form/codigo_barras_validacion.dart';
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
  // Precios por tipo de precio: controlador de monto por tipo_precio_id,
  // tipos activos y montos que el usuario editó a mano (no se recalculan)
  final Map<int, TextEditingController> _montoCtrl = {};
  final Set<int> _tiposActivos = {};
  final Set<int> _montoManual = {};
  late final TextEditingController _codigoBarrasController;
  int? _marcaId;
  int? _unidadMedidaId;

  // Stocks del producto: es lo que se envía al backend al guardar
  List<Map<String, dynamic>> _stocksAgregados = [];

  // Fraccionamiento: conversiones de unidad (producto padre → hijo)
  bool _esFraccionado = false;
  List<Map<String, dynamic>> _conversiones = [];

  // Imagen
  final ImagePicker _imagePicker = ImagePicker();
  File? _imagenSeleccionada;

  // Producto cargado desde la API (con stocks completos)
  Producto? _productoActual;
  bool _recargando = false;
  // Estado del formulario tal como quedó tras la última carga; si difiere
  // del actual, hay cambios sin guardar
  String? _firmaCargada;

  bool get _esNuevo => widget.producto == null;

  String _firmaFormulario() => jsonEncode([
    _nombreController.text,
    _skuController.text,
    {for (final e in _montoCtrl.entries) '${e.key}': e.value.text},
    (_tiposActivos.toList()..sort()),
    _codigoBarrasController.text,
    _marcaId,
    _unidadMedidaId,
    _stocksAgregados,
    _esFraccionado,
    _conversiones,
  ]);

  bool get _hayCambiosSinGuardar =>
      _imagenSeleccionada != null ||
      (_firmaCargada != null && _firmaFormulario() != _firmaCargada);

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    if (p != null) _aplicarPreciosDelProducto(p);
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
      _codigoBarrasController,
    ]) {
      c.dispose();
    }
    for (final c in _montoCtrl.values) {
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
      _TipoMensaje.aviso => AppColores.naranja,
      _TipoMensaje.neutro => AppColores.gris,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: color,
        duration: duracion ?? const Duration(seconds: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Carga inicial
  // ---------------------------------------------------------------------------

  /// Carga dropdowns y (si es edición) el producto completo en paralelo, y
  /// cuando ambos terminan preselecciona la unidad "UN".
  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;
    final dropdownProvider = context.read<DropdownProvider>();
    final esEdicion = widget.producto != null && widget.producto!.id > 0;

    await Future.wait([
      dropdownProvider.loadDropdownData(),
      if (esEdicion) _loadProductoCompleto(widget.producto!.id),
    ]);
    if (!mounted) return;

    // Pre-seleccionar unidad con código="UN"
    if (_unidadMedidaId == null) {
      final unidadUN = dropdownProvider.unidades
          .where((u) => u.codigo == 'UN')
          .firstOrNull;
      if (unidadUN != null) setState(() => _unidadMedidaId = unidadUN.id);
    }
    _firmaCargada = _firmaFormulario();
  }

  /// Carga el producto completo desde la API (con stocks y límites) y
  /// reemplaza lo que hay en el formulario. Devuelve false si falló.
  Future<bool> _loadProductoCompleto(int productoId) async {
    try {
      final producto = await apiService.getProductoById(productoId);
      if (!mounted) return false;
      setState(() {
        _productoActual = producto;
        _nombreController.text = producto.nombre;
        _skuController.text = producto.sku ?? '';
        _aplicarPreciosDelProducto(producto);
        _codigoBarrasController.text = producto.codigosBarra ?? '';
        _marcaId = producto.marcaId;
        _unidadMedidaId = producto.unidadMedidaId ?? _unidadMedidaId;
        _stocksAgregados = _combinarStocksConLimites(producto);
        _esFraccionado = producto.esFraccionado ?? false;
        _conversiones = [...producto.conversiones];
      });
      return true;
    } catch (e) {
      debugPrint('[ProductoForm] Error cargando producto: $e');
      return false;
    }
  }

  /// Botón recargar: actualiza marcas/unidades/almacenes y, si se está
  /// editando, vuelve a traer el producto desde el servidor (descartando
  /// los cambios sin guardar, previa confirmación).
  Future<void> _recargar() async {
    if (!_esNuevo && _hayCambiosSinGuardar) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text(
            'Al recargar se traerá la información actual del producto '
            'y se perderán los cambios que no guardaste.\n\n¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar y recargar'),
            ),
          ],
        ),
      );
      if (descartar != true || !mounted) return;
    }

    setState(() => _recargando = true);
    final resultados = await Future.wait([
      context.read<DropdownProvider>().reloadDropdownData().then((_) => true),
      if (!_esNuevo) _loadProductoCompleto(widget.producto!.id),
    ]);
    if (!mounted) return;

    setState(() {
      _recargando = false;
      if (!_esNuevo) _imagenSeleccionada = null;
    });
    if (resultados.every((ok) => ok)) {
      _firmaCargada = _firmaFormulario();
      _mensaje(
        _esNuevo ? 'Datos recargados' : 'Producto y datos recargados',
        duracion: const Duration(seconds: 2),
      );
    } else {
      _mensaje(
        'No se pudo recargar el producto. Intenta de nuevo.',
        tipo: _TipoMensaje.error,
      );
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

  /// Abre el editor de stock: sin [index] agrega una fila nueva; con
  /// [index] edita esa fila de la tabla.
  Future<void> _abrirEditorStock([int? index]) async {
    final resultado = await StockEditorSheet.mostrar(
      context,
      stockInicial: index != null ? _stocksAgregados[index] : null,
    );
    if (resultado == null || !mounted) return;

    setState(() {
      if (index != null) {
        _stocksAgregados[index] = resultado;
      } else {
        _stocksAgregados.add(resultado);
      }
    });
    _mensaje(
      index != null
          ? 'Stock actualizado correctamente'
          : 'Stock agregado correctamente',
    );
  }

  // ---------------------------------------------------------------------------
  // Fraccionamiento
  // ---------------------------------------------------------------------------

  /// Mismas reglas que la web antes de guardar. Null si todo está bien.
  String? _validarConversiones() {
    if (!_esFraccionado) return null;
    if (_conversiones.isEmpty) {
      return 'Producto fraccionado sin conversiones: agrega al menos una o '
          'desactiva "Permitir conversiones".';
    }
    if (_conversiones.any((c) => c['unidad_base_id'] != _unidadMedidaId)) {
      return 'Las conversiones usan una unidad base distinta a la del '
          'producto. Edítalas o elimínalas.';
    }
    final principales = _conversiones
        .where((c) => c['es_conversion_principal'] == true)
        .length;
    if (principales != 1) {
      return 'Debe haber exactamente una conversión principal (⭐).';
    }
    return null;
  }

  /// Sin [index] agrega una conversión; con [index] edita esa.
  Future<void> _abrirEditorConversion([int? index]) async {
    final unidadBase = _unidadMedidaId;
    if (unidadBase == null) {
      _mensaje(
        'Primero selecciona la unidad de medida del producto',
        tipo: _TipoMensaje.aviso,
      );
      return;
    }

    final resultado = await ConversionEditorSheet.mostrar(
      context,
      unidadBaseId: unidadBase,
      productoId: widget.producto?.id,
      conversiones: _conversiones,
      indiceEditando: index,
    );
    if (resultado == null || !mounted) return;

    setState(() {
      // Solo una principal: la nueva/editada desmarca a las demás
      if (resultado['es_conversion_principal'] == true) {
        _conversiones = [
          for (final c in _conversiones)
            {...c, 'es_conversion_principal': false},
        ];
      }
      if (index != null) {
        _conversiones[index] = resultado;
      } else {
        _conversiones.add(resultado);
      }
    });
  }

  void _eliminarConversion(int index) {
    setState(() => _conversiones = [..._conversiones]..removeAt(index));
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

  /// Hoja inferior para elegir el origen de la foto (cámara o galería).
  void _showImageSourceDialog() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Foto del producto',
                    style: Theme.of(ctx).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar foto'),
                subtitle: const Text('Usa la cámara del teléfono'),
                onTap: () {
                  Navigator.pop(ctx);
                  _seleccionarImagen(ImageSource.camera);
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                subtitle: const Text('Una foto que ya tengas guardada'),
                onTap: () {
                  Navigator.pop(ctx);
                  _seleccionarImagen(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
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
    final tiposPrecio = context.read<DropdownProvider>().tiposPrecio;
    final errorPrecios = _validarPrecios(tiposPrecio);
    if (errorPrecios != null) {
      _mensaje(errorPrecios, tipo: _TipoMensaje.error);
      return;
    }
    final errorConversiones = _validarConversiones();
    if (errorConversiones != null) {
      _mensaje(errorConversiones, tipo: _TipoMensaje.error);
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
      // '' = el usuario borró el código → el backend lo elimina. Si no se
      // pudo cargar el producto, un campo vacío no es confiable: null = no tocar
      codigosBarra:
          (_esNuevo ||
              _productoActual != null ||
              _codigoBarrasController.text.trim().isNotEmpty)
          ? _codigoBarrasController.text
          : null,
      limiteventa: base?.limiteventa,
      // Igual que el stock: si no se pudo cargar el producto o no hay tipos,
      // null = no tocar los precios (una lista vacía los quitaría todos)
      preciosPorTipo:
          (_esNuevo || _productoActual != null) && tiposPrecio.isNotEmpty
          ? _preciosParaGuardar(tiposPrecio)
          : null,
      // La tabla es lo que se guarda. Si al editar no se pudo cargar el
      // producto completo, la tabla está vacía por error: se reenvían los
      // stocks originales para no perderlos.
      stocks: (_esNuevo || _productoActual != null)
          ? _stocksAgregados
          : (base?.stocks ?? []),
      // Igual que el stock: si no se pudo cargar el producto, null = el
      // backend deja las conversiones como están
      esFraccionado: (_esNuevo || _productoActual != null)
          ? _esFraccionado
          : null,
      conversiones: _conversiones,
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
            tooltip: _esNuevo
                ? 'Recargar marcas, unidades y almacenes'
                : 'Recargar producto, marcas, unidades y almacenes',
            onPressed: _recargando ? null : _recargar,
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
                      _seccionFlat('Información', Icons.inventory_2_outlined, [
                        CampoTexto(
                          controller: _nombreController,
                          label: 'Nombre *',
                          enabled: !guardando,
                        ),
                        const SizedBox(height: 16),
                        ImagenProductoCard(
                          imagenSeleccionada: _imagenSeleccionada,
                          imagenRemota: (_productoActual ?? widget.producto)
                              ?.imagenPrincipal,
                          habilitado: !guardando,
                          onSeleccionar: _showImageSourceDialog,
                          onQuitar: () =>
                              setState(() => _imagenSeleccionada = null),
                        ),
                        const SizedBox(height: 16),
                        _buildCodigoBarra(guardando),
                        const SizedBox(height: 16),
                        _buildUnidadYMarca(dropdownProvider, guardando),
                        if (!_esNuevo) ...[
                          const SizedBox(height: 16),
                          CampoTexto(
                            controller: _skuController,
                            label: 'SKU',
                            enabled: !guardando,
                          ),
                        ],
                      ]),
                      const SizedBox(height: 16),
                      _seccionFlat('Precios', Icons.sell_outlined, [
                        _buildPrecios(guardando, dropdownProvider.tiposPrecio),
                      ]),
                      const SizedBox(height: 16),
                      _buildSeccionStock(),
                      const SizedBox(height: 16),
                      _buildSeccionFraccionamiento(dropdownProvider),
                      const SizedBox(height: 16),
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
                if (guardando || _recargando || dropdownProvider.isLoading)
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

  /// Bloque plano con título e icono; [accion] va a la derecha del encabezado.
  Widget _seccionFlat(
    String titulo,
    IconData icono,
    List<Widget> hijos, {
    Widget? accion,
  }) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    return Material(
      color: colores.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colores.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: colores.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (accion != null) accion,
              ],
            ),
            const SizedBox(height: 14),
            ...hijos,
          ],
        ),
      ),
    );
  }

  /// Campo con escanear y limpiar dentro, y una pista que valida el formato GS1.
  Widget _buildCodigoBarra(bool guardando) {
    final estado = AppColores.estado(context);
    final tema = Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _codigoBarrasController,
      builder: (context, valor, _) {
        final texto = valor.text.trim();
        final resultado = texto.isEmpty ? null : evaluarCodigoBarra(texto);
        final (icono, color) = switch (resultado?.nivel) {
          NivelCodigo.ok => (Icons.check_circle_outline, estado.verde),
          NivelCodigo.aviso => (Icons.warning_amber_rounded, estado.naranja),
          NivelCodigo.info => (
            Icons.info_outline,
            tema.colorScheme.onSurfaceVariant,
          ),
          null => (Icons.info_outline, tema.colorScheme.onSurfaceVariant),
        };
        final mensaje =
            resultado?.mensaje ??
            'Escanea el código o escríbelo. Acepta EAN-13, EAN-8, UPC-A o GTIN-14.';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CampoTexto(
              controller: _codigoBarrasController,
              label: 'Código de barras',
              hint: 'Escanea o escribe',
              enabled: !guardando,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.qr_code_2),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (texto.isNotEmpty && !guardando)
                      IconButton(
                        tooltip: 'Limpiar código',
                        onPressed: _codigoBarrasController.clear,
                        icon: const Icon(Icons.close),
                      ),
                    IconButton.filledTonal(
                      tooltip: 'Escanear código de barras',
                      onPressed: guardando ? null : _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      mensaje,
                      style: tema.textTheme.labelSmall?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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

  // ---------------------------------------------------------------------------
  // Precios por tipo de precio (tipos_precio): costo y precios de venta
  // ---------------------------------------------------------------------------

  TextEditingController _ctrlMonto(int tipoId) =>
      _montoCtrl.putIfAbsent(tipoId, TextEditingController.new);

  double _numeroDe(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;

  TipoPrecioOpcion? _costoDe(List<TipoPrecioOpcion> tipos) =>
      tipos.where((t) => t.esPrecioBase).firstOrNull;

  /// Carga los precios del producto. Los que ya existen se toman como fijados
  /// a mano: no se recalculan solos al cambiar el costo.
  void _aplicarPreciosDelProducto(Producto p) {
    for (final c in _montoCtrl.values) {
      c.text = '';
    }
    _tiposActivos.clear();
    _montoManual.clear();
    (p.preciosPorTipo ?? const <int, double>{}).forEach((tipoId, monto) {
      _ctrlMonto(tipoId).text = monto.toStringAsFixed(2);
      _tiposActivos.add(tipoId);
      _montoManual.add(tipoId);
    });
  }

  /// Monto sugerido: costo + porcentaje de ganancia del tipo.
  void _calcularMonto(TipoPrecioOpcion tipo, double costo) {
    if (tipo.esPrecioBase || tipo.porcentajeGanancia <= 0 || costo <= 0) return;
    _ctrlMonto(tipo.id).text = (costo * (1 + tipo.porcentajeGanancia / 100))
        .toStringAsFixed(2);
  }

  /// Al cambiar el costo se recalculan los montos que no se editaron a mano.
  void _recalcularMontos(List<TipoPrecioOpcion> tipos) {
    final costoTipo = _costoDe(tipos);
    if (costoTipo == null) return;
    final costo = _numeroDe(_ctrlMonto(costoTipo.id).text);
    for (final t in tipos) {
      if (!_montoManual.contains(t.id)) _calcularMonto(t, costo);
    }
  }

  void _alActivarTipo(
    TipoPrecioOpcion tipo,
    bool activo,
    List<TipoPrecioOpcion> tipos,
  ) {
    setState(() {
      if (!activo) {
        _tiposActivos.remove(tipo.id);
        return;
      }
      _tiposActivos.add(tipo.id);
      // Al activarlo se sugiere el monto si todavía está vacío
      final costoTipo = _costoDe(tipos);
      if (costoTipo != null &&
          _ctrlMonto(tipo.id).text.isEmpty &&
          !_montoManual.contains(tipo.id)) {
        _calcularMonto(tipo, _numeroDe(_ctrlMonto(costoTipo.id).text));
      }
    });
  }

  /// Mismo criterio que el backend: ningún precio puede quedar bajo el costo.
  String? _validarPrecios(List<TipoPrecioOpcion> tipos) {
    final costoTipo = _costoDe(tipos);
    if (costoTipo == null) return null;
    final costo = _numeroDe(_ctrlMonto(costoTipo.id).text);
    if (costo <= 0) return null;
    for (final t in tipos) {
      if (t.esPrecioBase || !_tiposActivos.contains(t.id)) continue;
      final monto = _numeroDe(_ctrlMonto(t.id).text);
      if (monto > 0 && monto < costo) {
        return 'El precio de ${t.nombre} (${monto.toStringAsFixed(2)}) '
            'no puede ser menor al costo (${costo.toStringAsFixed(2)}).';
      }
    }
    return null;
  }

  /// Costo (siempre que tenga monto) y cada tipo activo con monto > 0.
  Map<int, double> _preciosParaGuardar(List<TipoPrecioOpcion> tipos) {
    final resultado = <int, double>{};
    for (final t in tipos) {
      if (!t.esPrecioBase && !_tiposActivos.contains(t.id)) continue;
      final monto = _numeroDe(_ctrlMonto(t.id).text);
      if (monto > 0) resultado[t.id] = monto;
    }
    return resultado;
  }

  Widget _buildPrecios(bool guardando, List<TipoPrecioOpcion> tipos) {
    final theme = Theme.of(context);
    if (tipos.isEmpty) {
      return Text(
        'No hay tipos de precio activos en la empresa.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final costoTipo = _costoDe(tipos);
    final otros = tipos.where((t) => !t.esPrecioBase).toList();
    // Precios guardados de tipos que ya no están activos: no se pueden editar aquí
    final huerfanos =
        _tiposActivos.where((id) => !tipos.any((t) => t.id == id)).toList()
          ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (costoTipo != null)
          CampoTexto(
            controller: _ctrlMonto(costoTipo.id),
            label: 'Costo de compra',
            hint: '0.00',
            enabled: !guardando,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _recalcularMontos(tipos)),
          ),
        for (final t in otros) ...[
          const SizedBox(height: 10),
          _filaPrecio(t, tipos, guardando),
        ],
        for (final id in huerfanos) _avisoTipoInactivo(id),
      ],
    );
  }

  /// Aviso para un precio cuyo tipo ya no está activo: se quita al guardar.
  Widget _avisoTipoInactivo(int tipoId) {
    final tema = Theme.of(context);
    final estado = AppColores.estado(context);
    final monto = _numeroDe(_ctrlMonto(tipoId).text);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: estado.naranja.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: estado.naranja),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hay un precio de Bs ${monto.toStringAsFixed(2)} de un tipo '
                'inactivo. Se quitará al guardar.',
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Un tipo de precio: checkbox para activarlo, monto y margen sobre el costo.
  Widget _filaPrecio(
    TipoPrecioOpcion tipo,
    List<TipoPrecioOpcion> tipos,
    bool guardando,
  ) {
    final colores = Theme.of(context).colorScheme;
    final tema = Theme.of(context);
    final activo = _tiposActivos.contains(tipo.id);
    final monto = _ctrlMonto(tipo.id);
    final costoTipo = _costoDe(tipos);
    final costoCtrl = costoTipo == null ? null : _ctrlMonto(costoTipo.id);

    return Material(
      color: colores.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colores.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          children: [
            Checkbox(
              value: activo,
              onChanged: guardando
                  ? null
                  : (v) => _alActivarTipo(tipo, v ?? false, tipos),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  monto,
                  if (costoCtrl != null) costoCtrl,
                ]),
                builder: (context, child) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tipo.nombre,
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _textoMargen(tipo, costoCtrl, monto),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: CampoTexto(
                controller: monto,
                label: 'Monto',
                hint: '0.00',
                compacta: true,
                enabled: activo && !guardando,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  _montoManual.add(tipo.id);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ganancia en Bs y % sobre el costo (verde), o aviso si queda bajo el costo (rojo).
  Widget _textoMargen(
    TipoPrecioOpcion tipo,
    TextEditingController? costoCtrl,
    TextEditingController monto,
  ) {
    final tema = Theme.of(context);
    final estado = AppColores.estado(context);
    final costo = costoCtrl == null ? 0.0 : _numeroDe(costoCtrl.text);
    final precio = _numeroDe(monto.text);

    var texto = '';
    var color = tema.colorScheme.onSurfaceVariant;
    if (precio <= 0) {
      texto = tipo.porcentajeGanancia > 0
          ? 'Sugerido +${tipo.porcentajeGanancia.toStringAsFixed(0)}% sobre el costo'
          : 'Sin monto';
    } else if (costo <= 0) {
      texto = 'Ingresa el costo para ver la ganancia';
    } else {
      final ganancia = precio - costo;
      final pct = ganancia / costo * 100;
      if (ganancia < 0) {
        texto = 'Debajo del costo (${ganancia.toStringAsFixed(2)} Bs)';
        color = estado.rojo;
      } else {
        texto =
            'Ganancia ${ganancia.toStringAsFixed(2)} Bs · ${pct.toStringAsFixed(1)}%';
        color = estado.verde;
      }
    }
    return Text(
      texto,
      style: tema.textTheme.labelSmall?.copyWith(color: color),
    );
  }

  /// Conversiones de unidad (fraccionamiento): mismas reglas y avisos que
  /// el paso "Conversiones" del formulario web.
  Widget _buildSeccionFraccionamiento(DropdownProvider dropdownProvider) {
    final theme = Theme.of(context);
    final unidades = dropdownProvider.unidades;
    final baseCorta = etiquetaUnidad(unidades, _unidadMedidaId, corta: true);
    final sinPrincipal =
        _conversiones.isNotEmpty &&
        !_conversiones.any((c) => c['es_conversion_principal'] == true);
    final baseDistinta = _conversiones.any(
      (c) => c['unidad_base_id'] != _unidadMedidaId,
    );

    Widget aviso(String texto, Color color) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto, style: theme.textTheme.bodySmall),
    );

    return _seccionFlat(
      'Fraccionamiento',
      Icons.call_split,
      [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Permitir conversiones de unidades'),
          subtitle: Text(
            'Unidad base: ${etiquetaUnidad(unidades, _unidadMedidaId)}',
          ),
          value: _esFraccionado,
          onChanged: (v) => setState(() => _esFraccionado = v),
        ),
        if (_esFraccionado) ...[
          if (baseDistinta)
            aviso(
              '⚠️ Las conversiones usan una unidad base distinta a la del '
              'producto ($baseCorta). Edítalas o elimínalas.',
              theme.colorScheme.error,
            ),
          if (sinPrincipal)
            aviso(
              '⚡ Sin conversión principal: edita una y márcala con ⭐.',
              AppColores.estado(context).naranja,
            ),
          if (_conversiones.isEmpty)
            aviso(
              '📝 Aún no hay conversiones. Agrega al menos una para poder '
              'vender en otras unidades.',
              AppColores.estado(context).naranja,
            ),
          for (final (i, conv) in _conversiones.indexed)
            _buildConversionTile(i, conv, unidades, baseCorta),
        ],
      ],
      accion: _esFraccionado
          ? FilledButton.tonalIcon(
              onPressed: () => _abrirEditorConversion(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
    );
  }

  Widget _buildConversionTile(
    int index,
    Map<String, dynamic> conv,
    List<DropdownOption> unidades,
    String baseCorta,
  ) {
    final theme = Theme.of(context);
    final destino = etiquetaUnidad(
      unidades,
      conv['unidad_destino_id'] as int?,
      corta: true,
    );
    final hijo = conv['producto_destino'] as Map?;
    final nombreVenta = conv['nombre_cuando_se_vende_como'];
    final activo = conv['activo'] != false;
    final principal = conv['es_conversion_principal'] == true;
    final factor = formatearFactor(conv['factor_conversion']);

    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: activo ? null : theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        title: Text(
          '${principal ? '⭐ ' : ''}1 $baseCorta = $factor $destino'
          '${activo ? '' : '  (inactiva)'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conv['producto_destino_id'] != null)
              Text(
                '👶 ${hijo?['nombre'] ?? 'Producto #${conv['producto_destino_id']}'}'
                '${hijo?['sku'] != null ? ' · ${hijo!['sku']}' : ''}',
              ),
            Text('📦 Venta: ${nombreVenta ?? 'Automático'}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: AppColores.estado(context).azul,
              tooltip: 'Editar',
              onPressed: () => _abrirEditorConversion(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              color: theme.colorScheme.error,
              tooltip: 'Eliminar',
              onPressed: () => _eliminarConversion(index),
            ),
          ],
        ),
      ),
    );
  }

  /// Stock del producto: la tabla es lo que se guarda; las filas se
  /// agregan/editan en un bottom sheet.
  Widget _buildSeccionStock() {
    final theme = Theme.of(context);
    return _seccionFlat(
      'Stock por Almacén',
      Icons.inventory_2_outlined,
      [
        if (_stocksAgregados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sin stock cargado. Usa "Agregar" para cargar stock en un almacén.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          TablaStocks(
            stocks: _stocksAgregados,
            onEditar: _abrirEditorStock,
            onEliminar: _eliminarStock,
          ),
      ],
      accion: FilledButton.tonalIcon(
        onPressed: () => _abrirEditorStock(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}
