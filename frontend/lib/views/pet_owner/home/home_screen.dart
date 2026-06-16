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
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/sitter_card.dart';
import 'package:hopetsit/views/pet_owner/home/widgets/walker_card.dart';
import 'package:hopetsit/views/pet_owner/posts/edit_post_screen.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/expandable_post_input.dart';
import 'package:hopetsit/widgets/home_quick_action_bar.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:share_plus/share_plus.dart';

enum HomeMyPostsSortOrder { newestFirst, oldestFirst }

/// v426 — tri client-side de la liste de prestataires affichée (bouton
/// "Trier" du nouveau bloc recherche). Distance = plus proche d'abord ;
/// Note = meilleure note d'abord.
enum HomeProviderSortOrder { distance, rating }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;
  HomeMyPostsSortOrder _myPostsSortOrder = HomeMyPostsSortOrder.newestFirst;

  // v426 — tri client-side de la liste de prestataires (bouton "Trier" du
  // bloc recherche premium). Defaut : par distance (plus proche d'abord).
  HomeProviderSortOrder _providerSortOrder = HomeProviderSortOrder.distance;

  // v435 — filtres client-side fonctionnels (Daniel : "Trier marche mais
  // Animaux gardés et Disponibilité ouvrent juste 'Bientôt'").
  //   _petTypeFilter      : 'dog' | 'cat' | 'small' | 'nac' | 'bird' | null(=tous)
  //   _availabilityFilter : 'today' | 'week' | null(=tous)
  // Le filtre s'applique sur la liste réactive du HomeController (même
  // approche assignAll que le tri). Choisir "Tous" relance la recherche
  // nearby pour restaurer l'ensemble complet.
  String? _petTypeFilter;
  String? _availabilityFilter;

  // v426 — refonte header recherche (maquettes 50/51) : la valeur du rayon
  // est portée par le HomeController (nearMeRadiusKm) ; on n'a plus besoin
  // du flag offersNearMeEnabled côté UI. Bornes du slider : 10 → 500 km.
  static const double _kMinRadiusKm = 10.0;
  static const double _kMaxRadiusKm = 500.0;

  /// Accent de l'onglet actif (bleu pet-sitters / vert promeneurs).
  static const Color _kSitterAccent = Color(0xFF2563EB);
  static const Color _kWalkerAccent = Color(0xFF16A34A);

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

  // ==========================================================================
  // v426 — Refonte header recherche owner (maquettes 50 = pet-sitters bleu,
  // 51 = promeneurs vert). Remplace l'ancien slider rouge "Près de chez moi".
  //   1) bloc recherche (chip localisation + slider rayon 10→500 km)
  //   2) rangée de filtres (chips Animaux gardés / Disponibilité / Trier)
  //   3) en-tête résultats (compteur autour de moi + résultats trouvés)
  // Le slider déclenche les MÊMES appels que l'ancien (loadNearbySitters /
  // loadNearbyWalkers) → la recherche par rayon fonctionne à l'identique.
  // ==========================================================================

  bool get _isWalkerTab => _selectedTabIndex == 2;
  Color get _accent => _isWalkerTab ? _kWalkerAccent : _kSitterAccent;

  /// Ville + pays de l'owner depuis le profil persistant (sinon "Ma position").
  /// v435 — si une ville de recherche manuelle est fixée, elle prime sur le
  /// profil (l'utilisateur a explicitement choisi de chercher ailleurs).
  String _ownerCityCountryLabel() {
    final manual = _homeController.searchCity.value.trim();
    if (manual.isNotEmpty) return manual;
    try {
      final profile =
          _storage.read(StorageKeys.userProfile) as Map<String, dynamic>?;
      String city = '';
      String country = '';
      final loc = profile?['location'];
      if (loc is Map) {
        city = (loc['city'] as String?)?.trim() ?? '';
        country = (loc['country'] as String?)?.trim() ?? '';
      }
      if (city.isEmpty) city = (profile?['city'] as String?)?.trim() ?? '';
      if (country.isEmpty) {
        country = (profile?['country'] as String?)?.trim() ?? '';
      }
      final parts = [city, country].where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.join(', ');
    } catch (_) {/* noop */}
    return 'home_my_position'.tr;
  }

  /// v426 — barre d'onglets pill (icône + label) façon maquettes 50/51.
  /// Garde EXACTEMENT la logique de switch (setState _selectedTabIndex).
  /// Actif : pill plein coloré (orange/bleu/vert) + texte blanc ;
  /// inactif : transparent + texte gris.
  Widget _buildTabBar(BuildContext context) {
    final allPosts = <PostModel>[
      ..._postsController.posts,
      ..._postsController.postsWithoutMedia,
    ];
    final myCount = _userId == null
        ? 0
        : allPosts.where((p) => p.owner.id == _userId).length;
    return Container(
      height: 52.h,
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabPill(
              context,
              index: 0,
              icon: Icons.article_rounded,
              label: '${'my_posts_title'.tr} ($myCount)',
              activeColor: AppColors.primaryColor,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: _tabPill(
              context,
              index: 1,
              icon: Icons.pets_rounded,
              label: 'home_segment_sitters'.tr,
              activeColor: _kSitterAccent,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: _tabPill(
              context,
              index: 2,
              icon: Icons.directions_walk_rounded,
              label: 'home_segment_walkers'.tr,
              activeColor: _kWalkerAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabPill(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
  }) {
    final selected = _selectedTabIndex == index;
    final fg = selected ? AppColors.whiteColor : AppColors.grey500Color;
    return GestureDetector(
      onTap: () {
        if (_selectedTabIndex == index) return;
        setState(() => _selectedTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        height: double.infinity,
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15.sp, color: fg),
                SizedBox(width: 4.w),
                Flexible(
                  child: InterText(
                    text: label,
                    textAlign: TextAlign.center,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bloc recherche premium : chip localisation (gauche) + rayon (droite).
  Widget _buildSearchBlock(BuildContext context) {
    final accent = _accent;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gauche : chip localisation (tappable, no-op pour l'instant) ──
          Expanded(
            flex: 5,
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              // v435 — Daniel : permettre de CHANGER de ville depuis la carte
              // "Autour de moi". Tap → bottomsheet picker de ville.
              onTap: () => _showCityPickerSheet(context),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 16.sp, color: accent),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: PoppinsText(
                            text: 'home_around_me'.tr,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Flexible(
                          child: InterText(
                            text: _ownerCityCountryLabel(),
                            fontSize: 11.sp,
                            color: AppColors.textSecondary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16.sp,
                            color: AppColors.textSecondary(context)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Container(width: 1, height: 48.h, color: AppColors.divider(context)),
          SizedBox(width: 10.w),
          // ── Droite : rayon (label + valeur + slider + ticks) ──
          Expanded(
            flex: 7,
            child: Obx(() {
              final current = _homeController.nearMeRadiusKm.value
                  .clamp(_kMinRadiusKm, _kMaxRadiusKm)
                  .toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InterText(
                        text: 'home_radius'.tr,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(context),
                      ),
                      PoppinsText(
                        text: '${current.toInt()} km',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accent,
                      inactiveTrackColor: accent.withValues(alpha: 0.18),
                      thumbColor: accent,
                      overlayColor: accent.withValues(alpha: 0.15),
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 9),
                    ),
                    child: Slider(
                      value: current,
                      min: _kMinRadiusKm,
                      max: _kMaxRadiusKm,
                      divisions: ((_kMaxRadiusKm - _kMinRadiusKm) ~/ 10),
                      label: '${current.toInt()} km',
                      onChanged: (value) {
                        final v = value
                            .clamp(_kMinRadiusKm, _kMaxRadiusKm)
                            .toDouble();
                        _homeController.nearMeRadiusKm.value = v;
                        _homeController.offersNearMeEnabled.value = true;
                      },
                      onChangeEnd: (value) {
                        final v = value
                            .clamp(_kMinRadiusKm, _kMaxRadiusKm)
                            .toDouble();
                        // MÊMES appels que l'ancien slider → recherche intacte.
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
                        fontSize: 9.sp,
                        color: AppColors.textSecondary(context),
                      ),
                      InterText(
                        text: '50 km',
                        fontSize: 9.sp,
                        color: AppColors.textSecondary(context),
                      ),
                      InterText(
                        text: '${_kMaxRadiusKm.toInt()} km',
                        fontSize: 9.sp,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Rangée de 3 chips filtre. Animaux/Promenades + Disponibilité ouvrent un
  /// bottomsheet placeholder léger ; "Trier" ouvre un sheet de tri fonctionnel.
  Widget _buildFilterRow(BuildContext context) {
    final accent = _accent;
    final keptLabel =
        _isWalkerTab ? 'home_filter_walks'.tr : 'home_filter_kept_pets'.tr;
    final keptIcon =
        _isWalkerTab ? Icons.directions_walk_rounded : Icons.pets_rounded;
    // v435 — la puce reflète si un filtre est actif (label dynamique + accent).
    final petActive = _petTypeFilter != null;
    final availActive = _availabilityFilter != null;
    final keptDynamicLabel =
        petActive ? '$keptLabel · ${_petTypeShortLabel(_petTypeFilter!)}' : keptLabel;
    final availLabel = availActive
        ? (_availabilityFilter == 'today'
            ? 'home_avail_today'.tr
            : 'home_avail_week'.tr)
        : 'home_filter_availability'.tr;
    return Row(
      children: [
        Expanded(
          child: _filterChip(
            context,
            icon: keptIcon,
            label: keptDynamicLabel,
            showChevron: true,
            accent: petActive ? accent : null,
            onTap: () => _showPetTypeFilterSheet(context, keptLabel),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _filterChip(
            context,
            icon: Icons.event_available_rounded,
            label: availLabel,
            showChevron: true,
            accent: availActive ? accent : null,
            onTap: () => _showAvailabilityFilterSheet(context),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _filterChip(
            context,
            icon: Icons.tune_rounded,
            label: 'home_filter_sort'.tr,
            showChevron: false,
            accent: accent,
            onTap: () => _showSortSheet(context),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool showChevron,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final fg = accent ?? AppColors.textPrimary(context);
    return Material(
      color: accent != null
          ? accent.withValues(alpha: 0.08)
          : AppColors.inputFill(context),
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
                color: accent != null
                    ? accent.withValues(alpha: 0.4)
                    : AppColors.divider(context),
                width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15.sp, color: fg),
              SizedBox(width: 5.w),
              Flexible(
                child: InterText(
                  text: label,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showChevron)
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16.sp, color: AppColors.textSecondary(context)),
            ],
          ),
        ),
      ),
    );
  }

  /// En-tête résultats : "🎯 N pet-sitters/promeneurs autour de moi" + count.
  Widget _buildResultsHeader(BuildContext context) {
    return Obx(() {
      final count = _isWalkerTab
          ? _homeController.walkers.length
          : _homeController.sitters.length;
      final leftText = _isWalkerTab
          ? 'home_results_walkers'.trParams({'count': count.toString()})
          : 'home_results_sitters'.trParams({'count': count.toString()});
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('🎯', style: TextStyle(fontSize: 14.sp)),
          SizedBox(width: 6.w),
          Expanded(
            child: PoppinsText(
              text: leftText,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 6.w),
          InterText(
            text: 'home_results_found'.trParams({'count': count.toString()}),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: _accent,
          ),
        ],
      );
    });
  }

  /// Bottomsheet de tri fonctionnel — applique un tri client-side (Distance /
  /// Note) sur la liste de prestataires actuellement affichée.
  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.card(ctx),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(
            20.w, 14.h, 20.w, 20.h + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 14.h),
                decoration: BoxDecoration(
                  color: AppColors.divider(ctx),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            PoppinsText(
              text: 'home_filter_sort'.tr,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(ctx),
            ),
            SizedBox(height: 8.h),
            _sortTile(
              ctx,
              icon: Icons.near_me_rounded,
              label: 'home_sort_distance'.tr,
              selected: _providerSortOrder == HomeProviderSortOrder.distance,
              onTap: () {
                Navigator.pop(ctx);
                _applyProviderSort(HomeProviderSortOrder.distance);
              },
            ),
            _sortTile(
              ctx,
              icon: Icons.star_rounded,
              label: 'home_sort_rating'.tr,
              selected: _providerSortOrder == HomeProviderSortOrder.rating,
              onTap: () {
                Navigator.pop(ctx);
                _applyProviderSort(HomeProviderSortOrder.rating);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = _accent;
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
        child: Row(
          children: [
            Icon(icon, size: 20.sp, color: selected ? accent : AppColors.greyColor),
            SizedBox(width: 12.w),
            Expanded(
              child: InterText(
                text: label,
                fontSize: 14.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 18.sp, color: accent),
          ],
        ),
      ),
    );
  }

  /// Applique le tri choisi sur la liste réactive du HomeController. Le tri
  /// est purement client-side et ne touche pas au chargement réseau.
  void _applyProviderSort(HomeProviderSortOrder order) {
    setState(() => _providerSortOrder = order);
    if (_isWalkerTab) {
      final list = _homeController.walkers.toList();
      list.sort((a, b) {
        if (order == HomeProviderSortOrder.rating) {
          return b.rating.compareTo(a.rating);
        }
        final da = a.distanceKm ?? double.infinity;
        final db = b.distanceKm ?? double.infinity;
        return da.compareTo(db);
      });
      _homeController.walkers.assignAll(list);
    } else {
      final list = _homeController.sitters.toList();
      list.sort((a, b) {
        if (order == HomeProviderSortOrder.rating) {
          return b.rating.compareTo(a.rating);
        }
        final da = a.distanceKm ?? double.infinity;
        final db = b.distanceKm ?? double.infinity;
        return da.compareTo(db);
      });
      _homeController.sitters.assignAll(list);
    }
  }

  // v435 — libellé court d'un type d'animal pour la puce de filtre.
  String _petTypeShortLabel(String key) {
    switch (key) {
      case 'dog':
        return 'pet_type_dog'.tr;
      case 'cat':
        return 'pet_type_cat'.tr;
      case 'small':
        return 'pet_type_small'.tr;
      case 'nac':
        return 'pet_type_nac'.tr;
      case 'bird':
        return 'pet_type_bird'.tr;
      default:
        return key;
    }
  }

  /// v435 — recharge la liste nearby complète (réinitialise les filtres en
  /// les ré-appliquant ensuite sur la liste fraîche).
  Future<void> _reloadProviders() async {
    final r = _homeController.nearMeRadiusKm.value.round();
    if (_isWalkerTab) {
      await _homeController.loadNearbyWalkers(radiusKm: r);
    } else {
      await _homeController.loadNearbySitters(radiusKm: r);
    }
  }

  /// v435 — applique les filtres actifs (type d'animal + disponibilité) sur la
  /// liste réactive du HomeController, après l'avoir rechargée complète.
  Future<void> _applyProviderFilters() async {
    await _reloadProviders();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    bool availMatch(List<DateTime> dates) {
      if (_availabilityFilter == null) return true;
      if (dates.isEmpty) return false;
      for (final d in dates) {
        final day = DateTime(d.year, d.month, d.day);
        if (_availabilityFilter == 'today') {
          if (day == today) return true;
        } else {
          if (!day.isBefore(today) && day.isBefore(weekEnd)) return true;
        }
      }
      return false;
    }

    if (_isWalkerTab) {
      // Walker a acceptedPetTypes → filtre type réel ; availableDates → dispo.
      final filtered = _homeController.walkers.where((w) {
        final typeOk = _petTypeFilter == null ||
            w.acceptedPetTypes
                .map((e) => e.toLowerCase())
                .contains(_petTypeFilter);
        return typeOk && availMatch(w.availableDates);
      }).toList();
      _homeController.walkers.assignAll(filtered);
    } else {
      // Sitter n'expose pas acceptedPetTypes côté client → le filtre type est
      // un no-op (on ne masque personne) ; la dispo s'applique via availableDates.
      final filtered = _homeController.sitters.where((s) {
        return availMatch(s.availableDates);
      }).toList();
      _homeController.sitters.assignAll(filtered);
    }
    if (mounted) setState(() {});
  }

  /// v435 — sheet "Animaux gardés / Promenades" : choix d'un type d'animal.
  void _showPetTypeFilterSheet(BuildContext context, String title) {
    final options = <Map<String, String>>[
      {'key': '', 'label': 'home_filter_all'.tr},
      {'key': 'dog', 'label': 'pet_type_dog'.tr},
      {'key': 'cat', 'label': 'pet_type_cat'.tr},
      {'key': 'small', 'label': 'pet_type_small'.tr},
      {'key': 'nac', 'label': 'pet_type_nac'.tr},
      {'key': 'bird', 'label': 'pet_type_bird'.tr},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _filterSheetShell(
        ctx,
        title: title,
        children: options.map((o) {
          final key = o['key']!;
          final selected =
              (key.isEmpty && _petTypeFilter == null) || _petTypeFilter == key;
          return _sortTile(
            ctx,
            icon: key.isEmpty ? Icons.clear_all_rounded : Icons.pets_rounded,
            label: o['label']!,
            selected: selected,
            onTap: () {
              Navigator.pop(ctx);
              _petTypeFilter = key.isEmpty ? null : key;
              _applyProviderFilters();
            },
          );
        }).toList(),
      ),
    );
  }

  /// v435 — sheet "Disponibilité" : aujourd'hui / cette semaine / tous.
  void _showAvailabilityFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _filterSheetShell(
        ctx,
        title: 'home_filter_availability'.tr,
        children: [
          _sortTile(
            ctx,
            icon: Icons.clear_all_rounded,
            label: 'home_filter_all'.tr,
            selected: _availabilityFilter == null,
            onTap: () {
              Navigator.pop(ctx);
              _availabilityFilter = null;
              _applyProviderFilters();
            },
          ),
          _sortTile(
            ctx,
            icon: Icons.today_rounded,
            label: 'home_avail_today'.tr,
            selected: _availabilityFilter == 'today',
            onTap: () {
              Navigator.pop(ctx);
              _availabilityFilter = 'today';
              _applyProviderFilters();
            },
          ),
          _sortTile(
            ctx,
            icon: Icons.date_range_rounded,
            label: 'home_avail_week'.tr,
            selected: _availabilityFilter == 'week',
            onTap: () {
              Navigator.pop(ctx);
              _availabilityFilter = 'week';
              _applyProviderFilters();
            },
          ),
        ],
      ),
    );
  }

  /// Coquille commune des bottomsheets de filtre (poignée + titre + items).
  Widget _filterSheetShell(
    BuildContext ctx, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(ctx),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(
          20.w, 14.h, 20.w, 20.h + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 14.h),
              decoration: BoxDecoration(
                color: AppColors.divider(ctx),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          PoppinsText(
            text: title,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(ctx),
          ),
          SizedBox(height: 8.h),
          ...children,
        ],
      ),
    );
  }

  /// v435 — sheet "Autour de moi" : champ ville avec autocomplétion (réutilise
  /// CityLocationPicker) pour changer la ville de recherche, + bouton retour GPS.
  void _showCityPickerSheet(BuildContext context) {
    final cityController = TextEditingController(
      text: _homeController.searchCity.value,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card(ctx),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.fromLTRB(
              20.w, 14.h, 20.w, 20.h + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.divider(ctx),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              PoppinsText(
                text: 'home_change_city_title'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(ctx),
              ),
              SizedBox(height: 4.h),
              InterText(
                text: 'home_change_city_hint'.tr,
                fontSize: 12.sp,
                color: AppColors.textSecondary(ctx),
              ),
              SizedBox(height: 12.h),
              CityLocationPicker(
                cityController: cityController,
                isGettingLocation: false,
                onGetLocation: () {
                  // Retour à la géoloc de l'appareil.
                  Navigator.pop(ctx);
                  _homeController.clearSearchCity();
                  setState(() {});
                },
                detectedCity: _homeController.searchCity.value,
                onLocationSelected: (city, lat, lng) {
                  Navigator.pop(ctx);
                  _homeController.setSearchCity(city, lat, lng);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
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
                    // v420 — maquette détail annonce : animaux + bio owner.
                    pets: post.pets,
                    ownerBio: post.owner.bio,
                    // v435 — lieu de garde affiché dans la grille.
                    serviceLocation: post.serviceLocation,
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
              // v426 — le composer "Publication" n'apparaît que sur l'onglet
              // "Mes publications" (absent des maquettes 50/51 prestataires).
              if (_selectedTabIndex == 0) ...[
                const SliverToBoxAdapter(
                  child: ExpandablePostInput(),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 12.h)),
              ] else
                SliverToBoxAdapter(child: SizedBox(height: 12.h)),

              // ── Tabs (Mes publications / Pet-sitters / Promeneurs) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _buildTabBar(context),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 12.h)),

              // ── Header recherche premium (sitters/walkers tabs only) ──
              if (_selectedTabIndex != 0) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: _buildSearchBlock(context),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 10.h)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: _buildFilterRow(context),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 12.h)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: _buildResultsHeader(context),
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
