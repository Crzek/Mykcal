import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../core/format/numbers.dart';

/// Borrador del formulario de perfil. Vive en memoria: si se cierra la app se vuelve a
/// escribir, así no quedan datos de salud en el móvil (research R10).
class ProfileDraft {
  const ProfileDraft({
    this.age = '',
    this.height = '',
    this.weight = '',
    this.sex,
    this.activity,
    this.goal,
  });

  factory ProfileDraft.fromProfile(Profile p) => ProfileDraft(
    age: '${p.age}',
    height: '${p.heightCm}',
    weight: formatWeight(p.weightKg),
    sex: p.sex,
    activity: p.activityLevel,
    goal: p.goal,
  );

  final String age;
  final String height;
  final String weight;
  final String? sex;
  final String? activity;
  final String? goal;
}

class ProfileDraftNotifier extends Notifier<ProfileDraft> {
  @override
  ProfileDraft build() => const ProfileDraft();

  void update(ProfileDraft draft) => state = draft;
}

final profileDraftProvider =
    NotifierProvider<ProfileDraftNotifier, ProfileDraft>(
      ProfileDraftNotifier.new,
    );

/// Perfil guardado, para la edición desde Ajustes.
final profileProvider = FutureProvider.autoDispose<Profile>(
  (ref) => ref.watch(mykcalApiProvider).profile(),
);

enum FieldProblem { required, range }

FieldProblem? _intInRange(String text, int min, int max) {
  final t = text.trim();
  if (t.isEmpty) return FieldProblem.required;
  final value = int.tryParse(t);
  if (value == null || value < min || value > max) return FieldProblem.range;
  return null;
}

/// Edad 18–100 (FR-004).
FieldProblem? validateAge(String text) => _intInRange(text, 18, 100);

/// Altura 100–250 cm (FR-004).
FieldProblem? validateHeight(String text) => _intInRange(text, 100, 250);

final _weightShape = RegExp(r'^\d{1,3}([.,]\d)?$');

/// Peso 30–300 kg con un decimal como máximo (FR-004).
FieldProblem? validateWeight(String text) {
  final t = text.trim();
  if (t.isEmpty) return FieldProblem.required;
  final value = parseDecimal(t);
  if (!_weightShape.hasMatch(t) || value == null || value < 30 || value > 300) {
    return FieldProblem.range;
  }
  return null;
}
