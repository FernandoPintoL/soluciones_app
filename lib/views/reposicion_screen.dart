import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../widgets/app_drawer.dart';
import '../widgets/colores_almacen.dart';
import '../widgets/inventario/abrir_edicion_producto.dart';
import '../widgets/inventario/transferir_sheet.dart';

/// Reposición de SALA DE VENTAS desde ALMACÉN PRINCIPAL y compras sugeridas,
/// calculadas en el backend a partir de stock_limites (mínimo/máximo por
/// almacén) y stock_productos (stock actual). Solo consulta.
class ReposicionScreen extends StatefulWidget {
  const ReposicionScreen({super.key});

  @override
  State<ReposicionScreen> createState() => _ReposicionScreenState();
}

class _GrupoReposicion {
  final String clave;
  final String titulo;
  final IconData icono;
  final String verbo; // etiqueta de la cantidad sugerida
  final String vacio;

  const _GrupoReposicion(
    this.clave,
    this.titulo,
    this.icono,
    this.verbo,
    this.vacio,
  );
}

const _grupos = [
  _GrupoReposicion(
    'reponer',
    'Reponer',
    Icons.swap_horiz,
    'traspasar',
    'Sala de ventas está abastecida: nada que traer del almacén.',
  ),
  _GrupoReposicion(
    'comprar_almacen',
    'Comprar',
    Icons.shopping_cart,
    'comprar',
    'El almacén principal está sobre sus mínimos.',
  ),
  _GrupoReposicion(
    'compra_directa_sala',
    'Directo a sala',
    Icons.storefront,
    'comprar',
    'Ningún producto de compra directa (sin límite en almacén principal) está bajo su mínimo.',
  ),
];

class _ReposicionScreenState extends State<ReposicionScreen> {
  Map<String, dynamic>? _datos;
  String? _error;
  bool _cargando = true;
  String _busqueda = '';

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
      final datos = await apiService.getReposicionSugerida();
      if (mounted) setState(() => _datos = datos);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar(Map<String, dynamic> item) async {
    await abrirEdicionProducto(context, item['producto_id'] as int);
    if (mounted) _cargar(); // límites o stock pudieron cambiar
  }

  /// Abre la transferencia ALMACÉN PRINCIPAL → SALA con la cantidad sugerida.
  Future<void> _traspasar(Map<String, dynamic> item) async {
    final principalId = _datos?['almacen_principal']?['id'] as int?;
    final salaId = _datos?['almacen_sala']?['id'] as int?;
    if (principalId == null || salaId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await apiService.getProductosStock(
        ids: [item['producto_id'] as int],
        limite: 1,
      );
      final filas = r['filas'] ?? [];
      if (!mounted) return;
      if (!filas.any((f) => f['almacen_id'] == principalId)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'El producto ya no tiene stock en el almacén principal',
            ),
          ),
        );
        return;
      }
      final mensaje = await TransferirSheet.mostrar(
        context,
        filasProducto: filas,
        almacenOrigenId: principalId,
        almacenes: r['almacenes'] ?? [],
        destinoInicialId: salaId,
        cantidadInicial: num.tryParse('${item['cantidad_sugerida']}'),
      );
      if (mensaje == null || !mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('✅ $mensaje')));
      _cargar();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  List<Map<String, dynamic>> _items(String grupo) {
    final lista = (_datos?[grupo] as List?) ?? const [];
    final q = _busqueda.trim().toLowerCase();
    return [
      for (final i in lista.whereType<Map>())
        if (q.isEmpty ||
            '${i['nombre']} ${i['sku'] ?? ''}'.toLowerCase().contains(q))
          Map<String, dynamic>.from(i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _grupos.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reposición y compras'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recalcular',
              onPressed: _cargando ? null : _cargar,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final g in _grupos)
                Tab(
                  icon: Icon(g.icono),
                  text: _datos == null
                      ? g.titulo
                      : '${g.titulo} (${_items(g.clave).length})',
                ),
            ],
          ),
        ),
        drawer: const AppDrawer(currentRoute: 'reposicion'),
        body: SafeArea(top: false, child: _buildCuerpo()),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_cargando && _datos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _datos == null) {
      return _Mensaje(
        icono: Icons.error_outline,
        texto: _error!,
        accion: FilledButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (_datos?['almacen_sala'] == null &&
        _datos?['almacen_principal'] == null) {
      return const _Mensaje(
        icono: Icons.warehouse_outlined,
        texto:
            'No se encontraron los almacenes. Deben llamarse "…Principal…" y '
            '"Sala…" o "…Venta…".',
      );
    }

    return Column(
      children: [
        if (_cargando) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o SKU',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [for (final g in _grupos) _buildLista(g)],
          ),
        ),
      ],
    );
  }

  Widget _buildLista(_GrupoReposicion grupo) {
    final items = _items(grupo.clave);
    return RefreshIndicator(
      onRefresh: _cargar,
      child: items.isEmpty
          ? ListView(
              // ListView para que el pull-to-refresh funcione aun vacío
              children: [
                const SizedBox(height: 80),
                _Mensaje(
                  icono: Icons.check_circle_outline,
                  texto: _busqueda.isEmpty
                      ? grupo.vacio
                      : 'Sin coincidencias para "$_busqueda".',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: items.length,
              itemBuilder: (context, i) => _ItemReposicion(
                item: items[i],
                grupo: grupo,
                nombreSala: _datos?['almacen_sala']?['nombre'] ?? 'Sala',
                nombrePrincipal:
                    _datos?['almacen_principal']?['nombre'] ?? 'Principal',
                onTraspasar: grupo.clave == 'reponer'
                    ? () => _traspasar(items[i])
                    : null,
                onEditar: () => _editar(items[i]),
              ),
            ),
    );
  }
}

String _num(dynamic v) {
  final n = num.tryParse('$v') ?? 0;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}

/// "2 (mín 2 · máx 20)" o "2 (mín 2 · sin máx)".
String _stockConLimites(dynamic stock, Map? limites) {
  if (limites == null) return _num(stock);
  final max = limites['maximo'];
  return '${_num(stock)}  (mín ${_num(limites['minimo'])} · '
      '${max == null ? 'sin máx' : 'máx ${_num(max)}'})';
}

class _ItemReposicion extends StatelessWidget {
  final Map<String, dynamic> item;
  final _GrupoReposicion grupo;
  final String nombreSala;
  final String nombrePrincipal;
  final VoidCallback? onTraspasar;
  final VoidCallback onEditar;

  const _ItemReposicion({
    required this.item,
    required this.grupo,
    required this.nombreSala,
    required this.nombrePrincipal,
    this.onTraspasar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unidad = item['unidad'] ?? '';
    final sala = item['sala'] as Map?;
    final principal = item['principal'] as Map?;
    final paraSala = num.tryParse('${item['cantidad_para_sala'] ?? 0}') ?? 0;
    final sinMaximo =
        (grupo.clave == 'comprar_almacen' ? principal : sala)?['maximo'] ==
        null;

    final color = switch (grupo.clave) {
      'reponer' => Colors.blue,
      'comprar_almacen' => Colors.deepOrange,
      _ => Colors.green,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tocar la tarjeta abre la edición del producto
        onTap: onEditar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _BadgeId(id: item['producto_id']),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(text: '${item['nombre']}  '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item['sku'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${item['sku']}${unidad.isNotEmpty ? ' · $unidad' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (sala != null || grupo.clave != 'comprar_almacen')
                      _ChipAlmacen(
                        icono: Icons.storefront,
                        color: colorSala,
                        nombre: nombreSala,
                        texto: _stockConLimites(item['stock_sala'], sala),
                      ),
                    if (grupo.clave != 'compra_directa_sala')
                      _ChipAlmacen(
                        icono: Icons.warehouse,
                        color: colorPrincipal,
                        nombre: nombrePrincipal,
                        texto: _stockConLimites(
                          item['stock_principal'],
                          principal,
                        ),
                      ),
                    if (paraSala > 0)
                      _Linea(
                        icono: Icons.info_outline,
                        texto:
                            'Incluye ${_num(paraSala)} que sala necesita y el almacén no cubre',
                        color: theme.colorScheme.primary,
                      ),
                    if (sinMaximo)
                      _Linea(
                        icono: Icons.warning_amber,
                        texto:
                            'Sin stock máximo: se sugiere solo hasta el mínimo',
                        color: Colors.orange.shade800,
                      ),
                    if (onTraspasar != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.tonalIcon(
                          onPressed: onTraspasar,
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Traspasar'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      _num(item['cantidad_sugerida']),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: color.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      grupo.verbo,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "#2081" destacado delante del nombre del producto.
class _BadgeId extends StatelessWidget {
  final dynamic id;

  const _BadgeId({required this.id});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '#$id',
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Stock de un almacén en una franja con su color: borde izquierdo, fondo
/// suave, icono y nombre del almacén en negrita.
class _ChipAlmacen extends StatelessWidget {
  final IconData icono;
  final MaterialColor color;
  final String nombre;
  final String texto;

  const _ChipAlmacen({
    required this.icono,
    required this.color,
    required this.nombre,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final tono = oscuro ? color.shade200 : color.shade800;
    final estilo = Theme.of(context).textTheme.bodySmall?.copyWith(color: tono);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: oscuro ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 15, color: tono),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$nombre: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: texto),
                ],
              ),
              style: estilo,
            ),
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color? color;

  const _Linea({required this.icono, required this.texto, this.color});

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 14, color: color ?? estilo?.color),
          const SizedBox(width: 4),
          Expanded(child: Text(texto, style: estilo)),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Widget? accion;

  const _Mensaje({required this.icono, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}
