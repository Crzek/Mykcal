import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';

/// Clave de IA del usuario: `null` si no tiene (006). Nunca guarda el texto de la clave.
final aiKeyControllerProvider =
    AsyncNotifierProvider<AiKeyController, AiKeyStatus?>(AiKeyController.new);

/// `true` solo con una clave confirmada; mientras carga o si falla, la foto queda desactivada.
final aiKeyConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(aiKeyControllerProvider).valueOrNull != null,
);

class AiKeyController extends AsyncNotifier<AiKeyStatus?> {
  @override
  Future<AiKeyStatus?> build() => ref.watch(mykcalApiProvider).aiKey();

  /// Guarda o sustituye la clave. Si el servidor la rechaza, el estado no cambia y el error sube.
  Future<void> save(String rawKey) async {
    final status = await ref.read(mykcalApiProvider).saveAiKey(rawKey);
    state = AsyncData(status);
  }

  Future<void> delete() async {
    await ref.read(mykcalApiProvider).deleteAiKey();
    state = const AsyncData(null);
  }
}
