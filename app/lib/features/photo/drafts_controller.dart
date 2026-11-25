import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'draft_model.dart';
import 'drafts_store.dart';
import 'pending_analysis_notifier.dart';

final draftsStoreProvider = Provider<DraftsStore>((ref) => DraftsStore());

/// Borradores guardados en el móvil, del más antiguo al más reciente.
final draftsControllerProvider =
    AsyncNotifierProvider<DraftsController, List<PhotoDraft>>(
      DraftsController.new,
    );

/// Borradores que el usuario puede gestionar: los que se están analizando ahora no cuentan.
final visibleDraftsProvider = Provider<List<PhotoDraft>>((ref) {
  final inFlight = ref.watch(pendingAnalysisProvider);
  final drafts = ref.watch(draftsControllerProvider).valueOrNull ?? const [];
  return [
    for (final d in drafts)
      if (!inFlight.contains(d.id)) d,
  ];
});

class DraftsController extends AsyncNotifier<List<PhotoDraft>> {
  @override
  Future<List<PhotoDraft>> build() => ref.watch(draftsStoreProvider).list();

  Future<void> reload() async {
    state = AsyncData(await ref.read(draftsStoreProvider).list());
  }

  /// Guarda o sustituye un borrador y borra la foto de los que el tope descartó.
  Future<void> put(PhotoDraft draft) async {
    final dropped = await ref.read(draftsStoreProvider).save(draft);
    for (final d in dropped) {
      await _deletePhoto(d);
    }
    await reload();
  }

  /// Elimina el borrador y su foto local.
  Future<void> discard(String id) async {
    final draft = _find(id);
    await ref.read(draftsStoreProvider).remove(id);
    if (draft != null) await _deletePhoto(draft);
    await reload();
  }

  /// El usuario sigue a mano (o guardó la propuesta): el borrador sobra y no toca el diario.
  Future<void> completeManually(String id) => discard(id);

  /// Vuelve a enviar la foto del borrador.
  Future<void> retry(String id) async {
    final draft = _find(id);
    if (draft == null) return;
    await ref.read(pendingAnalysisProvider.notifier).retry(draft);
  }

  PhotoDraft? _find(String id) {
    for (final d in state.valueOrNull ?? const <PhotoDraft>[]) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> _deletePhoto(PhotoDraft draft) async {
    try {
      final file = File(draft.photoPath);
      if (await file.exists()) await file.delete();
    } on Object {
      // La foto puede haber desaparecido ya (caché del sistema): no es un error.
    }
  }
}
