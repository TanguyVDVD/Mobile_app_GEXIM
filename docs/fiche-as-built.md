# La fiche AS BUILT

Le rapport de conformité est **un formulaire fixe rempli**, pas une mise en page
composée. Chaque page reprend `template_rapport.png` — la fiche « Resserrage RF
— AS BUILT » — et l'application y pose les valeurs.

Il n'y a donc **rien à configurer** : ni couleur, ni marges, ni page de garde, ni
papier à en-tête. Ce qui varie d'un document à l'autre, ce sont les données.

---

## Pagination

- **Chaque traversée commence sur une page neuve.** Deux traversées ne
  partagent jamais une page : une fiche s'extrait du dossier sans emporter la
  moitié de la suivante.
- Une traversée **peut occuper plusieurs pages**. Le formulaire offre deux cases
  de photo ; au-delà, les clichés passent sur des pages de suite, six par page.
- Les pages de suite ne reprennent pas le formulaire — ce serait afficher une
  vingtaine de cases vides — mais portent le numéro de traversée et le chantier.
  Un dossier se photocopie et se transmet par extraits : une page détachée doit
  rester identifiable.

---

## Ce qui remplit chaque ligne

| Ligne du formulaire | Origine |
|---|---|
| Date | la date de la traversée, modifiable sur la fiche |
| Numéro *(en-tête)* | le numéro de la traversée — une page valant une fiche |
| Client · logo · adresse | le client du chantier ; **logo et adresse obligatoires** |
| Numéro Projet | le chantier (*Numéro de projet*) |
| Intitulé Projet | le chantier (*Nom du chantier*) |
| Purchase Order | la traversée |
| Bâtiment(s) concerné(s) | la traversée |
| Etage | la traversée, de -3 à 5 |
| Numéro du point | attribué par le serveur à la synchronisation |
| Photographies | les deux premiers clichés ; les suivants en page de suite |
| Configuration | liste *Configurations* |
| Configuration détaillée | liste *Configurations détaillées* |
| Niveau EI | liste *Niveaux EI* |
| Fournisseur de produit utilisé | liste *Fournisseurs* |
| Type de produit utilisé | liste *Types de produit* |
| Produit utilisé (1) à (5) | liste *Produits*, **cinq emplacements positionnels** |

Un champ non renseigné s'imprime en tiret, jamais en blanc : une case vide se
lirait comme un défaut d'impression, là où c'est une lacune du dossier.

Les cinq emplacements produit sont **positionnels**. Retirer le deuxième ne fait
pas remonter le troisième : le rapport d'un chantier déjà livré porte ces
numéros-là.

---

## Les listes déroulantes

Six listes, administrées depuis **Paramètres** (administrateur uniquement) :
Configurations, Configurations détaillées, Niveaux EI, Fournisseurs, Types de
produit, Produits.

Ce sont des **données**, pas du code : une entrée s'ajoute, se renomme, se
réordonne et se retire sans migration ni déploiement. Les valeurs de départ sont
installées par `bootstrap.sql`.

Quelques règles qui comptent :

- **Retirer n'efface pas.** Une entrée retirée n'est plus proposée à la saisie,
  mais les traversées qui la désignent la conservent — et un rapport régénéré
  deux ans plus tard rend le même document.
- **Renommer change le passé.** Les fiches déjà relevées porteront le nouveau
  libellé. Corriger une faute de frappe, oui ; recycler une entrée pour un autre
  produit, non — créez-en une.
- **L'ordre est celui de l'administrateur**, pas l'alphabet : celui-ci placerait
  EI120 avant EI30.

---

## Modifier le formulaire lui-même

`template_rapport.png` fait 562 × 709 px. Les coordonnées de chaque case sont
relevées **sur cette image**, en pixels, et rassemblées dans `_Zones`
(`packages/firestop_report/lib/src/as_built_builder.dart`).

**Toute retouche du PNG impose de les relever à nouveau.** Elles ont été
obtenues en détectant les traits du tableau sur l'image, puis vérifiées en
superposant les rectangles sur le gabarit.

Deux points à ne pas défaire :

- Le fond est posé **centré, à l'échelle**, jamais étiré : le rapport de forme
  du PNG (0,793) n'est pas celui de l'A4 (0,707), et l'étirer désaccorderait
  toutes les cases de leurs libellés imprimés.
- Les textes d'exemple « logo client » et « adresse client » ont été retirés du
  PNG. Ne les réintroduisez pas : rien ne les masque au rendu, ils
  apparaîtraient sous les valeurs réelles.

Pour inspecter un document dont la mise en page surprend :
`AsBuiltBuilder().build(data, compresser: false)` écrit les flux de contenu en
clair, ce qui rend le PDF lisible dans un éditeur de texte.
