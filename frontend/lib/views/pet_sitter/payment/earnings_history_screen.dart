import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

class EarningsHistoryScreen extends StatefulWidget {
  const EarningsHistoryScreen({super.key});

  @override
  State<EarningsHistoryScreen> createState() => _EarningsHistoryScreenState();
}

class _EarningsHistoryScreenState extends State<EarningsHistoryScreen> {
  bool _loading = true;
  List<dynamic> _earnings = [];
  Map<String, dynamic> _summary = {};
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;

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
      });
    }
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/sitters/me/earnings?page=$_page&limit=20');
      final map = data as Map<String, dynamic>;
      setState(() {
        if (refresh || _page == 1) {
          _earnings = map['earnings'] as List<dynamic>? ?? [];
        } else {
          _earnings.addAll(map['earnings'] as List<dynamic>? ?? []);
        }
        _summary = map['summary'] as Map<String, dynamic>? ?? {};
        final pag = map['pagination'] as Map<String, dynamic>? ?? {};
        _totalPages = pag['pages'] ?? 1;
      });
    } catch (_) {
      // silently handle
    } finally {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
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
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primaryColor,
        title: InterText(
          text: 'earnings_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadEarnings(refresh: true),
              child: CustomScrollView(
                slivers: [
                  // ── Summary cards ──
                  SliverToBoxAdapter(child: _buildSummary()),

                  // ── Earnings list header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
                      child: InterText(
                        text: 'earnings_history_label'.tr,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),

                  // ── List or empty ──
                  _earnings.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long,
                                    size: 48.sp,
                                    color: AppColors.greyText.withOpacity(0.4)),
                                SizedBox(height: 12.h),
                                InterText(
                                  text: 'earnings_empty'.tr,
                                  fontSize: 14.sp,
                                  color: AppColors.textSecondary(context),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index == _earnings.length) {
                                return _loadingMore
                                    ? Padding(
                                        padding: EdgeInsets.all(16.h),
                                        child: const Center(
                                            child:
                                                CircularProgressIndicator()),
                                      )
                                    : const SizedBox.shrink();
                              }
                              if (index == _earnings.length - 3) {
                                _loadMore();
                              }
                              return _buildEarningCard(
                                  _earnings[index] as Map<String, dynamic>);
                            },
                            childCount: _earnings.length + 1,
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummary() {
    final earned = (_summary['totalEarned'] ?? 0).toDouble();
    final paidOut = (_summary['totalPaidOut'] ?? 0).toDouble();
    final pending = (_summary['pendingPayout'] ?? 0).toDouble();
    final commission = (_summary['totalCommission'] ?? 0).toDouble();

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryColor, AppColors.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'earnings_total_earned'.tr,
            fontSize: 13.sp,
            color: Colors.white70,
          ),
          SizedBox(height: 4.h),
          PoppinsText(
            text: CurrencyHelper.format('EUR', earned),
            fontSize: 28.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'earnings_paid_out'.tr,
                  CurrencyHelper.format('EUR', paidOut),
                  Icons.check_circle_outline,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _summaryItem(
                  'earnings_pending'.tr,
                  CurrencyHelper.format('EUR', pending),
                  Icons.schedule,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _summaryItem(
                  'earnings_commission'.tr,
                  CurrencyHelper.format('EUR', commission),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14.sp, color: Colors.white70),
            SizedBox(width: 4.w),
            Flexible(
              child: InterText(
                text: label,
                fontSize: 10.sp,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        PoppinsText(
          text: value,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _buildEarningCard(Map<String, dynamic> e) {
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

    final statusColor = payoutStatus == 'completed'
        ? Colors.green
        : payoutStatus == 'processing'
            ? Colors.blue
            : payoutStatus == 'failed'
                ? Colors.red
                : Colors.orange;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: owner name + amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ownerName.isNotEmpty)
                      InterText(
                        text: ownerName,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    if (serviceType.isNotEmpty)
                      InterText(
                        text: serviceType,
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                      ),
                  ],
                ),
              ),
              PoppinsText(
                text: '+${CurrencyHelper.format(currency, netPayout)}',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.green.shade700,
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Details row
          Row(
            children: [
              // Date
              Icon(Icons.calendar_today, size: 13.sp, color: AppColors.textSecondary(context)),
              SizedBox(width: 4.w),
              InterText(
                text: paidAt != null
                    ? DateFormat('dd MMM yyyy').format(paidAt)
                    : '-',
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(width: 14.w),

              // Provider
              Icon(
                provider == 'stripe' ? Icons.credit_card : Icons.paypal,
                size: 13.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(width: 4.w),
              InterText(
                text: provider == 'stripe' ? 'Stripe' : 'PayPal',
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
              ),
              const Spacer(),

              // Payout status badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: InterText(
                  text: _payoutStatusLabel(payoutStatus),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),

          // Breakdown
          SizedBox(height: 8.h),
          Row(
            children: [
              InterText(
                text: '${'earnings_total_label'.tr}: ${CurrencyHelper.format(currency, totalPrice)}',
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(width: 12.w),
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
              text: '${'earnings_paid_on'.tr} ${DateFormat('dd MMM yyyy').format(payoutAt)}',
              fontSize: 11.sp,
              color: Colors.green,
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
