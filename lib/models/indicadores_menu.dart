double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? 0}') ?? 0;
}

int _i(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? 0}') ?? 0;
}

/// Datos que muestra el menú lateral (GET /api/app/indicadores).
class IndicadoresMenu {
  final bool cajaAbierta;
  final String? cajaNombre;
  final double efectivoEnCaja;
  final int stockBajo;

  IndicadoresMenu({
    required this.cajaAbierta,
    required this.cajaNombre,
    required this.efectivoEnCaja,
    required this.stockBajo,
  });

  factory IndicadoresMenu.fromJson(Map<String, dynamic> json) {
    final caja = json['caja'] is Map
        ? Map<String, dynamic>.from(json['caja'] as Map)
        : <String, dynamic>{};
    return IndicadoresMenu(
      cajaAbierta: caja['abierta'] == true,
      cajaNombre: caja['caja_nombre']?.toString(),
      efectivoEnCaja: _d(caja['efectivo_en_caja']),
      stockBajo: _i(json['stock_bajo']),
    );
  }
}
