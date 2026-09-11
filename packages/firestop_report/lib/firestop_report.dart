/// Rendu des rapports de conformité calfeutrement.
///
/// Dart pur : aucune dépendance Flutter, aucune entrée-sortie. Le même code
/// produit l'aperçu dans l'application et le document définitif côté serveur.
///
/// Le rapport est **un formulaire fixe rempli**, pas une mise en page à
/// composer : il n'y a donc ni gabarit, ni couleur d'accentuation, ni papier à
/// en-tête à configurer. Tout cela a existé et a été retiré — le document est
/// désormais toujours la fiche AS BUILT.
library;

export 'src/as_built_builder.dart';
export 'src/report_data.dart';
