import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
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
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/sitter_card.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/walker_card.dart';
import 'package:hopetsit/views/pet_owner/posts/edit_post_screen.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
// v23.1 — HomeHeader Container-based, remplace AppBar pour fix grey rectangle.
import 'package:hopetsit/widgets/home_header.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/custom_segmented_control.dart';
import 'package:hopetsit/widgets/expandable_post_input.dart';
import 'package:hopetsit/widgets/home_quick_action_bar.dart';
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

  // v23.1 part 240 — Daniel : "quand la barre est a 0 sa dois mafficher
  // uniquement les profile de 0 a 50km de chez moi". Slider minimum =
  // 50km. Defaut 50km. Plus de mode "toutes les distances" (qui ramenait
  // sitters a 250km dans le filtre 120km). Constants utilises par le
  // slider + le label + l'init de _maxDistanceKm.
  static const double _kMinRadiusKm = 50.0;
  static const double _kMaxRadiusKm = 500.0;

  /// Inline "Près de chez moi" filter — shared by Pet-sitters + Promeneurs
  /// tabs. 0 = toutes les distances (pas de filtre).
  double _maxDistanceKm = _kMinRadiusKm; // v240 — was 0 ("toutes"), now 50km min.

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
    // v23.1 — bug #34 fix : use translateServiceType so 'day_care' becomes
    // 'Garderie' (FR) / 'Day Care' (EN) / etc. instead of the raw 'day care'.
    return types
        .map(translateServiceType)
        .where((s) => s.isNotEmpty)
        .join(', ');
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

  // ignore: unused_element
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

  /// Walkers tab (index 2) — real listing now that /walkers is wired.
  /// Same layout as the sitters tab: reactive list + pull-to-refresh.
  /// Shares the "Près de chez moi" slider with the sitters tab (both lists
  /// filter themselves against the same radius via the HomeController).
  // v23.1 part 240 — retourne un Sliver pour s'integrer au CustomScrollView
  // de la home (page entierement scrollable). loading + empty utilisent
  // SliverFillRemaining ; la liste utilise SliverList.builder lazy.
  Widget _buildWalkersTab() {
    return Obx(() {
      if (_homeController.isLoadingWalkers.value) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          ),
        );
      }

      if (_homeController.walkers.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    color:
                        AppColors.greenColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_walk_rounded,
                    size: 36.sp,
                    color: AppColors.greenColor,
                  ),
                ),
                SizedBox(height: 16.h),
                // v23.1.147 — fix i18n : strings hardcodées FR remplacées par .tr.
                PoppinsText(
                  text: 'home_no_walkers_title'.tr,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 6.h),
                InterText(
                  text: 'home_no_walkers_body'.tr,
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                ),
                SizedBox(height: 18.h),
                ElevatedButton.icon(
                  onPressed: () {
                    Get.to(
                      () => const PublishReservationRequestScreen(),
                    )?.then((_) => _postsController.refreshPosts());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenColor,
                    padding: EdgeInsets.symmetric(
                        horizontal: 18.w, vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: InterText(
                    text: 'Publier une promenade',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      }

      // v23.1 part 240 — SliverPadding+SliverList.builder pour scroll unifie.
      // Le RefreshIndicator parent vient du CustomScrollView (au niveau du
      // body Scaffold) ou est gere via gesture sur la page entiere — on le
      // retire ici car SliverList n'accepte pas de wrapper non-sliver.
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        sliver: SliverList.builder(
          itemCount: _homeController.walkers.length,
          itemBuilder: (context, index) {
            final walker = _homeController.walkers[index];
            double? halfHour;
            double? hour;
            for (final r in walker.walkRates) {
              if (!r.enabled || r.basePrice <= 0) continue;
              if (r.durationMinutes == 30) halfHour = r.basePrice;
              if (r.durationMinutes == 60) hour = r.basePrice;
            }
            return WalkerCard(
              walker: walker,
              onRequestWalk: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SendRequestScreen(
                      serviceProviderName: walker.name,
                      serviceProviderId: walker.id,
                      serviceProviderRole: 'walker',
                      walkerHalfHourRate: halfHour,
                      walkerHourlyRate: hour,
                      currencyCode: walker.currency,
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }

  /// Inline "Près de chez moi" slider — partagé par les onglets Pet-sitters
  /// et Promeneurs. 0 km = toutes les distances. Connecté directement au
  /// [HomeController] pour que `loadNearbySitters()` soit appelé sur drag.
  Widget _buildInlineDistanceSlider(BuildContext context) {
    return Obx(() {
      final current = _homeController.offersNearMeEnabled.value
          ? _homeController.nearMeRadiusKm.value
          : _maxDistanceKm;
      return _distanceSliderBody(context, current);
    });
  }

  Widget _distanceSliderBody(BuildContext context, double current) {
    // v23.1 part 240 — Slider toujours actif, minimum 50 km (Daniel :
    // "deja quand la barre est a 0 sa dois mafficher uniquement les
    // profile de 0 a 50km"). Plus de mode "toutes les distances" qui
    // ramenait des sitters a 250km par fallback list complete.
    final clamped = current.clamp(_kMinRadiusKm, _kMaxRadiusKm).toDouble();
    final label = 'distance_slider_km'
        .trParams({'km': clamped.toInt().toString()});
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.primaryColor,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.near_me_rounded,
                size: 18.sp,
                color: AppColors.primaryColor,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: label,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryColor,
              inactiveTrackColor:
                  AppColors.primaryColor.withValues(alpha: 0.2),
              thumbColor: AppColors.primaryColor,
              overlayColor:
                  AppColors.primaryColor.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: clamped,
              min: _kMinRadiusKm,
              max: _kMaxRadiusKm,
              // (500 - 50) / 9 ~ 50 → 9 divisions de 50km (50/100/.../500).
              divisions: ((_kMaxRadiusKm - _kMinRadiusKm) ~/ 10),
              label: '${clamped.toInt()} km',
              onChanged: (value) {
                final v = value.clamp(_kMinRadiusKm, _kMaxRadiusKm).toDouble();
                setState(() => _maxDistanceKm = v);
                _homeController.nearMeRadiusKm.value = v;
                _homeController.offersNearMeEnabled.value = true;
              },
              onChangeEnd: (value) {
                final v = value.clamp(_kMinRadiusKm, _kMaxRadiusKm).toDouble();
                _homeController.loadNearbySitters(radiusKm: v.round());
                _homeController.loadNearbyWalkers(radiusKm: v.round());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InterText(
                text: '${_kMinRadiusKm.toInt()} km',
                fontSize: 10.sp,
                color: AppColors.textSecondary(context),
              ),
              InterText(
                text: '${_kMaxRadiusKm.toInt()} km',
                fontSize: 10.sp,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // v23.1 part 240 — retourne un Sliver pour s'integrer au CustomScrollView.
  // Le SortBar devient le premier item de la SliverList (index 0).
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
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (sortedMine.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: InterText(
                text: 'my_posts_no_posts'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.greyColor,
              ),
            ),
          ),
        );
      }

      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        sliver: SliverList.builder(
          // +1 pour le SortBar en index 0.
          itemCount: sortedMine.length + 1,
          itemBuilder: (context, idx) {
            if (idx == 0) return _buildMyPostsSortBar();
            final index = idx - 1;
            final post = sortedMine[index];
                  final rawCity = post.location?.city.trim();
                  final locationLabel = (rawCity != null && rawCity.isNotEmpty)
                      ? rawCity
                      : null;
                  // v18.6 — ajout onEdit + isReserved + ownerViewOfOwnPost
                  // + share subject deep-link (cohérence avec my_posts_screen).
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
                    isReserved: post.reservedBy != null,
                    reservedProviderRole: post.reservedBy?.providerRole,
                    ownerViewOfOwnPost: true,
                    // v23.1.152 — Daniel : "pour la 5eme fois ds owner le
                    // cadre urgend sur ma publication naparait pa". CETTE
                    // page (home owner tab "Mes publications") etait celle
                    // qu'il regardait, pas MyPostsScreen. Fix : forwarder
                    // les flags boost au PetPostCard ici aussi.
                    //
                    // v23.1.180 — Daniel : "le cadre urgent boost naparait
                    // tjr pa". Fallback frontend : si MES propres posts ET
                    // que MOI j'ai un boost/abo actif localement (lu via
                    // ActiveBenefitsRow.boostActiveAccessor qui combine
                    // boostExpiry + mapBoostExpiry + UserSubscription
                    // active depuis v175), on force isOwnerBoosted=true
                    // indépendamment du backend cache.
                    isOwnerBoosted: post.isOwnerBoosted ||
                        ActiveBenefitsRow.boostActiveAccessor.value,
                    ownerBoostTier: post.ownerBoostTier,
                    onDelete: () => _confirmAndDeletePost(context, post.id),
                    onEdit: () {
                      Get.to(() => EditPostScreen(post: post));
                    },
                    onShare: () async {
                      try {
                        final petName = post.pets.isNotEmpty
                            ? post.pets.first.petName
                            : '';
                        // v23.1.170 — Daniel : "tout les boutons des email
                        // ne marche pas". Audit a aussi révélé que les
                        // share links pointaient sur hopetsit.app (un
                        // domaine qui n'existe PAS) au lieu de hopetsit.com.
                        // On unifie : tous les liens passent désormais par
                        // hopetsit.com → intercepté par universal links
                        // iOS/Android ou fallback web /post/:id.
                        final link = 'https://hopetsit.com/post/${post.id}';
                        final subject = 'share_post_subject'.trParams({
                          'petName': petName.isEmpty ? 'HoPetSit' : petName,
                        });
                        final shareText =
                            'share_post_body'.trParams({'link': link});
                        final imageUrls = post.images
                            .where((img) => img.url.isNotEmpty)
                            .map((img) => img.url)
                            .toList();
                        if (imageUrls.isNotEmpty) {
                          final tempDir = await getTemporaryDirectory();
                          final List<XFile> xFiles = [];
                          for (int i = 0; i < imageUrls.length; i++) {
                            final url = imageUrls[i];
                            // v23.1.175 — Daniel : fix crash _Uri.resolve
                            // FormatException. tryParse + skip si invalid.
                            final uri = Uri.tryParse(url);
                            if (uri == null || !uri.hasScheme) {
                              continue;
                            }
                            final response = await http.get(uri);
                            final file = File(
                                '${tempDir.path}/share_image_$i.jpg');
                            await file.writeAsBytes(response.bodyBytes);
                            xFiles.add(XFile(file.path));
                          }
                          await SharePlus.instance.share(ShareParams(
                            files: xFiles,
                            text: shareText,
                            subject: subject,
                          ));
                        } else {
                          await SharePlus.instance.share(ShareParams(
                            text: shareText,
                            subject: subject,
                          ));
                        }
                      } catch (e) {
                        AppLogger.logError('Failed to share post', error: e);
                        await SharePlus.instance.share(ShareParams(text: post.body));
                      }
                    },
                  );
                },
              ),
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

  // v23.1 part 240 — SITTERS tab simplifiee : retourne UN sliver, plus de
  // duplicata "Offers Near Me" button (le slider inline en haut de la home
  // joue maintenant ce role). loading/empty state via SliverFillRemaining ;
  // liste via SliverList.builder lazy.
  Widget _buildSittersTab() {
    return Obx(() {
      final isLoading = _homeController.isLoadingSitters.value;

      if (isLoading) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (_homeController.sitters.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
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
        );
      }
      // v23.1 part 250 — perf : le calcul du "latest post" (filter + sort
      // de postsWithoutMedia) etait fait DANS l'itemBuilder, donc re-execute
      // pour CHAQUE sitter a chaque frame de scroll → O(posts) × O(sitters).
      // Or `days` ne depend ni de l'index ni du sitter (c'est le dernier
      // post de l'user courant). On le calcule UNE SEULE FOIS ici, hors du
      // builder. Dans l'itemBuilder on ne fait plus que la multiplication
      // par les tarifs du sitter. Gain direct sur le jank de scroll low-end.
      int? sharedEstDays;
      if (_userId != null) {
        final myPosts = _postsController.postsWithoutMedia
            .where((p) =>
                p.owner.id == _userId &&
                p.startDate != null &&
                p.endDate != null)
            .toList();
        if (myPosts.isNotEmpty) {
          myPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final latestPost = myPosts.first;
          final rawDays =
              latestPost.endDate!.difference(latestPost.startDate!).inDays;
          // Treat same-day requests as 1 day (avoid hiding total).
          sharedEstDays = rawDays > 0 ? rawDays : 1;
        }
      }

      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        sliver: SliverList.builder(
                  itemCount: _homeController.sitters.length,
                  itemBuilder: (context, index) {
                    final sitter = _homeController.sitters[index];

                    // Session v15-3 — the new SitterCard reads rates directly
                    // from the SitterModel (including the hourly × 8 fallback),
                    // so we only compute the "estimated cost" here from the
                    // Owner's latest active reservation post and hand it in.
                    // v23.1 part 250 — days hisse hors builder ; ici on ne
                    // calcule plus que le cout par sitter (cheap).
                    double? estCost;
                    final int? estDays = sharedEstDays;
                    if (estDays != null) {
                      final days = estDays;
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

                    return SitterCard(
                      sitter: sitter,
                      estimatedCost: estCost,
                      estimatedDays: estDays,
                      onTap: () {
                        Get.to(
                          () => ServiceProviderDetailScreen(
                            sitterId: sitter.id,
                            status: 'status_available'.tr,
                          ),
                        );
                      },
                      onSendRequest: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SendRequestScreen(
                              serviceProviderName: sitter.name,
                              serviceProviderId: sitter.id,
                              serviceProviderRole: 'sitter',
                              // Session v15 — pass rates so the Total row
                              // on the request screen can compute live.
                              sitterDailyRate: sitter.dailyRate > 0
                                  ? sitter.dailyRate
                                  : null,
                              sitterWeeklyRate: sitter.weeklyRate > 0
                                  ? sitter.weeklyRate
                                  : null,
                              sitterMonthlyRate: sitter.monthlyRate > 0
                                  ? sitter.monthlyRate
                                  : null,
                              currencyCode: sitter.currency,
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
              );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        // v23.1 part 22 — bg blanc + surfaceTintColor + bottomSheetTheme
        // explicit transparent. Material 3 surface tint OFF pour kill
        // tout overlay teinté gris résiduel.
        backgroundColor: AppColors.appBar(context),
        // ignore: deprecated_member_use
        // surfaceTintColor isn't on Scaffold — Material 3 tint reaches via
        // the inner Material widget. We compensate by wrapping body inline.
        extendBody: false,
        extendBodyBehindAppBar: false,
        // v23.1 part 221 — Daniel : "sur la page acceuil owner et sitter
        // je veux que se soit comme la page de walker quand tu scroll tu
        // scrolle tte la page pas avec le fix en haut bloquer". Avant :
        // HomeHeader custom 70h en appBar (avec avatar + nom + notif +
        // boost) qui prenait beaucoup d'espace fixe en haut. Maintenant :
        // AppBar standard leger (comme walker) avec juste le titre + les
        // actions essentielles. Le body a plus de place et scroll mieux.
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.appBar(context),
          surfaceTintColor: Colors.transparent,
          title: PoppinsText(
            text: _profileController.userName.value.isNotEmpty
                ? _profileController.userName.value
                : 'home_default_user_name'.tr,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          actions: [
            const BoostQuickAction(role: 'owner'),
            SizedBox(width: 4.w),
            IconButton(
              icon: Icon(Icons.notifications_rounded,
                  color: AppColors.primaryColor, size: 22.sp),
              onPressed: () {
                Get.to(() => const NotificationsScreen())?.then((_) {
                  _notificationsController.refreshUnreadCount();
                });
              },
            ),
            SizedBox(width: 8.w),
          ],
        ),
        // v23.1 part 27 — REVERT default SafeArea (bottom: true). Avec la pill
        // flottante + extendBody: true, le body étend derrière la pill. SafeArea
        // bottom protège le contenu pour qu'il ne soit pas caché.
        // v23.1 part 230 — Daniel : "app lag sur Oppo + petit ecran".
        // Root cause = v229 mit shrinkWrap:true + NeverScrollable sur les
        // ListView.builder internes → Flutter doit construire TOUS les
        // items d'un coup (50 sitters = 50 widgets cree + layout au boot
        // de la page). Sur Oppo/low-end → lag impossible a scroller.
        //
        // REVERT v229 : on retire SingleChildScrollView et on revient
        // au Column avec Expanded(ListView.builder) standard. Le ListView
        // construit ses items paresseusement (seulement ce qui est
        // visible) → fluide partout. Le QuickActionBar + Publication
        // input + SegmentedControl restent fixes en haut, mais c'est
        // un compromis necessaire pour la perf low-end.
        // v23.1 part 240 — Daniel : "je veux que la page acceuil sur les
        // 3 profil owner sitter et walker, soit scrolable pas le haut
        // fixe". Refactor en CustomScrollView avec slivers : le header
        // (QuickAction + PostInput + Segment + Slider) devient des
        // SliverToBoxAdapter qui scrollent NATURELLEMENT avec la liste.
        // Avantage perf : SliverList.builder garde le lazy build (pas de
        // regression v229 shrinkWrap). Le top fly-away quand l'user
        // descend dans la liste, comme demandé.
        body: SafeArea(
          child: CustomScrollView(
            // Hint Flutter de garder seulement 80px hors viewport en cache
            // pour scroller fluide sur low-end (Oppo / petits ecrans).
            cacheExtent: 80,
            slivers: [
              // ── Header bloc : actions rapides + input publication ──
              const SliverToBoxAdapter(
                child: HomeQuickActionBar(role: 'owner'),
              ),
              const SliverToBoxAdapter(
                child: ExpandablePostInput(),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 12.h)),

              // ── Segmented control (Mes posts / Pet-sitters / Promeneurs) ──
              SliverToBoxAdapter(
                child: Padding(
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
                      middleText: 'home_segment_sitters'.tr,
                      rightText: 'home_segment_walkers'.tr,
                      selectedIndex: _selectedTabIndex,
                      activeColorLeft: AppColors.primaryColor,
                      activeColorMiddle: const Color(0xFF1A73E8),
                      activeColorRight: AppColors.greenColor,
                      onLeftTap: () {
                        setState(() => _selectedTabIndex = 0);
                      },
                      onMiddleTap: () {
                        setState(() => _selectedTabIndex = 1);
                      },
                      onRightTap: () {
                        setState(() => _selectedTabIndex = 2);
                      },
                    );
                  }),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 12.h)),

              // ── Slider "Près de chez moi" (sitters/walkers tabs only) ──
              if (_selectedTabIndex != 0) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: _buildInlineDistanceSlider(context),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 10.h)),
              ],

              // ── Tab content (Sliver-based pour scroll unifie) ──
              // Chaque _buildXxxTab() retourne maintenant un Widget Sliver
              // (SliverList ou SliverFillRemaining selon loading/empty).
              if (_selectedTabIndex == 0)
                _buildMyPostsTab()
              else if (_selectedTabIndex == 1)
                _buildSittersTab()
              else
                _buildWalkersTab(),

              // Bottom padding pour eviter que le dernier item soit cache
              // par la pill flottante du bottom nav.
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
            ],
          ),
        ),
        // v23.1 — FAB compact bottom-right : icône + uniquement, gradient,
        // taille discrète pour ne pas masquer le contenu.
        floatingActionButton: Container(
          width: 52.w,
          height: 52.w,
          decoration: BoxDecoration(
            gradient: AppColors.linearGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Get.to(() => const PublishReservationRequestScreen())?.then((_) {
                  _postsController.refreshPosts();
                });
              },
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 26.sp,
                  color: AppColors.whiteColor,
                ),
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
