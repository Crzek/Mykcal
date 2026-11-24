import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Edición de CIQUAL de la semilla (`backend/src/mykcal/foods/data/FUENTES.md`).
const ciqualEdition = '2025';
const ciqualUrl = 'https://ciqual.anses.fr';
const openFoodFactsUrl = 'https://world.openfoodfacts.org';

/// Fuentes de datos y su atribución (pantalla 6 de contracts/ui-flows.md, research R16).
/// Las direcciones son texto seleccionable: no se añade `url_launcher` solo para esto.
class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget section(String title, String body, String url) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 8),
          SelectableText(url),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSources)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            section(
              l10n.sourcesGenericTitle,
              l10n.sourcesGeneric(ciqualEdition),
              ciqualUrl,
            ),
            section(
              l10n.sourcesPackagedTitle,
              l10n.sourcesPackaged,
              openFoodFactsUrl,
            ),
          ],
        ),
      ),
    );
  }
}
