import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/walker_model.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/verified_badge.dart';

/// v23.1 part 37 — WalkerDetailScreen équivalent de ServiceProviderDetailScreen
/// pour les walkers. Affiche le profil public complet (avatar, nom, rating,
/// bio, skills, ville, langue, tarifs walking 30/60min, badge vérifié).
///
/// Utilisé quand owner clique "Voir profil promeneur" sur une candidature
/// walker dans home_quick_action_bar.
class WalkerDetailScreen extends StatefulWidget {
  final String walkerId;

  const WalkerDetailScreen({super.key, required this.walkerId});

  @override
  State<WalkerDetailScreen> createState() => _WalkerDetailScreenState();
}

class _WalkerDetailScreenState extends State<WalkerDetailScreen> {
  static const Color _walkerAccent = Color(0xFF16A34A);
  WalkerModel? _walker;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWalker();
  }

  Future<void> _loadWalker() async {
    setState(() => _loading = true);
    try {
      final repo = Get.find<WalkerRepository>();
      final walker = await repo.getWalkerProfile(widget.walkerId);
      if (mounted) {
        setState(() {
          _walker = walker;
          _loading = false;
        });
      }
    } catch (e) {
      AppLogger.logError('walker.getProfile failed', error: e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
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
        iconTheme: const IconThemeData(color: _walkerAccent),
        title: PoppinsText(
          text: _walker?.name ?? 'Promeneur',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _walkerAccent))
          : _error != null
              ? _buildError()
              : _walker == null
                  ? const Center(child: Text('Walker introuvable'))
                  : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                color: const Color(0xFFE53935), size: 48.sp),
            SizedBox(height: 12.h),
            InterText(
              text: 'Impossible de charger le profil du promeneur.',
              fontSize: 14.sp,
              textAlign: TextAlign.center,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: _loadWalker,
              style: ElevatedButton.styleFrom(backgroundColor: _walkerAccent),
              child: const Text('Réessayer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final w = _walker!;
    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        // Header card : avatar + nom + verified badge + rating
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.appBar(context),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 40.r,
                backgroundColor: _walkerAccent.withValues(alpha: 0.15),
                backgroundImage: w.avatar.url.isNotEmpty
                    ? CachedNetworkImageProvider(w.avatar.url)
                    : null,
                child: w.avatar.url.isEmpty
                    ? Icon(Icons.person, color: _walkerAccent, size: 40.sp)
                    : null,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: PoppinsText(
                            text: w.name,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        VerifiedBadge(isVerified: w.verified),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: _walkerAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: InterText(
                        text: 'role_walker'.tr,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: _walkerAccent,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: const Color(0xFFFFB400), size: 18.sp),
                        SizedBox(width: 4.w),
                        InterText(
                          text: w.rating > 0
                              ? '${w.rating.toStringAsFixed(1)} (${w.reviewsCount} avis)'
                              : 'Pas encore d\'avis',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Bio
        if ((w.bio ?? '').isNotEmpty) ...[
          _section('À propos', Icons.person_outline, w.bio!),
          SizedBox(height: 12.h),
        ],

        // Localisation
        if ((w.city ?? '').isNotEmpty || w.address.isNotEmpty)
          _section(
            'Localisation',
            Icons.location_on_outlined,
            (w.city != null && w.city!.isNotEmpty) ? w.city! : w.address,
          ),
        SizedBox(height: 12.h),

        // Langue
        if (w.language.isNotEmpty)
          _section('Langue parlée', Icons.language, w.language),
        SizedBox(height: 12.h),

        // Tarifs walking
        if (w.walkRates.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.appBar(context),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        color: _walkerAccent, size: 20.sp),
                    SizedBox(width: 8.w),
                    PoppinsText(
                      text: 'Tarifs',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                ...w.walkRates.where((r) => r.enabled && r.basePrice > 0).map(
                      (r) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InterText(
                              text: 'Promenade ${r.durationMinutes} min',
                              fontSize: 13.sp,
                            ),
                            InterText(
                              text: CurrencyHelper.format(
                                  w.currency, r.basePrice),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: _walkerAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
        ],

        // Service info
        if (w.service.isNotEmpty)
          _section(
            'Services',
            Icons.work_outline,
            w.service.map((s) => s.replaceAll('_', ' ')).join(', '),
          ),
      ],
    );
  }

  Widget _section(String title, IconData icon, String body) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.appBar(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _walkerAccent, size: 20.sp),
              SizedBox(width: 8.w),
              PoppinsText(
                text: title,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          InterText(
            text: body,
            fontSize: 13.sp,
            color: AppColors.textPrimary(context),
          ),
        ],
      ),
    );
  }
}
