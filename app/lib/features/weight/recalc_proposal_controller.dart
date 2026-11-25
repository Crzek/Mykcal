import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/mykcal_api.dart';
import '../diary/diary_day_controller.dart';
import '../target/recalc_dialogs.dart';
import '../target/target_controller.dart';
import 'recalc_proposal_dialog.dart';
import 'weight_controller.dart';

final recalcProposalControllerProvider = Provider<RecalcProposalController>(
  RecalcProposalController.new,
);

/// Consulta la propuesta de recálculo y gestiona la respuesta del usuario (US3, F3).
///
/// La propuesta vive en el servidor: cerrar el diálogo sin responder no llama a nada y la misma
/// propuesta vuelve a mostrarse la próxima vez (US3.7).
class RecalcProposalController {
  RecalcProposalController(this._ref);

  final Ref _ref;
  bool _checking = false;

  Future<void> check(BuildContext context) async {
    if (_checking) return;
    _checking = true;
    try {
      final api = _ref.read(mykcalApiProvider);
      final offset = weightUtcOffsetMin(_ref.read(diaryNowProvider)());
      final proposal = await api.recalcProposal(offset);
      if (!proposal.pending ||
          proposal.current == null ||
          proposal.proposed == null) {
        return;
      }
      if (!context.mounted) return;
      final choice = await showRecalcProposalDialog(context, proposal);
      if (choice == null) return;
      if (choice == RecalcChoice.ignore) {
        await _tolerant(() => api.ignoreRecalc(offset));
        return;
      }
      final target = await _tolerant(() => api.acceptRecalc(offset));
      if (target == null) return;
      _ref.invalidate(targetProvider);
      _ref.invalidate(diaryDayControllerProvider);
      if (context.mounted) {
        await showTargetUpdatedDialog(
          context,
          previous: proposal.current!,
          current: target.values,
        );
      }
    } on ApiFailure {
      // Sin red o fallo del servidor: la propuesta sigue pendiente y se verá más tarde.
    } finally {
      _checking = false;
    }
  }

  /// `RECALC_NO_PROPOSAL` significa «ya resuelta»: no es un error para el usuario.
  Future<T?> _tolerant<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiError catch (e) {
      if (e.code == 'RECALC_NO_PROPOSAL') return null;
      rethrow;
    }
  }
}
