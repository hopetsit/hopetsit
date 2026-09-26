// v589 (26/09/2026) — FENÊTRES D'ANNONCE de la PawMap.
// Daniel : « balancer des pop-up sur la PawMap qui apparaissent UNE fois pour
// lancer un message, genre mettre à jour l'app ».
//
// Écrites dans l'admin (« Annonces PawMap »), lues à l'ouverture de la carte
// (`GET /app-config/announcements`, filtrées par le serveur : rôle,
// plateforme, build, dates). Chaque appareil n'en voit une qu'UNE fois :
// l'id est mémorisé dès l'affichage. Jamais pendant la découverte guidée.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/network/api_client.dart';
import '../../../utils/pawmap_theme.dart';
import 'pawmap_buttons.dart';

const String kPawAnnounceSeenKey = 'pawmap_announce_seen_v589';

class PawAnnouncement {
  const PawAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.url,
  });

  final String id;
  final String title;
  final String body;
  final String kind; // info | update | link
  final String url;

  static PawAnnouncement? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    final id = (m['id'] ?? '').toString();
    final title = (m['title'] ?? '').toString().trim();
    final body = (m['body'] ?? '').toString().trim();
    if (id.isEmpty || (title.isEmpty && body.isEmpty)) return null;
    return PawAnnouncement(
      id: id,
      title: title,
      body: body,
      kind: (m['kind'] ?? 'info').toString(),
      url: (m['url'] ?? '').toString(),
    );
  }
}

/// Première annonce jamais vue sur cet appareil (pure, testée).
PawAnnouncement? pickUnseenAnnouncement(
    List<PawAnnouncement> list, Iterable<String> seen) {
  final s = seen.toSet();
  for (final a in list) {
    if (!s.contains(a.id)) return a;
  }
  return null;
}

bool _busy = false;

/// Va chercher les annonces et montre la première pas encore vue.
Future<void> maybeShowPawMapAnnouncement(BuildContext context,
    {bool Function()? canShow}) async {
  if (_busy) return;
  _busy = true;
  try {
    if (!Get.isRegistered<ApiClient>()) return;
    final lang = (Get.locale?.languageCode ?? 'fr').toLowerCase();
    dynamic raw;
    try {
      raw = await Get.find<ApiClient>().get('/app-config/announcements',
          queryParameters: {'lang': lang}, requiresAuth: true);
    } catch (_) {
      raw = await Get.find<ApiClient>().get('/app-config/announcements',
          queryParameters: {'lang': lang});
    }
    final list = <PawAnnouncement>[
      if (raw is Map && raw['announcements'] is List)
        for (final e in (raw['announcements'] as List))
          if (PawAnnouncement.fromJson(e) case final PawAnnouncement a) a,
    ];
    final box = GetStorage();
    final seen = <String>[
      for (final e in (box.read(kPawAnnounceSeenKey) as List? ?? const []))
        e.toString(),
    ];
    final a = pickUnseenAnnouncement(list, seen);
    if (a == null) return;
    if (!context.mounted || (canShow != null && !canShow())) return;
    // Vue = vue : mémorisée dès l'affichage (une seule fois par appareil).
    await box.write(kPawAnnounceSeenKey, [...seen, a.id].take(200).toList());
    if (!context.mounted) return;
    await showPawAnnouncement(context, a);
  } catch (e) {
    debugPrint('[PawMap] announcements failed: $e');
  } finally {
    _busy = false;
  }
}

Future<void> _openAction(PawAnnouncement a) async {
  String url = a.url;
  if (a.kind == 'update' && url.isEmpty) {
    url = GetPlatform.isIOS
        ? 'https://apps.apple.com/app/id6763645719'
        : 'https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit';
  }
  final u = Uri.tryParse(url);
  if (u == null || !u.hasScheme) return;
  try {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {/* aucune appli pour ouvrir le lien */}
}

/// La fenêtre : carte blanche chaude (encre en sombre), bandeau orange PawMap
/// avec un mégaphone, titre, message, un bouton signature. Voile encre, jamais
/// gris. Fermable par la croix ou « Plus tard » implicite (toucher dehors).
Future<void> showPawAnnouncement(BuildContext context, PawAnnouncement a) {
  final IconData icon = switch (a.kind) {
    'update' => Icons.system_update_rounded,
    'link' => Icons.open_in_new_rounded,
    _ => Icons.campaign_rounded,
  };
  final String cta = switch (a.kind) {
    'update' => 'pawmap589_announce_update'.tr,
    'link' => 'pawmap589_announce_open'.tr,
    _ => 'pawmap589_announce_ok'.tr,
  };
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'pawmap589_announce_ok'.tr,
    barrierColor: const Color(0xFF17141F).withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) {
      final dark = PawMapTheme.isDark(ctx);
      return SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                key: ValueKey<String>('pawmap_announce_${a.id}'),
                constraints: BoxConstraints(maxWidth: 420.w),
                decoration: BoxDecoration(
                  color: PawMapTheme.panelOn(ctx),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                      color: PawMapTheme.accent.withValues(alpha: 0.35), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: PawMapTheme.accent.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(16.w, 14.h, 8.w, 14.h),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFC92A12), Color(0xFF9E1F0B)],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.white, width: 1.4),
                            ),
                            child: Icon(icon, color: Colors.white, size: 21.sp),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              a.title.isNotEmpty ? a.title : 'PawMap',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'pawmap_coach_close'.tr,
                            child: GestureDetector(
                              key: const ValueKey<String>('pawmap_announce_close'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(ctx).maybePop(),
                              child: Padding(
                                padding: EdgeInsets.all(8.w),
                                child: Icon(Icons.close_rounded,
                                    color: Colors.white, size: 22.sp),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (a.body.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 4.h),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                          child: SingleChildScrollView(
                            child: Text(
                              a.body,
                              style: PawMapTheme.fontOn(ctx,
                                  size: 14.5.sp,
                                  weight: FontWeight.w600,
                                  height: 1.35,
                                  color: dark ? null : const Color(0xFF3A2A26)),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 18.h),
                      child: PawSignatureButton(
                        key: const ValueKey<String>('pawmap_announce_cta'),
                        label: cta,
                        icon: icon,
                        color: PawMapTheme.accent,
                        onTap: () {
                          Navigator.of(ctx).maybePop();
                          if (a.kind != 'info') unawaited(_openAction(a));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final t = Curves.easeOutCubic.transform(anim.value);
      return Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      );
    },
  );
}
