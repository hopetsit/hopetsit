// 645 (PAM, 24/11/2026) — page des candidats du propriétaire, parité avec le
// site du 24/11 (`OwnerCandidatesPay3110.tsx`, `detailLabel` et `badges2411`) :
//   · sous le total, le détail « 11 jours × 16,80 € » ;
//   · pastilles « 📍 Le plus proche » et « 💶 Le moins cher ».
// Rendu et textes seulement : aucun prix n'est calculé pour être payé, le
// total reste celui du serveur. Logique PURE testée par test/cand645_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/services620.dart';
import 'package:hopetsit/widgets/app_text.dart';

import 'cand644.dart';

/// Les deux nouveautés du 24/11 (`--dart-define=OWNER_CANDIDATES_645=false` les masque).
const bool kOwnerCandidates645 =
    bool.fromEnvironment('OWNER_CANDIDATES_645', defaultValue: true);

/// Unité de la quantité : celle du serveur, sinon déduite du service de la
/// candidature, sinon du 1er service de la demande (site : `unitOf`).
String _unit645(ApplicationModel a, List<String>? postServices) {
  final u = (a.pricing?.unit ?? '').trim().toLowerCase();
  if (u.isNotEmpty) return u;
  final svc = a.serviceType.isNotEmpty
      ? a.serviceType
      : ((postServices != null && postServices.isNotEmpty) ? postServices.first : '');
  return svc == 'home_visit' ? 'visit' : (svc == 'dog_walking' ? 'walk' : 'day');
}

/// Détail du total : « 11 jours × 16,80 € » (tarif frais compris = total ÷
/// quantité). Vide si le total n'est pas affichable (indicatif, « tarif à
/// venir », absent), si la quantité n'est pas un entier > 1 ; « ≈ » devant
/// quand la division ne tombe pas juste. [money] formate un montant
/// (par défaut comme le total de la carte).
String candidateDetail645(
  ApplicationModel a, {
  List<String>? postServices,
  String Function(String currency, double amount)? money,
}) {
  final total = candidateTotalValue644(a);
  final p = a.pricing;
  if (total == null || p == null) return '';
  final qty = p.quantity;
  if (qty == null || !p.quantityWhole || qty <= 1) return '';
  final perUnit = (total / qty * 100).round() / 100;
  if (!(perUnit > 0)) return '';
  final exact = (perUnit * qty - total).abs() < 0.005;
  final unit = _unit645(a, postServices);
  final qtyLabel = quantityLabel620(
    qty,
    unit == 'night' ? ServiceUnit620.day : serviceUnit620Parse(unit),
    night: unit == 'night',
  );
  final cur = (p.currency ?? '').isNotEmpty ? p.currency! : 'EUR';
  final price = (money ?? (String c, double v) => CurrencyHelper.format(c, v))(cur, perUnit);
  return '${exact ? '' : '≈ '}$qtyLabel × $price';
}

/// Repères de la liste : la plus petite distance et le plus petit total,
/// `null` quand la pastille ne doit pas sortir.
class CandBadges645 {
  const CandBadges645({this.km, this.total});
  final int? km;
  final double? total;

  static const CandBadges645 none = CandBadges645();

  bool _pending(ApplicationModel a) => a.status.toLowerCase().trim() == 'pending';

  /// « Le plus proche » sur cette carte ?
  bool closest(ApplicationModel a, int? cardKm) =>
      km != null && _pending(a) && cardKm != null && cardKm == km;

  /// « Le moins cher » sur cette carte ?
  bool cheapest(ApplicationModel a) {
    final t = candidateTotalValue644(a);
    return total != null && _pending(a) && t != null && t == total;
  }
}

/// Règle du site (`badges2411`) : parmi les candidats EN ATTENTE dont le tarif
/// n'est pas « à venir », une pastille seulement s'il y a au moins DEUX
/// valeurs connues et que la plus petite est SEULE en tête (pas d'ex æquo).
CandBadges645 badges645(
  Iterable<ApplicationModel> items, {
  required int? Function(ApplicationModel a) kmOf,
}) {
  if (!kOwnerCandidates645) return CandBadges645.none;
  final pend = items
      .where((a) => a.status.toLowerCase().trim() == 'pending' && a.pricing?.stale != true)
      .toList();
  final kms = <int>[
    for (final a in pend)
      if (kmOf(a) != null) kmOf(a)!,
  ];
  final tots = <double>[
    for (final a in pend)
      if (candidateTotalValue644(a) != null) candidateTotalValue644(a)!,
  ];
  int? minKm;
  if (kms.length >= 2) {
    final m = kms.reduce((x, y) => x < y ? x : y);
    if (kms.where((v) => v == m).length == 1) minKm = m;
  }
  double? minTot;
  if (tots.length >= 2) {
    final m = tots.reduce((x, y) => x < y ? x : y);
    if (tots.where((v) => v == m).length == 1) minTot = m;
  }
  return CandBadges645(km: minKm, total: minTot);
}

/// Pastille « 📍 Le plus proche » (vert) ou « 💶 Le moins cher » (ambre) :
/// mêmes couleurs que le site, pleines, lisibles en clair comme en sombre.
class CandBadge645 extends StatelessWidget {
  const CandBadge645.closest({super.key}) : _closest = true;
  const CandBadge645.cheapest({super.key}) : _closest = false;

  final bool _closest;

  @override
  Widget build(BuildContext context) {
    final Color bg = _closest ? const Color(0xFFEAF6EE) : const Color(0xFFFFF4D6);
    final Color fg = _closest ? const Color(0xFF15803D) : const Color(0xFF7A4B00);
    final String label =
        (_closest ? 'cand645_badge_closest' : 'cand645_badge_cheapest').tr;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: InterText(
        text: '${_closest ? '📍' : '💶'} $label',
        fontSize: 11.sp,
        fontWeight: FontWeight.w800,
        color: fg,
      ),
    );
  }
}
