import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';

/// Nombre de una comida fija (FR-001).
String mealName(Meal meal, AppLocalizations l10n) => switch (meal) {
  Meal.breakfast => l10n.mealBreakfast,
  Meal.lunch => l10n.mealLunch,
  Meal.afternoonSnack => l10n.mealAfternoonSnack,
  Meal.dinner => l10n.mealDinner,
  Meal.snacks => l10n.mealSnacks,
};
