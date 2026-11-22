// 644 (BOB, 22/11/2026) — page des candidats du propriétaire : les quatre
// corrections publiées le 22/11 sur le site (`OwnerCandidatesPay3110.tsx`,
// `lib/cand3110.ts`) et le serveur (`priceOffer2211.js`, `payLater2211.js`),
// portées dans l'app :
//   · « Proposer mon prix » (si `priceOffer2211View.canOffer`) ;
//   · « Lui parler avant de réserver » + 4 messages prêts ;
//   · « Réserver <prénom>, payer plus tard » (si `payLater2211View.canReserve`) ;
//   · ordre « confiance d'abord » + « Plus loin de chez toi ».
// Ici : les coupe-circuits, la logique PURE (testée par test/app644_test.dart)
// et les blocs d'interface posés dans `post_candidates_sheet.dart`.
// Aucun prix n'est calculé dans l'app : tout vient du serveur.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

// ───────────────────────────── coupe-circuits ─────────────────────────────
// `flutter build … --dart-define=PRICE_OFFER_644=false` masque la nouveauté.
// OWNER_CANDIDATES_644=false coupe les quatre nouveautés propriétaire d'un coup.

/// Les nouveautés 644 de la page des candidats (interrupteur général).
const bool kOwnerCandidates644 =
    bool.fromEnvironment('OWNER_CANDIDATES_644', defaultValue: true);

/// « Proposer mon prix ».
const bool kPriceOffer644 = bool.fromEnvironment('PRICE_OFFER_644', defaultValue: true);

/// « Lui parler avant de réserver » + messages prêts (éteint : « Écrire à … » d'avant).
const bool kTalkBefore644 = bool.fromEnvironment('TALK_BEFORE_644', defaultValue: true);

/// « Réserver (prénom), payer plus tard ».
const bool kPayLater644 = bool.fromEnvironment('PAY_LATER_644', defaultValue: true);

/// Ordre « photo, identité, distance, prix » + « Plus loin de chez toi »
/// (éteint : ordre du build 628, PawBoost puis ordre du serveur).
const bool kCandOrder644 = bool.fromEnvironment('CAND_ORDER_644', defaultValue: true);

/// Réglages effectifs. Les tests peuvent en forcer un (`Flags644.priceOffer = false`).
class Flags644 {
  Flags644._();
  static bool priceOffer = kOwnerCandidates644 && kPriceOffer644;
  static bool talkBefore = kOwnerCandidates644 && kTalkBefore644;
  static bool payLater = kOwnerCandidates644 && kPayLater644;
  static bool order = kOwnerCandidates644 && kCandOrder644;

  static void reset() {
    priceOffer = kOwnerCandidates644 && kPriceOffer644;
    talkBefore = kOwnerCandidates644 && kTalkBefore644;
    payLater = kOwnerCandidates644 && kPayLater644;
    order = kOwnerCandidates644 && kCandOrder644;
  }
}

// ───────────────────────────── logique pure ─────────────────────────────

/// Au-delà de cette distance, un candidat à une promenade ou à une visite
/// passe sous « Plus loin de chez toi » (site : `FAR_KM_2211`).
const int kFarKm644 = 10;
const Set<String> _nearServices644 = <String>{'dog_walking', 'home_visit'};

bool _pending644(ApplicationModel a) => a.status.toLowerCase().trim() == 'pending';
bool _accepted644(ApplicationModel a) =>
    const <String>['accepted', 'agreed'].contains(a.status.toLowerCase().trim());

/// Total affichable (serveur), sinon null : jamais un total absent, nul,
/// indicatif, périmé ou inférieur au tarif unitaire (site : `totalOf3110`).
double? candidateTotalValue644(ApplicationModel a) {
  final p = a.pricing;
  if (p == null || p.stale || p.indicative) return null;
  final t = p.totalPrice;
  if (t == null || !(t > 0)) return null;
  final rate = p.appliedRate;
  if (rate != null && rate > 0 && t + 0.001 < rate) return null;
  return t;
}

/// Devise de la candidature (celle du prix du serveur, sinon celle du candidat).
String candidateCurrency644(ApplicationModel a) {
  final c = (a.pricing?.currency ?? '').trim();
  if (c.isNotEmpty) return c.toUpperCase();
  return a.sitter.currency.isNotEmpty ? a.sitter.currency.toUpperCase() : 'EUR';
}

/// Le candidat a-t-il une photo de profil ? (site : `hasPhoto2211`).
bool hasPhoto644(ApplicationModel a) => a.sitter.avatar.url.trim().isNotEmpty;

/// « Plus loin de chez toi » : seulement pour une promenade ou une visite à
/// domicile (service de la candidature, sinon ceux de la demande : tous de ce
/// type), à PLUS de 10 km. Distance inconnue = proche. Personne n'est masqué.
bool isFar644(ApplicationModel a, int? km, List<String>? postServices) {
  final services =
      a.serviceType.isNotEmpty ? <String>[a.serviceType] : (postServices ?? const <String>[]);
  if (services.isEmpty || !services.every(_nearServices644.contains)) return false;
  return km != null && km > kFarKm644;
}

/// Réservé « payer plus tard », pas encore payé : `accepted` + échéance en cours.
bool isHeld644(ApplicationModel a) =>
    _accepted644(a) && a.payLater?.status == 'waiting' && a.payLater?.deadline != null;

/// Ordre de la page (site : `sortCandidates3110`, « confiance d'abord ») :
/// 1) le candidat de la notification ; 2) promenade / visite : les candidats à
/// plus de 10 km après tous les autres ; 3) PawBoost actif (règle de l'app,
/// build 628, gardée au-dessus du reste) ; 4) photo ; 5) identité vérifiée ;
/// 6) le plus proche (distance inconnue en dernier) ; 7) le moins cher (total
/// inconnu en dernier) ; 8) ordre du serveur (tri stable).
/// [kmOf] donne la distance arrondie d'un candidat (null = inconnue).
List<ApplicationModel> sortCandidates644(
  Iterable<ApplicationModel> items, {
  required int? Function(ApplicationModel a) kmOf,
  String? highlightId,
  List<String>? postServices,
}) {
  final list = items.toList();
  final idx = <String, int>{for (var i = 0; i < list.length; i++) list[i].id: i};
  final km = <String, int?>{for (final a in list) a.id: kmOf(a)};
  final focus = (highlightId ?? '').isEmpty ? null : highlightId;
  int flag(bool first) => first ? 0 : 1;
  list.sort((x, y) {
    final fx = flag(focus != null && x.id == focus), fy = flag(focus != null && y.id == focus);
    if (fx != fy) return fx - fy;
    final dx = isFar644(x, km[x.id], postServices) ? 1 : 0;
    final dy = isFar644(y, km[y.id], postServices) ? 1 : 0;
    if (dx != dy) return dx - dy;
    final bx = flag(x.sitter.isBoosted), by = flag(y.sitter.isBoosted);
    if (bx != by) return bx - by;
    final px = flag(hasPhoto644(x)), py = flag(hasPhoto644(y));
    if (px != py) return px - py;
    final vx = flag(x.sitter.identityVerified), vy = flag(y.sitter.identityVerified);
    if (vx != vy) return vx - vy;
    final kx = km[x.id], ky = km[y.id];
    if (kx != ky) {
      if (kx == null) return 1;
      if (ky == null) return -1;
      return kx - ky;
    }
    final tx = candidateTotalValue644(x), ty = candidateTotalValue644(y);
    if (tx != ty) {
      if (tx == null) return 1;
      if (ty == null) return -1;
      return tx.compareTo(ty);
    }
    return (idx[x.id] ?? 0) - (idx[y.id] ?? 0);
  });
  return list;
}

/// Candidat AVANT lequel poser l'intertitre « Plus loin de chez toi » : le 1er
/// « plus loin » (hors candidat de la notification), seulement s'il reste au
/// moins un candidat proche. '' = pas d'intertitre.
String firstFarId644(
  List<ApplicationModel> sorted, {
  required int? Function(ApplicationModel a) kmOf,
  String? highlightId,
  List<String>? postServices,
}) {
  bool far(ApplicationModel a) => isFar644(a, kmOf(a), postServices);
  final f = sorted.firstWhereOrNull((a) => a.id != (highlightId ?? '') && far(a));
  if (f == null || !sorted.any((a) => !far(a))) return '';
  return f.id;
}

/// Montant saisi → nombre (virgule ou point), null si illisible ou ≤ 0.
double? parseAmount644(String raw) {
  final s = raw.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  if (s.isEmpty) return null;
  final v = double.tryParse(s);
  if (v == null || !v.isFinite || !(v > 0)) return null;
  return (v * 100).round() / 100;
}

String _money644(String currency, double v) => CurrencyHelper.format(currency, v);

/// Message d'erreur de « Proposer mon prix » selon le code du serveur.
String offerErrorText644(String code, {double? min, double? max, required String currency}) {
  final low = min != null
      ? 'cand644_offer_err_low'.tr.replaceAll('{min}', _money644(currency, min))
      : 'cand644_offer_err'.tr;
  final high = max != null
      ? 'cand644_offer_err_high'.tr.replaceAll('{max}', _money644(currency, max))
      : 'cand644_offer_err'.tr;
  switch (code) {
    case 'OFFER_TOO_LOW':
      return low;
    case 'OFFER_NOT_LOWER':
      return high;
    case 'OFFER_LIMIT':
      return 'cand644_offer_err_limit'.tr;
    default:
      return 'cand644_offer_err'.tr;
  }
}

/// Contrôle local AVANT l'envoi (mêmes bornes que le serveur, qui tranche) :
/// renvoie le code d'erreur, ou '' si le montant peut partir.
String offerLocalCheck644(double? amount, {double? min, double? max}) {
  if (amount == null) return 'OFFER_TOO_LOW';
  if (max != null && amount >= max) return 'OFFER_NOT_LOWER';
  if (min != null && amount < min) return 'OFFER_TOO_LOW';
  return '';
}

/// Message d'erreur de « Réserver, payer plus tard » selon le code du serveur.
String laterErrorText644(String code) =>
    (code == 'PAY_LATER_TOO_LATE' ? 'cand644_later_err_late' : 'cand644_later_err').tr;

/// État de la proposition de prix à afficher sous la carte : texte ('' = rien)
/// et ton (vrai = vert : en attente / acceptée ; faux = orange : refusée…).
({String text, bool good}) offerNote644(ApplicationModel a, String firstName) {
  final o = a.priceOffer;
  if (o == null || o.status.isEmpty || !_pending644(a)) return (text: '', good: false);
  final cur = o.currency.isNotEmpty ? o.currency : candidateCurrency644(a);
  final price = (o.amount != null && o.amount! > 0) ? _money644(cur, o.amount!) : '';
  String t(String key) =>
      key.tr.replaceAll('{name}', firstName).replaceAll('{price}', price);
  switch (o.status) {
    case 'pending':
      return (text: t(price.isNotEmpty ? 'cand644_offer_pending' : 'cand644_offer_sent'), good: true);
    case 'accepted':
      return (text: t('cand644_offer_accepted'), good: true);
    case 'declined':
      return (text: t('cand644_offer_declined'), good: false);
    case 'expired':
      return (text: t('cand644_offer_expired'), good: false);
    case 'cancelled':
      return (text: t('cand644_offer_cancelled'), good: false);
    default:
      return (text: '', good: false);
  }
}

/// Les 4 messages prêts (site : `questionsFor`) : se parler 10 minutes,
/// expérience avec mon animal (garde / promenade), le rencontrer, les dates.
List<String> questions644({required bool isWalker, required String animalKind, required bool tbd}) {
  final k = animalKind.toLowerCase().trim();
  final animalKey = (k.startsWith('dog') || k == 'chien')
      ? 'cand644_animal_dog'
      : (k.startsWith('cat') || k == 'chat')
          ? 'cand644_animal_cat'
          : 'cand644_animal_other';
  return <String>[
    'cand644_q_call'.tr,
    (isWalker ? 'cand644_q_exp_walk' : 'cand644_q_exp').tr.replaceAll('{animal}', animalKey.tr),
    'cand644_q_meet'.tr,
    (tbd ? 'cand644_q_dates_tbd' : 'cand644_q_dates').tr,
  ];
}

/// « mar. 24 nov. 14:00 » à l'heure du téléphone, dans la langue de l'app.
String heldDate644(DateTime deadline, {String? locale}) {
  final d = deadline.toLocal();
  final lang = locale ?? Get.locale?.languageCode ?? 'fr';
  try {
    return '${DateFormat.MMMEd(lang).format(d)} ${DateFormat.Hm(lang).format(d)}';
  } catch (_) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// 628 + 644 — réservation à ouvrir en paiement à la fermeture de la feuille :
/// comme `chosenBookingId628`, SAUF une réservation « payer plus tard » en
/// cours (le propriétaire a justement choisi de ne pas payer tout de suite ;
/// il paie par « Payer maintenant »).
String? chosenBookingId644(Iterable<ApplicationModel> applications, String postId) {
  final re = RegExp(r'^[0-9a-fA-F]{24}$');
  for (final a in applications) {
    if (a.postId != postId || !_accepted644(a)) continue;
    if (Flags644.payLater && isHeld644(a)) continue;
    final b = a.bookingId ?? '';
    if (re.hasMatch(b)) return b;
  }
  return null;
}

/// 644 (ZOE) — titre du bandeau d'accueil « à payer » quand la réservation est
/// un « payer plus tard » en cours : « Réservé jusqu'au (date heure) », au lieu
/// de « (prénom) a accepté ! » (faux ici : c'est le propriétaire qui a réservé,
/// et l'échéance n'apparaissait nulle part hors de la feuille). null = titre d'avant.
String? heldBannerTitle644(String bookingId, Iterable<ApplicationModel> applications) {
  if (!Flags644.payLater || bookingId.isEmpty) return null;
  for (final a in applications) {
    if ((a.bookingId ?? '') == bookingId && isHeld644(a)) {
      return 'cand644_later_held'.tr.replaceAll('{date}', heldDate644(a.payLater!.deadline!));
    }
  }
  return null;
}

// ───────────────────────────── interface ─────────────────────────────

const Color _green644 = Color(0xFF15803D);

Widget _note644(BuildContext context, String text, {required bool good, Key? key}) {
  final Color tone = good ? _green644 : AppColors.primaryColor;
  final Color on = AppColors.accentOn(context, tone);
  return Container(
    key: key,
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (good) ...[
          Icon(Icons.check_circle_rounded, size: 15.sp, color: on),
          SizedBox(width: 6.w),
        ],
        Expanded(
          child: InterText(
            text: text,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: on,
          ),
        ),
      ],
    ),
  );
}

/// Lien texte (44 pt de haut au moins) — « Proposer mon prix », « Fermer ».
class _Link644 extends StatelessWidget {
  const _Link644({super.key, required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            child: Center(
              widthFactor: 1,
              child: InterText(
                text: label,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: color,
                textDecoration: TextDecoration.underline,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encart « Réservé jusqu'au (date heure) » d'une réservation « payer plus tard ».
class HeldBox644 extends StatelessWidget {
  const HeldBox644({super.key, required this.app, required this.firstName});
  final ApplicationModel app;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final on = AppColors.accentOn(context, _green644);
    final String date = heldDate644(app.payLater!.deadline!);
    return Container(
      key: Key('cand644_held_${app.id}'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: _green644.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, size: 16.sp, color: on),
              SizedBox(width: 6.w),
              Expanded(
                child: InterText(
                  text: 'cand644_later_held'.tr.replaceAll('{date}', date),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: on,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          InterText(
            text: 'cand644_later_held_sub'.tr.replaceAll('{name}', firstName),
            fontSize: 11.5.sp,
            height: 1.35,
            color: AppColors.textSecondary(context),
          ),
        ],
      ),
    );
  }
}

/// Sous le bouton « Choisir » d'un candidat EN ATTENTE : « Réserver (prénom),
/// payer plus tard » (confirmation en deux temps), l'état de la proposition de
/// prix, le champ « Proposer mon prix » et les messages d'erreur.
/// N'affiche RIEN si le serveur n'envoie ni vue « prix » ni vue « plus tard ».
class CandExtras644 extends StatefulWidget {
  const CandExtras644({
    super.key,
    required this.app,
    required this.firstName,
    required this.tbd,
    required this.roleColor,
    required this.busy,
    required this.onReserveLater,
    required this.onProposePrice,
  });

  final ApplicationModel app;
  final String firstName;

  /// Demande « dates à prévoir » : ni prix proposé ni réservation (pas de total).
  final bool tbd;
  final Color roleColor;

  /// Un choix est en cours sur la feuille (les boutons attendent).
  final RxBool busy;
  final Future<Result644> Function() onReserveLater;
  final Future<Result644> Function(double amount) onProposePrice;

  @override
  State<CandExtras644> createState() => _CandExtras644State();
}

class _CandExtras644State extends State<CandExtras644> {
  /// '' | 'offer' | 'later' — une seule zone ouverte à la fois sur la carte.
  String _zone = '';
  bool _sending = false;
  String _error = '';
  final TextEditingController _amount = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _open(String zone) {
    if (_sending || widget.busy.value) return;
    setState(() {
      _zone = zone;
      _error = '';
      if (zone == 'offer') _amount.clear();
    });
    if (zone == 'offer') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
  }

  void _close() {
    if (_sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _zone = '';
      _error = '';
    });
  }

  Future<void> _sendOffer() async {
    if (_sending || widget.busy.value) return;
    final a = widget.app;
    final cur = candidateCurrency644(a);
    final double? min = a.priceOffer?.minAmount;
    final double? max = a.priceOffer?.currentTotal ?? candidateTotalValue644(a);
    final double? amount = parseAmount644(_amount.text);
    final String local = offerLocalCheck644(amount, min: min, max: max);
    if (local.isNotEmpty) {
      setState(() => _error = offerErrorText644(local, min: min, max: max, currency: cur));
      return;
    }
    setState(() {
      _sending = true;
      _error = '';
    });
    final Result644 r = await widget.onProposePrice(amount!);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (r.ok) {
        _zone = '';
        _amount.clear();
      } else {
        _error = offerErrorText644(r.code, min: min, max: max, currency: cur);
        // Limite atteinte ou fonction coupée : le champ se referme, le lien disparaît.
        if (r.code == 'OFFER_LIMIT' || r.code == 'OFFER_DISABLED') _zone = '';
      }
    });
  }

  Future<void> _confirmLater() async {
    if (_sending || widget.busy.value) return;
    setState(() {
      _sending = true;
      _error = '';
    });
    final Result644 r = await widget.onReserveLater();
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (r.ok) {
        _zone = '';
      } else if (r.code.startsWith('PAY_LATER_')) {
        _zone = '';
        _error = laterErrorText644(r.code);
      } else {
        _error = r.message ?? laterErrorText644(r.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    final bool pending = _pending644(a);
    final double? total = candidateTotalValue644(a);
    final bool priced = !widget.tbd && total != null && a.pricing?.stale != true;
    final bool canLater =
        Flags644.payLater && pending && priced && a.payLater?.canReserve == true;
    final bool canOffer =
        Flags644.priceOffer && pending && priced && a.priceOffer?.canOffer == true;
    final bool released =
        Flags644.payLater && pending && a.payLater?.status == 'released';
    final note = Flags644.priceOffer ? offerNote644(a, widget.firstName) : (text: '', good: false);
    final String name = widget.firstName;
    final String cur = candidateCurrency644(a);
    final Color owner = AppColors.primaryColor;
    final Color roleOn = AppColors.accentOn(context, widget.roleColor);

    final children = <Widget>[
      if (canLater && _zone != 'later')
        ActionPillButton(
          key: Key('cand644_later_btn_${a.id}'),
          label: 'cand644_later_btn'.tr.replaceAll('{name}', name),
          icon: Icons.event_available_rounded,
          tone: owner,
          kind: ActionPillKind.ghost,
          expand: true,
          onPressed: () => _open('later'),
        ),
      if (canLater && _zone == 'later')
        Container(
          key: Key('cand644_later_confirm_${a.id}'),
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: owner.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: 'cand644_later_text'
                    .tr
                    .replaceAll('{name}', name)
                    .replaceAll('{hours}', '${a.payLater?.holdHours ?? 48}'),
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 8.h),
              ActionPillButton(
                key: Key('cand644_later_ok_${a.id}'),
                label: (_sending ? 'cand644_later_busy' : 'cand644_later_confirm').tr,
                icon: Icons.check_rounded,
                tone: owner,
                expand: true,
                haptic: true,
                busy: _sending,
                onPressed: _confirmLater,
              ),
              Center(
                child: _Link644(
                  key: Key('cand644_later_close_${a.id}'),
                  label: 'cand644_ask_close'.tr,
                  color: AppColors.textSecondary(context),
                  onTap: _close,
                ),
              ),
            ],
          ),
        ),
      if (released)
        _note644(context, 'cand644_later_released'.tr,
            good: false, key: Key('cand644_later_released_${a.id}')),
      if (note.text.isNotEmpty)
        _note644(context, note.text,
            good: note.good, key: Key('cand644_offer_note_${a.id}')),
      if (canOffer && _zone == 'offer')
        Container(
          key: Key('cand644_offer_box_${a.id}'),
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: widget.roleColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: 'cand644_offer_title'.tr.replaceAll('{name}', name),
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                height: 1.3,
                color: roleOn,
              ),
              SizedBox(height: 2.h),
              InterText(
                key: Key('cand644_offer_hint_${a.id}'),
                text: 'cand644_offer_hint'
                    .tr
                    .replaceAll('{name}', name)
                    .replaceAll('{min}', _money644(cur, a.priceOffer?.minAmount ?? 0))
                    .replaceAll(
                        '{max}', _money644(cur, a.priceOffer?.currentTotal ?? total)),
                fontSize: 11.5.sp,
                height: 1.35,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 8.h),
              TextField(
                key: Key('cand644_offer_input_${a.id}'),
                controller: _amount,
                focusNode: _amountFocus,
                enabled: !_sending,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(9),
                ],
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendOffer(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.card(context),
                  hintText: 'cand644_offer_label'.tr,
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                  suffixText: cur,
                  suffixStyle: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: roleOn,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: widget.roleColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: widget.roleColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: widget.roleColor, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              ActionPillButton(
                key: Key('cand644_offer_send_${a.id}'),
                label: (_sending ? 'cand644_offer_sending' : 'cand644_offer_send').tr,
                icon: Icons.account_balance_wallet_rounded,
                tone: widget.roleColor,
                expand: true,
                busy: _sending,
                onPressed: _sendOffer,
              ),
              Center(
                child: _Link644(
                  key: Key('cand644_offer_close_${a.id}'),
                  label: 'cand644_ask_close'.tr,
                  color: AppColors.textSecondary(context),
                  onTap: _close,
                ),
              ),
            ],
          ),
        ),
      if (canOffer && _zone != 'offer')
        Center(
          child: _Link644(
            key: Key('cand644_offer_btn_${a.id}'),
            label: 'cand644_offer_btn'.tr,
            color: roleOn,
            onTap: () => _open('offer'),
          ),
        ),
      if (_error.isNotEmpty)
        _note644(context, _error, good: false, key: Key('cand644_error_${a.id}')),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: Key('cand644_extras_${a.id}'),
      padding: EdgeInsets.only(top: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: 8.h),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Intertitre « Plus loin de chez toi · à plus de 10 km ».
class FarHeader644 extends StatelessWidget {
  const FarHeader644({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('cand644_far_header'),
      padding: EdgeInsets.only(top: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place_rounded, size: 16.sp, color: AppColors.textSecondary(context)),
          SizedBox(width: 6.w),
          Expanded(
            child: InterText(
              text: 'cand644_far_title'.tr.replaceAll('{km}', '$kFarKm644'),
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Lui parler avant de réserver » : feuille avec les 4 messages prêts. Un
/// toucher sur un message ouvre la conversation avec ce texte DANS le champ
/// (modifiable avant l'envoi) ; « Voir la conversation » l'ouvre sans texte.
/// Renvoie le texte choisi, '' pour la conversation seule, null si fermée.
Future<String?> showTalkSheet644(
  BuildContext context, {
  required String firstName,
  required List<String> questions,
  required Color roleColor,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final Color roleOn = AppColors.accentOn(ctx, roleColor);
      return Container(
        key: const Key('cand644_talk_sheet'),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.86),
        decoration: BoxDecoration(
          color: AppColors.scaffold(ctx),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h + appBottomInset(ctx)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 10.h),
                  decoration: BoxDecoration(
                    color: AppColors.divider(ctx),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              PoppinsText(
                text: 'cand644_ask_title'.tr.replaceAll('{name}', firstName),
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(ctx),
              ),
              SizedBox(height: 3.h),
              InterText(
                text: 'cand644_ask_hint'.tr.replaceAll('{name}', firstName),
                fontSize: 12.sp,
                height: 1.35,
                color: AppColors.textSecondary(ctx),
              ),
              SizedBox(height: 10.h),
              for (var i = 0; i < questions.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Semantics(
                    button: true,
                    child: Material(
                      color: AppColors.card(ctx),
                      borderRadius: BorderRadius.circular(14.r),
                      child: InkWell(
                        key: Key('cand644_q_$i'),
                        borderRadius: BorderRadius.circular(14.r),
                        onTap: () => Navigator.of(ctx).pop(questions[i]),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: roleColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InterText(
                                  text: questions[i],
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: roleOn,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Icon(Icons.chevron_right_rounded, size: 18.sp, color: roleOn),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 2.h),
              ActionPillButton(
                key: const Key('cand644_talk_open'),
                label: 'cand644_ask_see'.tr,
                icon: Icons.chat_bubble_rounded,
                tone: roleColor,
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(''),
              ),
            ],
          ),
        ),
      );
    },
  );
}
