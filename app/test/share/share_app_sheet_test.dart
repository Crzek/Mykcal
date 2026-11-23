import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mykcal/core/config/download_link.dart';
import 'package:mykcal/core/share/share_port.dart';
import 'package:mykcal/features/share/share_app_sheet.dart';
import 'package:mykcal/l10n/app_localizations.dart';

class _FakeShare extends Mock implements SharePort {}

const _link = 'https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk';

void main() {
  late _FakeShare share;
  late List<String> clipboard;
  Object? clipboardError;

  setUp(() {
    share = _FakeShare();
    when(() => share.share(any())).thenAnswer((_) async {});
    clipboard = [];
    clipboardError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardError != null) throw clipboardError!;
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharePortProvider.overrideWithValue(share),
          downloadLinkProvider.overrideWithValue(_link),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showShareAppSheet(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra título, explicación y enlace seleccionable', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(find.text('Compartir Mykcal'), findsOneWidget);
    expect(find.textContaining('código de invitación'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text(_link), findsOneWidget);
  });

  testWidgets('Copiar escribe el enlace exacto y avisa', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('Copiar'));
    await tester.pumpAndSettle();
    expect(clipboard, [_link]);
    expect(find.text('Enlace copiado'), findsOneWidget);
  });

  testWidgets('si el portapapeles falla, avisa y la hoja sigue abierta', (
    tester,
  ) async {
    clipboardError = PlatformException(code: 'error');
    await pumpSheet(tester);
    await tester.tap(find.text('Copiar'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo copiar el enlace'), findsOneWidget);
    expect(find.text(_link), findsOneWidget);
  });

  testWidgets('Compartir envía el texto con el enlace y sin datos personales', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.tap(find.text('Compartir').last);
    await tester.pumpAndSettle();
    final text =
        verify(() => share.share(captureAny())).captured.single as String;
    expect(text, 'Prueba Mykcal, la app para registrar lo que comes: $_link');
    expect(text, isNot(contains('Ana')));
  });

  testWidgets('botones de al menos 48 dp y con etiqueta', (tester) async {
    await pumpSheet(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
