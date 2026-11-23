import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/auth/auth_controller.dart';

class InvitationsController extends AutoDisposeAsyncNotifier<InvitationStatus> {
  @override
  Future<InvitationStatus> build() => _guard(() => ref.read(mykcalApiProvider).invitation());

  Future<void> rotate() async {
    state = const AsyncLoading<InvitationStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => _guard(() => ref.read(mykcalApiProvider).rotateInvitation()),
    );
  }

  Future<InvitationStatus> _guard(Future<InvitationStatus> Function() call) async {
    try {
      return await call();
    } on SessionExpired {
      await ref.read(authControllerProvider.notifier).markExpired();
      rethrow;
    }
  }
}

final invitationsControllerProvider =
    AsyncNotifierProvider.autoDispose<InvitationsController, InvitationStatus>(
        InvitationsController.new);
