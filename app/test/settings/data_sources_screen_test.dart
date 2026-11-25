import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/settings/data_sources_screen.dart';
import 'package:mykcal/features/settings/settings_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

void main() {
  testWidgets('muestra la atribución de CIQUAL y de Open Food Facts', (
    tester,
  ) async {
    final h = Harness();
    await h.pumpScreen(tester, const DataSourcesScreen());
    expect(
      find.textContaining(
        'Table de composition nutritionnelle des aliments Ciqual',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('edición 2025'), findsOneWidget);
    expect(find.textContaining('CC BY 4.0'), findsOneWidget);
    expect(find.textContaining('Open Database License (ODbL)'), findsOneWidget);
    expect(find.byType(SelectableText), findsNWidgets(2));
    expect(find.text('https://ciqual.anses.fr'), findsOneWidget);
    expect(find.text('https://world.openfoodfacts.org'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('Ajustes tiene la entrada «Fuentes de datos»', (tester) async {
    final h = Harness();
    await h.pumpScreen(tester, const SettingsScreen());
    await tester.tap(find.text('Fuentes de datos'));
    await tester.pumpAndSettle();
    expect(find.text('Productos envasados'), findsOneWidget);
  });

  testWidgets('con el texto al 200 % no desborda', (tester) async {
    final h = Harness();
    await h.pumpScreen(
      tester,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: DataSourcesScreen(),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ajustes muestra el estado de la clave de IA y abre la guía', (
    tester,
  ) async {
    final h = Harness();
    await h.pumpScreen(tester, const SettingsScreen());
    expect(find.text('Clave de IA'), findsOneWidget);
    expect(find.text('No configurada'), findsOneWidget);
    final h2 = Harness();
    h2.api.onAiKey = () async => AiKeyStatus(
      provider: 'gemini',
      configuredAt: DateTime.utc(2026, 11, 25, 10),
    );
    await tester.pumpWidget(const SizedBox());
    await h2.pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    expect(find.text('Configurada · 25 nov 2026'), findsOneWidget);
    await tester.tap(find.text('Clave de IA'));
    await tester.pumpAndSettle();
    expect(find.text('Proveedor: Google Gemini'), findsOneWidget);
  });
}
