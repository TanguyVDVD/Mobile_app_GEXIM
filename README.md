# FireStop Tracker

Recensement et documentation photographique des **calfeutrements de traversées**
sur chantier : les percements de parois pour câbles et tuyauteries, et les
dispositifs coupe-feu qui les rebouchent.

Chaque traversée doit être prouvée par deux clichés — la percée nue, puis le
calfeutrement réalisé — accompagnés des matériaux mis en œuvre. À la clôture du
chantier, l'ensemble devient un **rapport de conformité PDF** remis au client.
C'est un document à valeur contractuelle, opposable en cas de sinistre.

L'application est conçue pour être utilisée **sans réseau**, sur une tablette,
avec des gants.

---

## Mise en route

### 1. Le backend

Créez un projet sur [supabase.com](https://supabase.com), puis collez
**`supabase/bootstrap.sql`** dans le SQL Editor. Ce fichier réunit les neuf
migrations et les données de départ ; il s'applique en une fois sur un projet
vierge.

Créez ensuite un compte dans **Authentication › Users** (cochez *Auto Confirm
User*) et promouvez-le :

```sql
update public.profiles set role = 'admin' where email = 'vous@exemple.be';
```

C'est la seule opération SQL manuelle : tous les comptes suivants s'inscrivent
depuis l'application, et un administrateur les élève depuis l'écran *Équipe*.

### 2. L'application

Copiez `env.example.json` vers `env.json` et renseignez l'URL et la clé
*publishable* du projet (**Project Settings › API**), puis :

```bash
flutter pub get
dart run build_runner build      # génère le code Drift
flutter run --dart-define-from-file=env.json
```

Sous VS Code, **F5** suffit — la configuration est dans `.vscode/launch.json`.

Pour un APK installable sur les tablettes :

```bash
flutter build apk --release --dart-define-from-file=env.json
```

> La clé publishable est **compilée dans l'APK**. Ce n'est pas un secret : elle
> est publique par conception, et ce sont les policies de sécurité au niveau
> ligne (RLS) qui protègent les données. Changer de projet impose de
> reconstruire.

**Android 7.0 minimum**, toutes architectures incluses (dont ARM 32 bits).

---

## Les deux rôles

| | Technicien | Administrateur |
|---|---|---|
| Voit | uniquement les chantiers auxquels il est **affecté** | tous |
| Fait | relève des traversées, photographie, renseigne les matériaux | gère clients, chantiers, affectations et comptes |
| Clôture un chantier | non | oui, ce qui gèle le relevé et produit le rapport |

Tout compte créé par inscription naît technicien et **ne voit aucun chantier**
tant qu'un administrateur ne l'a pas affecté.

---

## Ce qui structure le code

### La base locale fait foi

L'interface ne parle **jamais** au réseau. Elle lit et écrit dans SQLite, et
l'écran se met à jour instantanément — en avion comme en 4G. Un moteur rattrape
le serveur en arrière-plan quand le réseau le permet.

```
Écrans ⇄ SQLite ──→ file d'attente ──→ Supabase
                    binaires photo ──↗
           ↖────────── descente ←────┘
```

Toute mutation écrit la table métier **et** met en file l'envoi distant dans la
même transaction. Un crash entre les deux laisserait une modification visible à
l'écran mais jamais transmise — la pire des pannes, parce que silencieuse.

### Deux horodatages, deux autorités

`updated_at` appartient au client : il date la saisie et arbitre les conflits
(dernière écriture gagnante). `synced_at` appartient au serveur : il sert de
curseur à la descente.

Les confondre serait une panne totale et silencieuse — une seule tablette à
l'horloge déréglée propulserait le curseur de toutes les autres dans le futur,
et plus rien ne redescendrait.

### La sécurité est dans Postgres

L'application masque ce qu'un technicien ne doit pas voir, mais ce n'est qu'un
confort. Le verrou réel est dans les policies RLS : un APK modifié, une tablette
à l'heure fausse ou un appel direct à l'API se heurtent aux mêmes règles.

Une policy trop permissive ne produit **aucune erreur** — elle laisse passer.
Les refus sont donc prouvés par 14 tests SQL rejouant les migrations réelles sur
un Postgres jetable :

```bash
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml exec -T db \
  psql -v ON_ERROR_STOP=1 -U postgres -d firestop < docker/rls_tests.sql
```

### Le rapport est une donnée dérivée

`packages/firestop_report/` est un package **Dart pur**, sans dépendance
Flutter ni entrée-sortie : le rendu est une fonction de (données, gabarit) vers
des octets. Le même code produira le document côté serveur le jour où la
génération y sera déplacée.

Le PDF ne transite donc pas par la file d'attente : il se reconstruit à
l'identique depuis les traversées, ce qui vaut mieux que de faire voyager des
dizaines de mégaoctets.

La mise en page est **configurable par client** — couleur, page de garde,
disposition des clichés, marges, et **papier à en-tête** : le rapport se compose
par-dessus votre document type. Tout se règle depuis *Clients › Mise en page du
rapport*, sans écrire de JSON. Voir `docs/gabarit-rapport.md`.

Le gabarit est lu avec tolérance : une valeur erronée retombe sur un défaut
plutôt que d'empêcher la production d'un document contractuel.

---

## Organisation

```
lib/
  app/          thème, routage, injection
  database/     Drift — tables, DAO, base locale
  sync/         file d'attente, montée, descente, passerelle distante
  features/     auth · capture · points · projects · admin · reports
  shared/       composants d'interface
packages/
  firestop_report/   rendu PDF, Dart pur
supabase/
  migrations/   schéma, RLS, stockage
  bootstrap.sql généré, pour l'installation initiale
docker/
  rls_tests.sql banc d'essai des policies
```

## Vérifier

```bash
flutter analyze                                  # doit rester à zéro
flutter test                                     # 51 tests
cd packages/firestop_report && dart test         # 29 tests
```

`dart run build_runner build` est **obligatoire** après toute modification de
table ou de DAO.

---

## Ce qui reste à faire

1. **Deux polices TrueType** à déposer dans `assets/fonts/`. Sans elles, le PDF
   perd silencieusement `—`, `’`, `œ` et `…` — des caractères que les correcteurs
   de clavier produisent tout seuls. Voir `assets/fonts/README.md`.
2. **Un worker de génération PDF**, utile au-delà d'environ 150 traversées par
   chantier, où la mémoire d'une tablette ancienne devient le facteur limitant.
   Le package est déjà prêt pour ça.
3. **La purge locale après révocation** : retirer un technicien d'un chantier lui
   coupe l'accès côté serveur, mais les données déjà descendues restent sur sa
   tablette jusqu'à une reconnexion.
