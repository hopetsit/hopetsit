// v566 — informations de facturation d'un compte (demande Daniel 18/09).
//
// Contrat serveur FIGÉ : `GET/PATCH /users/me/billing-info` →
//   { type: 'individual'|'business', legalName,
//     idType: 'nif'|'nie'|'cif'|'siret'|'vat'|'ein'|'passport'|'company_number'|'other',
//     idNumber, vatNumber, address, postalCode, city, country, updatedAt }
// Les factures renvoient la même forme dans `issuerBilling` (prestataire) et
// `customerBilling` (propriétaire).
//
// Règle d'affichage : rien ne sort quand une donnée est vide (jamais « null »).
import 'package:get/get.dart';

class BillingInfo {
  final String type; // 'individual' | 'business'
  final String legalName;
  final String idType; // '' si non renseigné
  final String idNumber;
  final String vatNumber;
  final String address;
  final String postalCode;
  final String city;
  final String country; // ISO 3166-1 alpha-2 (ex. « ES »)
  final DateTime? updatedAt;

  const BillingInfo({
    this.type = 'individual',
    this.legalName = '',
    this.idType = '',
    this.idNumber = '',
    this.vatNumber = '',
    this.address = '',
    this.postalCode = '',
    this.city = '',
    this.country = '',
    this.updatedAt,
  });

  static const BillingInfo empty = BillingInfo();

  /// Types d'identifiant acceptés par le serveur (contrat figé).
  static const List<String> allIdTypes = <String>[
    'nif',
    'nie',
    'cif',
    'siret',
    'vat',
    'ein',
    'passport',
    'company_number',
    'other',
  ];

  /// Liste proposée selon le pays (ISO-2). ES : NIF, NIE, CIF ; FR : SIRET,
  /// n° TVA ; US : EIN ; partout : passeport, numéro d'entreprise, autre.
  static List<String> idTypesForCountry(String iso) {
    final c = iso.trim().toUpperCase();
    return <String>[
      if (c == 'ES') ...<String>['nif', 'nie', 'cif'],
      if (c == 'FR') ...<String>['siret', 'vat'],
      if (c == 'US') 'ein',
      'passport',
      'company_number',
      'other',
    ];
  }

  /// Libellé d'un type d'identifiant. Les sigles ne se traduisent PAS.
  static String idTypeLabel(String idType) {
    switch (idType) {
      case 'nif':
        return 'NIF';
      case 'nie':
        return 'NIE';
      case 'cif':
        return 'CIF';
      case 'siret':
        return 'SIRET';
      case 'ein':
        return 'EIN';
      case 'vat':
        return 'billing_id_vat'.tr;
      case 'passport':
        return 'billing_id_passport'.tr;
      case 'company_number':
        return 'billing_id_company_number'.tr;
      case 'other':
        return 'billing_id_other'.tr;
      default:
        return '';
    }
  }

  static String _s(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s == 'null' || s == 'undefined') return '';
    return s;
  }

  /// Tolérant : `null`, autre chose qu'une Map, ou champs absents → vide.
  factory BillingInfo.fromJson(dynamic raw) {
    if (raw is! Map) return BillingInfo.empty;
    final json = Map<String, dynamic>.from(raw);
    final t = _s(json['type']).toLowerCase();
    final idT = _s(json['idType']).toLowerCase();
    final upd = _s(json['updatedAt']);
    return BillingInfo(
      type: t == 'business' ? 'business' : 'individual',
      legalName: _s(json['legalName']),
      idType: allIdTypes.contains(idT) ? idT : '',
      idNumber: _s(json['idNumber']),
      vatNumber: _s(json['vatNumber']),
      address: _s(json['address']),
      postalCode: _s(json['postalCode']),
      city: _s(json['city']),
      country: _s(json['country']).toUpperCase(),
      updatedAt: upd.isEmpty ? null : DateTime.tryParse(upd),
    );
  }

  bool get isBusiness => type == 'business';

  /// Vide = rien d'utile à imprimer sur une facture (le pays seul, pré-rempli
  /// par défaut, ne compte pas).
  bool get isEmpty =>
      legalName.isEmpty &&
      idNumber.isEmpty &&
      vatNumber.isEmpty &&
      address.isEmpty &&
      postalCode.isEmpty &&
      city.isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// « CIF : B12345678 » (ou le numéro seul si le type est inconnu).
  String get idLine {
    if (idNumber.isEmpty) return '';
    final label = idTypeLabel(idType);
    return label.isEmpty ? idNumber : '$label : $idNumber';
  }

  /// « TVA : ESB12345678 » — masqué si l'identifiant principal EST le n° TVA.
  String get vatLine {
    if (vatNumber.isEmpty) return '';
    if (idType == 'vat' && idNumber == vatNumber) return '';
    return '${'billing_vat_short'.tr} : $vatNumber';
  }

  /// « 28001 Madrid » / « Madrid » / « 28001 ».
  String get cityLine =>
      <String>[postalCode, city].where((e) => e.isNotEmpty).join(' ');

  /// Résumé court pour la rangée du Profil : « CIF · B12345678 », sinon le
  /// nom légal, sinon vide.
  String get summary {
    if (idNumber.isNotEmpty) {
      final label = idTypeLabel(idType);
      return label.isEmpty ? idNumber : '$label · $idNumber';
    }
    if (vatNumber.isNotEmpty) return '${'billing_vat_short'.tr} · $vatNumber';
    return legalName;
  }

  /// Lignes SOUS le nom (identifiant, TVA, adresse, ville, pays) — uniquement
  /// les non vides. Le pays n'est imprimé que s'il accompagne une adresse.
  List<String> get detailLines {
    final hasAddress = address.isNotEmpty || cityLine.isNotEmpty;
    return <String>[
      idLine,
      vatLine,
      address,
      cityLine,
      if (hasAddress) country,
    ].where((e) => e.isNotEmpty).toList();
  }
}
