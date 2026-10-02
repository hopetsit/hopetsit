// 607 NEO (02/10/2026, décision de Daniel) — « Ramène tes clients ».
//  · BringClientsHomeCard607 : carte de l'accueil gardien/promeneur, montrée
//    tant qu'il n'y a AUCUNE réservation, ou quand la personne est Pionnière
//    (aucun autre prestataire à 25 km) — texte honnête, jamais de promesse de
//    revenus. Rien pour un propriétaire.
//  · MyLinkProfileTile607 : entrée « Mon lien personnel » du Profil.
//  · MyLinkSheet607 : copier le lien, message prêt à envoyer (partage système),
//    affiche A4 avec QR. Aucun envoi automatique.
//  · PioneerFicheBadge607 : pastille « Pionnier » sur la fiche publique.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/my_link607.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

typedef MyLinkLoader607 = Future<MyLink607?> Function({bool force});

Color accentFor607(String role) =>
    role == 'walker' ? AppColors.walkerAccent : AppColors.sitterAccent;

/// Pastille « Pionnier » (rectangle arrondi, jamais rond — préférence Daniel).
class PioneerBadge607 extends StatelessWidget {
  const PioneerBadge607({super.key, required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('neo607_pioneer_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.flag_rounded, size: 14, color: accent),
          const SizedBox(width: 4),
          InterText(
            text: 'neo607_pioneer_badge'.tr,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ],
      ),
    );
  }
}

class BringClientsHomeCard607 extends StatefulWidget {
  const BringClientsHomeCard607({super.key, this.loader, this.roleOverride});

  /// Tests : remplace l'appel serveur.
  final MyLinkLoader607? loader;

  /// Tests : remplace le rôle lu dans GetStorage.
  final String? roleOverride;

  @override
  State<BringClientsHomeCard607> createState() => _BringClientsHomeCard607State();
}

class _BringClientsHomeCard607State extends State<BringClientsHomeCard607> {
  MyLink607? _link;

  String get _role => widget.roleOverride ?? activeRole607();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!isProviderRole607(_role)) return;
    final loader = widget.loader ?? ({bool force = false}) => fetchMyLink607(force: force);
    final l = await loader(force: false);
    if (mounted) setState(() => _link = l);
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    if (!isProviderRole607(_role) || link == null) return const SizedBox.shrink();
    final pioneer = link.isPioneer == true;
    if (!pioneer && link.bookingsCount > 0) return const SizedBox.shrink();
    final accent = accentFor607(link.role);
    final String title;
    final String body;
    if (pioneer) {
      final base = link.role == 'walker' ? 'neo607_pioneer_title_walker' : 'neo607_pioneer_title_sitter';
      title = link.city.isNotEmpty
          ? base.tr.replaceAll('{city}', link.city)
          : '${base}_nocity'.tr;
      body = 'neo607_pioneer_body'.tr;
    } else {
      title = 'neo607_card_title'.tr;
      body = 'neo607_card_body'.tr;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        key: ValueKey<String>(pioneer ? 'neo607_home_pioneer' : 'neo607_home_card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
          boxShadow: <BoxShadow>[
            BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (pioneer) ...<Widget>[
              PioneerBadge607(accent: accent),
              const SizedBox(height: 10),
            ],
            PoppinsText(
              text: title,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
            const SizedBox(height: 6),
            InterText(
              text: body,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _PillButton607(
                    key: const ValueKey<String>('neo607_home_share'),
                    label: 'neo607_share'.tr,
                    icon: Icons.ios_share_rounded,
                    accent: accent,
                    filled: true,
                    onTap: () => shareLink607(link),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillButton607(
                    key: const ValueKey<String>('neo607_home_more'),
                    label: 'neo607_home_more_btn'.tr,
                    icon: Icons.qr_code_2_rounded,
                    accent: accent,
                    filled: false,
                    onTap: () => MyLinkSheet607.show(context, link),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton607 extends StatelessWidget {
  const _PillButton607({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? accent : accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: filled ? Colors.white : accent),
              const SizedBox(width: 6),
              Flexible(
                child: InterText(
                  text: label,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : accent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feuille « Ton lien personnel ».
class MyLinkSheet607 extends StatefulWidget {
  const MyLinkSheet607({super.key, required this.link});
  final MyLink607 link;

  static Future<void> show(BuildContext context, MyLink607 link) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MyLinkSheet607(link: link),
    );
  }

  @override
  State<MyLinkSheet607> createState() => _MyLinkSheet607State();
}

class _MyLinkSheet607State extends State<MyLinkSheet607> {
  bool _posterBusy = false;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    CustomSnackbar.showSuccess(title: 'neo607_copied'.tr, message: text);
  }

  Future<void> _poster() async {
    if (_posterBusy) return;
    setState(() => _posterBusy = true);
    final ok = await downloadPoster607(widget.link);
    if (!mounted) return;
    setState(() => _posterBusy = false);
    if (!ok) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: 'neo607_poster_error'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final accent = accentFor607(link.role);
    final message = shareMessage607(link);
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey<String>('neo607_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PoppinsText(
                      text: 'neo607_sheet_title'.tr,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  if (link.isPioneer == true) PioneerBadge607(accent: accent),
                ],
              ),
              const SizedBox(height: 12),
              _box(
                context,
                accent,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SelectableText(
                        link.url.replaceFirst('https://', ''),
                        key: const ValueKey<String>('neo607_sheet_url'),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accent),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('neo607_copy'),
                      tooltip: 'neo607_copy'.tr,
                      icon: Icon(Icons.copy_rounded, color: accent),
                      onPressed: () => _copy(link.url),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InterText(
                text: 'neo607_message_btn'.tr,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              const SizedBox(height: 6),
              _box(
                context,
                accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    InterText(
                      key: const ValueKey<String>('neo607_message_text'),
                      text: message,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary(context),
                    ),
                    InkWell(
                      key: const ValueKey<String>('neo607_copy_message'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _copy(message),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.copy_rounded, size: 16, color: accent),
                            const SizedBox(width: 4),
                            InterText(
                              text: 'neo607_copy'.tr.split(' ').first,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PillButton607(
                key: const ValueKey<String>('neo607_sheet_share'),
                label: 'neo607_share'.tr,
                icon: Icons.ios_share_rounded,
                accent: accent,
                filled: true,
                onTap: () => shareLink607(link),
              ),
              const SizedBox(height: 10),
              _PillButton607(
                key: const ValueKey<String>('neo607_sheet_poster'),
                label: _posterBusy ? '…' : 'neo607_poster'.tr,
                icon: Icons.picture_as_pdf_rounded,
                accent: accent,
                filled: false,
                onTap: _poster,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(BuildContext context, Color accent, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}

/// Entrée « Mon lien personnel » de la page Profil (gardien / promeneur).
class MyLinkProfileTile607 extends StatefulWidget {
  const MyLinkProfileTile607({super.key, required this.role, this.loader});
  final String role;
  final MyLinkLoader607? loader;

  @override
  State<MyLinkProfileTile607> createState() => _MyLinkProfileTile607State();
}

class _MyLinkProfileTile607State extends State<MyLinkProfileTile607> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    final loader = widget.loader ?? ({bool force = false}) => fetchMyLink607(force: force);
    final link = await loader(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (link == null) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: 'neo607_link_error'.tr);
      return;
    }
    await MyLinkSheet607.show(context, link);
  }

  @override
  Widget build(BuildContext context) {
    if (!isProviderRole607(widget.role)) return const SizedBox.shrink();
    final accent = accentFor607(widget.role);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey<String>('neo607_profile_tile'),
          borderRadius: BorderRadius.circular(16),
          onTap: _open,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.qr_code_2_rounded, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      InterText(
                        text: 'neo607_profile_entry'.tr,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                      const SizedBox(height: 2),
                      InterText(
                        text: 'neo607_profile_entry_sub'.tr,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
                _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                      )
                    : Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille « Pionnier » sur la fiche publique d'un gardien / promeneur.
/// Lit `GET /public/providers/badge/:role/:id` ; rien tant qu'on ne sait pas.
class PioneerFicheBadge607 extends StatefulWidget {
  const PioneerFicheBadge607({super.key, required this.role, required this.providerId, this.fetcher});
  final String role;
  final String providerId;
  final Future<bool> Function(String role, String id)? fetcher;

  @override
  State<PioneerFicheBadge607> createState() => _PioneerFicheBadge607State();
}

final Map<String, bool> _badgeCache607 = <String, bool>{};

Future<bool> fetchPioneerBadge607(String role, String id) async {
  final key = '$role/$id';
  final hit = _badgeCache607[key];
  if (hit != null) return hit;
  try {
    final client = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
    final res = await client
        .get('/public/providers/badge/$role/$id')
        .timeout(const Duration(seconds: 6));
    final v = res is Map && res['isPioneer'] == true;
    _badgeCache607[key] = v;
    return v;
  } catch (_) {
    return false;
  }
}

class _PioneerFicheBadge607State extends State<PioneerFicheBadge607> {
  bool _pioneer = false;

  @override
  void initState() {
    super.initState();
    if (widget.providerId.isEmpty || !isProviderRole607(widget.role)) return;
    (widget.fetcher ?? fetchPioneerBadge607)(widget.role, widget.providerId).then((v) {
      if (mounted && v) setState(() => _pioneer = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_pioneer) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(child: PioneerBadge607(accent: accentFor607(widget.role))),
    );
  }
}
