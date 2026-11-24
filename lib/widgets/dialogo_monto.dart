import 'package:flutter/material.dart';

/// Diálogo para pedir un monto. El controlador vive dentro del diálogo y se libera
/// en su propio dispose(), así no se usa después de liberarse durante la animación de salida.
class DialogoMonto extends StatefulWidget {
  final String titulo;
  final String etiqueta;
  final String valorInicial;
  final String textoConfirmar;

  const DialogoMonto({
    super.key,
    required this.titulo,
    required this.etiqueta,
    required this.valorInicial,
    this.textoConfirmar = 'Aceptar',
  });

  /// Devuelve el monto escrito, o null si se cancela o no es un número.
  static Future<double?> mostrar(
    BuildContext context, {
    required String titulo,
    required String etiqueta,
    required String valorInicial,
    String textoConfirmar = 'Aceptar',
  }) {
    return showDialog<double>(
      context: context,
      builder: (_) => DialogoMonto(
        titulo: titulo,
        etiqueta: etiqueta,
        valorInicial: valorInicial,
        textoConfirmar: textoConfirmar,
      ),
    );
  }

  @override
  State<DialogoMonto> createState() => _DialogoMontoState();
}

class _DialogoMontoState extends State<DialogoMonto> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.valorInicial,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? _parse(String s) {
    final limpio = s.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    return double.tryParse(limpio);
  }

  void _confirmar() => Navigator.pop(context, _parse(_ctrl.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo, maxLines: 2),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        // El botón "listo" del teclado aplica el valor, igual que el botón del diálogo
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _confirmar(),
        decoration: InputDecoration(labelText: widget.etiqueta),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: Text(widget.textoConfirmar)),
      ],
    );
  }
}
