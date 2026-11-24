import 'dart:async';

import 'package:flutter/material.dart';

import '../models/venta_app.dart';
import '../services/api_errors.dart';
import '../services/ventas_service.dart';

/// Hoja para elegir cliente: lista paginada que carga la siguiente página al hacer scroll.
/// Sin texto lista todos los clientes; con 2 o más letras filtra por nombre, NIT o teléfono.
/// Devuelve el [ClienteVenta] elegido con Navigator.pop.
class SelectorCliente extends StatefulWidget {
  const SelectorCliente({super.key});

  @override
  State<SelectorCliente> createState() => _SelectorClienteState();
}

class _SelectorClienteState extends State<SelectorCliente> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<ClienteVenta> _items = [];
  String _q = '';
  int _pagina = 0;
  bool _hayMas = true;
  bool _cargando = false;
  int _req = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _recargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final texto = valor.trim();
      final consulta = texto.length >= 2 ? texto : '';
      if (consulta != _q) {
        _q = consulta;
        _recargar();
      }
    });
  }

  /// Vuelve a la primera página (al cambiar el texto de búsqueda).
  Future<void> _recargar() async {
    final req = ++_req;
    setState(() {
      _items.clear();
      _pagina = 0;
      _hayMas = true;
      _cargando = false;
      _error = null;
    });
    await _cargarPagina(req);
  }

  Future<void> _cargarPagina(int req) async {
    if (_cargando || !_hayMas) return;
    setState(() => _cargando = true);
    try {
      final siguiente = _pagina + 1;
      final r = await ventasService.listarClientes(page: siguiente, q: _q);
      if (!mounted || req != _req) return;
      setState(() {
        _items.addAll(r.items);
        _pagina = siguiente;
        _hayMas = r.hasMore;
      });
    } catch (e) {
      if (mounted && req == _req) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted && req == _req) {
        setState(() => _cargando = false);
        // Si la página no llena la pantalla no hay scroll: pedir la siguiente igual
        WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      }
    }
  }

  void _onScroll() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.extentAfter < 300 || pos.maxScrollExtent == 0) {
      _cargarPagina(_req);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Text(
              'Elegir cliente',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                labelText: 'Nombre, NIT o teléfono',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: TextStyle(color: colores.error)),
            Expanded(child: _listado(colores)),
          ],
        ),
      ),
    );
  }

  Widget _listado(ColorScheme colores) {
    if (_items.isEmpty) {
      if (_cargando) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Text(
          _q.isEmpty ? 'No hay clientes' : 'Sin resultados para "$_q"',
          style: TextStyle(color: colores.onSurfaceVariant),
        ),
      );
    }

    final conPie = _cargando || _hayMas;
    return ListView.builder(
      controller: _scroll,
      itemCount: _items.length + (conPie ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final c = _items[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(c.nombre),
          subtitle: c.nit != null && c.nit!.isNotEmpty
              ? Text('NIT: ${c.nit}')
              : null,
          onTap: () => Navigator.pop(context, c),
        );
      },
    );
  }
}
