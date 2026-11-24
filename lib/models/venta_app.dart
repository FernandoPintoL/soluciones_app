/// Modelos para la pantalla "Nueva venta" (espejo de web-facil ventas/create.tsx,
/// con el subconjunto del flujo principal: cliente, productos, cobro).

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int? _toIntOrNull(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class ClienteVenta {
  final int id;
  final String nombre;
  final String? nit;
  final String? telefono;
  // Crédito habilitado por la empresa para este cliente (la venta a crédito depende de esto)
  final bool puedeTenerCredito;
  final double limiteCredito;

  ClienteVenta({
    required this.id,
    required this.nombre,
    this.nit,
    this.telefono,
    this.puedeTenerCredito = false,
    this.limiteCredito = 0,
  });

  factory ClienteVenta.fromJson(Map<String, dynamic> json) {
    return ClienteVenta(
      id: _toIntOrNull(json['id']) ?? 0,
      nombre: (json['nombre'] ?? json['razon_social'] ?? '').toString(),
      nit: json['nit']?.toString(),
      telefono: json['telefono']?.toString(),
      puedeTenerCredito:
          json['puede_tener_credito'] == true ||
          json['puede_tener_credito'] == 1,
      limiteCredito: _toDouble(json['limite_credito']),
    );
  }
}

/// Un tipo de precio de venta del producto (ej. VENTA, LICORERIA, MAYORISTA).
class PrecioVenta {
  final int? tipoPrecioId;
  final String nombre;
  final double precio;

  PrecioVenta({
    required this.tipoPrecioId,
    required this.nombre,
    required this.precio,
  });
}

/// Precios de venta del producto: sin los de costo y sin los que van por unidad
/// (caja, paquete…), que todavía no se manejan en la app.
List<PrecioVenta> _preciosDeVenta(Map<String, dynamic> json) {
  final lista = json['precios'];
  if (lista is! List) return const [];
  final unidadBase = _toIntOrNull(json['unidad_medida_id']);
  final precios = <PrecioVenta>[];
  for (final p in lista) {
    if (p is! Map) continue;
    // Precios de la unidad base del producto; los de otra unidad (caja, paquete…) no se manejan aún
    final unidad = _toIntOrNull(p['unidad_medida_id']);
    if (unidadBase != null && unidad != null && unidad != unidadBase) continue;
    final tipo = p['tipo_precio'];
    final codigo = tipo is Map ? (tipo['codigo'] ?? '').toString() : '';
    final nombre = (p['nombre'] ?? (tipo is Map ? tipo['nombre'] : '') ?? '')
        .toString();
    if (codigo == 'COSTO' || nombre.toLowerCase().contains('costo')) continue;
    // Un solo precio por tipo (el primero de la unidad base)
    final tipoId = _toIntOrNull(p['tipo_precio_id']);
    if (precios.any((x) => x.tipoPrecioId == tipoId)) continue;
    precios.add(
      PrecioVenta(
        tipoPrecioId: _toIntOrNull(p['tipo_precio_id']),
        nombre: nombre,
        precio: _toDouble(p['precio']),
      ),
    );
  }
  return precios;
}

class ProductoVenta {
  final int id;
  final String nombre;
  final String? sku;
  final String? imagenUrl;
  final double precioVenta;
  final int? tipoPrecioId;
  final String? tipoPrecioNombre;
  final double stockDisponible;
  final bool permiteVentaSinStock;
  final bool esCombo;
  // Servicio (ej. comisión de transferencias): sin stock, precio escrito en la venta, cantidad 1
  final bool esServicio;
  // Códigos de barras del producto (el principal primero)
  final List<String> codigosBarra;
  // Todos los tipos de precio de venta del producto (para elegir en el carrito)
  final List<PrecioVenta> preciosVenta;

  ProductoVenta({
    required this.id,
    required this.nombre,
    this.sku,
    this.imagenUrl,
    required this.precioVenta,
    this.tipoPrecioId,
    this.tipoPrecioNombre,
    required this.stockDisponible,
    this.permiteVentaSinStock = false,
    this.esCombo = false,
    this.esServicio = false,
    this.codigosBarra = const [],
    this.preciosVenta = const [],
  });

  factory ProductoVenta.fromJson(Map<String, dynamic> json) {
    String? imagen;
    final imagenes = json['imagenes'];
    if (imagenes is List && imagenes.isNotEmpty && imagenes.first is Map) {
      imagen = (imagenes.first as Map)['url']?.toString();
    }

    // Precio de referencia de la app: el de tipo VENTA (no el recomendado por cliente)
    final precio = _precioDeVenta(json);

    return ProductoVenta(
      id: _toIntOrNull(json['id']) ?? 0,
      nombre: (json['nombre'] ?? '').toString(),
      sku: json['sku']?.toString(),
      imagenUrl: imagen,
      precioVenta: precio.precio,
      tipoPrecioId: precio.tipoPrecioId,
      tipoPrecioNombre: precio.tipoPrecioNombre,
      stockDisponible: _toDouble(
        json['stock_disponible'] ?? json['cantidad_disponible'],
      ),
      permiteVentaSinStock: json['permite_venta_sin_stock'] == true,
      esCombo: json['es_combo'] == true,
      esServicio: json['es_servicio'] == true,
      codigosBarra: _codigosDeBarra(json),
      preciosVenta: _preciosDeVenta(json),
    );
  }
}

/// Códigos de barras: `codigos_barras` (lista de textos) o, si no viene, `codigo_barras`.
List<String> _codigosDeBarra(Map<String, dynamic> json) {
  final lista = json['codigos_barras'];
  if (lista is List) {
    return lista
        .map((c) => c?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toList();
  }
  final unico = json['codigo_barras']?.toString() ?? '';
  return unico.isEmpty ? const [] : [unico];
}

/// Busca en `precios` el de tipo VENTA. Si no existe, usa el precio recomendado del backend.
({double precio, int? tipoPrecioId, String? tipoPrecioNombre}) _precioDeVenta(
  Map<String, dynamic> json,
) {
  final precios = json['precios'];
  if (precios is List) {
    for (final p in precios) {
      if (p is! Map) continue;
      final tipo = p['tipo_precio'];
      if (tipo is Map && tipo['codigo'] == 'VENTA') {
        return (
          precio: _toDouble(p['precio']),
          tipoPrecioId: _toIntOrNull(p['tipo_precio_id']),
          tipoPrecioNombre: tipo['nombre']?.toString(),
        );
      }
    }
  }
  return (
    precio: _toDouble(json['precio_venta']),
    tipoPrecioId: _toIntOrNull(json['tipo_precio_id_recomendado']),
    tipoPrecioNombre: json['tipo_precio_nombre_recomendado']?.toString(),
  );
}

class ItemVenta {
  final ProductoVenta producto;
  double cantidad;
  double precioUnitario;
  // Tipo de precio elegido para esta línea (por defecto el de VENTA del producto)
  int? tipoPrecioId;
  String? tipoPrecioNombre;

  ItemVenta({
    required this.producto,
    this.cantidad = 1,
    required this.precioUnitario,
    int? tipoPrecioId,
    String? tipoPrecioNombre,
  }) : tipoPrecioId = tipoPrecioId ?? producto.tipoPrecioId,
       tipoPrecioNombre = tipoPrecioNombre ?? producto.tipoPrecioNombre;

  double get subtotal => cantidad * precioUnitario;

  bool get superaStock =>
      !producto.esServicio &&
      !producto.permiteVentaSinStock &&
      cantidad > producto.stockDisponible;
}

class TipoPagoVenta {
  final int id;
  final String nombre;
  final String codigo;

  TipoPagoVenta({required this.id, required this.nombre, required this.codigo});

  factory TipoPagoVenta.fromJson(Map<String, dynamic> json) {
    return TipoPagoVenta(
      id: _toIntOrNull(json['id']) ?? 0,
      nombre: (json['nombre'] ?? '').toString(),
      codigo: (json['codigo'] ?? '').toString(),
    );
  }
}

class CatalogosVenta {
  final int? usuarioId;
  final int almacenId;
  final int estadoDocumentoId;
  final int? tipoDocumentoId;
  final int monedaId;
  final ClienteVenta? clienteGeneral;

  CatalogosVenta({
    required this.usuarioId,
    required this.almacenId,
    required this.estadoDocumentoId,
    required this.tipoDocumentoId,
    required this.monedaId,
    required this.clienteGeneral,
  });

  factory CatalogosVenta.fromJson(Map<String, dynamic> json) {
    final cg = json['cliente_general'];
    return CatalogosVenta(
      usuarioId: _toIntOrNull(json['usuario_id']),
      almacenId: _toIntOrNull(json['almacen_id']) ?? 1,
      estadoDocumentoId: _toIntOrNull(json['estado_documento_id']) ?? 0,
      tipoDocumentoId: _toIntOrNull(json['tipo_documento_id']),
      monedaId: _toIntOrNull(json['moneda_id']) ?? 1,
      clienteGeneral: cg is Map
          ? ClienteVenta.fromJson(Map<String, dynamic>.from(cg))
          : null,
    );
  }
}
