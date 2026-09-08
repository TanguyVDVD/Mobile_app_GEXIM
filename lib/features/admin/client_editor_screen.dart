import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';

/// Création ou modification d'un client.
///
/// `clientId` nul ⇒ création.
class ClientEditorScreen extends ConsumerStatefulWidget {
  const ClientEditorScreen({this.clientId, super.key});

  final String? clientId;

  @override
  ConsumerState<ClientEditorScreen> createState() => _ClientEditorScreenState();
}

class _ClientEditorScreenState extends ConsumerState<ClientEditorScreen> {
  final _name = TextEditingController();
  final _contactName = TextEditingController();
  final _contactEmail = TextEditingController();
  final _contactPhone = TextEditingController();
  final _address = TextEditingController();

  bool _loaded = false;
  bool _busy = false;

  bool get _isNew => widget.clientId == null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _contactName,
      _contactEmail,
      _contactPhone,
      _address,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du client est obligatoire.')),
      );
      return;
    }

    setState(() => _busy = true);
    final dao = ref.read(projectDaoProvider);

    if (_isNew) {
      await dao.createClient(
        name: name,
        contactName: _trimmedOrNull(_contactName),
        contactEmail: _trimmedOrNull(_contactEmail),
        contactPhone: _trimmedOrNull(_contactPhone),
        address: _trimmedOrNull(_address),
      );
    } else {
      await dao.updateClient(
        widget.clientId!,
        name: name,
        contactName: _trimmedOrNull(_contactName),
        contactEmail: _trimmedOrNull(_contactEmail),
        contactPhone: _trimmedOrNull(_contactPhone),
        address: _trimmedOrNull(_address),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNew && !_loaded) {
      final client = ref.watch(clientProvider(widget.clientId!)).valueOrNull;
      if (client != null) {
        _name.text = client.name;
        _contactName.text = client.contactName ?? '';
        _contactEmail.text = client.contactEmail ?? '';
        _contactPhone.text = client.contactPhone ?? '';
        _address.text = client.address ?? '';
        _loaded = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nouveau client' : 'Client'),
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
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom du client *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactName,
            decoration: const InputDecoration(
              labelText: 'Personne de contact',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Courriel',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Adresse',
              border: OutlineInputBorder(),
            ),
          ),
          if (!_isNew) ...[
            const SizedBox(height: 28),
            OutlinedButton.icon(
              // Uniquement sur un client existant : la mise en page se rattache
              // à un identifiant, qui n'existe pas encore à la création.
              onPressed: () =>
                  context.push('/clients/${widget.clientId}/template'),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              label: const Text('Mise en page du rapport'),
            ),
            const SizedBox(height: 8),
            Text(
              'Papier à en-tête, logo, couleurs et marges du rapport PDF remis '
              'à ce client.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
