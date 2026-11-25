import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/photo/draft_model.dart';
import 'package:mykcal/features/photo/drafts_controller.dart';
import 'package:mykcal/features/photo/drafts_store.dart';

import '../helpers/fakes.dart';

PhotoDraft draft(String id, int minute) => PhotoDraft(
  id: id,
  meal: Meal.dinner,
  entryDate: DateTime(2026, 11, 25),
  photoPath: '/no/existe/$id.jpg',
  createdAt: DateTime.utc(2026, 11, 25, 20, minute),
  failureCode: 'timeout',
);

void main() {
  test('list refleja el almacén', () async {
    final h = Harness();
    await DraftsStore().save(draft('a', 1));
    final c = h.container();
    c.listen(draftsControllerProvider, (_, _) {});
    final list = await c.read(draftsControllerProvider.future);
    expect(list.map((d) => d.id), ['a']);
  });

  test(
    'discard elimina el borrador y tolera una foto que ya no está',
    () async {
      final h = Harness();
      final c = h.container();
      c.listen(draftsControllerProvider, (_, _) {});
      final controller = c.read(draftsControllerProvider.notifier);
      await controller.put(draft('a', 1));
      await controller.put(draft('b', 2));
      await controller.discard('a');
      expect(c.read(draftsControllerProvider).value!.map((d) => d.id), ['b']);
      expect((await DraftsStore().list()).map((d) => d.id), ['b']);
    },
  );

  test(
    'completeManually lo elimina sin tocar las entradas del diario',
    () async {
      final h = Harness();
      final c = h.container();
      c.listen(draftsControllerProvider, (_, _) {});
      final controller = c.read(draftsControllerProvider.notifier);
      await controller.put(draft('a', 1));
      await controller.completeManually('a');
      expect(c.read(draftsControllerProvider).value, isEmpty);
      expect(h.api.addedEntries, isEmpty);
      expect(h.api.deletedEntries, isEmpty);
    },
  );

  test('guardar el borrador número 21 descarta el más antiguo', () async {
    final h = Harness();
    final c = h.container();
    c.listen(draftsControllerProvider, (_, _) {});
    final controller = c.read(draftsControllerProvider.notifier);
    for (var i = 0; i < 21; i++) {
      await controller.put(draft('d$i', i));
    }
    final ids = c.read(draftsControllerProvider).value!.map((d) => d.id);
    expect(ids, hasLength(20));
    expect(ids, isNot(contains('d0')));
  });
}
