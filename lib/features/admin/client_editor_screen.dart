import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../database/database.dart';
import '../../shared/widgets/plate.dart';
import '../../sync/backoff.dart';

/// Création ou modification d'un client.
///
/// `clientId` nul ⇒ création.
///
/// **L'adresse et le logo sont obligatoires à la création**, parce qu'ils
/// figurent l'un et l'autre en tête de chaque fiche du rapport. Le formulaire
/// AS BUILT leur réserve deux cases : les laisser vides produirait un document
/// contractuel amputé de l'identification de son destinataire.
///
/// Conséquence assumée : **créer un client demande du réseau.** Le logo est un
/// binaire distant ; on ne peut pas le rendre obligatoire et créer le client
/// hors ligne. Le reste de la console d'administration continue de fonctionner
/// sans réseau, mais pas ce geste-là.
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
  String? _message;

  /// Logo choisi mais pas encore déposé, à la création.
  ///
  /// Gardé en mémoire plutôt qu'envoyé tout de suite : le chemin distant est
  /// préfixé de l'identifiant du client, et cet identifiant n'est arrêté qu'au
  /// moment de l'enregistrement. Déposer avant laisserait un objet orphelin
  /// dans le bucket chaque fois qu'un admin change d'avis.
  Uint8List? _logoEnAttente;
  String? _logoNom;
  String? _logoExtension;

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

  void _refuser(String raison) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(raison)));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final address = _address.text.trim();

    if (name.isEmpty) return _refuser('Le nom du client est obligatoire.');
    if (address.isEmpty) {
      return _refuser(
        'L\'adresse est obligatoire : elle figure sur chaque fiche du rapport.',
      );
    }
    // Vérifié ici, avec les autres champs obligatoires, et non dans `_creer` :
    // un refus prononcé là-bas rendait la main normalement, et `_save`
    // fermait l'écran derrière le message — le client n'était pas créé, et
    // toute la saisie était perdue.
    if (_isNew && _logoEnAttente == null) {
      return _refuser('Le logo est obligatoire : il figure sur chaque fiche.');
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      if (_isNew) {
        await _creer(name: name, address: address);
      } else {
        await ref.read(projectDaoProvider).updateClient(
              widget.clientId!,
              name: name,
              contactName: _trimmedOrNull(_contactName),
              contactEmail: _trimmedOrNull(_contactEmail),
              contactPhone: _trimmedOrNull(_contactPhone),
              address: address,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } on SyncException catch (e) {
      if (mounted) {
        setState(
          () => _message = e.isTransient
              ? 'Envoi du logo impossible sans réseau. Un client se crée '
                  'depuis un poste connecté.'
              : 'Envoi refusé : ${e.message}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Dépose le logo, **puis** crée le client.
  ///
  /// Cet ordre est le même que pour les clichés de traversée, et pour la même
  /// raison : la base ne doit jamais référencer un objet absent du bucket. Si
  /// le dépôt échoue, aucun client n'est créé — mieux vaut refaire la saisie
  /// que se retrouver avec une fiche qui promet un logo introuvable, découvert
  /// à l'ouverture du rapport par le client.
  Future<void> _creer({required String name, required String address}) async {
    // Garanti par `_save`, qui refuse avant d'arriver ici.
    final octets = _logoEnAttente!;

    final id = newId();
    final chemin = '$id/${newId()}.${_logoExtension ?? 'png'}';

    await ref.read(remoteGatewayProvider).uploadAsset(
          remotePath: chemin,
          bytes: octets,
          contentType: _logoExtension == 'png' ? 'image/png' : 'image/jpeg',
          bucket: 'client-logos',
        );

    await ref.read(projectDaoProvider).createClient(
          id: id,
          name: name,
          address: address,
          logoPath: chemin,
          contactName: _trimmedOrNull(_contactName),
          contactEmail: _trimmedOrNull(_contactEmail),
          contactPhone: _trimmedOrNull(_contactPhone),
        );
  }

  /// Choisit un fichier de logo.
  ///
  /// À la création, les octets sont gardés en mémoire. Sur un client existant,
  /// l'identifiant est connu : le dépôt est immédiat, et le chemin part par la
  /// file d'attente comme le reste de la fiche.
  Future<void> _choisirLogo() async {
    final choix = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      // Indispensable : sur Android le fichier choisi vit derrière un
      // `content://`, sans chemin lisible. On récupère donc les octets.
      withData: true,
    );

    final fichier = choix?.files.firstOrNull;
    final octets = fichier?.bytes;
    if (octets == null) return;

    final extension = (fichier!.extension ?? 'png').toLowerCase();

    if (_isNew) {
      setState(() {
        _logoEnAttente = octets;
        _logoNom = fichier.name;
        _logoExtension = extension;
        _message = null;
      });
      return;
    }

    final chemin = '${widget.clientId}/${newId()}.$extension';

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(remoteGatewayProvider).uploadAsset(
            remotePath: chemin,
            bytes: octets,
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
            bucket: 'client-logos',
          );
      await ref.read(projectDaoProvider).setClientLogo(widget.clientId!, chemin);
    } on SyncException catch (e) {
      if (mounted) {
        setState(
          () => _message = e.isTransient
              ? 'Envoi impossible sans réseau. Le logo se dépose depuis un '
                  'poste connecté.'
              : 'Envoi refusé : ${e.message}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Client? client;
    if (!_isNew) {
      client = ref.watch(clientProvider(widget.clientId!)).valueOrNull;
      if (client != null && !_loaded) {
        _name.text = client.name;
        _contactName.text = client.contactName ?? '';
        _contactEmail.text = client.contactEmail ?? '';
        _contactPhone.text = client.contactPhone ?? '';
        _address.text = client.address;
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
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(Fs.lg),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nom du client *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Fs.md),
            TextField(
              controller: _address,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Adresse *',
                helperText: 'Reportée en tête de chaque fiche du rapport.',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: Fs.xl),
            const SectionHeading('Logo *'),
            _Logo(
              cheminDistant: client?.logoPath,
              nomEnAttente: _logoNom,
              busy: _busy,
              onChoisir: _choisirLogo,
            ),
            if (_message case final String message) ...[
              const SizedBox(height: Fs.sm),
              Text(
                message,
                style: const TextStyle(fontSize: 14, color: Fs.signal),
              ),
            ],

            const SizedBox(height: Fs.xl),
            const SectionHeading('Contact'),
            TextField(
              controller: _contactName,
              decoration: const InputDecoration(
                labelText: 'Personne de contact',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Fs.md),
            TextField(
              controller: _contactEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Courriel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Fs.md),
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// État du logo, et le geste qui le change.
///
/// Trois états, et le premier doit se voir : **manquant**. Le logo est une
/// donnée obligatoire ; un champ vide et silencieux se confondrait avec un
/// champ facultatif qu'on a choisi de laisser tel quel.
class _Logo extends StatelessWidget {
  const _Logo({
    required this.cheminDistant,
    required this.nomEnAttente,
    required this.busy,
    required this.onChoisir,
  });

  /// Logo déjà déposé, sur un client existant.
  final String? cheminDistant;

  /// Fichier choisi mais pas encore déposé, à la création.
  final String? nomEnAttente;

  final bool busy;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final present = nomEnAttente ?? cheminDistant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Plate(
          accent: present == null,
          padding: const EdgeInsets.all(Fs.md),
          child: Row(
            children: [
              Icon(
                present == null
                    ? Icons.warning_amber_outlined
                    : Icons.image_outlined,
                size: 21,
                color: present == null ? Fs.signal : Fs.inkMuted,
              ),
              const SizedBox(width: Fs.md),
              Expanded(
                child: Text(
                  present ??
                      'Aucun logo. Il figure sur chaque fiche du rapport : '
                          'un client ne se crée pas sans.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: present == null
                      ? const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: Fs.signal,
                          fontWeight: FontWeight.w600,
                        )
                      : Fs.metaOf(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Fs.md),
        OutlinedButton.icon(
          onPressed: busy ? null : onChoisir,
          icon: const Icon(Icons.upload_file, size: 20),
          label: Text(present == null ? 'Choisir un logo' : 'Remplacer'),
        ),
        const SizedBox(height: Fs.sm),
        Text(
          'PNG ou JPEG. Le dépôt du fichier demande une connexion — '
          'contrairement au reste de cette fiche, qui part avec la file de '
          'synchronisation.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
