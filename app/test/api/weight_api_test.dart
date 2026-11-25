import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';

import 'api_client_test.dart' show StubAdapter, api, json;

Map<String, dynamic> targetValuesJson(int kcal) => {
  'kcal': kcal,
  'protein_g': 144,
  'carbs_g': 373,
  'fat_g': 77,
  'fiber_g': 30,
  'sodium_mg': 2000,
  'potassium_mg': 3500,
  'calcium_mg': 1000,
  'iron_mg': 8,
  'magnesium_mg': 400,
  'vitamin_d_ug': 15,
  'vitamin_c_mg': 90,
};

void main() {
  test('weightEntries lee la lista', () async {
    final adapter = StubAdapter(
      (_) => json(200, {
        'entries': [
          {
            'measured_on': '2026-11-22',
            'weight_kg': 78.4,
            'updated_at': '2026-11-22T08:00:00Z',
          },
        ],
      }),
    );
    final entries = await api(adapter).weightEntries();
    expect(adapter.requests.single.path, '/v1/weight');
    expect(entries.single.weightKg, 78.4);
    expect(entries.single.measuredOn, DateTime(2026, 11, 22));
  });

  test(
    'saveWeight, updateWeight y deleteWeight envían fecha y desfase',
    () async {
      final adapter = StubAdapter(
        (o) => o.method == 'DELETE'
            ? json(204, const {})
            : json(200, {
                'measured_on': '2026-11-22',
                'weight_kg': 78.4,
                'updated_at': '2026-11-22T08:00:00Z',
              }),
      );
      final client = api(adapter);
      await client.saveWeight(DateTime(2026, 11, 22), 78.4, 60);
      await client.updateWeight(DateTime(2026, 11, 22), 77.0, 60);
      await client.deleteWeight(DateTime(2026, 11, 22), 60);
      final [post, put, delete] = adapter.requests;
      expect((post.method, post.path), ('POST', '/v1/weight'));
      expect(post.data, {'measured_on': '2026-11-22', 'weight_kg': 78.4});
      expect(post.queryParameters, {'utc_offset_min': 60});
      expect((put.method, put.path), ('PUT', '/v1/weight/2026-11-22'));
      expect(put.data, {'weight_kg': 77});
      expect((delete.method, delete.path), ('DELETE', '/v1/weight/2026-11-22'));
      expect(delete.queryParameters, {'utc_offset_min': 60});
    },
  );

  test('weightChart lee puntos, media nula y resumen', () async {
    final adapter = StubAdapter(
      (_) => json(200, {
        'period': 'p30',
        'points': [
          {'date': '2026-11-20', 'weight_kg': 79.0, 'average_kg': null},
          {'date': '2026-11-22', 'weight_kg': 78.0, 'average_kg': 78.5},
        ],
        'summary': {
          'count': 2,
          'current_weight_kg': 78.0,
          'weekly_average_kg': null,
          'change_kg': -1.0,
        },
      }),
    );
    final chart = await api(adapter).weightChart('p30', 0);
    expect(adapter.requests.single.queryParameters, {
      'period': 'p30',
      'utc_offset_min': 0,
    });
    expect(chart.points.first.averageKg, isNull);
    expect(chart.points.last.averageKg, 78.5);
    expect(chart.summary.changeKg, -1.0);
    expect(chart.summary.weeklyAverageKg, isNull);
  });

  test('recalcProposal: pending con valores y none', () async {
    final pending = StubAdapter(
      (_) => json(200, {
        'status': 'pending',
        'reference_weight_kg': 80.0,
        'weekly_average_kg': 78.2,
        'was_manual': true,
        'large_change': false,
        'current': targetValuesJson(2759),
        'proposed': targetValuesJson(2700),
      }),
    );
    final proposal = await api(pending).recalcProposal(0);
    expect(proposal.pending, isTrue);
    expect(proposal.wasManual, isTrue);
    expect(proposal.current!.kcal, 2759);
    expect(proposal.proposed!.kcal, 2700);
    final none = await api(StubAdapter((_) => json(200, {'status': 'none'})))
        .recalcProposal(0);
    expect(none.pending, isFalse);
    expect(none.current, isNull);
  });

  test('acceptRecalc e ignoreRecalc usan POST', () async {
    final adapter = StubAdapter(
      (o) => o.path.endsWith('ignore')
          ? json(204, const {})
          : json(200, {
              'values': targetValuesJson(2700),
              'source': 'calculated',
              'effective_from': '2026-11-22T08:00:00Z',
              'calculation': {
                'weight_kg': 78.2,
                'age': 30,
                'sex': 'male',
                'height_cm': 180,
                'activity_level': 'moderate',
                'goal': 'maintain',
                'calculated_at': '2026-11-22T08:00:00Z',
                'notices': <String>[],
              },
            }),
    );
    final client = api(adapter);
    final target = await client.acceptRecalc(0);
    await client.ignoreRecalc(0);
    expect(target.values.kcal, 2700);
    expect(adapter.requests[0].path, '/v1/recalc-proposal/accept');
    expect(adapter.requests[1].path, '/v1/recalc-proposal/ignore');
  });

  test(
    'mapea VALIDATION_ERROR, WEIGHT_NOT_FOUND y RECALC_NO_PROPOSAL',
    () async {
      Future<ApiError> failWith(
        int status,
        String code,
        Future<Object?> Function(dynamic client) call, {
        List<String>? fields,
      }) async {
        final client = api(
          StubAdapter(
            (_) =>
                json(status, {'code': code, 'message': 'x', 'fields': ?fields}),
          ),
        );
        try {
          await call(client);
        } on ApiError catch (e) {
          return e;
        }
        throw StateError('no falló');
      }

      final validation = await failWith(
        400,
        'VALIDATION_ERROR',
        (c) => c.saveWeight(DateTime(2026, 11, 22), 5.0, 0),
        fields: ['weight_kg'],
      );
      expect(validation.fields, ['weight_kg']);
      final missing = await failWith(
        404,
        'WEIGHT_NOT_FOUND',
        (c) => c.deleteWeight(DateTime(2026, 11, 22), 0),
      );
      expect(missing.code, 'WEIGHT_NOT_FOUND');
      final none = await failWith(
        409,
        'RECALC_NO_PROPOSAL',
        (c) => c.acceptRecalc(0),
      );
      expect(none.status, 409);
    },
  );
}
