import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/photo/draft_model.dart';
import 'package:mykcal/features/photo/drafts_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

PhotoDraft draft(String id, int minute) => PhotoDraft(
  id: id,
  meal: Meal.lunch,
  entryDate: DateTime(2026, 11, 25),
  photoPath: '/tmp/$id.jpg',
  createdAt: DateTime.utc(2026, 11, 25, 12, minute),
  description: 'arroz',
  totalGrams: 300,
  failureCode: 'timeout',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guarda y lista, y conserva todos los campos', () async {
    final store = DraftsStore();
    await store.save(draft('a', 1));
    final back = (await store.list()).single;
    expect(back.id, 'a');
    expect(back.meal, Meal.lunch);
    expect(back.entryDate, DateTime(2026, 11, 25));
    expect(back.description, 'arroz');
    expect(back.totalGrams, 300);
    expect(back.failureCode, 'timeout');
    expect(back.photoPath, '/tmp/a.jpg');
  });

  test('guardar con el mismo id sustituye', () async {
    final store = DraftsStore();
    await store.save(draft('a', 1));
    await store.save(draft('a', 1).withFailure('quota_exceeded'));
    final all = await store.list();
    expect(all, hasLength(1));
    expect(all.single.failureCode, 'quota_exceeded');
  });

  test('elimina uno', () async {
    final store = DraftsStore();
    await store.save(draft('a', 1));
    await store.save(draft('b', 2));
    await store.remove('a');
    expect((await store.list()).map((d) => d.id), ['b']);
  });

  test('al superar 20 descarta el más antiguo y lo devuelve', () async {
    final store = DraftsStore();
    for (var i = 0; i < 20; i++) {
      await store.save(draft('d$i', i));
    }
    final dropped = await store.save(draft('nuevo', 30));
    expect(dropped.map((d) => d.id), ['d0']);
    final ids = (await store.list()).map((d) => d.id).toList();
    expect(ids, hasLength(20));
    expect(ids, isNot(contains('d0')));
    expect(ids.last, 'nuevo');
  });

  test('persiste entre instancias', () async {
    await DraftsStore().save(draft('a', 1));
    expect((await DraftsStore().list()).single.id, 'a');
  });

  test('una propuesta se guarda sin causa y se recupera', () async {
    final store = DraftsStore();
    await store.save(draft('a', 1).withProposal(sampleProposalForStore()));
    final back = (await store.list()).single;
    expect(back.hasProposal, isTrue);
    expect(back.proposal!.items.single.aiName, 'Arroz');
  });

  test('datos ilegibles no rompen: lista vacía', () async {
    SharedPreferences.setMockInitialValues({'photo_drafts': 'esto no es json'});
    expect(await DraftsStore().list(), isEmpty);
  });
}

PhotoAnalysisResult sampleProposalForStore() => const PhotoAnalysisResult(
  items: [ProposedItem(aiName: 'Arroz', aiGrams: 100, flagged: false)],
);
