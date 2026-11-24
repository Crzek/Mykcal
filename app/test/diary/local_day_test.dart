import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/diary/local_day.dart';

void main() {
  test('today y dateOnly quitan la hora', () {
    final now = DateTime(2026, 11, 24, 23, 59, 59);
    expect(LocalDay.today(now), DateTime(2026, 11, 24));
    expect(
      LocalDay.dateOnly(DateTime(2026, 1, 5, 7, 30)),
      DateTime(2026, 1, 5),
    );
  });

  test('isoDate da AAAA-MM-DD con ceros', () {
    expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
    expect(isoDate(DateTime(2026, 11, 24)), '2026-11-24');
  });

  test('sameDay, isBefore e isAfter comparan solo la fecha', () {
    final a = DateTime(2026, 11, 24, 23, 0);
    final b = DateTime(2026, 11, 24, 1, 0);
    expect(LocalDay.sameDay(a, b), isTrue);
    expect(LocalDay.isBefore(a, b), isFalse);
    expect(LocalDay.isAfter(a, b), isFalse);
    expect(LocalDay.isBefore(DateTime(2026, 11, 23, 23), b), isTrue);
    expect(LocalDay.isAfter(DateTime(2026, 11, 25, 0, 1), a), isTrue);
  });

  test('addDays cruza mes y año', () {
    expect(LocalDay.addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    expect(LocalDay.addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
  });

  test('utcOffsetMin usa la medianoche siguiente del móvil', () {
    final day = DateTime(2026, 11, 24);
    expect(
      LocalDay.utcOffsetMin(day),
      DateTime(2026, 11, 25).timeZoneOffset.inMinutes,
    );
  });

  test('utcOffsetMin con cambio de hora: pregunta por el final del día', () {
    // Zona simulada: +60 hasta el 29 de marzo de 2026 a las 00:00, +120 después (verano).
    int zone(DateTime localInstant) =>
        localInstant.isBefore(DateTime(2026, 3, 29)) ? 60 : 120;
    final asked = <DateTime>[];
    int spy(DateTime d) {
      asked.add(d);
      return zone(d);
    }

    // El 27 termina en +60. El 28 termina el 29 a las 00:00, que ya es verano: +120.
    expect(LocalDay.utcOffsetMin(DateTime(2026, 3, 27), offsetOf: spy), 60);
    expect(LocalDay.utcOffsetMin(DateTime(2026, 3, 28), offsetOf: spy), 120);
    expect(LocalDay.utcOffsetMin(DateTime(2026, 3, 29), offsetOf: spy), 120);
    expect(asked.first, DateTime(2026, 3, 28));
    expect(asked[1], DateTime(2026, 3, 29));
  });
}
