# FireStop Tracker

Recensement et documentation photographique des **calfeutrements de traversées**
sur chantier : les percements de parois pour câbles et tuyauteries, et les
dispositifs coupe-feu qui les rebouchent.

Chaque traversée doit être prouvée par deux clichés — la percée nue, puis le
calfeutrement réalisé — et caractérisée : configuration, niveau EI, produits mis
en œuvre. À la clôture du
chantier, l'ensemble devient un **classeur Excel de fiches AS BUILT**, une feuille
par traversée, dans le modèle du bureau.
C'est un document à valeur contractuelle, opposable en cas de sinistre.

L'application est conçue pour être utilisée **sans réseau**, sur une tablette,
avec des gants.

Elle a deux visages : l'**application Android** du technicien, cœur du projet,
et une **version navigateur** pour l'administrateur — chantiers, clients, listes,
export des fiches — hébergée sur un VPS (voir `deploy/nginx.conf`).

---

## Mise en route

### 1. Le backend

Créez un projet sur [supabase.com](https://supabase.com), puis collez
**`supabase/bootstrap.sql`** dans le SQL Editor. Ce fichier réunit les trois
migrations — schéma, droits d'accès, stockage — et s'applique en une fois sur un
projet vierge. Il installe au passage les six listes de la fiche de traversée —
configurations, configurations détaillées, niveaux EI, fournisseurs, types de
produit et produits — qu'un administrateur complète ensuite depuis
*Paramètres*.

`bootstrap.sql` est généré : après toute modification d'une migration,
`dart run tools/bootstrap.dart` le reconstruit.

Créez ensuite un compte — depuis l'écran *Créer un compte* de l'application, ou
dans **Authentication › Users** (cochez *Auto Confirm User*) — et promouvez-le :

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
autorisé l'installation d'applications de sources inconnues.

> **Sauvegardez le keystore ailleurs que sur le poste de build.** En diffusion
> directe, cette clé est l'identité de l'application : Android refuse toute
> mise à jour signée autrement. La perdre oblige à désinstaller l'app de
> chaque tablette — et donc à perdre les relevés qui n'y ont pas encore été
> transmis.

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
| Fait | relève, photographie et caractérise les traversées | gère clients, chantiers, affectations, listes et comptes |
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
Les refus sont donc prouvés par 31 tests SQL rejouant les migrations réelles sur
un Postgres jetable :

```bash
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml exec -T db \
  psql -v ON_ERROR_STOP=1 -U postgres -d firestop < docker/rls_tests.sql
```

### L'export est une donnée dérivée

À la clôture d'un chantier, l'application produit un classeur Excel : **une
feuille par traversée**, remplie dans le modèle du bureau,
`AS_BUILT_Resserages_RF_model_vierge.xlsm`.

`packages/firestop_excel/` est un package **Dart pur**, sans dépendance Flutter
ni entrée-sortie : une fonction `(modèle, données) → octets`. Il ne reconstruit
pas le classeur, il le **retouche** — un `.xlsm` est une archive de fichiers
XML, et seules les feuilles de fiche sont réécrites. Tout le reste traverse
octet pour octet : les macros, les styles, la feuille « Menus déroulants ».
Chaque fiche garde donc ses trois boutons et ses listes déroulantes, et le
classeur reste exploitable dans Excel — y compris pour ajouter un point à la
main.

Le classeur ne transite pas par la file d'attente : il se reconstruit à
l'identique depuis les traversées.

Ce qui change d'une entreprise à l'autre se règle dans *Paramètres* :
configurations, configurations détaillées, niveaux EI, fournisseurs et leurs
produits, types de produit. Ce sont des listes de données, pas du code : un
administrateur en ajoute sans migration.

**Retoucher le modèle** impose de relancer les tests du package : les
emplacements des valeurs y sont relevés cellule par cellule, et un test échoue
si l'une d'elles a disparu. Pour regarder le résultat dans Excel :
`cd packages/firestop_excel ; dart run tool/exemple.dart ..\..\exemple.xlsm`.

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
  firestop_excel/    classeur Excel des fiches AS BUILT, Dart pur
supabase/
  migrations/   schéma, RLS, stockage
  bootstrap.sql généré, pour l'installation initiale
docker/
  rls_tests.sql banc d'essai des policies
deploy/
  nginx.conf    configuration du VPS pour la version navigateur
web/            page d'accueil, icônes, SQLite en WebAssembly
tools/
  bootstrap.dart  régénère supabase/bootstrap.sql
  web/            les deux fichiers de la base locale côté navigateur
  macros.ps1      réinscrit la macro « Nouveau point » (tools/macros/) dans le modèle
  logo.py         régénère le logo et les icônes
AS_BUILT_Resserages_RF_model_vierge.xlsm
                le modèle du classeur, avec ses macros — à versionner :
                les cellules de la fiche sont relevées sur lui
```

## Vérifier

```bash
flutter analyze                                  # doit rester à zéro
flutter test                                     # 168 tests
cd packages/firestop_excel && dart test          # 38 tests
```

`dart run build_runner build` est **obligatoire** après toute modification de
table ou de DAO.

---

## Ce qui reste à faire

0. **Le premier essai en conditions réelles.** La version 0.1.0 est prête à
   installer, mais n'a encore tourné sur aucune tablette réelle : un relevé
   complet photos comprises, hors réseau puis au retour du réseau, jusqu'au
   classeur ouvert dans Excel et relu.
1. **Les listes de « Menus déroulants »** du classeur sont celles du modèle,
   pas celles de *Paramètres*. Une fiche exportée porte les bonnes valeurs ;
   seule une fiche ajoutée à la main dans Excel propose les anciennes.
3. **La purge locale après révocation** : retirer un technicien d'un chantier lui
   coupe l'accès côté serveur, mais les données déjà descendues restent sur sa
   tablette jusqu'à une reconnexion.
4. **Deux permissions de stockage superflues** dans l'APK, apportées par le
   plugin caméra. L'application ne s'en sert pas ; les retirer demande un essai
   de prise de vue sur une tablette Android 9 ou antérieure.
