import 'dart:convert';

import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../sync/backoff.dart';
import '../../sync/remote_gateway.dart';

/// Enregistrement d'une mise en page de rapport.
///
/// **En ligne uniquement**, comme le changement de rôle et le dépôt d'un
/// rapport. Trois raisons :
///
///  * les fichiers du gabarit — papier à en-tête, logo — viennent d'être
///    déposés sur le serveur ; enregistrer les chemins hors ligne créerait une
///    ligne pointant vers des objets qui n'existent pas encore ;
///  * `report_templates` n'est pas dans la file d'attente : c'est une table
///    descendante, administrée depuis un bureau, pas depuis un chantier ;
///  * une mise en page mal enregistrée se corrige en la ré-enregistrant, alors
///    qu'un relevé perdu ne se retrouve pas.
class TemplateAdminService {
  const TemplateAdminService(this._db, this._gateway);

  final AppDatabase _db;
  final RemoteGateway _gateway;

  Future<void> save({
    required String id,
    required String clientId,
    required String name,
    required Map<String, Object?> config,
    String? letterheadCoverPath,
    String? letterheadBodyPath,
    String? logoPath,
  }) async {
    final now = DateTime.now();

    // Le serveur d'abord : si RLS refuse, rien ne doit apparaître localement.
    await _gateway.upsertTemplate({
      'id': id,
      'name': name,
      'config': config,
      'is_default': false,
      'letterhead_cover_path': letterheadCoverPath,
      'letterhead_body_path': letterheadBodyPath,
      'updated_at': now.toUtc().toIso8601String(),
    });

    await _gateway.attachTemplateToClient(
      clientId: clientId,
      templateId: id,
      logoPath: logoPath,
    );

    // Reflet local immédiat, pour que l'aperçu suive sans attendre la descente.
    await _db.transaction(() async {
      await _db.into(_db.reportTemplates).insertOnConflictUpdate(
            ReportTemplatesCompanion.insert(
              id: id,
              name: name,
              config: jsonEncode(config),
              letterheadCoverPath: Value(letterheadCoverPath),
              letterheadBodyPath: Value(letterheadBodyPath),
              updatedAt: now,
            ),
          );

      await (_db.update(_db.clients)..where((t) => t.id.equals(clientId)))
          .write(
        ClientsCompanion(
          templateId: Value(id),
          logoPath: Value(logoPath),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Gabarit appliqué à un client : le sien, sinon celui par défaut.
  Stream<ReportTemplate?> watchForClient(String clientId) {
    return _db
        .customSelect(
          '''
          SELECT t.* FROM report_templates t
            JOIN clients c ON c.template_id = t.id
           WHERE c.id = ?1
           UNION ALL
          SELECT t.* FROM report_templates t
           WHERE t.is_default = 1
             AND NOT EXISTS (SELECT 1 FROM clients
                              WHERE id = ?1 AND template_id IS NOT NULL)
           LIMIT 1
          ''',
          variables: [Variable<String>(clientId)],
          readsFrom: {_db.reportTemplates, _db.clients},
        )
        .watch()
        .map((rows) =>
            rows.isEmpty ? null : _db.reportTemplates.map(rows.first.data));
  }
}

/// Erreur d'enregistrement déjà formulée.
SyncException templateRefused(String message) =>
    SyncException(message, isTransient: false);
