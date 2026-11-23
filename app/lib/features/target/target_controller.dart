import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';

/// Objetivo vigente. Se invalida al guardar el perfil o el objetivo.
final targetProvider = FutureProvider.autoDispose<DailyTarget>(
  (ref) => ref.watch(mykcalApiProvider).target(),
);
