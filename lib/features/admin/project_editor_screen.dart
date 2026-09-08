import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../database/database.dart';
import '../../database/tables/enums.dart';

/// Création ou pilotage d'un chantier. `projectId` nul ⇒ création.
class ProjectEditorScreen extends ConsumerStatefulWidget {
  const ProjectEditorScreen({this.projectId, super.key});

  final String? projectId;

  @override
  ConsumerState<ProjectEditorScreen> createState() =>
      _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends ConsumerState<ProjectEditorScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  String? _clientId;
  DateTime? _startedOn;
  bool _loaded = false;
  bool _busy = false;

  bool get _isNew => widget.projectId == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final clientId = _clientId;

    if (name.isEmpty || clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom et client sont obligatoires.')),
      );
      return;
    }

    setState(() => _busy = true);
    final dao = ref.read(projectDaoProvider);
    final description =
        _description.text.trim().isEmpty ? null : _description.text.trim();

    if (_isNew) {
      await dao.createProject(
        clientId: clientId,
        name: name,
        description: description,
        startedOn: _startedOn,
      );
    } else {
      await dao.updateProject(
        widget.projectId!,
        name: name,
        clientId: clientId,
        description: description,
        startedOn: _startedOn,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Clôture : gèle le chantier et ouvre la génération du rapport.
  ///
  /// Confirmation explicite parce que le geste est visible depuis toutes les
  /// tablettes : les opérateurs perdent instantanément le droit d'écrire, y
  /// compris au milieu d'une saisie. Ce n'est pas un réglage d'affichage, c'est
  /// une policy RLS côté serveur.
  Future<void> _close(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clôturer le chantier ?'),
        content: const Text(
          'Les opérateurs ne pourront plus ajouter ni modifier de traversée, '
          'sur cet appareil comme sur les leurs.\n\n'
          'Assurez-vous que tout le monde a synchronisé : un relevé encore sur '
          'une tablette sera refusé par le serveur après la clôture.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    await ref.read(projectDaoProvider).closeProject(project.id);

    // Le rapport s'enchaîne immédiatement : c'est le geste attendu après une
    // clôture, et le faire chercher dans un autre écran serait gratuit.
    if (mounted) unawaited(context.push('/projects/${project.id}/report'));
  }

  /// Suppression du chantier — logique, jamais physique.
  Future<void> _delete(Project project) async {
    // Lecture ponctuelle, et non `ref.read(...).valueOrNull ?? []` : un flux
    // pas encore émis aurait annoncé « 0 traversée » dans une boîte de dialogue
    // destructive, ce qui est exactement le moment où il ne faut pas se
    // tromper de chiffre.
    final points = await ref.read(pointDaoProvider).pointSummaries(project.id);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le chantier ?'),
        content: Text(
          points.isEmpty
              ? 'Le chantier disparaîtra des listes, sur cet appareil comme '
                  'sur ceux des techniciens affectés.'
              : 'Ce chantier contient ${points.length} traversée'
                  '${points.length > 1 ? 's' : ''} relevée'
                  '${points.length > 1 ? 's' : ''}. Elles disparaîtront avec '
                  'lui.\n\nSi le dossier a déjà été remis à un client, '
                  'clôturez plutôt que de supprimer : la clôture fige le '
                  'relevé en le laissant consultable.',
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
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    await ref.read(projectDaoProvider).deleteProject(project.id);
    // Retour à l'accueil : les deux écrans précédents — le relevé et cette
    // fiche — portent sur un chantier qui n'existe plus.
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
    final project = _isNew
        ? null
        : ref.watch(projectProvider(widget.projectId!)).valueOrNull;

    if (!_isNew && project != null && !_loaded) {
      _name.text = project.name;
      _description.text = project.description ?? '';
      _clientId = project.clientId;
      _startedOn = project.startedOn;
      _loaded = true;
    }

    final closed = project?.status == ProjectStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nouveau chantier' : 'Chantier'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Enregistrer'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom du chantier *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _clientId,
            decoration: const InputDecoration(
              labelText: 'Client *',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final client in clients)
                DropdownMenuItem(value: client.id, child: Text(client.name)),
            ],
            onChanged: (value) => setState(() => _clientId = value),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            title: const Text('Date de début'),
            subtitle: Text(
              _startedOn == null ? 'Non définie' : _formatDate(_startedOn!),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startedOn ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _startedOn = picked);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Caractéristiques',
              border: OutlineInputBorder(),
            ),
          ),

          if (project != null) ...[
            const SizedBox(height: 28),
            Text('Équipe affectée',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _MemberPicker(projectId: project.id),

            const SizedBox(height: 28),
            if (closed) ...[
              // Le PDF est une donnée dérivée : le régénérer à tout moment
              // donne le même document, il n'y a donc rien à archiver côté
              // appareil.
              FilledButton.icon(
                onPressed: () =>
                    context.push('/projects/${project.id}/report'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Rapport de conformité'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(projectDaoProvider).reopenProject(project.id),
                icon: const Icon(Icons.lock_open),
                label: const Text('Rouvrir le chantier'),
              ),
            ] else
              FilledButton.icon(
                onPressed: () => _close(project),
                icon: const Icon(Icons.lock),
                label: const Text('Clôturer et générer le rapport'),
              ),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: () => _delete(project),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer le chantier'),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Affectation des opérateurs.
///
/// C'est cette liste que lisent les policies RLS : elle décide de ce que chacun
/// peut voir et écrire, et borne aussi le volume descendu sur chaque tablette.
class _MemberPicker extends ConsumerWidget {
  const _MemberPicker({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operators = ref.watch(operatorsProvider).valueOrNull;
    final members = ref.watch(projectMembersProvider(projectId)).valueOrNull;

    if (operators == null || members == null) {
      return const LinearProgressIndicator();
    }
    if (operators.isEmpty) {
      return Text(
        'Aucun opérateur connu. Les comptes se créent dans Supabase ; leurs '
        'profils redescendent à la synchronisation suivante.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final assigned = {for (final m in members) m.userId};

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final operator in operators)
          FilterChip(
            label: Text(
              operator.fullName.isEmpty ? operator.email : operator.fullName,
            ),
            selected: assigned.contains(operator.id),
            onSelected: (on) {
              final next = {...assigned};
              if (on) {
                next.add(operator.id);
              } else {
                next.remove(operator.id);
              }
              ref.read(projectDaoProvider).setMembers(projectId, next);
            },
          ),
      ],
    );
  }
}
