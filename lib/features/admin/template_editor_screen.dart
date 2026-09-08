import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firestop_report/firestop_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../database/database.dart';
import '../../shared/widgets/plate.dart';
import '../../sync/backoff.dart';

/// Mise en page du rapport d'un client : couleur, disposition, marges, et
/// papier à en-tête.
///
/// Le gabarit est stocké en JSON, mais personne ne le saisit à la main ici :
/// l'administrateur d'une entreprise de calfeutrement n'a pas à connaître la
/// syntaxe d'un objet JSON pour choisir une couleur.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({required this.clientId, super.key});

  final String clientId;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  final _name = TextEditingController();
  final _subtitle = TextEditingController();

  int _accent = 0xFFC8102E;
  PhotoLayout _layout = PhotoLayout.twoUp;
  bool _cover = true;
  bool _summary = true;
  bool _perPoint = true;
  double _marginTop = 17;
  double _marginBottom = 17;
  double _marginSide = 11;

  String? _templateId;
  String? _coverPath;
  String? _bodyPath;
  String? _logoPath;

  bool _loaded = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------

  void _load(Client client, ReportTemplate? template) {
    _logoPath = client.logoPath;
    _templateId = template?.id;
    _coverPath = template?.letterheadCoverPath;
    _bodyPath = template?.letterheadBodyPath;
    _name.text = template?.name ?? 'Rapport ${client.name}';

    final config = template == null
        ? TemplateConfig.fallback
        : _parse(template.config);

    _accent = config.brand.accentColor;
    _layout = config.pointCard.layout;
    _cover = config.cover.enabled;
    _summary = config.cover.showSummary;
    _perPoint = config.pointCard.pageBreakPerPoint;
    _subtitle.text = config.cover.subtitle;
    _marginTop = config.margins.top;
    _marginBottom = config.margins.bottom;
    _marginSide = config.margins.left;
    _loaded = true;
  }

  TemplateConfig _parse(String raw) {
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic>
          ? TemplateConfig.fromJson(json)
          : TemplateConfig.fallback;
    } on FormatException {
      return TemplateConfig.fallback;
    }
  }

  Map<String, Object?> _toJson() => {
        'version': 1,
        'brand': {
          'accentColor':
              '#${_accent.toRadixString(16).padLeft(8, '0').substring(2)}',
          'showLogo': true,
        },
        'cover': {
          'enabled': _cover,
          'showSummary': _summary,
          'subtitle': _subtitle.text.trim(),
        },
        'pointCard': {
          'layout': _layout.name,
          'pageBreak': _perPoint ? 'perPoint' : 'flow',
        },
        'margins': {
          'top': _marginTop,
          'bottom': _marginBottom,
          'left': _marginSide,
          'right': _marginSide,
        },
        'header': {'left': '{{client.name}}', 'right': '{{project.name}}'},
        'footer': {'center': 'Page {{page}}/{{pages}} - généré le {{date}}'},
      };

  // ---------------------------------------------------------------------------
  // Envois
  // ---------------------------------------------------------------------------

  /// Choisit un fichier et le dépose. Rend le chemin distant, ou `null`.
  Future<String?> _envoyer({
    required List<String> extensions,
    required String bucket,
    required String prefixe,
  }) async {
    final choix = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      // Indispensable : sur Android le fichier choisi vit derrière un
      // `content://`, sans chemin lisible. On récupère donc les octets.
      withData: true,
    );

    final fichier = choix?.files.firstOrNull;
    final octets = fichier?.bytes;
    if (octets == null) return null;

    final extension = (fichier!.extension ?? 'bin').toLowerCase();
    final chemin = '$prefixe/${newId()}.$extension';

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(letterheadServiceProvider).upload(
            remotePath: chemin,
            bytes: octets,
            contentType: switch (extension) {
              'pdf' => 'application/pdf',
              'png' => 'image/png',
              _ => 'image/jpeg',
            },
            bucket: bucket,
          );
      return chemin;
    } on SyncException catch (e) {
      if (mounted) {
        setState(() => _message = e.isTransient
            ? 'Envoi impossible sans réseau. Réessayez une fois connecté.'
            : 'Envoi refusé : ${e.message}');
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Client client) async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final id = _templateId ?? newId();
      await ref.read(templateAdminServiceProvider).save(
            id: id,
            clientId: client.id,
            name: _name.text.trim().isEmpty
                ? 'Rapport ${client.name}'
                : _name.text.trim(),
            config: _toJson(),
            letterheadCoverPath: _coverPath,
            letterheadBodyPath: _bodyPath,
            logoPath: _logoPath,
          );
      if (mounted) {
        setState(() {
          _templateId = id;
          _message = 'Mise en page enregistrée.';
        });
      }
    } on SyncException catch (e) {
      if (mounted) setState(() => _message = 'Échec : ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(clientProvider(widget.clientId)).valueOrNull;
    final template = ref.watch(templateForClientProvider(widget.clientId)).valueOrNull;

    if (client == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_loaded) _load(client, template);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mise en page du rapport'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _save(client),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Fs.lg),
        children: [
          if (_message != null) ...[
            Plate(
              accent: true,
              padding: const EdgeInsets.all(Fs.md),
              child: Text(_message!, style: Fs.metaOf(context)),
            ),
            const SizedBox(height: Fs.lg),
          ],

          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom de la mise en page'),
          ),
          const SizedBox(height: Fs.xl),

          const SectionHeading('Papier à en-tête'),
          Text(
            'Le rapport se compose par-dessus votre document type. Fournissez '
            'un PDF d\'une page, ou une image.',
            style: Fs.metaOf(context),
          ),
          const SizedBox(height: Fs.md),
          _FileRow(
            label: 'Page de garde',
            valeur: _coverPath,
            busy: _busy,
            onPick: () async {
              final chemin = await _envoyer(
                extensions: const ['pdf', 'png', 'jpg', 'jpeg'],
                bucket: 'letterheads',
                prefixe: 'cover',
              );
              if (chemin != null) setState(() => _coverPath = chemin);
            },
            onClear: () => setState(() => _coverPath = null),
          ),
          _FileRow(
            label: 'Pages suivantes',
            aide: 'Facultatif — la page de garde est reprise à défaut.',
            valeur: _bodyPath,
            busy: _busy,
            onPick: () async {
              final chemin = await _envoyer(
                extensions: const ['pdf', 'png', 'jpg', 'jpeg'],
                bucket: 'letterheads',
                prefixe: 'body',
              );
              if (chemin != null) setState(() => _bodyPath = chemin);
            },
            onClear: () => setState(() => _bodyPath = null),
          ),
          const SizedBox(height: Fs.xl),

          const SectionHeading('Logo du client'),
          _FileRow(
            label: 'Logo',
            aide: 'Affiché en tête de la page de garde.',
            valeur: _logoPath,
            busy: _busy,
            onPick: () async {
              final chemin = await _envoyer(
                extensions: const ['png', 'jpg', 'jpeg'],
                bucket: 'client-logos',
                prefixe: client.id,
              );
              if (chemin != null) setState(() => _logoPath = chemin);
            },
            onClear: () => setState(() => _logoPath = null),
          ),
          const SizedBox(height: Fs.xl),

          const SectionHeading('Marges'),
          Text(
            'À ajuster pour que le texte ne se pose pas sur votre en-tête '
            'imprimé.',
            style: Fs.metaOf(context),
          ),
          const SizedBox(height: Fs.sm),
          _MarginSlider(
            label: 'Haut',
            value: _marginTop,
            onChanged: (v) => setState(() => _marginTop = v),
          ),
          _MarginSlider(
            label: 'Bas',
            value: _marginBottom,
            onChanged: (v) => setState(() => _marginBottom = v),
          ),
          _MarginSlider(
            label: 'Côtés',
            value: _marginSide,
            onChanged: (v) => setState(() => _marginSide = v),
          ),
          const SizedBox(height: Fs.xl),

          const SectionHeading('Couleur d\'accentuation'),
          _ColorRow(
            selected: _accent,
            onSelected: (c) => setState(() => _accent = c),
          ),
          const SizedBox(height: Fs.xl),

          const SectionHeading('Disposition des clichés'),
          _LayoutPicker(
            selected: _layout,
            onSelected: (l) => setState(() => _layout = l),
          ),
          const SizedBox(height: Fs.xl),

          const SectionHeading('Contenu'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _cover,
            title: const Text('Page de garde'),
            onChanged: (v) => setState(() => _cover = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _summary,
            title: const Text('Tableau récapitulatif'),
            onChanged: (v) => setState(() => _summary = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _perPoint,
            title: const Text('Une traversée par page'),
            subtitle: const Text(
              'Exigé par la plupart des cahiers des charges : une fiche doit '
              'pouvoir être extraite seule.',
            ),
            onChanged: (v) => setState(() => _perPoint = v),
          ),
          if (_cover) ...[
            const SizedBox(height: Fs.md),
            TextField(
              controller: _subtitle,
              decoration: const InputDecoration(
                labelText: 'Sous-titre de la page de garde',
              ),
            ),
          ],
          const SizedBox(height: Fs.xxl),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.label,
    required this.valeur,
    required this.busy,
    required this.onPick,
    required this.onClear,
    this.aide,
  });

  final String label;
  final String? aide;
  final String? valeur;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final present = valeur != null && valeur!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: Fs.sm),
      child: Plate(
        padding: const EdgeInsets.all(Fs.md),
        onTap: busy ? null : onPick,
        child: Row(
          children: [
            Icon(
              present ? Icons.description : Icons.upload_file,
              size: 22,
              color: present ? Fs.ink : Fs.inkMuted,
            ),
            const SizedBox(width: Fs.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    present
                        ? valeur!.split('/').last
                        : aide ?? 'Toucher pour choisir un fichier',
                    style: Fs.metaOf(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (present)
              IconButton(
                tooltip: 'Retirer',
                icon: const Icon(Icons.close, size: 20),
                onPressed: busy ? null : onClear,
              ),
          ],
        ),
      ),
    );
  }
}

class _MarginSlider extends StatelessWidget {
  const _MarginSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: Fs.metaOf(context))),
        Expanded(
          child: Slider(
            value: value,
            max: 60,
            divisions: 60,
            label: '${value.round()} mm',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 54,
          child: Text('${value.round()} mm', style: Fs.metaOf(context)),
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  /// Palette volontairement courte. Un sélecteur de couleur libre inviterait à
  /// des teintes illisibles en noir et blanc — or un rapport de conformité
  /// finit souvent photocopié.
  static const _palette = <int, String>{
    0xFFC8102E: 'Rouge coupe-feu',
    0xFF0057B8: 'Bleu',
    0xFF2E7D32: 'Vert',
    0xFF37474F: 'Ardoise',
    0xFF6A1B9A: 'Violet',
    0xFFE65100: 'Orange',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Fs.sm,
      runSpacing: Fs.sm,
      children: [
        for (final entry in _palette.entries)
          InkWell(
            onTap: () => onSelected(entry.key),
            borderRadius: Fs.radius,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Color(entry.key),
                borderRadius: Fs.radius,
                border: Border.all(
                  color: entry.key == selected ? Fs.ink : Fs.hairline,
                  width: entry.key == selected ? 3 : 1,
                ),
              ),
              child: entry.key == selected
                  ? const Icon(Icons.check, color: Colors.white, size: 22)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _LayoutPicker extends StatelessWidget {
  const _LayoutPicker({required this.selected, required this.onSelected});

  final PhotoLayout selected;
  final ValueChanged<PhotoLayout> onSelected;

  static const _libelles = <PhotoLayout, (String, String)>{
    PhotoLayout.twoUp: ('Côte à côte', 'Avant et après alignés — la lecture par comparaison'),
    PhotoLayout.stacked: ('L\'un sous l\'autre', 'Pleine largeur, quand le détail prime'),
    PhotoLayout.grid: ('Grille 2×2', 'Les deux obligatoires plus deux complémentaires'),
    PhotoLayout.none: ('Sans cliché', 'Récapitulatif textuel seul'),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in _libelles.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Fs.sm),
            child: Plate(
              padding: const EdgeInsets.all(Fs.md),
              onTap: () => onSelected(entry.key),
              child: Row(
                children: [
                  Icon(
                    entry.key == selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: entry.key == selected ? Fs.signal : Fs.inkMuted,
                  ),
                  const SizedBox(width: Fs.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value.$1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(entry.value.$2, style: Fs.metaOf(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
