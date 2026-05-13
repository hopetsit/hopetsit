/// Exception thrown when the API returns an unexpected response.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final dynamic details;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message, details: $details)';
}

/// v23.1 part 125 — Phase 2 audit C3.
/// Couche de transport : pas de réseau (avion, WiFi décroché, DNS KO).
/// Distincte d'`ApiException` pour que l'UI puisse afficher "Tu n'as pas
/// de réseau, reconnecte-toi" au lieu d'un message d'erreur HTTP.
class NetworkUnreachableException implements Exception {
  NetworkUnreachableException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'NetworkUnreachableException($message)';
}

/// v23.1 part 125 — Phase 2 audit C3.
/// Le réseau était joignable mais le backend n'a pas répondu dans le
/// délai imparti (Render cold-start fréquent — 30-45s). L'UI peut
/// proposer un retry direct.
class ApiTimeoutException implements Exception {
  ApiTimeoutException(this.message, {this.elapsed});
  final String message;
  final Duration? elapsed;

  @override
  String toString() => 'ApiTimeoutException($message, elapsed: $elapsed)';
}
