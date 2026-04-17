import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Sprint 6 step 3 — owner views the latest visit report for a booking.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.get(
        '/bookings/${widget.bookingId}/visit-report',
        requiresAuth: true,
      );
      if (r is Map && r['report'] is Map) {
        setState(() => _report = Map<String, dynamic>.from(r['report']));
      }
    } catch (e) {
      setState(() => _error = e.toString());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: PoppinsText(
          text: 'Visit report',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? Center(
                  child: InterText(
                    text: _error ?? 'No report yet.',
                    fontSize: 14.sp,
                    color: AppColors.textSecondary(context),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.all(16.w),
                  children: [
                    InterText(
                      text: '${_moodIcon((_report!['mood'] ?? 'calm').toString())}  ${(_report!['mood'] ?? '').toString().toUpperCase()}',
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 12.h),
                    if ((_report!['notes'] ?? '').toString().isNotEmpty)
                      InterText(
                        text: _report!['notes'].toString(),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary(context),
                      ),
                    SizedBox(height: 12.h),
                    if (_report!['activities'] is List &&
                        (_report!['activities'] as List).isNotEmpty)
                      InterText(
                        text: 'Activities: ${(_report!['activities'] as List).join(", ")}',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary(context),
                      ),
                    SizedBox(height: 16.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        for (final url in (_report!['photos'] as List? ?? []))
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: CachedNetworkImage(
                              imageUrl: url.toString(),
                              width: 110.w,
                              height: 110.h,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
