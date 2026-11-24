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

// ---------------------------------------------------------------------------
// 003 — Base de alimentos (contracts/api-changes.md)
// ---------------------------------------------------------------------------

double? _optNum(Object? value) => (value as num?)?.toDouble();

/// Tipo de alimento: genérico (CIQUAL), envasado (Open Food Facts) o personalizado.
enum FoodKind {
  generic,
  packaged,
  custom;

  static FoodKind parse(Object? value) => switch (value) {
    'packaged' => FoodKind.packaged,
    'custom' => FoodKind.custom,
    _ => FoodKind.generic,
  };
}

/// Valores por 100 g o 100 ml. `null` es «sin dato» y no es lo mismo que 0 (FR-003).
class Nutrients {
  const Nutrients({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG,
    this.sodiumMg,
    this.potassiumMg,
    this.calciumMg,
    this.ironMg,
    this.magnesiumMg,
    this.vitaminDUg,
    this.vitaminCMg,
  });

  factory Nutrients.fromJson(Map<String, dynamic> json) => Nutrients(
    kcal: (json['kcal'] as num).toDouble(),
    proteinG: (json['protein_g'] as num).toDouble(),
    carbsG: (json['carbs_g'] as num).toDouble(),
    fatG: (json['fat_g'] as num).toDouble(),
    fiberG: _optNum(json['fiber_g']),
    sodiumMg: _optNum(json['sodium_mg']),
    potassiumMg: _optNum(json['potassium_mg']),
    calciumMg: _optNum(json['calcium_mg']),
    ironMg: _optNum(json['iron_mg']),
    magnesiumMg: _optNum(json['magnesium_mg']),
    vitaminDUg: _optNum(json['vitamin_d_ug']),
    vitaminCMg: _optNum(json['vitamin_c_mg']),
  );

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? fiberG;
  final double? sodiumMg;
  final double? potassiumMg;
  final double? calciumMg;
  final double? ironMg;
  final double? magnesiumMg;
  final double? vitaminDUg;
  final double? vitaminCMg;

  /// Fibra o algún micro sin dato.
  bool get hasMissing => [
    fiberG,
    sodiumMg,
    potassiumMg,
    calciumMg,
    ironMg,
    magnesiumMg,
    vitaminDUg,
    vitaminCMg,
  ].any((v) => v == null);

  /// Mismos nombres que el API; solo los valores con dato salvo los 4 obligatorios.
  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    if (fiberG != null) 'fiber_g': fiberG,
    if (sodiumMg != null) 'sodium_mg': sodiumMg,
    if (potassiumMg != null) 'potassium_mg': potassiumMg,
    if (calciumMg != null) 'calcium_mg': calciumMg,
    if (ironMg != null) 'iron_mg': ironMg,
    if (magnesiumMg != null) 'magnesium_mg': magnesiumMg,
    if (vitaminDUg != null) 'vitamin_d_ug': vitaminDUg,
    if (vitaminCMg != null) 'vitamin_c_mg': vitaminCMg,
  };
}

/// Fila de una lista de alimentos (`FoodSummary`).
class FoodSummary {
  const FoodSummary({
    required this.id,
    required this.kind,
    required this.name,
    required this.baseUnit,
    required this.kcal,
    required this.isMine,
    this.brand,
  });

  factory FoodSummary.fromJson(Map<String, dynamic> json) => FoodSummary(
    id: json['id'] as String,
    kind: FoodKind.parse(json['kind']),
    name: json['name'] as String,
    brand: json['brand'] as String?,
    baseUnit: json['base_unit'] as String,
    kcal: (json['kcal'] as num).toDouble(),
    isMine: json['is_mine'] as bool,
  );

  final String id;
  final FoodKind kind;
  final String name;
  final String? brand;

  /// `g` o `ml`.
  final String baseUnit;
  final double kcal;
  final bool isMine;
}

/// Detalle de un alimento (`Food`).
class Food {
  const Food({
    required this.id,
    required this.kind,
    required this.name,
    required this.baseUnit,
    required this.per100,
    required this.isMine,
    required this.source,
    this.brand,
    this.barcode,
    this.servingSize,
  });

  factory Food.fromJson(Map<String, dynamic> json) => Food(
    id: json['id'] as String,
    kind: FoodKind.parse(json['kind']),
    name: json['name'] as String,
    brand: json['brand'] as String?,
    barcode: json['barcode'] as String?,
    baseUnit: json['base_unit'] as String,
    per100: Nutrients.fromJson(json['per_100'] as Map<String, dynamic>),
    servingSize: _optNum(json['serving_size']),
    isMine: json['is_mine'] as bool,
    source: json['source'] as String,
  );

  final String id;
  final FoodKind kind;
  final String name;
  final String? brand;
  final String? barcode;
  final String baseUnit;
  final Nutrients per100;

  /// Ración del envase en `baseUnit` (FR-010).
  final double? servingSize;
  final bool isMine;

  /// `ciqual`, `off` o `user`.
  final String source;
}

enum BarcodeResult {
  found,
  notFound,
  incomplete;

  static BarcodeResult parse(Object? value) => switch (value) {
    'found' => BarcodeResult.found,
    'incomplete' => BarcodeResult.incomplete,
    _ => BarcodeResult.notFound,
  };
}

/// Respuesta de `GET /v1/foods/barcode`.
class BarcodeLookup {
  const BarcodeLookup({
    required this.result,
    required this.code,
    this.food,
    this.stale = false,
    this.productName,
    this.brand,
  });

  factory BarcodeLookup.fromJson(Map<String, dynamic> json) => BarcodeLookup(
    result: BarcodeResult.parse(json['result']),
    code: json['code'] as String,
    food: json['food'] == null
        ? null
        : Food.fromJson(json['food'] as Map<String, dynamic>),
    stale: json['stale'] == true,
    productName: json['product_name'] as String?,
    brand: json['brand'] as String?,
  );

  final BarcodeResult result;

  /// Código normalizado (UPC-A → EAN-13).
  final String code;
  final Food? food;

  /// Copia de más de 30 días porque Open Food Facts no respondió.
  final bool stale;

  /// Solo con `incomplete`: para precargar el formulario.
  final String? productName;
  final String? brand;
}

/// Cómo se interpretan los valores de un alimento personalizado.
enum FoodBasis {
  per100('per_100'),
  perServing('per_serving');

  const FoodBasis(this.wire);
  final String wire;
}

/// Cuerpo de `POST`/`PUT /v1/foods/custom`.
class CustomFoodInput {
  const CustomFoodInput({
    required this.name,
    required this.baseUnit,
    required this.basis,
    required this.values,
    this.brand,
    this.barcode,
    this.servingSize,
  });

  final String name;
  final String? brand;
  final String? barcode;

  /// `g` o `ml`.
  final String baseUnit;
  final FoodBasis basis;
  final double? servingSize;

  /// Por 100 o por ración, según [basis].
  final Nutrients values;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (brand != null) 'brand': brand,
    if (barcode != null) 'barcode': barcode,
    'base_unit': baseUnit,
    'basis': basis.wire,
    if (servingSize != null) 'serving_size': servingSize,
    'values': values.toJson(),
  };
}

/// Respuesta de crear o editar un alimento personalizado.
class CustomFoodSaved {
  const CustomFoodSaved({required this.food, required this.warnings});

  factory CustomFoodSaved.fromJson(Map<String, dynamic> json) =>
      CustomFoodSaved(
        food: Food.fromJson(json['food'] as Map<String, dynamic>),
        warnings: (json['warnings'] as List<dynamic>).cast<String>(),
      );

  final Food food;

  /// Solo `KCAL_MISMATCH`: avisa sin impedir guardar.
  final List<String> warnings;

  bool get kcalMismatch => warnings.contains('KCAL_MISMATCH');
}
