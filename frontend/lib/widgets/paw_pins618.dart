// 618 (PAM, 19/10/2026) — PINS du classement (PROCHAIN_BUILD_618 §B,
// décision de Daniel : « podium + 1er Chef de meute »).
//
// · Podium : pin OR (1er), ARGENT (2e), BRONZE (3e) du classement général du
//   moment — il change de main dès que quelqu'un passe devant.
// · « 1er Chef de meute » : pin UNIQUE et définitif de la première personne
//   (hors staff / test) arrivée au rang Chef de meute. Jamais réattribué.
//
// Contrat serveur, même forme partout (classement + `me`, /pawpoints/me,
// couches membres de la PawMap) :
//   pins: { podium: 1|2|3|null, firstPackLeader: true|false }
// Champ absent ou vide = RIEN affiché (jamais un faux pin).
//
// Couleurs pleines, zéro gris : l'argent est un argent BLEUTÉ (saturation
// ≥ 25 %), le « 1er Chef de meute » reprend le violet royal du rang.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hopetsit/widgets/paw_icons.dart';

class PawPins618 {
  const PawPins618({this.podium, this.firstPackLeader = false});

  /// 1, 2 ou 3 ; null hors podium.
  final int? podium;
  final bool firstPackLeader;

  bool get isEmpty => podium == null && !firstPackLeader;

  /// null si absent, illisible ou vide (ancien serveur).
  static PawPins618? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final p = (raw['podium'] as num?)?.toInt();
    final pins = PawPins618(
      podium: (p != null && p >= 1 && p <= 3) ? p : null,
      firstPackLeader: raw['firstPackLeader'] == true,
    );
    return pins.isEmpty ? null : pins;
  }

  /// Premiers pins trouvés parmi plusieurs entrées (une personne à plusieurs
  /// rôles : le serveur les porte sur chaque rôle, on prend le meilleur).
  static PawPins618? bestOf(Iterable<dynamic> raws) {
    int? podium;
    var first = false;
    for (final r in raws) {
      final p = fromJson(r);
      if (p == null) continue;
      if (p.podium != null && (podium == null || p.podium! < podium)) podium = p.podium;
      first = first || p.firstPackLeader;
    }
    final out = PawPins618(podium: podium, firstPackLeader: first);
    return out.isEmpty ? null : out;
  }

  /// Code du petit pin dessiné sur le rond de la PawMap : 1..3 = podium,
  /// 4 = 1er Chef de meute seul, 0 = rien. Le podium passe devant (une seule
  /// pastille sur un rond déjà chargé : couronne, coche, point de statut).
  int get mapCode => podium ?? (firstPackLeader ? 4 : 0);
}

/// Couleurs d'un pin : (clair, foncé, encre du chiffre).
class PawPinStyle618 {
  const PawPinStyle618(this.light, this.dark, this.ink);
  final Color light;
  final Color dark;
  final Color ink;

  static const PawPinStyle618 gold = PawPinStyle618(Color(0xFFFFD86B), Color(0xFFD99A06), Color(0xFF5A3C00));
  // Argent bleuté : jamais un gris (saturation HSL ≥ 25 %).
  static const PawPinStyle618 silver = PawPinStyle618(Color(0xFFD4E2F4), Color(0xFF7E9CC4), Color(0xFF1F3654));
  static const PawPinStyle618 bronze = PawPinStyle618(Color(0xFFF2B27A), Color(0xFFB0602A), Color(0xFF4A2208));
  static const PawPinStyle618 packLeader = PawPinStyle618(Color(0xFFB58AF0), Color(0xFF6A2FB0), Colors.white);

  /// 1..3 = podium, 4 = 1er Chef de meute.
  static PawPinStyle618 of(int code) => switch (code) {
        1 => gold,
        2 => silver,
        3 => bronze,
        _ => packLeader,
      };
}

/// Libellé traduit d'un pin (1..3 podium, 4 = 1er Chef de meute).
String pawPinLabel618(int code) => switch (code) {
      1 => 'pins618_gold'.tr,
      2 => 'pins618_silver'.tr,
      3 => 'pins618_bronze'.tr,
      _ => 'pins618_first_pack_leader'.tr,
    };

/// Le disque d'un pin : chiffre du podium, ou patte dorée pour le
/// 1er Chef de meute.
class PawPinDisc618 extends StatelessWidget {
  const PawPinDisc618({super.key, required this.code, this.size = 20});
  final int code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final st = PawPinStyle618.of(code);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [st.light, st.dark],
        ),
        border: Border.all(
          color: code == 4 ? const Color(0xFFFFC94A) : Colors.white,
          width: size >= 20 ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(color: st.dark.withValues(alpha: 0.35), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: code == 4
          ? PawIconWidget(PawIcon.paw,
              size: size * 0.56, color: const Color(0xFFFFE08A), fill: const Color(0xFFFFE08A))
          : Text(
              '$code',
              style: GoogleFonts.poppins(
                fontSize: size * 0.52,
                height: 1,
                fontWeight: FontWeight.w800, // Poppins ExtraBold embarquée
                color: st.ink,
              ),
            ),
    );
  }
}

/// Rangée de pins. [compact] = disques seuls (lignes du classement, carte
/// focus) ; sinon disque + libellé (« Or · 1er du classement »).
class PawPinsRow618 extends StatelessWidget {
  const PawPinsRow618({super.key, required this.pins, this.compact = false, this.onDark = false});

  final PawPins618 pins;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final codes = <int>[
      if (pins.podium != null) pins.podium!,
      if (pins.firstPackLeader) 4,
    ];
    if (codes.isEmpty) return const SizedBox.shrink();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final children = <Widget>[];
    for (final c in codes) {
      final label = pawPinLabel618(c);
      if (children.isNotEmpty) children.add(SizedBox(width: compact ? 3 : 6));
      if (compact) {
        children.add(Semantics(
          label: label,
          child: Tooltip(
            message: label,
            child: PawPinDisc618(key: ValueKey<String>('pin618_$c'), code: c, size: 18),
          ),
        ));
        continue;
      }
      final st = PawPinStyle618.of(c);
      final Color bg = onDark
          ? const Color(0x33FFFFFF)
          : (dark ? st.dark.withValues(alpha: 0.30) : st.light.withValues(alpha: 0.45));
      final Color ink = onDark ? Colors.white : (dark ? st.light : (c == 4 ? st.dark : st.ink));
      children.add(Container(
        key: ValueKey<String>('pin618_$c'),
        padding: const EdgeInsets.fromLTRB(3, 3, 9, 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: onDark ? const Color(0x66FFFFFF) : st.dark.withValues(alpha: 0.7)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PawPinDisc618(code: c, size: 18),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink, height: 1.1),
            ),
          ),
        ]),
      ));
    }
    return Wrap(
      key: const ValueKey<String>('pins618_row'),
      spacing: 0,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
