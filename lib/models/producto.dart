class Producto {
  final int id;
  final String nombre;
  final String? sku;
  final String? descripcion;
  final double? peso;
  final int? unidadMedidaId;
  final int? categoriaId;
  final int? marcaId;
  final String? marcaNombre;  // Nombre de la marca
  final int? proveedorId;
  final int stockMinimo;
  final int stockMaximo;
  final bool activo;
  final bool esProductoComida;
  final bool permitirVentaSinStock;
  final bool esProductoAdicional;
  final bool puedeRecbirProductoAdicional;
  final bool visibleApp;
  final bool esDeProduccion;
  final double? limiteventa;
  final double? precioCompra;
  final double? precioVenta;
  final String? principioActivo;
  final String? usoMedicacion;
  final DateTime? fechaCreacion;
  final List<String> imagenesUrls;  // URLs de imágenes
  final String? codigosBarra;  // Códigos de barra
  final List<Map<String, dynamic>> stocks;  // Stocks por almacén/sector
  final List<Map<String, dynamic>> stockLimites;  // Límites por almacén/sector
  // Fraccionamiento: null = no informado (al guardar no se tocan las conversiones)
  final bool? esFraccionado;
  final List<Map<String, dynamic>> conversiones;  // Conversiones de unidad / producto hijo

  // Obtener la primera imagen (principal)
  String? get imagenPrincipal => imagenesUrls.isNotEmpty ? imagenesUrls.first : null;

  // Verificar si tiene código de barra
  bool get tieneCodigoBarras => codigosBarra != null && codigosBarra!.isNotEmpty;

  // Obtener stock total (suma de TODOS los lotes)
  int get stockTotal {
    if (stocks.isEmpty) {
      // print('📦 [Producto $id] Sin stocks');
      return 0;
    }

    int total = 0;
    for (final stock in stocks) {
      final cantidad = stock['cantidad'];
      // Convertir a número sin importar el tipo
      num value = 0;
      if (cantidad is num) {
        value = cantidad;
      } else if (cantidad is String) {
        value = num.tryParse(cantidad) ?? 0;
      }
      total += value.toInt();
    }
    // print('📦 [Producto $id] stockTotal = $total (suma de ${stocks.length} lotes)');
    return total;
  }

  Producto({
    required this.id,
    required this.nombre,
    this.sku,
    this.descripcion,
    this.peso,
    this.unidadMedidaId,
    this.categoriaId,
    this.marcaId,
    this.marcaNombre,
    this.proveedorId,
    this.stockMinimo = 0,
    this.stockMaximo = 0,
    this.activo = true,
    this.esProductoComida = false,
    this.permitirVentaSinStock = false,
    this.esProductoAdicional = false,
    this.puedeRecbirProductoAdicional = false,
    this.visibleApp = true,
    this.esDeProduccion = false,
    this.limiteventa,
    this.precioCompra,
    this.precioVenta,
    this.principioActivo,
    this.usoMedicacion,
    this.fechaCreacion,
    this.imagenesUrls = const [],
    this.codigosBarra,
    this.stocks = const [],
    this.stockLimites = const [],
    this.esFraccionado,
    this.conversiones = const [],
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    // Extraer URLs de imágenes (si existen)
    final List<String> imagenesUrls = [];
    final imagenes = json['imagenes'] as List?;
    if (imagenes != null && imagenes.isNotEmpty) {
      // Ordenar por es_principal (true primero), luego por orden
      final imagenesOrdenadas = List<Map<String, dynamic>>.from(
        imagenes.map((img) => img as Map<String, dynamic>)
      );
      imagenesOrdenadas.sort((a, b) {
        final aPrincipal = a['es_principal'] == true ? 0 : 1;
        final bPrincipal = b['es_principal'] == true ? 0 : 1;
        if (aPrincipal != bPrincipal) return aPrincipal.compareTo(bPrincipal);
        return (a['orden'] ?? 0).compareTo(b['orden'] ?? 0);
      });
      imagenesUrls.addAll(
        imagenesOrdenadas.map((img) => (img['url'] as String?) ?? '').where((url) => url.isNotEmpty),
      );
    }

    // Extraer código de barra principal (si existe)
    String? codigoBarraPrincipal;

    // Intentar obtener de codigosBarra (camelCase, usado por búsqueda) o codigos_barra (snake_case)
    final codigosBarra = json['codigosBarra'] ?? json['codigos_barra'];

    if (codigosBarra is List && codigosBarra.isNotEmpty) {
      // Buscar el código de barra principal
      for (var cb in codigosBarra) {
        if (cb is Map && cb['es_principal'] == true) {
          codigoBarraPrincipal = cb['codigo'] as String?;
          break;
        }
      }
      // Si no hay principal, usar el primero
      if (codigoBarraPrincipal == null && codigosBarra.isNotEmpty) {
        final first = codigosBarra.first;
        if (first is Map) {
          codigoBarraPrincipal = first['codigo'] as String?;
        } else if (first is String) {
          codigoBarraPrincipal = first;
        }
      }
    } else if (codigosBarra is String) {
      // Si el backend devolvió un string directo
      codigoBarraPrincipal = codigosBarra;
    }

    // Extraer precios del array precios por tipo
    final preciosArray = json['precios'] as List?;
    double? precioCompra;
    double? precioVenta;

    if (preciosArray != null && preciosArray.isNotEmpty) {
      try {
        // Buscar precio de COSTO
        final precioCosto = preciosArray.firstWhere(
          (p) => p is Map && p['tipo_precio'] is Map && p['tipo_precio']['codigo'] == 'COSTO',
          orElse: () => null,
        );
        if (precioCosto != null) {
          precioCompra = double.tryParse(precioCosto['precio'].toString());
        }

        // Buscar precio de VENTA
        final precioVentaMap = preciosArray.firstWhere(
          (p) => p is Map && p['tipo_precio'] is Map && p['tipo_precio']['codigo'] == 'VENTA',
          orElse: () => null,
        );
        if (precioVentaMap != null) {
          precioVenta = double.tryParse(precioVentaMap['precio'].toString());
        }
      } catch (e) {
        // print('⚠️ [Producto] Error extrayendo precios: $e');
      }
    }

    // Fallback a campos directos si existen
    precioCompra ??= json['precio_compra'] != null ? double.parse(json['precio_compra'].toString()) : null;
    precioVenta ??= json['precio_venta'] != null ? double.parse(json['precio_venta'].toString()) : null;

    // Extraer nombre de marca desde el objeto marca (si viene en el response)
    String? marcaNombre;
    final marca = json['marca'];
    if (marca is Map<String, dynamic>) {
      marcaNombre = marca['nombre'] as String?;
    }

    return Producto(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      sku: json['sku'],
      descripcion: json['descripcion'],
      peso: json['peso'] != null ? double.parse(json['peso'].toString()) : null,
      unidadMedidaId: json['unidad_medida_id'],
      categoriaId: json['categoria_id'],
      marcaId: json['marca_id'],
      marcaNombre: marcaNombre,
      proveedorId: json['proveedor_id'],
      stockMinimo: json['stock_minimo'] ?? 0,
      stockMaximo: json['stock_maximo'] ?? 0,
      activo: json['activo'] ?? true,
      esProductoComida: json['es_producto_comida'] ?? false,
      permitirVentaSinStock: json['permite_venta_sin_stock'] ?? false,
      esProductoAdicional: json['es_producto_adicional'] ?? false,
      puedeRecbirProductoAdicional: json['puede_tener_producto_adicional'] ?? false,
      visibleApp: json['visible_app'] ?? true,
      esDeProduccion: json['es_de_produccion'] ?? false,
      limiteventa: json['limite_venta'] != null ? double.parse(json['limite_venta'].toString()) : null,
      precioCompra: precioCompra,
      precioVenta: precioVenta,
      principioActivo: json['principio_activo'],
      usoMedicacion: json['uso_de_medicacion'],
      fechaCreacion: json['fecha_creacion'] != null ? DateTime.parse(json['fecha_creacion']) : null,
      imagenesUrls: imagenesUrls,
      codigosBarra: codigoBarraPrincipal,
      stocks: _extractStocks(json['stock'] ?? json['stocks']),  // Intenta 'stock' o 'stocks'
      stockLimites: _extractStockLimites(json['stockLimites'] ?? json['stock_limites']),  // Intenta camelCase o snake_case
      esFraccionado: json['es_fraccionado'] is bool ? json['es_fraccionado'] as bool : null,
      conversiones: json['conversiones'] is List
          ? (json['conversiones'] as List)
              .whereType<Map>()
              .map((c) => Map<String, dynamic>.from(c))
              .toList()
          : const [],
    );
  }

  static List<Map<String, dynamic>> _extractStocks(dynamic stocksData) {
    // print('📦 [Producto] stocksData: $stocksData (type: ${stocksData.runtimeType})');

    // Si es un número, es el stock total del endpoint de búsqueda
    if (stocksData is num) {
      // print('⚠️ [Producto] stocksData es número ($stocksData), probablemente de búsqueda, retornando vacío');
      return [];
    }

    if (stocksData is! List) {
      // print('⚠️ [Producto] stocksData NO es lista, retornando vacío');
      return [];
    }

    // print('📦 [Producto] Stocks encontrados: ${stocksData.length}');

    return stocksData.map<Map<String, dynamic>>((stock) {
      if (stock is! Map) return {};

      final cantidad = stock['cantidad'];
      final cantidadDisponible = stock['cantidad_disponible'];

      // Convertir cantidad a int de forma segura (maneja doubles como 45.0000)
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

      // print('  📦 Stock: id=${stock['id']}, cantidad=$cantidad → $cantidadInt, almacen=${stock['almacen_id']}, sector=${stock['sector_id']}');

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
  }

  static List<Map<String, dynamic>> _extractStockLimites(dynamic stockLimitesData) {
    if (stockLimitesData is! List) {
      return [];
    }

    return stockLimitesData.map<Map<String, dynamic>>((sl) {
      if (sl is! Map) return {};

      return {
        'id': sl['id'],
        'producto_id': sl['producto_id'],
        'almacen_id': sl['almacen_id'],
        'sector_id': sl['sector_id'],
        'stock_minimo': sl['stock_minimo'],
        'stock_maximo': sl['stock_maximo'],
        'almacen_nombre': sl['almacen'] != null ? sl['almacen']['nombre'] as String : 'Almacén ${sl['almacen_id']}',
        'sector_nombre': sl['sector'] != null ? sl['sector']['nombre'] as String : 'Sector ${sl['sector_id']}',
      };
    }).toList();
  }

  Map<String, dynamic> toJson() {
    // 🔥 HELPER: Convertir IDs inválidos (0 o null) a null para permitir eliminación
    final sanitizeId = (int? id) => (id == null || id == 0) ? null : id;

    final json = {
      'nombre': nombre,
      'sku': sku,
      'descripcion': descripcion,
      'peso': peso,
      'unidad_medida_id': sanitizeId(unidadMedidaId),
      'categoria_id': sanitizeId(categoriaId),      // 🔥 FIX: Permitir null
      'marca_id': sanitizeId(marcaId),              // 🔥 FIX: Permitir null
      'proveedor_id': sanitizeId(proveedorId),      // 🔥 FIX: Permitir null
      'stock_minimo': stockMinimo,
      'stock_maximo': stockMaximo,
      'activo': activo ? 1 : 0,
      'es_producto_comida': esProductoComida ? 1 : 0,
      'permite_venta_sin_stock': permitirVentaSinStock ? 1 : 0,
      'es_producto_adicional': esProductoAdicional ? 1 : 0,
      'puede_tener_producto_adicional': puedeRecbirProductoAdicional ? 1 : 0,
      'visible_app': visibleApp ? 1 : 0,
      'es_de_produccion': esDeProduccion ? 1 : 0,
      'limite_venta': limiteventa,
      'precio_compra': precioCompra,
      'precio_venta': precioVenta,
      'principio_activo': principioActivo,
      'uso_de_medicacion': usoMedicacion,
      // null = no tocar los códigos; '' = eliminarlos (el backend borra con lista vacía)
      if (codigosBarra != null)
        'codigos': codigosBarra!.trim().isEmpty ? [] : [codigosBarra!.trim()],
      // Enviar stocks/almacenes con lote, fecha_vencimiento y límites
      'almacenes': stocks.isNotEmpty
          ? stocks.map((stock) => {
              if (stock['id'] != null) 'id': stock['id'],
              'almacen_id': stock['almacen_id'],
              'sector_id': stock['sector_id'],
              'stock': stock['cantidad'],
              'cantidad_disponible': stock['cantidad_disponible'],
              'lote': stock['lote'],
              'fecha_vencimiento': stock['fecha_vencimiento'],
              if (stock['stock_minimo'] != null) 'stock_minimo': stock['stock_minimo'],
              if (stock['stock_maximo'] != null) 'stock_maximo': stock['stock_maximo'],
            }).toList()
          : [],
      // Solo si se informó: si no, el backend deja las conversiones como están
      if (esFraccionado != null) ...{
        'es_fraccionado': esFraccionado,
        'conversiones': esFraccionado!
            ? conversiones.map((c) => {
                'unidad_base_id': c['unidad_base_id'],
                'unidad_destino_id': c['unidad_destino_id'],
                'producto_destino_id': c['producto_destino_id'],
                'factor_conversion': c['factor_conversion'],
                'nombre_cuando_se_vende_como': c['nombre_cuando_se_vende_como'],
                'activo': c['activo'] ?? true,
                'es_conversion_principal': c['es_conversion_principal'] ?? false,
              }).toList()
            : [],
      },
    };

    return json;
  }
}
