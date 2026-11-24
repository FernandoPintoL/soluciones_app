double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? 0}') ?? 0;
}

String _texto(dynamic v) => v?.toString() ?? '';

/// "2026-11-23T00:00:00.000000Z" → "23/11/2026".
/// Se toma solo la parte de la fecha del texto, sin convertir la zona horaria
/// (convertir podría mover la venta al día anterior).
/// Fecha y hora de registro: "23/11/2026 15:42" a partir de created_at.
/// Usa la hora tal como la envía el servidor (sin convertir zona horaria).
String formatearFechaHoraVenta(String fecha, String? createdAt) {
  final soloFecha = formatearFechaVenta(fecha);
  final hora = _horaBolivia(createdAt);
  return hora == null ? soloFecha : '$soloFecha $hora';
}

/// Bolivia (America/La_Paz) es UTC-4 todo el año, sin horario de verano.
/// El servidor envía created_at en UTC ("...Z"): se convierte a hora de Bolivia
/// igual que la web, sin depender de la zona horaria del teléfono.
String? _horaBolivia(String? createdAt) {
  if (createdAt == null) return null;
  final dt = DateTime.tryParse(createdAt);
  if (dt == null) return null;
  // Sin zona en el texto: se muestra la hora tal cual
  final bolivia = dt.isUtc ? dt.toUtc().add(const Duration(hours: -4)) : dt;
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(bolivia.hour)}:${dos(bolivia.minute)}';
}

String formatearFechaVenta(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso;
  return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}

/// Venta en el listado (GET /api/app/ventas).
class VentaListado {
  // Momento de registro (created_at): de aquí sale la hora
  final String? createdAt;
  final int id;
  final String numero;
  final String fecha;
  final double total;
  final String estado; // texto del campo estado (ej. "Anulado")
  final String estadoPago; // PAGADO, PARCIAL, PENDIENTE
  final String estadoDocumentoCodigo; // APROBADO, ANULADO
  final String clienteNombre;
  final String? clienteNit;
  final String tipoPagoNombre;

  VentaListado({
    this.createdAt,
    required this.id,
    required this.numero,
    required this.fecha,
    required this.total,
    required this.estado,
    required this.estadoPago,
    required this.estadoDocumentoCodigo,
    required this.clienteNombre,
    required this.clienteNit,
    required this.tipoPagoNombre,
  });

  bool get anulada =>
      estadoDocumentoCodigo.toUpperCase() == 'ANULADO' ||
      estado.toLowerCase() == 'anulado';

  factory VentaListado.fromJson(Map<String, dynamic> json) {
    final cliente = json['cliente'];
    final estadoDoc = json['estado_documento'];
    final tipoPago = json['tipoPago'];
    return VentaListado(
      id: (json['id'] as num?)?.toInt() ?? 0,
      numero: _texto(json['numero']),
      fecha: _texto(json['fecha']),
      createdAt: json['created_at']?.toString(),
      total: _num(json['total']),
      estado: _texto(json['estado']),
      estadoPago: _texto(json['estado_pago']).toUpperCase(),
      estadoDocumentoCodigo: estadoDoc is Map
          ? _texto(estadoDoc['codigo']).toUpperCase()
          : '',
      clienteNombre: cliente is Map ? _texto(cliente['nombre']) : '',
      clienteNit: cliente is Map ? _texto(cliente['nit']) : null,
      tipoPagoNombre: tipoPago is Map ? _texto(tipoPago['nombre']) : '',
    );
  }
}

/// Línea de una venta (detalle).
class VentaLinea {
  final String producto;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  VentaLinea({
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory VentaLinea.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'];
    return VentaLinea(
      producto: producto is Map ? _texto(producto['nombre']) : 'Producto',
      cantidad: _num(json['cantidad']),
      precioUnitario: _num(json['precio_unitario']),
      subtotal: _num(json['subtotal']),
    );
  }
}

/// Detalle completo de una venta (GET /api/app/ventas/{id}).
class VentaDetalle {
  // Momento de registro (created_at): de aquí sale la hora
  final String? createdAt;
  final int id;
  final String numero;
  final String fecha;
  final double subtotal;
  final double descuento;
  final double total;
  final String observaciones;
  final String estadoDocumentoCodigo;
  final String estadoDocumentoNombre;
  final String clienteNombre;
  final String? clienteNit;
  final String? clienteTelefono;
  final String tipoPagoNombre;
  final List<VentaLinea> lineas;

  VentaDetalle({
    this.createdAt,
    required this.id,
    required this.numero,
    required this.fecha,
    required this.subtotal,
    required this.descuento,
    required this.total,
    required this.observaciones,
    required this.estadoDocumentoCodigo,
    required this.estadoDocumentoNombre,
    required this.clienteNombre,
    required this.clienteNit,
    required this.clienteTelefono,
    required this.tipoPagoNombre,
    required this.lineas,
  });

  bool get anulada => estadoDocumentoCodigo.toUpperCase() == 'ANULADO';

  factory VentaDetalle.fromJson(Map<String, dynamic> json) {
    final cliente = json['cliente'];
    final estadoDoc = json['estado_documento'];
    final tipoPago = json['tipoPago'];
    final detalles = json['detalles'];
    return VentaDetalle(
      id: (json['id'] as num?)?.toInt() ?? 0,
      numero: _texto(json['numero']),
      fecha: _texto(json['fecha']),
      createdAt: json['created_at']?.toString(),
      subtotal: _num(json['subtotal']),
      descuento: _num(json['descuento']),
      total: _num(json['total']),
      observaciones: _texto(json['observaciones']),
      estadoDocumentoCodigo: estadoDoc is Map
          ? _texto(estadoDoc['codigo']).toUpperCase()
          : '',
      estadoDocumentoNombre: estadoDoc is Map
          ? _texto(estadoDoc['nombre'])
          : '',
      clienteNombre: cliente is Map ? _texto(cliente['nombre']) : '',
      clienteNit: cliente is Map ? _texto(cliente['nit']) : null,
      clienteTelefono: cliente is Map ? _texto(cliente['telefono']) : null,
      tipoPagoNombre: tipoPago is Map ? _texto(tipoPago['nombre']) : '',
      lineas: detalles is List
          ? detalles
                .whereType<Map>()
                .map((d) => VentaLinea.fromJson(Map<String, dynamic>.from(d)))
                .toList()
          : const [],
    );
  }
}
