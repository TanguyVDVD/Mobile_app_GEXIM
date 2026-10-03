// Produit un classeur d'exemple, pour le regarder dans Excel.
//
//   cd packages/firestop_excel
//   dart run tool/exemple.dart ..\..\exemple.xlsm [nombre de fiches]
//
// Les tests lisent le XML ; ils ne disent pas si Excel ouvre le classeur sans
// le « réparer », ni si la fiche est belle. Cela se vérifie à l'œil, ici.
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:firestop_excel/firestop_excel.dart';

const modele = '../../AS_BUILT_Resserages_RF_model_vierge.xlsm';

void main(List<String> args) {
  final sortie = args.isEmpty ? 'exemple.xlsm' : args[0];
  final nombre = args.length > 1 ? int.parse(args[1]) : 3;

  final octets = File(modele).readAsBytesSync();
  // Faute de vrais clichés sous la main, l'image d'en-tête du modèle sert de
  // logo et de photo : c'est un JPEG large, il montre l'étirement.
  final image = Uint8List.fromList(
    ZipDecoder()
        .decodeBytes(octets)
        .firstWhere((f) => f.name == 'xl/media/image6.jpeg')
        .readBytes()!,
  );

  final classeur = const AsBuiltWorkbook().build(
    modele: octets,
    data: ReportData(
      client: const ReportClient(
        name: 'Client Exemple SA',
        address: 'Rue du Test 1\n4000 Liège',
      ),
      project: const ReportProject(name: 'Hall logistique', code: '2026-118'),
      clientLogo: image,
      points: [
        for (var i = 1; i <= nombre; i++)
          ReportPoint(
            number: '$i',
            capturedAt: DateTime(2026, 10, 3),
            purchaseOrder: 'PO-4471',
            building: 'Bloc A',
            floor: 'Niveau ${i % 3}',
            configuration: 'Traversée de paroi verticale',
            configurationDetail: 'Chemin de câbles',
            eiLevel: 'EI60',
            supplier: 'Promat',
            productType: 'Mortier',
            products: const ['Promastop-M', '', 'Promaseal-A'],
            photos: [
              for (var k = 0; k < (i - 1) % 3; k++) ReportPhoto(bytes: image),
            ],
          ),
      ],
    ),
  );

  File(sortie).writeAsBytesSync(classeur);
  stdout.writeln('$sortie : ${classeur.length} octets, $nombre fiches');
}
