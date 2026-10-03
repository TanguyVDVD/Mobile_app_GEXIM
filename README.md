# FireStop Tracker

Recensement et documentation photographique des **calfeutrements de traversées**
sur chantier : les percements de parois pour câbles et tuyauteries, et les
dispositifs coupe-feu qui les rebouchent.

Chaque traversée est photographiée et caractérisée : étage, configuration,
niveau EI, fournisseur, produits mis en œuvre. Le chantier s'exporte ensuite en
un **classeur Excel de fiches AS BUILT** — une feuille par traversée, dans le
modèle du bureau, macros comprises.

L'application a deux visages :

| | Pour qui | Ce qu'on y fait |
|---|---|---|
| **Application Android** | le technicien, sur tablette | relever, photographier, caractériser — **sans réseau** s'il le faut |
| **Version navigateur** | l'administrateur, à son poste | chantiers, clients, listes, comptes, affectations, export des fiches |

L'application Android est le cœur du projet. La version navigateur fait tout
sauf la prise de vue, et suppose un poste connecté.

---

## Mise en route

### 1. Le backend

Créez un projet sur [supabase.com](https://supabase.com), puis collez
**`supabase/bootstrap.sql`** dans le SQL Editor. Ce fichier réunit toutes les
migrations de `supabase/migrations/` — schéma, droits d'accès, stockage — et
s'applique en une fois sur un projet vierge. Il installe au passage les listes
de la fiche (étages, configurations, niveaux EI, fournisseurs, produits…),
qu'un administrateur complète ensuite depuis *Paramètres*.

`bootstrap.sql` est **généré** : après toute modification d'une migration,
`dart run tools/bootstrap.dart` le reconstruit.

Sur un projet **déjà installé**, on ne rejoue pas `bootstrap.sql` : on exécute,
dans l'ordre de leur nom, les fichiers de `supabase/migrations/` qui n'y sont
pas encore passés. **La migration passe avant la version de l'application qui
en dépend** — l'application envoie les nouvelles colonnes, et le serveur refuse
une colonne qu'il ne connaît pas.

Créez ensuite un compte — depuis l'écran *Créer un compte* de l'application, ou
dans **Authentication › Users** (cochez *Auto Confirm User*) — et promouvez-le :

```sql
update public.profiles set role = 'admin' where email = 'vous@exemple.be';
```

C'est la seule opération SQL manuelle : les comptes suivants s'inscrivent
depuis l'application, et un administrateur les élève depuis l'écran
*Utilisateurs*.

### 2. Lancer l'application

Copiez `env.example.json` vers `env.json` et renseignez l'URL et la clé
*publishable* du projet (**Project Settings › API**), puis :

```bash
flutter pub get
dart run build_runner build                               # génère le code Drift
flutter run --dart-define-from-file=env.json              # tablette ou émulateur
flutter run -d chrome --dart-define-from-file=env.json    # navigateur
```

Sous VS Code, **F5** suffit — la configuration est dans `.vscode/launch.json`.

> La clé publishable est **compilée dans l'application**, APK comme version
> navigateur. Ce n'est pas un secret : elle est publique par conception, et ce
> sont les policies de sécurité au niveau ligne (RLS) qui protègent les
> données. Changer de projet Supabase impose de recompiler.

### 3. L'APK des tablettes

L'APK de production est signé par une clé que désigne `android/key.properties`
— hors dépôt ; `android/key.properties.example` explique comment créer le
keystore. Sans lui, la compilation s'arrête plutôt que de signer avec la clé de
débogage.

```bash
flutter build apk --release --dart-define-from-file=env.json
```

L'APK sort dans `build/app/outputs/flutter-apk/app-release.apk`. Pour
l'installer : `adb install` sur une tablette branchée en USB (débogage
activé), ou copie du fichier sur la tablette puis ouverture, après avoir
autorisé l'installation d'applications de sources inconnues. Une nouvelle
version s'installe par-dessus l'ancienne ; la base locale se met à niveau seule
à l'ouverture.

> **Sauvegardez le keystore ailleurs que sur le poste de build.** En diffusion
> directe, cette clé est l'identité de l'application : Android refuse toute
> mise à jour signée autrement. La perdre oblige à désinstaller l'app de
> chaque tablette — et donc à perdre les relevés qui n'y ont pas encore été
> transmis.

**Android 7.0 minimum**, toutes architectures incluses (dont ARM 32 bits).

Quand une version change la forme des données échangées avec le serveur,
**toutes les tablettes doivent être mises à jour ensemble** : une tablette en
retard ne sait plus lire ce que les autres envoient, et sa synchronisation
s'arrête.

### 4. La version navigateur, sur un VPS

```bash
flutter build web --release --dart-define-from-file=env.json --no-web-resources-cdn
```

`build/web` est un dossier de fichiers statiques : on le copie sur le serveur,
et rien d'autre ne tourne là-bas pour l'application — comptes, données et
photos restent chez Supabase. `deploy/nginx.conf` est la configuration prête à
adapter : nom de domaine, identifiant du projet Supabase, certificat HTTPS.
Tout y est commenté, en particulier les trois réglages faciles à casser (le
type des fichiers WebAssembly, le cache des fichiers d'entrée, les en-têtes de
sécurité).

Pour mettre à jour : recompiler, recopier `build/web`. Les utilisateurs ont la
nouvelle version au rechargement de la page.

---

## Les deux rôles

| | Technicien | Administrateur |
|---|---|---|
| Voit | uniquement les chantiers auxquels il est **affecté** | tous |
| Fait | relève, photographie et caractérise les traversées | gère clients, chantiers, affectations, listes et comptes |
| Clôture un chantier | non | oui, ce qui gèle le relevé |
| Exporte les fiches | non | oui |
| Supprime | une traversée, une photo | aussi un chantier, un client, une entrée de liste |

Tout compte créé par inscription naît technicien et **ne voit aucun chantier**
tant qu'un administrateur ne l'a pas affecté.

---

## Ce que l'application fait

### La fiche d'une traversée

Elle suit, ligne pour ligne, le formulaire du bureau :

- **Identification** — date, numéro du point, numéro et intitulé du projet,
  Purchase Order, bâtiment, étage. Le numéro du point est un texte libre
  (« 12 », « 1.40 », « A-07 ») ; l'application propose le suivant du dernier
  point relevé. Numéro de projet, intitulé et Purchase Order se saisissent sur
  le chantier et arrivent préremplis : ils restent modifiables fiche par fiche,
  et une fiche non modifiée suit le chantier s'il est corrigé après coup.
- **Photographies** — deux emplacements, plus des clichés complémentaires.
- **Caractéristiques** — configuration, configuration détaillée, niveau EI,
  fournisseur, type de produit, et jusqu'à cinq produits. Les produits proposés
  sont ceux du fournisseur choisi.

Dans la liste d'un chantier, chaque traversée dit où elle en est : « Complet »,
ou le nombre de photos ajoutées et de valeurs manquantes, en rouge pour ce qui
manque.

### Les listes sont des données

Étages, configurations, niveaux EI, fournisseurs et leurs produits, types de
produit : tout ce qui se choisit dans une liste déroulante s'administre dans
*Paramètres*, sans toucher au code. Une entrée retirée n'est plus proposée,
mais les traversées qui la portent la gardent.

### L'export Excel

L'application remplit le modèle `AS_BUILT_Resserages_RF_model_vierge.xlsm` :
une feuille par traversée, nommée d'après son numéro, avec ses valeurs, ses
deux photos et le logo du client. Le classeur garde les macros du modèle — le
bouton « Nouveau point » y crée une fiche de plus, déjà remplie de ce qui est
commun au chantier — et ses listes déroulantes.

Sur tablette le classeur part par la feuille de partage ; dans un navigateur il
se télécharge. L'écran d'export signale ce qui manque avant qu'il ne parte : un
cliché ou un logo qui n'a pas pu être récupéré.

### Les suppressions

Supprimer un **chantier** ou une **traversée** l'efface pour de bon, sur le
serveur et sur toutes les tablettes, photos comprises. Un avertissement le dit
avant. La suppression d'un chantier demande d'être en ligne ; celle d'une
traversée se fait aussi hors ligne et s'applique à la synchronisation suivante.
Un client ne se supprime que s'il n'a plus de chantier.

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

Dans un navigateur, c'est le même SQLite, compilé en WebAssembly et rangé dans
le stockage du site.

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
Les refus sont donc prouvés par 31 tests SQL rejouant les migrations réelles sur
un Postgres jetable :

```bash
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml exec -T db \
  psql -v ON_ERROR_STOP=1 -U postgres -d firestop < docker/rls_tests.sql
docker compose -f docker/docker-compose.yml down -v
```

### Le classeur est retouché, pas reconstruit

`packages/firestop_excel/` est un package **Dart pur**, sans dépendance Flutter
ni entrée-sortie : une fonction `(modèle, données) → octets`. Un `.xlsm` est une
archive de fichiers XML ; seules les feuilles de fiche sont réécrites, et tout
le reste traverse octet pour octet — les macros, les styles, la feuille « Menus
déroulants ».

Le modèle peut être rouvert et enregistré dans Excel sans rien casser : le
générateur relit dans le fichier tout ce qu'Excel réécrit en enregistrant
(numéros de style, dimensions des cases). Après un changement du modèle, lancez
tout de même les tests du package, puis regardez un classeur d'exemple :

```bash
cd packages/firestop_excel
dart test
dart run tool/exemple.dart ..\..\exemple.xlsm 3
```

La macro « Nouveau point » a sa source dans `tools/macros/Module1.bas`.
`tools/macros.ps1` la réinscrit dans le modèle — à relancer si le bureau
fournit une nouvelle version du fichier, qui n'aurait plus cette macro.

### Deux plateformes, un seul code

Mêmes écrans, même base locale, même synchronisation. Ce qui sépare la tablette
du navigateur — fichiers de photos, prise de vue, sortie du classeur — est
décidé en un seul endroit, `lib/core/plateforme.dart`. Le chemin de la tablette
n'est jamais réécrit pour arranger le navigateur.

---

## Organisation

```
lib/
  app/          thème, routage, injection
  core/         identifiants, plateforme, numéros de point
  database/     Drift — tables, DAO, base locale (tablette et navigateur)
  sync/         file d'attente, montée, descente, passerelle distante
  features/     auth · capture · points · projects · admin · reports
  shared/       composants d'interface
packages/
  firestop_excel/   classeur Excel des fiches AS BUILT, Dart pur
supabase/
  migrations/   schéma, droits d'accès, stockage — la source de vérité
  bootstrap.sql généré, pour l'installation d'un projet vierge
docker/
  rls_tests.sql banc d'essai des policies
deploy/
  nginx.conf    configuration du VPS pour la version navigateur
web/            page d'accueil, icônes, SQLite en WebAssembly
android/        la cible tablette
assets/
  branding/     le logo, en PNG et en SVG
tools/
  bootstrap.dart  régénère supabase/bootstrap.sql
  macros.ps1      réinscrit la macro « Nouveau point » dans le modèle
  macros/         sa source, et le modèle tel que le bureau l'avait fourni
  web/            de quoi régénérer les deux fichiers de la base côté navigateur
  logo.py         régénère le logo et les icônes
  emulateur.ps1   lance l'émulateur Android en ligne de commande
AS_BUILT_Resserages_RF_model_vierge.xlsm
                le modèle du classeur, avec ses macros
```

`CLAUDE.md` tient le journal détaillé des choix d'architecture et des pièges
rencontrés ; c'est la lecture suivante pour qui reprend le code.

## Vérifier

```bash
flutter analyze                                  # doit rester à zéro
flutter test                                     # 168 tests
cd packages/firestop_excel && dart test          # 38 tests
```

`dart run build_runner build` est **obligatoire** après toute modification de
table ou de DAO.

---

## État

Version **0.5.1**. Essayée le 3 octobre 2026 sur une tablette et dans un
navigateur : l'ensemble fonctionne.

Ce qui reste ouvert :

1. **Les listes de « Menus déroulants » du classeur** sont celles du modèle,
   pas celles de *Paramètres*. Une fiche exportée porte les bonnes valeurs ;
   seule une fiche ajoutée à la main dans Excel propose les listes du modèle.
2. **La troisième photo et les suivantes** restent dans l'application : la
   fiche Excel n'a que deux cases, et l'export ne signale pas celles qu'il
   laisse de côté.
3. **La purge locale après révocation** : retirer un technicien d'un chantier
   lui coupe l'accès côté serveur, mais les données déjà descendues restent sur
   sa tablette jusqu'à une reconnexion.
4. **L'inscription est ouverte.** Tout compte créé, même sans chantier, peut
   lire les listes de produits, les logos des clients, et le nom et l'adresse
   des administrateurs. À fermer dans Supabase si les comptes sont connus
   d'avance.
5. **Deux permissions de stockage superflues** dans l'APK, apportées par le
   plugin caméra. L'application ne s'en sert pas ; les retirer demande un essai
   de prise de vue sur une tablette Android 9 ou antérieure.
6. **La table et l'espace de stockage `reports`**, hérités de l'ancien export
   PDF, existent toujours côté serveur et ne servent plus.
