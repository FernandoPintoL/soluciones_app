class Categoria {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final DateTime? fechaCreacion;

  Categoria({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.activo = true,
    this.fechaCreacion,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      activo: json['activo'] ?? true,
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo ? 1 : 0,
    };
  }
}
