import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import 'registration_controller.dart';

/// Pantalla del código de invitación (contracts/ui-flows.md).
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  late final TextEditingController _field;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: ref.read(registrationDraftProvider));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _field.dispose();
    super.dispose();
  }

  String _formatWait(Duration d) {
    final seconds = d.inSeconds < 1 ? 1 : d.inSeconds;
    if (seconds < 60) return '$seconds s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return rest == 0 ? '$minutes min' : '$minutes min $rest s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reg = ref.watch(registrationControllerProvider);
    final now = ref.read(authClockProvider)();
    final waiting = reg.retryAfter != null && reg.retryAfter!.isAfter(now);
    final canSubmit = !reg.busy && !waiting;

    final message = switch (reg.problem) {
      RegistrationProblem.invalid => l10n.errInvitationInvalid,
      RegistrationProblem.required => l10n.errInvitationRequired,
      RegistrationProblem.noSeats => l10n.errNoSeats,
      RegistrationProblem.tooManyAttempts => waiting
          ? l10n.errTooManyAttempts(_formatWait(reg.retryAfter!.difference(now)))
          : null,
      RegistrationProblem.forbidden => l10n.errForbidden,
      RegistrationProblem.offline => l10n.offlineBanner,
      RegistrationProblem.server => l10n.errServer,
      null => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.codeTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.codeIntro, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(l10n.codeHelp),
              const SizedBox(height: 4),
              Text(l10n.codeAdminHint),
              const SizedBox(height: 24),
              TextField(
                controller: _field,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: l10n.codeLabel),
                onChanged: (value) {
                  ref.read(registrationDraftProvider.notifier).state = value;
                  setState(() {});
                },
                onSubmitted: (_) => canSubmit
                    ? ref.read(registrationControllerProvider.notifier).submit()
                    : null,
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: canSubmit
                    ? () => ref.read(registrationControllerProvider.notifier).submit()
                    : null,
                child: reg.busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.codeContinue),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
