import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';

/// Session v15-4 — icône de tier pour l'onglet Map Boost.
///
/// Différencie visuellement Map Boost de Boost : au lieu de médailles
/// (bronze/silver/gold/platinum) partagées avec Boost, on affiche un pin
/// cartographique entouré de halos concentriques dont le nombre et la
/// couleur varient selon le tier :
///
///   bronze   → 1 pin bleu clair, pas de halo — "Découverte"
///   silver   → pin bleu + 1 halo statique    — "Visible"
///   gold     → pin or + 2 halos pulsant       — "Pin Doré"
///   platinum → pin or + 3 halos pulsant       — "Map Premium"
///
/// Les halos animés pulsent avec un léger décalage entre eux pour éviter
/// le clignotement synchrone qui fait cheap. Durée 2s full cycle.
class MapBoostPinIcon extends StatefulWidget {
  const MapBoostPinIcon({
    super.key,
    required this.tier,
    this.size = 50,
  });

  /// Tier key coming from the backend. Accepts `bronze`, `silver`, `gold`,
  /// `platinum` and the legacy alias `diamond` (maps to platinum).
  final String tier;

  /// Outer size of the whole icon square. Default 50 fits the 50x50 box
  /// used in the Map Boost package cards.
  final double size;

  @override
  State<MapBoostPinIcon> createState() => _MapBoostPinIconState();
}

class _MapBoostPinIconState extends State<MapBoostPinIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  _PinTierData _dataFor(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return const _PinTierData(
          color: Color(0xFF60A5FA), // light blue
          haloColor: AppColors.mapBoostBlue,
          haloCount: 0,
          iconData: Icons.place_outlined,
        );
      case 'silver':
        return const _PinTierData(
          color: AppColors.mapBoostBlue,
          haloColor: AppColors.mapBoostBlue,
          haloCount: 1,
          iconData: Icons.place_rounded,
        );
      case 'gold':
        return const _PinTierData(
          color: AppColors.mapBoostGold,
          haloColor: AppColors.mapBoostGold,
          haloCount: 2,
          iconData: Icons.location_on_rounded,
        );
      case 'platinum':
      case 'diamond':
        return const _PinTierData(
          color: AppColors.mapBoostGoldDeep,
          haloColor: AppColors.mapBoostGold,
          haloCount: 3,
          iconData: Icons.location_on_rounded,
        );
      default:
        return const _PinTierData(
          color: AppColors.mapBoostBlue,
          haloColor: AppColors.mapBoostBlue,
          haloCount: 0,
          iconData: Icons.place_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _dataFor(widget.tier);
    final pinSize = widget.size * 0.56; // pin proportional to frame
    final maxHalo = widget.size * 0.95; // halos nearly fill the square

    if (data.haloCount == 0) {
      // Static, no halo — keeps bronze calm.
      return SizedBox(
        width: widget.size.w,
        height: widget.size.w,
        child: Center(
          child: Icon(
            data.iconData,
            size: pinSize.sp,
            color: data.color,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.size.w,
      height: widget.size.w,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < data.haloCount; i++)
                _buildHalo(
                  index: i,
                  count: data.haloCount,
                  color: data.haloColor,
                  maxSize: maxHalo,
                ),
              Icon(
                data.iconData,
                size: pinSize.sp,
                color: data.color,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Each halo is offset in time by `index / count` so the pulses don't
  /// all fire at once — looks more like a live radar sweep.
  Widget _buildHalo({
    required int index,
    required int count,
    required Color color,
    required double maxSize,
  }) {
    final offset = index / count;
    final progress = (_ctrl.value + offset) % 1.0;
    // Expand from 40% to 100% of maxSize across the cycle.
    final currentSize = maxSize * (0.4 + 0.6 * progress);
    // Fade from 0.35 to 0 as the halo grows.
    final opacity = (1.0 - progress) * 0.35;
    return Container(
      width: currentSize.w,
      height: currentSize.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}

class _PinTierData {
  final Color color;
  final Color haloColor;
  final int haloCount;
  final IconData iconData;

  const _PinTierData({
    required this.color,
    required this.haloColor,
    required this.haloCount,
    required this.iconData,
  });
}
