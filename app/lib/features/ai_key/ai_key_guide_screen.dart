import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../l10n/app_localizations.dart';
import 'ai_key_controller.dart';

/// Guía para conseguir la clave de IA, pegarla y gestionarla (`contracts/ui-flows.md` §1).
///
/// Con [onboarding] es el paso opcional tras el alta: muestra «Omitir» y llama a [onDone] al
/// guardar o al omitir.
class AiKeyGuideScreen extends ConsumerStatefulWidget {
  const AiKeyGuideScreen({super.key, this.onboarding = false, this.onDone});

  final bool onboarding;
  final VoidCallback? onDone;

  @override
  ConsumerState<AiKeyGuideScreen> createState() => _AiKeyGuideScreenState();
}

class _AiKeyGuideScreenState extends ConsumerState<AiKeyGuideScreen> {
  final _text = TextEditingController();
  bool _saving = false;
  bool _replacing = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final raw = _text.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(aiKeyControllerProvider.notifier).save(raw);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.code == 'AI_KEY_INVALID'
            ? l10n.aiKeyInvalid
            : l10n.aiKeyUnavailable;
      });
      return;
    } on ApiFailure {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.aiKeyUnavailable;
      });
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.aiKeySaved)));
    if (!mounted) return;
    _text.clear();
    setState(() {
      _saving = false;
      _replacing = false;
    });
    widget.onDone?.call();
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiKeyRemoveTitle),
        content: Text(l10n.aiKeyRemoveBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.aiKeyRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(aiKeyControllerProvider.notifier).delete();
      messenger.showSnackBar(SnackBar(content: Text(l10n.aiKeyRemoved)));
    } on ApiFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(aiKeyControllerProvider);
    final configured = status.valueOrNull;
    final showField = configured == null || _replacing;
    final steps = [
      l10n.aiKeyStep1,
      l10n.aiKeyStep2,
      l10n.aiKeyStep3,
      l10n.aiKeyStep4,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiKeyTitle)),
      body: SafeArea(
        child: status.isLoading && configured == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (configured != null) ...[
                    Text(
                      l10n.aiKeyConfiguredOn(
                        DateFormat(
                          'd MMM y',
                          'es',
                        ).format(configured.configuredAt.toLocal()),
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.aiKeyProvider),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(l10n.aiKeyIntro),
                    const SizedBox(height: 16),
                  ],
                  if (showField) ...[
                    for (var i = 0; i < steps.length; i++)
                      Semantics(
                        label: l10n.aiKeyStepLabel('${i + 1}', steps[i]),
                        excludeSemantics: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('${i + 1}. ${steps[i]}'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _text,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: l10n.aiKeyFieldLabel,
                        hintText: l10n.aiKeyFieldHint,
                        errorText: _error,
                        errorMaxLines: 4,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.aiKeySave),
                    ),
                  ],
                  if (configured != null && !_replacing) ...[
                    OutlinedButton(
                      onPressed: () => setState(() => _replacing = true),
                      child: Text(l10n.aiKeyChange),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: _remove,
                      child: Text(l10n.aiKeyRemove),
                    ),
                  ],
                  if (widget.onboarding && configured == null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onDone,
                      child: Text(l10n.aiKeySkip),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
