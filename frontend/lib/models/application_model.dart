import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/conclure1011.dart';

class ApplicationModel {
  final String id;
  final String postBody;
  final String petName;
  final String description;
  final String? serviceDate;
  /// 613 §9 (ZOE) — début RÉEL du service (instant ISO, UTC) recopié de
  /// l'annonce. `serviceDate` n'est que le jour UTC à minuit : une promenade
  /// le 17/10 à 1 h 18 (Paris) y devient « 2026-10-16 » (mesuré, émulateur).
  final String? startDate;
  final String timeSlot;
  final String status;
  final String createdAt;
  final String updatedAt;
  final ApplicationUser owner;
  final ApplicationSitter sitter;
  final BookingPricing? pricing;
  /// Session v17.2 — id of the Booking created when the owner accepts this
  /// application. Populated from `application.bookingId` on the backend
  /// (sanitizeApplication). Used to open AirwallexPaymentScreen when the
  /// owner reopens a "Demande du sitter / walker" notification that has
  /// already been accepted.
  final String? bookingId;
  /// v23.1 — B3+B5 : id of the owner's Post this application targets.
  /// Used to group candidatures per-post and detect "multiple candidates".
  final String? postId;
  /// v23.1 — provider role: 'sitter' | 'walker'. Computed from the
  /// `walker` field presence (sanitizeApplication exposes either
  /// `sitter` or `walker`).
  final String providerRole;
  /// v587 (point 8) — lieu du service recopié de l'annonce par le serveur :
  /// at_owner | at_sitter | both | pickup | meeting_point ('' = inconnu).
  final String serviceLocation;
  final String meetingPoint;
  /// 644 — service de la candidature (`dog_walking`, `home_visit`…), '' si le
  /// serveur ne l'envoie pas. Sert au rangement « Plus loin de chez toi ».
  final String serviceType;
  /// 644 — « Proposer mon prix » (`priceOffer2211View` du serveur 22/11) ;
  /// null avec un ancien serveur : rien n'est affiché.
  final PriceOffer2211View? priceOffer;
  /// 644 — « Réserver, payer plus tard » (`payLater2211View`) ; null = rien.
  final PayLater2211View? payLater;

  ApplicationModel({
    required this.id,
    required this.postBody,
    required this.petName,
    required this.description,
    this.serviceDate,
    this.startDate,
    required this.timeSlot,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.owner,
    required this.sitter,
    this.pricing,
    this.bookingId,
    this.postId,
    this.providerRole = 'sitter',
    this.serviceLocation = '',
    this.meetingPoint = '',
    this.serviceType = '',
    this.priceOffer,
    this.payLater,
  });

  /// 644 — copie avec un autre état « prix proposé » / « payer plus tard »
  /// (mise à jour locale après la réponse du serveur, sans recharger la liste).
  ApplicationModel copyWith644({PriceOffer2211View? priceOffer, PayLater2211View? payLater}) =>
      ApplicationModel(
        id: id,
        postBody: postBody,
        petName: petName,
        description: description,
        serviceDate: serviceDate,
        startDate: startDate,
        timeSlot: timeSlot,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        owner: owner,
        sitter: sitter,
        pricing: pricing,
        bookingId: bookingId,
        postId: postId,
        providerRole: providerRole,
        serviceLocation: serviceLocation,
        meetingPoint: meetingPoint,
        serviceType: serviceType,
        priceOffer: priceOffer ?? this.priceOffer,
        payLater: payLater ?? this.payLater,
      );

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    final pricingJson = json['pricing'];
    final rawBookingId = json['bookingId'];
    String? parsedBookingId;
    if (rawBookingId is String && rawBookingId.isNotEmpty) {
      parsedBookingId = rawBookingId;
    } else if (rawBookingId is Map) {
      // Populated booking — grab its id.
      final inner = rawBookingId['id']?.toString() ?? rawBookingId['_id']?.toString();
      if (inner != null && inner.isNotEmpty) parsedBookingId = inner;
    }
    // v23.1 — accept either `sitter` or `walker` populated objects so the
    // owner can distinguish candidate roles in the multi-candidates UI.
    final providerJson = (json['walker'] is Map<String, dynamic>
            ? json['walker']
            : json['sitter']) as Map<String, dynamic>? ??
        {};
    final providerRole = json['walker'] is Map<String, dynamic> ? 'walker' : 'sitter';
    return ApplicationModel(
      id: json['id'] as String? ?? '',
      postBody: json['postBody'] as String? ?? '',
      petName: json['petName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      serviceDate: json['serviceDate'] as String?,
      startDate: json['startDate']?.toString(),
      timeSlot: json['timeSlot'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      owner: ApplicationUser.fromJson(
        json['owner'] as Map<String, dynamic>? ?? {},
      ),
      sitter: ApplicationSitter.fromJson(providerJson),
      pricing: pricingJson is Map<String, dynamic>
          ? BookingPricing.fromJson(pricingJson)
          : null,
      bookingId: parsedBookingId,
      postId: json['postId']?.toString(),
      serviceLocation: (json['serviceLocation'] ?? '').toString(),
      meetingPoint: (json['meetingPoint'] ?? '').toString(),
      providerRole: providerRole,
      serviceType: (json['serviceType'] ?? '').toString(),
      priceOffer: PriceOffer2211View.tryParse(json['priceOffer2211View']),
      payLater: PayLater2211View.tryParse(json['payLater2211View']),
    );
  }
}

double? _num644(dynamic v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// 644 — ce que le serveur autorise pour « Proposer mon prix » et où en est la
/// dernière proposition (`priceOffer2211.ownerView`). Lecture seule.
class PriceOffer2211View {
  /// Le lien « Proposer mon prix » peut être montré.
  final bool canOffer;
  /// pending | accepted | declined | expired | cancelled | '' (aucune).
  final String status;
  final double? amount;
  final String currency;
  final double? currentTotal;
  final double? minAmount;
  final bool negotiated;

  const PriceOffer2211View({
    this.canOffer = false,
    this.status = '',
    this.amount,
    this.currency = '',
    this.currentTotal,
    this.minAmount,
    this.negotiated = false,
  });

  static PriceOffer2211View? tryParse(dynamic json) {
    if (json is! Map) return null;
    return PriceOffer2211View(
      canOffer: json['canOffer'] == true,
      status: (json['status'] ?? '').toString().toLowerCase().trim(),
      amount: _num644(json['amount']),
      currency: (json['currency'] ?? '').toString().toUpperCase().trim(),
      currentTotal: _num644(json['currentTotal']),
      minAmount: _num644(json['minAmount']),
      negotiated: json['negotiated'] == true,
    );
  }

  PriceOffer2211View closed() => PriceOffer2211View(
        canOffer: false,
        status: status,
        amount: amount,
        currency: currency,
        currentTotal: currentTotal,
        minAmount: minAmount,
        negotiated: negotiated,
      );
}

/// 644 — ce que le serveur autorise pour « Réserver, payer plus tard » et où
/// en est la réservation (`payLater2211.ownerView`). Lecture seule.
class PayLater2211View {
  /// Le bouton « Réserver (prénom), payer plus tard » peut être montré.
  final bool canReserve;
  /// waiting | paid | released | '' (rien).
  final String status;
  /// Échéance de paiement (instant UTC), null si absente ou illisible.
  final DateTime? deadline;
  final int? holdHours;

  const PayLater2211View({
    this.canReserve = false,
    this.status = '',
    this.deadline,
    this.holdHours,
  });

  static PayLater2211View? tryParse(dynamic json) {
    if (json is! Map) return null;
    final h = _num644(json['holdHours']);
    return PayLater2211View(
      canReserve: json['canReserve'] == true,
      status: (json['status'] ?? '').toString().toLowerCase().trim(),
      deadline: DateTime.tryParse((json['deadline'] ?? '').toString()),
      holdHours: h?.round(),
    );
  }

  PayLater2211View closed() =>
      PayLater2211View(canReserve: false, status: status, deadline: deadline, holdHours: holdHours);
}

class ApplicationUser {
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
  final ApplicationAvatar avatar;

  ApplicationUser({
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

  factory ApplicationUser.fromJson(Map<String, dynamic> json) {
    return ApplicationUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      language: json['language'] as String? ?? '',
      address: json['address'] as String? ?? '',
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: _parseService(json['service']),
      verified: json['verified'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      avatar: ApplicationAvatar.fromJson(
        json['avatar'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  static List<String> _parseService(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      return [value];
    }
    return [];
  }
}

class ApplicationSitter {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String language;
  final String address;
  final String? city; // City extracted from location object
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
  final ApplicationAvatar avatar;
  /// 624 — position approximative (floutée ~1 km par le serveur) pour
  /// « à ~N km » sur la page des candidats ; null si absente.
  final double? lat;
  final double? lng;
  /// 624 — identité vérifiée (KYC), pastille « Identité vérifiée ».
  final bool identityVerified;
  /// 628 — PawBoost actif (`isBoosted` posé par le serveur dans
  /// sanitizeApplication) : candidats boostés en tête, tri stable.
  final bool isBoosted;
  /// 1011 — candidat véhiculé (`sitter.hasVehicle` / `walker.hasVehicle`) :
  /// pastille « Véhiculé » seulement quand c'est `true` ; null = inconnu.
  final bool? hasVehicle;

  ApplicationSitter({
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
    this.lat,
    this.lng,
    this.identityVerified = false,
    this.isBoosted = false,
    this.hasVehicle,
  });

  /// 624 — `location.lat/lng`, sinon `location.coordinates` = [lng, lat].
  static (double?, double?) _point(dynamic loc) {
    if (loc is! Map) return (null, null);
    double? d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    final la = d(loc['lat']), ln = d(loc['lng']);
    if (la != null && ln != null) return (la, ln);
    final c = loc['coordinates'];
    if (c is List && c.length >= 2) {
      final x = d(c[0]), y = d(c[1]);
      if (x != null && y != null && !(x == 0 && y == 0)) return (y, x);
    }
    return (null, null);
  }

  factory ApplicationSitter.fromJson(Map<String, dynamic> json) {
    final pt = _point(json['location']);
    return ApplicationSitter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      language: json['language'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['location'] is Map<String, dynamic>
          ? (json['location']['city'] as String?)
          : null,
      rate: json['rate'] as String?,
      skills: json['skills'] as String? ?? '',
      bio: json['bio'] as String?,
      acceptedTerms: json['acceptedTerms'] as bool? ?? false,
      service: ApplicationUser._parseService(json['service']),
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
      lat: pt.$1,
      lng: pt.$2,
      // Même règle que la PawMap (`pawIdentityVerified`) : jamais un simple
      // e-mail vérifié.
      identityVerified:
          json['identityVerified'] == true || json['kycVerified'] == true,
      isBoosted: json['isBoosted'] == true,
      hasVehicle: parseTriBool1011(json['hasVehicle']),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      // 644 — le site lit `avatar` comme un texte : on accepte les deux formes.
      avatar: json['avatar'] is String
          ? ApplicationAvatar(url: (json['avatar'] as String).trim(), publicId: '')
          : ApplicationAvatar.fromJson(
              json['avatar'] is Map ? Map<String, dynamic>.from(json['avatar'] as Map) : {},
            ),
    );
  }

  static String _parseSitterCurrency(dynamic value) {
    if (value == null) return 'EUR';
    final s = value.toString().trim().toUpperCase();
    if (s == 'EUR') return 'EUR';
    return s.isNotEmpty ? s : 'EUR';
  }
}

class ApplicationAvatar {
  final String url;
  final String publicId;

  ApplicationAvatar({required this.url, required this.publicId});

  factory ApplicationAvatar.fromJson(Map<String, dynamic> json) {
    return ApplicationAvatar(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
    );
  }
}
