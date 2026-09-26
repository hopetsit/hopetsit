// v589 — « les gens que je mets staff dans l'admin peuvent cliquer sur les
// abonnements sans payer » (Daniel, 26/09). Sur iPhone la boutique passait
// directement par l'achat Apple : un staff payait. On demande d'abord au
// serveur (GET /users/me/staff, 3 profils) ; un staff passe par l'activation
// gratuite du serveur (réponse `staff: true, activated: true`).
import 'package:get/get.dart';

import '../data/network/api_client.dart';

class StaffAccess {
  StaffAccess._();

  static bool? _cached;
  static DateTime? _at;

  /// Vrai si la personne connectée est staff. Mis en cache 10 min ; en cas
  /// d'erreur réseau, faux (achat normal).
  static Future<bool> isStaff() async {
    if (_cached != null && _at != null &&
        DateTime.now().difference(_at!) < const Duration(minutes: 10)) {
      return _cached!;
    }
    try {
      if (!Get.isRegistered<ApiClient>()) return false;
      final r = await Get.find<ApiClient>().get('/users/me/staff', requiresAuth: true);
      _cached = r is Map && r['staff'] == true;
      _at = DateTime.now();
      return _cached!;
    } catch (_) {
      return false;
    }
  }

  static void reset() {
    _cached = null;
    _at = null;
  }
}
