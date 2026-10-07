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
  _SupplyEntry(this.total, this.at, {this.sitters, this.walkers});
  final int? total;
  final int? sitters; // 613 — détail par rôle (null si le serveur ne le dit pas)
  final int? walkers;
  final DateTime at;

  int? pick(String? onlyRole) {
    if (onlyRole == 'walker') return (walkers ?? 0) > 0 ? walkers : null;
    if (onlyRole == 'sitter') return (sitters ?? 0) > 0 ? sitters : null;
    return total;
  }
}

final Map<String, _SupplyEntry> _supplyCache600 = <String, _SupplyEntry>{};
const Duration _supplyCacheTtl600 = Duration(minutes: 10);

/// Vide le cache (tests).
void resetSupplyCache600() => _supplyCache600.clear();

/// Total gardiens + promeneurs de [city], ou null (inconnu / 0 / ville vide).
/// 613 §9 (ZOE) — [onlyRole] `'walker'` / `'sitter'` : le nombre de CE rôle
/// seulement. Une promenade ne prévient que les promeneurs, une garde que
/// les gardiens (serveur, `rolesForServices`) : la confirmation « Envoyée à
/// 70 gardiens et promeneurs » annonçait le double (mesuré sur l'émulateur :
/// 35 e-mails partis, 70 affichés).
Future<int?> fetchSupplyTotal600(String city, {ApiClient? api, String? onlyRole}) async {
  final c = city.trim();
  if (c.isEmpty || c.contains('@')) return null;
  final key = c.toLowerCase();
  final hit = _supplyCache600[key];
  if (hit != null && DateTime.now().difference(hit.at) < _supplyCacheTtl600) {
    return hit.pick(onlyRole);
  }
  int? total;
  int? sitters;
  int? walkers;
  try {
    final client = api ??
        (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient());
    final res = await client
        .get(kSupplyCityEndpoint600, queryParameters: <String, dynamic>{'city': c})
        .timeout(const Duration(seconds: 4));
    if (res is Map) {
      final sv = res['sitters'];
      final wv = res['walkers'];
      if (sv is num) sitters = sv.toInt();
      if (wv is num) walkers = wv.toInt();
      final t = res['total'];
      if (t is num && t > 0) {
        total = t.toInt();
      } else {
        final s = sitters ?? 0;
        final w = walkers ?? 0;
        if (s + w > 0) total = s + w;
      }
    }
  } catch (_) {
    total = null;
    sitters = null;
    walkers = null;
  }
  final entry = _SupplyEntry(total, DateTime.now(), sitters: sitters, walkers: walkers);
  _supplyCache600[key] = entry;
  return entry.pick(onlyRole);
}
