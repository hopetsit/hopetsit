// 646 (PAM, 25/11/2026 — ordre de Daniel : « je veux que les clients
// comprennent ») — « tarif à venir ».
//
// Depuis le 25/11 le serveur ne calcule plus jamais « tarif d'une heure × 8 ».
// Un gardien sans tarif à la journée qui répond à une garde voit sa
// candidature créée en « tarif à venir » : `pricing.stale = true`,
// `pricing.indicative = true`, `totalPrice` null. L'app ne décide plus rien
// à la place du serveur : elle lit sa réponse.
//
// Fonctions PURES (aucun widget) : testables directement.
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/server_error_message.dart';

/// La réponse de `POST /applications` (ou une candidature seule) est-elle en
/// « tarif à venir » ?
bool isRateToCome646(Object? response) {
  if (response is! Map) return false;
  final Object? app = response['application'] is Map ? response['application'] : response;
  if (app is! Map) return false;
  final Object? pricing = app['pricing'];
  return pricing is Map && pricing['stale'] == true;
}

/// Tarif réclamé par un REFUS du serveur : 'day' | 'visit' | 'walk' | 'any',
/// 'not_for_walker' (un promeneur sur une garde), ou null si le refus ne
/// parle pas de tarif.
String? rateNeedOfError646(Object error, {String role = '', String service = ''}) {
  if (error is! ApiException) return null;
  // 646 (ZOE, contrôle du 25/11) — depuis le 25/11 après-midi le serveur écrit
  // ces deux refus dans la LANGUE du compte et sans `code` : les mots-clés
  // anglais ne les reconnaissent plus (vu au simulateur : bandeau rouge sans
  // bouton). Le champ `details` de la réponse, lui, reste fixe.
  final Object? body = error.details;
  if (body is Map && error.statusCode == 400) {
    final String d = (body['details'] ?? '').toString().toLowerCase();
    if (d.contains('30 min or 60 min walks')) return 'walk';
    if (d.contains('non-zero rate')) return needOfService646(service);
  }
  final String key = errorKeyFor(error);
  switch (key) {
    case 'pam646_need_visit':
      return 'visit';
    case 'pam646_need_walk':
      return 'walk';
    case 'pam646_need_day':
      return 'day';
    case 'pam646_need_any':
      // Un promeneur a forcément un tarif de balade quand il arrive ici (sinon
      // le serveur répond « at least one walk rate ») : ce refus veut dire que
      // la demande est une garde.
      return role.toLowerCase() == 'walker' ? 'not_for_walker' : needOfService646(service);
    default:
      return null;
  }
}

/// 646 (ZOE) — quand le serveur dit seulement « il manque ton tarif », le
/// service de la demande dit LEQUEL : visite → 'visit', garde → 'day', sinon
/// 'any' (Mes tarifs s'ouvre alors sur la première rubrique vide).
String needOfService646(String service) {
  final String s = service.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  if (s == 'home_visit' || s == 'homevisit') return 'visit';
  if (s == 'house_sitting' || s == 'pet_sitting' || s == 'day_care' ||
      s == 'overnight_stay' || s == 'long_stay') {
    return 'day';
  }
  return 'any';
}

/// Clé i18n de la phrase d'un refus de tarif.
String needKey646(String need) {
  switch (need) {
    case 'day':
      return 'pam646_need_day';
    case 'visit':
      return 'pam646_need_visit';
    case 'walk':
      return 'pam646_need_walk';
    case 'not_for_walker':
      return 'pam646_walker_not_for_you';
    default:
      return 'pam646_need_any';
  }
}

/// Clé i18n de l'encadré fixe de l'écran Mes tarifs.
String ratesBoxKey646(String focus) {
  switch (focus) {
    case 'visit':
      return 'pam646_rates_box_visit';
    case 'walk':
      return 'pam646_rates_box_walk';
    default:
      return 'pam646_rates_box_day';
  }
}

/// Rubrique de Mes tarifs à ouvrir pour un GARDIEN quand on ne sait pas
/// laquelle (« auto », en venant d'une notification) : celle qui est vide.
/// Le prix par jour d'abord (c'est lui qui débloque une garde), puis la visite.
/// '' = rien à pointer.
String autoFocus646({
  required String role,
  double dailyRate = 0,
  double weeklyRate = 0,
  double monthlyRate = 0,
  double visitRate = 0,
  bool hasWalkRate = false,
}) {
  if (role.toLowerCase() == 'walker') return hasWalkRate ? '' : 'walk';
  if (dailyRate <= 0 && weeklyRate <= 0 && monthlyRate <= 0) return 'day';
  if (visitRate <= 0) return 'visit';
  return '';
}
