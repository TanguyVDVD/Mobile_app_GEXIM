import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../database/database.dart';
import '../../database/tables/enums.dart';
import '../../shared/widgets/plate.dart';
import '../../shared/widgets/sync_status_bar.dart';

/// Intitulés des listes, côté interface.
///
/// Volontairement ici et non sur [SettingKind] : l'enum est un contrat de
/// synchronisation partagé avec Postgres, et il n'a pas à porter le vocabulaire
/// d'un écran. Les libellés reprennent mot pour mot ceux imprimés sur le
/// formulaire du rapport — un administrateur doit pouvoir faire le lien sans
/// réfléchir entre la ligne qu'il voit sur une fiche et la liste qu'il modifie.
extension SettingKindLabel on SettingKind {
  String get titre => switch (this) {
        SettingKind.configuration => 'Configurations',
        SettingKind.configurationDetail => 'Configurations détaillées',
        SettingKind.eiLevel => 'Niveaux EI',
        SettingKind.supplier => 'Fournisseurs',
        SettingKind.productType => 'Types de produit',
        SettingKind.product => 'Produits',
        SettingKind.floor => 'Étages',
      };

  /// Intitulé du bouton d'ajout, accordé. Écrit en toutes lettres plutôt que
  /// composé à la volée : le genre ne se devine pas depuis le nom de la liste.
  String get nouveau => switch (this) {
        SettingKind.configuration => 'Nouvelle configuration',
        SettingKind.configurationDetail => 'Nouvelle configuration détaillée',
        SettingKind.eiLevel => 'Nouveau niveau EI',
        SettingKind.supplier => 'Nouveau fournisseur',
        SettingKind.productType => 'Nouveau type de produit',
        SettingKind.product => 'Nouveau produit',
        SettingKind.floor => 'Nouvel étage',
      };

  /// Où la liste apparaît sur la fiche — rien de plus : la note d'en-tête sert
  /// à faire le lien avec le document, pas à expliquer le métier.
  String get aide => switch (this) {
        SettingKind.configuration => 'Ligne « Configuration » de la fiche.',
        SettingKind.configurationDetail =>
          'Ligne « Configuration détaillée » de la fiche.',
        SettingKind.eiLevel => 'Ligne « Niveau EI » de la fiche.',
        SettingKind.supplier =>
          'Ligne « Fournisseur de produit utilisé » de la fiche.',
        SettingKind.productType =>
          'Ligne « Type de produit utilisé » de la fiche.',
        SettingKind.product =>
          'Lignes « Produit utilisé (1) » à « (5) » de la fiche.',
        SettingKind.floor => 'Ligne « Etage » de la fiche.',
      };
}

/// Administration des listes déroulantes de la fiche de traversée.
///
/// Réservé à l'administrateur — la garde vit dans `router.dart`, et le verrou
/// réel dans la policy RLS `setting_options_write`.
///
/// Les écritures passent par la file d'attente, comme les chantiers et les
/// clients : un administrateur en déplacement doit pouvoir ajouter un produit,
/// il partira tout seul.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Les produits n'ont pas d'onglet : ils se gèrent **depuis leur
  /// fournisseur**. Une liste à plat de tous les produits inviterait à en
  /// créer un sans dire de qui il est — et celui-là ne serait proposé sur
  /// aucune fiche.
  ///
  /// Dans l'ordre de la fiche : l'étage, qui est dans son bloc
  /// d'identification, passe avant les caractéristiques — bien qu'il soit le
  /// dernier arrivé dans l'enum.
  static const _onglets = [
    SettingKind.floor,
    SettingKind.configuration,
    SettingKind.configurationDetail,
    SettingKind.eiLevel,
    SettingKind.supplier,
    SettingKind.productType,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _onglets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Paramètres'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final kind in _onglets) Tab(text: kind.titre, height: 44),
            ],
          ),
        ),
        body: Column(
          children: [
            const SyncStatusBar(),
            Expanded(
              child: TabBarView(
                children: [
                  for (final kind in _onglets) _ListePage(kind: kind),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les produits d'un fournisseur — ou, sans [fournisseur], ceux qui n'en ont
/// aucun et attendent d'être rattachés.
///
/// Un écran poussé et non une route GoRouter : ce n'est pas une destination,
/// c'est le détail d'une ligne de `/parametres`, et « retour » doit y ramener.
class _ProduitsScreen extends StatelessWidget {
  const _ProduitsScreen({this.fournisseur});

  final SettingOption? fournisseur;

  @override
  Widget build(BuildContext context) {
    final fournisseur = this.fournisseur;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fournisseur == null
              ? 'Produits sans fournisseur'
              : 'Produits — ${fournisseur.label}',
        ),
      ),
      body: Column(
        children: [
          const SyncStatusBar(),
          Expanded(
            child: _ListePage(
              kind: SettingKind.product,
              fournisseur: fournisseur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une liste, et les gestes qui la modifient.
///
/// Pour [SettingKind.product], la liste est celle d'**un** [fournisseur] ;
/// sans lui, ce sont les produits restés sans fournisseur, qu'on ne peut que
/// rattacher, renommer ou retirer — pas en créer d'autres.
class _ListePage extends ConsumerWidget {
  const _ListePage({required this.kind, this.fournisseur});

  final SettingKind kind;
  final SettingOption? fournisseur;

  bool get _produits => kind == SettingKind.product;
  bool get _orphelins => _produits && fournisseur == null;

  String get _aide {
    final fournisseur = this.fournisseur;
    // Seule la liste des produits sans fournisseur garde une consigne : sans
    // elle, rien ne dit pourquoi ces produits sont là ni quoi en faire.
    if (_produits && fournisseur == null) {
      return 'Ces produits ne désignent aucun fournisseur : ils ne sont '
          'proposés sur aucune fiche. Rattachez chacun au sien.';
    }
    return kind.aide;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = _produits
        ? ref.watch(productsOfSupplierProvider(fournisseur?.id))
        : ref.watch(settingOptionsProvider(kind));

    // Sur l'onglet des fournisseurs, chaque ligne annonce son nombre de
    // produits, et l'en-tête signale ceux qui n'ont pas de fournisseur.
    final tousLesProduits = kind == SettingKind.supplier
        ? ref.watch(settingOptionsProvider(SettingKind.product)).valueOrNull ??
            const <SettingOption>[]
        : const <SettingOption>[];
    final parFournisseur = <String?, int>{};
    for (final produit in tousLesProduits) {
      parFournisseur.update(produit.parentId, (n) => n + 1, ifAbsent: () => 1);
    }
    final sansFournisseur = parFournisseur[null] ?? 0;

    return Scaffold(
      body: options.when(
        loading: () => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => EmptyState(
          title: 'Lecture impossible',
          body: '$e',
          icon: Icons.error_outline,
        ),
        data: (liste) => ReadableWidth(
          child: liste.isEmpty
              ? EmptyState(
                  title: _orphelins ? 'Tout est rattaché' : 'Liste vide',
                  body: _orphelins
                      ? 'Chaque produit désigne un fournisseur.'
                      : '$_aide\n\nAjoutez une première entrée : tant '
                          'que la liste est vide, le champ correspondant de '
                          'la fiche de traversée ne propose rien.',
                  icon: Icons.list_alt_outlined,
                )
              // `ReorderableListView` plutôt qu'une paire de flèches : l'ordre
              // des listes est un ordre métier (EI30 avant EI120, les produits
              // par fréquence d'emploi), et il se règle beaucoup plus vite au
              // doigt qu'en comptant des crans.
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.lg, Fs.lg, 96),
                  itemCount: liste.length,
                  // L'aide d'en-tête ne fait pas partie des éléments
                  // déplaçables : `header` est rendu hors de la zone de tri.
                  header: Padding(
                    padding: const EdgeInsets.only(bottom: Fs.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_aide, style: Fs.metaOf(context)),
                        if (sansFournisseur > 0) ...[
                          const SizedBox(height: Fs.md),
                          _SansFournisseurPlate(
                            nombre: sansFournisseur,
                            onTap: () => _ouvrirProduits(context, null),
                          ),
                        ],
                      ],
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final option = liste[index];
                    final estFournisseur = kind == SettingKind.supplier;
                    return Padding(
                      key: ValueKey(option.id),
                      padding: const EdgeInsets.only(bottom: Fs.sm),
                      child: _OptionPlate(
                        option: option,
                        rang: index,
                        detail: estFournisseur
                            ? _nombreDeProduits(parFournisseur[option.id] ?? 0)
                            : null,
                        // Un fournisseur s'ouvre sur ses produits ; le
                        // renommer passe alors par le crayon. Partout
                        // ailleurs, toucher la ligne la renomme.
                        onOuvrir: estFournisseur
                            ? () => _ouvrirProduits(context, option)
                            : null,
                        onRattacher: _produits
                            ? () => _rattacher(context, ref, option)
                            : null,
                        onRenommer: () => _renommer(context, ref, option),
                        onRetirer: () => _retirer(context, ref, option),
                      ),
                    );
                  },
                  // `onReorderItem` et non `onReorder`, déprécié : le second
                  // rendait un indice d'arrivée calculé **avant** le retrait de
                  // l'élément déplacé, qu'il fallait corriger à la main d'un
                  // cran vers le bas. Le premier le corrige déjà.
                  onReorderItem: (from, to) {
                    final ids = [for (final o in liste) o.id];
                    ids.insert(to, ids.removeAt(from));
                    // Toute la liste est réécrite, et non les deux lignes qui
                    // ont bougé : une seule transaction, un seul état final.
                    // Voir `SettingsDao.reorder`.
                    ref.read(settingsDaoProvider).reorder(kind, ids);
                  },
                ),
        ),
      ),
      // Pas d'ajout parmi les produits sans fournisseur : on n'en crée pas
      // d'autres, on vide cette liste.
      floatingActionButton: _orphelins
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _ajouter(context, ref),
              icon: const Icon(Icons.add, size: 24),
              label: Text(kind.nouveau),
            ),
    );
  }

  static String _nombreDeProduits(int n) => switch (n) {
        0 => 'Aucun produit',
        1 => '1 produit',
        _ => '$n produits',
      };

  void _ouvrirProduits(BuildContext context, SettingOption? fournisseur) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProduitsScreen(fournisseur: fournisseur),
      ),
    );
  }

  Future<void> _ajouter(BuildContext context, WidgetRef ref) async {
    final libelle = await _demanderLibelle(
      context,
      titre: kind.nouveau,
      initial: '',
    );
    if (libelle == null) return;
    await ref.read(settingsDaoProvider).create(
          kind: kind,
          label: libelle,
          supplierId: fournisseur?.id,
        );
  }

  /// Rattache un produit à un fournisseur, ou le change de fournisseur.
  Future<void> _rattacher(
    BuildContext context,
    WidgetRef ref,
    SettingOption produit,
  ) async {
    final dao = ref.read(settingsDaoProvider);
    // Une lecture ponctuelle, pas `watchKind(...).first` : voir « Un flux
    // vivant n'est pas une lecture ponctuelle » dans CLAUDE.md.
    final fournisseurs = [
      for (final f in await dao.ofKind(SettingKind.supplier))
        if (f.id != produit.parentId) f,
    ];
    if (!context.mounted) return;

    final choisi = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Fournisseur de « ${produit.label} »'),
        children: [
          if (fournisseurs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: Fs.sm),
              child: Text(
                'Aucun autre fournisseur. Créez-le d\'abord dans l\'onglet '
                'Fournisseurs.',
              ),
            ),
          for (final f in fournisseurs)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(f.id),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(f.label, style: const TextStyle(fontSize: 16.5)),
                ),
              ),
            ),
        ],
      ),
    );
    if (choisi == null) return;
    await dao.attach(produit.id, choisi);
  }

  Future<void> _renommer(
    BuildContext context,
    WidgetRef ref,
    SettingOption option,
  ) async {
    final libelle = await _demanderLibelle(
      context,
      titre: 'Renommer',
      initial: option.label,
      // Renommer, ce n'est pas remplacer : les traversées déjà relevées
      // pointent sur cette ligne, et leur caractéristique changera avec elle —
      // y compris sur un rapport régénéré. Corriger une faute de frappe, oui ;
      // recycler une entrée pour un autre produit, non.
      note: 'Les traversées déjà relevées porteront le nouveau libellé, y '
          'compris dans un export refait. Pour un autre produit, créez une '
          'entrée.',
    );
    if (libelle == null) return;
    await ref.read(settingsDaoProvider).rename(option.id, libelle);
  }

  Future<void> _retirer(
    BuildContext context,
    WidgetRef ref,
    SettingOption option,
  ) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retirer « ${option.label} » ?'),
        content: Text(
          'L\'entrée ne sera plus proposée à la saisie. Les traversées qui la '
          'désignent déjà la conservent, et leur fiche reste identique.'
          '${kind == SettingKind.supplier ? '\n\nSes produits ne seront plus '
              'proposés non plus.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (!(confirme ?? false)) return;
    await ref.read(settingsDaoProvider).retire(option.id);
  }
}

/// Saisie d'un libellé, avec refus du vide.
Future<String?> _demanderLibelle(
  BuildContext context, {
  required String titre,
  required String initial,
  String? note,
}) async {
  final saisi = await showDialog<String>(
    context: context,
    builder: (context) =>
        _LibelleDialog(titre: titre, initial: initial, note: note),
  );

  // Le vide est traité comme une annulation : un libellé vide ne se distingue
  // pas d'une ligne absente dans une liste déroulante, et la contrainte SQL le
  // refuserait de toute façon — mais bien plus tard, à la synchronisation.
  return (saisi == null || saisi.isEmpty) ? null : saisi;
}

/// La boîte de saisie, propriétaire de son contrôleur.
///
/// Un `State` et non un contrôleur créé puis libéré autour de `showDialog` :
/// le `Future` rend la main dès le `pop`, alors que la boîte joue encore son
/// animation de sortie — le `TextField` perd le focus, se reconstruit, et lit
/// un contrôleur déjà libéré (« A TextEditingController was used after being
/// disposed »). Libéré dans [dispose], il ne l'est qu'une fois la boîte
/// réellement retirée de l'arbre.
class _LibelleDialog extends StatefulWidget {
  const _LibelleDialog({
    required this.titre,
    required this.initial,
    this.note,
  });

  final String titre;
  final String initial;
  final String? note;

  @override
  State<_LibelleDialog> createState() => _LibelleDialogState();
}

class _LibelleDialogState extends State<_LibelleDialog> {
  late final TextEditingController _controleur;

  @override
  void initState() {
    super.initState();
    _controleur = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return AlertDialog(
      title: Text(widget.titre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controleur,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Libellé',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          if (note != null) ...[
            const SizedBox(height: Fs.sm),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controleur.text.trim()),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Signale, en tête des fournisseurs, les produits qui n'en désignent aucun.
///
/// N'apparaît que s'il y en a : c'est un reliquat du catalogue d'avant le
/// rattachement, pas une rubrique.
class _SansFournisseurPlate extends StatelessWidget {
  const _SansFournisseurPlate({required this.nombre, required this.onTap});

  final int nombre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Plate(
      padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.md, Fs.sm, Fs.md),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.link_off, size: 21, color: Fs.signal),
          const SizedBox(width: Fs.md),
          Expanded(
            child: Text(
              nombre == 1
                  ? '1 produit sans fournisseur — à rattacher'
                  : '$nombre produits sans fournisseur — à rattacher',
              style: const TextStyle(fontSize: 16.5, color: Fs.ink),
            ),
          ),
          const Icon(Icons.chevron_right, color: Fs.inkMuted),
        ],
      ),
    );
  }
}

class _OptionPlate extends StatelessWidget {
  const _OptionPlate({
    required this.option,
    required this.rang,
    required this.onRenommer,
    required this.onRetirer,
    this.detail,
    this.onOuvrir,
    this.onRattacher,
  });

  final SettingOption option;
  final int rang;
  final VoidCallback onRenommer;
  final VoidCallback onRetirer;

  /// Ligne secondaire, sous le libellé.
  final String? detail;

  /// Si fourni, toucher la ligne l'ouvre, et renommer passe par un bouton.
  final VoidCallback? onOuvrir;

  /// Si fourni, offre de changer le fournisseur du produit.
  final VoidCallback? onRattacher;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Plate(
      padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.sm, Fs.sm, Fs.sm),
      onTap: onOuvrir ?? onRenommer,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${rang + 1}', style: Fs.metaOf(context)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: const TextStyle(fontSize: 16.5, color: Fs.ink),
                ),
                if (detail != null) Text(detail, style: Fs.metaOf(context)),
              ],
            ),
          ),
          if (onOuvrir != null)
            IconButton(
              tooltip: 'Renommer',
              icon: const Icon(Icons.edit_outlined, size: 21),
              color: Fs.inkMuted,
              onPressed: onRenommer,
            ),
          if (onRattacher != null)
            IconButton(
              tooltip: 'Changer de fournisseur',
              icon: const Icon(Icons.swap_horiz, size: 21),
              color: Fs.inkMuted,
              onPressed: onRattacher,
            ),
          IconButton(
            tooltip: 'Retirer',
            icon: const Icon(Icons.delete_outline, size: 21),
            color: Fs.inkMuted,
            onPressed: onRetirer,
          ),
          ReorderableDragStartListener(
            index: rang,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: Fs.sm),
              child: Icon(Icons.drag_handle, size: 21, color: Fs.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
