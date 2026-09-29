// v600 NEO (29/09/2026) — nombre de gardiens + promeneurs d'une ville, lu
// sur `GET /supply/city?city=…` (route publique de BOB, la même que la preuve
// « 28 gardiens et promeneurs à Paris » du site). Sert à :
//   · l'accueil propriétaire à 0 demande : « N gardiens et promeneurs à
//     <ville> seront prévenus » ;
//   · la confirmation après « Publier » : « Envoyée à N gardiens et
//     promeneurs ».
// Jamais d'exception : null quand la ville est vide, le serveur muet ou le
// total à 0 (on n'affiche alors AUCUN chiffre, règle de Daniel : rien
// d'inventé). Petit cache mémoire de 10 min par ville.
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';

const String kSupplyCityEndpoint600 = '/supply/city';

class _SupplyEntry {
  _SupplyEntry(this.total, this.at);
  final int? total;
  final DateTime at;
}

final Map<String, _SupplyEntry> _supplyCache600 = <String, _SupplyEntry>{};
const Duration _supplyCacheTtl600 = Duration(minutes: 10);

/// Vide le cache (tests).
void resetSupplyCache600() => _supplyCache600.clear();

/// Total gardiens + promeneurs de [city], ou null (inconnu / 0 / ville vide).
Future<int?> fetchSupplyTotal600(String city, {ApiClient? api}) async {
  final c = city.trim();
  if (c.isEmpty || c.contains('@')) return null;
  final key = c.toLowerCase();
  final hit = _supplyCache600[key];
  if (hit != null && DateTime.now().difference(hit.at) < _supplyCacheTtl600) {
    return hit.total;
  }
  int? total;
  try {
    final client = api ??
        (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient());
    final res = await client
        .get(kSupplyCityEndpoint600, queryParameters: <String, dynamic>{'city': c})
        .timeout(const Duration(seconds: 4));
    if (res is Map) {
      final t = res['total'];
      if (t is num && t > 0) {
        total = t.toInt();
      } else {
        final s = (res['sitters'] as num?)?.toInt() ?? 0;
        final w = (res['walkers'] as num?)?.toInt() ?? 0;
        if (s + w > 0) total = s + w;
      }
    }
  } catch (_) {
    total = null;
  }
  _supplyCache600[key] = _SupplyEntry(total, DateTime.now());
  return total;
}
