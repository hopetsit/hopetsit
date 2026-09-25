// v573 — FICHE GARDIEN vue par un propriétaire (depuis une annonce, l'accueil,
// la PawMap, une notification ou la liste d'amis).
//
// Daniel, capture à l'appui : « c'est la vieille page, le design d'avant, pas
// possible ». Refonte de RENDU uniquement — contrôleur, appels réseau,
// navigation et conditions d'affichage sont strictement identiques.
//
// Ce qui change :
//   · plus AUCUNE image de couverture en pleine largeur : le visuel marketing
//     qui servait de repli quand le gardien n'a pas de photo a disparu, l'en-tête
//     est un bandeau dégradé bleu gardien + un avatar cerclé de blanc (initiale
//     si pas de photo) ;
//   · la carte « Détails de la réservation » ne s'affiche PLUS quand il n'y a
//     pas de réservation liée (avant : une ligne vide, puis « Statut actuel :
//     DISPONIBLE » ET « Statut de la demande : Disponible » — deux pastilles de
//     styles différents pour la même information). Une seule pastille de statut
//     est visible à la fois : la disponibilité dans l'en-tête sans réservation,
//     la pastille `BookingStatusChip` dans la carte avec réservation ;
//   · toutes les sections sont des cartes (coins 20) avec une icône Material
//     ronde teintée ; les sections vides affichent une ligne discrète DANS la
//     carte au lieu de trois gros blocs de vide ;
//   · « Démarrer le chat » devient l'action principale d'une barre collante en
//     bas (dégagement `appBottomInset`, barre Samsung) au lieu d'un gros bouton
//     au milieu de la page ; partage et signalement restent en haut à droite,
//     en boutons ronds translucides sur le bandeau.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_detail_controller.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/views/guest/signup_wall_sheet.dart';
import 'package:hopetsit/views/map/pawmap_rates.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';
import 'package:hopetsit/views/service_provider/widgets/provider_action_bar.dart';
import 'package:hopetsit/views/service_provider/widgets/book_as_owner.dart';
import 'package:hopetsit/services/self_profiles_service.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/reviews/widgets/rating_stars.dart';
import 'package:hopetsit/views/service_provider/widgets/public_profile_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/report_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

class Review {
  final String reviewerName;
  final String reviewerImage;
  final double rating;
  final String reviewText;

  Review({
    required this.reviewerName,
    required this.reviewerImage,
    required this.rating,
    required this.reviewText,
  });
}

class ServiceProviderDetailScreen extends StatelessWidget {
  final String sitterId;
  final String status;
  final BookingModel? booking;

  const ServiceProviderDetailScreen({
    super.key,
    required this.sitterId,
    required this.status,
    this.booking,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SitterDetailController(sitterId: sitterId));
    // v586 (point 8) — ids de mes profils (reconnaître ma propre fiche).
    SelfProfiles.refresh();

    return _ServiceProviderDetailContent(
      controller: controller,
      sitterId: sitterId,
      status: status,
      booking: booking,
    );
  }
}

class _ServiceProviderDetailContent extends StatelessWidget {
  final SitterDetailController controller;
  final String sitterId;
  final String status;
  final BookingModel? booking;

  const _ServiceProviderDetailContent({
    required this.controller,
    required this.sitterId,
    required this.status,
    this.booking,
  });

  static const PublicProfilePalette _palette = kSitterProfilePalette;

  /// Condition INCHANGÉE : une réservation / candidature est liée dès que le
  /// statut n'est pas un simple état de présence du gardien.
  bool get _hasBooking {
    final String s = status.toLowerCase();
    return s != 'available' && s != 'offline' && s != 'online';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: publicProfileAppBar(
        palette: _palette,
        title: Obx(
          () => PoppinsText(
            text: controller.sitter.value?.name ??
                'sitter_detail_loading_name'.tr,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: <Widget>[
          // v531 — retour testeur US : « I can't find a way to share or
          // forward to friends ». Partage du profil prestataire via la
          // feuille native (WhatsApp, Instagram, SMS, email…).
          PublicProfileBannerAction(
            icon: Icons.ios_share_rounded,
            tooltip: 'post_action_share'.tr,
            onTap: () {
              try {
                final name = controller.sitter.value?.name ?? '';
                final safeName = name.isEmpty ? 'HoPetSit' : name;
                SharePlus.instance.share(ShareParams(
                  text: 'share_profile_body'.trParams({
                    'name': safeName,
                    'link': 'https://hopetsit.com/download',
                  }),
                  subject:
                      'share_profile_subject'.trParams({'name': safeName}),
                ));
              } catch (_) {
                // Un échec de partage ne doit jamais faire planter l'écran.
              }
            },
          ),
          PublicProfileBannerAction(
            icon: Icons.flag_outlined,
            tooltip: 'report_dialog_title'.tr,
            onTap: () {
              ReportDialog.show(
                context: context,
                targetType: 'profile',
                targetId: sitterId,
                snapshot: controller.sitter.value?.name ?? '',
              );
            },
          ),
        ],
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const PublicProfileSkeleton(palette: _palette);
          }

          final SitterModel? sitter = controller.sitter.value;
          if (sitter == null) {
            return PublicProfileErrorView(
              accent: _palette.accent,
              message: controller.errorMessage.value ??
                  'sitter_detail_load_error'.tr,
            );
          }

          return Column(
            children: <Widget>[
              Expanded(
                child: PublicProfileBackground(
                  accent: _palette.accent,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: publicProfileBottomPadding(
                        context,
                        hasActionBar: true,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildHero(context, sitter),
                        SizedBox(height: 18.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _buildStats(context, sitter),
                              SizedBox(height: 14.h),
                              if (_hasBooking) ...<Widget>[
                                _buildBookingCard(context),
                                SizedBox(height: 14.h),
                              ],
                              _buildRatesCard(context, sitter),
                              SizedBox(height: 14.h),
                              _buildAboutCard(context, sitter),
                              SizedBox(height: 14.h),
                              _buildSkillsCard(context, sitter),
                              ..._buildServicesCard(context, sitter),
                              SizedBox(height: 14.h),
                              _buildReviewsCard(context, sitter),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // v584 (25/09, point 8) — Réserver · dès X €/j EN PREMIER,
              // le chat en second (rond). Même parcours de réservation que
              // depuis l'épingle de la carte (SendRequestScreen pré-rempli).
              // v586 (point 8, Daniel) — Réserver pour TOUS les spectateurs
              // (gardien / promeneur : avec leur profil propriétaire) ; seule
              // exception : sa propre fiche, sans barre d'action.
              Obx(() {
                if (SelfProfiles.isMe(sitterId) || SelfProfiles.isMe(sitter.id)) {
                  return const SizedBox.shrink(key: ValueKey<String>('provider_self_no_actions'));
                }
                final paymentStatus = booking?.paymentStatus?.toLowerCase().trim();
                final bool isLocked = booking != null && paymentStatus != 'paid';
                return ProviderActionBar(
                  role: 'sitter',
                  rates: _ratesOf(sitter),
                  messageLocked: isLocked,
                  messageLoading: controller.isStartingChat.value,
                  onBook: () => _book(context, sitter),
                  onMessage: () => _message(context, controller, sitter),
                );
              }),
            ],
          );
        }),
      ),
        ),
    );
  }

  // ───────────────────────────── En-tête ─────────────────────────────

  Widget _buildHero(BuildContext context, SitterModel sitter) {
    return PublicProfileHero(
      palette: _palette,
      role: 'sitter',
      name: sitter.name,
      imageUrl: sitter.avatar.url,
      // v23.1 part 251 — badge KYC only (flag legacy verified retiré).
      verified: sitter.identityVerified,
      // Une SEULE pastille de statut : sans réservation liée on montre la
      // disponibilité ici, sinon c'est la carte « réservation » qui l'affiche.
      statusChip: _hasBooking ? null : _availabilityPill(context),
      location: sitter.displayCity,
      // v565 (point 38) — étoiles modernes, « Nouveau » sans avis.
      rating: RatingStars(
        rating: sitter.rating,
        reviewsCount: sitter.reviewsCount,
        size: 16,
      ),
    );
  }

  Widget _availabilityPill(BuildContext context) {
    final String s = status.toLowerCase();
    final bool online = s == 'available' || s == 'online';
    return PublicProfileStatusPill(
      icon: online ? Icons.check_circle_rounded : Icons.circle_outlined,
      label: _localizedStatusLabel(status),
      tone: online ? const Color(0xFF16A34A) : AppColors.greyColor,
    );
  }

  // ───────────────────────────── Statistiques ─────────────────────────

  Widget _buildStats(BuildContext context, SitterModel sitter) {
    return PublicProfileStatsRow(
      accent: _palette.accent,
      stats: <PublicProfileStat>[
        PublicProfileStat(
          icon: Icons.star_rounded,
          value: sitter.rating > 0 ? sitter.rating.toStringAsFixed(1) : '—',
          label: 'profiles573_stat_rating'.tr,
        ),
        PublicProfileStat(
          icon: Icons.reviews_rounded,
          value: '${sitter.reviewsCount}',
          label: 'profiles573_stat_reviews'.tr,
        ),
        PublicProfileStat(
          icon: Icons.verified_user_rounded,
          value: '${sitter.completedServicesCount}',
          label: 'profiles573_stat_services'.tr,
        ),
      ],
    );
  }

  // ───────────────────────────── Sections ─────────────────────────────

  /// Carte « Détails de la réservation » — affichée UNIQUEMENT quand une
  /// réservation / candidature est liée, avec UNE seule pastille de statut.
  Widget _buildBookingCard(BuildContext context) {
    return PublicProfileSection(
      accent: _palette.accent,
      icon: Icons.event_note_rounded,
      title: 'sitter_detail_booking_details_title'.tr,
      child: Row(
        children: <Widget>[
          Expanded(
            child: InterText(
              text: 'sitter_detail_application_status_label'.tr,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryStrong(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10.w),
          Flexible(
            child: BookingStatusChip(
              status: status,
              paymentStatus: booking?.paymentStatus,
              accent: _palette.accent,
            ),
          ),
        ],
      ),
    );
  }

  /// v584 (25/09, point 8) — tarifs COMPLETS dans SA devise (heure / jour /
  /// semaine / mois + animal supplémentaire), lignes vides jamais affichées.
  PawProviderRates _ratesOf(SitterModel sitter) => PawProviderRates(
        currency: sitter.currency.isEmpty ? 'EUR' : sitter.currency,
        role: 'sitter',
        hourly: sitter.hourlyRate > 0 ? sitter.hourlyRate : null,
        daily: sitter.dailyRate > 0 ? sitter.dailyRate : null,
        weekly: sitter.weeklyRate > 0 ? sitter.weeklyRate : null,
        monthly: sitter.monthlyRate > 0 ? sitter.monthlyRate : null,
        extraPet: sitter.extraPetRate > 0 ? sitter.extraPetRate : null,
      );

  /// v586 (point 8) — Message : propriétaire → conversation directe (inchangé) ;
  /// gardien / promeneur → avec son profil propriétaire (le serveur réserve
  /// `/conversations/start` aux propriétaires).
  void _message(BuildContext context, SitterDetailController controller, SitterModel sitter) {
    if ((SecureTokenStore.currentToken() ?? '').isEmpty) {
      SignupWallSheet.show(trigger: 'booking', name: sitter.name, recommendedRole: 'pet_owner');
      return;
    }
    final String role = viewerRoleNow();
    if (role.isEmpty || role == 'owner') {
      _handleStartChat(controller, sitter.id, sitter.name, sitter.avatar.url);
      return;
    }
    runAsOwner(
      context,
      providerName: sitter.name,
      forMessage: true,
      then: () => openOwnerChatWithProvider(
        providerId: sitter.id,
        providerRole: 'sitter',
        providerName: sitter.name,
        providerAvatar: sitter.avatar.url,
      ),
    );
  }

  void _book(BuildContext context, SitterModel sitter) {
    if ((SecureTokenStore.currentToken() ?? '').isEmpty) {
      SignupWallSheet.show(trigger: 'booking', name: sitter.name, recommendedRole: 'pet_owner');
      return;
    }
    final r = _ratesOf(sitter);
    // v586 (point 8) — gardien / promeneur : bascule vers le profil
    // propriétaire d'abord (dialogue maison), puis MÊME écran pré-rempli.
    runAsOwner(context, providerName: sitter.name, forMessage: false, then: () => Get.to(() => SendRequestScreen(
          serviceProviderName: sitter.name,
          serviceProviderId: sitter.id,
          serviceProviderRole: 'sitter',
          sitterDailyRate: r.daily,
          sitterWeeklyRate: r.weekly,
          sitterMonthlyRate: r.monthly,
          currencyCode: r.currency,
          initialServiceType: 'pet_sitting',
          preselectFirstPet: true,
        )));
  }

  Widget _buildRatesCard(BuildContext context, SitterModel sitter) {
    final List<Widget> rows = <Widget>[
      for (final line in _ratesOf(sitter).lines)
        PublicProfileRateRow(
          label: line.label,
          value: line.value,
          accent: _palette.accent,
        ),
    ];

    return PublicProfileSection(
      accent: _palette.accent,
      icon: Icons.payments_rounded,
      title: 'pawmap_rates_title'.tr,
      child: rows.isEmpty
          ? PublicProfileEmptyLine(
              icon: Icons.payments_outlined,
              text: 'profiles573_no_rates'.tr,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
    );
  }



  Widget _buildAboutCard(BuildContext context, SitterModel sitter) {
    final String bio = (sitter.bio ?? '').trim();
    return PublicProfileSection(
      accent: _palette.accent,
      icon: Icons.person_rounded,
      title: 'sitter_detail_about_title'.trParams({'name': sitter.name}),
      child: bio.isNotEmpty
          ? PublicProfileBody(text: bio)
          : PublicProfileEmptyLine(
              icon: Icons.notes_rounded,
              text: 'sitter_detail_no_bio'.tr,
            ),
    );
  }

  Widget _buildSkillsCard(BuildContext context, SitterModel sitter) {
    final List<String> skills = sitter.skillsList
        .where((String s) => s.trim().isNotEmpty)
        .toList();
    return PublicProfileSection(
      accent: _palette.accent,
      icon: Icons.workspace_premium_rounded,
      title: 'sitter_detail_skills_title'.tr,
      child: skills.isEmpty
          ? PublicProfileEmptyLine(
              icon: Icons.school_outlined,
              text: 'sitter_detail_no_skills'.tr,
            )
          : Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: skills
                  .map<Widget>((String s) =>
                      PublicProfileTag(label: s, accent: _palette.accent))
                  .toList(),
            ),
    );
  }

  /// v23.1 — services proposés + animaux acceptés. Condition INCHANGÉE : la
  /// section entière disparaît quand les deux listes sont vides.
  List<Widget> _buildServicesCard(BuildContext context, SitterModel sitter) {
    final List<String> services =
        sitter.service.where((String s) => s.trim().isNotEmpty).toList();
    final List<String> petTypes =
        sitter.acceptedPetTypes.where((String p) => p.trim().isNotEmpty).toList();
    if (services.isEmpty && petTypes.isEmpty) return const <Widget>[];

    return <Widget>[
      SizedBox(height: 14.h),
      PublicProfileSection(
        accent: _palette.accent,
        icon: Icons.work_rounded,
        title: 'signup_services_offered'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (services.isNotEmpty)
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: services
                    .map<Widget>((String s) => PublicProfileTag(
                          label: translateServiceType(s),
                          accent: _palette.accent,
                        ))
                    .toList(),
              ),
            if (petTypes.isNotEmpty) ...<Widget>[
              if (services.isNotEmpty) SizedBox(height: 14.h),
              InterText(
                text: 'signup_animals_accepted'.tr,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: petTypes
                    .map<Widget>((String p) => PublicProfileTag(
                          label: _petTypeLabel(p),
                          accent: _palette.accent,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // Mappe un code espèce (dog/cat/small/nac/bird) vers son libellé i18n, avec
  // repli humanisé si le code est inconnu (jamais de clé brute à l'écran).
  String _petTypeLabel(String code) {
    final normalized = code.trim().toLowerCase();
    final key = 'pet_type_$normalized';
    final translated = key.tr;
    if (translated != key) return translated;
    if (normalized.isEmpty) return code;
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  Widget _buildReviewsCard(BuildContext context, SitterModel sitter) {
    final List<dynamic> reviews = sitter.reviews;
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
    final Map<dynamic, dynamic> map =
        review is Map ? review : const <dynamic, dynamic>{};
    final Map<dynamic, dynamic> reviewer = map['reviewer'] is Map
        ? map['reviewer'] as Map<dynamic, dynamic>
        : const <dynamic, dynamic>{};
    final String name = asStr(reviewer['name']).trim().isNotEmpty
        ? asStr(reviewer['name']).trim()
        : 'sitter_detail_anonymous_reviewer'.tr;
    final String image = asStr(map['reviewerImage']).trim().isNotEmpty
        ? asStr(map['reviewerImage']).trim()
        : asStr(reviewer['avatar']).trim();
    final double rating = (map['rating'] as num?)?.toDouble() ?? 0.0;

    return PublicProfileReviewCard(
      name: name,
      imageUrl: image,
      rating: rating,
      comment: asStr(map['comment']),
      date: _reviewDate(context, map['createdAt']),
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

  // ───────────────────────── Barre d'action ──────────────────────────

  Future<void> _handleStartChat(
    SitterDetailController controller,
    String sitterId,
    String sitterName,
    String sitterImage,
  ) async {
    try {
      controller.isStartingChat.value = true;

      final ownerRepository = Get.find<OwnerRepository>();
      final response = await ownerRepository.startConversation(
        sitterId: sitterId,
      );

      // Extract conversation ID and sitter info from response
      final conversation = response['conversation'] as Map<String, dynamic>?;
      final conversationId = conversation?['id'] as String? ?? '';

      if (conversationId.isEmpty) {
        throw Exception('Conversation ID not found in response');
      }

      // Extract sitter name and image from API response if available
      String finalSitterName = sitterName;
      String finalSitterImage = sitterImage.isNotEmpty ? sitterImage : '';

      if (conversation != null) {
        // Try to get sitter info from conversation object
        final sitterData = conversation['sitter'] as Map<String, dynamic>?;
        if (sitterData != null) {
          finalSitterName = sitterData['name']?.toString() ?? sitterName;

          // Extract sitter avatar
          if (sitterData['avatar'] != null) {
            if (sitterData['avatar'] is String) {
              finalSitterImage = sitterData['avatar'] as String;
            } else if (sitterData['avatar'] is Map &&
                sitterData['avatar']['url'] != null) {
              finalSitterImage = sitterData['avatar']['url'] as String;
            }
          }
        }
      }

      // Navigate to chat screen
      Get.to(
        () => IndividualChatScreen(
          conversationId: conversationId,
          contactName: finalSitterName,
          contactImage: finalSitterImage.isNotEmpty ? finalSitterImage : '',
        ),
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to start conversation', error: error.message);
      // v18.9.2 — les 404/500 backend affichent désormais une erreur
      // générique traduite. Les 402 chat-access gardent le path upsell.
      final m = error.message.toLowerCase();
      final isNotFound = m.contains('not found');
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: isNotFound ? 'common_error_message'.tr : error.message,
      );
    } catch (error) {
      AppLogger.logError('Failed to start conversation', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'sitter_detail_start_chat_failed'.tr,
      );
    } finally {
      controller.isStartingChat.value = false;
    }
  }

  String _localizedStatusLabel(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'available':
      case 'online':
        return 'status_available_label'.tr;
      case 'cancelled':
        return 'status_cancelled_label'.tr;
      case 'rejected':
        return 'status_rejected_label'.tr;
      case 'pending':
        return 'status_pending_label'.tr;
      case 'agreed':
        return 'status_agreed_label'.tr;
      case 'paid':
        return 'status_paid_label'.tr;
      case 'accepted':
        return 'status_accepted_label'.tr;
      default:
        if (status.isEmpty) return status;
        return status[0].toUpperCase() + status.substring(1);
    }
  }
}
