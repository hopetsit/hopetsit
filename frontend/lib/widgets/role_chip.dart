// v569 — Daniel : « dans Accueil et Chat, en haut, le rôle modernisé à côté du
// nom ». Pastille unique pour les 3 rôles : pilule teintée, icône du rôle,
// liseré fin, libellé court qui ne déborde jamais.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';

class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role, this.compact = false});

  /// 'owner' | 'sitter' | 'walker' (insensible à la casse).
  final String role;

  /// Version serrée pour les barres de titre étroites.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lower = role.trim().toLowerCase();
    if (lower.isEmpty) return const SizedBox.shrink();
    late final Color color;
    late final IconData icon;
    late final String key;
    switch (lower) {
      case 'walker':
        color = AppColors.walkerAccent;
        icon = Icons.directions_walk_rounded;
        key = 'role_walker';
        break;
      case 'sitter':
        color = AppColors.sitterAccent;
        icon = Icons.home_rounded;
        key = 'role_sitter';
        break;
      default:
        color = AppColors.primaryColor;
        icon = Icons.pets_rounded;
        key = 'role_owner';
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7.w : 9.w,
        vertical: compact ? 2.5.h : 3.5.h,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10.sp : 11.sp, color: color),
          SizedBox(width: 3.5.w),
          Text(
            key.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: compact ? 9.5.sp : 10.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
