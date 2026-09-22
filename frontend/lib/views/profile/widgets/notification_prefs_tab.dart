// v565 — point 19 : onglet « Notifications » des Préférences (3 rôles).
// Interrupteurs par catégorie + choix du son avec bouton d'écoute.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/notification_prefs_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/app_text.dart';

class NotificationPrefsTab extends StatelessWidget {
  final Color accent;
  const NotificationPrefsTab({super.key, required this.accent});

  static const Map<String, IconData> _categoryIcons = {
    'messages': Icons.chat_bubble_rounded,
    'bookings': Icons.event_available_rounded,
    'payments': Icons.payments_rounded,
    'friends': Icons.group_rounded,
    'pawmap': Icons.map_rounded,
    'live': Icons.share_location_rounded,
    'reviews': Icons.star_rounded,
    'subscriptions': Icons.workspace_premium_rounded,
  };

  static const Map<String, IconData> _soundIcons = {
    'default': Icons.notifications_rounded,
    'frog': Icons.water_drop_rounded,
    'bark': Icons.pets_rounded,
    'meow': Icons.pets_rounded,
    'tweet': Icons.flutter_dash_rounded,
    'vibrate': Icons.vibration_rounded,
    'silent': Icons.notifications_off_rounded,
  };

  static const Map<String, String> _soundEmoji = {
    'default': '🔔',
    'frog': '🐸',
    'bark': '🐶',
    'meow': '🐱',
    'tweet': '🦉',
    'vibrate': '📳',
    'silent': '🔕',
  };

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<NotificationPrefsController>()
        ? Get.find<NotificationPrefsController>()
        : Get.put(NotificationPrefsController());

    return Obx(() {
      final loading = c.loading.value;
      final saving = c.saving.value;
      final err = c.error.value;
      final currentSound = c.sound.value;
      final previewing = c.previewing.value;
      final cats = Map<String, bool>.from(c.categories);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileInfoBanner(
            icon: Icons.notifications_active_rounded,
            accent: accent,
            text: 'notif_prefs_intro'.tr,
          ),
          if (err.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: ProfileEmptyState(
                icon: Icons.cloud_off_rounded,
                title: err,
                accent: accent,
                error: true,
                actionLabel: 'common_retry'.tr,
                onAction: c.load,
              ),
            ),
          ProfileSectionTitle('notif_prefs_categories'.tr, icon: Icons.tune_rounded),
          Stack(
            children: [
              ProfileGroupCard(
                children: [
                  for (final key in NotificationPrefsController.categoryKeys)
                    ProfileRow(
                      icon: _categoryIcons[key] ?? Icons.notifications_rounded,
                      title: 'notif_cat_$key'.tr,
                      subtitle: 'notif_cat_${key}_sub'.tr,
                      color: accent,
                      showChevron: false,
                      trailing: AppSwitch(
                        value: cats[key] ?? true,
                        accent: accent,
                        onChanged: saving ? null : (v) => c.setCategory(key, v),
                      ),
                    ),
                ],
              ),
              if (loading)
                Positioned(
                  top: 8.h,
                  right: 12.w,
                  child: SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  ),
                ),
            ],
          ),
          ProfileSectionTitle('notif_prefs_sound'.tr, icon: Icons.volume_up_rounded),
          ProfileGroupCard(
            children: [
              for (final s in NotificationPrefsController.sounds)
                _SoundRow(
                  accent: accent,
                  label: 'notif_sound_$s'.tr,
                  emoji: _soundEmoji[s] ?? '🔔',
                  icon: _soundIcons[s] ?? Icons.notifications_rounded,
                  selected: currentSound == s,
                  playing: previewing == s,
                  canPreview: s != 'silent',
                  onSelect: saving ? null : () => c.setSound(s),
                  onPreview: () => c.preview(s),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: InterText(
              text: 'notif_prefs_footer'.tr,
              fontSize: 11.5.sp,
              color: AppColors.textSecondary(context),
              maxLines: 4,
              height: 1.35,
            ),
          ),
        ],
      );
    });
  }
}

class _SoundRow extends StatelessWidget {
  final Color accent;
  final String label;
  final String emoji;
  final IconData icon;
  final bool selected;
  final bool playing;
  final bool canPreview;
  final VoidCallback? onSelect;
  final VoidCallback onPreview;

  const _SoundRow({
    required this.accent,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.selected,
    required this.playing,
    required this.canPreview,
    required this.onSelect,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? accent : accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Text(emoji, style: TextStyle(fontSize: 18.sp)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: PoppinsText(
                text: label,
                fontSize: 14.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accent : AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (canPreview)
              IconButton(
                onPressed: onPreview,
                tooltip: 'notif_prefs_listen'.tr,
                visualDensity: VisualDensity.compact,
                // v577 — Daniel : « le petit haut-parleur animé ». Pendant
                // l'écoute, l'icône figée `graphic_eq` est remplacée par un
                // haut-parleur dont les ondes sortent en cascade.
                icon: playing
                    ? SpeakerPlayingIcon(color: accent, size: 26.sp)
                    : Icon(
                        Icons.play_circle_fill_rounded,
                        size: 26.sp,
                        // v578 — « aucun gris » : le bouton d'écoute prend la
                        // couleur du rôle, il ne se fond plus dans le texte.
                        color: accent,
                      ),
              ),
            SizedBox(width: 4.w),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 22.sp,
              // v577 — « aucun gris nulle part » : le cercle vide prend une
              // teinte pâle de la couleur du rôle, plus le gris neutre.
              color: selected ? accent : accent.withValues(alpha: 0.32),
            ),
          ],
        ),
      ),
    );
  }
}


/// v577 — Haut-parleur animé, affiché pendant l'écoute d'un son de
/// notification (Daniel, 22/09 : « le petit haut-parleur animé »).
///
/// Une seule boucle de 1,1 s : le cône respire légèrement et les deux ondes
/// sortent l'une après l'autre, en fondu. Tout est dessiné (aucune image), la
/// couleur suit l'accent du rôle. L'animation se coupe si le téléphone
/// demande moins d'animations.
class SpeakerPlayingIcon extends StatefulWidget {
  const SpeakerPlayingIcon({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<SpeakerPlayingIcon> createState() => _SpeakerPlayingIconState();
}

class _SpeakerPlayingIconState extends State<SpeakerPlayingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (BuildContext context, Widget? _) => CustomPaint(
            painter: _SpeakerPainter(
              color: widget.color,
              t: still ? 0.45 : _loop.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeakerPainter extends CustomPainter {
  _SpeakerPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint body = Paint()..color = color;

    // Respiration douce du cône (±4 %).
    final double breath =
        1 + 0.04 * math.sin(t * 2 * math.pi);
    canvas.save();
    canvas.translate(w * 0.30, h / 2);
    canvas.scale(breath, breath);
    canvas.translate(-w * 0.30, -h / 2);

    // Corps : petit rectangle arrondi + pavillon triangulaire.
    final RRect box = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.36, w * 0.16, h * 0.28),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(box, body);
    final Path horn = Path()
      ..moveTo(w * 0.26, h * 0.38)
      ..lineTo(w * 0.46, h * 0.18)
      ..lineTo(w * 0.46, h * 0.82)
      ..lineTo(w * 0.26, h * 0.62)
      ..close();
    canvas.drawPath(horn, body);
    canvas.restore();

    // Deux ondes qui sortent l'une après l'autre.
    for (int i = 0; i < 2; i++) {
      final double phase = (t + i * 0.5) % 1.0;
      final double eased = Curves.easeOut.transform(phase);
      final double radius = w * (0.22 + 0.16 * eased);
      final double fade = (1 - phase).clamp(0.0, 1.0);
      final Paint wave = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.075
        ..color = color.withValues(alpha: 0.85 * fade);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.46, h / 2), radius: radius),
        -math.pi / 3.2,
        2 * math.pi / 3.2,
        false,
        wave,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeakerPainter old) =>
      old.t != t || old.color != color;
}
