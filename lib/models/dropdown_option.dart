class DropdownOption {
  final int id;
  final String nombre;
  final String? codigo;

  DropdownOption({
    required this.id,
    required this.nombre,
    this.codigo,
  });

  factory DropdownOption.fromJson(Map<String, dynamic> json) {
    return DropdownOption(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'],
    );
  }

  @override
  String toString() => nombre;
}
