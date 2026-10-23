// 619 (PAM, 23/10/2026 — ordre de Daniel « code postal = position »).
//
// Un compte inscrit avec sa ville seule, ou une demande publiée par la ville,
// était placé au CENTRE de la ville : 16 propriétaires et 13 prestataires au
// même point à Paris / New York le 23/10. Le serveur (commit 66269c0c +
// build 619) transforme désormais un code postal en position
// (geocodePostal2310). Ici : la règle de validation commune aux 3 rôles, le
// clavier adapté au pays, et l'appel unique `PUT /users/me/profile` qui
// déplace le compte depuis « Modifier le profil ».
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// Nettoyage identique au serveur (`cleanCode`) : majuscules, lettres et
/// chiffres seulement, 10 caractères au plus.
String cleanPostalCode2310(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '').let10();

extension _Cap on String {
  String let10() => length > 10 ? substring(0, 10) : this;
}

/// Obligatoire : 3 à 10 caractères utiles (consigne du build 619).
bool isPostalCodeValid2310(String raw) {
  final c = cleanPostalCode2310(raw);
  return c.length >= 3 && c.length <= 10;
}

/// Pays dont le code postal n'a que des chiffres → clavier numérique
/// (consigne : « clavier numérique »). Les autres (GB, CA, NL, IE…) gardent
/// le clavier texte, sinon leurs lettres seraient impossibles à saisir.
const Set<String> _digitsOnlyCountries = <String>{
  'FR', 'US', 'ES', 'DE', 'IT', 'PT', 'PL', 'KR', 'JP', 'BE', 'CH', 'AT',
  'LU', 'MX', 'BR', 'AR', 'CL', 'CO', 'DK', 'NO', 'SE', 'FI', 'CZ', 'HU',
  'RO', 'GR', 'TR', 'MA', 'TN', 'DZ', 'AU', 'NZ', 'IN', 'CN', 'TW', 'TH',
  'VN', 'ID', 'PH', 'MY', 'SG', 'ZA', 'EG', 'IL', 'RU', 'UA', 'HR', 'SI',
  'SK', 'BG', 'RS', 'LT', 'LV', 'EE', 'IS', 'MC', 'AD', 'SM', 'VA', 'LI',
};

TextInputType postalKeyboardFor2310(String? countryIso) {
  final iso = (countryIso ?? '').trim().toUpperCase();
  if (iso.isEmpty || _digitsOnlyCountries.contains(iso)) {
    return TextInputType.number;
  }
  return TextInputType.text;
}

/// « Modifier le profil » (3 rôles) : enregistre le code postal et, en
/// retour, la position calculée par le serveur. Renvoie la position
/// `(lat, lng)` renvoyée (null si le serveur n'en a pas calculé : ancien
/// serveur ou code inconnu). Lève en cas d'erreur réseau / 4xx.
Future<({double? lat, double? lng, String city})> savePostalCode2310({
  required String postalCode,
  String? country,
  String? city,
  ApiClient? api,
}) async {
  final client = api ?? (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient());
  final code = cleanPostalCode2310(postalCode);
  final body = <String, dynamic>{
    'postalCode': code,
    if (country != null && country.trim().isNotEmpty)
      'country': country.trim().toUpperCase(),
    if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
  };
  final r = await client.put(ApiEndpoints.myProfile,
      body: body, requiresAuth: true);
  return positionFromProfileResponse2310(r);
}

/// Lit `user.location.coordinates` ([lng, lat]) d'une réponse de
/// `PUT /users/me/profile` (ou `lat`/`lng` plats).
({double? lat, double? lng, String city}) positionFromProfileResponse2310(
    dynamic r) {
  double? lat;
  double? lng;
  String city = '';
  if (r is Map) {
    final u = r['user'] is Map ? r['user'] as Map : r;
    final loc = u['location'];
    if (loc is Map) {
      final coords = loc['coordinates'];
      if (coords is List && coords.length >= 2) {
        lng = (coords[0] as num?)?.toDouble();
        lat = (coords[1] as num?)?.toDouble();
      } else {
        lat = (loc['lat'] as num?)?.toDouble();
        lng = (loc['lng'] as num?)?.toDouble();
      }
      city = (loc['city'] ?? '').toString();
    }
    if (city.isEmpty) city = (u['city'] ?? '').toString();
  }
  return (lat: lat, lng: lng, city: city);
}

/// Après « Enregistrer » : le profil local porte la nouvelle position (la
/// PawMap s'ouvre dessus), le « dernier endroit regardé » est oublié, et la
/// carte montée y va tout de suite. Renvoie true si une position a été appliquée.
bool applyMovedPosition2310(
    ({double? lat, double? lng, String city}) pos, String postalCode) {
  final lat = pos.lat;
  final lng = pos.lng;
  if (lat == null || lng == null) return false;
  try {
    final box = GetStorage();
    final raw = box.read(StorageKeys.userProfile);
    if (raw is Map) {
      final p = Map<String, dynamic>.from(raw);
      p['location'] = <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[lng, lat],
        if (pos.city.isNotEmpty) 'city': pos.city,
      };
      p['postalCode'] = cleanPostalCode2310(postalCode);
      if (pos.city.isNotEmpty) p['city'] = pos.city;
      box.write(StorageKeys.userProfile, p);
    }
    box.remove('pawmap_last_center');
  } catch (_) {/* stockage indisponible : la carte vivante bouge quand même */}
  pawMapProfileMovedTo619.value = LatLng(lat, lng);
  pawMapProfileMoved619.value++;
  return true;
}
