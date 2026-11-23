/// Aviso de macros incoherentes (FR-017, research R13).
///
/// `true` si la energía de los macros (`4·P + 4·C + 9·G`) difiere más de un 5% de las kcal.
/// Aritmética entera para que el 5% exacto no avise.
bool macroEnergyMismatch(int kcal, int proteinG, int carbsG, int fatG) {
  if (kcal <= 0) return false;
  final diff = (macroEnergy(proteinG, carbsG, fatG) - kcal).abs();
  return diff * 100 > kcal * 5;
}

int macroEnergy(int proteinG, int carbsG, int fatG) =>
    4 * proteinG + 4 * carbsG + 9 * fatG;
