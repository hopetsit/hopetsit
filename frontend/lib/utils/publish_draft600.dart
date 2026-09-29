// v600 NEO (29/09/2026) — « Publier ma demande » : brouillon local, espèces
// d'animaux (mêmes clés que le site : dog / cat / nac / bird / reptile /
// other), ville du profil et report de la pop-up promo après une publication.
//
// Tout passe par GetStorage (mémoire + fichier local) : rien ne part au
// serveur tant que le propriétaire n'appuie pas sur « Publier ».
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// Clé du brouillon de demande (un seul par appareil, remplacé à chaque
/// changement du formulaire).
const String kPublishDraftKey600 = 'publish600_draft';

/// Jusqu'à quand (ms depuis l'époque) la pop-up « Un cadeau pour toi » reste
/// muette après une publication : elle ne doit jamais recouvrir la demande
/// qui vient de partir.
const String kPromoSnoozeUntilKey600 = 'promo_popup_snooze_until_600';

/// Espèces proposées quand aucun animal n'est enregistré — les clés que le
/// site envoie déjà dans `animalTypes` (v404).
const List<String> kAnimalSpecies600 = <String>[
  'dog',
  'cat',
  'nac',
  'bird',
  'reptile',
  'other',
];

/// Libellé traduit d'une espèce (clé `neo600_animal_<espèce>`).
String animalSpeciesI18nKey600(String species) => 'neo600_animal_$species';

/// Un brouillon plus vieux que ça n'est plus proposé.
const Duration kPublishDraftMaxAge600 = Duration(days: 14);

/// Heures par défaut d'une garde / garderie (modifiables en un appui).
const int kDefaultStartHour600 = 8;
const int kDefaultEndHour600 = 20;

/// Ville du profil de la personne connectée ('' si inconnue). Le profil est
/// mémorisé sous `StorageKeys.userProfile` : la ville peut être à plat
/// (`city`) ou dans `location.city` selon l'ancienneté du compte.
String profileCity600({GetStorage? storage}) {
  try {
    final box = storage ?? GetStorage();
    final p = box.read(StorageKeys.userProfile);
    if (p is! Map) return '';
    final flat = (p['city'] ?? '').toString().trim();
    if (flat.isNotEmpty && !flat.contains('@')) return flat;
    final loc = p['location'];
    if (loc is Map) {
      final c = (loc['city'] ?? '').toString().trim();
      if (c.isNotEmpty && !c.contains('@')) return c;
    }
  } catch (_) {}
  return '';
}

/// Lit le brouillon (null s'il n'y en a pas, s'il est trop vieux ou illisible).
Map<String, dynamic>? readPublishDraft600({GetStorage? storage}) {
  try {
    final box = storage ?? GetStorage();
    final raw = box.read(kPublishDraftKey600);
    if (raw is! Map) return null;
    final d = Map<String, dynamic>.from(raw);
    final savedAt = (d['savedAt'] as num?)?.toInt() ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    if (savedAt <= 0 || age > kPublishDraftMaxAge600.inMilliseconds) {
      return null;
    }
    return d;
  } catch (_) {
    return null;
  }
}

/// Écrit le brouillon (horodaté).
void writePublishDraft600(Map<String, dynamic> draft, {GetStorage? storage}) {
  try {
    final box = storage ?? GetStorage();
    box.write(kPublishDraftKey600, <String, dynamic>{
      ...draft,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {/* best-effort : un brouillon perdu n'empêche rien */}
}

/// Efface le brouillon (publication faite, ou « Recommencer »).
void clearPublishDraft600({GetStorage? storage}) {
  try {
    (storage ?? GetStorage()).remove(kPublishDraftKey600);
  } catch (_) {}
}

/// Un brouillon vaut la peine d'être proposé s'il porte autre chose que le
/// seul type de service (pré-réglé par les cartes de l'accueil).
bool publishDraftIsMeaningful600(Map<String, dynamic>? d) {
  if (d == null) return false;
  bool has(String k) {
    final v = d[k];
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  return has('startDate') ||
      has('notes') ||
      has('animalTypes') ||
      has('petIds') ||
      has('budget') ||
      has('serviceLocation') ||
      has('meetingPoint');
}

/// Après une publication : la pop-up promo attend au moins 24 h.
void snoozePromoPopup600({GetStorage? storage, Duration for_ = const Duration(hours: 24)}) {
  try {
    (storage ?? GetStorage()).write(
      kPromoSnoozeUntilKey600,
      DateTime.now().add(for_).millisecondsSinceEpoch,
    );
  } catch (_) {}
}

/// La pop-up promo est-elle mise en pause (publication récente) ?
bool promoPopupSnoozed600({GetStorage? storage}) {
  try {
    final until = (storage ?? GetStorage()).read(kPromoSnoozeUntilKey600);
    if (until is num) {
      return until.toInt() > DateTime.now().millisecondsSinceEpoch;
    }
  } catch (_) {}
  return false;
}
