/// Le numéro d'un point est un **texte** : « 12 », mais aussi « 1.40 » ou
/// « A-07 », selon le repérage du chantier. Deux choses ne vont alors plus de
/// soi, et vivent ici : dans quel ordre les ranger, et lequel proposer ensuite.
library;

final _chiffres = RegExp(r'\d+');
final _morceaux = RegExp(r'\d+|\D+');

/// Ordre de lecture d'un humain : « 2 » avant « 10 », « 1.9 » avant « 1.40 ».
///
/// L'ordre alphabétique rangerait « 10 » avant « 2 », et le relevé comme le
/// classeur exporté sortiraient dans un ordre que personne ne reconnaît. Les
/// suites de chiffres sont donc comparées comme des nombres, le reste comme
/// du texte, sans tenir compte de la casse.
///
/// Un numéro absent se range après tous les autres.
int comparerNumeros(String? a, String? b) {
  if (a == null || b == null) {
    return a == b ? 0 : (a == null ? 1 : -1);
  }

  final ma = _morceaux.allMatches(a).map((m) => m[0]!).toList();
  final mb = _morceaux.allMatches(b).map((m) => m[0]!).toList();

  for (var i = 0; i < ma.length && i < mb.length; i++) {
    final na = BigInt.tryParse(ma[i]);
    final nb = BigInt.tryParse(mb[i]);

    final ecart = na != null && nb != null
        ? na.compareTo(nb)
        : ma[i].toLowerCase().compareTo(mb[i].toLowerCase());
    if (ecart != 0) return ecart;
  }
  return ma.length.compareTo(mb.length);
}

/// Le numéro qui suit [numero] : sa **dernière** suite de chiffres, plus un.
///
/// « 12 » → « 13 », « 1.40 » → « 1.41 », « A-09 » → « A-10 » — les zéros de
/// tête sont gardés, pour ne pas casser un repérage à largeur fixe. `null` si
/// [numero] ne contient aucun chiffre : il n'y a alors rien à proposer, et
/// mieux vaut un champ vide qu'une invention.
String? numeroSuivant(String numero) {
  final dernier = _chiffres.allMatches(numero).lastOrNull;
  if (dernier == null) return null;

  final suivant = (BigInt.parse(dernier[0]!) + BigInt.one)
      .toString()
      .padLeft(dernier[0]!.length, '0');
  return numero.replaceRange(dernier.start, dernier.end, suivant);
}
