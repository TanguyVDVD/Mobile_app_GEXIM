# Gabarit de rapport

Un gabarit décrit **la mise en page du rapport PDF** d'un client : couleur
d'accentuation, page de garde, disposition des clichés, champs affichés sur
chaque fiche. C'est un objet JSON stocké dans `report_templates.config`.

Un client sans gabarit reprend celui marqué `is_default`.

> **Rien ne peut casser un rapport.** Chaque clé est lue avec tolérance : une
> valeur absente, mal orthographiée ou d'un mauvais type retombe sur son défaut.
> Refuser de produire un document contractuel pour une virgule mal placée serait
> le mauvais arbitrage. Une clé inconnue est simplement ignorée — sans
> avertissement, donc relisez les noms.

---

## Exemple complet

Toutes les clés reconnues, avec leurs valeurs par défaut :

```json
{
  "version": 1,

  "brand": {
    "accentColor": "#C8102E",
    "showLogo": true
  },

  "cover": {
    "enabled": true,
    "subtitle": "Rapport de conformité - calfeutrement de traversées",
    "showSummary": true
  },

  "pointCard": {
    "layout": "twoUp",
    "fields": ["ref", "location", "materials", "description", "author", "date"],
    "pageBreak": "perPoint"
  },

  "margins": {
    "top": 17,
    "right": 11,
    "bottom": 17,
    "left": 11
  },

  "header": {
    "left": "{{client.name}}",
    "right": "{{project.name}}"
  },

  "footer": {
    "center": "Page {{page}}/{{pages}} - généré le {{date}}"
  }
}
```

---

## Référence

### `brand`

| Clé | Valeurs | Par défaut |
|---|---|---|
| `accentColor` | `#RRGGBB` ou `#AARRGGBB` | `#C8102E` |
| `showLogo` | `true` / `false` | `true` |

La couleur d'accentuation habille le filet de la page de garde, l'en-tête du
tableau récapitulatif et le bandeau de chaque fiche. Une valeur illisible
retombe sur le rouge coupe-feu.

`showLogo` à `false`, ou un client sans logo, remplace l'image de couverture par
la raison sociale en gros caractères.

### `cover`

| Clé | Valeurs | Par défaut |
|---|---|---|
| `enabled` | `true` / `false` | `true` |
| `subtitle` | texte libre | *« Rapport de conformité - calfeutrement de traversées »* |
| `showSummary` | `true` / `false` | `true` |

`showSummary` produit un tableau récapitulatif — numéro, localisation,
matériaux, complétude du dossier — sur une page distincte.

La page de garde signale toujours le nombre de traversées **dont le dossier est
incomplet**. Ce n'est pas désactivable : c'est la première chose qu'un auditeur
vérifie, et le taire rendrait le document trompeur.

### `pointCard`

| Clé | Valeurs | Par défaut |
|---|---|---|
| `layout` | `twoUp`, `stacked`, `grid`, `none` | `twoUp` |
| `fields` | liste parmi `ref`, `location`, `materials`, `description`, `author`, `date` | tous |
| `pageBreak` | `perPoint`, ou toute autre valeur | `perPoint` |

**Dispositions**

- `twoUp` — avant et après côte à côte. La lecture par comparaison, la plus
  parlante pour un contrôle.
- `stacked` — l'un sous l'autre, en pleine largeur. Quand le détail compte plus
  que la comparaison.
- `grid` — grille 2×2 : les deux clichés réglementaires plus deux
  complémentaires.
- `none` — aucun cliché, récapitulatif textuel seul.

**Champs**

Une liste vide ou entièrement inconnue affiche **tous** les champs : une fiche
muette est pire qu'une fiche trop bavarde.

**Pagination**

`perPoint` place une traversée par page. La plupart des cahiers des charges
l'exigent, pour qu'une fiche puisse être extraite et transmise seule. Toute
autre valeur (`flow`, par exemple) enchaîne les fiches à la suite.

### `margins`

Marges en **millimètres**, bornées entre 0 et 60. Défauts : 17 en haut et en
bas, 11 sur les côtés.

Ce réglage n'existe que pour le papier à en-tête : chaque document type imprime
dans ses propres zones, et le contenu doit s'en écarter. Sans marges adaptées,
le texte se poserait par-dessus le logo ou les mentions légales.

Une valeur aberrante est ramenée dans les bornes plutôt que refusée — au-delà
de 60 mm, la zone utile devient trop étroite pour deux clichés côte à côte, et
la mise en page échouerait à la génération.

### `header` et `footer`

| Clé | Rôle |
|---|---|
| `left` | aligné à gauche |
| `center` | centré (alias accepté : `text`) |
| `right` | aligné à droite |

Substitutions disponibles :

| Marqueur | Remplacé par |
|---|---|
| `{{client.name}}` | raison sociale du client |
| `{{project.name}}` | nom du chantier |
| `{{page}}` | numéro de la page courante |
| `{{pages}}` | nombre total de pages |
| `{{date}}` | date de génération, `JJ/MM/AAAA` |

Un bandeau dont les trois zones sont vides n'occupe aucune place.

---

## Deux variantes prêtes à l'emploi

### Dossier de contrôle détaillé

Chaque traversée sur sa page, quatre clichés, sans page de garde — pour une
annexe jointe à un rapport plus large.

```json
{
  "version": 1,
  "brand": { "accentColor": "#0057B8" },
  "cover": { "enabled": false, "showSummary": true },
  "pointCard": {
    "layout": "grid",
    "fields": ["ref", "location", "materials", "description", "author", "date"],
    "pageBreak": "perPoint"
  },
  "header": { "left": "{{client.name}}", "right": "{{project.name}}" },
  "footer": { "center": "Annexe technique - page {{page}}/{{pages}}" }
}
```

### Synthèse compacte

Fiches enchaînées, sans récapitulatif ni observations : un document court, à
remettre en fin de chantier.

```json
{
  "version": 1,
  "brand": { "accentColor": "#2E7D32", "showLogo": true },
  "cover": { "enabled": true, "showSummary": false,
             "subtitle": "Synthèse des traversées calfeutrées" },
  "pointCard": {
    "layout": "twoUp",
    "fields": ["ref", "location", "materials"],
    "pageBreak": "flow"
  },
  "header": { "right": "{{project.name}}" },
  "footer": { "center": "{{date}} - page {{page}}/{{pages}}" }
}
```

---

## Poser un gabarit

Depuis l'application : *Clients › (un client) › **Mise en page du rapport***.
Couleur, disposition, marges, page de garde, papier à en-tête et logo s'y
règlent sans écrire une ligne de JSON.

Le JSON reste utile pour dupliquer une mise en page d'un client à l'autre, ou
pour un réglage que le formulaire n'expose pas :

```sql
-- 1. Créer le gabarit
insert into public.report_templates (id, name, config, is_default)
values (gen_random_uuid(), 'Annexe technique bleue', '{ ... }'::jsonb, false);

-- 2. L'attribuer à un client
update public.clients
   set template_id = (select id from public.report_templates
                       where name = 'Annexe technique bleue')
 where name = 'Nom du client';
```

Le gabarit redescend sur les tablettes à la synchronisation suivante, et le
rapport suivant l'utilise.

---

## Papier à en-tête

Le rapport peut se composer **par-dessus votre document type**. Déposez-le
depuis *Clients › (un client) › Mise en page du rapport* : un PDF d'une page, ou
une image.

Deux fonds distincts sont possibles — la page de garde et les pages suivantes,
puisque la plupart des papiers à en-tête ont une première page chargée et des
pages de suite allégées. À défaut de second fichier, la page de garde est
reprise partout.

**Le compromis à connaître.** Le PDF fourni est converti en image à 150 points
par pouce avant d'être appliqué. Son texte n'est donc plus sélectionnable dans
le rapport final, et un agrandissement extrême le montrerait pixelisé. En
échange, n'importe quel document fonctionne — y compris ceux aux polices
exotiques qu'un analyseur PDF rendrait de travers.

Pensez à ajuster les **marges** en conséquence : c'est le seul moyen d'éviter
que le texte ne se pose sur votre en-tête imprimé.

## Ce que le gabarit ne fait pas

- **Il ne change pas la structure du document.** L'ordre — page de garde,
  récapitulatif, fiches — est fixe.
- **Il n'embarque pas de police.** `fontFamily` n'est pas lu : les polices se
  déposent dans `assets/fonts/`.
