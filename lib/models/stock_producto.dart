class StockProducto {
  final int almacenId;
  final int sectorId;
  final int cantidad;
  final String? almacenNombre;
  final String? sectorNombre;

  StockProducto({
    required this.almacenId,
    required this.sectorId,
    required this.cantidad,
    this.almacenNombre,
    this.sectorNombre,
  });

  Map<String, dynamic> toJson() {
    return {
      'almacen_id': almacenId,
      'sector_id': sectorId,
      'cantidad': cantidad,
    };
  }

  factory StockProducto.fromJson(Map<String, dynamic> json) {
    return StockProducto(
      almacenId: json['almacen_id'] ?? 0,
      sectorId: json['sector_id'] ?? 0,
      cantidad: json['cantidad'] ?? 0,
      almacenNombre: json['almacen_nombre'],
      sectorNombre: json['sector_nombre'],
    );
  }
}
