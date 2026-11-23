/// Paso pendiente del onboarding (`Me.onboarding`, research R10).
enum Onboarding {
  consent,
  profile,
  done;

  static Onboarding parse(Object? value) => switch (value) {
    'consent' => Onboarding.consent,
    'profile' => Onboarding.profile,
    _ => Onboarding.done,
  };
}

/// Respuesta de `GET /v1/me` y `POST /v1/registration` (contracts/openapi.yaml `Me`).
class Me {
  const Me({
    required this.id,
    required this.displayName,
    required this.isAdmin,
    required this.active,
    this.onboarding = Onboarding.done,
  });

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    isAdmin: json['is_admin'] as bool,
    active: json['status'] == 'active',
    onboarding: Onboarding.parse(json['onboarding']),
  );

  final String id;
  final String displayName;
  final bool isAdmin;
  final bool active;
  final Onboarding onboarding;
}

/// `InvitationStatus` del contrato.
class InvitationStatus {
  const InvitationStatus({
    required this.code,
    required this.activeAccounts,
    required this.maxAccounts,
    required this.freeSeats,
  });

  factory InvitationStatus.fromJson(Map<String, dynamic> json) =>
      InvitationStatus(
        code: json['code'] as String?,
        activeAccounts: json['active_accounts'] as int,
        maxAccounts: json['max_accounts'] as int,
        freeSeats: json['free_seats'] as int,
      );

  /// Sin guion; la pantalla lo muestra como `ABCD-EFGH`.
  final String? code;
  final int activeAccounts;
  final int maxAccounts;
  final int freeSeats;

  String? get displayCode {
    final c = code;
    if (c == null || c.length != 8) return c;
    return '${c.substring(0, 4)}-${c.substring(4)}';
  }
}

/// `Profile` del contrato (002): el peso es el del registro más reciente.
class Profile {
  const Profile({
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    age: json['age'] as int,
    sex: json['sex'] as String,
    heightCm: json['height_cm'] as int,
    weightKg: (json['weight_kg'] as num).toDouble(),
    activityLevel: json['activity_level'] as String,
    goal: json['goal'] as String,
  );

  final int age;
  final String sex;
  final int heightCm;
  final double weightKg;
  final String activityLevel;
  final String goal;
}

/// Cuerpo de `PUT /v1/profile`.
class ProfileInput {
  const ProfileInput({
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
    required this.measuredOn,
  });

  final int age;
  final String sex;
  final int heightCm;
  final double weightKg;
  final String activityLevel;
  final String goal;

  /// Fecha local del móvil, `yyyy-MM-dd` (research R6).
  final String measuredOn;

  Map<String, dynamic> toJson() => {
    'age': age,
    'sex': sex,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'activity_level': activityLevel,
    'goal': goal,
    'measured_on': measuredOn,
  };
}

/// Los 12 valores del objetivo diario (`TargetValues` del contrato).
class TargetValues {
  const TargetValues({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
    required this.potassiumMg,
    required this.calciumMg,
    required this.ironMg,
    required this.magnesiumMg,
    required this.vitaminDUg,
    required this.vitaminCMg,
  });

  factory TargetValues.fromJson(Map<String, dynamic> json) => TargetValues(
    kcal: json['kcal'] as int,
    proteinG: json['protein_g'] as int,
    carbsG: json['carbs_g'] as int,
    fatG: json['fat_g'] as int,
    fiberG: json['fiber_g'] as int,
    sodiumMg: json['sodium_mg'] as int,
    potassiumMg: json['potassium_mg'] as int,
    calciumMg: json['calcium_mg'] as int,
    ironMg: json['iron_mg'] as int,
    magnesiumMg: json['magnesium_mg'] as int,
    vitaminDUg: json['vitamin_d_ug'] as int,
    vitaminCMg: json['vitamin_c_mg'] as int,
  );

  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final int sodiumMg;
  final int potassiumMg;
  final int calciumMg;
  final int ironMg;
  final int magnesiumMg;
  final int vitaminDUg;
  final int vitaminCMg;

  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'fiber_g': fiberG,
    'sodium_mg': sodiumMg,
    'potassium_mg': potassiumMg,
    'calcium_mg': calciumMg,
    'iron_mg': ironMg,
    'magnesium_mg': magnesiumMg,
    'vitamin_d_ug': vitaminDUg,
    'vitamin_c_mg': vitaminCMg,
  };
}

/// Datos del último cálculo y avisos (`DailyTarget.calculation`).
class TargetCalculation {
  const TargetCalculation({required this.sex, required this.notices});

  factory TargetCalculation.fromJson(Map<String, dynamic> json) =>
      TargetCalculation(
        sex: json['sex'] as String,
        notices: (json['notices'] as List<dynamic>).cast<String>(),
      );

  final String sex;

  /// `MIN_KCAL_APPLIED` o `CARBS_CLAMPED`.
  final List<String> notices;
}

/// `DailyTarget` del contrato.
class DailyTarget {
  const DailyTarget({
    required this.values,
    required this.manual,
    required this.calculation,
  });

  factory DailyTarget.fromJson(Map<String, dynamic> json) => DailyTarget(
    values: TargetValues.fromJson(json['values'] as Map<String, dynamic>),
    manual: json['source'] == 'manual',
    calculation: TargetCalculation.fromJson(
      json['calculation'] as Map<String, dynamic>,
    ),
  );

  final TargetValues values;

  /// `true` si el objetivo se editó a mano (`source = manual`).
  final bool manual;
  final TargetCalculation calculation;
}

/// Resultado del recálculo tras guardar el perfil (`ProfileSaved.recalculation`).
enum RecalculationStatus {
  created,
  applied,
  proposed,
  none;

  static RecalculationStatus parse(Object? value) => switch (value) {
    'created' => RecalculationStatus.created,
    'applied' => RecalculationStatus.applied,
    'proposed' => RecalculationStatus.proposed,
    _ => RecalculationStatus.none,
  };
}

class ProfileSaved {
  const ProfileSaved({
    required this.profile,
    required this.target,
    required this.status,
    this.previous,
    this.proposed,
  });

  factory ProfileSaved.fromJson(Map<String, dynamic> json) {
    final recalculation = json['recalculation'] as Map<String, dynamic>;
    TargetValues? values(String key) => recalculation[key] == null
        ? null
        : TargetValues.fromJson(recalculation[key] as Map<String, dynamic>);
    return ProfileSaved(
      profile: Profile.fromJson(json['profile'] as Map<String, dynamic>),
      target: DailyTarget.fromJson(json['target'] as Map<String, dynamic>),
      status: RecalculationStatus.parse(recalculation['status']),
      previous: values('previous'),
      proposed: values('proposed'),
    );
  }

  final Profile profile;

  /// Objetivo vigente tras guardar.
  final DailyTarget target;
  final RecalculationStatus status;

  /// Solo con `applied`: valores anteriores.
  final TargetValues? previous;

  /// Solo con `proposed`: valores que saldrían; no se han guardado.
  final TargetValues? proposed;
}
