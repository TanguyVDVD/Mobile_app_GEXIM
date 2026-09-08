import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Génère un identifiant pour une nouvelle entité, **côté client**.
///
/// Pilier de l'architecture offline-first : un opérateur crée un point dans un
/// sous-sol en béton, sans réseau. L'identité de ce point doit donc exister
/// immédiatement, sans aller-retour serveur.
///
/// UUID **v7** et non v4 : les v7 sont préfixés d'un timestamp milliseconde,
/// donc lexicographiquement triables par ordre de création. Deux bénéfices
/// concrets :
///  - les index B-tree Postgres restent compacts (insertions en fin d'index,
///    au lieu d'écritures aléatoires comme avec des v4) ;
///  - un tri par clé primaire donne l'ordre chronologique gratuitement.
String newId() => _uuid.v7();
