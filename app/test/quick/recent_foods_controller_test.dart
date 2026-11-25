import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/diary/diary_day_controller.dart';
import 'package:mykcal/features/quick/recent_foods_controller.dart';

import '../helpers/fakes.dart';

void main() {
  test('recentFoodsProvider carga de la API', () async {
    final h = Harness();
    h.api.onRecentFoods = () async => [sampleQuick(name: 'Pan')];
    final c = h.container();
    final sub = c.listen(recentFoodsProvider, (_, _) {});
    final items = await c.read(recentFoodsProvider.future);
    expect(items.single.food.name, 'Pan');
    expect(h.api.recentCalls, 1);
    sub.close();
  });

  test('DiaryDayController.apply refresca Recientes', () async {
    final h = Harness();
    var round = 0;
    h.api.onRecentFoods = () async => [sampleQuick(name: 'Pan ${round++}')];
    final c = h.container();
    final sub = c.listen(recentFoodsProvider, (_, _) {});
    final day = DateTime(2026, 11, 22);
    c.listen(diaryDayControllerProvider(day), (_, _) {});
    await c.read(diaryDayControllerProvider(day).future);
    expect(
      (await c.read(recentFoodsProvider.future)).single.food.name,
      'Pan 0',
    );
    c
        .read(diaryDayControllerProvider(day).notifier)
        .apply(sampleDay(date: day));
    expect(
      (await c.read(recentFoodsProvider.future)).single.food.name,
      'Pan 1',
    );
    expect(h.api.recentCalls, 2);
    sub.close();
  });

  test('refresh() vuelve a pedir la lista', () async {
    final h = Harness();
    h.api.onRecentFoods = () async => [sampleQuick()];
    final c = h.container();
    final sub = c.listen(recentFoodsProvider, (_, _) {});
    await c.read(recentFoodsProvider.future);
    await c.read(recentFoodsProvider.notifier).refresh();
    expect(h.api.recentCalls, 2);
    sub.close();
  });
}
