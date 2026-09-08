import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../database/tables/enums.dart';
import '../../sync/remote_gateway.dart';

/// Changement de rôle d'un utilisateur.
class UserAdminService {
  const UserAdminService(this._db, this._gateway);

  final AppDatabase _db;
  final RemoteGateway _gateway;

  /// Élève ou rétrograde un compte. **Exige du réseau.**
  ///
  /// Le serveur d'abord, la base locale ensuite. L'ordre inverse afficherait un
  /// rôle que le serveur a refusé — et `guard_profile_role` refuse bel et bien
  /// si l'appelant n'est pas administrateur.
  ///
  /// Aucune mise en file : voir `RemoteGateway.setUserRole`. Un geste qui étend
  /// des droits doit être immédiat, ou ne pas avoir lieu.
  Future<void> setRole(String userId, UserRole role) async {
    await _gateway.setUserRole(userId, role);

    // Reflet local, pour que l'interface suive sans attendre la descente. Le
    // prochain pull confirmera avec la version du serveur, qui fait foi.
    await (_db.update(_db.profiles)..where((t) => t.id.equals(userId))).write(
      ProfilesCompanion(
        role: Value(role),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
