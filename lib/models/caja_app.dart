double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class CajaOpcion {
  final int id;
  final String nombre;

  CajaOpcion({required this.id, required this.nombre});

  factory CajaOpcion.fromJson(Map<String, dynamic> json) {
    return CajaOpcion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nombre: (json['nombre'] ?? 'Caja').toString(),
    );
  }
}

/// Apertura de caja abierta con el resumen igual que la web (CajaController::index).
class AperturaCaja {
  final int id;
  final int cajaId;
  final String cajaNombre;
  final DateTime? fechaApertura;
  final double montoApertura;
  final double ventasTotal;
  final double ventasEfectivo;
  final double ventasQr;
  final double ventasCredito;
  final double ingresos;
  final double egresos;
  final double vueltos;
  final double gastos;
  final double pagosCreditos;
  final double efectivoEnCaja;
  final double efectivoEntradas;
  final double efectivoSalidas;
  final double transferenciasQr;
  final double efectivoEsperado;

  AperturaCaja({
    required this.id,
    required this.cajaId,
    required this.cajaNombre,
    required this.fechaApertura,
    required this.montoApertura,
    required this.ventasTotal,
    required this.ventasEfectivo,
    required this.ventasQr,
    required this.ventasCredito,
    required this.ingresos,
    required this.egresos,
    required this.vueltos,
    required this.gastos,
    required this.pagosCreditos,
    required this.efectivoEnCaja,
    required this.efectivoEntradas,
    required this.efectivoSalidas,
    required this.transferenciasQr,
    required this.efectivoEsperado,
  });

  factory AperturaCaja.fromJson(Map<String, dynamic> json) {
    return AperturaCaja(
      id: (json['id'] as num?)?.toInt() ?? 0,
      cajaId: (json['caja_id'] as num?)?.toInt() ?? 0,
      cajaNombre: (json['caja_nombre'] ?? 'Caja').toString(),
      fechaApertura: DateTime.tryParse(
        (json['fecha_apertura'] ?? '').toString(),
      ),
      montoApertura: _d(json['monto_apertura']),
      ventasTotal: _d(json['ventas_total']),
      ventasEfectivo: _d(json['ventas_efectivo']),
      ventasQr: _d(json['ventas_qr']),
      ventasCredito: _d(json['ventas_credito']),
      ingresos: _d(json['ingresos']),
      egresos: _d(json['egresos']),
      vueltos: _d(json['vueltos']),
      gastos: _d(json['gastos']),
      pagosCreditos: _d(json['pagos_creditos']),
      efectivoEnCaja: _d(json['efectivo_en_caja']),
      efectivoEntradas: _d(json['efectivo_entradas']),
      efectivoSalidas: _d(json['efectivo_salidas']),
      transferenciasQr: _d(json['transferencias_qr']),
      efectivoEsperado: _d(json['efectivo_esperado']),
    );
  }
}

class EstadoCaja {
  final bool abierta;
  final AperturaCaja? apertura;
  final List<CajaOpcion> cajas;

  EstadoCaja({
    required this.abierta,
    required this.apertura,
    required this.cajas,
  });

  factory EstadoCaja.fromJson(Map<String, dynamic> json) {
    final apertura = json['apertura'];
    return EstadoCaja(
      abierta: json['abierta'] == true,
      apertura: apertura is Map
          ? AperturaCaja.fromJson(Map<String, dynamic>.from(apertura))
          : null,
      cajas: (json['cajas'] as List? ?? [])
          .whereType<Map>()
          .map((c) => CajaOpcion.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }
}

class ResultadoCierre {
  final int cierreId;
  final double montoEsperado;
  final double montoReal;
  final double diferencia;

  ResultadoCierre({
    required this.cierreId,
    required this.montoEsperado,
    required this.montoReal,
    required this.diferencia,
  });

  factory ResultadoCierre.fromJson(Map<String, dynamic> json) {
    return ResultadoCierre(
      cierreId: (json['cierre_id'] as num?)?.toInt() ?? 0,
      montoEsperado: _d(json['monto_esperado']),
      montoReal: _d(json['monto_real']),
      diferencia: _d(json['diferencia']),
    );
  }
}
