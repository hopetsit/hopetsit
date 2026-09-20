// v565 — Daniel (18/09, captures des 3 en-têtes de profil) : « les trois
// cadres : modernise, garde les couleurs du service mais égalise, modernise et
// fais tout plus beau, même le compteur d'abonnement ».
//
// Un SEUL widget [ProfileHero] pour les 3 écrans de profil (owner / sitter /
// walker) : exactement la même structure, seule la couleur du dégradé change.
//   1. rangée du haut : chip de rôle en verre (logo + libellé), badge KYC
//      (prestataires), cloche en verre avec badge rouge (ProfileNotificationBell)
//   2. avatar rond 96 à anneau blanc + bouton caméra du rôle ; nom Poppins 26 ;
//      pilule « ● Disponible · service » (prestataires, point vert/gris selon
//      la dispo RÉELLE du jour) ou pilule animal principal (propriétaire,
//      tap → fiche animal, « + Ajouter un animal » s'il n'y en a pas)
//   3. badges d'abonnement redessinés (ActiveBenefitsRow en mode hero)
//   4. rangée de 3 statistiques en tuiles de verre, toutes cliquables.
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/my_pets_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/views/booking/bookings_history_screen.dart';
import 'package:hopetsit/views/pet_sitter/booking/sitter_bookings_screen.dart';
import 'package:hopetsit/views/pet_walker/booking/walker_bookings_screen.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/pet_profile_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_notification_bell.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/my_kyc_verified_badge.dart';


class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.role,
    required this.userName,
    required this.profileImageUrl,
    required this.profile,
    required this.onCamera,
    this.isUploadingImage,
  });

  /// 'owner' | 'sitter' | 'walker'.
  final String role;
  final RxString userName;
  final RxString profileImageUrl;
  final Rxn<ProfileModel> profile;
  /// Caméra = changer la photo (fonction conservée telle quelle par écran).
  final VoidCallback onCamera;
  /// Spinner pendant l'envoi de la photo (le contrôleur sitter n'en a pas).
  final RxBool? isUploadingImage;

  bool get _isOwner => role == 'owner';

  // ── Palette par rôle (dégradés imposés) ────────────────────────────────
  List<Color> get _gradient {
    switch (role) {
      case 'sitter':
        return const [Color(0xFF2563EB), Color(0xFF3B82F6)];
      case 'walker':
        return const [Color(0xFF16A34A), Color(0xFF22C55E)];
      default:
        return const [Color(0xFFC92A12), Color(0xFFE24E2E)];
    }
  }

  Color get _accent => _gradient.first;

  String get _roleLabel {
    switch (role) {
      case 'sitter':
        return 'role_pet_sitter'.tr;
      case 'walker':
        return 'role_pet_walker'.tr;
      default:
        return 'role_pet_owner'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34.r)),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          _paw(right: -26.w, top: -24.h, size: 150.sp, angle: 0.31, alpha: 0.10),
          _paw(left: -18.w, bottom: 26.h, size: 84.sp, angle: -0.42, alpha: 0.07),
          _decoCircle(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 18.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // (1) rangée du haut : chip rôle · KYC · cloche
                  Row(
                    children: [
                      _roleChip(),
                      if (!_isOwner) ...[
                        SizedBox(width: 8.w),
                        const MyKycVerifiedBadge(large: true),
                      ],
                      const Spacer(),
                      ProfileNotificationBell(role: role),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // (2) avatar + nom + pilule
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _avatar(),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Obx(() => PoppinsText(
                                  text: userName.value.isEmpty
                                      ? _roleLabel
                                      : userName.value,
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )),
                            SizedBox(height: 8.h),
                            _isOwner
                                ? _OwnerPetPill(accent: _accent)
                                : _AvailabilityPill(role: role, profile: profile),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // (3) badges d'abonnement (mode hero)
                  const ActiveBenefitsRow(hero: true),
                  SizedBox(height: 10.h),
                  // (4) 3 statistiques
                  _isOwner ? _ownerStats() : _providerStats(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Décor ────────────────────────────────────────────────────────────
  Widget _paw({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double size,
    required double angle,
    required double alpha,
  }) =>
      Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: angle,
            child: Text(
              '🐾',
              style: TextStyle(
                fontSize: size,
                color: Colors.white.withValues(alpha: alpha),
              ),
            ),
          ),
        ),
      );

  Widget _decoCircle() => Positioned(
        left: -34.w,
        bottom: -56.h,
        child: IgnorePointer(
          child: Container(
            width: 150.w,
            height: 150.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
        ),
      );

  /// Chip « verre » : logo de l'app + libellé du rôle, coins 999.
  Widget _roleChip() => Container(
        padding: EdgeInsets.fromLTRB(6.w, 5.h, 13.w, 5.h),
        decoration: _glass(radius: 999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Image.asset('assets/brand/png/ic_launcher.png',
                  width: 22.w, height: 22.w, fit: BoxFit.cover),
            ),
            SizedBox(width: 8.w),
            InterText(
              text: _roleLabel,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  /// Avatar rond 96 à anneau blanc + bouton caméra du rôle.
  Widget _avatar() {
    final double size = 96.w;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Obx(() {
          final url = profileImageUrl.value;
          final uploading = isUploadingImage?.value ?? false;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: uploading
                  ? Center(
                      child: SizedBox(
                        width: 26.w,
                        height: 26.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : url.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          placeholder: (_, __) => _avatarFallback(),
                          errorWidget: (_, __, ___) => _avatarFallback(),
                        )
                      : _avatarFallback(),
            ),
          );
        }),
        Positioned(
          bottom: -2,
          right: -2,
          child: GestureDetector(
            onTap: onCamera,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.camera_alt_rounded, size: 15.sp, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback() => Center(
        child: Icon(
          role == 'walker'
              ? Icons.directions_walk_rounded
              : Icons.person_rounded,
          size: 46.sp,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      );

  // ── Statistiques ─────────────────────────────────────────────────────
  Widget _providerStats() {
    return Row(
      children: [
        // Jours actifs (depuis createdAt) → calendrier de disponibilités.
        Obx(() {
          final created = profile.value?.createdAt;
          final days = _daysActive(created);
          return _StatTile(
            label: 'hero_stat_days'.tr,
            value: days == null ? '—' : '$days',
            onTap: () => Get.to(() => AvailabilityCalendarScreen(
                  role: role == 'walker' ? 'walker' : null,
                )),
          );
        }),
        SizedBox(width: 8.w),
        // Note : étoiles + moyenne, « Nouveau » si aucun avis → Mes avis.
        Obx(() {
          final p = profile.value;
          final count = p?.reviewsCount ?? 0;
          double avg = p?.rating ?? 0;
          if (avg <= 0) avg = p?.averageRating ?? 0;
          final isNew = count <= 0 && avg <= 0;
          return _StatTile(
            label: 'hero_stat_rating'.tr,
            value: isNew ? 'hero_rating_new'.tr : avg.toStringAsFixed(1),
            leading: isNew ? null : _Stars(rating: avg),
            onTap: () => openMyReviews(role: role, accent: _accent),
          );
        }),
        SizedBox(width: 8.w),
        // Réservations terminées → onglet Réservations.
        _CompletedBookingsTile(role: role, profile: profile),
      ],
    );
  }

  Widget _ownerStats() {
    final petsCtl = Get.isRegistered<MyPetsController>()
        ? Get.find<MyPetsController>()
        : Get.put(MyPetsController());
    final friendsCtl = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController(), permanent: true);
    return Row(
      children: [
        Obx(() => _StatTile(
              label: 'hero_stat_pets'.tr,
              value: '${petsCtl.pets.length}',
              onTap: () => Get.to(() => const MyPetsScreen()),
            )),
        SizedBox(width: 8.w),
        _CompletedBookingsTile(role: role, profile: profile),
        SizedBox(width: 8.w),
        Obx(() {
          final n = friendsCtl.friends
              .where((f) => f.status.toLowerCase() == 'accepted')
              .length;
          return _StatTile(
            label: 'hero_stat_friends'.tr,
            value: '$n',
            onTap: () => Get.to(() => const FriendsScreen()),
          );
        }),
      ],
    );
  }

  static BoxDecoration _glass({double radius = 16}) => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      );
}

/// Jours actifs réels depuis l'inscription ; `null` si la date est inconnue
/// (on affiche « — » plutôt qu'un faux 0).
int? _daysActive(String? createdAt) {
  if (createdAt == null || createdAt.trim().isEmpty) return null;
  final d = DateTime.tryParse(createdAt);
  if (d == null) return null;
  final n = DateTime.now().difference(d).inDays;
  return n < 0 ? 0 : n;
}

bool _isCompleted(BookingModel b) {
  final s = b.status.toLowerCase();
  return s == 'completed' || b.confirmationStatus == 'confirmed';
}

/// Tuile « Réservations » (terminées) : lit le contrôleur de réservations du
/// rôle s'il est monté (il l'est en permanence dans les 3 barres de
/// navigation), sinon le compteur serveur du profil. Tap → onglet Réservations.
class _CompletedBookingsTile extends StatelessWidget {
  const _CompletedBookingsTile({required this.role, required this.profile});
  final String role;
  final Rxn<ProfileModel> profile;

  @override
  Widget build(BuildContext context) {
    RxList<BookingModel>? list;
    if (role == 'sitter' && Get.isRegistered<SitterBookingsController>()) {
      list = Get.find<SitterBookingsController>().bookings;
    } else if (role == 'walker' && Get.isRegistered<WalkerBookingsController>()) {
      list = Get.find<WalkerBookingsController>().bookings;
    } else if (role == 'owner' && Get.isRegistered<BookingsController>()) {
      list = Get.find<BookingsController>().bookings;
    }
    return Obx(() {
      int? n;
      if (list != null) {
        n = list.where(_isCompleted).length;
      } else {
        final p = profile.value;
        if (p != null) {
          n = role == 'owner' ? p.stats.bookingsCount : p.completedServicesCount;
        }
      }
      return _StatTile(
        label: 'hero_stat_bookings'.tr,
        value: n == null ? '—' : '$n',
        // Daniel (18/09) : « après Réservations, pas de retour vers mon
        // profil » → on POUSSE l'écran (flèche retour) au lieu de changer
        // d'onglet.
        onTap: () {
          if (role == 'sitter') {
            openMainTabOr(3, () => const SitterBookingsScreen());
          } else if (role == 'walker') {
            openMainTabOr(3, () => const WalkerBookingsScreen());
          } else {
            Get.to(() => const BookingsHistoryScreen());
          }
        },
      );
    });
  }
}

/// Tuile de verre : valeur (précédée d'un éventuel widget) + libellé.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
  });
  final String label;
  final String value;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
          decoration: ProfileHero._glass(radius: 16.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24.h,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        SizedBox(width: 4.w),
                      ],
                      InterText(
                        text: value,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 3.h),
              InterText(
                text: label,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.80),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 5 petites étoiles remplies selon la moyenne (demi-étoile gérée).
class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final IconData icon = rating >= i + 1
            ? Icons.star_rounded
            : (rating >= i + 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded);
        return Icon(icon, size: 11.sp, color: const Color(0xFFFFCB2E));
      }),
    );
  }
}

/// Pilule « ● Disponible · service » des prestataires. Le point est vert si
/// le prestataire est disponible AUJOURD'HUI : la date du jour n'est pas dans
/// `unavailableDates` (GET /sitters|walkers/me/availability, même route que le
/// calendrier) et, pour un promeneur avec des jours déclarés, le jour de la
/// semaine en fait partie. Gris sinon.
class _AvailabilityPill extends StatefulWidget {
  const _AvailabilityPill({required this.role, required this.profile});
  final String role;
  final Rxn<ProfileModel> profile;

  @override
  State<_AvailabilityPill> createState() => _AvailabilityPillState();
}

class _AvailabilityPillState extends State<_AvailabilityPill> {
  bool? _blockedToday; // null = inconnu (réseau) → on suppose disponible

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final base = widget.role == 'walker' ? '/walkers' : '/sitters';
      final resp = await Get.find<ApiClient>()
          .get('$base/me/availability', requiresAuth: true);
      if (!mounted || resp is! Map) return;
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);
      final blocked = ((resp['unavailableDates'] as List?) ?? const [])
          .map((e) => DateTime.tryParse(e.toString()))
          .whereType<DateTime>()
          .any((d) => DateTime.utc(d.year, d.month, d.day) == today);
      setState(() => _blockedToday = blocked);
    } catch (_) {
      // best-effort : on garde l'état « inconnu ».
    }
  }

  static const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  Widget build(BuildContext context) {
    final service = widget.role == 'walker'
        ? 'hero_service_walk'.tr
        : 'hero_service_sit'.tr;
    return Obx(() {
      final days = widget.profile.value?.availableDays ?? const <String>[];
      final todayKey = _dayKeys[DateTime.now().weekday - 1];
      final dayOk = days.isEmpty ||
          days.any((d) => d.toLowerCase().startsWith(todayKey));
      final available = dayOk && _blockedToday != true;
      final label = available
          ? 'hero_status_available'.tr
          : 'hero_status_unavailable'.tr;
      return _HeroPill(
        leading: Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: available ? const Color(0xFF4ADE80) : const Color(0xFFCBD5E1),
            shape: BoxShape.circle,
            boxShadow: available
                ? [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.7),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
        ),
        text: '$label · $service',
      );
    });
  }
}

/// Pilule animal principal du propriétaire : « 🐶 Rex · Golden Retriever »
/// (tap → fiche animal ; « +N » si d'autres animaux), ou « + Ajouter un animal ».
class _OwnerPetPill extends StatelessWidget {
  const _OwnerPetPill({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final petsCtl = Get.isRegistered<MyPetsController>()
        ? Get.find<MyPetsController>()
        : Get.put(MyPetsController());
    return Obx(() {
      final pets = petsCtl.pets;
      if (pets.isEmpty) {
        return _HeroPill(
          leading: Icon(Icons.add_rounded, size: 14.sp, color: Colors.white),
          text: 'hero_add_pet'.tr,
          onTap: () => Get.to(() => const MyPetsScreen()),
        );
      }
      final PetModel p = pets.first;
      final extra = pets.length > 1 ? '  +${pets.length - 1}' : '';
      final breed = p.breed.trim();
      final text = breed.isEmpty ? '${p.petName}$extra' : '${p.petName} · $breed$extra';
      return _HeroPill(
        leading: p.avatar.url.isNotEmpty
            ? CircleAvatar(
                radius: 9.r,
                backgroundColor: Colors.white24,
                backgroundImage: CachedNetworkImageProvider(p.avatar.url),
              )
            : Text(petSpeciesEmoji(p.category), style: TextStyle(fontSize: 12.sp)),
        text: text,
        onTap: () => Get.to(() => PetProfileScreen(
              pet: p,
              accent: petSpeciesColor(p.category),
            )),
      );
    });
  }
}

/// Pilule de verre commune (statut prestataire / animal propriétaire).
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.leading, required this.text, this.onTap});
  final Widget leading;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(10.w, 5.h, 12.w, 5.h),
        decoration: ProfileHero._glass(radius: 999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            SizedBox(width: 7.w),
            Flexible(
              child: InterText(
                text: text,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: 4.w),
              Icon(Icons.chevron_right_rounded,
                  size: 14.sp, color: Colors.white.withValues(alpha: 0.85)),
            ],
          ],
        ),
      ),
    );
  }
}
