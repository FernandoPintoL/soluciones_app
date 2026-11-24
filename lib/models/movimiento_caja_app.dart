/// Tipo de operación de caja (ej. GASTOS, PAGO_SUELDO, VENTA, INGRESO MANUAL).
/// [direccion] indica si el tipo es de ingreso (ENTRADA) o de egreso (SALIDA).
class TipoOperacionCaja {
  final int id;
  final String codigo;
  final String nombre;
  final String direccion;

  TipoOperacionCaja({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.direccion,
  });

  factory TipoOperacionCaja.fromJson(Map<String, dynamic> json) {
    return TipoOperacionCaja(
      id: (json['id'] as num?)?.toInt() ?? 0,
      codigo: (json['codigo'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      direccion: (json['direccion'] ?? '').toString().toUpperCase(),
    );
  }
}
