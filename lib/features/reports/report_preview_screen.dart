import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../sync/backoff.dart';
import 'report_exporter.dart';
import 'report_service.dart';

/// Génère puis présente le rapport d'un chantier.
///
/// La génération se fait à l'ouverture de l'écran, avec sa progression : sur un
/// gros chantier elle rapatrie et réduit plusieurs centaines de clichés, et un
/// écran figé sans explication ferait croire à un plantage.
class ReportPreviewScreen extends ConsumerStatefulWidget {
  const ReportPreviewScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ReportPreviewScreen> createState() =>
      _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends ConsumerState<ReportPreviewScreen> {
  Uint8List? _pdf;
  String? _error;
  ReportPhase _phase = ReportPhase.reading;
  int _done = 0;
  int _total = 0;
  bool _publishing = false;
  bool _exporting = false;

  /// Nom proposé au sélecteur d'emplacement.
  ///
  /// Daté, et le chantier nommé : un dossier client finit par contenir plusieurs
  /// révisions du même rapport, et « rapport.pdf » ne dit ni lequel ni quand.
  /// L'ordre année-mois-jour les range chronologiquement d'eux-mêmes.
  String _nomDeFichier(String projet) {
    final date = DateTime.now();
    final horodatage = '${date.year}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
    final nom = projet.trim().isEmpty ? 'chantier' : projet.trim();

    // Les caractères interdits par NTFS feraient échouer l'écriture, et le
    // sélecteur ne prévient pas toujours : un nom de chantier contient
    // volontiers « / » ou « : ».
    final propre = nom
        .replaceAll(RegExp(r'[\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), '-');

    return 'rapport-$propre-$horodatage.pdf';
  }

  Future<void> _export() async {
    final bytes = _pdf;
    if (bytes == null) return;

    final projet =
        ref.read(projectProvider(widget.projectId)).valueOrNull?.name ?? '';

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final resultat = await ref.read(reportExporterProvider).enregistrer(
            nomPropose: _nomDeFichier(projet),
            octets: bytes,
          );

      switch (resultat) {
        case ExportReussi(:final chemin):
          messenger.showSnackBar(
            SnackBar(
              content: Text('Rapport enregistré : $chemin'),
              duration: const Duration(seconds: 8),
            ),
          );
        case ExportAnnule():
          // Rien : une annulation volontaire n'a pas à produire de message.
          break;
        case ExportEchoue(:final raison):
          messenger.showSnackBar(
            SnackBar(
              content: Text('Enregistrement impossible : $raison'),
              duration: const Duration(seconds: 8),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = await ref.read(reportServiceProvider).build(
            widget.projectId,
            onProgress: (phase, done, total) {
              if (!mounted) return;
              setState(() {
                _phase = phase;
                _done = done;
                _total = total;
              });
            },
          );
      if (mounted) setState(() => _pdf = bytes);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _publish() async {
    final bytes = _pdf;
    if (bytes == null) return;

    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(reportServiceProvider).publish(widget.projectId, bytes);
      messenger.showSnackBar(
        const SnackBar(content: Text('Rapport déposé sur le serveur.')),
      );
    } on SyncException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.isTransient
                // Pas de file d'attente pour le PDF, et c'est voulu : il se
                // régénère à l'identique depuis les traversées.
                ? 'Dépôt impossible sans réseau. Le rapport reste consultable '
                    'et partageable ; relancez le dépôt une fois connecté.'
                : 'Dépôt refusé : ${e.message}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdf = _pdf;
    final exporter = ref.watch(reportExporterProvider);
    final projectName =
        ref.watch(projectProvider(widget.projectId)).valueOrNull?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Rapport — $projectName'),
        actions: [
          if (pdf != null)
            IconButton(
              tooltip: exporter.proposeUnEmplacement
                  ? 'Enregistrer sous…'
                  : 'Partager le rapport',
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      exporter.proposeUnEmplacement
                          ? Icons.save_alt
                          : Icons.ios_share,
                    ),
            ),
          if (pdf != null)
            IconButton(
              tooltip: 'Déposer sur le serveur',
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
            ),
        ],
      ),
      body: switch ((_error, pdf)) {
        (final String message, _) => _Failure(message, onRetry: () {
            setState(() {
              _error = null;
              _done = 0;
            });
            _generate();
          }),
        (_, null) => _Progress(phase: _phase, done: _done, total: _total),
        (_, final Uint8List bytes) => PdfPreview(
            build: (_) => bytes,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: 'rapport-${projectName.replaceAll(' ', '-')}.pdf',
          ),
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.phase,
    required this.done,
    required this.total,
  });

  final ReportPhase phase;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final counted = phase == ReportPhase.photos && total > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: counted ? done / total : null),
            const SizedBox(height: 20),
            // L'étape est nommée : une génération qui s'éternise doit dire où
            // elle est bloquée, sans quoi le diagnostic passe par le débogueur.
            Text(
              counted ? '${phase.label} : $done / $total' : '${phase.label}…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Les clichés pris par d\'autres appareils sont rapatriés au '
              'passage : la première génération peut être longue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure(this.message, {required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
