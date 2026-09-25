/// Pet info within a booking (from API "pets" array).
class BookingPet {
  final String id;
  final String petName;
  final String breed;
  final String category;
  final String weight;
  final String height;
  final String colour;
  final String vaccination;
  final String medicationAllergies;
  final BookingAvatar avatar;

  BookingPet({
    required this.id,
    required this.petName,
    required this.breed,
    required this.category,
    required this.weight,
    required this.height,
    required this.colour,
    required this.vaccination,
    required this.medicationAllergies,
    required this.avatar,
  });

  factory BookingPet.fromJson(Map<String, dynamic> json) {
    final avatarData = json['avatar'];
    BookingAvatar avatar;
    if (avatarData is String) {
      avatar = BookingAvatar(url: avatarData, publicId: '');
    } else if (avatarData is Map<String, dynamic>) {
      avatar = BookingAvatar.fromJson(avatarData);
    } else {
      avatar = BookingAvatar(url: '', publicId: '');
    }
    return BookingPet(
      id: json['id'] as String? ?? '',
      petName: json['petName'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      category: json['category'] as String? ?? '',
      weight: json['weight']?.toString() ?? '',
      height: json['height']?.toString() ?? '',
      colour: json['colour']?.toString() ?? json['color']?.toString() ?? '',
      vaccination: json['vaccination'] as String? ?? '',
      medicationAllergies: json['medicationAllergies'] as String? ?? '',
      avatar: avatar,
    );
  }
}

/// v565 (point 24 / contrat §7) — étape de la chronologie de remise renvoyée
/// par `GET /bookings/:id` : `timeline: [{ step, at, by }]`, step ∈ planned |
/// picked_up | pickup_confirmed | returned | return_confirmed | completed.
class BookingTimelineStep {
  final String step;
  final String? at;
  final String? by;
  const BookingTimelineStep({required this.step, this.at, this.by});

  factory BookingTimelineStep.fromJson(Map<String, dynamic> json) {
    return BookingTimelineStep(
      step: (json['step'] ?? '').toString(),
      at: json['at']?.toString(),
      by: json['by']?.toString(),
    );
  }

  DateTime? get atDate => at == null ? null : DateTime.tryParse(at!)?.toLocal();
}

/// v565 (point 24 / contrat §7) — objet `handover` du booking : horodatages
/// des rappels, des actions prestataire, des confirmations owner (manuelles
/// ou automatiques après 2 h) et positions GPS. Toutes les dates sont null par
/// défaut (vieux backend ou étape pas encore atteinte).
class BookingHandover {
  final String? pickupReminderAt;
  final String? pickupOverdueAt;
  final String? pickupProviderAt;
  final String? pickupOwnerConfirmedAt;
  final String? pickupAutoConfirmedAt;
  final String? returnReminderAt;
  final String? returnProviderAt;
  final String? returnOwnerConfirmedAt;
  final String? returnAutoConfirmedAt;
  final double? pickupLat;
  final double? pickupLng;
  final double? returnLat;
  final double? returnLng;
  final String? stillActiveNoticeAt;

  const BookingHandover({
    this.pickupReminderAt,
    this.pickupOverdueAt,
    this.pickupProviderAt,
    this.pickupOwnerConfirmedAt,
    this.pickupAutoConfirmedAt,
    this.returnReminderAt,
    this.returnProviderAt,
    this.returnOwnerConfirmedAt,
    this.returnAutoConfirmedAt,
    this.pickupLat,
    this.pickupLng,
    this.returnLat,
    this.returnLng,
    this.stillActiveNoticeAt,
  });

  static String? _s(dynamic v) => v?.toString();
  static double? _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  factory BookingHandover.fromJson(Map<String, dynamic> json) {
    return BookingHandover(
      pickupReminderAt: _s(json['pickupReminderAt']),
      pickupOverdueAt: _s(json['pickupOverdueAt']),
      pickupProviderAt: _s(json['pickupProviderAt']),
      pickupOwnerConfirmedAt: _s(json['pickupOwnerConfirmedAt']),
      pickupAutoConfirmedAt: _s(json['pickupAutoConfirmedAt']),
      returnReminderAt: _s(json['returnReminderAt']),
      returnProviderAt: _s(json['returnProviderAt']),
      returnOwnerConfirmedAt: _s(json['returnOwnerConfirmedAt']),
      returnAutoConfirmedAt: _s(json['returnAutoConfirmedAt']),
      pickupLat: _d(json['pickupLat']),
      pickupLng: _d(json['pickupLng']),
      returnLat: _d(json['returnLat']),
      returnLng: _d(json['returnLng']),
      stillActiveNoticeAt: _s(json['stillActiveNoticeAt']),
    );
  }

  /// Le prestataire a déclaré la récupération.
  bool get pickedUp => pickupProviderAt != null;
  /// Récupération confirmée (par le propriétaire OU automatiquement).
  bool get pickupConfirmed =>
      pickupOwnerConfirmedAt != null || pickupAutoConfirmedAt != null;
  /// Le prestataire a déclaré le rendu.
  bool get returned => returnProviderAt != null;
  /// Rendu confirmé (par le propriétaire OU automatiquement).
  bool get returnConfirmed =>
      returnOwnerConfirmedAt != null || returnAutoConfirmedAt != null;
  /// Le propriétaire doit confirmer la récupération.
  bool get pickupAwaitingOwner => pickedUp && !pickupConfirmed;
  /// Le propriétaire doit confirmer le rendu.
  bool get returnAwaitingOwner => returned && !returnConfirmed;
}

class BookingModel {
  final String id;
  final String petName;
  final String petWeight;
  final String petHeight;
  final String petColor;
  final String description;
  final String date;
  final String timeSlot;
  String status;
  final String createdAt;
  final String updatedAt;
  // v23.1 part 44 — paidAt is the canonical "moment payment was confirmed".
  // Banner uses it (not updatedAt) to decide whether the "Paiement reçu"
  // banner is still relevant : updatedAt drifts on every booking edit
  // (status change, agreement update…) which made the banner reappear
  // every time the booking was touched, even hours after the payment.
  final String? paidAt;
  final BookingUser owner;
  final BookingSitter sitter;
  final List<BookingPet> pets; // From API "pets" array
  final String? paymentStatus; // 'pending', 'paid', 'failed', etc.
  // v23.1.259 — Système de confirmation de service. confirmationStatus :
  // none / awaiting_start / in_progress / awaiting_confirmation / confirmed /
  // disputed. Pilote l'affichage des boutons (démarrer/terminer/confirmer).
  final String confirmationStatus;
  // v532 — preuve de remise. Le serveur n'envoie [handoverCode] QU'AU
  // PROPRIÉTAIRE (côté prestataire il vaut toujours null) : c'est lui qui le
  // lit et le dicte au gardien au moment de confier l'animal. Les deux URL
  // sont les photos prises à la récupération et à la restitution.
  final String? handoverCode;
  final String? pickupProofUrl;
  final String? returnProofUrl;
  final String? serviceStartedAt;
  final String? serviceEndedAt;
  final String? autoReleaseAt;
  final double? totalAmount; // Total amount including platform fee
  final double? basePrice; // Base price before platform fee
  final BookingPricing? pricing; // Pricing details
  final String? cancelledAt; // When booking was cancelled
  final String? cancelledBy; // Who cancelled the booking
  final String? cancellationReason; // Reason for cancellation
  final String? serviceType; // Type of service
  final String? houseSittingVenue; // owners_home or sitters_home
  /// v587 (point 8) — lieu du service recopié de l'annonce :
  /// at_owner | at_sitter | both | pickup | meeting_point (+ meetingPoint).
  final String? serviceLocation;
  final String? meetingPoint;
  final int? duration; // Walk duration in minutes (e.g. 30/60) when applicable
  final String? specialInstructions; // Special instructions for the booking
  // v23.1.170 — Daniel : bouton dynamique « Suivre walker » / « Suivre sitter ».
  // On expose le rôle du provider tel qu'envoyé par l'API (`sitter` ou
  // `walker`) pour pouvoir afficher dynamiquement le label du bouton.
  final String? providerRole;
  // v462 — éligibilité d'annulation 72h AUTORITAIRE, calculée par le backend
  // (sanitizeBooking) avec la MÊME règle que selfCancelWithRefund. Évite que
  // le frontend re-devine (cause racine récurrente du bug « bouton ne marche
  // pas + pop up anglais »). Nullable = vieux backend pas encore déployé →
  // on retombe sur un recalcul local robuste (cf. getters plus bas).
  final bool? canSelfCancel;
  final int? hoursUntilStart;
  // v565 (point 24) — remise / rendu : objet `handover` + chronologie
  // `timeline` renvoyés par le détail (`GET /bookings/:id`). La liste peut ne
  // pas les porter → null / vide, et la carte de service retombe sur
  // `confirmationStatus` + `serviceStartedAt` / `serviceEndedAt`.
  final BookingHandover? handover;
  final List<BookingTimelineStep> timeline;
  // v565 — fin prévue (ISO) quand le serveur la renvoie ; sert au rappel
  // « rendu dans 30 min ». Null si absent.
  final String? endDate;

  BookingModel({
    required this.id,
    required this.petName,
    required this.petWeight,
    required this.petHeight,
    required this.petColor,
    required this.description,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
    required this.owner,
    required this.sitter,
    List<BookingPet>? pets,
    this.paymentStatus,
    this.confirmationStatus = 'none',
    this.handoverCode,
    this.pickupProofUrl,
    this.returnProofUrl,
    this.serviceStartedAt,
    this.serviceEndedAt,
    this.autoReleaseAt,
    this.totalAmount,
    this.basePrice,
    this.pricing,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.serviceType,
    this.houseSittingVenue,
    this.serviceLocation,
    this.meetingPoint,
    this.duration,
    this.specialInstructions,
    this.providerRole,
    this.canSelfCancel,
    this.hoursUntilStart,
    this.handover,
    List<BookingTimelineStep>? timeline,
    this.endDate,
  })  : pets = pets ?? [],
        timeline = timeline ?? const <BookingTimelineStep>[];

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Handle 'sitter', 'walker' and 'otherParty' fields from API.
    // For owner flow: 'sitter' OR 'walker' (since v17) OR 'otherParty' carries
    // the provider info — depending on whether the booking targets a sitter
    // or a walker. For sitter/walker flow: only 'otherParty' exists (owner).
    final sitterData = json['sitter'] as Map<String, dynamic>?;
    // Session v17 — walker bookings populate `walker` in sanitizeBooking.
    // BookingSitter is structurally compatible (name/email/avatar/etc.) so
    // we reuse the same model under the `sitter` field for backward compat.
    final walkerData = json['walker'] as Map<String, dynamic>?;
    final ownerData = json['owner'] as Map<String, dynamic>?;
    final otherParty = json['otherParty'] as Map<String, dynamic>?;

    // Determine which field to use based on what's available.
    // Priority: sitter > walker > otherParty > {} (empty fallback).
    final finalSitterData = sitterData ?? walkerData ?? otherParty ?? {};

    // v23.1.170 — Daniel : bouton "Suivre walker" / "Suivre sitter".
    // On déduit le rôle depuis le champ source. Si l'API envoie `walker` →
    // walker. Si elle envoie `sitter` → sitter. Si seulement `otherParty` →
    // on lit `providerType` si présent, sinon fallback null.
    String? inferredProviderRole;
    if (walkerData != null) {
      inferredProviderRole = 'walker';
    } else if (sitterData != null) {
      inferredProviderRole = 'sitter';
    } else if (otherParty != null) {
      inferredProviderRole = (otherParty['providerType'] ??
              otherParty['role'] ??
              json['providerType'])
          ?.toString()
          .toLowerCase();
    } else {
      inferredProviderRole = (json['providerType'] ?? json['providerRole'])
          ?.toString()
          .toLowerCase();
    }

    // If 'owner' exists, use it; otherwise use 'otherParty' (for sitter flow)
    final finalOwnerData = ownerData ?? otherParty ?? {};

    // v23.1 part 252 — crash audit : whereType au lieu de cast brut
    // (crashait si un element pets n'etait pas un Map).
    final petsList = json['pets'] as List<dynamic>?;
    final parsedPets = petsList != null
        ? petsList
              .whereType<Map<String, dynamic>>()
              .map((e) => BookingPet.fromJson(e))
              .toList()
        : <BookingPet>[];
    final firstPetName = parsedPets.isNotEmpty
        ? parsedPets.first.petName
        : (json['petName'] as String? ?? '');
    final firstPetWeight = parsedPets.isNotEmpty
        ? parsedPets.first.weight
        : (json['petWeight']?.toString() ?? '');
    final firstPetHeight = parsedPets.isNotEmpty
        ? parsedPets.first.height
        : (json['petHeight']?.toString() ?? '');
    final firstPetColor = parsedPets.isNotEmpty
        ? parsedPets.first.colour
        : (json['petColor']?.toString() ?? '');

    return BookingModel(
      id: json['id'] as String? ?? '',
      petName: firstPetName,
      petWeight: firstPetWeight,
      petHeight: firstPetHeight,
      petColor: firstPetColor,
      description: json['description'] as String? ?? '',
      date: json['date'] as String? ?? '',
      timeSlot: json['timeSlot'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      paidAt: json['paidAt'] as String? ?? json['paid_at'] as String?,
      owner: BookingUser.fromJson(finalOwnerData),
      sitter: BookingSitter.fromJson(finalSitterData),
      pets: parsedPets,
      // v23.1.254 — Daniel : "annulation sous 72h a disparu sur tous les
      // profils". Cause racine : le bouton d'annulation 72h est gaté sur
      // `paymentStatus == 'paid'`, mais certains chemins backend renvoient
      // un booking payé SANS le champ paymentStatus (le backend marque le
      // paiement via status='paid' ET/OU paidAt, et sanitizeBooking n'ajoute
      // paymentStatus que s'il est défini en DB). Résultat : paymentStatus
      // null → bouton caché sur les 3 profils. Fallback : si status='paid'
      // ou paidAt présent, on considère paymentStatus='paid'. Ne peut que
      // FAIRE APPARAÎTRE le bouton pour des réservations réellement payées.
      paymentStatus: (json['paymentStatus'] as String?) ??
          ((((json['status'] as String?) ?? '').toLowerCase() == 'paid') ||
                  (json['paidAt'] ?? json['paid_at']) != null
              ? 'paid'
              : null),
      // v23.1.259 — confirmation de service.
      confirmationStatus:
          (json['confirmationStatus'] as String?) ?? 'none',
      // v532 — preuve de remise (cf. champs ci-dessus).
      handoverCode: json['handoverCode'] as String?,
      pickupProofUrl: json['pickupProofUrl'] as String?,
      returnProofUrl: json['returnProofUrl'] as String?,
      serviceStartedAt: json['serviceStartedAt'] as String?,
      serviceEndedAt: json['serviceEndedAt'] as String?,
      autoReleaseAt: json['autoReleaseAt'] as String?,
      totalAmount:
          (json['totalAmount'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble(),
      basePrice:
          (json['basePrice'] as num?)?.toDouble() ??
          (json['base_price'] as num?)?.toDouble(),
      // v23.1 part 252 — crash audit : is Map au lieu de cast brut.
      pricing: json['pricing'] is Map<String, dynamic>
          ? BookingPricing.fromJson(json['pricing'] as Map<String, dynamic>)
          : null,
      cancelledAt:
          json['cancelledAt'] as String? ?? json['cancelled_at'] as String?,
      cancelledBy:
          json['cancelledBy'] as String? ?? json['cancelled_by'] as String?,
      cancellationReason:
          json['cancellationReason'] as String? ??
          json['cancellation_reason'] as String?,
      serviceType:
          json['serviceType'] as String? ?? json['service_type'] as String?,
      houseSittingVenue:
          json['houseSittingVenue'] as String? ??
          json['house_sitting_venue'] as String?,
      serviceLocation: json['serviceLocation'] as String?,
      meetingPoint: json['meetingPoint'] as String?,
      duration: json['duration'] as int?,
      providerRole: inferredProviderRole,
      specialInstructions:
          json['specialInstructions'] as String? ??
          json['special_instructions'] as String?,
      // v462 — éligibilité 72h autoritaire renvoyée par le backend.
      canSelfCancel: json['canSelfCancel'] as bool?,
      hoursUntilStart: (json['hoursUntilStart'] as num?)?.toInt(),
      // v565 — remise / rendu (contrat §7).
      handover: json['handover'] is Map
          ? BookingHandover.fromJson(
              Map<String, dynamic>.from(json['handover'] as Map))
          : null,
      timeline: json['timeline'] is List
          ? (json['timeline'] as List)
              .whereType<Map>()
              .map((e) => BookingTimelineStep.fromJson(
                  Map<String, dynamic>.from(e)))
              .where((e) => e.step.isNotEmpty)
              .toList()
          : null,
      endDate: (json['endDate'] ?? json['end_date'] ?? json['dateEnd'])
          ?.toString(),
    );
  }

  // ── v565 — aides remise / rendu ────────────────────────────────────────
  /// Début prévu du service (date + heure du créneau si lisible), en heure
  /// locale. Null si la date n'est pas interprétable.
  DateTime? get plannedStart {
    final d = _localStartDate();
    if (d == null) return null;
    final m = RegExp(r'(\d{1,2})[:h](\d{2})').firstMatch(timeSlot);
    if (m == null) return d;
    final h = int.tryParse(m.group(1)!) ?? 0;
    final mi = int.tryParse(m.group(2)!) ?? 0;
    return DateTime(d.year, d.month, d.day, h, mi);
  }

  /// Fin prévue : `endDate` serveur, sinon début + durée (promenade), sinon
  /// début + 1 h (garde à la journée : le serveur envoie le rappel, l'app ne
  /// fait qu'afficher).
  DateTime? get plannedEnd {
    if (endDate != null) {
      final e = DateTime.tryParse(endDate!);
      if (e != null) return e.toLocal();
    }
    final s = plannedStart;
    if (s == null) return null;
    if (duration != null && duration! > 0) {
      return s.add(Duration(minutes: duration!));
    }
    final m = RegExp(r'(\d{1,2})[:h](\d{2})\s*[-–]\s*(\d{1,2})[:h](\d{2})')
        .firstMatch(timeSlot);
    if (m != null) {
      final h = int.tryParse(m.group(3)!) ?? s.hour;
      final mi = int.tryParse(m.group(4)!) ?? s.minute;
      return DateTime(s.year, s.month, s.day, h, mi);
    }
    return null;
  }

  // ── v462 — Éligibilité annulation 72h ─────────────────────────────────
  // On PRÉFÈRE toujours la valeur backend (canSelfCancel). Si elle est absente
  // (vieux backend), on recalcule localement de façon ROBUSTE : on accepte les
  // formats ISO « yyyy-MM-dd[…] » ET « dd/MM/yyyy », et on applique le seuil
  // 72h. Ce recalcul reste conservateur (minuit, sans timeSlot) mais ne sert
  // plus que de filet de sécurité — le backend est la source de vérité.
  DateTime? _localStartDate() {
    final s = date.trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mo == null || y == null) return null;
    try {
      return DateTime(y, mo, d);
    } catch (_) {
      return null;
    }
  }

  /// true si la réservation est annulable gratuitement (fenêtre > 72h). Lit la
  /// valeur backend si présente, sinon recalcul local.
  bool get isSelfCancelEligible {
    if (canSelfCancel != null) return canSelfCancel!;
    final dt = _localStartDate();
    if (dt == null) return false;
    return dt.difference(DateTime.now()).inHours > 72;
  }

  /// Nombre d'heures avant le début du service (pour l'affichage du dialogue).
  int get hoursUntilStartResolved {
    if (hoursUntilStart != null) return hoursUntilStart!;
    final dt = _localStartDate();
    if (dt == null) return 0;
    final h = dt.difference(DateTime.now()).inHours;
    return h < 0 ? 0 : h;
  }
}

/// Parses service from API: can be List`<String>` or String (legacy).
List<String> _parseBookingService(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) {
    return [value];
  }
  return [];
}

class BookingUser {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final bool acceptedTerms;
  final List<String> service;
  final bool verified;
  final String createdAt;
  final String updatedAt;
  final BookingAvatar avatar;

  BookingUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.language,
    required this.address,
    required this.acceptedTerms,
    required this.service,
    required this.verified,
    required this.createdAt,
    required this.updatedAt,
    required this.avatar,
  });

  factory BookingUser.fromJson(Map<String, dynamic> json) {
    // Handle avatar - can be a string URL or an object
    BookingAvatar avatar;
    final avatarData = json['avatar'];
    if (avatarData is String) {
      // If avatar is a string URL, create an avatar object with it
      avatar = BookingAvatar(url: avatarData, publicId: '');
    } else if (avatarData is Map<String, dynamic>) {
      avatar = BookingAvatar.fromJson(avatarData);
    } else {
      avatar = BookingAvatar(url: '', publicId: '');
    }

    // Handle both 'phone' and 'mobile' fields from API
    final mobile = json['phone'] as String? ?? json['mobile'] as String? ?? '';

    // Handle both 'location' and 'address' fields from API
    final address =
        json['location'] as String? ?? json['address'] as String? ?? '';

    return BookingUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: mobile,
      language: json['language'] as String? ?? '',
      address: address,
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: _parseBookingService(json['service']),
      verified: json['verified'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: avatar,
    );
  }
}

class BookingSitter {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final String? city;
  final String? rate;
  final String skills;
  final String? bio;
  final bool acceptedTerms;
  final List<String> service;
  final bool verified;
  final double rating;
  final int reviewsCount;
  final List<dynamic> feedback;
  final double hourlyRate;
  final double weeklyRate;
  final double monthlyRate;
  final String currency;
  final String createdAt;
  final String updatedAt;
  final BookingAvatar avatar;

  BookingSitter({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.language,
    required this.address,
    this.city,
    this.rate,
    required this.skills,
    this.bio,
    required this.acceptedTerms,
    required this.service,
    required this.verified,
    required this.rating,
    required this.reviewsCount,
    required this.feedback,
    required this.hourlyRate,
    this.weeklyRate = 0.0,
    this.monthlyRate = 0.0,
    this.currency = 'EUR',
    required this.createdAt,
    required this.updatedAt,
    required this.avatar,
  });

  factory BookingSitter.fromJson(Map<String, dynamic> json) {
    // Handle avatar - can be a string URL or an object
    BookingAvatar avatar;
    final avatarData = json['avatar'];
    if (avatarData is String) {
      // If avatar is a string URL, create an avatar object with it
      avatar = BookingAvatar(url: avatarData, publicId: '');
    } else if (avatarData is Map<String, dynamic>) {
      avatar = BookingAvatar.fromJson(avatarData);
    } else {
      avatar = BookingAvatar(url: '', publicId: '');
    }

    // Handle both 'phone' and 'mobile' fields from API
    final mobile = json['phone'] as String? ?? json['mobile'] as String? ?? '';

    // Handle both 'location' and 'address' fields from API
    final address =
        json['location'] as String? ?? json['address'] as String? ?? '';

    final location = json['location'];
    final city = location is Map ? (location['city'] as String?) : null;
    return BookingSitter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: mobile,
      language: json['language'] as String? ?? '',
      address: address,
      city: city,
      rate: json['rate'] as String?,
      skills: json['skills'] as String? ?? '',
      bio: json['bio'] as String?,
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: _parseBookingService(json['service']),
      verified: json['verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: json['reviewsCount'] as int? ?? 0,
      feedback: json['feedback'] as List<dynamic>? ?? [],
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      weeklyRate: (json['weeklyRate'] as num?)?.toDouble() ?? 0.0,
      monthlyRate: (json['monthlyRate'] as num?)?.toDouble() ?? 0.0,
      currency: _parseSitterCurrency(
        json['currency'] ?? json['hourlyRateCurrency'],
      ),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: avatar,
    );
  }

  static String _parseSitterCurrency(dynamic value) {
    if (value == null) return 'EUR';
    final s = value.toString().trim().toUpperCase();
    if (s == 'EUR') return 'EUR';
    return s.isNotEmpty ? s : 'EUR';
  }
}

class BookingPricing {
  final double? platformFeePercentage;
  final double? basePrice;
  final double? platformFee;
  final double? totalPrice;
  final double? netAmount; // Amount after fees
  final String? currency;

  /// Backend tier: `hourly`, `weekly`, or `monthly` (length-based).
  final String? pricingTier;
  final double? appliedRate;
  final double? totalHours;
  final double? totalDays;

  BookingPricing({
    this.platformFeePercentage,
    this.basePrice,
    this.platformFee,
    this.totalPrice,
    this.netAmount,
    this.currency,
    this.pricingTier,
    this.appliedRate,
    this.totalHours,
    this.totalDays,
  });

  factory BookingPricing.fromJson(Map<String, dynamic> json) {
    final baseFromApi =
        (json['basePrice'] as num?)?.toDouble() ??
        (json['base_price'] as num?)?.toDouble();
    final baseFromLegacy =
        (json['netPayout'] as num?)?.toDouble() ??
        (json['net_payout'] as num?)?.toDouble();

    return BookingPricing(
      platformFeePercentage:
          (json['platformFeePercentage'] as num?)?.toDouble() ??
          (json['platform_fee_percentage'] as num?)?.toDouble(),
      basePrice: baseFromApi ?? baseFromLegacy,
      // v18.9.8 — le backend stocke le champ sous le nom `commission`
      // (pricing.js / bookingController). On garde aussi `platformFee` et
      // `platform_fee` pour rétro-compat avec d'anciennes réponses.
      platformFee:
          (json['platformFee'] as num?)?.toDouble() ??
          (json['platform_fee'] as num?)?.toDouble() ??
          (json['commission'] as num?)?.toDouble(),
      totalPrice:
          (json['totalPrice'] as num?)?.toDouble() ??
          (json['total_price'] as num?)?.toDouble(),
      // v20.0.11 — CRITICAL FIX: le backend stocke `netPayout` (pas
      // `netAmount`). Avant ce fallback, netAmount restait null et les
      // écrans tombaient sur `total * 0.8` qui re-déduisait 20% au walker/
      // sitter, d'où l'affichage "Tu touches 4.80€" pour un tarif de 5€.
      // Avec le fallback, le provider reçoit bien son tarif complet.
      netAmount:
          (json['netAmount'] as num?)?.toDouble() ??
          (json['net_amount'] as num?)?.toDouble() ??
          (json['netPayout'] as num?)?.toDouble() ??
          (json['net_payout'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      pricingTier: json['pricingTier'] as String? ?? json['pricing_tier'] as String?,
      appliedRate:
          (json['appliedRate'] as num?)?.toDouble() ??
          (json['applied_rate'] as num?)?.toDouble(),
      totalHours:
          (json['totalHours'] as num?)?.toDouble() ??
          (json['total_hours'] as num?)?.toDouble(),
      totalDays:
          (json['totalDays'] as num?)?.toDouble() ??
          (json['total_days'] as num?)?.toDouble(),
    );
  }

  /// Best-effort base service amount for display when only tier fields exist.
  double? get resolvedBaseAmount {
    if (basePrice != null && basePrice! > 0) return basePrice;
    if (appliedRate != null && appliedRate! > 0) return appliedRate;
    return null;
  }
}

class BookingAvatar {
  final String url;
  final String publicId;

  BookingAvatar({required this.url, required this.publicId});

  factory BookingAvatar.fromJson(Map<String, dynamic> json) {
    return BookingAvatar(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
    );
  }
}
