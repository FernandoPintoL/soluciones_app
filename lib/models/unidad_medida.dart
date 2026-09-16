class UnidadMedida {
  final int id;
  final String nombre;
  final String codigo;
  final bool activo;

  UnidadMedida({
    required this.id,
    required this.nombre,
    required this.codigo,
    this.activo = true,
  });

  factory UnidadMedida.fromJson(Map<String, dynamic> json) {
    return UnidadMedida(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      codigo: json['codigo'] as String,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'codigo': codigo,
      'activo': activo,
    };
  }

  UnidadMedida copyWith({
    int? id,
    String? nombre,
    String? codigo,
    bool? activo,
  }) {
    return UnidadMedida(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      activo: activo ?? this.activo,
    );
  }
}
