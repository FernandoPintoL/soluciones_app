import 'package:flutter/material.dart';

import '../config/colores_app.dart';

import '../models/caja_app.dart';
import '../services/api_errors.dart';
import '../services/caja_service.dart';
import '../widgets/app_drawer.dart';

/// Mi caja: resumen igual que la web (Cajas), abrir y cerrar.
/// Las ventas solo se pueden registrar con una caja abierta.
class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  EstadoCaja? _estado;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;

  CajaOpcion? _cajaSeleccionada;
  final _efectivoCtrl = TextEditingController();
  final _transferenciaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _efectivoCtrl.dispose();
    _transferenciaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final estado = await cajaService.estado();
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _cajaSeleccionada ??= estado.cajas.isNotEmpty
            ? estado.cajas.first
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _texto(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ───────────────────────── Abrir ─────────────────────────

  Future<void> _abrir() async {
    final efectivo = _numero(_efectivoCtrl.text) ?? 0;
    final transferencia = _numero(_transferenciaCtrl.text) ?? 0;
    if (efectivo < 0 || transferencia < 0) {
      _mensaje('Los montos no pueden ser negativos', error: true);
      return;
    }
    setState(() => _procesando = true);
    try {
      await cajaService.abrir(
        cajaId: _cajaSeleccionada?.id,
        efectivo: efectivo,
        transferencia: transferencia,
        observaciones: _obsCtrl.text.trim(),
      );
      _efectivoCtrl.clear();
      _transferenciaCtrl.clear();
      _obsCtrl.clear();
      _mensaje('Caja abierta');
      await _cargar();
    } catch (e) {
      _mensaje(_texto(e), error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ───────────────────────── Cerrar ─────────────────────────

  Future<void> _cerrar(AperturaCaja a) async {
    final cierre = await showDialog<({double efectivo, double qr, String obs})>(
      context: context,
      builder: (_) => _DialogoCierre(
        efectivoEsperado: a.efectivoEnCaja,
        qrEsperado: a.transferenciasQr,
        totalEsperado: a.efectivoEsperado,
      ),
    );
    if (cierre == null) return;

    setState(() => _procesando = true);
    try {
      final resultado = await cajaService.cerrar(
        montoReal: cierre.efectivo + cierre.qr,
        observaciones: cierre.obs,
      );
      if (!mounted) return;
      await _mostrarResultadoCierre(resultado);
      await _cargar();
    } catch (e) {
      _mensaje(_texto(e), error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _mostrarResultadoCierre(ResultadoCierre r) {
    final sobra = r.diferencia > 0.009;
    final falta = r.diferencia < -0.009;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          falta ? Icons.warning_amber_rounded : Icons.check_circle,
          color: falta
              ? AppColores.estado(context).naranja
              : AppColores.estado(context).verde,
          size: 48,
        ),
        title: const Text('Caja cerrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filaResumen('Esperado (efectivo + QR)', r.montoEsperado),
            _filaResumen('Contado', r.montoReal),
            const Divider(),
            _filaResumen(
              sobra ? 'Sobrante' : (falta ? 'Faltante' : 'Diferencia'),
              r.diferencia.abs(),
              destacado: true,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi caja'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'caja'),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _estado == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _estado == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final estado = _estado!;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (estado.abierta && estado.apertura != null)
            _vistaAbierta(estado.apertura!)
          else
            _vistaCerrada(estado.cajas),
        ],
      ),
    );
  }

  Widget _vistaAbierta(AperturaCaja a) {
    final colores = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: colores.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lock_open,
                      color: AppColores.estado(context).verde,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.cajaNombre,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Chip(label: Text('ABIERTA')),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  a.fechaApertura != null
                      ? 'Abierta el ${_fecha(a.fechaApertura!)}'
                      : 'Caja abierta',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metrica('Apertura', a.montoApertura, Icons.savings_outlined),
            _metrica(
              'Ventas',
              a.ventasTotal,
              Icons.receipt_long_outlined,
              detalle:
                  'Efectivo ${_bs(a.ventasEfectivo)} · QR ${_bs(a.ventasQr)}'
                  '${a.ventasCredito > 0 ? '\nCrédito ${_bs(a.ventasCredito)}' : ''}',
            ),
            _metrica(
              'Egresos',
              a.egresos,
              Icons.arrow_upward,
              detalle: 'Transferencia - salidas',
            ),
            _metrica(
              'Vueltos / cambio',
              a.vueltos,
              Icons.currency_exchange,
              detalle: 'Salen del efectivo',
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Efectivo a contar: lo que debe haber en el cajón
        Card(
          color: AppColores.estado(context).naranja.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: AppColores.estado(context).naranja,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💵 Efectivo a contar en caja'),
                const SizedBox(height: 4),
                Text(
                  _bs(a.efectivoEnCaja),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColores.estado(context).naranja,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_bs(a.montoApertura)} apertura + ${_bs(a.efectivoEntradas)} '
                  'cobrado en efectivo − ${_bs(a.efectivoSalidas)} salidas en efectivo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tarjetaSimple(
                'Transferencias / QR',
                _bs(a.transferenciasQr),
                Icons.qr_code_2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tarjetaSimple(
                'Total esperado (efectivo + QR)',
                _bs(a.efectivoEsperado),
                Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metrica('Ingresos', a.ingresos, Icons.arrow_downward),
            _metrica('Gastos', a.gastos, Icons.shopping_cart_outlined),
            _metrica(
              'Cobros de créditos',
              a.pagosCreditos,
              Icons.assignment_turned_in_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colores.error,
            foregroundColor: colores.onError,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _procesando ? null : () => _cerrar(a),
          icon: _procesando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.lock_outline),
          label: const Text('Cerrar caja'),
        ),
      ],
    );
  }

  Widget _vistaCerrada(List<CajaOpcion> cajas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 8),
                Text(
                  'No tienes una caja abierta',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Abre tu caja para poder registrar ventas.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (cajas.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No tienes una caja asignada. Contacta con administración.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          if (cajas.length > 1)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Caja'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CajaOpcion>(
                  value: _cajaSeleccionada,
                  isExpanded: true,
                  items: [
                    for (final c in cajas)
                      DropdownMenuItem(value: c, child: Text(c.nombre)),
                  ],
                  onChanged: (c) => setState(() => _cajaSeleccionada = c),
                ),
              ),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.point_of_sale),
              title: Text(cajas.first.nombre),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _efectivoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Efectivo inicial (Bs)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transferenciaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Transferencia / QR inicial (Bs)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obsCtrl,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _procesando ? null : _abrir,
            icon: _procesando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_open),
            label: const Text('Abrir caja'),
          ),
        ],
      ],
    );
  }

  Widget _metrica(
    String titulo,
    double valor,
    IconData icono, {
    String? detalle,
  }) {
    final ancho = (MediaQuery.of(context).size.width - 32 - 12) / 2;
    return SizedBox(
      width: ancho,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icono,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(titulo, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                _bs(valor),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (detalle != null) ...[
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaSimple(String titulo, String valor, IconData icono) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(titulo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _filaResumen(String etiqueta, double valor, {bool destacado = false}) {
    final estilo = TextStyle(
      fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(etiqueta, style: estilo)),
          Text(_bs(valor), style: estilo),
        ],
      ),
    );
  }

  void _mensaje(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  String _texto(Object e) => e is ApiException
      ? e.message
      : e.toString().replaceFirst('Exception: ', '');

  double? _numero(String s) {
    final limpio = s.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    return double.tryParse(limpio);
  }

  String _bs(double v) => 'Bs ${v.toStringAsFixed(2)}';

  String _fecha(DateTime d) {
    final local = d.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)}/${local.year} ${dos(local.hour)}:${dos(local.minute)}';
  }
}

/// Conteo de cierre igual que la web: efectivo contado + transferencias/QR confirmadas.
/// Sus controladores se liberan en su propio State.
class _DialogoCierre extends StatefulWidget {
  final double efectivoEsperado;
  final double qrEsperado;
  final double totalEsperado;

  const _DialogoCierre({
    required this.efectivoEsperado,
    required this.qrEsperado,
    required this.totalEsperado,
  });

  @override
  State<_DialogoCierre> createState() => _DialogoCierreState();
}

class _DialogoCierreState extends State<_DialogoCierre> {
  late final TextEditingController _efectivoCtrl = TextEditingController(
    text: widget.efectivoEsperado.toStringAsFixed(2),
  );
  late final TextEditingController _qrCtrl = TextEditingController(
    text: widget.qrEsperado.toStringAsFixed(2),
  );
  final _obsCtrl = TextEditingController();

  @override
  void dispose() {
    _efectivoCtrl.dispose();
    _qrCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  double _parse(String s) {
    final limpio = s.trim().replaceAll(',', '.');
    return double.tryParse(limpio) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cerrar caja'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total esperado (efectivo + QR): Bs ${widget.totalEsperado.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _efectivoCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Efectivo contado (Bs)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qrCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Transferencias / QR confirmadas (Bs)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _obsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, (
            efectivo: _parse(_efectivoCtrl.text),
            qr: _parse(_qrCtrl.text),
            obs: _obsCtrl.text.trim(),
          )),
          child: const Text('Cerrar caja'),
        ),
      ],
    );
  }
}
