import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// Sprint 6 step 3 — owner views the latest visit report for a booking.
///
/// v565 — kit Profil / Réservations : états chargement / vide / erreur avec
/// « Réessayer », humeur traduite, activités en pilules, photos en grille.
class ViewVisitReportScreen extends StatefulWidget {
  final String bookingId;
  const ViewVisitReportScreen({super.key, required this.bookingId});

  @override
  State<ViewVisitReportScreen> createState() => _ViewVisitReportScreenState();
}

class _ViewVisitReportScreenState extends State<ViewVisitReportScreen> {
  final ApiClient _api = Get.isRegistered<ApiClient>()
      ? Get.find<ApiClient>()
      : ApiClient();
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  Color get _accent => currentRoleAccent();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.get(
        '/bookings/${widget.bookingId}/visit-report',
        requiresAuth: true,
      );
      if (r is Map && r['report'] is Map) {
        _report = Map<String, dynamic>.from(r['report']);
      } else {
        _report = null;
      }
    } catch (e) {
      _error = paymentErrorMessage(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _moodIcon(String mood) {
    switch (mood) {
      case 'happy':
        return '😊';
      case 'anxious':
        return '😟';
      case 'calm':
      default:
        return '😌';
    }
  }

  // v565 — libellé traduit de l'humeur (avant : code brut en capitales).
  String _moodLabel(String mood) {
    switch (mood) {
      case 'happy':
        return 'v565_vr_mood_happy'.tr;
      case 'anxious':
        return 'v565_vr_mood_anxious'.tr;
      case 'calm':
      default:
        return 'v565_vr_mood_calm'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    // v565 — kit Profil : états chargement / vide / erreur (« Réessayer »),
    // humeur en carte, notes, activités en pilules, grille de photos.
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'v565_vr_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        color: accent,
        onRefresh: _load,
        child: _loading
            ? BookingLoadingList(accent: accent)
            : _error != null
                ? BookingErrorState(message: _error!, onRetry: _load)
                : _report == null
                    ? BookingEmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'v565_vr_none'.tr,
                        accent: accent,
                      )
                    : _content(context, accent),
      ),
    );
  }

  Widget _content(BuildContext context, Color accent) {
    final r = _report!;
    final mood = (r['mood'] ?? 'calm').toString();
    final notes = (r['notes'] ?? '').toString();
    final activities = r['activities'] is List
        ? (r['activities'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : const <String>[];
    final photos = (r['photos'] as List? ?? const []).map((e) => e.toString()).toList();
    final createdAt = DateTime.tryParse((r['createdAt'] ?? '').toString());
    final dateLabel = createdAt != null
        ? DateFormat.yMMMd(Get.locale?.languageCode).add_Hm().format(createdAt.toLocal())
        : '';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
      children: [
        // Humeur
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            children: [
              Text(_moodIcon(mood), style: TextStyle(fontSize: 34.sp)),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'v565_vr_mood'.tr,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                    PoppinsText(
                      text: _moodLabel(mood),
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateLabel.isNotEmpty)
                      InterText(
                        text: dateLabel,
                        fontSize: 11.sp,
                        color: AppColors.textSecondary(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (notes.isNotEmpty) ...[
          ProfileSectionTitle('v565_vr_notes'.tr, icon: Icons.notes_rounded),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: InterText(
              text: notes,
              fontSize: 14.sp,
              color: AppColors.textPrimary(context),
              height: 1.45,
              maxLines: 60,
            ),
          ),
        ],
        if (activities.isNotEmpty) ...[
          ProfileSectionTitle(
            'v565_pay_vr_activities_title'.tr,
            icon: Icons.directions_run_rounded,
          ),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final a in activities)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: InterText(
                    text: a.trim(),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
            ],
          ),
        ],
        if (photos.isNotEmpty) ...[
          ProfileSectionTitle(
            'v565_pay_vr_photos'.trParams({'count': photos.length.toString()}),
            icon: Icons.photo_library_rounded,
          ),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final url in photos)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: 104.w,
                    height: 104.w,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 104.w,
                      height: 104.w,
                      color: accent.withValues(alpha: 0.08),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 104.w,
                      height: 104.w,
                      color: accent.withValues(alpha: 0.08),
                      child: Icon(Icons.broken_image_outlined,
                          color: AppColors.textSecondary(context)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
