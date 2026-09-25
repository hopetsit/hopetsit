import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// Mes gains (sitter / walker) — résumé + liste paginée.
///
/// v565 (point 28) — kit Profil / Réservations : couleur du rôle, états
/// chargement / vide / erreur avec « Réessayer », type de service traduit,
/// dates localisées. Rendu atteignable depuis « Gérer mes paiements ».
class EarningsHistoryScreen extends StatefulWidget {
  const EarningsHistoryScreen({super.key});

  @override
  State<EarningsHistoryScreen> createState() => _EarningsHistoryScreenState();
}

class _EarningsHistoryScreenState extends State<EarningsHistoryScreen> {
  bool _loading = true;
  // v565 — état d'erreur explicite avec « Réessayer » (avant : catch
  // silencieux → écran « 0 € » trompeur).
  String? _error;
  List<dynamic> _earnings = [];
  Map<String, dynamic> _summary = {};
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;

  Color get _accent => currentRoleAccent();

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = Get.find<ApiClient>();
      // v18.9.8 — écran partagé sitter/walker. On route vers l'endpoint
      // role-aware sinon un walker tombait toujours sur 0€ (endpoint
      // /sitters/me/earnings filtré par sitterId, qui n'existe pas pour
      // les bookings walker). Endpoint backend créé en v18.9.8.
      final role = Get.find<AuthController>().userRole.value;
      final endpoint = role == 'walker'
          ? '/walkers/me/earnings'
          : '/sitters/me/earnings';
      final data = await api.get('$endpoint?page=$_page&limit=20');
      final map = data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (refresh || _page == 1) {
          _earnings = map['earnings'] as List<dynamic>? ?? [];
        } else {
          _earnings.addAll(map['earnings'] as List<dynamic>? ?? []);
        }
        _summary = map['summary'] as Map<String, dynamic>? ?? {};
        final pag = map['pagination'] as Map<String, dynamic>? ?? {};
        _totalPages = pag['pages'] ?? 1;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Première page en erreur → état d'erreur ; page suivante → on garde
      // la liste et on revient d'un cran.
      if (_page <= 1) {
        _error = paymentErrorMessage(e);
      } else {
        _page--;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() {
      _loadingMore = true;
      _page++;
    });
    await _loadEarnings();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'earnings_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        color: accent,
        onRefresh: () => _loadEarnings(refresh: true),
        child: _loading
            ? BookingLoadingList(accent: accent)
            : _error != null && _earnings.isEmpty
                ? BookingErrorState(
                    message: _error!,
                    onRetry: () => _loadEarnings(refresh: true),
                  )
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Summary cards ──
                      SliverToBoxAdapter(child: _buildSummary(accent)),

                      // ── Earnings list header ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: ProfileSectionTitle(
                            'earnings_history_label'.tr,
                            icon: Icons.history_rounded,
                          ),
                        ),
                      ),

                      // ── List or empty ──
                      if (_earnings.isEmpty)
                        SliverToBoxAdapter(
                          child: BookingEmptyState(
                            icon: Icons.receipt_long_rounded,
                            title: 'earnings_empty'.tr,
                            subtitle: 'v565_pay_earnings_hint'.tr,
                            accent: accent,
                            embedded: true,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 28.h),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == _earnings.length) {
                                  return _loadingMore
                                      ? Padding(
                                          padding: EdgeInsets.all(16.h),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                                color: accent),
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                }
                                if (index == _earnings.length - 3) {
                                  _loadMore();
                                }
                                return _buildEarningCard(
                                    _earnings[index] as Map<String, dynamic>,
                                    accent);
                              },
                              childCount: _earnings.length + 1,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummary(Color accent) {
    // Lot D — devise du résumé (serveur) sinon celle des lignes, jamais « EUR »
    // en dur : un promeneur en USD voyait ses totaux en euros.
    final String cur = (_summary['currency'] as String?)?.toUpperCase() ??
        (_earnings.isNotEmpty ? ((_earnings.first as Map)['currency'] ?? 'EUR').toString() : 'EUR');
    final earned = (_summary['totalEarned'] ?? 0).toDouble();
    final paidOut = (_summary['totalPaidOut'] ?? 0).toDouble();
    final pending = (_summary['pendingPayout'] ?? 0).toDouble();
    final commission = (_summary['totalCommission'] ?? 0).toDouble();

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              InterText(
                text: 'earnings_total_earned'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          PoppinsText(
            text: CurrencyHelper.format(cur, earned),
            fontSize: 30.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'earnings_paid_out'.tr,
                  CurrencyHelper.format(cur, paidOut),
                  Icons.check_circle_outline,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _summaryItem(
                  'earnings_pending'.tr,
                  CurrencyHelper.format(cur, pending),
                  Icons.schedule,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _summaryItem(
                  'earnings_commission'.tr,
                  CurrencyHelper.format(cur, commission),
                  Icons.percent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13.sp, color: Colors.white),
              SizedBox(width: 4.w),
              Flexible(
                child: InterText(
                  text: label,
                  fontSize: 10.sp,
                  color: Colors.white,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PoppinsText(
              text: value,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningCard(Map<String, dynamic> e, Color accent) {
    final netPayout = (e['netPayout'] ?? 0).toDouble();
    final totalPrice = (e['totalPrice'] ?? 0).toDouble();
    final commission = (e['commission'] ?? 0).toDouble();
    final currency = e['currency'] ?? 'EUR';
    final payoutStatus = e['payoutStatus'] ?? 'pending';
    final paidAt = e['paidAt'] != null ? DateTime.tryParse(e['paidAt']) : null;
    final payoutAt = e['payoutAt'] != null ? DateTime.tryParse(e['payoutAt']) : null;
    final provider = e['paymentProvider'] ?? '';
    final ownerName = e['owner']?['name'] ?? '';
    final serviceType = e['serviceType'] ?? '';
    final lang = Get.locale?.languageCode ?? 'fr';

    final statusColor = payoutStatus == 'completed'
        ? const Color(0xFF16A34A)
        : payoutStatus == 'processing'
            ? const Color(0xFF2563EB)
            : payoutStatus == 'failed'
                ? const Color(0xFFEF4444)
                : const Color(0xFFF59E0B);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: owner name + amount
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Icon(Icons.pets_rounded, size: 18.sp, color: accent),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ownerName.isNotEmpty)
                      PoppinsText(
                        text: ownerName,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (serviceType.isNotEmpty)
                      InterText(
                        text: translateServiceType(serviceType),
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              PoppinsText(
                text: '+${CurrencyHelper.format(currency, netPayout)}',
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF16A34A),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Details row
          // v565 — anti-débordement : date / fournisseur dans un Wrap
          // Expanded, badge de statut Flexible avec ellipsis (DE / PT longs).
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14.w,
                  runSpacing: 4.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Date
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 13.sp, color: AppColors.textSecondary(context)),
                        SizedBox(width: 4.w),
                        InterText(
                          text: paidAt != null
                              ? DateFormat('dd MMM yyyy', lang).format(paidAt)
                              : '-',
                          fontSize: 11.sp,
                          color: AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                    // Provider — v21.1.1 : Stripe purgé. Défaut Airwallex, fallback
                    // PayPal pour les anciennes payouts en historique.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider == 'paypal' ? Icons.paypal : Icons.account_balance_rounded,
                          size: 13.sp,
                          color: AppColors.textSecondary(context),
                        ),
                        SizedBox(width: 4.w),
                        InterText(
                          text: provider == 'paypal' ? 'PayPal' : 'Airwallex',
                          fontSize: 11.sp,
                          color: AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Payout status badge
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 5.w),
                      Flexible(
                        child: InterText(
                          text: _payoutStatusLabel(payoutStatus),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Breakdown
          SizedBox(height: 8.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 4.h,
            children: [
              InterText(
                text: '${'earnings_total_label'.tr}: ${CurrencyHelper.format(currency, totalPrice)}',
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
              ),
              InterText(
                text: '${'earnings_fee_label'.tr}: -${CurrencyHelper.format(currency, commission)}',
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
          if (payoutAt != null) ...[
            SizedBox(height: 4.h),
            InterText(
              text: '${'earnings_paid_on'.tr} ${DateFormat('dd MMM yyyy', lang).format(payoutAt)}',
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF16A34A),
            ),
          ],
        ],
      ),
    );
  }

  String _payoutStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'earnings_status_completed'.tr;
      case 'processing':
        return 'earnings_status_processing'.tr;
      case 'failed':
        return 'earnings_status_failed'.tr;
      default:
        return 'earnings_status_pending'.tr;
    }
  }
}
