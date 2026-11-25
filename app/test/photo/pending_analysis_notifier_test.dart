import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/photo/drafts_controller.dart';
import 'package:mykcal/features/photo/pending_analysis_notifier.dart';

import '../helpers/fakes.dart';

final day = DateTime(2026, 11, 25);

Future<void> submit(ProviderContainer c, {String? description}) => c
    .read(pendingAnalysisProvider.notifier)
    .submit(
      photoPath: photoPath,
      meal: Meal.lunch,
      date: day,
      description: description,
      totalGrams: 300,
    );

void main() {
  test('éxito: pendiente mientras vuela y luego propuesta guardada', () async {
    final h = Harness();
    final gate = Completer<PhotoAnalysisResult>();
    h.api.onAnalyzePhoto = (_) => gate.future;
    final c = h.container();
    c.listen(draftsControllerProvider, (_, _) {});
    await c.read(draftsControllerProvider.future);

    final sending = submit(c, description: 'arroz');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(pendingAnalysisProvider), hasLength(1));
    // Pendiente: aún no es un borrador que gestionar...
    expect(c.read(visibleDraftsProvider), isEmpty);
    // ...y el resto de la app sigue libre: se puede registrar por búsqueda.
    await h.api.addEntry(
      date: day,
      meal: Meal.lunch,
      foodId: 'otro',
      quantity: 50,
      utcOffsetMin: 0,
    );
    expect(h.api.addedEntries, hasLength(1));

    gate.complete(sampleProposal());
    await sending;
    expect(c.read(pendingAnalysisProvider), isEmpty);
    final draft = c.read(visibleDraftsProvider).single;
    expect(draft.hasProposal, isTrue);
    expect(draft.failureCode, isNull);
    expect(draft.proposal!.items, hasLength(2));
    final call = h.api.analyzeCalls.single;
    expect(call.description, 'arroz');
    expect(call.totalGrams, 300);
    expect(c.read(analysisOutcomesProvider)!.draft.id, draft.id);
  });

  final failures = <(Object, String)>[
    (const ApiError('AI_KEY_INVALID', 422), 'key_invalid'),
    (const ApiError('AI_QUOTA_EXCEEDED', 429), 'quota_exceeded'),
    (const ApiError('AI_RESPONSE_INVALID', 422), 'invalid_response'),
    (const ApiError('AI_UNRECOGNIZED', 422), 'unrecognized'),
    (const ApiError('AI_TIMEOUT', 504), 'timeout'),
    (const ApiError('AI_PROVIDER_UNAVAILABLE', 503), 'provider_unavailable'),
    (const ApiError('AI_KEY_REQUIRED', 403), 'key_required'),
    (const NetworkFailure(), 'no_connection'),
  ];
  for (final (error, code) in failures) {
    test('fallo $code: queda como borrador con su causa', () async {
      final h = Harness();
      h.api.onAnalyzePhoto = (_) async => throw error;
      final c = h.container();
      c.listen(draftsControllerProvider, (_, _) {});
      await c.read(draftsControllerProvider.future);
      await submit(c);
      final draft = c.read(visibleDraftsProvider).single;
      expect(draft.failureCode, code);
      expect(draft.hasProposal, isFalse);
      expect(draft.photoPath, photoPath);
      expect(draft.meal, Meal.lunch);
      expect(c.read(pendingAnalysisProvider), isEmpty);
    });
  }

  test(
    'app cerrada durante el análisis: queda un borrador «interrupted»',
    () async {
      final h = Harness();
      final gate = Completer<PhotoAnalysisResult>();
      h.api.onAnalyzePhoto = (_) => gate.future;
      final c1 = ProviderContainer(overrides: h.overrides);
      c1.listen(draftsControllerProvider, (_, _) {});
      await c1.read(draftsControllerProvider.future);
      final sending = submit(c1);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      c1.dispose(); // el proceso termina antes de la respuesta
      gate.complete(sampleProposal());
      await sending;

      // Al reabrir (contenedor nuevo, mismo almacenamiento local) la foto está como borrador.
      final c2 = h.container();
      c2.listen(draftsControllerProvider, (_, _) {});
      await c2.read(draftsControllerProvider.future);
      final draft = c2.read(visibleDraftsProvider).single;
      expect(draft.failureCode, 'interrupted');
      expect(draft.photoPath, photoPath);
    },
  );

  test(
    'reintentar reenvía la misma foto y, con éxito, deja la propuesta',
    () async {
      final h = Harness();
      var calls = 0;
      h.api.onAnalyzePhoto = (_) async {
        if (calls++ == 0) throw const ApiError('AI_TIMEOUT', 504);
        return sampleProposal();
      };
      final c = h.container();
      c.listen(draftsControllerProvider, (_, _) {});
      await c.read(draftsControllerProvider.future);
      await submit(c, description: 'arroz');
      final first = c.read(visibleDraftsProvider).single;
      expect(first.failureCode, 'timeout');
      await c.read(draftsControllerProvider.notifier).retry(first.id);
      final second = c.read(visibleDraftsProvider).single;
      expect(second.id, first.id);
      expect(second.hasProposal, isTrue);
      expect(h.api.analyzeCalls.last.description, 'arroz');
    },
  );
}
