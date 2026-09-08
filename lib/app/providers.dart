import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/daos/point_dao.dart';
import '../database/daos/project_dao.dart';
import '../database/database.dart';
import '../database/tables/enums.dart';
import '../features/admin/template_admin_service.dart';
import '../features/admin/user_admin_service.dart';
import '../features/auth/auth_backend.dart';
import '../features/auth/auth_service.dart';
import '../features/capture/image_compressor.dart';
import '../features/capture/photo_capture_service.dart';
import '../features/capture/photo_repository.dart';
import '../features/capture/photo_storage.dart';
import '../features/capture/reduction_jpeg.dart';
import '../features/reports/letterhead_service.dart';
import '../features/reports/report_exporter.dart';
import '../features/reports/report_service.dart';
import '../sync/remote_gateway.dart';
import '../sync/sync_engine.dart';

/// Câblage de l'injection.
///
/// Riverpod « à la main », sans `riverpod_generator` : `drift_dev` impose déjà
/// une passe de `build_runner`, et une poignée de providers explicites reste
/// plus lisible qu'une seconde couche de génération.

// -----------------------------------------------------------------------------
// Socle
// -----------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final projectDaoProvider =
    Provider<ProjectDao>((ref) => ref.watch(databaseProvider).projectDao);

final pointDaoProvider =
    Provider<PointDao>((ref) => ref.watch(databaseProvider).pointDao);

// -----------------------------------------------------------------------------
// Capture
// -----------------------------------------------------------------------------

final photoStorageProvider = Provider<PhotoStorage>((ref) => const PhotoStorage());

/// Interface et non implémentation : les tests substituent un double, la
/// compression réelle passant par un plugin natif indisponible hors appareil.
final photoProcessorProvider = Provider<PhotoProcessor>(
  (ref) => ImageCompressor(
    ref.watch(photoStorageProvider),
    ref.watch(reductionJpegProvider),
  ),
);

final photoCaptureServiceProvider = Provider<PhotoCaptureService>(
  (ref) => PhotoCaptureService(
    dao: ref.watch(pointDaoProvider),
    processor: ref.watch(photoProcessorProvider),
  ),
);

final templateAdminServiceProvider = Provider<TemplateAdminService>(
  (ref) => TemplateAdminService(
    ref.watch(databaseProvider),
    ref.watch(remoteGatewayProvider),
  ),
);

/// Gabarit appliqué à un client : le sien, sinon celui par défaut.
final templateForClientProvider =
    StreamProvider.family<ReportTemplate?, String>(
  (ref, clientId) =>
      ref.watch(templateAdminServiceProvider).watchForClient(clientId),
);

final letterheadServiceProvider = Provider<LetterheadService>(
  (ref) => LetterheadService(ref.watch(remoteGatewayProvider)),
);

/// Réduction des clichés : codec natif sur mobile, repli Dart sur Windows.
/// Voir `ReductionJpeg` — sans ce repli, un rapport généré sur PC sortirait
/// sans aucune photo, et sans le moindre message.
final reductionJpegProvider = Provider<ReductionJpeg>(
  (ref) => ReductionJpeg.pourLaPlateforme(),
);

/// Sortie du rapport : sélecteur d'emplacement sur PC, feuille de partage sur
/// tablette.
final reportExporterProvider = Provider<ReportExporter>(
  (ref) => ReportExporter.pourLaPlateforme(),
);

final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(
    db: ref.watch(databaseProvider),
    photos: ref.watch(photoRepositoryProvider),
    gateway: ref.watch(remoteGatewayProvider),
    letterheads: ref.watch(letterheadServiceProvider),
    reduction: ref.watch(reductionJpegProvider),
  ),
);

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => PhotoRepository(
    ref.watch(databaseProvider),
    ref.watch(remoteGatewayProvider),
    ref.watch(photoStorageProvider),
  ),
);

// -----------------------------------------------------------------------------
// Session
// -----------------------------------------------------------------------------

final authBackendProvider = Provider<AuthBackend>(
  (ref) => SupabaseAuthBackend(Supabase.instance.client.auth),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(databaseProvider),
    ref.watch(authBackendProvider),
    ref.watch(photoStorageProvider),
  ),
);

/// Session courante, `null` si déconnecté.
///
/// La valeur initiale est émise immédiatement, avant tout événement : la
/// session étant persistée sur l'appareil, l'app doit s'ouvrir sur le relevé
/// sans le moindre aller-retour réseau.
final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final backend = ref.watch(authBackendProvider);
  yield backend.currentUserId;
  yield* backend.userIdChanges;
});

/// Identifiant de l'opérateur connecté, auteur des relevés.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authUserIdProvider).valueOrNull,
);

/// Profil local de l'utilisateur : son nom pour les rapports, son rôle pour
/// l'interface.
final currentProfileProvider = StreamProvider<Profile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  return ref.watch(databaseProvider).watchProfile(userId);
});

// -----------------------------------------------------------------------------
// Vues
// -----------------------------------------------------------------------------

/// Vue admin : les chantiers clôturés restent visibles, ce sont eux qui portent
/// les rapports.
final allProjectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectDaoProvider).watchAllProjects(),
);

/// Vue technicien : uniquement les chantiers **en cours** auxquels il a été
/// explicitement affecté.
///
/// Le filtrage est fait ici *et* par les policies RLS, qui ne font descendre
/// que ces chantiers-là. La redondance est voulue : la base locale d'un compte
/// promu administrateur puis rétrogradé pourrait encore contenir des chantiers
/// qu'il ne doit plus voir, tant qu'aucune purge n'a eu lieu.
final assignedProjectsProvider = StreamProvider<List<Project>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);

  return ref.watch(projectDaoProvider).watchAssignedProjects(userId).map(
        (list) => [
          for (final project in list)
            if (project.status == ProjectStatus.inProgress) project,
        ],
      );
});

final allProfilesProvider = StreamProvider<List<Profile>>(
  (ref) => ref.watch(projectDaoProvider).watchAllProfiles(),
);

/// Nombre de chantiers par utilisateur, pour repérer un technicien oublié.
final assignmentCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(projectDaoProvider).watchAssignmentCounts(),
);

final userAdminServiceProvider = Provider<UserAdminService>(
  (ref) => UserAdminService(
    ref.watch(databaseProvider),
    ref.watch(remoteGatewayProvider),
  ),
);

final clientsProvider = StreamProvider<List<Client>>(
  (ref) => ref.watch(projectDaoProvider).watchClients(),
);

final projectProvider = StreamProvider.family<Project?, String>(
  (ref, id) => ref.watch(projectDaoProvider).watchProject(id),
);

final clientProvider = StreamProvider.family<Client?, String>(
  (ref, id) => ref.watch(projectDaoProvider).watchClient(id),
);

final operatorsProvider = StreamProvider<List<Profile>>(
  (ref) => ref.watch(projectDaoProvider).watchOperators(),
);

final projectMembersProvider =
    StreamProvider.family<List<ProjectMember>, String>(
  (ref, projectId) => ref.watch(projectDaoProvider).watchMembers(projectId),
);

final pointsProvider = StreamProvider.family<List<PointSummary>, String>(
  (ref, projectId) => ref.watch(pointDaoProvider).watchPoints(projectId),
);

final pointProvider = StreamProvider.family<Point?, String>(
  (ref, pointId) => ref.watch(pointDaoProvider).watchPoint(pointId),
);

final pointPhotosProvider = StreamProvider.family<List<Photo>, String>(
  (ref, pointId) => ref.watch(pointDaoProvider).watchPhotos(pointId),
);

final materialsProvider = StreamProvider<List<MaterialItem>>(
  (ref) => ref.watch(pointDaoProvider).watchMaterials(),
);

final pointMaterialsProvider =
    StreamProvider.family<List<PointMaterial>, String>(
  (ref, pointId) => ref.watch(pointDaoProvider).watchPointMaterials(pointId),
);

// -----------------------------------------------------------------------------
// Synchronisation
// -----------------------------------------------------------------------------

/// Surchargé en test par un faux gateway — l'interface [RemoteGateway] n'a que
/// deux méthodes, le double est trivial à écrire.
final remoteGatewayProvider = Provider<RemoteGateway>(
  (ref) => SupabaseRemoteGateway(Supabase.instance.client),
);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(databaseProvider),
    gateway: ref.watch(remoteGatewayProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final syncStateProvider = StreamProvider<SyncState>(
  (ref) => ref.watch(syncEngineProvider).states,
);

/// Compteur « N éléments à synchroniser ».
///
/// Sur un chantier sans réseau, c'est la seule preuve visible pour l'opérateur
/// que son relevé n'est pas perdu. À afficher en permanence.
final pendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchPendingCount(),
);
