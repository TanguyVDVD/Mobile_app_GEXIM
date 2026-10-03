import '../../database/database.dart';
import '../../sync/remote_gateway.dart';
import '../capture/photo_storage.dart';

/// Gestes d'administration d'un chantier qui **exigent le réseau**.
///
/// Pour l'instant un seul : la suppression. Elle est la seule de l'application
/// à effacer pour de bon, et c'est pourquoi elle ne passe pas par la file
/// d'attente — même raisonnement que le changement de rôle
/// (`UserAdminService`). Mise en file, elle s'appliquerait des heures plus
/// tard, peut-être après que l'administrateur a changé d'avis, sans qu'il
/// puisse la reprendre : on ne rattrape pas un effacement.
class ProjectAdminService {
  const ProjectAdminService(this._db, this._gateway);

  final AppDatabase _db;
  final RemoteGateway _gateway;

  /// Supprime **définitivement** un chantier : ses affectations, ses
  /// traversées, leurs clichés — sur le serveur, puis sur cet appareil.
  ///
  /// Le serveur d'abord. S'il refuse ou ne répond pas, rien n'est touché ici
  /// et l'appelant reçoit une `SyncException`. L'inverse — purger la tablette
  /// puis échouer en ligne — ferait redescendre au cycle suivant un chantier
  /// que l'écran venait de dire supprimé.
  ///
  /// Les autres appareils l'apprennent à leur prochaine descente, par la trace
  /// que le serveur garde de la suppression (`PullEntity.deletedProject`), et
  /// purgent leur copie de la même façon — travail non envoyé compris.
  Future<void> deleteProject(String projectId) async {
    await _gateway.deleteProject(projectId);

    final fichiers = await _db.projectDao.purgeProject(projectId);
    await PhotoStorage.effacer(fichiers);
  }
}
