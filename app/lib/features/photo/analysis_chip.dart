import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../diary/local_day.dart';
import '../../core/api/models.dart';
import 'draft_model.dart';
import 'drafts_controller.dart';
import 'drafts_screen.dart';
import 'pending_analysis_notifier.dart';
import 'proposal_edit_screen.dart';

/// «Analizando…», «Análisis listo ✓» o «Análisis fallido ✕» bajo la cabecera de una comida
/// (`contracts/ui-flows.md` §4). Es informativo: no bloquea ninguna otra acción.
class AnalysisChip extends ConsumerWidget {
  const AnalysisChip({super.key, required this.meal, required this.date});

  final Meal meal;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inFlight = ref.watch(pendingAnalysisProvider);
    final drafts = [
      for (final d
          in ref.watch(draftsControllerProvider).valueOrNull ??
              const <PhotoDraft>[])
        if (d.meal == meal && LocalDay.sameDay(d.entryDate, date)) d,
    ];
    if (drafts.isEmpty) return const SizedBox.shrink();
    final analyzing = drafts.any((d) => inFlight.contains(d.id));
    final ready = drafts.where((d) => d.hasProposal).toList();
    final String label;
    final Widget? leading;
    final VoidCallback? onTap;
    if (analyzing) {
      label = l10n.chipAnalyzing;
      leading = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      onTap = null;
    } else if (ready.isNotEmpty) {
      label = l10n.chipReady;
      leading = null;
      onTap = () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProposalEditScreen(draft: ready.last),
        ),
      );
    } else {
      label = l10n.chipFailed;
      leading = null;
      onTap = () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const DraftsScreen()));
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ActionChip(
          avatar: leading,
          label: Text(label),
          onPressed: onTap,
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}
