import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../shared/widgets/plate.dart';
import 'report_exporter.dart';
import 'report_service.dart';

/// Génère le classeur Excel d'un chantier, puis le remet.
///
/// La génération se fait à l'ouverture de l'écran, avec sa progression : sur un
/// gros chantier elle rapatrie et réduit plusieurs centaines de clichés, et un
/// écran figé sans explication ferait croire à un plantage.
///
/// Il n'y a pas d'aperçu, et c'est voulu : un classeur se regarde dans Excel,
/// où il reste modifiable. L'écran dit donc ce que le fichier contient — et
/// surtout ce qui lui **manque** — avant de le laisser partir.
class ReportExportScreen extends ConsumerStatefulWidget {
  const ReportExportScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ReportExportScreen> createState() => _ReportExportScreenState();
}

class _ReportExportScreenState extends ConsumerState<ReportExportScreen> {
  ClasseurProduit? _classeur;
  String? _error;
  ReportPhase _phase = ReportPhase.reading;
  int _done = 0;
  int _total = 0;
  bool _exporting = false;

  /// Nom proposé au sélecteur d'emplacement.
  ///
  /// Daté, et le chantier nommé : un dossier client finit par contenir
  /// plusieurs révisions du même classeur, et « as-built.xlsm » ne dit ni
  /// lequel ni quand. L'ordre année-mois-jour les range chronologiquement
  /// d'eux-mêmes.
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

    return 'as-built-$propre-$horodatage.${ReportExporter.extension}';
  }

  Future<void> _export() async {
    final classeur = _classeur;
    if (classeur == null) return;

    final projet =
        ref.read(projectProvider(widget.projectId)).valueOrNull?.name ?? '';

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final resultat = await ref.read(reportExporterProvider).enregistrer(
            nomPropose: _nomDeFichier(projet),
            octets: classeur.octets,
          );

      switch (resultat) {
        case ExportReussi(:final chemin):
          messenger.showSnackBar(
            SnackBar(
              content: Text('Classeur enregistré : $chemin'),
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
      final classeur = await ref.read(reportServiceProvider).build(
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
      if (mounted) setState(() => _classeur = classeur);
    } on StateError catch (e) {
      // Le message est écrit pour être lu : un chantier sans traversée.
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _relancer() {
    setState(() {
      _error = null;
      _classeur = null;
      _done = 0;
    });
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    final classeur = _classeur;
    final projectName =
        ref.watch(projectProvider(widget.projectId)).valueOrNull?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('Export Excel — $projectName')),
      body: switch ((_error, classeur)) {
        (final String message, _) => _Failure(message, onRetry: _relancer),
        (_, null) => _Progress(phase: _phase, done: _done, total: _total),
        (_, final ClasseurProduit pret) => _Pret(
            classeur: pret,
            exporter: ref.watch(reportExporterProvider),
            enCours: _exporting,
            onExport: _export,
            onRelancer: _relancer,
          ),
      },
    );
  }
}

/// Le classeur est prêt : ce qu'il contient, et le geste pour le sortir.
class _Pret extends StatelessWidget {
  const _Pret({
    required this.classeur,
    required this.exporter,
    required this.enCours,
    required this.onExport,
    required this.onRelancer,
  });

  final ClasseurProduit classeur;
  final ReportExporter exporter;
  final bool enCours;
  final VoidCallback onExport;
  final VoidCallback onRelancer;

  @override
  Widget build(BuildContext context) {
    final fiches = classeur.fiches;
    final manquants = classeur.clichesManquants;
    final poids = classeur.octets.length / (1024 * 1024);

    return ReadableWidth(
      child: ListView(
        padding: const EdgeInsets.all(Fs.lg),
        children: [
          Plate(
            padding: const EdgeInsets.all(Fs.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fiches == 1 ? '1 fiche AS BUILT' : '$fiches fiches AS BUILT',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: Fs.sm),
                Text(
                  'Une feuille par traversée, dans le modèle du bureau — '
                  'macros et listes déroulantes comprises. '
                  '${poids.toStringAsFixed(poids < 10 ? 1 : 0)} Mo.',
                  style: Fs.metaOf(context),
                ),
              ],
            ),
          ),

          // Ce qui manque est dit ici, avant que le fichier ne parte : une
          // fiche de conformité sans sa photo ne se découvre pas chez le
          // client.
          if (manquants > 0) ...[
            const SizedBox(height: Fs.md),
            _Alerte(
              manquants == 1
                  ? '1 cliché n\'a pas pu être rapatrié : sa case est vide '
                      'dans le classeur.'
                  : '$manquants clichés n\'ont pas pu être rapatriés : leurs '
                      'cases sont vides dans le classeur.',
              'Ils ont été pris sur un autre appareil et cet appareil est '
                  'hors ligne, ou ils n\'ont pas encore été envoyés. '
                  'Régénérez une fois la synchronisation terminée.',
            ),
          ],
          if (classeur.sansLogo) ...[
            const SizedBox(height: Fs.md),
            const _Alerte(
              'Le logo du client n\'a pas pu être rapatrié.',
              'La case « Client » porte son nom à la place. Régénérez avec du '
                  'réseau pour l\'obtenir.',
            ),
          ],

          const SizedBox(height: Fs.xl),
          FilledButton.icon(
            onPressed: enCours ? null : onExport,
            icon: enCours
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
            label: Text(
              exporter.proposeUnEmplacement
                  ? 'Enregistrer sous…'
                  : 'Partager le classeur',
            ),
          ),
          const SizedBox(height: Fs.md),
          OutlinedButton.icon(
            onPressed: enCours ? null : onRelancer,
            icon: const Icon(Icons.refresh),
            label: const Text('Régénérer'),
          ),
        ],
      ),
    );
  }
}

class _Alerte extends StatelessWidget {
  const _Alerte(this.titre, this.detail);

  final String titre;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Plate(
      accent: true,
      padding: const EdgeInsets.all(Fs.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: Fs.signal),
          const SizedBox(width: Fs.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(fontSize: 16, color: Fs.ink)),
                const SizedBox(height: Fs.sm),
                Text(detail, style: Fs.metaOf(context)),
              ],
            ),
          ),
        ],
      ),
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
