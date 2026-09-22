// v569 — « Accord de réservation » : modernisation + branchement vérifié.
//
// Défauts corrigés (capture Daniel, build 568) :
//  1. « 4 Sep 2026 » en anglais alors que l'app est en français. CAUSE RACINE :
//     `_formatBookingDate()` contenait une table de mois EN CODÉE EN DUR
//     (['Jan','Feb',…]) — aucune locale n'était consultée. Remplacé par
//     `DateFormat.yMMMd(Get.locale?.toLanguageTag())` (main.dart initialise
//     déjà les symboles des 9 langues et `Intl.defaultLocale`).
//  2. « Palier tarifaire → hourly » : la valeur TECHNIQUE du backend
//     (`pricing.pricingTier` ∈ hourly | daily | weekly | monthly, cf.
//     `backend/src/utils/tierPricing.js` + `models/Booking.js`) était affichée
//     brute. Traduite via `agr569_tier_*`.
//  3. « Total heures 0.0 » : les heures s'affichaient même en facturation à la
//     journée / semaine / mois. Désormais heures SI tier = hourly, jours SINON,
//     et jamais une valeur nulle.
//  4. « Lieu du house sitting » (franglais) : clé `house_sitting_venue_label`
//     redéfinie dans `localization/v565/agreement569_i18n.dart` (les paquets
//     v565 priment sur `translations/*.dart`) → FR « Lieu de la garde ».
//
// Branchement / synchro :
//  - L'écran appelle TOUJOURS `GET /bookings/:id/agreement` (avant, passer
//    `totalPrice` court-circuitait l'appel : ni dates, ni palier, ni net).
//    `totalPrice` ne sert plus que de premier rendu instantané.
//  - Montants : on privilégie `pricing.totalPrice` / `pricing.currency`
//    renvoyés par le serveur — c'est EXACTEMENT ce que facture
//    `createBookingPaymentIntent` (`Number(booking.pricing.totalPrice)` +
//    `booking.pricing.currency`). Le calcul local base + 20 % ne reste qu'en
//    dernier recours. Aucune devise codée en dur.
//  - Le net prestataire est envoyé par la route d'accord sous le nom
//    `netToSitter` (et non `netAmount`/`netPayout`) : il n'était JAMAIS lu,
//    donc la ligne n'apparaissait jamais. Lu explicitement ici.
//  - Bouton « Payer » réservé au PROPRIÉTAIRE (le backend refuse déjà le
//    paiement à un prestataire : `canPay` exige `userId === ownerId`).
//  - Rafraîchissement : pull-to-refresh, retour au premier plan, et écoute des
//    événements socket `booking:paid` / `booking:accepted` / `booking:cancelled`
//    avec un handler NOMMÉ (un `off(event)` global casserait les listeners de
//    BookingsController / PostsController).
import 'package:hopetsit/widgets/role_chip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/loyalty_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_constants.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/payment/airwallex_payment_screen.dart';
import 'package:hopetsit/views/payment/paypal_payment_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/promo_code_sheet.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

class BookingAgreementScreen extends StatefulWidget {
  final BookingModel booking;
  final double? totalPrice; // Premier rendu : l'accord serveur reste la source.
  final String? viewerRole;

  const BookingAgreementScreen({
    super.key,
    required this.booking,
    this.totalPrice,
    this.viewerRole,
  });

  @override
  State<BookingAgreementScreen> createState() => _BookingAgreementScreenState();
}

class _BookingAgreementScreenState extends State<BookingAgreementScreen>
    with WidgetsBindingObserver {
  final OwnerRepository _ownerRepository = Get.find<OwnerRepository>();

  late BookingModel _booking = widget.booking;

  bool _isLoading = false;
  bool _isBusy = false; // action en cours (agree avant paiement)
  String _errorMessage = '';
  bool _descExpanded = false;

  double? _basePrice;
  double? _platformFee;
  double? _finalTotal;
  double? _netToProvider;
  String? _currency;
  String? _agreementStartDate;
  String? _agreementEndDate;
  String? _agreementHouseSittingVenue;
  bool? _serverCanPay;

  /// Walk duration from agreement API (minutes: 30 or 60).
  int? _agreementDurationMinutes;

  /// Parsed from agreement GET (includes tier, applied rate, hours/days).
  BookingPricing? _agreementPricing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyLocalFallback();
    // Réouverture de l'écran : on relit l'accord ET le statut (l'autre partie
    // a pu accepter / annuler pendant que la liste était en cache).
    _refreshAll();
    _bindSocket();
  }

  @override
  void dispose() {
    _unbindSocket();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour au premier plan : l'autre partie a pu accepter / annuler depuis
    // un autre appareil pendant ce temps.
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshAll(silent: true);
    }
  }

  // ───────────────────────────── socket ─────────────────────────────

  void _onBookingEvent(dynamic _) {
    if (!mounted) return;
    _refreshAll(silent: true);
  }

  void _bindSocket() {
    try {
      if (!Get.isRegistered<SocketService>()) return;
      final s = Get.find<SocketService>().socket;
      if (s == null) return;
      // Handler NOMMÉ → `off(event, handler)` ciblé au dispose : un
      // `off('booking:paid')` global retirerait les listeners de
      // BookingsController et PostsController qui partagent l'événement.
      for (final e in const [
        'booking:paid',
        'booking:accepted',
        'booking:cancelled',
        'booking:service-updated',
      ]) {
        s.off(e, _onBookingEvent);
        s.on(e, _onBookingEvent);
      }
    } catch (e) {
      AppLogger.logError('BookingAgreement socket bind failed', error: e);
    }
  }

  void _unbindSocket() {
    try {
      if (!Get.isRegistered<SocketService>()) return;
      final s = Get.find<SocketService>().socket;
      if (s == null) return;
      for (final e in const [
        'booking:paid',
        'booking:accepted',
        'booking:cancelled',
        'booking:service-updated',
      ]) {
        s.off(e, _onBookingEvent);
      }
    } catch (_) {
      /* best-effort */
    }
  }

  // ───────────────────────────── données ─────────────────────────────

  /// Valeurs immédiates issues de la réservation déjà en mémoire : l'écran
  /// n'est jamais vide le temps de l'appel réseau.
  void _applyLocalFallback() {
    final p = _booking.pricing;
    _agreementPricing ??= p;
    _basePrice = p?.basePrice ??
        p?.resolvedBaseAmount ??
        _booking.basePrice ??
        widget.totalPrice;
    final safeBase = _basePrice ?? 0.0;
    _platformFee = p?.platformFee ?? _calculatePlatformFee(safeBase);
    _finalTotal = p?.totalPrice ??
        _booking.totalAmount ??
        widget.totalPrice ??
        _calculateFinalTotal(safeBase, _platformFee ?? 0.0);
    _netToProvider = p?.netAmount;
    _currency = p?.currency ?? _booking.sitter.currency;
    _agreementHouseSittingVenue = _booking.houseSittingVenue;
    _agreementStartDate ??= _booking.date;
    _agreementEndDate ??= _booking.endDate;
  }

  Future<void> _refreshAll({bool silent = false}) async {
    await Future.wait<void>([
      _loadBookingAgreement(silent: silent),
      _refreshBookingStatus(),
    ]);
  }

  /// `GET /bookings/:id` → statut / paiement à jour (l'autre partie a pu
  /// accepter, payer ou annuler ailleurs). 404 = vieux backend → on garde.
  Future<void> _refreshBookingStatus() async {
    if (_booking.id.isEmpty) return;
    try {
      final fresh = await _ownerRepository.getBookingDetail(_booking.id);
      if (fresh == null || !mounted) return;
      setState(() {
        _booking = fresh;
        // La réservation passée par le parent est partagée avec l'écran
        // appelant : on garde son statut aligné (seul champ mutable).
        widget.booking.status = fresh.status;
      });
    } catch (e) {
      AppLogger.logError('Booking detail refresh failed', error: e);
    }
  }

  Future<void> _loadBookingAgreement({bool silent = false}) async {
    if (_booking.id.isEmpty) {
      _applyLocalFallback();
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }
    try {
      final response = await _ownerRepository.getBookingAgreement(
        bookingId: _booking.id,
      );

      // API : { "agreement": { "pricing": { … } } }.
      final agreementData =
          response['agreement'] as Map<String, dynamic>? ?? response;
      final pricing =
          agreementData['pricing'] as Map<String, dynamic>? ?? agreementData;

      double? num2(Map<String, dynamic> m, List<String> keys) {
        for (final k in keys) {
          final v = m[k];
          if (v is num) return v.toDouble();
        }
        return null;
      }

      _basePrice = num2(pricing, ['basePrice', 'base_price']) ??
          num2(agreementData, ['basePrice', 'base_price']) ??
          _booking.pricing?.basePrice ??
          _booking.basePrice ??
          _booking.sitter.hourlyRate;

      _platformFee = num2(pricing, ['platformFee', 'platform_fee']) ??
          num2(agreementData, ['platformFee', 'platform_fee']) ??
          _booking.pricing?.platformFee ??
          _calculatePlatformFee(_basePrice ?? 0);

      // Le montant RÉELLEMENT débité par le backend est
      // `booking.pricing.totalPrice` : il passe en premier.
      _finalTotal = num2(pricing, ['totalPrice', 'total_price', 'finalTotal']) ??
          num2(agreementData, ['totalAmount', 'total_amount']) ??
          _booking.pricing?.totalPrice ??
          _booking.totalAmount ??
          _calculateFinalTotal(_basePrice ?? 0, _platformFee ?? 0);

      // `netToSitter` = nom réel du champ dans la réponse d'accord
      // (bookingController.getBookingAgreement). `netAmount`/`netPayout`
      // gardés pour les autres chemins.
      _netToProvider =
          num2(pricing, ['netToSitter', 'net_to_sitter', 'netAmount', 'netPayout']) ??
              _booking.pricing?.netAmount;

      _currency = pricing['currency'] as String? ??
          agreementData['currency'] as String? ??
          _booking.pricing?.currency ??
          _booking.sitter.currency;
      _agreementStartDate = agreementData['startDate'] as String? ??
          agreementData['start_date'] as String? ??
          agreementData['serviceDate'] as String? ??
          _booking.date;
      _agreementEndDate = agreementData['endDate'] as String? ??
          agreementData['end_date'] as String? ??
          _booking.endDate;
      _agreementHouseSittingVenue =
          agreementData['houseSittingVenue'] as String? ??
              agreementData['house_sitting_venue'] as String? ??
              _booking.houseSittingVenue;
      _agreementDurationMinutes = (agreementData['duration'] as num?)?.toInt();
      final canPay = agreementData['canPay'];
      _serverCanPay = canPay is bool ? canPay : null;

      _agreementPricing = BookingPricing.fromJson(pricing);

      if (_basePrice == null || _basePrice! <= 0) {
        final fb = _agreementPricing?.resolvedBaseAmount ??
            _booking.pricing?.resolvedBaseAmount ??
            _booking.sitter.hourlyRate;
        if (fb > 0) {
          _basePrice = fb;
          _platformFee = _calculatePlatformFee(_basePrice!);
          _finalTotal = _calculateFinalTotal(_basePrice!, _platformFee!);
        }
      }
      _errorMessage = '';
    } on ApiException catch (e) {
      // v18.9.1 — pas de pop-up rouge quand le repli local donne déjà le bon
      // prix. L'erreur n'est montrée que si on n'a AUCUN montant à afficher.
      AppLogger.logError(
        'Failed to refresh booking agreement — silent fallback to booking.pricing',
        error: e,
      );
      _applyLocalFallback();
      _errorMessage = _hasAnyPrice ? '' : (e.message.isNotEmpty ? e.message : 'agr569_error_msg'.tr);
    } catch (e) {
      AppLogger.logError('Failed to load booking agreement', error: e);
      _applyLocalFallback();
      _errorMessage = _hasAnyPrice ? '' : 'agr569_error_msg'.tr;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _hasAnyPrice => (_finalTotal ?? 0) > 0 || (_basePrice ?? 0) > 0;

  double _calculatePlatformFee(double total) {
    // v18.9.8 — taux centralisé dans AppConstants. Source de vérité :
    // pricing.js côté backend.
    return total * AppConstants.platformCommissionRate;
  }

  double _calculateFinalTotal(double total, double platformFee) =>
      total + platformFee;

  // ───────────────────────────── rôle / statut ─────────────────────────────

  String get _viewerRole {
    final given = (widget.viewerRole ?? '').trim().toLowerCase();
    if (given.isNotEmpty) return given;
    try {
      if (Get.isRegistered<AuthController>()) {
        return (Get.find<AuthController>().userRole.value ?? 'owner')
            .toLowerCase();
      }
    } catch (_) {
      /* pas de session → owner par défaut */
    }
    return 'owner';
  }

  bool get _isOwnerView => _viewerRole != 'sitter' && _viewerRole != 'walker';

  String get _statusLower => _booking.status.toLowerCase().trim();
  String get _paymentStatusLower =>
      (_booking.paymentStatus ?? '').toLowerCase().trim();

  bool get _isPaid => _paymentStatusLower == 'paid' || _statusLower == 'paid';
  bool get _isCancelled => _statusLower == 'cancelled';
  bool get _isRejected => _statusLower == 'rejected';
  bool get _isCompleted => _statusLower == 'completed';

  /// Service commencé mais pas encore rendu / confirmé.
  bool get _isInProgress {
    if (!_isPaid || _isCompleted) return false;
    final h = _booking.handover;
    if (h != null && h.pickedUp && !h.returnConfirmed) return true;
    return _booking.serviceStartedAt != null && _booking.serviceEndedAt == null;
  }

  /// Le propriétaire peut payer : statut accepté/convenu + paiement non réglé.
  /// Le backend exige en plus `userId === ownerId` → on gate sur le rôle.
  bool get _canPay {
    if (!_isOwnerView) return false;
    if (_serverCanPay == false) return false;
    final okStatus = _statusLower == 'agreed' ||
        _statusLower == 'accepted' ||
        _statusLower == 'confirmed';
    final okPayment = _paymentStatusLower.isEmpty ||
        _paymentStatusLower == 'pending' ||
        _paymentStatusLower == 'failed';
    return okStatus && okPayment && !_isPaid;
  }

  BookingStatusStyle get _statusStyle {
    final base = BookingStatusStyle.resolve(
      _booking.status,
      paymentStatus: _booking.paymentStatus,
      accent: AppColors.roleAccent(_viewerRole),
    );
    // `booking_ui_kit` fusionne « refusée » avec « annulée » : ici l'écran de
    // détail doit les distinguer (une demande refusée n'est pas une
    // réservation annulée).
    if (_isRejected) {
      return BookingStatusStyle(
        base.color,
        'agr569_status_rejected'.tr,
        Icons.do_not_disturb_on_rounded,
      );
    }
    if (_isInProgress) {
      return BookingStatusStyle(
        const Color(0xFF2563EB),
        'agr569_status_in_progress'.tr,
        Icons.pets_rounded,
      );
    }
    return base;
  }

  String? get _statusBanner {
    if (_isCancelled) return 'agr569_banner_cancelled'.tr;
    if (_isRejected) return 'agr569_banner_rejected'.tr;
    if (_isPaid && !_isInProgress && !_isCompleted) {
      return 'agr569_banner_paid'.tr;
    }
    if (_canPay) return 'agr569_banner_awaiting_payment'.tr;
    if (_statusLower == 'pending') return 'agr569_banner_pending'.tr;
    return null;
  }

  // ───────────────────────────── formatage ─────────────────────────────

  static String? _localeTag() {
    try {
      return Get.locale?.toLanguageTag();
    } catch (_) {
      return null;
    }
  }

  /// v569 — CORRECTION du « 4 Sep 2026 » : plus aucune table de mois en dur.
  String _formatBookingDate(String rawDate) {
    final value = rawDate.trim();
    if (value.isEmpty) return '';
    try {
      final date = DateTime.parse(value).toLocal();
      return DateFormat.yMMMd(_localeTag()).format(date);
    } catch (_) {
      return rawDate;
    }
  }

  String _formatDateTime(String dateTimeString) {
    final value = dateTimeString.trim();
    if (value.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(value).toLocal();
      final tag = _localeTag();
      final time = DateFormat.Hm(tag).format(dateTime);
      final diff = DateTime.now().difference(dateTime);
      if (diff.inDays == 0) {
        return 'booking_agreement_today_at'.trParams({'time': time});
      }
      if (diff.inDays == 1) {
        return 'booking_agreement_yesterday_at'.trParams({'time': time});
      }
      return '${DateFormat.yMMMd(tag).format(dateTime)} '
          '${'booking_agreement_at'.tr} $time';
    } catch (_) {
      return dateTimeString;
    }
  }

  String _formatPrice(double price) => CurrencyHelper.format(
        _currency ?? _booking.pricing?.currency ?? _booking.sitter.currency,
        price,
      );

  /// v18.9.1 — 'dog_walking' → libellé traduit ; repli lisible sinon.
  String _localizedServiceType(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return raw;
    final key = 'send_request_service_$normalized';
    final translated = key.tr;
    if (translated != key) return translated;
    return normalized
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Palier de facturation du backend (`hourly | daily | weekly | monthly`).
  String? _localizedTier(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    switch (t) {
      case 'hourly':
        return 'agr569_tier_hourly'.tr;
      case 'daily':
        return 'agr569_tier_daily'.tr;
      case 'weekly':
        return 'agr569_tier_weekly'.tr;
      case 'monthly':
        return 'agr569_tier_monthly'.tr;
      default:
        return t.isEmpty ? null : t;
    }
  }

  String? _formattedRate(BookingPricing? p) {
    final rate = p?.appliedRate;
    if (rate == null || rate <= 0) return null;
    final value = _formatPrice(rate);
    switch ((p?.pricingTier ?? '').toLowerCase()) {
      case 'daily':
        return 'agr569_per_day'.trParams({'rate': value});
      case 'weekly':
        return 'agr569_per_week'.trParams({'rate': value});
      case 'monthly':
        return 'agr569_per_month'.trParams({'rate': value});
      case 'hourly':
        return 'agr569_per_hour'.trParams({'rate': value});
      default:
        return value;
    }
  }

  int? get _durationMinutesForDisplay {
    final v = _agreementDurationMinutes ?? _booking.duration;
    if (v == null || v <= 0) return null;
    return v;
  }

  /// Durée lisible : d'abord la durée explicite (promenade 30/60 min), sinon
  /// calculée depuis début/fin, sinon depuis les heures/jours du serveur.
  String? get _durationLabel {
    final minutes = _durationMinutesForDisplay;
    if (minutes != null && minutes < 60 * 12) {
      if (minutes < 60) {
        return 'agr569_minutes_count'.trParams({'n': '$minutes'});
      }
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (m == 0) return 'agr569_hours_count'.trParams({'n': '$h'});
      return 'agr569_hours_minutes'.trParams({'h': '$h', 'm': '$m'});
    }

    final start = _parse(_agreementStartDate);
    final end = _parse(_agreementEndDate);
    if (start != null && end != null && end.isAfter(start)) {
      final d = end.difference(start);
      if (d.inHours < 24) {
        final h = d.inHours;
        final m = d.inMinutes % 60;
        if (h == 0) return 'agr569_minutes_count'.trParams({'n': '$m'});
        if (m == 0) return 'agr569_hours_count'.trParams({'n': '$h'});
        return 'agr569_hours_minutes'.trParams({'h': '$h', 'm': '$m'});
      }
      final days = (d.inHours / 24).ceil();
      return days <= 1
          ? 'agr569_one_day'.tr
          : 'agr569_days_count'.trParams({'n': '$days'});
    }

    final p = _agreementPricing ?? _booking.pricing;
    final tier = (p?.pricingTier ?? '').toLowerCase();
    if (tier == 'hourly') {
      final hours = p?.totalHours;
      if (hours != null && hours > 0) {
        return 'agr569_hours_count'
            .trParams({'n': _trimNumber(hours)});
      }
      return null;
    }
    final days = p?.totalDays;
    if (days != null && days > 0) {
      return days <= 1
          ? 'agr569_one_day'.tr
          : 'agr569_days_count'.trParams({'n': days.toStringAsFixed(0)});
    }
    return null;
  }

  static DateTime? _parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim())?.toLocal();
  }

  static String _trimNumber(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  // ───────────────────────────── actions ─────────────────────────────

  /// Session v16.3b — le propriétaire passe la réservation en `agreed` si
  /// besoin (le backend refuse un payment intent sinon) puis ouvre la page de
  /// paiement. Montant et devise = ceux affichés = ceux facturés.
  Future<void> _agreeAndPayWithStripe(double finalTotal) async {
    if (_statusLower == 'accepted') {
      final ok = await _ensureAgreed();
      if (!ok) return;
    }
    if (!mounted) return;
    await Get.to(
      () => AirwallexPaymentScreen(
        booking: _booking,
        totalAmount: finalTotal,
        currency: _currency ??
            _booking.pricing?.currency ??
            _booking.sitter.currency,
      ),
    );
    if (mounted) await _refreshAll(silent: true);
  }

  Future<void> _agreeAndPayWithPaypal(double finalTotal) async {
    if (_statusLower == 'accepted') {
      final ok = await _ensureAgreed();
      if (!ok) return;
    }
    if (!mounted) return;
    await Get.to(
      () => PayPalPaymentScreen(
        booking: _booking,
        totalAmount: finalTotal,
        currency: _currency ??
            _booking.pricing?.currency ??
            _booking.sitter.currency,
      ),
    );
    if (mounted) await _refreshAll(silent: true);
  }

  /// `PUT /bookings/:id/agree`. Met le statut local à jour immédiatement.
  Future<bool> _ensureAgreed() async {
    try {
      setState(() => _isBusy = true);
      await _ownerRepository.agreeToBooking(bookingId: _booking.id);
      _booking.status = 'agreed';
      widget.booking.status = 'agreed';
      return true;
    } on ApiException catch (e) {
      AppLogger.logError('Failed to agree before payment', error: e.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.message.isNotEmpty ? e.message : 'common_error_generic'.tr,
      );
      return false;
    } catch (e) {
      AppLogger.logError('Failed to agree before payment', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.roleAccent(_viewerRole);
    final showSkeleton = _isLoading && !_hasAnyPrice;
    final showError = !_isLoading && _errorMessage.isNotEmpty && !_hasAnyPrice;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: accent),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'booking_agreement_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          IconButton(
            tooltip: 'agr569_refresh'.tr,
            onPressed: _isLoading ? null : () => _refreshAll(),
            icon: Icon(Icons.refresh_rounded,
                size: 20.sp, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: showSkeleton
          ? _AgreementSkeleton(accent: accent)
          : showError
              ? BookingErrorState(
                  message: _errorMessage,
                  onRetry: () => _refreshAll(),
                )
              : RefreshIndicator(
                  color: accent,
                  onRefresh: () => _refreshAll(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
                    children: [
                      if (_statusBanner != null) ...[
                        _buildStatusBanner(_statusBanner!),
                        SizedBox(height: 12.h),
                      ],
                      _buildHeaderCard(accent),
                      SizedBox(height: 12.h),
                      _buildDatesCard(accent),
                      SizedBox(height: 12.h),
                      _buildServiceCard(accent),
                      SizedBox(height: 12.h),
                      _buildPriceCard(accent),
                    ],
                  ),
                ),
        ),
      bottomNavigationBar: showSkeleton ? null : _buildActionBar(accent),
    );
  }

  // ── bandeau d'état ────────────────────────────────────────────────
  Widget _buildStatusBanner(String text) {
    final s = _statusStyle;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: s.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(s.icon, size: 18.sp, color: s.color),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: text,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: s.color,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── en-tête : avatar + nom de l'autre partie + pastille de statut ──
  Widget _buildHeaderCard(Color accent) {
    final other = _isOwnerView ? _booking.sitter.name : _booking.owner.name;
    final avatarUrl =
        _isOwnerView ? _booking.sitter.avatar.url : _booking.owner.avatar.url;
    final roleLabel = _isOwnerView
        ? 'booking_agreement_service_provider_label'.tr
        // v576 — libellé de rôle unifié (clé unique pour toute l'app).
        : roleLabelKey('owner').tr;
    final ref = _booking.id.length > 6
        ? _booking.id.substring(_booking.id.length - 6).toUpperCase()
        : _booking.id.toUpperCase();

    return BookingCard(
      accent: accent,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  image: avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(avatarUrl,
                              maxWidth: 200),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl.isEmpty
                    ? Icon(Icons.person_rounded, size: 26.sp, color: accent)
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: roleLabel,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    PoppinsText(
                      text: other.trim().isNotEmpty ? other : '—',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusPill(),
              if (ref.isNotEmpty)
                InterText(
                  text: '${'agr569_booking_ref'.tr} · $ref',
                  fontSize: 11.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill() {
    final s = _statusStyle;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          InterText(
            text: s.label,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: s.color,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── bloc Dates ────────────────────────────────────────────────────
  Widget _buildDatesCard(Color accent) {
    final start = _formatBookingDate(_agreementStartDate ?? '');
    final end = _formatBookingDate(_agreementEndDate ?? '');
    final slot = BookingDateFormat.localizedTime(_booking.timeSlot);
    final duration = _durationLabel;

    String? range;
    if (start.isNotEmpty && end.isNotEmpty && start != end) {
      range = 'agr569_from_to'.trParams({'start': start, 'end': end});
    } else if (start.isNotEmpty) {
      range = 'agr569_on_day'.trParams({'date': start});
    } else if (end.isNotEmpty) {
      range = 'agr569_on_day'.trParams({'date': end});
    }

    final rows = <Widget>[
      if (range != null)
        BookingInfoRow(
          icon: Icons.event_rounded,
          label: 'agr569_section_dates'.tr,
          value: range,
          accent: accent,
        ),
      if (slot.isNotEmpty)
        BookingInfoRow(
          icon: Icons.schedule_rounded,
          label: 'agr569_slot'.tr,
          value: slot,
          accent: accent,
        ),
      if (duration != null)
        BookingInfoRow(
          icon: Icons.timelapse_rounded,
          label: 'agr569_duration'.tr,
          value: duration,
          accent: accent,
        ),
      if (_booking.cancelledAt != null && _booking.cancelledAt!.isNotEmpty)
        BookingInfoRow(
          icon: Icons.event_busy_rounded,
          label: 'booking_agreement_cancelled_at_label'.tr,
          value: _formatDateTime(_booking.cancelledAt!),
          accent: accent,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return _section(accent, 'agr569_section_dates'.tr, rows);
  }

  // ── bloc Service ──────────────────────────────────────────────────
  Widget _buildServiceCard(Color accent) {
    final venue = _agreementHouseSittingVenue ?? _booking.houseSittingVenue;
    String? venueLabel;
    if (venue == 'owners_home') {
      venueLabel = 'house_sitting_venue_owners_home'.tr;
    } else if (venue == 'sitters_home') {
      venueLabel = 'house_sitting_venue_sitters_home'.tr;
    }

    final petNames = _booking.pets.isNotEmpty
        ? _booking.pets
            .map((p) => p.petName.trim())
            .where((n) => n.isNotEmpty)
            .join(' · ')
        : _booking.petName.trim();

    final rows = <Widget>[
      if ((_booking.serviceType ?? '').isNotEmpty)
        BookingInfoRow(
          icon: Icons.pets_rounded,
          label: 'booking_agreement_service_type_label'.tr,
          value: _localizedServiceType(_booking.serviceType!),
          accent: accent,
        ),
      if (venueLabel != null)
        BookingInfoRow(
          icon: Icons.home_rounded,
          label: 'house_sitting_venue_label'.tr,
          value: venueLabel,
          accent: accent,
        ),
      if (petNames.isNotEmpty)
        BookingInfoRow(
          icon: Icons.cruelty_free_rounded,
          label: _booking.pets.length > 1
              ? 'agr569_pets'.tr
              : 'bookings_detail_pet_label'.tr,
          value: petNames,
          accent: accent,
        ),
      if ((_booking.sitter.city ?? '').trim().isNotEmpty)
        BookingInfoRow(
          icon: Icons.location_on_rounded,
          label: 'booking_agreement_city_label'.tr,
          value: _booking.sitter.city!,
          accent: accent,
        ),
      if (_booking.specialInstructions != null &&
          _booking.specialInstructions!.trim().isNotEmpty)
        BookingInfoRow(
          icon: Icons.sticky_note_2_rounded,
          label: 'booking_agreement_special_instructions_label'.tr,
          value: _booking.specialInstructions!,
          accent: accent,
        ),
      if (_booking.cancellationReason != null &&
          _booking.cancellationReason!.trim().isNotEmpty)
        BookingInfoRow(
          icon: Icons.info_outline_rounded,
          label: 'booking_agreement_cancellation_reason_label'.tr,
          value: _booking.cancellationReason!,
          accent: accent,
        ),
    ];

    final desc = _booking.description.trim();
    if (desc.isNotEmpty) rows.add(_buildDescription(desc, accent));

    if (rows.isEmpty) return const SizedBox.shrink();
    return _section(accent, 'agr569_section_service'.tr, rows);
  }

  Widget _buildDescription(String desc, Color accent) {
    const threshold = 150;
    final isLong = desc.length > threshold;
    final shown = (!isLong || _descExpanded)
        ? desc
        : '${desc.substring(0, threshold).trimRight()}…';
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'bookings_detail_description_label'.tr,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 4.h),
          InterText(
            text: shown,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
          if (isLong)
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(top: 6.h, bottom: 2.h),
                child: InterText(
                  text: _descExpanded
                      ? 'agr569_see_less'.tr
                      : 'agr569_see_more'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── bloc Prix (façon reçu) ────────────────────────────────────────
  Widget _buildPriceCard(Color accent) {
    final p = _agreementPricing ?? _booking.pricing;
    final tier = (p?.pricingTier ?? '').toLowerCase();
    final base = _basePrice ?? p?.resolvedBaseAmount ?? 0.0;
    final fee = _platformFee ?? _calculatePlatformFee(base);
    final total = _finalTotal ?? _calculateFinalTotal(base, fee);

    final tierLabel = _localizedTier(p?.pricingTier);
    final rateLabel = _formattedRate(p);
    final hours = p?.totalHours;
    final days = p?.totalDays;
    // Une ligne n'a de sens que si elle correspond au palier facturé :
    // heures pour « à l'heure », jours pour journée / semaine / mois.
    final showHours = tier == 'hourly' && hours != null && hours > 0;
    final showDays = tier != 'hourly' && days != null && days > 0;

    final totalLabel =
        _isOwnerView ? 'agr569_you_pay'.tr : 'agr569_owner_pays'.tr;
    final netLabel = _isOwnerView
        ? 'agr569_provider_receives'.tr
        : 'agr569_you_receive'.tr;

    return BookingCard(
      accent: accent,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: 'agr569_section_price'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 14.h),
          if (tierLabel != null)
            _receiptRow('booking_agreement_pricing_tier_label'.tr, tierLabel,
                muted: true),
          if (rateLabel != null)
            _receiptRow('agr569_rate_label'.tr, rateLabel, muted: true),
          if (showHours)
            _receiptRow('booking_agreement_total_hours_label'.tr,
                _trimNumber(hours), muted: true),
          if (showDays)
            _receiptRow('booking_agreement_total_days_label'.tr,
                days.toStringAsFixed(0),
                muted: true),
          if (tierLabel != null || rateLabel != null || showHours || showDays)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Divider(
                height: 1,
                color: AppColors.divider(context).withValues(alpha: 0.6),
              ),
            ),
          _receiptRow('booking_agreement_base_price_label'.tr,
              _formatPrice(base)),
          _receiptRow('booking_agreement_platform_fee_label'.tr,
              _formatPrice(fee),
              muted: true),
          if (_netToProvider != null && _netToProvider! > 0)
            _receiptRow(netLabel, _formatPrice(_netToProvider!), muted: true),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InterText(
                    text: totalLabel,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    maxLines: 2,
                  ),
                ),
                SizedBox(width: 8.w),
                PoppinsText(
                  text: _formatPrice(total),
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool muted = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 9.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InterText(
              text: label,
              fontSize: 12.5.sp,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
              color: muted
                  ? AppColors.textSecondary(context)
                  : AppColors.textPrimary(context),
              maxLines: 2,
            ),
          ),
          SizedBox(width: 10.w),
          InterText(
            text: value,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _section(Color accent, String title, List<Widget> rows) {
    return BookingCard(
      accent: accent,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: title,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 12.h),
          ...rows,
        ],
      ),
    );
  }

  // ── barre d'action collante ───────────────────────────────────────
  Widget _buildActionBar(Color accent) {
    final total = _finalTotal ??
        _calculateFinalTotal(
          _basePrice ?? 0,
          _platformFee ?? _calculatePlatformFee(_basePrice ?? 0),
        );
    final currency =
        _currency ?? _booking.pricing?.currency ?? _booking.sitter.currency;

    final children = <Widget>[];

    if (_canPay) {
      // Sprint 7 step 1 — remise fidélité.
      children.add(
        Builder(
          builder: (context) {
            final ctrl = Get.isRegistered<LoyaltyController>()
                ? Get.find<LoyaltyController>()
                : Get.put(LoyaltyController());
            return Obx(() {
              if (!ctrl.hasDiscountAvailable.value) {
                return const SizedBox.shrink();
              }
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: accent,
                value: ctrl.useLoyaltyCreditForNextPayment.value,
                onChanged: (v) =>
                    ctrl.useLoyaltyCreditForNextPayment.value = v ?? false,
                title: InterText(
                  text: 'loyalty_use_credit'.tr,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              );
            });
          },
        ),
      );
      // v565 (point 27) — entrée claire « J'ai un code ».
      children.add(
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              final ok = await showPromoCodeSheet(context, accent: accent);
              if (ok && mounted) {
                try {
                  if (Get.isRegistered<LoyaltyController>()) {
                    await Get.find<LoyaltyController>().load();
                  }
                } catch (_) {/* best-effort */}
                if (mounted) setState(() {});
              }
            },
            icon: Icon(Icons.confirmation_number_outlined,
                size: 18.sp, color: accent),
            label: InterText(
              text: 'v565_promo_have_code'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      );
      children.add(
        CustomButton(
          title: 'payment_pay_with_card'.tr.replaceAll(
                '@amount',
                CurrencyHelper.format(currency, total),
              ),
          onTap: _isBusy ? null : () => _agreeAndPayWithStripe(total),
          bgColor: accent,
          textColor: AppColors.whiteColor,
          height: 48.h,
          radius: 48.r,
        ),
      );
      if (AppConstants.showPayPalOption) {
        children.add(SizedBox(height: 10.h));
        children.add(
          CustomButton(
            title: 'payment_pay_with_paypal'.tr.replaceAll(
                  '@amount',
                  CurrencyHelper.format(currency, total),
                ),
            onTap: _isBusy ? null : () => _agreeAndPayWithPaypal(total),
            bgColor: AppColors.whiteColor,
            textColor: AppColors.grey700Color,
            borderColor: AppColors.grey300Color,
            height: 48.h,
            radius: 48.r,
          ),
        );
      }
    } else {
      // Annulée / refusée / payée / en attente : bandeau d'état en haut de
      // page + ligne neutre ici (plus de gros bouton grisé isolé).
      final s = _statusStyle;
      children.add(
        Row(
          children: [
            Icon(s.icon, size: 18.sp, color: s.color),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: _isPaid
                    ? 'booking_agreement_payment_completed'.tr
                    : (_isCancelled || _isRejected)
                        ? s.label
                        : 'agr569_no_action'.tr,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
                maxLines: 2,
              ),
            ),
            SizedBox(width: 8.w),
            OutlinedButton(
              onPressed: _isLoading ? null : () => _refreshAll(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary(context),
                side: BorderSide(
                  color: AppColors.textSecondary(context)
                      .withValues(alpha: 0.35),
                ),
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: InterText(
                text: 'agr569_refresh'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // ⚠️ dégagement bas UNIQUE de l'app (utils/bottom_inset.dart) : la barre
      // n'est pas dans un SafeArea → appBottomInset, jamais doublé (le scroll
      // ne l'applique plus).
      padding: EdgeInsets.fromLTRB(
        16.w,
        12.h,
        16.w,
        12.h + appBottomInset(context),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Squelette de chargement simple (aucune dépendance) — même esprit que
/// `BookingLoadingList` du kit Réservations, adapté au détail.
class _AgreementSkeleton extends StatefulWidget {
  final Color accent;
  const _AgreementSkeleton({required this.accent});

  @override
  State<_AgreementSkeleton> createState() => _AgreementSkeletonState();
}

class _AgreementSkeletonState extends State<_AgreementSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bone(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.textSecondary(context).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8.r),
        ),
      );

  Widget _card(List<Widget> children) => BookingCard(
        accent: widget.accent,
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Opacity(
          opacity: 0.55 + 0.45 * _c.value,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
            children: [
              _card([
                Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary(context)
                            .withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bone(70.w, 12.h),
                        SizedBox(height: 8.h),
                        _bone(140.w, 16.h),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _bone(110.w, 20.h),
              ]),
              SizedBox(height: 12.h),
              _card([
                _bone(90.w, 14.h),
                SizedBox(height: 14.h),
                _bone(double.infinity, 12.h),
                SizedBox(height: 10.h),
                _bone(200.w, 12.h),
              ]),
              SizedBox(height: 12.h),
              _card([
                _bone(120.w, 14.h),
                SizedBox(height: 14.h),
                _bone(double.infinity, 12.h),
                SizedBox(height: 10.h),
                _bone(180.w, 12.h),
                SizedBox(height: 16.h),
                _bone(double.infinity, 44.h),
              ]),
            ],
          ),
        );
      },
    );
  }
}
