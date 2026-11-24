/// Validación de códigos de barra GS1: EAN-8, UPC-A (12), EAN-13 y GTIN-14.
/// Es solo un aviso: el backend acepta cualquier texto, así que nunca bloquea.
enum NivelCodigo { ok, aviso, info }

class ResultadoCodigo {
  final NivelCodigo nivel;
  final String mensaje;

  const ResultadoCodigo(this.nivel, this.mensaje);
}

ResultadoCodigo evaluarCodigoBarra(String codigo) {
  final c = codigo.trim();
  if (!RegExp(r'^\d+$').hasMatch(c)) {
    return const ResultadoCodigo(
      NivelCodigo.info,
      'Código no numérico: se guardará tal cual',
    );
  }

  const formatos = {8: 'EAN-8', 12: 'UPC-A', 13: 'EAN-13', 14: 'GTIN-14'};
  final formato = formatos[c.length];
  if (formato == null) {
    return const ResultadoCodigo(
      NivelCodigo.aviso,
      'Longitud no estándar: se esperan 8, 12, 13 o 14 dígitos',
    );
  }

  final esperado = digitoVerificador(c.substring(0, c.length - 1));
  if (esperado != int.parse(c[c.length - 1])) {
    return const ResultadoCodigo(
      NivelCodigo.aviso,
      'El dígito verificador no coincide: revisa el código',
    );
  }
  return ResultadoCodigo(NivelCodigo.ok, '$formato válido');
}

/// Dígito verificador GS1 (pesos 3 y 1 desde la derecha). [base] no incluye el último dígito.
int digitoVerificador(String base) {
  var suma = 0;
  for (var i = 0; i < base.length; i++) {
    final digito = int.parse(base[base.length - 1 - i]);
    suma += i.isEven ? digito * 3 : digito;
  }
  return (10 - suma % 10) % 10;
}
