import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import 'draft_model.dart';
import 'drafts_controller.dart';

/// Códigos de fallo de un borrador y cómo salen del API (research R11).
String failureCodeFor(Object error) {
  if (error is ApiError) {
    return switch (error.code) {
      'AI_KEY_INVALID' => 'key_invalid',
      'AI_KEY_REQUIRED' => 'key_required',
      'AI_QUOTA_EXCEEDED' => 'quota_exceeded',
      'AI_RESPONSE_INVALID' => 'invalid_response',
      'AI_UNRECOGNIZED' => 'unrecognized',
      'AI_TIMEOUT' => 'timeout',
      _ => 'provider_unavailable',
    };
  }
  if (error is NetworkFailure) return 'no_connection';
  return 'provider_unavailable';
}

/// Resultado de un análisis para quien lo observa (snackbars del diario).
class AnalysisOutcome {
  const AnalysisOutcome(this.draft);

  /// Con propuesta lista o con `failureCode`.
  final PhotoDraft draft;
}

final analysisOutcomesProvider = StateProvider<AnalysisOutcome?>((ref) => null);

/// Ids de los borradores cuyo análisis está en vuelo (`pendiente`, research R8).
///
/// Enviar nunca bloquea: el borrador se guarda **antes** de enviar con `interrupted`; si la app se
/// cierra a mitad, ese borrador es el que se encuentra al volver. Si llega la respuesta, lo
/// sustituye por la propuesta o por la causa del fallo.
final pendingAnalysisProvider =
    NotifierProvider<PendingAnalysisNotifier, Set<String>>(
      PendingAnalysisNotifier.new,
    );

class PendingAnalysisNotifier extends Notifier<Set<String>> {
  bool _disposed = false;

  @override
  Set<String> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const {};
  }

  /// Envía una foto nueva en segundo plano.
  Future<void> submit({
    required String photoPath,
    required Meal meal,
    required DateTime date,
    String? description,
    int? totalGrams,
  }) async {
    final draft = PhotoDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      meal: meal,
      entryDate: date,
      photoPath: photoPath,
      createdAt: DateTime.now(),
      description: description,
      totalGrams: totalGrams,
      failureCode: 'interrupted',
    );
    await ref.read(draftsControllerProvider.notifier).put(draft);
    await _run(draft);
  }

  /// Reintenta con la foto y los datos del borrador.
  Future<void> retry(PhotoDraft draft) =>
      _run(draft.withFailure('interrupted'));

  Future<void> _run(PhotoDraft draft) async {
    state = {...state, draft.id};
    final drafts = ref.read(draftsControllerProvider.notifier);
    await drafts.put(draft.withFailure('interrupted'));
    PhotoDraft result;
    try {
      final proposal = await ref
          .read(mykcalApiProvider)
          .analyzePhoto(
            photoPath: draft.photoPath,
            meal: draft.meal,
            date: draft.entryDate,
            description: draft.description,
            totalGrams: draft.totalGrams,
          );
      result = draft.withProposal(proposal);
    } on Object catch (e) {
      result = draft.withFailure(failureCodeFor(e));
    }
    // Si el proveedor se descartó (la app se cerró), el borrador `interrupted` ya está guardado.
    if (_disposed) return;
    state = {...state}..remove(draft.id);
    await drafts.put(result);
    if (_disposed) return;
    ref.read(analysisOutcomesProvider.notifier).state = AnalysisOutcome(result);
  }
}
