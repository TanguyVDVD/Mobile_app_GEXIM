import 'dart:math' as math;

const Duration _base = Duration(seconds: 5);
const Duration _ceiling = Duration(minutes: 30);
const int _maxDoublings = 10;

/// Délai avant la prochaine tentative, après [attempts] échecs.
///
/// Croissance exponentielle plafonnée à 30 min, plus un bruit de ±20 %.
///
/// Le bruit n'est pas cosmétique : quinze tablettes qui quittent le chantier au
/// même moment retrouvent le réseau à la même seconde. Sans désynchronisation,
/// elles retenteraient toutes en cadence et transformeraient une panne réseau
/// passagère en pic de charge auto-entretenu sur le serveur.
Duration backoffDelay(int attempts, {math.Random? random}) {
  final rng = random ?? math.Random();
  final doublings = attempts.clamp(0, _maxDoublings);
  final grown = _base * math.pow(2, doublings).toDouble();
  final capped = grown > _ceiling ? _ceiling : grown;

  final jitter = 1.0 + (rng.nextDouble() * 0.4 - 0.2);
  return Duration(
    milliseconds: (capped.inMilliseconds * jitter).round(),
  );
}

/// Erreur remontée par la couche distante, qualifiée pour la politique de rejeu.
class SyncException implements Exception {
  const SyncException(this.message, {required this.isTransient, this.statusCode});

  /// Construit l'exception à partir d'un code HTTP.
  factory SyncException.fromStatus(int statusCode, String message) {
    // 5xx = le serveur a un problème, il passera. 429 = ralentis. 408 = timeout.
    // Tout le reste en 4xx est une erreur de notre côté : inutile d'insister.
    final transient =
        statusCode >= 500 || statusCode == 429 || statusCode == 408;
    return SyncException(
      message,
      isTransient: transient,
      statusCode: statusCode,
    );
  }

  /// Coupure réseau, DNS, TLS : par nature temporaire.
  const SyncException.network(this.message)
      : isTransient = true,
        statusCode = null;

  final String message;
  final bool isTransient;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'SyncException: $message'
      : 'SyncException($statusCode): $message';
}
