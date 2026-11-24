import 'package:flutter/material.dart';

import '../config/colores_app.dart';
import '../config/modulos.dart';
import '../models/inicio_resumen.dart';
import '../services/api_errors.dart';
import '../services/inicio_service.dart';
import '../widgets/app_drawer.dart';
import 'caja_screen.dart';
import 'productos_list_screen.dart';
import 'ventas_listado_screen.dart';

/// Inicio: resumen del día y accesos a todas las pantallas.
/// Estilo plano: bloques de color sólido, sin sombras, esquinas redondeadas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Paleta plana
const _azul = AppColores.azul;
const _verde = AppColores.verde;
const _morado = AppColores.morado;
const _teal = AppColores.teal;
const _gris = AppColores.gris;

class _HomeScreenState extends State<HomeScreen> {
  ResumenInicio? _resumen;
  bool _cargando = true;
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
      final r = await inicioService.getResumen();
      if (!mounted) return;
      setState(() => _resumen = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _ir(Widget pantalla) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    ).then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'inicio'),
      body: RefreshIndicator(onRefresh: _cargar, child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    final r = _resumen;
    if (r == null) {
      if (_cargando) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error ?? 'Sin datos')),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _encabezado(),
        const SizedBox(height: 16),
        _tarjetaCaja(r.caja),
        const SizedBox(height: 12),
        _indicadores(r.hoy),
        const SizedBox(height: 12),
        _grafico(r.ultimosDias),
        const SizedBox(height: 12),
        _cobradoHoy(r.pagosHoy),
        const SizedBox(height: 12),
        _cajaHoy(r.caja),
        const SizedBox(height: 12),
        _masVendidos(r.topProductos),
        const SizedBox(height: 12),
        _stockBajo(r.stockBajo),
        const SizedBox(height: 20),
        Text(
          'Accesos rápidos',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _accesos(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _encabezado() {
    final ahora = DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    final fecha = '${dos(ahora.day)}/${dos(ahora.month)}/${ahora.year}';
    return Text(
      'Hoy · $fecha',
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColores.estado(context).gris),
    );
  }

  Widget _tarjetaCaja(CajaResumen c) {
    final color = c.abierta ? _verde : _gris;
    return _bloque(
      color: color,
      onTap: () => _ir(const CajaScreen()),
      child: Row(
        children: [
          Icon(
            c.abierta ? Icons.lock_open : Icons.lock_outline,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: c.abierta
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.cajaNombre ?? 'Caja abierta',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Efectivo en caja: Bs ${c.efectivoEnCaja.toStringAsFixed(2)} · '
                        'QR: Bs ${c.transferenciasQr.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'No tienes caja abierta',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }

  Widget _indicadores(VentasHoy h) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _kpi('Ventas', '${h.cantidad}', _azul, Icons.receipt_long),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kpi(
                'Total',
                'Bs ${h.total.toStringAsFixed(2)}',
                _verde,
                Icons.payments,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _kpi(
                'Contado',
                'Bs ${h.contado.toStringAsFixed(2)}',
                _teal,
                Icons.point_of_sale,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kpi(
                'Crédito',
                'Bs ${h.credito.toStringAsFixed(2)}',
                _morado,
                Icons.credit_score,
              ),
            ),
          ],
        ),
        if (h.anuladas > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${h.anuladas} venta(s) anulada(s) hoy',
            style: TextStyle(
              color: AppColores.estado(context).rojo,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _kpi(String titulo, String valor, Color color, IconData icono) {
    return _bloque(
      color: color,
      onTap: () => _ir(const VentasListadoScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bloque plano con título, sin sombra.
  Widget _seccion(String titulo, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// Cobrado hoy por medio de pago: barra apilada plana y leyenda.
  Widget _cobradoHoy(PagosHoy p) {
    final total = p.total;
    return _seccion(
      'Cobrado hoy',
      total <= 0
          ? Text(
              'Sin cobros hoy',
              style: TextStyle(color: AppColores.estado(context).gris),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        if (p.efectivo > 0)
                          Expanded(
                            flex: (p.efectivo * 100 / total).round().clamp(
                              1,
                              100,
                            ),
                            child: const ColoredBox(color: _verde),
                          ),
                        if (p.qr > 0)
                          Expanded(
                            flex: (p.qr * 100 / total).round().clamp(1, 100),
                            child: const ColoredBox(color: _azul),
                          ),
                        if (p.otros > 0)
                          Expanded(
                            flex: (p.otros * 100 / total).round().clamp(1, 100),
                            child: const ColoredBox(color: _gris),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _leyenda('Efectivo', p.efectivo, _verde),
                _leyenda('QR / transferencia', p.qr, _azul),
                if (p.otros > 0) _leyenda('Otros', p.otros, _gris),
              ],
            ),
    );
  }

  Widget _leyenda(String etiqueta, double valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(etiqueta)),
          Text(
            'Bs ${valor.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Entradas y salidas de la caja abierta.
  Widget _cajaHoy(CajaResumen c) {
    return _seccion(
      'Movimientos de caja hoy',
      !c.abierta
          ? Text(
              'Abre tu caja para ver los movimientos',
              style: TextStyle(color: AppColores.estado(context).gris),
            )
          : Row(
              children: [
                Expanded(
                  child: _mini(
                    'Entradas',
                    c.entradas,
                    AppColores.estado(context).verde,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _mini(
                    'Salidas',
                    c.salidas,
                    AppColores.estado(context).rojo,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _mini(String etiqueta, double valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bs ${valor.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Productos más vendidos de los últimos 7 días.
  Widget _masVendidos(List<TopProducto> items) {
    return _seccion(
      'Más vendidos (7 días)',
      items.isEmpty
          ? Text(
              'Sin ventas en la semana',
              style: TextStyle(color: AppColores.estado(context).gris),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColores.estado(context).azul
                              .withValues(alpha: 0.12),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: AppColores.estado(context).azul,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            items[i].nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${items[i].cantidad.toStringAsFixed(0)} u · Bs ${items[i].total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColores.estado(context).gris,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  /// Productos con stock por debajo del mínimo. Al tocar, abre Productos.
  Widget _stockBajo(StockBajo s) {
    return _seccion(
      'Stock bajo',
      s.total == 0
          ? Text(
              'Todo el stock está sobre el mínimo',
              style: TextStyle(color: AppColores.estado(context).gris),
            )
          : InkWell(
              onTap: () => _ir(const ProductosListScreen()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.total} producto(s) bajo el mínimo',
                    style: TextStyle(
                      color: AppColores.estado(context).rojo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final p in s.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${p.stockActual.toStringAsFixed(0)} / ${p.stockMinimo.toStringAsFixed(0)} · ${p.almacen}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColores.estado(context).gris,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (s.total > s.items.length)
                    Text(
                      'y ${s.total - s.items.length} más…',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColores.estado(context).gris,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// Barras de los últimos 7 días, sin ejes ni sombras.
  Widget _grafico(List<VentaDia> dias) {
    final maximo = dias.fold<double>(0, (m, d) => d.total > m ? d.total : m);
    const letras = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Últimos 7 días',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in dias)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: maximo <= 0
                                    ? 0.02
                                    : (d.total / maximo).clamp(0.02, 1.0),
                                widthFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: d.total > 0
                                        ? _azul
                                        : _gris.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            letras[DateTime.parse(d.fecha).weekday - 1],
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColores.estado(context).gris,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total de la semana: Bs ${dias.fold<double>(0, (s, d) => s + d.total).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: AppColores.estado(context).gris,
            ),
          ),
        ],
      ),
    );
  }

  /// Accesos rápidos: todos los módulos de operación e inventario, desde config/modulos.dart.
  Widget _accesos() {
    final accesos = [
      for (final m in modulos)
        if (m.id != 'inicio' && m.seccion != SeccionModulo.catalogos) m,
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        for (final a in accesos)
          _bloque(
            color: a.color,
            onTap: () => _ir(a.pantalla()),
            child: Row(
              children: [
                Icon(a.icono, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    a.titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Bloque plano: color sólido, esquinas redondeadas, sin sombra.
  Widget _bloque({
    required Color color,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}
