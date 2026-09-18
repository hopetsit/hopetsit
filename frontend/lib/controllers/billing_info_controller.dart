// v566 — informations de facturation (demande Daniel 18/09).
//
//   GET   /users/me/billing-info → objet BillingInfo (vide si jamais rempli)
//   PATCH /users/me/billing-info (corps partiel) → objet complet
//
// Un seul contrôleur partagé par : l'écran de saisie, la rangée du Profil
// (résumé « CIF · B12345678 ») et les factures (bandeau « Ajoute tes
// informations de facturation »).
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/billing_info_model.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';

class BillingInfoController extends GetxController {
  BillingInfoController({ApiClient? api, GetStorage? storage})
      : _api = api ?? (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient()),
        _storage = storage ?? GetStorage();

  static const String endpoint = '/users/me/billing-info';

  /// Instance partagée (créée à la demande).
  static BillingInfoController ensure() {
    return Get.isRegistered<BillingInfoController>()
        ? Get.find<BillingInfoController>()
        : Get.put(BillingInfoController(), permanent: true);
  }

  final ApiClient _api;
  final GetStorage _storage;

  final RxBool loading = false.obs;
  final RxBool saving = false.obs;
  final RxBool loaded = false.obs;
  final RxString error = ''.obs;
  final Rx<BillingInfo> info = BillingInfo.empty.obs;

  // ── Formulaire ────────────────────────────────────────────────────────
  final RxString type = 'individual'.obs;
  final RxString idType = ''.obs;
  final RxString country = ''.obs;
  final RxString idNumberError = ''.obs;
  final TextEditingController legalNameCtl = TextEditingController();
  final TextEditingController idNumberCtl = TextEditingController();
  final TextEditingController vatNumberCtl = TextEditingController();
  final TextEditingController addressCtl = TextEditingController();
  final TextEditingController postalCodeCtl = TextEditingController();
  final TextEditingController cityCtl = TextEditingController();

  String _loadedForUser = '';
  // Une demande « remplir le formulaire » arrivée pendant un chargement déjà
  // en cours (lancé par la rangée du Profil) est honorée à la fin de celui-ci.
  bool _wantFill = false;

  /// Données déjà chargées POUR le compte courant ?
  bool get isLoadedForCurrentUser => loaded.value && _loadedForUser == _currentUserId;

  @override
  void onClose() {
    legalNameCtl.dispose();
    idNumberCtl.dispose();
    vatNumberCtl.dispose();
    addressCtl.dispose();
    postalCodeCtl.dispose();
    cityCtl.dispose();
    super.onClose();
  }

  Map<String, dynamic> get _profile {
    try {
      final raw = _storage.read(StorageKeys.userProfile);
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {/* stockage facultatif */}
    return const <String, dynamic>{};
  }

  String get _currentUserId => (_profile['id'] ?? _profile['_id'] ?? '').toString();

  /// Pays du compte (ISO-2), utilisé pour pré-remplir le formulaire.
  String get accountCountry {
    final c = (_profile['country'] ?? '').toString().trim().toUpperCase();
    return c.length == 2 ? c : '';
  }

  /// Types d'identifiant proposés pour le pays choisi (+ le type déjà
  /// enregistré s'il n'en fait pas partie, pour ne jamais le perdre).
  List<String> get idTypeOptions {
    final list = BillingInfo.idTypesForCountry(country.value);
    final current = idType.value;
    if (current.isNotEmpty && !list.contains(current)) {
      return <String>[current, ...list];
    }
    return list;
  }

  void _fillForm(BillingInfo b) {
    type.value = b.type;
    idType.value = b.idType;
    // Pays : celui enregistré, sinon celui du compte, sinon celui du téléphone.
    final device = (Get.deviceLocale?.countryCode ?? '').toUpperCase();
    country.value = b.country.isNotEmpty
        ? b.country
        : (accountCountry.isNotEmpty ? accountCountry : (device.length == 2 ? device : ''));
    legalNameCtl.text = b.legalName;
    idNumberCtl.text = b.idNumber;
    vatNumberCtl.text = b.vatNumber;
    addressCtl.text = b.address;
    postalCodeCtl.text = b.postalCode;
    cityCtl.text = b.city;
    idNumberError.value = '';
  }

  /// Charge depuis le serveur. `fillForm: false` = simple rafraîchissement du
  /// résumé (rangée du Profil, factures) sans écraser une saisie en cours.
  Future<void> load({bool fillForm = true}) async {
    if (fillForm) _wantFill = true;
    if (loading.value) return;
    final uid = _currentUserId;
    if (uid != _loadedForUser) {
      // Changement de compte : ne jamais montrer les données du précédent.
      info.value = BillingInfo.empty;
      loaded.value = false;
      if (_wantFill) _fillForm(BillingInfo.empty);
    }
    loading.value = true;
    error.value = '';
    try {
      final r = await _api.get(endpoint, requiresAuth: true);
      final b = BillingInfo.fromJson(_unwrap(r));
      info.value = b;
      loaded.value = true;
      _loadedForUser = uid;
      if (_wantFill) _fillForm(b);
    } catch (e) {
      AppLogger.logError('billing-info load failed', error: e);
      error.value = 'billing_load_error'.tr;
    } finally {
      _wantFill = false;
      loading.value = false;
    }
  }

  /// Charge une seule fois par compte (utilisé par la rangée et les factures).
  Future<void> loadIfNeeded() async {
    if (isLoadedForCurrentUser) return;
    await load(fillForm: false);
  }

  /// Remet le formulaire sur la dernière valeur connue (ouverture de l'écran).
  void resetForm() => _fillForm(info.value);

  dynamic _unwrap(dynamic r) {
    if (r is Map) {
      if (r['billingInfo'] is Map) return r['billingInfo'];
      if (r['data'] is Map) return r['data'];
    }
    return r;
  }

  void setType(String t) {
    type.value = t == 'business' ? 'business' : 'individual';
  }

  void setIdType(String? t) {
    idType.value = t ?? '';
    idNumberError.value = '';
  }

  void setCountry(String iso) {
    country.value = iso.trim().toUpperCase();
  }

  /// Validation douce : le numéro est requis dès qu'un type est choisi.
  bool validate() {
    if (idType.value.isNotEmpty && idNumberCtl.text.trim().isEmpty) {
      idNumberError.value = 'billing_error_number_required'.tr;
      return false;
    }
    idNumberError.value = '';
    return true;
  }

  /// Enregistre. Renvoie `null` si OK, sinon le message d'erreur à afficher.
  Future<String?> save() async {
    if (saving.value) return null;
    if (!validate()) return idNumberError.value;
    final number = idNumberCtl.text.trim();
    // Numéro saisi sans type → « autre » (le contrat exige un type connu).
    final effectiveType = idType.value.isNotEmpty ? idType.value : (number.isNotEmpty ? 'other' : '');
    final business = type.value == 'business';
    final body = <String, dynamic>{
      'type': type.value,
      'legalName': legalNameCtl.text.trim(),
      if (effectiveType.isNotEmpty) 'idType': effectiveType,
      'idNumber': number,
      // Le n° TVA n'a de sens que pour un professionnel.
      'vatNumber': business ? vatNumberCtl.text.trim() : '',
      'address': addressCtl.text.trim(),
      'postalCode': postalCodeCtl.text.trim(),
      'city': cityCtl.text.trim(),
      'country': country.value,
    };
    saving.value = true;
    try {
      final r = await _api.patch(endpoint, body: body, requiresAuth: true);
      final parsed = BillingInfo.fromJson(_unwrap(r));
      // Réponse sans corps exploitable → on garde ce qui vient d'être envoyé.
      final b = (parsed.isEmpty && !_bodyIsEmpty(body)) ? BillingInfo.fromJson(body) : parsed;
      info.value = b;
      loaded.value = true;
      _loadedForUser = _currentUserId;
      _fillForm(b);
      return null;
    } on ApiException catch (e) {
      AppLogger.logError('billing-info save failed', error: e);
      return e.message.isNotEmpty ? e.message : 'billing_save_error'.tr;
    } catch (e) {
      AppLogger.logError('billing-info save failed', error: e);
      return 'billing_save_error'.tr;
    } finally {
      saving.value = false;
    }
  }

  bool _bodyIsEmpty(Map<String, dynamic> body) => BillingInfo.fromJson(body).isEmpty;
}
