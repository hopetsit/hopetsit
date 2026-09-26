// v590 (26/09) — handoff « Améliorer boutons et profil PawMap » §2 et §4.
//
// La CARTE FOCUS : 1er appui sur un marqueur (personne, ami, moi, demande)
// → la carte zoome sur lui et cette carte fixe apparaît en haut, entre les
// deux barres. « Profil › » (ou un 2e appui sur le marqueur) ouvre la fiche
// existante de l'app ; ✕ ferme et ramène la carte au cadrage d'avant.
// Remplace l'étiquette « Prénom · Voir le profil » qui débordait au zoom.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../utils/pawmap_theme.dart';
import 'pawmap_jewel.dart';

class PawFocusInfo {
  const PawFocusInfo({
    required this.key,
    required this.name,
    required this.role,
    required this.info,
    required this.onOpen,
    this.avatar = '',
    this.live = false,
    this.friend = false,
    this.icon,
  });

  /// Identifiant du marqueur (id de la personne, `req:<id>`, `me`).
  final String key;
  final String name;

  /// owner | sitter | walker (couleur de l'anneau et du bouton « Profil »).
  final String role;
  final String info;
  final String avatar;
  final bool live;
  final bool friend;

  /// Icône quand il n'y a pas de photo (demande : maison ; sinon patte).
  final IconData? icon;
  final VoidCallback onOpen;
}

class PawFocusCard extends StatelessWidget {
  const PawFocusCard({super.key, required this.info, required this.onClose});

  final PawFocusInfo info;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    final PawJewelPalette pal = info.friend
        ? const PawJewelPalette(
            Color(0xFFF47BB2), Color(0xFFE35A9A), Color(0xFFD6377F))
        : pawJewelForRole(info.role);
    final Color ink = dark ? const Color(0xFFF6F1EE) : const Color(0xFF1B1616);
    final Color sub = dark ? const Color(0xFFA39A97) : const Color(0xFF7A6F6C);
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('pawmap_focus_${info.key}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -8 * (1 - t)),
          child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
        ),
      ),
      child: Semantics(
        container: true,
        label: '${info.name}. ${info.info}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: info.onOpen,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [Color(0xEB2E2826), Color(0xE61A171D)]
                    : const [Color(0xF2FFFFFF), Color(0xE0FCF4F0)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFF78281E).withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 30,
                  spreadRadius: -14,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                _avatar(pal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              info.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ink,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (info.live) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E9E48),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (info.info.isNotEmpty)
                        Text(
                          info.info,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: sub,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // « Profil › » : dégradé du rôle, 34 de haut.
                GestureDetector(
                  key: const ValueKey<String>('pawmap_focus_open'),
                  onTap: info.onOpen,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                    decoration: BoxDecoration(
                      gradient: pal.gradient,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: pal.mid.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: -4,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'pawmap590_focus_profile'.tr,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const PawSymbol(PawSymbols.chevronRight, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // ✕ fermer : 30 px, fond carte, liseré 1 px.
                Semantics(
                  button: true,
                  label: 'pawmap590_focus_close'.tr,
                  child: GestureDetector(
                    key: const ValueKey<String>('pawmap_focus_close'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: SizedBox(
                      width: 36,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: dark ? const Color(0xFF2A2321) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFF78281E).withValues(alpha: 0.12),
                            ),
                          ),
                          child: PawSymbol(PawSymbols.close, size: 16, color: sub),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(PawJewelPalette pal) {
    final bool hasPhoto = info.avatar.startsWith('http');
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: pal.gradient),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(1.5),
        child: ClipOval(
          child: hasPhoto
              ? CachedNetworkImage(
                  imageUrl: info.avatar,
                  fit: BoxFit.cover,
                  memCacheWidth: 150,
                  errorWidget: (_, __, ___) => _fallback(pal),
                  placeholder: (_, __) => _fallback(pal),
                )
              : _fallback(pal),
        ),
      ),
    );
  }

  Widget _fallback(PawJewelPalette pal) => DecoratedBox(
        decoration: BoxDecoration(gradient: pal.gradient),
        child: Center(
          child: PawSymbol(info.icon ?? Icons.pets_rounded, size: 18),
        ),
      );
}
