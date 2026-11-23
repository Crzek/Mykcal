import 'package:flutter_test/flutter_test.dart';

/// Guías de accesibilidad de FR-017 / SC-007: contraste AA, zonas táctiles y etiquetas.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
}
