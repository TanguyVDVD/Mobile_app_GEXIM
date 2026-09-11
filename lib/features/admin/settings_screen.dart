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
/// réfléchir entre la ligne qu'il voit sur un PDF et la liste qu'il modifie.
extension SettingKindLabel on SettingKind {
  String get titre => switch (this) {
        SettingKind.configuration => 'Configurations',
        SettingKind.configurationDetail => 'Configurations détaillées',
        SettingKind.eiLevel => 'Niveaux EI',
        SettingKind.supplier => 'Fournisseurs',
        SettingKind.productType => 'Types de produit',
        SettingKind.product => 'Produits',
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
      };

  String get aide => switch (this) {
        SettingKind.configuration =>
          'Ligne « Configuration » de la fiche. Nature de la percée : '
              'traversée, percement ou ouverture linéaire, en paroi verticale '
              'ou horizontale.',
        SettingKind.configurationDetail =>
          'Ligne « Configuration détaillée ». Ce qui passe dans la percée, ou '
              'ce qu\'elle est quand rien n\'y passe.',
        SettingKind.eiLevel =>
          'Ligne « Niveau EI ». Degré coupe-feu exigé par le cahier des '
              'charges.',
        SettingKind.supplier =>
          'Ligne « Fournisseur de produit utilisé ». Fabricant des produits '
              'mis en œuvre.',
        SettingKind.productType =>
          'Ligne « Type de produit utilisé ». Nature de ce qui est posé : '
              'manchon, mortier, mousse, panneau… Un même type se décline chez '
              'plusieurs fournisseurs.',
        SettingKind.product =>
          'Lignes « Produit utilisé (1) » à « (5) ». Références commerciales '
              'posées sur la traversée.',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: SettingKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Paramètres'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final kind in SettingKind.values)
                Tab(text: kind.titre, height: 44),
            ],
          ),
        ),
        body: Column(
          children: [
            const SyncStatusBar(),
            Expanded(
              child: TabBarView(
                children: [
                  for (final kind in SettingKind.values) _ListePage(kind: kind),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une liste, et les gestes qui la modifient.
class _ListePage extends ConsumerWidget {
  const _ListePage({required this.kind});

  final SettingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(settingOptionsProvider(kind));

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
                  title: 'Liste vide',
                  body: '${kind.aide}\n\nAjoutez une première entrée : tant '
                      'que la liste est vide, le champ correspondant de la '
                      'fiche de traversée ne propose rien.',
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
                    child: Text(kind.aide, style: Fs.metaOf(context)),
                  ),
                  itemBuilder: (context, index) {
                    final option = liste[index];
                    return Padding(
                      key: ValueKey(option.id),
                      padding: const EdgeInsets.only(bottom: Fs.sm),
                      child: _OptionPlate(
                        option: option,
                        rang: index,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ajouter(context, ref),
        icon: const Icon(Icons.add, size: 24),
        label: Text(kind.nouveau),
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
    await ref.read(settingsDaoProvider).create(kind: kind, label: libelle);
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
          'compris sur un rapport régénéré. Pour un autre produit, créez une '
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
        content: const Text(
          'L\'entrée ne sera plus proposée à la saisie. Les traversées qui la '
          'désignent déjà la conservent, et leur rapport reste identique.',
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

class _OptionPlate extends StatelessWidget {
  const _OptionPlate({
    required this.option,
    required this.rang,
    required this.onRenommer,
    required this.onRetirer,
  });

  final SettingOption option;
  final int rang;
  final VoidCallback onRenommer;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    return Plate(
      padding: const EdgeInsets.fromLTRB(Fs.lg, Fs.sm, Fs.sm, Fs.sm),
      onTap: onRenommer,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${rang + 1}', style: Fs.metaOf(context)),
          ),
          Expanded(
            child: Text(
              option.label,
              style: const TextStyle(fontSize: 16.5, color: Fs.ink),
            ),
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
