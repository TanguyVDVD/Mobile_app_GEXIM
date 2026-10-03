import 'package:firestop_tracker/core/numero_point.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le numéro d'un point est un texte. Ce qui en découle se vérifie ici : dans
/// quel ordre le relevé et le classeur les rangent, et lequel la création
/// propose ensuite.
void main() {
  group('l\'ordre des numeros', () {
    List<String?> tries(List<String?> numeros) =>
        [...numeros]..sort(comparerNumeros);

    test('est celui d\'un lecteur, pas celui de l\'alphabet', () {
      // L'alphabet rangerait « 10 » avant « 2 », et « 1.40 » avant « 1.9 ».
      expect(tries(['10', '2', '1']), ['1', '2', '10']);
      expect(tries(['1.40', '1.9', '1.167']), ['1.9', '1.40', '1.167']);
      expect(tries(['2.1', '1.40', '10.3']), ['1.40', '2.1', '10.3']);
    });

    test('melange chiffres et lettres sans se perdre', () {
      expect(tries(['A-10', 'A-9', 'B-1']), ['A-9', 'A-10', 'B-1']);
      expect(tries(['12b', '12', '12a']), ['12', '12a', '12b']);
      // Sans tenir compte de la casse.
      expect(comparerNumeros('a-1', 'A-1'), 0);
    });

    test('range les fiches sans numero a la fin', () {
      expect(tries([null, '3', null, '1']), ['1', '3', null, null]);
    });

    test('ne bute pas sur un numero demesure', () {
      // Plus long qu'un entier machine : comparé quand même, sans exception.
      expect(
        comparerNumeros('99999999999999999999998', '99999999999999999999999'),
        lessThan(0),
      );
    });
  });

  group('le numero propose ensuite', () {
    test('incremente la derniere suite de chiffres', () {
      expect(numeroSuivant('12'), '13');
      expect(numeroSuivant('1.40'), '1.41');
      expect(numeroSuivant('1.99'), '1.100');
      expect(numeroSuivant('A-07 bis'), 'A-08 bis');
    });

    test('garde les zeros de tete', () {
      // Un repérage à largeur fixe ne doit pas passer de « 009 » à « 10 ».
      expect(numeroSuivant('009'), '010');
      expect(numeroSuivant('A-09'), 'A-10');
      expect(numeroSuivant('099'), '100');
    });

    test('ne propose rien quand il n\'y a pas de chiffre', () {
      expect(numeroSuivant('Gaine technique'), isNull);
    });
  });
}
