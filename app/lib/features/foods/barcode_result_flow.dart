import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/api/mykcal_api.dart';
import '../../l10n/app_localizations.dart';
import 'food_detail_screen.dart';

/// Abre el formulario de un personalizado con lo que se sabe del producto (lo conecta T065).
typedef CreateFromBarcode = void Function(
  String code,
  String? name,
  String? brand,
);

/// Consulta un código y muestra el resultado (pantalla 3 de contracts/ui-flows.md).
///
/// Termina cuando la persona ha visto el resultado y ha vuelto; así quien la llama puede volver
/// a encender la cámara. Mientras consulta muestra «Buscando producto…».
Future<void> lookupAndShowBarcode(
  BuildContext context,
  WidgetRef ref,
  String code, {
  CreateFromBarcode? onCreate,
  ValueChanged<Food>? onSelected,
}) async {
  while (true) {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final loading = _showLoading(context);
    BarcodeLookup? lookup;
    ApiFailure? failure;
    try {
      lookup = await ref.read(mykcalApiProvider).lookupBarcode(code);
    } on ApiFailure catch (e) {
      failure = e;
    } finally {
      if (navigator.mounted) navigator.pop(); // cierra el aviso de carga
      await loading;
    }
    if (!context.mounted) return;
    if (lookup != null) {
      await _showResult(context, lookup, onCreate, onSelected);
      return;
    }
    final retry = await _showFailure(context, failure!, code, onCreate);
    if (!retry) return;
  }
}

Future<void> _showLoading(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (ctx) {
    final l10n = AppLocalizations.of(ctx);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(l10n.scanLooking)),
            ],
          ),
        ),
      ),
    );
  },
);

Future<void> _showResult(
  BuildContext context,
  BarcodeLookup lookup,
  CreateFromBarcode? onCreate,
  ValueChanged<Food>? onSelected,
) async {
  final l10n = AppLocalizations.of(context);
  switch (lookup.result) {
    case BarcodeResult.found:
      final selected = onSelected;
      if (selected != null && lookup.food != null) {
        selected(lookup.food!);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              FoodDetailScreen(food: lookup.food, stale: lookup.stale),
        ),
      );
    case BarcodeResult.notFound:
      await _createSheet(
        context,
        message: l10n.scanNotFound,
        onCreate: onCreate == null
            ? null
            : () => onCreate(lookup.code, null, null),
      );
    case BarcodeResult.incomplete:
      final name = lookup.productName;
      await _createSheet(
        context,
        message: name == null
            ? l10n.scanIncompleteNoName
            : l10n.scanIncomplete(name),
        onCreate: onCreate == null
            ? null
            : () => onCreate(lookup.code, name, lookup.brand),
      );
  }
}

/// Devuelve `true` si hay que reintentar.
Future<bool> _showFailure(
  BuildContext context,
  ApiFailure failure,
  String code,
  CreateFromBarcode? onCreate,
) async {
  final l10n = AppLocalizations.of(context);
  final offline = failure is NetworkFailure;
  final retry = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                offline ? l10n.foodsOffline : l10n.scanSourceDown,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.retry),
            ),
            if (!offline && onCreate != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  onCreate(code, null, null);
                },
                child: Text(l10n.scanCreateFood),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  return retry ?? false;
}

Future<void> _createSheet(
  BuildContext context, {
  required String message,
  required VoidCallback? onCreate,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(message, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            if (onCreate != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onCreate();
                },
                child: Text(l10n.scanCreateWithCode),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
