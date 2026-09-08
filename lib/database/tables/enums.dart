/// Rôle d'un utilisateur. Pilote le RBAC côté app *et* les policies RLS Postgres.
enum UserRole { admin, operator }

/// Cycle de vie d'un projet.
///
/// Le passage à [completed] est réservé à l'admin : il gèle le projet (aucune
/// écriture d'opérateur n'est plus acceptée, y compris côté serveur via RLS) et
/// déclenche la génération du rapport PDF.
enum ProjectStatus { draft, inProgress, completed }

/// Nature d'une photo dans le dossier d'un point.
///
/// [before] et [after] sont les deux clichés exigés par la norme : l'état de la
/// traversée avant intervention, et le calfeutrement réalisé.
enum PhotoKind { before, after, extra }

/// Étape de traitement d'une photo, du déclencheur à l'objet distant.
enum PhotoUploadState {
  /// Fichier brut écrit sur le disque, compression pas encore faite.
  captured,

  /// Compressé et prêt à partir, en attente de réseau.
  ready,

  /// Binaire présent dans le bucket distant.
  uploaded,

  /// Échec définitif (fichier local disparu, refus serveur). Requiert l'humain.
  failed,
}

/// Type d'entité poussée par l'outbox. La valeur sérialisée sert aussi de nom de
/// table distante — voir `SupabaseRemoteGateway._tableFor`.
enum OutboxEntity {
  client,
  project,
  projectMember,
  point,
  pointMaterial,
  photo,
}

/// Entité redescendue du serveur.
///
/// **L'ordre de déclaration est celui des dépendances**, et il est significatif :
/// le pull parcourt `PullEntity.values` dans l'ordre, et les clés étrangères
/// sont appliquées localement (`PRAGMA foreign_keys = ON`). Insérer un point
/// avant son chantier échouerait.
///
/// Plus large que [OutboxEntity] : les profils, templates et matériaux sont
/// administrés côté serveur et ne remontent jamais depuis une tablette.
enum PullEntity {
  profile,
  reportTemplate,
  client,
  project,
  projectMember,
  point,
  material,
  pointMaterial,
  photo,
}

/// État d'une entrée d'outbox.
enum OutboxStatus {
  /// En attente de son tour.
  pending,

  /// Envoi en cours. Remis à [pending] au démarrage (reprise après crash).
  inflight,

  /// Échec permanent : ne sera plus retenté sans intervention.
  failed,
}
