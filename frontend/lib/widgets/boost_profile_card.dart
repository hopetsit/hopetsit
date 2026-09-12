// v19.1.1 — Boost profil : boutons côte à côte sans CrossAxisAlignment.stretch
// (qui cassait le rendu des sections en-dessous sur le profil owner).
// v23.1.390 — Daniel : 4 carrés ALIGNÉS sur une ligne (les 3 profils).
// v561 — handoff « Paw Buttons » (Daniel, 12/09) : les 4 carrés reprennent
// EXACTEMENT le design des cartes de la boutique (verre dépoli, dégradé 165°,
// disque blanc + icône pleine, titre + description). Design uniquement : mêmes
// destinations (onglets 0-3 de la boutique).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/paw_card_icons.dart';

class BoostProfileCard extends StatelessWidget {
  final String role; // 'owner' | 'sitter' | 'walker'

  const BoostProfileCard({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E9E2),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PawShopCard(
              colors: const [Color(0xFFFF6B4A), Color(0xFFE0361F)],
              shadow: const Color(0xFFE0361F),
              svg: PawCardIcons.boost,
              title: 'shop_tile_boost'.tr,
              subtitle: 'shop_card_boost_sub'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 0)),
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: PawShopCard(
              colors: const [Color(0xFF9B6BFF), Color(0xFF6A34E0)],
              shadow: const Color(0xFF6A34E0),
              svg: PawCardIcons.follow,
              title: 'shop_tile_premium'.tr,
              subtitle: 'shop_card_follow_sub'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 1)),
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: PawShopCard(
              colors: const [Color(0xFFFFC23D), Color(0xFFF0900A)],
              shadow: const Color(0xFFF0900A),
              svg: PawCardIcons.spot,
              title: 'shop_tile_map_boost'.tr,
              subtitle: 'shop_card_spot_sub'.tr,
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 2)),
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: PawShopCard(
              colors: const [Color(0xFF3A3028), Color(0xFF0F0B08)],
              shadow: Colors.black,
              svg: PawCardIcons.premium,
              title: 'shop_tile_pawpremium'.tr,
              subtitle: 'shop_card_premium_sub'.tr,
              titleColor: const Color(0xFFFFD34D),
              onTap: () => Get.to(() => const CoinShopScreen(initialTab: 3)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte « offre » du design Paw Buttons (ratio 1/1,75, rayon 22, bord blanc
/// translucide, reflet haut, ombre colorée, disque blanc 56 px + icône 26 px).
class PawShopCard extends StatelessWidget {
  const PawShopCard({
    super.key,
    required this.colors,
    required this.shadow,
    required this.svg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor = Colors.white,
    this.active = true,
  });

  final List<Color> colors;
  final Color shadow;
  final String svg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color titleColor;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AspectRatio(
        aspectRatio: 1 / 1.75,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: const Alignment(-0.6, -1),
              end: const Alignment(0.6, 1),
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1),
            boxShadow: [
              BoxShadow(
                color: shadow.withValues(alpha: active ? 0.6 : 0.35),
                blurRadius: active ? 26 : 18,
                spreadRadius: -12,
                offset: Offset(0, active ? 12 : 10),
              ),
            ],
          ),
          child: LayoutBuilder(builder: (context, c) {
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: c.maxHeight * 0.45,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 1,
                  child: ColoredBox(color: Colors.white.withValues(alpha: 0.55)),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(4.w, 14.h, 4.w, 10.h),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 14,
                              spreadRadius: -6,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: SvgPicture.string(svg, width: 26, height: 26),
                      ),
                      SizedBox(height: 10.h),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.26,
                            color: titleColor,
                            height: 1.1,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
