import 'package:flutter/material.dart';

import 'campo_formulario.dart';

class SearchSelectField<T> extends StatefulWidget {
  final int? value;
  final void Function(int?) onChanged;
  final String labelText;
  final String hintText;
  final List<SearchSelectOption<T>> items;
  final bool isExpanded;
  final bool enabled;

  const SearchSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelText,
    required this.items,
    this.hintText = 'Buscar...',
    this.isExpanded = true,
    this.enabled = true,
  });

  @override
  State<SearchSelectField<T>> createState() => _SearchSelectFieldState<T>();
}

class SearchSelectOption<T> {
  final int id;
  final String nombre;

  SearchSelectOption({required this.id, required this.nombre});
}

class _SearchSelectFieldState<T> extends State<SearchSelectField<T>> {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  List<SearchSelectOption<T>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
    _filteredItems = widget.items;

    // Mostrar el valor seleccionado en el campo si existe
    if (widget.value != null) {
      try {
        final selected = widget.items.firstWhere(
          (item) => item.id == widget.value,
        );
        _searchController.text = selected.nombre;
      } catch (e) {
        // No encontrado
      }
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(SearchSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _filteredItems = widget.items;
      if (_searchController.text.isNotEmpty) {
        _filterItems(_searchController.text);
      }
    }

    // Actualizar el campo si el valor cambia desde afuera
    if (oldWidget.value != widget.value) {
      if (widget.value != null) {
        try {
          final selected = widget.items.firstWhere(
            (item) => item.id == widget.value,
          );
          _searchController.text = selected.nombre;
        } catch (e) {
          _searchController.clear();
        }
      } else {
        _searchController.clear();
      }
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    if (query.isEmpty) {
      _filteredItems = widget.items;
    } else {
      _filteredItems = widget.items
          .where(
            (item) => item.nombre.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }

    // Recrear el overlay con los datos actualizados
    _hideOverlay();
    if (_focusNode.hasFocus) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (!mounted || _overlayEntry != null) return;

    try {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final size = renderBox.size;
      final offset = renderBox.localToGlobal(Offset.zero);

      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: offset.dx,
          top: offset.dy + size.height + 5,
          width: size.width,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline
                      .withAlpha((0.5 * 255).toInt()),
                ),
              ),
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No hay opciones',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        if (index >= _filteredItems.length)
                          return const SizedBox.shrink();

                        final item = _filteredItems[index];
                        final isSelected = widget.value == item.id;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _hideOverlay();
                              _searchController.clear();
                              _filteredItems = widget.items;
                              widget.onChanged(item.id);
                              _focusNode.unfocus();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                        .withAlpha((0.1 * 255).toInt())
                                  : Colors.transparent,
                              child: Text(
                                item.nombre,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    } catch (e) {
      print('Error showing overlay: $e');
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _searchController,
      focusNode: _focusNode,
      enabled: widget.enabled,
      decoration: decoracionCampo(
        widget.labelText,
        hint: widget.hintText,
        completado: widget.value != null,
        prefixIcon: widget.value != null
            ? const Icon(Icons.check_circle)
            : null,
        suffixIcon: _searchController.text.isEmpty
            ? const Icon(Icons.search)
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _filteredItems = widget.items;
                  _hideOverlay();
                  widget.onChanged(null);
                },
              ),
      ),
      onChanged: _filterItems,
    );
  }
}
