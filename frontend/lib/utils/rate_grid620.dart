// 620 (PAM, 24/10/2026 — complément de Daniel « vérifie aussi l'inscription,
// les tarifs ») — GRILLE DE TARIFS PAR SERVICE à l'inscription d'un gardien :
// la même qu'au profil (garde par jour / nuit, visite à domicile par visite +
// durée 30 | 60). Les valeurs partent dans `POST /auth/signup` ET, dès que le
// compte a un jeton (entrée directe ou après le code e-mail), dans
// `PUT /users/me/profile` + `PUT /sitters/me/rates` (même chemin que l'écran
// « Mes tarifs ») : le profil public montre « 12 €/visite » sans attendre.
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../data/network/api_client.dart';
import '../data/network/api_endpoints.dart';
import 'logger.dart';

const String kPendingRateGridKey620 = 'pending_rate_grid_620';

/// `defaultRateType` déduit de la grille : `visit` quand seules les visites
/// sont tarifées, sinon `day` quand un tarif jour existe, sinon `hour`.
String defaultRateType620({double? daily, double? visit, double? hourly}) {
  final d = (daily ?? 0) > 0, v = (visit ?? 0) > 0, h = (hourly ?? 0) > 0;
  if (v && !d) return 'visit';
  if (d) return 'day';
  if (h) return 'hour';
  return v ? 'visit' : 'day';
}

/// Grille telle qu'envoyée au serveur (clés du contrat §A.3).
Map<String, dynamic> rateGridPayload620({
  double? daily,
  double? weekly,
  double? monthly,
  double? hourly,
  double? visit,
  int visitDurationMinutes = 30,
}) {
  double? pos(double? x) => (x ?? 0) > 0 ? x : null;
  return <String, dynamic>{
    if (pos(daily) != null) 'dailyRate': daily,
    if (pos(weekly) != null) 'weeklyRate': weekly,
    if (pos(monthly) != null) 'monthlyRate': monthly,
    if (pos(hourly) != null) 'hourlyRate': hourly,
    'visitRate': pos(visit) ?? 0,
    'visitDurationMinutes': visitDurationMinutes >= 60 ? 60 : 30,
    'defaultRateType': defaultRateType620(daily: daily, visit: visit, hourly: hourly),
  };
}

/// Mémorise la grille choisie au wizard (envoyée dès qu'un jeton existe).
Future<void> savePendingRateGrid620(Map<String, dynamic> grid) async {
  try {
    await GetStorage().write(kPendingRateGridKey620, grid);
  } catch (_) {/* stockage indisponible : la grille est déjà dans le signup */}
}

/// Envoie la grille en attente (gardien) : `PUT /users/me/profile` puis
/// `PUT /sitters/me/rates`. Jamais fatal ; vrai si envoyée.
Future<bool> pushPendingRateGrid620({ApiClient? api}) async {
  final storage = GetStorage();
  final raw = storage.read(kPendingRateGridKey620);
  if (raw is! Map || raw.isEmpty) return false;
  final grid = Map<String, dynamic>.from(raw);
  final client = api ?? (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient());
  try {
    await client.put(ApiEndpoints.myProfile, body: grid, requiresAuth: true);
    try {
      await client.put('${ApiEndpoints.sitters}/me/rates',
          body: <String, dynamic>{
            'hourlyRate': grid['hourlyRate'] ?? 0,
            'dailyRate': grid['dailyRate'] ?? 0,
            'weeklyRate': grid['weeklyRate'] ?? 0,
            'monthlyRate': grid['monthlyRate'] ?? 0,
            'visitRate': grid['visitRate'] ?? 0,
            'visitDurationMinutes': grid['visitDurationMinutes'] ?? 30,
          },
          requiresAuth: true);
    } catch (e) {
      AppLogger.logError('620 grille : /sitters/me/rates', error: e);
    }
    await storage.remove(kPendingRateGridKey620);
    return true;
  } catch (e) {
    AppLogger.logError('620 grille de tarifs non envoyée (sera retentée)', error: e);
    return false;
  }
}
