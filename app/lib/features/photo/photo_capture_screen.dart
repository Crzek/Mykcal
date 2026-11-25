import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../diary/meal_labels.dart';
import 'pending_analysis_notifier.dart';
import 'photo_picker.dart';

/// Captura rápida: foto, descripción opcional y «Analizar». Al enviar vuelve al diario sin esperar
/// la respuesta (`contracts/ui-flows.md` §4, research R8).
class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key, required this.date, required this.meal});

  final DateTime date;
  final Meal meal;

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  final _description = TextEditingController();
  final _grams = TextEditingController();
  String? _path;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _pick(PhotoSource.camera),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    _grams.dispose();
    super.dispose();
  }

  Future<void> _pick(PhotoSource source) async {
    try {
      final path = await ref.read(photoPickerProvider).pick(source);
      if (!mounted) return;
      setState(() {
        _denied = false;
        if (path != null) _path = path;
      });
    } on PhotoPermissionDenied {
      if (mounted) setState(() => _denied = true);
    }
  }

  void _analyze() {
    final path = _path;
    if (path == null) return;
    final grams = int.tryParse(_grams.text.trim());
    final description = _description.text.trim();
    // Sin esperar: el envío sigue en segundo plano y el diario lo muestra como «Analizando…».
    ref
        .read(pendingAnalysisProvider.notifier)
        .submit(
          photoPath: path,
          meal: widget.meal,
          date: widget.date,
          description: description.isEmpty ? null : description,
          totalGrams: grams != null && grams > 0 ? grams : null,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l10n.photoCaptureTitle} · ${mealName(widget.meal, l10n)}',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_denied) ...[
              Text(l10n.photoPermissionDenied),
              const SizedBox(height: 8),
            ],
            if (_path != null)
              Semantics(
                label: l10n.photoCaptureTitle,
                image: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_path!),
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 220,
                      child: Center(child: Icon(Icons.photo, size: 48)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.photoTake),
                  onPressed: () => _pick(PhotoSource.camera),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.photoFromGallery),
                  onPressed: () => _pick(PhotoSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l10n.photoDescriptionLabel,
                hintText: l10n.photoDescriptionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _grams,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.photoTotalGramsLabel,
                hintText: l10n.photoTotalGramsHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _path == null ? null : _analyze,
              child: Text(l10n.photoAnalyze),
            ),
          ],
        ),
      ),
    );
  }
}
