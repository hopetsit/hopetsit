import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hopetsit/controllers/home_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/map/pets_map_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';
import 'package:hopetsit/views/service_provider/widgets/service_provider_card.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/custom_segmented_control.dart';
import 'package:hopetsit/widgets/expandable_post_input.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:share_plus/share_plus.dart';

enum HomeMyPostsSortOrder { newestFirst, oldestFirst }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;
  HomeMyPostsSortOrder _myPostsSortOrder = HomeMyPostsSortOrder.newestFirst;

  late final HomeController _homeController;
  late final ProfileController _profileController;
  late final NotificationsController _notificationsController;
  late final PostsController _postsController;
  late final GetStorage _storage;
  String? _userId;

  @override
  void initState() {
    super.initState();

    _homeController = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController(), permanent: true);

    _profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    _notificationsController = Get.isRegistered<NotificationsController>()
        ? Get.find<NotificationsController>()
        : Get.put(NotificationsController(), permanent: true);

    _postsController = Get.put(PostsController());
    _storage = Get.find<GetStorage>();

    final userProfile =
        _storage.read(StorageKeys.userProfile) as Map<String, dynamic>?;
    _userId = userProfile?['id'] as String?;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postsController.refreshPosts();
    });
  }

  static String _serviceTypesDisplay(List<String> types) {
    if (types.isEmpty) return '';
    return types.map((t) => t.replaceAll('_', ' ')).join(', ');
  }

  static String? _postDateRangeLabel(PostModel post) {
    final s = post.startDate;
    final e = post.endDate;
    if (s != null && e != null) {
      return '${s.day}/${s.month}/${s.year} - ${e.day}/${e.month}/${e.year}';
    }
    if (s != null) return '${s.day}/${s.month}/${s.year}';
    if (e != null) return '${e.day}/${e.month}/${e.year}';
    return null;
  }

  static bool _postHasDisplayableMedia(PostModel post) {
    return post.images.any((img) => img.url.isNotEmpty) ||
        post.videos.isNotEmpty ||
        post.postType.toLowerCase() == 'media';
  }

  Future<void> _confirmAndDeletePost(
    BuildContext context,
    String postId,
  ) async {
    CustomConfirmationDialog.show(
      context: context,
      message: 'my_posts_delete_message'.tr,
      yesText: 'post_action_delete'.tr,
      cancelText: 'common_cancel'.tr,
      onYes: () async {
        try {
          final postRepository = Get.find<PostRepository>();
          await postRepository.deletePost(postId);
          await _postsController.refreshPosts();
          CustomSnackbar.showSuccess(
            title: 'common_success'.tr,
            message: 'my_posts_delete_success'.tr,
          );
        } on ApiException catch (error) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: error.message,
          );
        } catch (error) {
          AppLogger.logError('HomeScreen: delete post failed', error: error);
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'my_posts_delete_failed'.tr,
          );
        }
      },
    );
  }

  List<PostModel> _filterAndSortMyPosts({
    required List<PostModel> media,
    required List<PostModel> withoutMedia,
    required String userId,
  }) {
    final seen = <String>{};
    final merged = <PostModel>[];

    for (final p in withoutMedia) {
      if (p.owner.id == userId && seen.add(p.id)) merged.add(p);
    }
    for (final p in media) {
      if (p.owner.id == userId && seen.add(p.id)) merged.add(p);
    }

    merged.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return _myPostsSortOrder == HomeMyPostsSortOrder.newestFirst ? -cmp : cmp;
    });

    return merged;
  }

  Widget _buildMyPostsTab() {
    return Obx(() {
      final isLoading = _postsController.isLoading.value;
      final sortedMine = _userId == null
          ? <PostModel>[]
          : _filterAndSortMyPosts(
              media: _postsController.posts,
              withoutMedia: _postsController.postsWithoutMedia,
              userId: _userId!,
            );

      if (isLoading && sortedMine.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (sortedMine.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: InterText(
              text: 'my_posts_no_posts'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.greyColor,
            ),
          ),
        );
      }

      return Column(
        children: [
          _buildMyPostsSortBar(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryColor,
              onRefresh: _postsController.refreshPosts,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                itemCount: sortedMine.length,
                itemBuilder: (context, index) {
                  final post = sortedMine[index];
                  final rawCity = post.location?.city.trim();
                  final locationLabel = (rawCity != null && rawCity.isNotEmpty)
                      ? rawCity
                      : null;
                  return PetPostCard(
                    userName: post.owner.name,
                    userEmail: post.owner.email,
                    userAvatar: post.owner.avatar.isNotEmpty ? post.owner.avatar : null,
                    petImages: post.images.map((img) => img.url).toList(),
                    postBody: post.body,
                    serviceTypes: _serviceTypesDisplay(post.serviceTypes),
                    dateRange: _postDateRangeLabel(post),
                    location: locationLabel,
                    isNetworkImage: post.images.isNotEmpty,
                    likeCount: post.likesCount,
                    commentCount: post.commentsCount,
                    onDelete: () => _confirmAndDeletePost(context, post.id),
                    onShare: () async {
                      try {
                        final imageUrls = post.images
                            .where((img) => img.url.isNotEmpty)
                            .map((img) => img.url)
                            .toList();
                        if (imageUrls.isNotEmpty) {
                          final tempDir = await getTemporaryDirectory();
                          final List<XFile> xFiles = [];
                          for (int i = 0; i < imageUrls.length; i++) {
                            final url = imageUrls[i];
                            final response = await http.get(Uri.parse(url));
                            final file = File(
                                '${tempDir.path}/share_image_$i.jpg');
                            await file.writeAsBytes(response.bodyBytes);
                            xFiles.add(XFile(file.path));
                          }
                          await Share.shareXFiles(
                            xFiles,
                            text: post.body,
                          );
                        } else {
                          await Share.share(post.body);
                        }
                      } catch (e) {
                        AppLogger.logError('Failed to share post', error: e);
                        await Share.share(post.body);
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMyPostsSortBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<HomeMyPostsSortOrder>(
              value: _myPostsSortOrder,
              icon: Icon(Icons.sort, size: 18.sp, color: AppColors.textSecondary(context)),
              style: TextStyle(
                  fontSize: 13.sp, color: AppColors.textPrimary(context)),
              items: [
                DropdownMenuItem(
                  value: HomeMyPostsSortOrder.newestFirst,
                  child: InterText(
                    text: 'my_posts_sort_newest'.tr,
                    fontSize: 14.sp,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                DropdownMenuItem(
                  value: HomeMyPostsSortOrder.oldestFirst,
                  child: InterText(
                    text: 'my_posts_sort_oldest'.tr,
                    fontSize: 14.sp,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _myPostsSortOrder = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── FIX #2: Sitters Tab with "Offers Near Me" button + radius slider ───
  Widget _buildSittersTab() {
    return Obx(() {
      final isLoading = _homeController.isLoadingSitters.value;

      return Column(
        children: [
          // "Offers Near Me" button
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 4.h),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _homeController.offersNearMeEnabled.value
                              ? AppColors.primaryColor
                              : AppColors.card(context),
                      foregroundColor:
                          _homeController.offersNearMeEnabled.value
                              ? AppColors.whiteColor
                              : AppColors.primaryColor,
                      side: BorderSide(color: AppColors.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    icon: Icon(Icons.near_me, size: 20.sp),
                    label: InterText(
                      text: 'map_offers_near_me'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: _homeController.offersNearMeEnabled.value
                          ? AppColors.whiteColor
                          : AppColors.primaryColor,
                    ),
                    onPressed: () =>
                        _homeController.toggleOffersNearMe(context),
                  ),
                ),
                // Radius slider shown only when Near Me is active
                if (_homeController.offersNearMeEnabled.value) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      InterText(
                        text: 'map_radius_label'.tr,
                        fontSize: 12.sp,
                        color: AppColors.greyText,
                      ),
                      Expanded(
                        child: Slider(
                          value: _homeController.nearMeRadiusKm.value,
                          min: 0,
                          max: 500,
                          divisions: 50,
                          activeColor: AppColors.primaryColor,
                          label:
                              '${_homeController.nearMeRadiusKm.value.round()} km',
                          onChanged: (val) {
                            _homeController.nearMeRadiusKm.value = val;
                          },
                          onChangeEnd: (val) {
                            _homeController.loadNearbySitters(
                                radiusKm: val.round());
                          },
                        ),
                      ),
                      InterText(
                        text:
                            '${_homeController.nearMeRadiusKm.value.round()} km',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_homeController.sitters.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: InterText(
                    text: 'home_no_sitters_message'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.greyColor,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryColor,
                onRefresh: _homeController.loadSitters,
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                  itemCount: _homeController.sitters.length,
                  itemBuilder: (context, index) {
                    final sitter = _homeController.sitters[index];

                    // FIX #1: show best available rate
                    final String displayPrice = sitter.hourlyRate > 0
                        ? sitter.hourlyRate.toStringAsFixed(1)
                        : '0';
                    // Daily rate fallback: if the sitter didn't set a daily rate
                    // but has an hourly rate, display (hourly × 8) as the day rate
                    // so owners always see a comparable per-day figure.
                    final double effectiveDailyRate = sitter.dailyRate > 0
                        ? sitter.dailyRate
                        : (sitter.hourlyRate > 0 ? sitter.hourlyRate * 8 : 0);
                    final String? displayDaily = effectiveDailyRate > 0
                        ? effectiveDailyRate.toStringAsFixed(1)
                        : null;
                    final String? displayWeekly = sitter.weeklyRate > 0
                        ? sitter.weeklyRate.toStringAsFixed(0)
                        : null;
                    final String? displayMonthly = sitter.monthlyRate > 0
                        ? sitter.monthlyRate.toStringAsFixed(0)
                        : null;

                    final String locationLabel = [
                      if (sitter.displayCity.isNotEmpty) sitter.displayCity,
                      if (sitter.distanceKm != null)
                        '${sitter.distanceKm!.toStringAsFixed(1)} km',
                    ].join(' · ');

                    // Calculate estimated cost from owner's latest reservation post.
                    // Uses the sitter's best available rate: daily > effective-daily
                    // (hourly × 8) > weekly / 7 > monthly / 30. Always shows at
                    // least 1 day so same-day start/end doesn't hide the figure.
                    double? estCost;
                    int? estDays;
                    if (_userId != null) {
                      final myPosts = _postsController.postsWithoutMedia
                          .where((p) => p.owner.id == _userId && p.startDate != null && p.endDate != null)
                          .toList();
                      if (myPosts.isNotEmpty) {
                        myPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                        final latestPost = myPosts.first;
                        final rawDays = latestPost.endDate!
                            .difference(latestPost.startDate!)
                            .inDays;
                        // Treat same-day requests as 1 day (avoid hiding total).
                        final days = rawDays > 0 ? rawDays : 1;
                        estDays = days;
                        if (sitter.dailyRate > 0) {
                          estCost = sitter.dailyRate * days;
                        } else if (sitter.hourlyRate > 0) {
                          estCost = sitter.hourlyRate * 8 * days; // 8h/day
                        } else if (sitter.weeklyRate > 0) {
                          estCost = (sitter.weeklyRate / 7) * days;
                        } else if (sitter.monthlyRate > 0) {
                          estCost = (sitter.monthlyRate / 30) * days;
                        }
                      }
                    }

                    return ServiceProviderCard(
                      name: sitter.name,
                      identityVerified: sitter.identityVerified,
                      isTopSitter: sitter.isTopSitter,
                      isBoosted: sitter.isBoosted,
                      phoneNumber: sitter.mobile,
                      email: sitter.email,
                      status: 'status_available'.tr,
                      showStatusChip: false,
                      rating: sitter.rating,
                      isBlurred: true,
                      reviewsCount: sitter.reviewsCount,
                      location: locationLabel,
                      pricePerHour: displayPrice,
                      pricePerDay: displayDaily,
                      pricePerWeek: displayWeekly,
                      pricePerMonth: displayMonthly,
                      currencyCode: sitter.currency,
                      estimatedCost: estCost,
                      estimatedDays: estDays,
                      profileImagePath: sitter.avatar.url.isNotEmpty
                          ? sitter.avatar.url
                          : null,
                      sitterId: sitter.id,
                      onSendRequest: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SendRequestScreen(
                              serviceProviderName: sitter.name,
                              serviceProviderId: sitter.id,
                            ),
                          ),
                        );
                      },
                      onBlock: () {
                        CustomConfirmationDialog.show(
                          context: context,
                          message: 'home_block_sitter_message'.trParams({
                            'name': sitter.name,
                          }),
                          yesText: 'home_block_sitter_yes'.tr,
                          cancelText: 'home_block_sitter_no'.tr,
                          yesButtonColor: AppColors.whiteColor,
                          cancelButtonColor: AppColors.primaryColor,
                          onYes: () {},
                          onCancel: () {
                            _homeController.blockSitter(sitter.id);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        backgroundColor: AppColors.scaffold(context),
        appBar: CustomAppBar(
          userName: _profileController.userName.value.isNotEmpty
              ? _profileController.userName.value
              : 'home_default_user_name'.tr,
          userImage: _profileController.profileImageUrl.value.isNotEmpty
              ? _profileController.profileImageUrl.value
              : '',
          showNotificationIcon: true,
          notificationUnreadRx: _notificationsController.unreadCount,
          onNotificationTap: () {
            Get.to(() => const NotificationsScreen())?.then((_) {
              _notificationsController.refreshUnreadCount();
            });
          },
          onProfileTap: () {},
          actions: [
            IconButton(
              icon: Container(
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  gradient: AppColors.linearGradient,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.map_outlined,
                  color: AppColors.whiteColor,
                  size: 20.sp,
                ),
              ),
              onPressed: () => Get.to(() => const PetsMapScreen()),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Flexible(flex: 0, child: const ExpandablePostInput()),
              SizedBox(height: 12.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Obx(() {
                  final allPosts = <PostModel>[
                    ..._postsController.posts,
                    ..._postsController.postsWithoutMedia,
                  ];
                  final myCount = _userId == null
                      ? 0
                      : allPosts.where((p) => p.owner.id == _userId).length;

                  return CustomSegmentedControl(
                    leftText: '${'my_posts_title'.tr} ($myCount)',
                    rightText: 'home_segment_sitters'.tr,
                    selectedIndex: _selectedTabIndex,
                    onLeftTap: () {
                      setState(() => _selectedTabIndex = 0);
                    },
                    onRightTap: () {
                      setState(() => _selectedTabIndex = 1);
                    },
                  );
                }),
              ),

              SizedBox(height: 12.h),

              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildMyPostsTab()
                    : _buildSittersTab(),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: AppColors.linearGradient,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.whiteColor,
            elevation: 0,
            icon: Icon(Icons.add_rounded, size: 22.sp),
            label: InterText(
              text: 'new_publication_button'.tr,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
            onPressed: () {
              Get.to(() => const PublishReservationRequestScreen())?.then((_) {
                _postsController.refreshPosts();
              });
            },
          ),
        ),
      ),
    );
  }
}
