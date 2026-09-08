# Polices du rapport PDF

Déposez ici deux fichiers TrueType, sous ces noms exacts :

```
assets/fonts/Report-Regular.ttf
assets/fonts/Report-Bold.ttf
```

`Report-Bold.ttf` est facultatif ; `Report-Regular.ttf` seul suffit à corriger
le problème décrit ci-dessous.

## Pourquoi c'est nécessaire

Sans ces fichiers, le rendu retombe sur **Helvetica**, police standard du format
PDF. Elle couvre les accents français, mais pas l'ensemble d'Unicode. En sont
absents, entre autres :

| Caractère | Nom | D'où il vient |
|---|---|---|
| `—` | tiret cadratin | correction automatique des claviers |
| `’` | apostrophe typographique | idem, sur iOS et Android |
| `œ` | ligature | « manœuvre », « cœur » |
| `…` | points de suspension | correction automatique |

Ces caractères sont alors **silencieusement omis** du document — un
avertissement en console, aucune exception. « manœuvre » devient « manuvre ».

Les libellés produits par l'application s'en tiennent au sous-ensemble sûr. Mais
le nom d'un client, l'observation saisie sur le terrain et le sous-titre d'un
gabarit sont du texte libre : sur un rapport de conformité remis à un client,
perdre des caractères sans le signaler n'est pas acceptable.

## Quelle police choisir

N'importe quelle TTF sous licence permettant la redistribution et couvrant le
latin étendu convient — Roboto, Open Sans, Source Sans, Noto Sans. Renommez-la
selon les noms ci-dessus.

Attention au poids : une police complète pèse plusieurs centaines de kilooctets
et sera embarquée dans **chaque** PDF produit. Un sous-ensemble latin suffit
largement.
