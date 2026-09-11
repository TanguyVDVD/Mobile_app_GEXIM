import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../database/tables/enums.dart';
import '../capture/photo_storage.dart';
import 'auth_backend.dart';

/// Geste refusé parce qu'il détruirait du travail non transmis.
class PendingWorkBlocked implements Exception {
  const PendingWorkBlocked(this.pending, this.message);

  final int pending;
  final String message;

  @override
  String toString() => message;
}

/// Ouverture et fermeture de session, et tout ce qu'elles impliquent
/// localement.
///
/// Le point délicat n'est pas la connexion elle-même — Supabase s'en charge —
/// mais ce qu'il advient de la base de la tablette autour.
class AuthService {
  const AuthService(this._db, this._backend, [this._storage = const PhotoStorage()]);

  final AppDatabase _db;
  final AuthBackend _backend;
  final PhotoStorage _storage;

  static const String _lastUserKey = 'last_user_id';

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _backend.signIn(email: email, password: password);

    final userId = _backend.currentUserId;
    if (userId == null) {
      throw const AuthFailure('Session non établie, réessayez.');
    }
    await _adopt(userId, _backend.currentUserEmail ?? email.trim());
  }

  /// Crée un compte. Rend `true` si la session est ouverte dans la foulée.
  ///
  /// Le nouveau compte est **toujours** un simple technicien : le rôle est fixé
  /// par défaut en base et n'est pas transmis depuis le client. Il n'a par
  /// ailleurs accès à aucun chantier tant qu'un admin ne l'y a pas affecté —
  /// les policies RLS ne lui en montrent aucun.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final opened = await _backend.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );

    final userId = _backend.currentUserId;
    if (opened && userId != null) {
      await _adopt(userId, _backend.currentUserEmail ?? email.trim());
    }
    return opened;
  }

  /// À appeler au démarrage lorsqu'une session persistée est retrouvée.
  ///
  /// C'est ce qui rend l'app utilisable hors ligne : la session survit à la
  /// fermeture, et rouvrir l'application dans un sous-sol ne déclenche aucun
  /// appel réseau bloquant.
  Future<void> restoreSession() async {
    final userId = _backend.currentUserId;
    if (userId == null) return;
    await _adopt(userId, _backend.currentUserEmail ?? '');
  }

  /// Ferme la session, en refusant de le faire s'il reste du travail local.
  ///
  /// Une déconnexion ne purge pas la base : le même opérateur qui se
  /// reconnecte retrouve son chantier sans tout retélécharger. Mais elle ouvre
  /// la porte à une connexion d'un autre compte, laquelle purge — d'où le
  /// contrôle ici, au plus tôt, pendant qu'il est encore facile de synchroniser.
  ///
  /// Les envois **refusés** par le serveur bloquent aussi : ils attendent
  /// qu'un administrateur lève la cause, et n'existent que sur cet appareil.
  Future<void> signOut() async {
    final (:enAttente, :refuses) = await _db.travailNonTransmis();
    if (enAttente + refuses > 0) {
      throw PendingWorkBlocked(
        enAttente + refuses,
        refuses == 0
            ? '$enAttente élément${_s(enAttente)} '
                'ne ${enAttente > 1 ? 'sont' : 'est'} pas encore '
                'synchronisé${_s(enAttente)}. Connectez-vous à un réseau avant '
                'de vous déconnecter.'
            : _messageRefus(enAttente + refuses, refuses,
                geste: 'vous déconnecter'),
      );
    }
    await _backend.signOut();
  }

  Future<void> _adopt(String userId, String email) async {
    final previous = await _readSetting(_lastUserKey);

    if (previous != null && previous != userId) {
      final (:enAttente, :refuses) = await _db.travailNonTransmis();
      final total = enAttente + refuses;
      if (total > 0) {
        // On referme la session que l'on vient d'ouvrir : la tablette reste
        // sur le compte précédent, seul capable de faire partir ces relevés.
        await _backend.signOut();
        throw PendingWorkBlocked(
          total,
          refuses == 0
              ? 'Cette tablette contient $total élément${_s(total)} '
                  'non synchronisé${_s(total)} appartenant au compte '
                  'précédent. Reconnectez-vous avec ce compte et synchronisez '
                  'avant de changer d\'utilisateur.'
              : 'Cette tablette contient $total élément${_s(total)} '
                  'non transmis appartenant au compte précédent, dont '
                  '$refuses refusé${_s(refuses)} par le serveur. '
                  'Reconnectez-vous avec ce compte : ils doivent partir, ou '
                  'être débloqués par un administrateur, avant tout '
                  'changement d\'utilisateur.',
        );
      }
      await _wipeLocalData();
    }

    await _writeSetting(_lastUserKey, userId);
    await _seedProfile(userId, email);
  }

  static String _s(int n) => n > 1 ? 's' : '';

  static String _messageRefus(int total, int refuses, {required String geste}) =>
      '$total élément${_s(total)} n\'${total > 1 ? 'ont' : 'a'} pas encore été '
      'transmis au serveur, dont $refuses refusé${_s(refuses)}. Touchez le '
      'bandeau de synchronisation pour réessayer ; si le refus persiste, un '
      'administrateur doit lever le blocage avant que vous puissiez $geste.';

  /// Crée un profil local minimal pour l'utilisateur connecté.
  ///
  /// Sans lui, la toute première traversée créée après connexion échouerait sur
  /// une violation de clé étrangère : `points.author_id` référence `profiles`,
  /// et la descente n'a pas encore livré le vrai profil — elle exige du réseau,
  /// que le chantier n'a pas toujours.
  ///
  /// Deux précautions :
  ///  - `insertOrIgnore` : si le vrai profil est déjà là, on ne l'écrase pas.
  ///  - `updatedAt` à l'époque zéro, et non à maintenant. La descente arbitre
  ///    au last-write-wins : un profil provisoire horodaté « maintenant »
  ///    gagnerait contre la version serveur, et l'opérateur resterait
  ///    éternellement sans nom et sans son vrai rôle.
  Future<void> _seedProfile(String userId, String email) {
    return _db.into(_db.profiles).insert(
          ProfilesCompanion.insert(
            id: userId,
            fullName: '',
            email: email,
            role: UserRole.operator,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Efface toute trace du compte précédent.
  ///
  /// Deux raisons, et la première suffit : les relevés d'un opérateur ne
  /// doivent pas apparaître sur la tablette d'un autre. La seconde est que les
  /// curseurs de descente seraient faux — bornés par le périmètre RLS de
  /// quelqu'un d'autre, ils feraient croire à jour des données jamais reçues.
  Future<void> _wipeLocalData() async {
    await _db.transaction(() async {
      // Ordre inverse des dépendances : les enfants d'abord, les clés
      // étrangères étant actives localement.
      await _db.delete(_db.photos).go();
      await _db.delete(_db.points).go();
      // Après `points`, qui référencent les options par clé étrangère.
      await _db.delete(_db.settingOptions).go();
      await _db.delete(_db.projectMembers).go();
      await _db.delete(_db.projects).go();
      await _db.delete(_db.clients).go();
      await _db.delete(_db.profiles).go();

      await _db.delete(_db.outboxEntries).go();
      await _db.delete(_db.syncCursors).go();
    });

    // Les fichiers ne sont plus référencés par aucune ligne : le balayage des
    // orphelins les emportera. On l'appelle sans délai de grâce puisqu'aucune
    // capture n'est en cours au moment d'un changement de compte.
    await _storage.sweepOrphans(_db, grace: Duration.zero);
  }

  Future<String?> _readSetting(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeSetting(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(AppSetting(key: key, value: value));
  }
}
