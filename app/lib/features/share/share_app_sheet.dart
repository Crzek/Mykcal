import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/download_link.dart';
import '../../core/share/share_port.dart';
import '../../l10n/app_localizations.dart';

/// Abre la hoja «Compartir Mykcal» (contracts/ui-flows.md). No usa la red.
Future<void> showShareAppSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ShareAppSheet(),
  );
}

class ShareAppSheet extends ConsumerWidget {
  const ShareAppSheet({super.key});

  Future<void> _copy(BuildContext context, String link) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: link));
      message = l10n.shareCopied;
    } on PlatformException {
      message = l10n.shareCopyFailed;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final link = ref.watch(downloadLinkProvider);
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.shareTitle, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(l10n.shareIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            SelectableText(link, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _copy(context, link),
                    child: Text(l10n.shareCopy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        ref.read(sharePortProvider).share(l10n.shareText(link)),
                    child: Text(l10n.shareSend),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
