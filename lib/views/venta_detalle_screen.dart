import 'package:flutter/material.dart';

import '../models/venta_listado.dart';
import '../services/api_errors.dart';
import '../services/ventas_service.dart';

/// Detalle de una venta: cliente, totales, líneas y anulación.
class VentaDetalleScreen extends StatefulWidget {
  final int ventaId;

  const VentaDetalleScreen({super.key, required this.ventaId});

  @override
  State<VentaDetalleScreen> createState() => _VentaDetalleScreenState();
}

class _VentaDetalleScreenState extends State<VentaDetalleScreen> {
  VentaDetalle? _venta;
  bool _cargando = true;
  bool _anulando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final v = await ventasService.getVenta(widget.ventaId);
      if (!mounted) return;
      setState(() => _venta = v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _texto(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _anular() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoAnular(),
    );
    if (motivo == null) return;

    setState(() => _anulando = true);
    try {
      await ventasService.anularVenta(widget.ventaId, motivo);
      _mensaje(
        'Venta anulada. Se restauró el stock y se anularon los movimientos.',
      );
      await _cargar();
    } catch (e) {
      _mensaje(_texto(e), error: true);
    } finally {
      if (mounted) setState(() => _anulando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venta = _venta;
    return Scaffold(
      appBar: AppBar(
        title: Text(venta == null ? 'Venta' : 'Venta ${venta.numero}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      body: _cargando && venta == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && venta == null
          ? _estadoError()
          : venta == null
          ? const SizedBox.shrink()
          : _contenido(venta),
      bottomNavigationBar: venta == null || venta.anulada
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _anulando ? null : _anular,
                  icon: _anulando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.block),
                  label: const Text('Anular venta'),
                ),
              ),
            ),
    );
  }

  Widget _estadoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  Widget _contenido(VentaDetalle v) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (v.anulada)
          Card(
            color: theme.colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Venta anulada'),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.clienteNombre.isEmpty ? 'Sin cliente' : v.clienteNombre,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (v.clienteNit != null && v.clienteNit!.isNotEmpty)
                  Text('NIT: ${v.clienteNit}'),
                if (v.clienteTelefono != null && v.clienteTelefono!.isNotEmpty)
                  Text('Tel: ${v.clienteTelefono}'),
                const SizedBox(height: 8),
                Text('Fecha: ${formatearFechaHoraVenta(v.fecha, v.createdAt)}'),
                Text(
                  'Pago: ${v.tipoPagoNombre.isEmpty ? '—' : v.tipoPagoNombre}',
                ),
                Text(
                  'Estado: ${v.estadoDocumentoNombre.isEmpty ? v.estadoDocumentoCodigo : v.estadoDocumentoNombre}',
                ),
                if (v.observaciones.isNotEmpty)
                  Text('Obs.: ${v.observaciones}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Productos',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        for (final l in v.lineas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.producto),
            subtitle: Text(
              '${l.cantidad.toStringAsFixed(0)} × Bs ${l.precioUnitario.toStringAsFixed(2)}',
            ),
            trailing: Text(
              'Bs ${l.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        const Divider(),
        _fila('Subtotal', v.subtotal),
        if (v.descuento > 0) _fila('Descuento', -v.descuento),
        _fila('Total', v.total, destacado: true),
      ],
    );
  }

  Widget _fila(String etiqueta, double valor, {bool destacado = false}) {
    final estilo = TextStyle(
      fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
      fontSize: destacado ? 18 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo),
          Text('Bs ${valor.toStringAsFixed(2)}', style: estilo),
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
}

/// Pide el motivo de anulación. El controlador vive en su propio State.
class _DialogoAnular extends StatefulWidget {
  const _DialogoAnular();

  @override
  State<_DialogoAnular> createState() => _DialogoAnularState();
}

class _DialogoAnularState extends State<_DialogoAnular> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final motivo = _ctrl.text.trim();
    Navigator.pop(context, motivo.isEmpty ? 'Anulada desde la app' : motivo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anular venta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se restaurará el stock y se anularán los movimientos de caja.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmar(),
            decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
          ),
        ],
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
          onPressed: _confirmar,
          child: const Text('Anular'),
        ),
      ],
    );
  }
}
