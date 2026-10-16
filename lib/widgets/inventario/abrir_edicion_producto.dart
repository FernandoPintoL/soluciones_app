import 'package:flutter/material.dart';

import '../../services/service_locator.dart';
import '../../views/producto_form_screen.dart';

/// Abre el formulario de edición del producto [productoId] desde cualquier
/// pantalla que solo tenga su id.
///
/// Carga antes el producto completo: el formulario toma de `widget.producto`
/// los campos que no muestra (descripción, peso, activo…) y los reenvía al
/// guardar, así que abrirlo con un objeto incompleto los borraría.
///
/// Se completa cuando el usuario vuelve del formulario (guardado o no).
Future<void> abrirEdicionProducto(BuildContext context, int productoId) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final producto = await apiService.getProductoById(productoId);
    navigator.pop(); // cierra el indicador de carga
    await navigator.push(
      MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: producto)),
    );
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'No se pudo abrir el producto #$productoId: '
          '${e.toString().replaceFirst('Exception: ', '')}',
        ),
      ),
    );
  }
}
