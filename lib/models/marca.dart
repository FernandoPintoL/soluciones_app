class Marca {
  final int id;
  final String nombre;
  final bool activo;

  Marca({
    required this.id,
    required this.nombre,
    this.activo = true,
  });

  factory Marca.fromJson(Map<String, dynamic> json) {
    return Marca(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'activo': activo,
    };
  }

  Marca copyWith({
    int? id,
    String? nombre,
    bool? activo,
  }) {
    return Marca(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      activo: activo ?? this.activo,
    );
  }
}
