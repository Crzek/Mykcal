import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format/numbers.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../target/recalc_dialogs.dart';
import '../target/target_controller.dart';
import '../target/target_screen.dart';
import 'profile_controller.dart';

/// Perfil (pantalla 2 de contracts/ui-flows.md), en onboarding y en edición desde Ajustes.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.onboarding});

  final bool onboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final Widget body;
    if (onboarding) {
      body = _ProfileForm(
        onboarding: true,
        initial: ref.read(profileDraftProvider),
      );
    } else {
      body = ref
          .watch(profileProvider)
          .when(
            data: (p) => _ProfileForm(
              onboarding: false,
              initial: ProfileDraft.fromProfile(p),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ConnectionErrorView(
              offline: error is NetworkFailure,
              onRetry: () => ref.invalidate(profileProvider),
            ),
          );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        automaticallyImplyLeading: !onboarding,
        actions: [
          if (onboarding)
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              child: Text(l10n.signOut),
            ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.onboarding, required this.initial});

  final bool onboarding;
  final ProfileDraft initial;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  String? _sex;
  String? _activity;
  String? _goal;
  bool _submitted = false;
  bool _busy = false;

  /// Campos que el servidor rechazó; se quitan al editarlos (research R14).
  final Set<String> _serverFields = {};

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _age = TextEditingController(text: d.age);
    _height = TextEditingController(text: d.height);
    _weight = TextEditingController(text: d.weight);
    _sex = d.sex;
    _activity = d.activity;
    _goal = d.goal;
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// En onboarding el borrador sobrevive a una reconstrucción de la pantalla.
  void _changed(String serverField) {
    _serverFields.remove(serverField);
    if (!widget.onboarding) return;
    ref
        .read(profileDraftProvider.notifier)
        .update(
          ProfileDraft(
            age: _age.text,
            height: _height.text,
            weight: _weight.text,
            sex: _sex,
            activity: _activity,
            goal: _goal,
          ),
        );
  }

  String? _problem(AppLocalizations l10n, FieldProblem? p, String rangeText) =>
      switch (p) {
        null => null,
        FieldProblem.required => l10n.errRequired,
        FieldProblem.range => rangeText,
      };

  String _todayLocal() {
    final d = ref.read(authClockProvider)().toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || _sex == null || _activity == null || _goal == null) return;
    setState(() => _busy = true);
    try {
      final saved = await ref
          .read(mykcalApiProvider)
          .saveProfile(
            ProfileInput(
              age: int.parse(_age.text.trim()),
              sex: _sex!,
              heightCm: int.parse(_height.text.trim()),
              weightKg: parseDecimal(_weight.text)!,
              activityLevel: _activity!,
              goal: _goal!,
              measuredOn: _todayLocal(),
            ),
          );
      ref.invalidate(targetProvider);
      ref.invalidate(profileProvider);
      if (!mounted) return;
      if (widget.onboarding) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => TargetScreen(result: saved.target),
          ),
        );
        return;
      }
      await _afterEdit(saved, navigator, messenger);
    } on ApiError catch (e) {
      if (e.code == 'VALIDATION_ERROR') {
        setState(() {
          _serverFields
            ..clear()
            ..addAll(e.fields);
        });
        _formKey.currentState!.validate();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
      }
    } on NetworkFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errOffline)));
    } on ApiFailure {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errServer)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _afterEdit(
    ProfileSaved saved,
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
  ) async {
    final l10n = AppLocalizations.of(context);
    switch (saved.status) {
      case RecalculationStatus.applied:
        await showTargetUpdatedDialog(
          context,
          previous: saved.previous!,
          current: saved.target.values,
        );
      case RecalculationStatus.proposed:
        final accept = await showRecalculationProposal(
          context,
          current: saved.target.values,
          proposed: saved.proposed!,
        );
        if (accept) {
          try {
            await ref.read(mykcalApiProvider).recalculateTarget();
            ref.invalidate(targetProvider);
          } on ApiFailure {
            messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
          }
        }
      case RecalculationStatus.created || RecalculationStatus.none:
        messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final errorStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );
    Widget selectionError(String? value) => _submitted && value == null
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(l10n.errRequired, style: errorStyle),
            ),
          )
        : const SizedBox.shrink();

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _age,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.profileAge,
              suffixText: l10n.unitYears,
            ),
            onChanged: (_) => _changed('age'),
            validator: (t) => _serverFields.contains('age')
                ? l10n.errAgeRange
                : _problem(l10n, validateAge(t ?? ''), l10n.errAgeRange),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(l10n.profileSex, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'male', label: Text(l10n.sexMale)),
              ButtonSegment(value: 'female', label: Text(l10n.sexFemale)),
            ],
            selected: {?_sex},
            onSelectionChanged: (s) {
              setState(() => _sex = s.isEmpty ? null : s.first);
              _changed('sex');
            },
          ),
          const SizedBox(height: 4),
          Text(l10n.profileSexHint, style: theme.textTheme.bodySmall),
          selectionError(_sex),
          const SizedBox(height: 20),
          TextFormField(
            controller: _height,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.profileHeight,
              suffixText: l10n.unitCm,
            ),
            onChanged: (_) => _changed('height_cm'),
            validator: (t) => _serverFields.contains('height_cm')
                ? l10n.errHeightRange
                : _problem(l10n, validateHeight(t ?? ''), l10n.errHeightRange),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.profileWeight,
              suffixText: l10n.unitKg,
            ),
            onChanged: (_) => _changed('weight_kg'),
            validator: (t) => _serverFields.contains('weight_kg')
                ? l10n.errWeightRange
                : _problem(l10n, validateWeight(t ?? ''), l10n.errWeightRange),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _activity,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.profileActivity),
            items: [
              DropdownMenuItem(
                value: 'sedentary',
                child: Text(l10n.activitySedentary),
              ),
              DropdownMenuItem(value: 'light', child: Text(l10n.activityLight)),
              DropdownMenuItem(
                value: 'moderate',
                child: Text(l10n.activityModerate),
              ),
              DropdownMenuItem(value: 'high', child: Text(l10n.activityHigh)),
              DropdownMenuItem(
                value: 'very_high',
                child: Text(l10n.activityVeryHigh),
              ),
            ],
            onChanged: (v) {
              setState(() => _activity = v);
              _changed('activity_level');
            },
            validator: (v) => v == null ? l10n.errRequired : null,
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(l10n.profileGoal, style: theme.textTheme.titleSmall),
          ),
          RadioGroup<String>(
            groupValue: _goal,
            onChanged: (v) {
              setState(() => _goal = v);
              _changed('goal');
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'lose_fat',
                  title: Text(l10n.goalLose),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'maintain',
                  title: Text(l10n.goalMaintain),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'gain_muscle',
                  title: Text(l10n.goalGain),
                ),
              ],
            ),
          ),
          selectionError(_goal),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(
              widget.onboarding ? l10n.profileCalculate : l10n.profileSave,
            ),
          ),
        ],
      ),
    );
  }
}
