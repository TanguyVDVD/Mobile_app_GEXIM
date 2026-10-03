import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/plateforme.dart';
import '../../database/database.dart';
import '../../database/tables/enums.dart';

/// Vignette d'une photo, qu'elle soit sur l'appareil ou encore chez le serveur.
class PhotoThumbnail extends ConsumerStatefulWidget {
  const PhotoThumbnail({required this.photo, this.size = 96, super.key});

  final Photo photo;
  final double size;

  @override
  ConsumerState<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends ConsumerState<PhotoThumbnail> {
  /// Le futur est mémorisé, et non recréé à chaque `build`.
  ///
  /// Un `FutureBuilder` alimenté directement depuis `build` relance sa requête
  /// à chaque reconstruction — donc à chaque image d'un défilement. La vignette
  /// clignoterait, et un téléchargement serait relancé en boucle.
  late Future<ImageProvider?> _image;

  @override
  void initState() {
    super.initState();
    _image = _resolve();
  }

  @override
  void didUpdateWidget(PhotoThumbnail old) {
    super.didUpdateWidget(old);
    if (old.photo.id != widget.photo.id ||
        old.photo.localPath != widget.photo.localPath) {
      _image = _resolve();
    }
  }

  /// Sur tablette, le fichier du cliché — rapatrié au besoin. Dans un
  /// navigateur, qui n'a pas de disque, ses octets lus depuis le serveur.
  Future<ImageProvider?> _resolve() async {
    final depot = ref.read(photoRepositoryProvider);

    if (Plateforme.fichiersLocaux) {
      final File? fichier = await depot.fileFor(widget.photo);
      return fichier == null ? null : FileImage(fichier);
    }
    final octets = await depot.octetsDistants(widget.photo);
    return octets == null ? null : MemoryImage(octets);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: FutureBuilder<ImageProvider?>(
          future: _image,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _placeholder(
                scheme,
                const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final image = snapshot.data;
            if (image == null) {
              // Photo prise ailleurs, pas encore rapatriée, et pas de réseau
              // pour le faire maintenant.
              return _placeholder(
                scheme,
                Icon(Icons.cloud_off, color: scheme.outline),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Image(image: image, fit: BoxFit.cover),
                if (widget.photo.uploadState != PhotoUploadState.uploaded)
                  const Positioned(
                    right: 4,
                    bottom: 4,
                    child: _PendingBadge(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme, Widget child) =>
      ColoredBox(color: scheme.surfaceContainerHighest, child: child);
}

/// Marque une photo encore absente du serveur.
class _PendingBadge extends StatelessWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.cloud_upload, size: 12, color: Colors.white),
    );
  }
}
