import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/shared/availability_calendar_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v565 (lot app-calendar-wallet) — rangée de 2 grandes cartes d'action sous
/// l'en-tête des profils sitter et walker :
///   📅 Mes disponibilités — sous-titre « N jours dispo ce mois » (réel)
///   💼 Portefeuille       — sous-titre solde réel, ou « Configurer l'IBAN »
///                           si aucun IBAN n'est enregistré.
/// Carte blanche, emoji sur carré teinté couleur du rôle, chevron, pression
/// animée. Les 3 lectures (dispos, wallet, IBAN) sont indépendantes et
/// tolérantes : une erreur retombe sur un libellé neutre, jamais sur un crash.
/// Après retour d'une sous-page, les chiffres sont rechargés.
class ProviderQuickActions extends StatefulWidget {
  const ProviderQuickActions({
    super.key,
    required this.role,
    required this.accent,
  });

  /// 'sitter' | 'walker'
  final String role;
  final Color accent;

  @override
  State<ProviderQuickActions> createState() => _ProviderQuickActionsState();
}

class _ProviderQuickActionsState extends State<ProviderQuickActions> {
  final ApiClient _api =
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();

  bool _loading = true;
  int? _daysThisMonth;
  double? _balance;
  String _currency = 'EUR';
  bool? _ibanConfigured; // null = inconnu (erreur réseau)

  String get _base => widget.role == 'walker' ? '/walkers' : '/sitters';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    await Future.wait<void>([_loadAvailability(), _loadWallet(), _loadIban()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAvailability() async {
    try {
      final resp = await _api.get('$_base/me/availability', requiresAuth: true);
      if (resp is! Map) return;
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);
      var n = 0;
      for (final e in (resp['availableDates'] as List?) ?? const []) {
        final d = DateTime.tryParse(e.toString());
        if (d == null) continue;
        final u = d.toUtc();
        final k = DateTime.utc(u.year, u.month, u.day);
        if (k.year == now.year && k.month == now.month && !k.isBefore(today)) {
          n++;
        }
      }
      _daysThisMonth = n;
    } catch (_) {
      _daysThisMonth = null;
    }
  }

  Future<void> _loadWallet() async {
    try {
      final w = await _api.get('/wallet', requiresAuth: true);
      if (w is Map) {
        _balance = (w['balance'] as num?)?.toDouble() ?? 0;
        _currency = (w['currency'] as String?) ?? 'EUR';
      }
    } catch (_) {
      _balance = null;
    }
  }

  Future<void> _loadIban() async {
    try {
      final r = await _api.get(ApiEndpoints.sitterMeIban, requiresAuth: true);
      if (r is Map) {
        final masked = (r['ibanNumberMasked'] ?? '').toString();
        _ibanConfigured = masked.isNotEmpty;
      }
    } catch (_) {
      _ibanConfigured = null;
    }
  }

  String get _availabilitySubtitle {
    if (_loading) return '…';
    final n = _daysThisMonth;
    if (n == null) return 'quick_availability_hint'.tr;
    return 'quick_availability_days'.trParams({'n': '$n'});
  }

  String get _walletSubtitle {
    if (_loading) return '…';
    if (_ibanConfigured == false) return 'quick_wallet_iban'.tr;
    final b = _balance;
    if (b == null) return 'quick_wallet_hint'.tr;
    return CurrencyHelper.format(_currency, b);
  }

  void _openCalendar() {
    Get.to(() => AvailabilityCalendarScreen(role: widget.role))
        ?.then((_) => _load());
  }

  void _openWallet() {
    Get.to(() => WalletScreen(accent: widget.accent))?.then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            emoji: '📅',
            title: 'quick_availability_title'.tr,
            subtitle: _availabilitySubtitle,
            accent: widget.accent,
            highlight: false,
            onTap: _openCalendar,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _QuickActionCard(
            emoji: '💼',
            title: 'quick_wallet_title'.tr,
            subtitle: _walletSubtitle,
            accent: widget.accent,
            // IBAN manquant → sous-titre mis en avant (ambre) pour attirer l'œil.
            highlight: !_loading && _ibanConfigured == false,
            onTap: _openWallet,
          ),
        ),
      ],
    );
  }
}

/// Carte d'action : emoji sur carré teinté, titre, sous-titre, chevron.
/// Hauteur FIXE (les 2 cartes restent alignées sans `stretch`/`IntrinsicHeight`),
/// textes en ellipse → aucun débordement quelle que soit la langue.
class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.highlight,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final bool highlight;
  final VoidCallback onTap;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    const amber = Color(0xFFE8920A);
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          height: 118.h,
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 10.w, 12.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: accent.withValues(alpha: _pressed ? 0.45 : 0.16),
              width: 1.1,
            ),
            boxShadow: _pressed ? null : AppColors.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.emoji,
                      style: TextStyle(fontSize: 20.sp, height: 1.0),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 22.sp, color: accent),
                ],
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PoppinsText(
                      text: widget.title,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: widget.subtitle,
                      fontSize: 11.5.sp,
                      fontWeight:
                          widget.highlight ? FontWeight.w700 : FontWeight.w500,
                      color: widget.highlight
                          ? amber
                          : AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
