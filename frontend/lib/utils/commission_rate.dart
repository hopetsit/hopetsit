// v613 — taux de commission HoPetSit affiché dans l'app.
//
// Le taux n'est JAMAIS figé ici : il vient du serveur, qui le calcule avec la
// même fonction que la réservation (`commissionRateForProvider` dans
// backend/src/utils/pricing.js : 15 % pour un prestataire Top, 20 % sinon).
//   • écran « Envoyer une demande » : GET /pricing/commission-rate ;
//   • facture PDF : relu sur la facture elle-même (commission ÷ net
//     prestataire), puisque la commission est calculée SUR le tarif du
//     prestataire et ajoutée en plus.

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// Taux valide renvoyé par le serveur (fraction entre 0 et 1 exclus), sinon null.
double? parseCommissionRate(Object? raw) {
  final v = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
  if (v == null || v.isNaN || v <= 0 || v >= 1) return null;
  return v;
}

/// « 15 », « 20 », « 17.5 » : le pourcentage à afficher pour un taux.
String commissionPercentLabel(double rate) {
  final pct = (rate * 1000).round() / 10; // une décimale au plus
  return pct == pct.roundToDouble()
      ? pct.toStringAsFixed(0)
      : pct.toStringAsFixed(1);
}

/// Taux relu sur une facture : commission ÷ net prestataire. Null si les
/// montants ne permettent pas de le relire (facture vide ou incomplète).
double? commissionRateFromAmounts(num? commission, num? netPayout) {
  final c = commission?.toDouble() ?? 0;
  final n = netPayout?.toDouble() ?? 0;
  if (c <= 0 || n <= 0) return null;
  return parseCommissionRate(c / n);
}

/// Libellé traduit contenant « @percent » (ex. « Commission HoPetSit
/// (@percent%) »). Taux connu → pourcentage réel ; taux inconnu → la
/// parenthèse disparaît (jamais un pourcentage supposé).
String commissionLabel(String template, double? rate) {
  if (rate != null) {
    return template.replaceAll('@percent', commissionPercentLabel(rate));
  }
  return template
      .replaceAll(RegExp(r'\s*[(（][^()（）]*@percent[^()（）]*[)）]'), '')
      .replaceAll('@percent', '')
      .trim();
}

/// Taux d'une facture tel que le serveur l'affiche : seuls les deux taux du
/// barème (15 % Top, 20 %) sont reconnus ; une facture ancienne ou
/// incomplète n'affiche pas de pourcentage.
double? invoiceCommissionRate(num? commission, num? netPayout) {
  final r = commissionRateFromAmounts(commission, netPayout);
  if (r == null) return null;
  final pct = (r * 100).round();
  return (pct == 15 || pct == 20) ? pct / 100 : null;
}

/// 613 §9 (ZOE, émulateur Android) — taux de commission du PRESTATAIRE
/// CONNECTÉ (gardien ou promeneur), pour le bloc « Votre gain estimé » d'une
/// annonce : un promeneur Top voyait « Client paie 120 € » alors que le
/// propriétaire paiera 115 € (+15 %). Même route que l'écran de demande.
/// Null si inconnu (pas prestataire, pas d'id, serveur muet) : l'appelant
/// garde alors son estimation habituelle.
final Map<String, double> _myRateCache613 = <String, double>{};

Future<double?> myProviderCommissionRate613(String role, {ApiClient? api}) async {
  final r = role.toLowerCase();
  if (r != 'walker' && r != 'sitter') return null;
  try {
    final profile = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
    final id = (profile?['id'] ?? profile?['_id'])?.toString() ?? '';
    if (id.isEmpty) return null;
    final key = '$r:$id';
    final hit = _myRateCache613[key];
    if (hit != null) return hit;
    final client = api ?? (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient());
    final res = await client.get(
      ApiEndpoints.pricingCommissionRate,
      queryParameters: <String, dynamic>{'providerId': id, 'role': r},
    );
    final rate = res is Map ? parseCommissionRate(res['commissionRate']) : null;
    if (rate != null) _myRateCache613[key] = rate;
    return rate;
  } catch (_) {
    return null;
  }
}

/// Tests : vide le cache du taux du prestataire connecté.
void resetMyProviderCommissionRate613() => _myRateCache613.clear();
