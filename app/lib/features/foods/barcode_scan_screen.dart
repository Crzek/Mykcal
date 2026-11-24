import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import 'barcode_manual_dialog.dart';
import 'barcode_result_flow.dart';
import 'gtin.dart';

/// Construye la vista de la cámara. En producción es `MobileScanner`; las pruebas la sustituyen.
typedef ScannerViewBuilder = Widget Function(
  BuildContext context,
  MobileScannerController controller,
  void Function(BarcodeCapture capture) onDetect,
  Widget Function(BuildContext context, MobileScannerException error)
  errorBuilder,
);

Widget _defaultView(
  BuildContext context,
  MobileScannerController controller,
  void Function(BarcodeCapture) onDetect,
  Widget Function(BuildContext, MobileScannerException) errorBuilder,
) => MobileScanner(
  controller: controller,
  onDetect: onDetect,
  errorBuilder: (ctx, error) => errorBuilder(ctx, error),
);

/// Escanear un código de barras (pantalla 3 de contracts/ui-flows.md, research R13).
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({
    super.key,
    this.controller,
    this.viewBuilder = _defaultView,
    this.onCreate,
  });

  /// Se recibe por parámetro para poder simularlo (T050).
  final MobileScannerController? controller;
  final ScannerViewBuilder viewBuilder;
  final CreateFromBarcode? onCreate;

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  late final MobileScannerController _controller;
  late final bool _ownsController;
  bool _handling = false;

  /// Android no vuelve a mostrar el diálogo tras una denegación permanente: si al pulsar
  /// «Permitir cámara» el permiso sigue denegado, se indica cómo activarlo en el sistema.
  bool _deniedForever = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        MobileScannerController(
          formats: const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
          ],
          detectionSpeed: DetectionSpeed.noDuplicates,
        );
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || !isValidGtin(raw)) continue;
      await _lookup(normalizeGtin(raw));
      return;
    }
  }

  Future<void> _lookup(String code) async {
    if (_handling) return;
    _handling = true;
    HapticFeedback.mediumImpact();
    await _controller.stop();
    if (!mounted) return;
    await lookupAndShowBarcode(context, ref, code, onCreate: widget.onCreate);
    _handling = false;
    if (mounted) await _controller.start();
  }

  Future<void> _manual() async {
    final code = await showBarcodeManualDialog(context);
    if (code != null && mounted) await _lookup(code);
  }

  Future<void> _allow() async {
    try {
      await _controller.start();
    } on MobileScannerException {
      // El estado del controlador lleva el error; se comprueba abajo.
    }
    if (!mounted) return;
    if (_controller.value.error?.errorCode ==
        MobileScannerErrorCode.permissionDenied) {
      setState(() => _deniedForever = true);
    }
  }

  Widget _error(BuildContext context, MobileScannerException error) {
    final l10n = AppLocalizations.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final forever = denied && _deniedForever;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 48,
              semanticLabel: '',
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                !denied
                    ? l10n.scanUnsupported
                    : forever
                    ? l10n.scanPermissionSettings
                    : l10n.scanPermissionBody,
                textAlign: TextAlign.center,
              ),
            ),
            if (denied && !forever) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _allow,
                child: Text(l10n.scanPermissionAllow),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanTitle),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (_, state, _) => state.torchState == TorchState.unavailable
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.scanTorch,
                    icon: Icon(
                      state.torchState == TorchState.on
                          ? Icons.flashlight_on
                          : Icons.flashlight_off,
                    ),
                    onPressed: _controller.toggleTorch,
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: widget.viewBuilder(
                context,
                _controller,
                _onDetect,
                _error,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.scanHint, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _manual,
                    child: Text(l10n.scanManual),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
