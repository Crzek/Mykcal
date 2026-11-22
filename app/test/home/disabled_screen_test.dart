import 'package:flutter_test/flutter_test.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

void main() {
  testWidgets('cuenta desactivada: mensaje, cerrar sesión y accesible (US2-4)', (tester) async {
    final h = Harness();
    await seedSession();
    h.api.onMe = () async => meDisabled;
    await h.pumpApp(tester);
    expect(find.text('Tu cuenta está desactivada'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    await expectAccessible(tester);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
