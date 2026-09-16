import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String)? onBarcodeDetected;
  final Function(String, bool)? onBarcodeDetectedWithExists;

  const BarcodeScannerScreen({
    super.key,
    this.onBarcodeDetected,
    this.onBarcodeDetectedWithExists,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late MobileScannerController controller;
  String? lastScannedCode;
  bool _showSuccessIndicator = false;
  bool _isClosing = false; // Bandera para evitar múltiples cierres

  @override
  void initState() {
    super.initState();
    print('📱 [BarcodeScannerScreen] initState - Inicializando scanner');
    controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    print('📱 [BarcodeScannerScreen] dispose - Cerrando scanner');
    try {
      controller.dispose();
    } catch (e) {
      print('⚠️ [BarcodeScannerScreen] Error al disponer controller: $e');
    }
    super.dispose();
  }

  void _onCodeDetected(String code) {
    if (lastScannedCode == code) {
      print('⚠️ [Scanner] Código duplicado ignorado: $code');
      return; // Evitar duplicados muy rápidos
    }

    if (_isClosing) {
      print('⚠️ [Scanner] Ya se está cerrando, ignorando detección');
      return;
    }

    print('✅ [Scanner] Código detectado: $code');

    setState(() {
      lastScannedCode = code;
      _showSuccessIndicator = true;
    });

    // Callback si se proporciona
    widget.onBarcodeDetected?.call(code);

    // Marcar como cerrando y detener el scanner
    _isClosing = true;

    // Parar el scanner
    try {
      controller.stop();
      print('📱 [Scanner] Scanner pausado');
    } catch (e) {
      print('⚠️ [Scanner] Error al pausar: $e');
    }

    // Mostrar indicador de éxito y luego cerrar la pantalla
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        print('📱 [Scanner] Cerrando pantalla con código: $code');
        try {
          Navigator.pop(context, code);
          print('✅ [Scanner] Pop exitoso');
        } catch (e) {
          print('❌ [Scanner] Error en pop: $e');
        }
      } else {
        print('⚠️ [Scanner] Widget no está mounted al intentar cerrar');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código de Barra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;

              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first;
                print('🔍 Código detectado: ${barcode.rawValue}');

                if (barcode.rawValue != null) {
                  _onCodeDetected(barcode.rawValue!);
                }
              }
            },
          ),
          // Marco de escaneo visual
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _showSuccessIndicator
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.outline,
                  width: _showSuccessIndicator ? 4 : 3,
                ),
              ),
            ),
          ),
          // Indicador de éxito
          if (_showSuccessIndicator)
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 80,
                  ),
                ),
              ),
            ),
          // Texto informativo
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Text(
                  lastScannedCode != null
                      ? 'Código: $lastScannedCode\n✅ Cargado en el formulario'
                      : 'Alinea el código con el marco',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
