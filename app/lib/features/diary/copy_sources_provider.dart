import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';

/// Comida destino de una copia: el día visible y la comida cuyo menú se abrió.
typedef CopyTarget = ({DateTime date, Meal meal});

/// Días anteriores con comidas que copiar a [CopyTarget] (FR-005, research R7).
final copySourcesProvider = FutureProvider.autoDispose
    .family<List<CopySourceDay>, CopyTarget>(
      (ref, target) =>
          ref.watch(mykcalApiProvider).copySources(target.date, target.meal),
    );
