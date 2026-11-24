double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? 0}') ?? 0;
}

int _i(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? 0}') ?? 0;
}

List<Map<String, dynamic>> _lista(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

/// Ventas aprobadas del día.
class VentasHoy {
  final int cantidad;
  final double total;
  final double contado;
  final double credito;
  final int anuladas;

  VentasHoy({
    required this.cantidad,
    required this.total,
    required this.contado,
    required this.credito,
    required this.anuladas,
  });

  factory VentasHoy.fromJson(Map<String, dynamic> json) => VentasHoy(
    cantidad: _i(json['ventas_count']),
    total: _d(json['ventas_total']),
    contado: _d(json['ventas_contado']),
    credito: _d(json['ventas_credito']),
    anuladas: _i(json['anuladas']),
  );
}

/// Cobrado hoy por medio de pago.
class PagosHoy {
  final double efectivo;
  final double qr;
  final double otros;

  PagosHoy({required this.efectivo, required this.qr, required this.otros});

  double get total => efectivo + qr + otros;

  factory PagosHoy.fromJson(Map<String, dynamic> json) => PagosHoy(
    efectivo: _d(json['efectivo']),
    qr: _d(json['qr']),
    otros: _d(json['otros']),
  );
}

/// Total vendido en un día (para el gráfico de los últimos 7 días).
class VentaDia {
  final String fecha; // yyyy-mm-dd
  final double total;

  VentaDia({required this.fecha, required this.total});

  factory VentaDia.fromJson(Map<String, dynamic> json) => VentaDia(
    fecha: (json['fecha'] ?? '').toString(),
    total: _d(json['total']),
  );
}

/// Producto más vendido de la semana.
class TopProducto {
  final String nombre;
  final double cantidad;
  final double total;

  TopProducto({
    required this.nombre,
    required this.cantidad,
    required this.total,
  });

  factory TopProducto.fromJson(Map<String, dynamic> json) => TopProducto(
    nombre: (json['nombre'] ?? '').toString(),
    cantidad: _d(json['cantidad']),
    total: _d(json['total']),
  );
}

/// Producto con stock por debajo del mínimo.
class StockBajoItem {
  final String nombre;
  final String almacen;
  final double stockActual;
  final double stockMinimo;

  StockBajoItem({
    required this.nombre,
    required this.almacen,
    required this.stockActual,
    required this.stockMinimo,
  });

  factory StockBajoItem.fromJson(Map<String, dynamic> json) => StockBajoItem(
    nombre: (json['nombre'] ?? '').toString(),
    almacen: (json['almacen'] ?? '').toString(),
    stockActual: _d(json['stock_actual']),
    stockMinimo: _d(json['stock_minimo']),
  );
}

class StockBajo {
  final int total;
  final List<StockBajoItem> items;

  StockBajo({required this.total, required this.items});

  factory StockBajo.fromJson(Map<String, dynamic> json) => StockBajo(
    total: _i(json['total']),
    items: _lista(json['items']).map(StockBajoItem.fromJson).toList(),
  );
}

/// Caja abierta del usuario, si la hay.
class CajaResumen {
  final bool abierta;
  final String? cajaNombre;
  final double efectivoEnCaja;
  final double transferenciasQr;
  final double entradas;
  final double salidas;

  CajaResumen({
    required this.abierta,
    required this.cajaNombre,
    required this.efectivoEnCaja,
    required this.transferenciasQr,
    required this.entradas,
    required this.salidas,
  });

  factory CajaResumen.fromJson(Map<String, dynamic> json) => CajaResumen(
    abierta: json['abierta'] == true,
    cajaNombre: json['caja_nombre']?.toString(),
    efectivoEnCaja: _d(json['efectivo_en_caja']),
    transferenciasQr: _d(json['transferencias_qr']),
    entradas: _d(json['entradas']),
    salidas: _d(json['salidas']),
  );
}

/// Resumen de la pantalla de inicio (GET /api/app/inicio).
class ResumenInicio {
  final VentasHoy hoy;
  final PagosHoy pagosHoy;
  final List<VentaDia> ultimosDias;
  final List<TopProducto> topProductos;
  final StockBajo stockBajo;
  final CajaResumen caja;

  ResumenInicio({
    required this.hoy,
    required this.pagosHoy,
    required this.ultimosDias,
    required this.topProductos,
    required this.stockBajo,
    required this.caja,
  });

  factory ResumenInicio.fromJson(Map<String, dynamic> json) {
    return ResumenInicio(
      hoy: VentasHoy.fromJson(Map<String, dynamic>.from(json['hoy'] as Map)),
      pagosHoy: PagosHoy.fromJson(
        Map<String, dynamic>.from(json['pagos_hoy'] as Map),
      ),
      ultimosDias: _lista(json['ultimos_dias']).map(VentaDia.fromJson).toList(),
      topProductos: _lista(json['top_productos'])
          .map(TopProducto.fromJson)
          .toList(),
      stockBajo: StockBajo.fromJson(
        Map<String, dynamic>.from(json['stock_bajo'] as Map),
      ),
      caja: CajaResumen.fromJson(
        Map<String, dynamic>.from(json['caja'] as Map),
      ),
    );
  }
}
