# Déployer la version navigateur sur le VPS

Toutes les étapes, dans l'ordre, pour mettre la version navigateur de FireStop
Tracker en ligne sur un VPS où **Apache** est installé et où **Docker**
tourne.

```
Visiteur ──HTTPS──▶ Apache du VPS ──HTTP──▶ conteneur Docker « web »
    │              (certificat, port 443)    (les fichiers de l'application,
    │                                         sur 127.0.0.1:8088)
    └────────────────HTTPS────────────────▶ Supabase (comptes, données, photos)
```

- **L'application est dans un conteneur.** Rien d'autre que Docker n'est
  nécessaire sur le VPS pour elle, et elle ne peut pas entrer en conflit avec
  vos autres applications : elle n'écoute que sur un port local.
- **Apache reste la porte d'entrée**, comme pour votre autre application : il
  reçoit les visiteurs, s'occupe du HTTPS, et passe les requêtes au conteneur.
- **Aucune donnée n'est sur le VPS** : comptes, relevés et photos restent chez
  Supabase.

Dans tout le document, remplacez :

| Ce qui est écrit | Par |
|---|---|
| `app.exemple.be` | le nom de domaine de l'application |
| `utilisateur@vps` | votre accès SSH au VPS |

Les commandes marquées **PC** se lancent sur le poste de développement, dans
PowerShell, à la racine du dépôt. Celles marquées **VPS** se lancent sur le
serveur, en SSH.

---

## Étape 1 — Faire pointer le nom de domaine vers le VPS

Chez le gestionnaire de votre nom de domaine, créez un enregistrement **A** :

| Nom | Type | Valeur |
|---|---|---|
| `app` (pour `app.exemple.be`) | A | l'adresse IP du VPS |

À faire en premier : la propagation peut prendre de quelques minutes à
quelques heures, et l'étape 8 en a besoin. Pour vérifier — **PC** :

```powershell
nslookup app.exemple.be
```

La réponse doit donner l'adresse IP du VPS.

---

## Étape 2 — Vérifier le VPS

**VPS** :

```bash
docker compose version
apache2 -v
ss -ltn | grep :8088 || echo "port 8088 libre"
```

- Les deux premières commandes doivent afficher un numéro de version.
- La troisième doit répondre `port 8088 libre`. Sinon, choisissez un autre
  port (8089, 8090…) et utilisez-le partout où ce document écrit `8088`.

---

## Étape 3 — Créer le dossier de l'application

**VPS** :

```bash
sudo mkdir -p /opt/firestop
sudo chown $USER: /opt/firestop
```

---

## Étape 4 — Envoyer les fichiers de déploiement

**PC** :

```powershell
scp deploy\docker-compose.yml utilisateur@vps:/opt/firestop/
scp -r deploy\nginx utilisateur@vps:/opt/firestop/
scp deploy\apache-firestop.conf utilisateur@vps:/opt/firestop/
```

| Fichier | Rôle |
|---|---|
| `docker-compose.yml` | décrit le conteneur |
| `nginx/firestop.conf.template` | le serveur de fichiers **à l'intérieur** du conteneur, avec ses en-têtes de sécurité. Vous n'avez pas à y toucher. |
| `apache-firestop.conf` | le site à ajouter à Apache (étape 8) |

> Le conteneur utilise nginx pour servir les fichiers. C'est sans rapport avec
> votre Apache : il est enfermé dans le conteneur, et vous n'avez rien à
> installer ni à régler pour lui.

---

## Étape 5 — Écrire le fichier de réglages

**VPS** :

```bash
nano /opt/firestop/.env
```

avec ces deux lignes :

```ini
SUPABASE_HOST=abcdefghijklmnop.supabase.co
PORT_LOCAL=8088
```

- **`SUPABASE_HOST`** : l'adresse de votre projet Supabase, **sans**
  `https://` ni barre finale. C'est la valeur de `SUPABASE_URL` dans le
  fichier `env.json` du projet, privée de son `https://`.
- **`PORT_LOCAL`** : le port choisi à l'étape 2.

`SUPABASE_HOST` est le réglage à ne pas rater. Il est inscrit dans la
politique de sécurité de la page : s'il est faux, l'application s'affiche mais
**ne peut pas se connecter**.

---

## Étape 6 — Compiler l'application et l'envoyer

**PC** :

```powershell
flutter build web --release --dart-define-from-file=env.json --no-web-resources-cdn
scp -r build\web utilisateur@vps:/opt/firestop/web
```

La compilation produit le dossier `build\web` (environ 45 Mo), que la seconde
commande copie sur le VPS sous le nom `/opt/firestop/web`.

L'adresse et la clé du projet Supabase sont inscrites dans l'application à la
compilation, à partir de `env.json` : **changer de projet Supabase impose de
recompiler**.

À ce stade, le dossier du VPS doit contenir — **VPS** :

```bash
ls -a /opt/firestop
```

```
.env   apache-firestop.conf   docker-compose.yml   nginx   web
```

---

## Étape 7 — Démarrer le conteneur

**VPS** :

```bash
cd /opt/firestop
docker compose up -d
```

Vérifier qu'il répond :

```bash
docker compose ps
curl -sI http://127.0.0.1:8088/ | head -n 1
curl -sI http://127.0.0.1:8088/sqlite3.wasm | grep -i content-type
```

- `docker compose ps` doit montrer le service `web` à l'état `Up`, puis
  `(healthy)` après une trentaine de secondes.
- La première commande `curl` doit répondre `HTTP/1.1 200 OK`.
- La seconde doit répondre `Content-Type: application/wasm`.

L'application tourne, mais n'est pas encore visible d'Internet : c'est le rôle
de l'étape suivante.

---

## Étape 8 — Ajouter le site à Apache, avec le HTTPS

### 8.1 Activer les modules nécessaires

**VPS** :

```bash
sudo a2enmod proxy proxy_http ssl headers rewrite
```

Sans effet s'ils sont déjà activés pour votre autre application.

### 8.2 Installer le site

**VPS** :

```bash
sudo cp /opt/firestop/apache-firestop.conf /etc/apache2/sites-available/firestop.conf
sudo nano /etc/apache2/sites-available/firestop.conf
```

Dans le fichier, remplacez `app.exemple.be` par votre nom de domaine — et
`8088` par votre port, s'il est différent. Il doit ressembler à ceci :

```apache
<VirtualHost *:80>
    ServerName app.exemple.be

    ProxyPreserveHost On

    ProxyPass        / http://127.0.0.1:8088/
    ProxyPassReverse / http://127.0.0.1:8088/

    ErrorLog  ${APACHE_LOG_DIR}/firestop-error.log
    CustomLog ${APACHE_LOG_DIR}/firestop-access.log combined
</VirtualHost>
```

Puis l'activer :

```bash
sudo a2ensite firestop
sudo apache2ctl configtest
sudo systemctl reload apache2
```

`configtest` doit répondre `Syntax OK`. S'il signale une erreur, corrigez le
fichier avant de recharger : un Apache qui ne redémarre pas met aussi votre
autre application hors ligne.

### 8.3 Obtenir le certificat HTTPS

**VPS** :

```bash
sudo certbot --apache -d app.exemple.be
```

Certbot obtient le certificat Let's Encrypt, crée lui-même la version HTTPS du
site, et propose de rediriger le HTTP vers le HTTPS : **acceptez la
redirection**. Le renouvellement est ensuite automatique.

Si la commande `certbot` n'existe pas :

```bash
sudo apt install certbot python3-certbot-apache
```

> **N'ajoutez aucun en-tête de sécurité dans Apache** pour ce site
> (`Content-Security-Policy`, `X-Frame-Options`…). Le conteneur les pose déjà ;
> en double, le navigateur applique la plus stricte des deux politiques, et
> l'application peut se retrouver bloquée.

---

## Étape 9 — Régler Supabase

Dans le tableau de bord Supabase, **Authentication › URL Configuration** :

- **Site URL** : `https://app.exemple.be`
- **Redirect URLs** : ajoutez `https://app.exemple.be/**`

Sans cela, les liens des courriels envoyés par Supabase (confirmation de
compte, mot de passe oublié) renvoient vers une adresse qui n'est pas la
vôtre.

Vérifiez aussi que toutes les migrations du dossier `supabase/migrations/` ont
été exécutées sur le projet : une migration manquante bloque la
synchronisation.

---

## Étape 10 — Vérifier

Dans un navigateur, ouvrez `https://app.exemple.be` :

1. le cadenas HTTPS est présent ;
2. l'écran de connexion s'affiche, avec son texte ;
3. la connexion avec un compte administrateur aboutit ;
4. les chantiers apparaissent ;
5. l'export d'un chantier télécharge un fichier `.xlsm`.

Si une étape échoue, ouvrez les outils de développement du navigateur (touche
F12, onglet « Console ») : le message qui s'y trouve désigne presque toujours
la cause. Voir « Dépannage ».

**Le déploiement est terminé.**

---

## Mettre à jour l'application

À chaque nouvelle version, dans cet ordre.

**1. Les migrations d'abord.** Si la version en apporte, exécutez-les dans
l'éditeur SQL de Supabase avant tout le reste.

**2. Recompiler et envoyer** — **PC** :

```powershell
flutter build web --release --dart-define-from-file=env.json --no-web-resources-cdn
scp -r build\web utilisateur@vps:/opt/firestop/web.nouveau
```

**3. Basculer** — **VPS** :

```bash
cd /opt/firestop
rm -rf web.ancien
mv web web.ancien
mv web.nouveau web
docker compose restart web
```

Le `restart` est nécessaire : le conteneur reste attaché au dossier `web` tel
qu'il existait à son démarrage, et continuerait sinon de servir l'ancienne
version. L'interruption dure environ une seconde. Il n'y a rien à faire côté
Apache.

Les utilisateurs obtiennent la nouvelle version **au rechargement de la page**.
Si un poste garde l'ancienne, un rechargement forcé (Ctrl+F5) la remplace.

### Revenir à la version précédente

**VPS** :

```bash
cd /opt/firestop
mv web web.rate
mv web.ancien web
docker compose restart web
```

Attention : si la version retirée avait apporté une migration SQL, l'ancienne
version de l'application peut ne plus être compatible avec la base.

---

## Dépannage

| Ce qu'on voit | Cause probable | Remède |
|---|---|---|
| `503 Service Unavailable` | le conteneur est arrêté, ou Apache vise le mauvais port | `cd /opt/firestop && docker compose ps` ; comparer le port du site Apache à `PORT_LOCAL` |
| `Invalid command 'ProxyPass'` au `configtest` | les modules ne sont pas activés | refaire l'étape 8.1 |
| La page par défaut d'Apache, ou votre autre application, à la place de FireStop | le `ServerName` ne correspond pas au domaine, ou le site n'est pas activé | relire `firestop.conf` ; `sudo a2ensite firestop && sudo systemctl reload apache2` |
| Certbot échoue | le domaine ne pointe pas encore vers le VPS, ou le port 80 est fermé | refaire la vérification de l'étape 1 ; ouvrir les ports 80 et 443 du pare-feu |
| L'application s'affiche **sans aucun texte** | la police est bloquée | un en-tête `Content-Security-Policy` a été ajouté dans Apache : le retirer |
| Écran de connexion correct, mais la connexion échoue ; console : *« violates the following Content Security Policy directive: connect-src »* | `SUPABASE_HOST` est faux dans `.env` | le corriger, puis `docker compose up -d --force-recreate web` |
| Même message, alors que `SUPABASE_HOST` est juste | l'application a été compilée avec un autre `env.json` | recompiler avec le bon fichier |
| `403 Forbidden` | les fichiers envoyés ne sont pas lisibles par le conteneur | `chmod -R a+rX /opt/firestop/web` |
| Le conteneur redémarre en boucle | `.env` absent ou mal écrit | `docker compose logs web` |
| Après une mise à jour, l'ancienne version reste affichée | le `restart` a été oublié, ou le navigateur garde son cache | `docker compose restart web`, puis Ctrl+F5 |
| Bandeau « synchronisation bloquée » dans l'application | une migration SQL n'a pas été exécutée sur Supabase | exécuter les migrations manquantes |

Les journaux — **VPS** :

```bash
cd /opt/firestop && docker compose logs --tail 100 web     # le conteneur
sudo tail -n 50 /var/log/apache2/firestop-error.log        # Apache
```

---

## Commandes utiles

**VPS** :

```bash
cd /opt/firestop

docker compose ps              # état du conteneur
docker compose logs -f web     # journaux en direct (Ctrl+C pour quitter)
docker compose restart web     # redémarrer
docker compose down            # arrêter (rien n'est perdu)
docker compose up -d           # démarrer
```

Le conteneur redémarre seul avec le VPS.

Pour retirer complètement l'application du VPS :

```bash
cd /opt/firestop && docker compose down
sudo a2dissite firestop && sudo systemctl reload apache2
sudo rm /etc/apache2/sites-available/firestop*.conf
sudo rm -rf /opt/firestop
```

---

## À savoir sur la sécurité

- **La clé Supabase est dans les fichiers servis.** C'est normal : c'est une
  clé publique, la même que dans l'application Android. Ce sont les règles
  d'accès de la base qui protègent les données.
- **Le modèle Excel est téléchargeable** par quiconque connaît son adresse
  (`/assets/AS_BUILT_Resserages_RF_model_vierge.xlsm`) : il fait partie des
  fichiers de l'application. C'est un modèle vierge, mais il porte l'en-tête
  de la société.
- **L'inscription est ouverte** tant qu'elle n'est pas fermée dans Supabase :
  toute personne qui trouve l'adresse peut créer un compte. Un compte sans
  chantier ne voit aucun relevé, mais peut lire les listes de produits et les
  logos des clients.
- **Le conteneur n'est pas joignable d'Internet** : il n'écoute que sur
  `127.0.0.1`. Seul Apache l'atteint.

---

## Ce qui a été vérifié

Sur le poste de développement, dans Docker : le conteneur démarre et passe son
contrôle de santé ; placé derrière un Apache configuré comme à l'étape 8.2, il
rend l'application avec ses en-têtes de sécurité (une seule fois chacun), le
bon type pour les fichiers WebAssembly, et l'application pour une adresse
inconnue. L'application elle-même se charge dans Chrome derrière le conteneur
sans aucune violation de la politique de sécurité.

Ce qui n'a pas pu l'être ici, faute de VPS et de nom de domaine : les commandes
propres à votre serveur — `a2enmod`, `a2ensite`, `certbot`. Elles supposent un
Apache installé par les paquets Debian ou Ubuntu ; sur une autre distribution,
les noms de commandes et de dossiers diffèrent.
