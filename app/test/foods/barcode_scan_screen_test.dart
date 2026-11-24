import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/foods/barcode_result_flow.dart';
import 'package:mykcal/features/foods/barcode_scan_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

class MockScanner extends Mock implements MobileScannerController {}

const validCode = '8410000000016';

MobileScannerState stateWith({MobileScannerException? error}) =>
    MobileScannerState(
      availableCameras: 1,
      cameraDirection: CameraFacing.back,
      cameraLensType: CameraLensType.any,
      isInitialized: error == null,
      isStarting: false,
      isRunning: error == null,
      size: Size.zero,
      torchState: TorchState.unavailable,
      zoomScale: 1,
      deviceOrientation: DeviceOrientation.portraitUp,
      error: error,
    );

class Setup {
  Setup({MobileScannerException? error}) {
    controller = MockScanner();
    when(() => controller.value).thenReturn(stateWith(error: error));
    when(() => controller.stop()).thenAnswer((_) async {});
    when(() => controller.start()).thenAnswer((_) async {});
    when(() => controller.toggleTorch()).thenAnswer((_) async {});
  }

  late final MockScanner controller;
  late void Function(BarcodeCapture) detect;
  MobileScannerException? error;

  ScannerViewBuilder get view => (ctx, c, onDetect, errorBuilder) {
    detect = onDetect;
    final e = controller.value.error;
    return e == null ? const SizedBox.expand() : errorBuilder(ctx, e);
  };

  Widget screen({CreateFromBarcode? onCreate}) => BarcodeScanScreen(
    controller: controller,
    viewBuilder: view,
    onCreate: onCreate,
  );
}

BarcodeCapture capture(String? raw) => BarcodeCapture(
  barcodes: [Barcode(rawValue: raw, format: BarcodeFormat.ean13)],
);

void main() {
  testWidgets('código leído: una sola llamada y la cámara se detiene', (
    tester,
  ) async {
    final h = Harness();
    final calls = <String>[];
    h.api.onBarcode = (code) async {
      calls.add(code);
      return BarcodeLookup(
        result: BarcodeResult.found,
        code: code,
        food: sampleFood(),
      );
    };
    final s = Setup();
    await h.pumpScreen(tester, s.screen());
    s.detect(capture(validCode));
    s.detect(capture(validCode)); // el mismo código llega dos veces
    await tester.pumpAndSettle();
    expect(calls, [validCode]);
    verify(() => s.controller.stop()).called(1);
    expect(find.text('Plátano, crudo'), findsWidgets); // detalle del alimento
  });

  testWidgets('un código con el dígito de control mal se ignora', (
    tester,
  ) async {
    final h = Harness();
    var calls = 0;
    h.api.onBarcode = (_) async {
      calls++;
      throw StateError('no debe llamarse');
    };
    final s = Setup();
    await h.pumpScreen(tester, s.screen());
    s.detect(capture('8410000000017'));
    s.detect(capture(null));
    await tester.pumpAndSettle();
    expect(calls, 0);
    verifyNever(() => s.controller.stop());
  });

  testWidgets('permiso denegado: explicación y entrada manual', (tester) async {
    final h = Harness();
    final s = Setup(
      error: const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      ),
    );
    await h.pumpScreen(tester, s.screen());
    expect(
      find.text(
        'Mykcal usa la cámara solo para leer códigos de barras. No guarda fotos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Permitir cámara'), findsOneWidget);
    expect(find.text('Introducir el código a mano'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('denegado para siempre: texto de ajustes en vez del botón', (
    tester,
  ) async {
    final h = Harness();
    final s = Setup(
      error: const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      ),
    );
    await h.pumpScreen(tester, s.screen());
    await tester.tap(find.text('Permitir cámara'));
    await tester.pumpAndSettle();
    verify(() => s.controller.start()).called(1);
    expect(find.text('Permitir cámara'), findsNothing);
    expect(
      find.text(
        'Puedes activarlo en Ajustes del sistema → Aplicaciones → Mykcal → Permisos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Introducir el código a mano'), findsOneWidget);
  });

  testWidgets('entrada manual: código inválido no llama a la API', (
    tester,
  ) async {
    final h = Harness();
    var calls = 0;
    h.api.onBarcode = (code) async {
      calls++;
      return BarcodeLookup(
        result: BarcodeResult.found,
        code: code,
        food: sampleFood(),
      );
    };
    final s = Setup();
    await h.pumpScreen(tester, s.screen());
    await tester.tap(find.text('Introducir el código a mano'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '8410000000017');
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Revisa el código: no es válido'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byType(TextField), validCode);
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('accesible y sin desbordes con el texto al 200 %', (
    tester,
  ) async {
    final h = Harness();
    final s = Setup();
    await h.pumpScreen(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: s.screen(),
      ),
    );
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });
}
