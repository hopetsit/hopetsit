import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_detail_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/pet_sitter/widgets/reservation_request_filter_dialog.dart';
import 'package:hopetsit/views/notifications/sitter_notifications_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
// Comments removed from publications
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Sort order for the sitter reservation feed (same as owner My Posts).
enum SitterFeedSortOrder { newestFirst, oldestFirst }

class SitterHomescreen extends StatefulWidget {
  const SitterHomescreen({super.key});

  @override
  State<SitterHomescreen> createState() => _SitterHomescreenState();
}

class _SitterHomescreenState extends State<SitterHomescreen> {
  final Map<String, bool> _loadingStates = {};
  final Map<String, String> _pendingApplicationIds = {};
  final Map<String, String> _pendingApplicationIdsByFingerprint = {};
  ReservationRequestFilterState _filterState =
      const ReservationRequestFilterState();
  SitterFeedSortOrder _sortOrder = SitterFeedSortOrder.newestFirst;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadPendingApplications();
    _loadUserPosition();
  }

  Future<void> _loadUserPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          AppLogger.logDebug('Location permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() => _userPosition = position);
      }
    } catch (e) {
      AppLogger.logError('Failed to load user position', error: e);
    }
  }

  List<PostModel> _applyRequestFilters(List<PostModel> source) {
    return source.where((post) {
      if (post.location == null &&
          post.startDate == null &&
          post.endDate == null &&
          post.serviceTypes.isEmpty) {
        return false;
      }

      if (_filterState.city != null && _filterState.city!.trim().isNotEmpty) {
        final city = post.location?.city ?? '';
        if (!city.toLowerCase().contains(
          _filterState.city!.trim().toLowerCase(),
        )) {
          return false;
        }
      }

      if (_filterState.serviceType != null &&
          _filterState.serviceType!.isNotEmpty) {
        final types = post.serviceTypes.map((e) => e.toLowerCase()).toList();
        if (!types.contains(_filterState.serviceType!.toLowerCase())) {
          return false;
        }
      }

      if (_filterState.dateRange != null) {
        final start = post.startDate;
        final end = post.endDate;
        if (start == null && end == null) return false;
        final postStart = start ?? end!;
        final postEnd = end ?? start!;
        final range = _filterState.dateRange!;
        if (postEnd.isBefore(range.start) || postStart.isAfter(range.end)) {
          return false;
        }
      }

      if (_filterState.maxDistanceKm != null &&
          _filterState.maxDistanceKm! > 0 &&
          _userPosition != null) {
        final postLat = post.location?.lat;
        final postLng = post.location?.lng;
        if (postLat == null || postLng == null) {
          return false;
        }

        final distanceInMeters = Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          postLat,
          postLng,
        );
        final distanceInKm = distanceInMeters / 1000;

        if (distanceInKm > _filterState.maxDistanceKm!) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  static String _formatDateShort(DateTime d) {
    const months = 'JanFebMarAprMayJunJulAugSepOctNovDec';
    final i = (d.month - 1) * 3;
    return '${d.day} ${months.substring(i, i + 3)}';
  }

  static String? _postDateRangeLabel(PostModel post) {
    final s = post.startDate;
    final e = post.endDate;
    if (s != null && e != null) {
      return '${_formatDateShort(s.toLocal())} – ${_formatDateShort(e.toLocal())}';
    }
    if (s != null) return _formatDateShort(s.toLocal());
    if (e != null) return _formatDateShort(e.toLocal());
    return null;
  }

  static String _serviceTypesDisplay(List<String> types) {
    if (types.isEmpty) return '';
    return types.map((t) => t.replaceAll('_', ' ')).join(', ');
  }

  List<PostModel> _sortFeedPosts(List<PostModel> posts) {
    final sorted = List<PostModel>.from(posts);
    sorted.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return _sortOrder == SitterFeedSortOrder.newestFirst ? -cmp : cmp;
    });
    return sorted;
  }

  Widget _buildSortBar() {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.divider(context).withValues(alpha: 0.5),
          ),
        ),
      child: Row(
        children: [
          Icon(Icons.sort_rounded, size: 20.sp, color: AppColors.textSecondary(context)),
          SizedBox(width: 8.w),
          Expanded(
            child: InterText(
              text: 'my_posts_sort_label'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<SitterFeedSortOrder>(
              value: _sortOrder,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primaryColor,
                size: 22.sp,
              ),
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
              items: [
                DropdownMenuItem(
                  value: SitterFeedSortOrder.newestFirst,
                  child: InterText(
                    text: 'my_posts_sort_newest'.tr,
                    fontSize: 14.sp,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                DropdownMenuItem(
                  value: SitterFeedSortOrder.oldestFirst,
                  child: InterText(
                    text: 'my_posts_sort_oldest'.tr,
                    fontSize: 14.sp,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _sortOrder = v);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  static String _defaultTimeSlotForPost(PostModel post) {
    final start = post.startDate?.toLocal();
    if (start != null) {
      final h24 = start.hour;
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      final minute = start.minute.toString().padLeft(2, '0');
      final amPm = h24 < 12 ? 'AM' : 'PM';
      return '$h12:$minute $amPm';
    }
    return 'All Day';
  }

  static String _serviceDateForPost(PostModel post) {
    final source = post.startDate ?? post.endDate ?? DateTime.now();
    return source
        .toUtc()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .toIso8601String();
  }

  static String? _startDateForPost(PostModel post) {
    return post.startDate?.toUtc().toIso8601String();
  }

  static String? _endDateForPost(PostModel post) {
    return post.endDate?.toUtc().toIso8601String();
  }

  String _normalizeIso(String? v) {
    if (v == null || v.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(v);
    if (parsed == null) return v.trim();
    return parsed.toUtc().toIso8601String();
  }

  String _buildRequestFingerprint({
    required String ownerId,
    required String petId,
    required String serviceType,
    required String serviceDate,
    required String timeSlot,
    String? startDate,
    String? endDate,
  }) {
    return [
      ownerId.trim(),
      petId.trim(),
      serviceType.trim().toLowerCase(),
      _normalizeIso(serviceDate),
      _normalizeIso(startDate),
      _normalizeIso(endDate),
      timeSlot.trim().toLowerCase(),
    ].join('|');
  }

  static int? _durationForPostService(PostModel post, String serviceType) {
    final normalized = serviceType
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (normalized != 'dog_walking' && normalized != 'walking') {
      return null;
    }

    if (post.startDate != null && post.endDate != null) {
      final minutes = post.endDate!.difference(post.startDate!).inMinutes.abs();
      if (minutes <= 45) return 30;
      return 60;
    }

    return 30;
  }

  Widget _activeFilterChip(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: AppColors.primaryColor),
          SizedBox(width: 6.w),
          InterText(
            text: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }

  void _showNearMeBottomSheet(BuildContext context) {
    double tempDistance = _filterState.maxDistanceKm ?? 0;

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Container(
          color: AppColors.card(context),
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 30.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InterText(
                text: 'filter_near_me'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 20.h),
              Slider(
                value: tempDistance,
                min: 0,
                max: 500,
                divisions: 50,
                label: tempDistance == 0
                    ? 'filter_all_distances'.tr
                    : '${tempDistance.toInt()} km',
                onChanged: (value) {
                  setBottomSheetState(() => tempDistance = value);
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: InterText(
                  text: tempDistance == 0
                      ? 'filter_all_distances'.tr
                      : 'filter_distance_km'
                          .trParams({'km': tempDistance.toInt().toString()}),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: AppColors.whiteColor,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _filterState = _filterState.copyWith(
                      maxDistanceKm:
                          tempDistance > 0 ? tempDistance : null,
                    );
                  });
                  Navigator.of(context).pop();
                },
                child: InterText(
                  text: 'filter_apply'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.whiteColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PostsController postsController = Get.put(PostsController());
    // Initialize SitterProfileController to call GET /sitters/{sitterId} API
    final SitterProfileController profileController = Get.put(
      SitterProfileController(),
    );

    final notificationsController = Get.isRegistered<NotificationsController>()
        ? Get.find<NotificationsController>()
        : Get.put(NotificationsController(), permanent: true);

    return Obx(
      () => Scaffold(
        backgroundColor: AppColors.scaffold(context),
        appBar: CustomAppBar(
          userName: profileController.userName.value.isNotEmpty
              ? profileController.userName.value
              : 'common_user'.tr,
          userImage: profileController.profileImageUrl.value.isNotEmpty
              ? profileController.profileImageUrl.value
              : '',
          showNotificationIcon: true,
          notificationUnreadRx: notificationsController.unreadCount,
          onNotificationTap: () {
            Get.to(() => const SitterNotificationsScreen())?.then((_) {
              notificationsController.refreshUnreadCount();
            });
          },
          onProfileTap: () {
            // Handle profile tap
            AppLogger.logDebug('SitterHomescreen: profile tapped');
          },
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // Refresh both posts and profile data
              await Future.wait([
                postsController.refreshPosts(),
                profileController.loadMyProfile(),
                _loadPendingApplications(),
              ]);
            },
            color: AppColors.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  Obx(() {
                    final combinedPosts = <PostModel>[
                      ...postsController.posts,
                      ...postsController.postsWithoutMedia,
                    ];

                    if (postsController.isLoading.value &&
                        combinedPosts.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (combinedPosts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'posts_empty_title'.tr,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: AppColors.greyText,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            CustomButton(
                              onTap: () => postsController.refreshPosts(),
                              title: 'common_refresh'.tr,
                              width: Get.size.width / 2,
                            ),
                          ],
                        ),
                      );
                    }

                    // Deduplicate by post id and keep stable ordering.
                    final seenIds = <String>{};
                    final uniquePosts = combinedPosts.where((post) {
                      if (post.id.isEmpty) return true;
                      if (seenIds.contains(post.id)) return false;
                      seenIds.add(post.id);
                      return true;
                    }).toList();

                    // Walker feed is strictly limited to walking requests
                    // (posts whose serviceTypes contains 'dog_walking').
                    // Sitter feed stays unchanged — the sitter/walker split
                    // mirrors the backend rule in getRequestPosts.
                    final currentRole = Get.isRegistered<AuthController>()
                        ? (Get.find<AuthController>().userRole.value ?? '')
                        : '';
                    final rolePrefiltered = currentRole == 'walker'
                        ? uniquePosts.where((p) => p.serviceTypes
                                .map((t) => t.toLowerCase())
                                .contains('dog_walking'))
                            .toList()
                        : uniquePosts;

                    final feedPosts = _filterState.hasActiveFilters
                        ? _applyRequestFilters(rolePrefiltered)
                        : rolePrefiltered;

                    final sortedFeed = _sortFeedPosts(feedPosts);

                    return Column(
                      children: [
                        // Near me and Filters row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Near me button
                            GestureDetector(
                              onTap: () => _showNearMeBottomSheet(context),
                              child: Builder(
                                builder: (context) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.card(context),
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: (_filterState.maxDistanceKm !=
                                              null &&
                                          _filterState.maxDistanceKm! > 0)
                                          ? AppColors.primaryColor
                                          : AppColors.divider(context),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.near_me_rounded,
                                        size: 20.sp,
                                        color: (_filterState.maxDistanceKm !=
                                                null &&
                                            _filterState.maxDistanceKm! > 0)
                                            ? AppColors.primaryColor
                                            : AppColors.textSecondary(
                                                context,
                                              ),
                                      ),
                                      SizedBox(width: 8.w),
                                      InterText(
                                        text: 'filter_near_me'.tr,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary(
                                          context,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            // Filters button
                            GestureDetector(
                              onTap: () {
                                ReservationRequestFilterDialog.show(
                                  context,
                                  initialState: _filterState,
                                  onApply: (state) {
                                    setState(() => _filterState = state);
                                  },
                                  onClear: () {
                                    setState(() {
                                      _filterState =
                                          const ReservationRequestFilterState();
                                    });
                                  },
                                );
                              },
                              child: Builder(
                                builder: (context) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.card(context),
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: _filterState.hasActiveFilters
                                          ? AppColors.primaryColor
                                          : AppColors.divider(context),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        size: 20.sp,
                                        color: _filterState.hasActiveFilters
                                            ? AppColors.primaryColor
                                            : AppColors.textSecondary(
                                                context,
                                              ),
                                      ),
                                      SizedBox(width: 8.w),
                                      InterText(
                                        text: _filterState.hasActiveFilters
                                            ? 'sitter_filters_on'.tr
                                            : 'sitter_filters'.tr,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary(
                                          context,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_filterState.hasActiveFilters) ...[
                          SizedBox(height: 10.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              if (_filterState.city != null &&
                                  _filterState.city!.trim().isNotEmpty)
                                _activeFilterChip(
                                  _filterState.city!.trim(),
                                  Icons.location_on_outlined,
                                ),
                              if (_filterState.serviceType != null &&
                                  _filterState.serviceType!.isNotEmpty)
                                _activeFilterChip(
                                  _filterState.serviceType!.replaceAll(
                                    '_',
                                    ' ',
                                  ),
                                  Icons.pets_outlined,
                                ),
                              if (_filterState.dateRange != null)
                                _activeFilterChip(
                                  '${_formatDateShort(_filterState.dateRange!.start)} – ${_formatDateShort(_filterState.dateRange!.end)}',
                                  Icons.calendar_today_outlined,
                                ),
                              if (_filterState.maxDistanceKm != null &&
                                  _filterState.maxDistanceKm! > 0)
                                _activeFilterChip(
                                  '< ${_filterState.maxDistanceKm!.toInt()} km',
                                  Icons.near_me_outlined,
                                ),
                            ],
                          ),
                        ],
                        if (uniquePosts.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          _buildSortBar(),
                        ],
                        SizedBox(height: 12.h),
                        if (sortedFeed.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Center(
                              child: InterText(
                                text: _filterState.hasActiveFilters
                                    ? 'sitter_no_requests_match'.tr
                                    : 'posts_empty_title'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.greyText,
                              ),
                            ),
                          ),
                        // Display all posts from API
                        ...sortedFeed.map((post) {
                          // Get all image URLs from the post
                          final imageUrls = post.images
                              .map((img) => img.url)
                              .where((url) => url.isNotEmpty)
                              .toList();
                          final petName = post.pets.isNotEmpty
                              ? post.pets.first.petName
                              : null;
                          final petId = post.pets.isNotEmpty
                              ? post.pets.first.id
                              : null;
                          final ownerId = post.owner.id.isNotEmpty
                              ? post.owner.id
                              : '';
                          final rawCity = post.location?.city.trim();
                          final locationLabel =
                              (rawCity != null && rawCity.isNotEmpty)
                              ? rawCity
                              : null;
                          final dateRangeLabel = _postDateRangeLabel(post);
                          final serviceTypesLabel = _serviceTypesDisplay(
                            post.serviceTypes,
                          );
                          final pendingApplicationId =
                              _pendingApplicationIds[post.id] ??
                              _pendingApplicationIdsByFingerprint[_buildRequestFingerprint(
                                ownerId: ownerId,
                                petId: petId ?? '',
                                serviceType: post.serviceTypes.isNotEmpty
                                    ? post.serviceTypes.first
                                    : '',
                                serviceDate: _serviceDateForPost(post),
                                startDate: _startDateForPost(post),
                                endDate: _endDateForPost(post),
                                timeSlot: _defaultTimeSlotForPost(post),
                              )];
                          final isCancelMode = pendingApplicationId != null;

                          return Padding(
                            padding: EdgeInsets.only(bottom: 16.h),
                            child: PetPostCard(
                              userName: post.owner.name,
                              userEmail: '',
                              userAvatar: post.owner.avatar.isNotEmpty
                                  ? post.owner.avatar
                                  : null,
                              petImages: imageUrls,
                              postBody: post.body,
                              petName: petName,
                              serviceTypes: serviceTypesLabel.isEmpty
                                  ? null
                                  : serviceTypesLabel,
                              dateRange: dateRangeLabel,
                              location: locationLabel,
                              isNetworkImage: imageUrls.isNotEmpty,
                              likeCount: post.likesCount,
                              // Comments disabled on publications
                              commentCount: 0,
                              isLiked: postsController.isPostLiked(post.id),
                              onViewPetDetails: petId != null
                                  ? () async => _handleCardTap(petId)
                                  : null,
                              onSendRequest:
                                  ownerId.isNotEmpty &&
                                      petId != null &&
                                      post.serviceTypes.isNotEmpty
                                  ? () async {
                                      if (isCancelMode) {
                                        await _handleCancelRequest(
                                          requestKey: post.id,
                                          applicationId: pendingApplicationId,
                                        );
                                      } else {
                                        await _handleSendRequest(
                                          requestKey: post.id,
                                          ownerId: ownerId,
                                          petId: petId,
                                          serviceType: post.serviceTypes.first,
                                          serviceDate: _serviceDateForPost(
                                            post,
                                          ),
                                          startDate: _startDateForPost(post),
                                          endDate: _endDateForPost(post),
                                          timeSlot: _defaultTimeSlotForPost(
                                            post,
                                          ),
                                          houseSittingVenue:
                                              post.houseSittingVenue,
                                          duration: _durationForPostService(
                                            post,
                                            post.serviceTypes.first,
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              requestButtonText: isCancelMode
                                  ? 'request_cancel_button'.tr
                                  : 'send_request_button'.tr,
                              isCancelRequest: isCancelMode,
                              isRequestLoading:
                                  _loadingStates[post.id] ?? false,
                              onLike: () {
                                // Toggle like with optimistic update
                                postsController.toggleLike(post.id);
                              },
                              // Comments disabled on publications
                              onComment: null,
                              onBlockUser: ownerId.isNotEmpty
                                  ? () => _handleBlockOwner(
                                      ownerId: ownerId,
                                      ownerName: post.owner.name,
                                    )
                                  : null,
                              onReportPost: () => _handleReportPost(
                                postId: post.id,
                              ),
                              onShare: () {
                                () async {
                                  try {
                                    final shareText = post.body.isNotEmpty
                                        ? post.body
                                        : (post.pets.isNotEmpty &&
                                                  post
                                                      .pets
                                                      .first
                                                      .petName
                                                      .isNotEmpty
                                              ? 'Meet ${post.pets.first.petName} — looking for a caring sitter. See photos and details on Hopetsit!'
                                              : 'Looking for a caring pet sitter? Check out this post on Hopetsit!');

                                    final filesToShare = <XFile>[];

                                    if (imageUrls.isNotEmpty) {
                                      final tmp = await getTemporaryDirectory();
                                      for (
                                        var i = 0;
                                        i < imageUrls.length;
                                        i++
                                      ) {
                                        final imageUrl = imageUrls[i];
                                        if (imageUrl.startsWith('http')) {
                                          final uri = Uri.parse(imageUrl);
                                          final resp = await http.get(uri);
                                          if (resp.statusCode == 200) {
                                            final bytes = resp.bodyBytes;
                                            final file = File(
                                              '${tmp.path}/share_${post.id}_$i.jpg',
                                            );
                                            await file.writeAsBytes(bytes);
                                            filesToShare.add(XFile(file.path));
                                          }
                                        } else {
                                          // Treat as local asset path.
                                          try {
                                            final data = await rootBundle.load(
                                              imageUrl,
                                            );
                                            final bytes = data.buffer
                                                .asUint8List();
                                            final file = File(
                                              '${tmp.path}/share_${post.id}_$i.png',
                                            );
                                            await file.writeAsBytes(bytes);
                                            filesToShare.add(XFile(file.path));
                                          } catch (_) {
                                            // Ignore only failed image and continue sharing others.
                                          }
                                        }
                                      }
                                    }

                                    if (filesToShare.isNotEmpty) {
                                      await Share.shareXFiles(
                                        filesToShare,
                                        text: shareText,
                                      );
                                    } else {
                                      await Share.share(shareText);
                                    }
                                  } catch (error) {
                                    AppLogger.logError(
                                      'SitterHomescreen: share failed',
                                      error: error,
                                    );
                                    CustomSnackbar.showError(
                                      title: 'common_error'.tr,
                                      message: 'share_failed'.tr,
                                    );
                                  }
                                }();
                              },
                            ),
                          );
                        }),
                        SizedBox(height: 50.h),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSendRequest({
    required String requestKey,
    required String ownerId,
    required String? petId,
    required String serviceType,
    required String serviceDate,
    String? startDate,
    String? endDate,
    required String timeSlot,
    String? houseSittingVenue,
    int? duration,
  }) async {
    // Button is only enabled when petId is non-null, but guard anyway.
    if (petId == null || petId.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_pet_required'.tr,
      );
      return;
    }

    setState(() {
      _loadingStates[requestKey] = true;
    });

    try {
      final sitterRepository = Get.find<SitterRepository>();
      final basePrice = await _resolveSitterBasePrice(sitterRepository);
      if (basePrice <= 0) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'request_sitter_pricing_error'.tr,
        );
        return;
      }
      final normalizedService = serviceType
          .trim()
          .toLowerCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');
      final venueForHouseSitting = normalizedService == 'house_sitting'
          ? ((houseSittingVenue == 'owners_home' ||
                    houseSittingVenue == 'sitters_home')
                ? houseSittingVenue
                : 'owners_home')
          : null;

      final response = await sitterRepository.createApplication(
        ownerId: ownerId,
        petIds: [petId],
        serviceType: serviceType,
        houseSittingVenue: venueForHouseSitting,
        serviceDate: serviceDate,
        startDate: startDate,
        endDate: endDate,
        timeSlot: timeSlot,
        basePrice: basePrice,
        duration: duration,
      );

      final application =
          response['application'] as Map<String, dynamic>? ?? const {};
      final applicationId = application['id']?.toString() ?? '';
      final duplicatePrevented = response['duplicatePrevented'] == true;
      final fingerprint = _buildRequestFingerprint(
        ownerId: ownerId,
        petId: petId,
        serviceType: serviceType,
        serviceDate: serviceDate,
        startDate: startDate,
        endDate: endDate,
        timeSlot: timeSlot,
      );
      if (applicationId.isNotEmpty && mounted) {
        setState(() {
          _pendingApplicationIds[requestKey] = applicationId;
          _pendingApplicationIdsByFingerprint[fingerprint] = applicationId;
        });
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: duplicatePrevented
            ? (response['message']?.toString() ?? 'request_send_success'.tr)
            : 'request_send_success'.tr,
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to send request', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_send_failed'.tr,
      );
    } catch (error) {
      AppLogger.logError('Failed to send request', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_send_failed'.tr,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates[requestKey] = false;
        });
      }
    }
  }

  Future<void> _handleCancelRequest({
    required String requestKey,
    required String? applicationId,
  }) async {
    if (applicationId == null || applicationId.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_cancel_error'.tr,
      );
      return;
    }

    setState(() {
      _loadingStates[requestKey] = true;
    });

    try {
      final sitterRepository = Get.find<SitterRepository>();
      await sitterRepository.cancelApplicationRequest(
        applicationId: applicationId,
      );

      if (mounted) {
        setState(() {
          _pendingApplicationIds.remove(requestKey);
          _pendingApplicationIdsByFingerprint.removeWhere(
            (_, id) => id == applicationId,
          );
        });
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'request_cancel_success'.tr,
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to cancel request', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      AppLogger.logError('Failed to cancel request', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_cancel_error'.tr,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates[requestKey] = false;
        });
      }
    }
  }

  Future<void> _loadPendingApplications() async {
    try {
      final sitterRepository = Get.find<SitterRepository>();
      final applications = await sitterRepository.getMyApplicationsRaw();

      if (!mounted) return;
      setState(() {
        _pendingApplicationIdsByFingerprint.clear();
        for (final app in applications) {
          final status = (app['status']?.toString() ?? '').toLowerCase();
          if (status != 'pending') continue;

          final appId = app['id']?.toString() ?? '';
          if (appId.isEmpty) continue;

          final owner = app['owner'];
          final ownerId = owner is Map ? owner['id']?.toString() ?? '' : '';
          if (ownerId.isEmpty) continue;

          final petIds = app['petIds'];
          String petId = '';
          if (petIds is List && petIds.isNotEmpty) {
            petId = petIds.first?.toString() ?? '';
          }
          if (petId.isEmpty) continue;

          final serviceType = app['serviceType']?.toString() ?? '';
          final serviceDate = app['serviceDate']?.toString() ?? '';
          final startDate = app['startDate']?.toString();
          final endDate = app['endDate']?.toString();
          final timeSlot = app['timeSlot']?.toString() ?? '';
          if (serviceType.isEmpty || serviceDate.isEmpty || timeSlot.isEmpty) {
            continue;
          }

          final key = _buildRequestFingerprint(
            ownerId: ownerId,
            petId: petId,
            serviceType: serviceType,
            serviceDate: serviceDate,
            startDate: startDate,
            endDate: endDate,
            timeSlot: timeSlot,
          );
          _pendingApplicationIdsByFingerprint[key] = appId;
        }
      });
    } catch (error) {
      AppLogger.logError('Failed to load pending applications', error: error);
    }
  }

  Future<double> _resolveSitterBasePrice(
    SitterRepository sitterRepository,
  ) async {
    try {
      final storage = GetStorage();
      final userProfile = storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );
      final sitterId = userProfile?['id']?.toString() ?? '';
      if (sitterId.isEmpty) {
        return 0;
      }

      // /sitters/me/profile is not available in current backend env; use /sitters/{id}.
      final profile = await sitterRepository.getSitterProfile(sitterId);
      final data =
          profile['sitter'] as Map<String, dynamic>? ??
          profile['profile'] as Map<String, dynamic>? ??
          profile;

      final fromHourly = (data['hourlyRate'] as num?)?.toDouble();
      if (fromHourly != null && fromHourly > 0) {
        return fromHourly;
      }

      final fromRateString = double.tryParse(data['rate']?.toString() ?? '');
      if (fromRateString != null && fromRateString > 0) {
        return fromRateString;
      }
    } catch (error) {
      AppLogger.logError('Failed to resolve sitter base price', error: error);
    }

    // Do not send fallback for invalid/unknown sitter pricing.
    return 0;
  }

  Future<void> _handleCardTap(String petId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
              SizedBox(height: 16.h),
              InterText(
                text: 'pet_detail_loading'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final petRepository = Get.find<PetRepository>();
      final pet = await petRepository.getPetById(petId);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Map pet data to PetDetailScreen format
      final age = pet.age.isNotEmpty ? pet.age : 'label_not_available'.tr;
      final gender = 'pet_detail_gender_unknown'
          .tr; // Gender not in PetModel, using default
      final weight = pet.weight.isNotEmpty
          ? '${pet.weight} kg'
          : 'label_not_available'.tr;
      final height = pet.height.isNotEmpty
          ? '${pet.height} cm'
          : 'label_not_available'.tr;
      final color = pet.colour.isNotEmpty
          ? pet.colour
          : 'label_not_available'.tr;
      final description = pet.bio.isNotEmpty
          ? pet.bio
          : 'pet_detail_no_description'.tr;

      // Get gallery images from photos
      final List<String> galleryImages = [];
      if (pet.photos.isNotEmpty) {
        for (var photo in pet.photos) {
          if (photo is Map<String, dynamic> && photo['url'] != null) {
            galleryImages.add(photo['url'].toString());
          } else if (photo is String) {
            galleryImages.add(photo);
          }
        }
      }

      // Get vaccinations
      final vaccinations = pet.vaccinations.isNotEmpty
          ? pet.vaccinations
          : ['pet_detail_no_vaccinations'.tr];

      // Get pet images array (avatar + gallery images, removing duplicates)
      final List<String> petImages = [];
      if (pet.avatar.url.isNotEmpty) {
        petImages.add(pet.avatar.url);
      }
      // Add gallery images that are different from avatar
      for (var galleryImage in galleryImages) {
        if (!petImages.contains(galleryImage)) {
          petImages.add(galleryImage);
        }
      }
      // If no images at all, use empty list (will show placeholder)

      // Get sitter profile image
      final SitterProfileController profileController =
          Get.find<SitterProfileController>();
      final sitterProfileImage = profileController.profileImageUrl.value;

      // Get owner information from pet model
      final ownerName = pet.owner?.name;
      final ownerAvatar = pet.owner?.avatar;
      final ownerCreatedAt = pet.owner?.createdAt;
      final ownerUpdatedAt = pet.owner?.updatedAt;

      // Get additional pet details
      final passportNumber = pet.passportNumber.isNotEmpty
          ? pet.passportNumber
          : null;
      final chipNumber = pet.chipNumber.isNotEmpty ? pet.chipNumber : null;
      final medicationAllergies = pet.medicationAllergies.isNotEmpty
          ? pet.medicationAllergies
          : null;
      final dob = pet.dob.isNotEmpty ? pet.dob : null;
      final category = pet.category.isNotEmpty ? pet.category : null;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetDetailScreen(
              petName: pet.petName,
              breed: pet.breed.isNotEmpty
                  ? pet.breed
                  : 'pet_detail_breed_unknown'.tr,
              age: age,
              gender: gender,
              weight: weight,
              height: height,
              color: color,
              description: description,
              vaccinations: vaccinations,
              galleryImages: galleryImages,
              petImages: petImages,
              sitterProfileImage: sitterProfileImage,
              ownerName: ownerName,
              ownerAvatar: ownerAvatar,
              ownerCreatedAt: ownerCreatedAt,
              ownerUpdatedAt: ownerUpdatedAt,
              passportNumber: passportNumber,
              chipNumber: chipNumber,
              medicationAllergies: medicationAllergies,
              dob: dob,
              category: category,
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      AppLogger.logError('Failed to load pet details', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      AppLogger.logError('Failed to load pet details', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_detail_load_error'.tr,
      );
    }
  }

  Future<void> _handleBlockOwner({
    required String ownerId,
    required String ownerName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card(dialogContext),
        title: InterText(
          text: 'block_user_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(dialogContext),
        ),
        content: InterText(
          text: 'block_user_confirm_message'.tr.replaceAll('{name}', ownerName),
          fontSize: 14.sp,
          color: AppColors.textPrimary(dialogContext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: InterText(
              text: 'common_cancel'.tr,
              fontSize: 14.sp,
              color: AppColors.textSecondary(dialogContext),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: InterText(
              text: 'block_user_action'.tr,
              fontSize: 14.sp,
              color: AppColors.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ownerRepository = Get.find<OwnerRepository>();
      await ownerRepository.blockAnyUser(
        targetUserId: ownerId,
        targetRole: 'owner',
      );
      if (mounted) {
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'block_user_success'.tr,
        );
      }
    } catch (error) {
      AppLogger.logError('Block owner failed', error: error);
      if (mounted) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'block_user_failed'.tr,
        );
      }
    }
  }

  Future<void> _handleReportPost({required String postId}) async {
    if (!mounted) return;
    CustomSnackbar.showSuccess(
      title: 'common_success'.tr,
      message: 'report_post_received'.tr,
    );
  }
}
