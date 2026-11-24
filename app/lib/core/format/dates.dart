/// Fecha `AAAA-MM-DD` de un día local (sin hora), como la espera el API del diario.
String isoDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
