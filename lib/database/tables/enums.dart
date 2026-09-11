/// Rôle d'un utilisateur. Pilote le RBAC côté app *et* les policies RLS Postgres.
enum UserRole { admin, operator }

/// Cycle de vie d'un chantier.
///
/// Le passage à [completed] est réservé à l'admin : il gèle le chantier (aucune
/// écriture de technicien n'est plus acceptée, y compris côté serveur via RLS)
/// et ouvre la génération du rapport PDF.
enum ProjectStatus { inProgress, completed }

/// Liste de paramètres administrable depuis `/parametres`.
///
/// Chaque valeur désigne **une** des listes déroulantes de la fiche de
/// traversée. Elles vivent toutes dans la même table `setting_options`, et non
/// dans des tables jumelles : elles ont la même forme (un libellé, un rang), le
/// même cycle de vie et les mêmes policies RLS. Des tables séparées auraient
/// demandé autant de DAO, d'entrées d'outbox et de policies — la sixième liste,
/// « type de produit », n'a coûté ici qu'une constante.
///
/// Pas d'`enum` Postgres pour les *valeurs* de ces listes, et c'est tout
/// l'objet de cette table : un administrateur doit pouvoir ajouter un produit
/// sans migration. Seule la *nature* de la liste est figée ici, parce que
/// chacune correspond à une colonne précise de `points` et à une ligne précise
/// du gabarit PDF.
enum SettingKind {
  /// Traversée de paroi verticale, percement horizontal, ouverture linéaire…
  configuration,

  /// Conduite synthétique, chemin de câbles, trou…
  configurationDetail,

  /// EI30, EI60, EI90, EI120.
  eiLevel,

  /// Fabricant du produit mis en œuvre (Promat…).
  supplier,

  /// Nature du produit posé : manchon, mortier, mousse 1 comp…
  ///
  /// Distincte de [product], qui en nomme la référence commerciale : un même
  /// type se décline chez plusieurs fournisseurs, et le formulaire porte les
  /// deux lignes.
  productType,

  /// Référence du produit (Promastop-FC…).
  product,
}

/// Nature d'une photo dans le dossier d'un point.
///
/// [before] et [after] sont les deux clichés exigés par la norme : l'état de la
/// traversée avant intervention, et le calfeutrement réalisé.
enum PhotoKind { before, after, extra }

/// Étape de traitement d'une photo, du déclencheur à l'objet distant.
enum PhotoUploadState {
  /// Compressé, écrit sur le disque, et prêt à partir — en attente de réseau.
  ready,

  /// Binaire présent dans le bucket distant.
  uploaded,

  /// Échec définitif (fichier local disparu, refus serveur). Requiert l'humain.
  failed,
}

/// Type d'entité poussée par l'outbox.
///
/// Stocké en base par son nom Dart (`textEnum`) : **renommer ou retirer une
/// valeur rendrait illisibles les entrées déjà en file** sur les tablettes. La
/// table distante correspondante est donnée par
/// `SupabaseRemoteGateway._tableFor`.
enum OutboxEntity {
  client,
  project,
  projectMember,
  settingOption,
  point,
  photo,
}

/// Entité redescendue du serveur.
///
/// **L'ordre de déclaration est celui des dépendances**, et il est significatif :
/// le pull parcourt `PullEntity.values` dans l'ordre, et les clés étrangères
/// sont appliquées localement (`PRAGMA foreign_keys = ON`). Insérer un point
/// avant son chantier échouerait.
///
/// Plus large que [OutboxEntity] : les profils ne remontent jamais depuis une
/// tablette — un changement de rôle passe, en ligne, par
/// `RemoteGateway.setUserRole`.
enum PullEntity {
  profile,
  // Avant `point`, qui référence ses options par clé étrangère jusque dans la
  // base locale : une option pas encore descendue ferait échouer l'insertion
  // du point qui la désigne.
  settingOption,
  client,
  project,
  projectMember,
  point,
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
