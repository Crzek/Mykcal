import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_errors.dart';
import '../../core/api/models.dart';
import '../../core/ui/connection_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../ai_key/ai_key_controller.dart';
import '../ai_key/ai_key_guide_screen.dart';
import '../foods/food_search_screen.dart';
import '../photo/analysis_chip.dart';
import '../photo/drafts_controller.dart';
import '../photo/draft_model.dart';
import '../photo/drafts_screen.dart';
import '../photo/failure_text.dart';
import '../photo/pending_analysis_notifier.dart';
import '../photo/photo_capture_screen.dart';
import '../photo/proposal_edit_screen.dart';
import '../quick/quick_tabs.dart';
import '../target/target_screen.dart';
import 'copy_meal_sheet.dart';
import 'entry_quantity_sheet.dart';
import 'meal_labels.dart';
import 'day_header.dart';
import 'diary_day_controller.dart';
import 'local_day.dart';
import 'selected_date.dart';
import 'meal_section.dart';
import 'summary_card.dart';
import 'summary_detail_sheet.dart';

/// Inicio: el diario del día con su resumen y las cinco comidas (FR-012).
///
/// [registeredAt] es el alta de la cuenta: el primer día que se puede ver (FR-010).
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key, this.registeredAt});

  final DateTime? registeredAt;

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(selectedDateProvider.notifier).resumed();
      // Aunque el día visible no cambie, «hoy» sí pudo cambiar: el título y «›» dependen de él.
      setState(() {});
    }
  }

  /// Día del alta en fecha local; sin ese dato no se limita por abajo.
  DateTime get _first {
    final registered = widget.registeredAt;
    return registered == null
        ? DateTime(2000)
        : LocalDay.dateOnly(registered.toLocal());
  }

  Future<void> _pick(DateTime date, DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: _first,
      lastDate: today,
    );
    if (picked != null && mounted) {
      ref.read(selectedDateProvider.notifier).goTo(picked, first: _first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = ref.watch(selectedDateProvider);
    final selected = ref.read(selectedDateProvider.notifier);
    final today = selected.today;
    final async = ref.watch(diaryDayControllerProvider(date));
    final aiKeyConfigured = ref.watch(aiKeyConfiguredProvider);
    final drafts = ref.watch(visibleDraftsProvider);
    ref.listen(analysisOutcomesProvider, (_, outcome) {
      if (outcome != null) _announce(outcome.draft);
    });
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DayHeader(
            date: date,
            today: today,
            first: _first,
            onPrevious: () => selected.previous(first: _first),
            onNext: () => selected.next(first: _first),
            onPick: () => _pick(date, today),
            onToday: selected.toToday,
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ConnectionErrorView(
              offline: error is NetworkFailure,
              onRetry: () => ref.invalidate(diaryDayControllerProvider(date)),
            ),
            data: (day) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!LocalDay.sameDay(date, today))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(l10n.dayPastNotice),
                  ),
                SummaryCard(
                  day: day,
                  onDetail: () => showSummaryDetail(context, day),
                  onTarget: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TargetScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (drafts.isNotEmpty)
                  Semantics(
                    label: l10n.draftsBadge('${drafts.length}'),
                    button: true,
                    excludeSemantics: true,
                    child: ListTile(
                      minTileHeight: 48,
                      leading: const Icon(Icons.photo_library_outlined),
                      title: Text(l10n.draftsBadge('${drafts.length}')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DraftsScreen(),
                        ),
                      ),
                    ),
                  ),
                for (final meal in day.meals)
                  MealSection(
                    meal: meal,
                    aiKeyConfigured: aiKeyConfigured,
                    onPhoto: () => _photo(context, date, meal.meal),
                    analysisChip: AnalysisChip(meal: meal.meal, date: date),
                    onAdd: () => _add(context, date, meal.meal),
                    onCopy: () =>
                        showCopyMealSheet(context, date: date, meal: meal.meal),
                    onTapEntry: (entry) => showEditEntrySheet(
                      context,
                      ref,
                      entry: entry,
                      date: date,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Cámara de una comida: con clave abre la captura; sin ella, la guía de la clave (FR-016).
  void _photo(BuildContext context, DateTime date, Meal meal) {
    final screen = ref.read(aiKeyConfiguredProvider)
        ? PhotoCaptureScreen(date: date, meal: meal)
        : const AiKeyGuideScreen();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// Aviso de que un análisis terminó, con la acción que corresponde a cada resultado.
  void _announce(PhotoDraft draft) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    void open(Widget screen) =>
        navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
    final String text;
    final String actionLabel;
    final VoidCallback action;
    if (draft.hasProposal) {
      text = l10n.snackReady;
      actionLabel = l10n.snackSeeProposal;
      action = () => open(ProposalEditScreen(draft: draft));
    } else {
      text = failureText(l10n, draft.failureCode);
      switch (draft.failureCode) {
        case 'key_invalid' || 'key_required':
          actionLabel = l10n.snackSettings;
          action = () => open(const AiKeyGuideScreen());
        case 'timeout' || 'no_connection' || 'provider_unavailable':
          actionLabel = l10n.draftsRetry;
          action = () =>
              ref.read(draftsControllerProvider.notifier).retry(draft.id);
        default:
          actionLabel = l10n.snackSeeDraft;
          action = () => open(const DraftsScreen());
      }
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(label: actionLabel, onPressed: action),
      ),
    );
  }

  /// «+» de una comida: búsqueda en modo selección → hoja de cantidad → de vuelta al diario.
  /// Con el campo vacío la búsqueda muestra Recientes y Favoritos (005).
  Future<void> _add(BuildContext context, DateTime date, Meal meal) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final home = ModalRoute.of(context);
    final name = mealName(meal, l10n);
    final tab = ValueNotifier<int>(0);

    /// Abre la hoja de cantidad; si se añadió, cierra la búsqueda y todo lo abierto desde ella
    /// (escáner, formulario) y avisa.
    Future<void> pick(
      BuildContext searchContext,
      Food food, {
      double? quantity,
      double? servings,
    }) async {
      final added = await showEntryQuantitySheet(
        searchContext,
        food: food,
        date: date,
        meal: meal,
        initialQuantity: quantity,
        initialServings: servings,
      );
      if (!added) return;
      navigator.popUntil((route) => route == home);
      messenger.showSnackBar(SnackBar(content: Text(l10n.entryAdded(name))));
    }

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (searchContext) => FoodSearchScreen(
          title: l10n.diaryAddToMeal(name),
          onSelected: (food) => pick(searchContext, food),
          emptyBuilder: (_) => QuickTabs(
            date: date,
            meal: meal,
            tabIndex: tab,
            onOpen: (item) => pick(
              searchContext,
              item.food,
              quantity: item.suggestedQuantity,
              servings: item.suggestedServings,
            ),
          ),
        ),
      ),
    );
    tab.dispose();
  }
}
