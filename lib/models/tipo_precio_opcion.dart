/// Tipo de precio de la empresa (tabla tipos_precio) para el formulario de productos.
class TipoPrecioOpcion {
  final int id;
  final String codigo;
  final String nombre;

  /// true = costo de compra: los demás precios se calculan sobre este monto.
  final bool esPrecioBase;

  /// Ganancia sugerida sobre el costo (ej. 30 = +30%). 0 = sin sugerencia.
  final double porcentajeGanancia;

  const TipoPrecioOpcion({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.esPrecioBase,
    required this.porcentajeGanancia,
  });

  factory TipoPrecioOpcion.fromJson(Map<String, dynamic> json) {
    return TipoPrecioOpcion(
      id: json['id'] as int,
      codigo: (json['codigo'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      esPrecioBase: json['es_precio_base'] == true,
      porcentajeGanancia:
          double.tryParse('${json['porcentaje_ganancia'] ?? 0}') ?? 0,
    );
  }
}
