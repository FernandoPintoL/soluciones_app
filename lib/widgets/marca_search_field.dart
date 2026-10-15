import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dropdown_option.dart';
import '../providers/dropdown_provider.dart';
import 'campo_formulario.dart';

/// Campo de búsqueda de marcas contra la API (con debounce).
class MarcaSearchField extends StatefulWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const MarcaSearchField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<MarcaSearchField> createState() => _MarcaSearchFieldState();
}

class _MarcaSearchFieldState extends State<MarcaSearchField> {
  final _controller = TextEditingController();
  List<DropdownOption> _resultados = [];
  bool _buscando = false;
  bool _mostrarDropdown = false;
  Timer? _debounce;
  // Se incrementa en cada búsqueda para descartar respuestas que llegan tarde
  int _busquedaActual = 0;

  @override
  void initState() {
    super.initState();
    _cargarMarcaActual();
  }

  @override
  void didUpdateWidget(MarcaSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el marcaId cambió (cuando se carga el producto completo), recargar
    if (widget.value != oldWidget.value) {
      _cargarMarcaActual();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargarMarcaActual() async {
    if (widget.value == null) return;
    final marca = await context.read<DropdownProvider>().getMarcaById(
      widget.value!,
    );
    if (marca != null && mounted) {
      setState(() => _controller.text = marca.nombre);
    }
  }

  void _onTextoCambiado(String query) {
    _debounce?.cancel();
    final busqueda = ++_busquedaActual;

    if (query.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _mostrarDropdown = false;
        _buscando = false;
      });
      // Texto borrado: quitar la marca seleccionada
      if (widget.value != null) widget.onChanged(null);
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _buscarMarcas(query.trim(), busqueda),
    );
  }

  Future<void> _buscarMarcas(String query, int busqueda) async {
    setState(() => _buscando = true);

    final resultados = await context.read<DropdownProvider>().searchMarcas(
      query,
    );

    if (mounted && busqueda == _busquedaActual) {
      setState(() {
        _resultados = resultados;
        _buscando = false;
        _mostrarDropdown = resultados.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: decoracionCampo(
            'Marca',
            hint: 'Buscar marca...',
            completado: widget.value != null,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _buscando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _onTextoCambiado,
          onTap: () {
            if (_controller.text.isNotEmpty && _resultados.isNotEmpty) {
              setState(() => _mostrarDropdown = true);
            }
          },
        ),
        if (_mostrarDropdown && _resultados.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (context, index) {
                final marca = _resultados[index];
                return ListTile(
                  title: Text(marca.nombre),
                  onTap: () {
                    setState(() {
                      _controller.text = marca.nombre;
                      _mostrarDropdown = false;
                      _resultados = [];
                    });
                    widget.onChanged(marca.id);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
