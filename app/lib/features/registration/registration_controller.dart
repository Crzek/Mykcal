import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/auth/auth_controller.dart';

/// Borrador del código: vive fuera de la pantalla, así que se conserva sin conexión y al
/// caducar la sesión (FR-015, caso límite).
final registrationDraftProvider = StateProvider<String>((ref) => '');

enum RegistrationProblem {
  invalid,
  required,
  noSeats,
  tooManyAttempts,
  forbidden,
  offline,
  server,
}

class RegistrationState {
  const RegistrationState({this.busy = false, this.problem, this.retryAfter});

  final bool busy;
  final RegistrationProblem? problem;

  /// Instante hasta el que el botón queda desactivado (cuenta atrás).
  final DateTime? retryAfter;
}

class RegistrationController extends Notifier<RegistrationState> {
  @override
  RegistrationState build() => const RegistrationState();

  Future<void> submit() async {
    final code = ref.read(registrationDraftProvider);
    state = const RegistrationState(busy: true);
    try {
      await ref.read(authControllerProvider.notifier).register(code);
      state = const RegistrationState();
    } on ApiError catch (e) {
      state = switch (e.code) {
        'INVITATION_INVALID' => const RegistrationState(
          problem: RegistrationProblem.invalid,
        ),
        'INVITATION_REQUIRED' => const RegistrationState(
          problem: RegistrationProblem.required,
        ),
        'NO_SEATS' => const RegistrationState(
          problem: RegistrationProblem.noSeats,
        ),
        'TOO_MANY_ATTEMPTS' => RegistrationState(
          problem: RegistrationProblem.tooManyAttempts,
          retryAfter: ref
              .read(authClockProvider)()
              .add(Duration(seconds: e.retryAfterSeconds ?? 30)),
        ),
        _ => const RegistrationState(problem: RegistrationProblem.forbidden),
      };
    } on NetworkFailure {
      state = const RegistrationState(problem: RegistrationProblem.offline);
    } on SessionExpired {
      state = const RegistrationState();
      await ref.read(authControllerProvider.notifier).markExpired();
    } on ApiFailure {
      state = const RegistrationState(problem: RegistrationProblem.server);
    }
  }
}

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RegistrationState>(
      RegistrationController.new,
    );
