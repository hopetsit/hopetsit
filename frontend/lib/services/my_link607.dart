// 607 NEO (02/10/2026, décision de Daniel) — « Ramène tes clients ».
// Lit `GET /public/providers/me/link` (serveur NEO 607) : lien personnel
// hopetsit.com/s/<slug>, badge Pionnier, nombre de réservations. Construit le
// message prêt à envoyer (9 langues) et télécharge l'affiche A4 + QR.
// Aucun envoi automatique : tout part du doigt de la personne (partage système).
import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/storage_keys.dart';

const String kMyLinkEndpoint607 = '/public/providers/me/link';

class MyLink607 {
  const MyLink607({
    required this.slug,
    required this.url,
    required this.role,
    this.city = '',
    this.isPioneer,
    this.bookingsCount = 0,
    this.posterPath = '',
  });

  final String slug;
  final String url;
  final String role; // 'sitter' | 'walker'
  final String city;
  final bool? isPioneer; // null = inconnu → rien d'affiché
  final int bookingsCount;
  final String posterPath;

  static MyLink607? fromJson(dynamic j) {
    if (j is! Map) return null;
    final slug = (j['slug'] ?? '').toString();
    final url = (j['url'] ?? '').toString();
    if (slug.isEmpty || !url.startsWith('https://')) return null;
    final p = j['isPioneer'];
    return MyLink607(
      slug: slug,
      url: url,
      role: (j['role'] ?? 'sitter').toString() == 'walker' ? 'walker' : 'sitter',
      city: (j['city'] ?? '').toString().trim(),
      isPioneer: p is bool ? p : null,
      bookingsCount: (j['bookingsCount'] as num?)?.toInt() ?? 0,
      posterPath: (j['posterPath'] ?? '').toString(),
    );
  }
}

/// Rôle actif lu localement : la carte n'existe que pour gardien et promeneur.
String activeRole607() =>
    (GetStorage().read(StorageKeys.userRole) ?? '').toString().toLowerCase();

bool isProviderRole607(String role) => role == 'sitter' || role == 'walker';

MyLink607? _cache607;
DateTime? _cacheAt607;

void resetMyLinkCache607() {
  _cache607 = null;
  _cacheAt607 = null;
}

/// Lien de la personne connectée, ou null (propriétaire, hors ligne, erreur).
Future<MyLink607?> fetchMyLink607({ApiClient? api, bool force = false}) async {
  if (!isProviderRole607(activeRole607())) return null;
  if (!force &&
      _cache607 != null &&
      _cacheAt607 != null &&
      DateTime.now().difference(_cacheAt607!) < const Duration(minutes: 10) &&
      _cache607!.role == activeRole607()) {
    return _cache607;
  }
  try {
    final client = api ??
        (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient());
    final res = await client
        .get(kMyLinkEndpoint607, requiresAuth: true)
        .timeout(const Duration(seconds: 8));
    final link = MyLink607.fromJson(res);
    if (link != null) {
      _cache607 = link;
      _cacheAt607 = DateTime.now();
    }
    return link;
  } catch (_) {
    return null;
  }
}

/// Message prêt à envoyer, dans la langue de l'app.
String shareMessage607(MyLink607 link) {
  final key = link.role == 'walker' ? 'neo607_message_walker' : 'neo607_message_sitter';
  return key.tr.replaceAll('{link}', link.url);
}

/// Langue de l'affiche (le serveur sert ja/ko en anglais).
String posterLang607() {
  final l = (Get.locale?.languageCode ?? 'fr').toLowerCase();
  return l;
}

/// Partage système du message (rien n'est envoyé sans la personne).
Future<void> shareLink607(MyLink607 link) async {
  await SharePlus.instance.share(ShareParams(text: shareMessage607(link)));
}

/// Télécharge l'affiche PDF (avec le jeton : un compte de test reste privé)
/// puis l'ouvre dans la feuille de partage (Imprimer, Enregistrer, envoyer).
/// Rend false si l'affiche n'a pas pu être obtenue.
Future<bool> downloadPoster607(MyLink607 link, {http.Client? httpClient}) async {
  final path = link.posterPath.isNotEmpty
      ? link.posterPath
      : '/public/providers/${link.slug}/poster.pdf';
  final uri = Uri.parse('${ApiConfig.baseUrl}$path?lang=${posterLang607()}');
  final client = httpClient ?? http.Client();
  try {
    final token = Get.isRegistered<ApiClient>()
        ? Get.find<ApiClient>().authToken
        : ApiClient().authToken;
    final res = await client.get(uri, headers: <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': 'application/pdf',
    }).timeout(const Duration(seconds: 20));
    final bytes = res.bodyBytes;
    final isPdf = res.statusCode == 200 &&
        bytes.length > 8 &&
        String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
    if (!isPdf) return false;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/hopetsit-${link.slug}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
      subject: 'HoPetSit',
    ));
    return true;
  } catch (_) {
    return false;
  } finally {
    if (httpClient == null) client.close();
  }
}
