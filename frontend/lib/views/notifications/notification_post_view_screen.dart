import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/post_date_label.dart';
import 'package:hopetsit/utils/post_price_estimator.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/service_provider/owner_profile_view_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/post_comment_sheet.dart';
import 'package:share_plus/share_plus.dart';

/// Shows a single post as the same [PetPostCard] used on the home feed (e.g. from a like notification).
class NotificationPostViewScreen extends StatefulWidget {
  const NotificationPostViewScreen({
    super.key,
    required this.post,
    this.openCommentsOnOpen = false,
  });

  final PostModel post;
  final bool openCommentsOnOpen;

  @override
  State<NotificationPostViewScreen> createState() =>
      _NotificationPostViewScreenState();
}

class _NotificationPostViewScreenState
    extends State<NotificationPostViewScreen> {
  // v442 — tarifs du prestataire qui consulte l'annonce (mêmes sources que le
  // feed sitter/walker) pour calculer « Votre gain estimé » via le MÊME helper
  // estimatePostPrice → synchronisé avec la charge réelle backend.
  double _providerHourlyRate = 0.0;
  double _providerDailyRate = 0.0;
  double _providerWeeklyRate = 0.0;
  double _providerMonthlyRate = 0.0;
  double _providerWalkRate30 = 0.0;
  double _providerWalkRate60 = 0.0;
  String _providerCurrency = 'EUR';

  @override
  void initState() {
    super.initState();
    if (widget.openCommentsOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          PostCommentSheet.show(context, widget.post);
        }
      });
    }
    // v442 — si un prestataire ouvre l'annonce, on charge ses tarifs pour le
    // bloc « gain estimé » (silencieux pour un owner / visiteur).
    _loadProviderRates();
  }

  String get _viewerRole {
    final role = Get.isRegistered<AuthController>()
        ? (Get.find<AuthController>().userRole.value ?? '').toLowerCase()
        : (GetStorage().read(StorageKeys.userRole) ?? '')
            .toString()
            .toLowerCase();
    return role;
  }

  /// v442 — calque exact de sitter_homescreen._loadProviderRates (walker
  /// /walkers/me/rates ; sitter GET /sitters/:id). Aucune nouvelle source.
  Future<void> _loadProviderRates() async {
    try {
      final role = _viewerRole;
      if (role == 'walker') {
        final walkerRepo = Get.isRegistered<WalkerRepository>()
            ? Get.find<WalkerRepository>()
            : null;
        if (walkerRepo == null) return;
        final rates = await walkerRepo.getMyWalkerRates();
        double hourly = 0.0;
        double halfHour = 0.0;
        for (final r in rates) {
          if (!r.enabled || r.basePrice <= 0) continue;
          if (r.durationMinutes == 60 && hourly == 0.0) hourly = r.basePrice;
          if (r.durationMinutes == 30 && halfHour == 0.0) halfHour = r.basePrice;
        }
        final derivedHourly = hourly > 0 ? hourly : halfHour * 2;
        if (!mounted) return;
        setState(() {
          _providerHourlyRate = derivedHourly;
          _providerWalkRate30 = halfHour;
          _providerWalkRate60 = hourly;
        });
      } else if (role == 'sitter') {
        final userProfile =
            GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
        final sitterId = userProfile?['id']?.toString();
        if (sitterId == null || sitterId.isEmpty) return;
        final sitterRepo = Get.isRegistered<SitterRepository>()
            ? Get.find<SitterRepository>()
            : null;
        if (sitterRepo == null) return;
        final profile = await sitterRepo.getSitterProfile(sitterId);
        final sitterPayload = (profile['sitter'] is Map)
            ? Map<String, dynamic>.from(profile['sitter'] as Map)
            : profile;
        double n(dynamic v) =>
            v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
        if (!mounted) return;
        setState(() {
          _providerHourlyRate = n(sitterPayload['hourlyRate']);
          _providerDailyRate = n(sitterPayload['dailyRate']);
          _providerWeeklyRate = n(sitterPayload['weeklyRate']);
          _providerMonthlyRate = n(sitterPayload['monthlyRate']);
          final cur = sitterPayload['currency']?.toString() ??
              sitterPayload['hourlyRateCurrency']?.toString();
          if (cur != null && cur.isNotEmpty) {
            _providerCurrency = cur.toUpperCase();
          }
        });
      }
    } catch (e) {
      AppLogger.logDebug('notif loadProviderRates failed: $e');
    }
  }

  /// v442 — même estimation que le feed (utils/post_price_estimator), donc le
  /// total client et le gain affichés == ce qui est réellement facturé.
  PostPriceEstimate? _estimateForPost(PostModel post) {
    try {
      final role = _viewerRole;
      if (role != 'sitter' && role != 'walker') return null;
      final hasAnyRate = _providerHourlyRate > 0 ||
          _providerDailyRate > 0 ||
          _providerWeeklyRate > 0 ||
          _providerMonthlyRate > 0;
      if (!hasAnyRate) return null;
      return estimatePostPrice(
        post: post,
        userRole: role,
        hourlyRate: _providerHourlyRate,
        dailyRate: _providerDailyRate,
        weeklyRate: _providerWeeklyRate,
        monthlyRate: _providerMonthlyRate,
        currency: _providerCurrency,
        walkRate30: _providerWalkRate30 > 0 ? _providerWalkRate30 : null,
        walkRate60: _providerWalkRate60 > 0 ? _providerWalkRate60 : null,
      );
    } catch (e) {
      AppLogger.logDebug('notif estimateForPost failed: $e');
      return null;
    }
  }

  /// v442 — libellé « Publié il y a … » dérivé de createdAt.
  String _publishedLabel(DateTime created) {
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'post_published_just_now'.tr;
    if (diff.inMinutes < 60) {
      return '${'post_published_prefix'.tr} ${diff.inMinutes} ${'post_time_minutes'.tr}';
    }
    if (diff.inHours < 24) {
      return '${'post_published_prefix'.tr} ${diff.inHours} ${diff.inHours == 1 ? 'post_time_hour'.tr : 'post_time_hours'.tr}';
    }
    final days = diff.inDays;
    return '${'post_published_prefix'.tr} $days ${days == 1 ? 'post_time_day'.tr : 'post_time_days'.tr}';
  }

  /// v442 — durée d'UNE sortie (minutes) pour la grille walker, dérivée de la
  /// fenêtre start/end de l'annonce (même base que l'estimateur de prix).
  int? _walkDurationMinutes(PostModel post) {
    final s = post.startDate;
    final e = post.endDate;
    if (s == null || e == null) return null;
    if (!e.isAfter(s)) return null;
    final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
    if (!sameDay) return null; // multi-jours : pas une durée « par sortie ».
    final m = e.difference(s).inMinutes;
    return m > 0 ? m : null;
  }

  // v443 — Daniel : la cellule « Dates » n'affiche plus que la DATE ; l'heure
  // part dans une horloge sous « Service » (cf serviceTime / PostDateLabel).
  static String? _postDateRangeLabel(PostModel post) =>
      PostDateLabel.dateOnly(post);

  static String _serviceTypesDisplay(List<String> types) {
    return translateServiceTypes(types);
  }

  /// #107 — ouvre le profil PROPRIÉTAIRE en lecture seule depuis l'en-tête de
  /// l'annonce (mêmes données que le feed : owner + pets du post).
  void _openOwnerProfile(PostModel post) {
    final rawCity = post.location?.city.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerProfileViewScreen(
          ownerId: post.owner.id,
          ownerName: post.owner.name,
          ownerAvatar:
              post.owner.avatar.isNotEmpty ? post.owner.avatar : null,
          ownerBio: post.owner.bio,
          ownerCity: (rawCity != null && rawCity.isNotEmpty) ? rawCity : null,
          pets: post.pets,
        ),
      ),
    );
  }

  PostModel _livePost(PostsController c) {
    for (final p in c.posts) {
      if (p.id == widget.post.id) return p;
    }
    for (final p in c.postsWithoutMedia) {
      if (p.id == widget.post.id) return p;
    }
    return widget.post;
  }

  @override
  Widget build(BuildContext context) {
    final postsController = Get.isRegistered<PostsController>()
        ? Get.find<PostsController>()
        : Get.put(PostsController());

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.appBar(context),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        title: InterText(
          text: 'notifications_post_view_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Obx(() {
            postsController.posts;
            postsController.postsWithoutMedia;
            final post = _livePost(postsController);
            final imageUrls = post.images
                .map((img) => img.url)
                .where((url) => url.isNotEmpty)
                .toList();
            final petName = post.pets.isNotEmpty
                ? post.pets.first.petName
                : null;
            final rawCity = post.location?.city.trim();
            final locationLabel = (rawCity != null && rawCity.isNotEmpty)
                ? rawCity
                : null;
            final dateRangeLabel = _postDateRangeLabel(post);
            final serviceTypesLabel = _serviceTypesDisplay(post.serviceTypes);

            final viewerRole = _viewerRole;
            final isProvider = viewerRole == 'walker' || viewerRole == 'sitter';
            return PetPostCard(
              userName: post.owner.name,
              userEmail: '',
              userAvatar: post.owner.avatar.isNotEmpty
                  ? post.owner.avatar
                  : null,
              petImages: imageUrls,
              // v420 — maquette détail annonce : animaux + bio owner.
              pets: post.pets,
              ownerBio: post.owner.bio,
              serviceLocation: post.serviceLocation,
              postBody: post.body,
              petName: petName,
              serviceTypes: serviceTypesLabel.isEmpty
                  ? null
                  : serviceTypesLabel,
              dateRange: dateRangeLabel,
              // v443 — heure → horloge sous « Service ».
              serviceTime: PostDateLabel.timeLabel(post),
              location: locationLabel,
              isNetworkImage: imageUrls.isNotEmpty,
              likeCount: post.likesCount,
              commentCount: post.commentsCount,
              // v442 — détail prestataire : couleur du rôle (vert walker /
              // bleu sitter), « Publié il y a … », durée de sortie, et
              // « Votre gain estimé » synchronisé au paiement réel.
              viewerRole: isProvider ? viewerRole : null,
              // #107 — prestataire : en-tête cliquable → profil propriétaire
              // (lecture seule) avec ses animaux. Owner/visiteur : inerte.
              onOwnerTap: (isProvider && post.owner.id.isNotEmpty)
                  ? () => _openOwnerProfile(post)
                  : null,
              priceEstimate: isProvider ? _estimateForPost(post) : null,
              publishedLabel:
                  isProvider ? _publishedLabel(post.createdAt) : null,
              walkDurationMinutes:
                  isProvider ? _walkDurationMinutes(post) : null,
              isReserved: post.isReserved,
              reservedProviderRole: post.reservedBy?.providerRole,
              isOwnerBoosted: post.isOwnerBoosted,
              ownerBoostTier: post.ownerBoostTier,
              isLiked: postsController.isPostLiked(post.id),
              onLike: () => postsController.toggleLike(post.id),
              onComment: () => PostCommentSheet.show(context, post),
              // v23.1.168 — Daniel : "verifie le bouton partager qui bug".
              // Le bouton Compartir/Partager n'avait pas de callback câblé
              // sur l'écran ouvert depuis une notification → tap inerte.
              // On fait pareil que sitter_homescreen / my_posts : on partage
              // le titre + lien deep-link vers le post.
              onShare: () {
                // v23.1.175 — Daniel : 14 crashes _Uri.resolve.
                // Manquait try/catch ici. On wrap pour ne plus crasher.
                try {
                  final text = post.body.trim().isNotEmpty
                      ? post.body.trim()
                      : 'post_card_default_share_message'.tr;
                  final postId = post.id.trim();
                  if (postId.isEmpty) {
                    // Pas de post.id → on partage juste le texte.
                    SharePlus.instance.share(ShareParams(text: text));
                    return;
                  }
                  final url = 'https://hopetsit.com/post/$postId';
                  SharePlus.instance.share(
                    ShareParams(text: '$text\n\n$url'),
                  );
                } catch (e) {
                  // Silently ignore — share failures shouldn't crash the app.
                }
              },
            );
          }),
        ),
      ),
    );
  }
}
