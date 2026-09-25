// v573 — FICHE PROMENEUR vue par un propriétaire.
//
// Même refonte de RENDU que la fiche gardien (`public_profile_kit.dart`) :
// bandeau dégradé vert promeneur + avatar cerclé de blanc (initiale sans
// photo, jamais d'image de catalogue), rangée de 3 tuiles, sections en cartes
// coins 20 avec icône Material dans un rond teinté, sections vides réduites à
// une ligne discrète DANS la carte, fond à petites pattes.
//
// Chargement, repository, conditions d'affichage et données : INCHANGÉS.
// Seuls changements hors rendu pur, tous sans risque :
//   · le titre de la barre affichait « Promeneur » en FRANÇAIS EN DUR → clé
//     existante `role_walker` (l'écran l'utilisait déjà plus bas) ;
//   · la ville / l'adresse (même expression qu'avant) remonte dans l'en-tête
//     au lieu d'une carte à elle seule — rien n'est perdu.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/models/walker_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/views/guest/signup_wall_sheet.dart';
import 'package:hopetsit/views/map/pawmap_rates.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';
import 'package:hopetsit/views/service_provider/widgets/provider_action_bar.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/reviews/widgets/rating_stars.dart';
import 'package:hopetsit/views/service_provider/widgets/public_profile_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

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
  static const PublicProfilePalette _palette = kWalkerProfilePalette;

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
      appBar: publicProfileAppBar(
        palette: _palette,
        title: PoppinsText(
          text: _walker?.name ?? 'role_walker'.tr,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        bottom: false,
        child: _loading
            ? const PublicProfileSkeleton(palette: _palette)
            : _error != null
                ? PublicProfileErrorView(
                    accent: _palette.accent,
                    message: 'walker_load_error'.tr,
                    actionLabel: 'common_retry'.tr,
                    onRetry: _loadWalker,
                  )
                : _walker == null
                    ? PublicProfileErrorView(
                        accent: _palette.accent,
                        icon: Icons.person_off_rounded,
                        message: 'walker_not_found'.tr,
                      )
                    : _buildContent(context, _walker!),
      ),
        ),
    );
  }

  Widget _buildContent(BuildContext context, WalkerModel w) {
    final String language = w.language.trim();
    final List<String> services =
        w.service.where((String s) => s.trim().isNotEmpty).toList();
    // v584 (25/09, point 8) — tarifs HAUT placés (sous l'en-tête, avant la
    // bio), dans SA devise, et barre du bas Réserver · dès X + Message.
    final PawProviderRates providerRates = _ratesOf(w);
    return Column(
      children: <Widget>[
        Expanded(
          child: PublicProfileBackground(
      accent: _palette.accent,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: publicProfileBottomPadding(context, hasActionBar: true),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHero(w),
            SizedBox(height: 18.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildStats(w),
                  SizedBox(height: 14.h),

                  if (!providerRates.isEmpty) ...<Widget>[
                    PublicProfileSection(
                      accent: _palette.accent,
                      icon: Icons.payments_rounded,
                      title: 'pawmap_rates_title'.tr,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: providerRates.lines
                            .map<Widget>((line) => PublicProfileRateRow(
                                  label: line.label,
                                  value: line.value,
                                  accent: _palette.accent,
                                ))
                            .toList(),
                      ),
                    ),
                    SizedBox(height: 14.h),
                  ],

                  // Bio — v471 : libellés i18n (étaient en dur FR).
                  if ((w.bio ?? '').trim().isNotEmpty) ...<Widget>[
                    PublicProfileSection(
                      accent: _palette.accent,
                      icon: Icons.person_rounded,
                      title: 'walker_detail_about'.tr,
                      child: PublicProfileBody(text: w.bio!.trim()),
                    ),
                    SizedBox(height: 14.h),
                  ],

                  // Langue
                  if (language.isNotEmpty) ...<Widget>[
                    PublicProfileSection(
                      accent: _palette.accent,
                      icon: Icons.language_rounded,
                      title: 'walker_detail_language'.tr,
                      child: PublicProfileBody(text: language),
                    ),
                    SizedBox(height: 14.h),
                  ],



                  // Services proposés — v23.1 : libellés lisibles via
                  // service_type_translator (ex. 'dog_walking' → « Promenade »).
                  if (services.isNotEmpty) ...<Widget>[
                    PublicProfileSection(
                      accent: _palette.accent,
                      icon: Icons.work_rounded,
                      title: 'signup_services_offered'.tr,
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: services
                            .map<Widget>((String s) => PublicProfileTag(
                                  label: translateServiceType(s),
                                  accent: _palette.accent,
                                ))
                            .toList(),
                      ),
                    ),
                    SizedBox(height: 14.h),
                  ],

                  // v23.1.290 — Avis (note + commentaire), visibles par tous.
                  _buildReviewsCard(context, w),
                ],
              ),
            ),
          ],
        ),
      ),
          ),
        ),
        ProviderActionBar(
          role: 'walker',
          rates: providerRates,
          canBook: _viewerCanBook,
          messageLoading: _startingChat,
          onBook: () => _book(w),
          onMessage: _viewerRole == 'owner' || _viewerRole.isEmpty ? () => _message(w) : null,
        ),
      ],
    );
  }

  /// v584 (25/09, point 8) — tarifs 30 min / 1 h / 2 h dans SA devise.
  PawProviderRates _ratesOf(WalkerModel w) {
    double? half, hour, two;
    for (final r in w.walkRates) {
      if (!r.enabled || r.basePrice <= 0) continue;
      if (r.durationMinutes == 30) half = r.basePrice;
      if (r.durationMinutes == 60) hour = r.basePrice;
      if (r.durationMinutes == 120) two = r.basePrice;
    }
    return PawProviderRates(
      currency: w.currency.isEmpty ? 'EUR' : w.currency,
      role: 'walker',
      halfHour: half,
      hourly: hour,
      twoHours: two,
    );
  }

  String get _viewerRole {
    final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    return (auth?.userRole.value ?? '').toLowerCase();
  }

  bool get _viewerCanBook => _viewerRole.isEmpty || _viewerRole == 'owner';

  void _book(WalkerModel w) {
    if ((SecureTokenStore.currentToken() ?? '').isEmpty) {
      SignupWallSheet.show(trigger: 'booking', name: w.name, recommendedRole: 'pet_owner');
      return;
    }
    final r = _ratesOf(w);
    Get.to(() => SendRequestScreen(
          serviceProviderName: w.name,
          serviceProviderId: widget.walkerId,
          serviceProviderRole: 'walker',
          walkerHalfHourRate: r.halfHour,
          walkerHourlyRate: r.hourly,
          currencyCode: r.currency,
          initialServiceType: 'dog_walking',
          preselectFirstPet: true,
        ));
  }

  bool _startingChat = false;

  /// Message au promeneur (propriétaire) : même route que depuis la carte.
  Future<void> _message(WalkerModel w) async {
    if ((SecureTokenStore.currentToken() ?? '').isEmpty) {
      SignupWallSheet.show(trigger: 'booking', name: w.name, recommendedRole: 'pet_owner');
      return;
    }
    if (_startingChat) return;
    setState(() => _startingChat = true);
    try {
      final res = await Get.find<OwnerRepository>().startConversation(walkerId: widget.walkerId);
      final conv = res['conversation'] as Map<String, dynamic>?;
      final convId = (conv?['id'] ?? conv?['_id'] ?? '').toString();
      if (convId.isEmpty) throw Exception('conversation id missing');
      if (!mounted) return;
      Get.to(() => IndividualChatScreen(
            conversationId: convId,
            contactName: w.name,
            contactImage: w.avatar.url,
          ));
    } catch (e) {
      AppLogger.logError('walker chat failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'sitter_detail_start_chat_failed'.tr,
      );
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  Widget _buildHero(WalkerModel w) {
    final String city = (w.city ?? '').trim();
    return PublicProfileHero(
      palette: _palette,
      role: 'walker',
      name: w.name,
      imageUrl: w.avatar.url,
      // v471 — Daniel : la pastille « vérifié » ne doit apparaître QUE si le
      // promeneur a PAYÉ la vérification d'identité (KYC 3 €).
      verified: w.identityVerified,
      location: city.isNotEmpty ? city : w.address.trim(),
      // v565 (point 38) — étoiles modernes, « Nouveau » sans avis.
      rating: RatingStars(
        rating: w.rating,
        reviewsCount: w.reviewsCount,
        size: 16,
      ),
    );
  }

  Widget _buildStats(WalkerModel w) {
    return PublicProfileStatsRow(
      accent: _palette.accent,
      stats: <PublicProfileStat>[
        PublicProfileStat(
          icon: Icons.star_rounded,
          value: w.rating > 0 ? w.rating.toStringAsFixed(1) : '—',
          label: 'profiles573_stat_rating'.tr,
        ),
        PublicProfileStat(
          icon: Icons.reviews_rounded,
          value: '${w.reviewsCount}',
          label: 'profiles573_stat_reviews'.tr,
        ),
        PublicProfileStat(
          icon: Icons.directions_walk_rounded,
          value: '${w.completedWalksCount}',
          label: 'profiles573_stat_walks'.tr,
        ),
      ],
    );
  }

  Widget _buildReviewsCard(BuildContext context, WalkerModel w) {
    final List<dynamic> reviews = w.reviews;
    return PublicProfileSection(
      accent: _palette.accent,
      icon: Icons.star_rounded,
      title: 'sitter_detail_reviews_title'.tr,
      trailing: reviews.isEmpty
          ? null
          : InterText(
              text: '${reviews.length}',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
            ),
      child: reviews.isEmpty
          ? PublicProfileEmptyLine(
              icon: Icons.star_outline_rounded,
              text: 'sitter_detail_no_reviews'.tr,
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < reviews.length; i++) ...<Widget>[
                  if (i > 0) SizedBox(height: 10.h),
                  _buildReviewItem(context, reviews[i]),
                ],
              ],
            ),
    );
  }

  Widget _buildReviewItem(BuildContext context, dynamic review) {
    String asStr(dynamic v) => v == null ? '' : v.toString();
    final Map<dynamic, dynamic> reviewMap =
        review is Map ? review : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> reviewerMap = reviewMap['reviewer'] is Map
        ? reviewMap['reviewer'] as Map<dynamic, dynamic>
        : const <dynamic, dynamic>{};
    final String reviewerName = asStr(reviewMap['reviewerName']).isNotEmpty
        ? asStr(reviewMap['reviewerName'])
        : asStr(reviewerMap['name']);
    final String reviewerImage = asStr(reviewMap['reviewerImage']).isNotEmpty
        ? asStr(reviewMap['reviewerImage'])
        : asStr(reviewerMap['avatar']);
    final double rating = (reviewMap['rating'] as num?)?.toDouble() ?? 0.0;
    final String displayName = reviewerName.trim().isNotEmpty
        ? reviewerName.trim()
        : 'sitter_detail_anonymous_reviewer'.tr;

    return PublicProfileReviewCard(
      name: displayName,
      imageUrl: reviewerImage,
      rating: rating,
      comment: asStr(reviewMap['comment']),
      date: _reviewDate(context, reviewMap['createdAt']),
      accent: _palette.accent,
    );
  }

  /// Date d'un avis, formatée par les localisations Material (jamais de table
  /// de mois codée en dur). Null si la date est absente ou illisible.
  String? _reviewDate(BuildContext context, dynamic raw) {
    final String s = (raw ?? '').toString().trim();
    if (s.isEmpty) return null;
    final DateTime? d = DateTime.tryParse(s);
    if (d == null) return null;
    return MaterialLocalizations.of(context).formatShortDate(d.toLocal());
  }

  // v472 — Daniel : nouveaux paliers walking « 30 min / 1h / 2h » (fini le
  // 60/90/120). Libellé court et NEUTRE (h/min universels, pas besoin d'i18n)
  // au lieu de « Promenade X min » en dur FR.
}
