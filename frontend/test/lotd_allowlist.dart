// v585 (lot D) — LISTES D'AUTORISATION figées des deux garde-fous
// (`lotd_raw_buttons_guard_test.dart`, `lotd_no_gray_test.dart`).
// GÉNÉRÉ par le script d'inventaire (scratchpad `inventaire.py` +
// `gen_allowlist.py`) : ne pas éditer à la main. Un fichier qui n'y figure
// pas doit être à ZÉRO ; un fichier qui y figure ne doit pas AUGMENTER. Pour
// baisser un compte après un nettoyage, régénérer ce fichier.

/// Boutons Material bruts (ElevatedButton / TextButton / OutlinedButton / FilledButton) encore hors du kit, par fichier.
const Map<String, int> kRawButtonsAllowed = <String, int>{
  'lib/services/app_update_service.dart': 2,
  'lib/views/auth/forgot_flow/forgot_password_email_screen.dart': 1,
  'lib/views/auth/forgot_flow/forgot_password_otp_screen.dart': 2,
  'lib/views/auth/otp_verification_screen.dart': 2,
  'lib/views/auth/signup_wizard_screen.dart': 2,
  'lib/views/booking/booking_agreement_screen.dart': 2,
  'lib/views/booking/handover/handover_action_sheet.dart': 4,
  'lib/views/booking/widgets/booking_ui_kit.dart': 1,
  'lib/views/boost/coin_shop_screen.dart': 2,
  'lib/views/boost/pawspot_leaderboard_screen.dart': 2,
  'lib/views/boost/widgets/shop_ui_kit.dart': 3,
  'lib/views/chat_shared/chat_delete_sheet.dart': 2,
  'lib/views/chat_shared/chat_gates.dart': 2,
  'lib/views/chat_shared/chat_states.dart': 1,
  'lib/views/chat_shared/contacts_locked_sheet.dart': 2,
  'lib/views/chat_shared/pawfollow_widgets.dart': 2,
  'lib/views/friends/tabs/legacy_tabs.dart': 2,
  'lib/views/map/paw_map_screen.dart': 15,
  'lib/views/map/pets_map_screen.dart': 3,
  'lib/views/map/widgets/create_report_sheet.dart': 1,
  'lib/views/notifications/notification_application_view_screen.dart': 1,
  'lib/views/notifications/notification_sitter_application_card_view_screen.dart': 1,
  'lib/views/notifications/notifications_screen.dart': 2,
  'lib/views/notifications/sitter_notifications_screen.dart': 1,
  'lib/views/payment/airwallex_payment_screen.dart': 2,
  'lib/views/payment/widgets/payment_ui_kit.dart': 3,
  'lib/views/pet_owner/booking-application/owner_booking_detail_screen.dart': 2,
  'lib/views/pet_owner/chat/individual_chat_screen.dart': 2,
  'lib/views/pet_owner/home/widgets/sitter_card.dart': 1,
  'lib/views/pet_owner/home/widgets/walker_card.dart': 1,
  'lib/views/pet_sitter/chat/sitter_individual_chat_screen.dart': 2,
  'lib/views/pet_sitter/home/sitter_homescreen.dart': 2,
  'lib/views/pet_sitter/profile/iban_setup_screen.dart': 2,
  'lib/views/pet_sitter/widgets/pet_post_card.dart': 1,
  'lib/views/pet_sitter/widgets/reservation_request_filter_dialog.dart': 2,
  'lib/views/profile/blocked_users_screen.dart': 1,
  'lib/views/profile/view_task_screen.dart': 2,
  'lib/views/profile/widgets/change_email_sheet.dart': 2,
  'lib/views/profile/widgets/email_change_field.dart': 1,
  'lib/views/reviews/my_reviews_screen.dart': 2,
  'lib/views/reviews/reviews_screen.dart': 4,
  'lib/views/shared/handover_proof_sheet.dart': 4,
  'lib/views/shared/widgets/home_empty_kit.dart': 1,
  'lib/views/wallet/wallet_screen.dart': 1,
  'lib/widgets/address_share_card.dart': 3,
  'lib/widgets/pawfollow_request_card.dart': 2,
  'lib/widgets/pawpass_required_dialog.dart': 2,
  'lib/widgets/pet_enriched_fields.dart': 1,
  'lib/widgets/phone_share_card.dart': 2,
  'lib/widgets/promo_code_sheet.dart': 1,
  'lib/widgets/service_confirmation_card.dart': 1,
};

/// Couleurs grises (saturation HSL < 0,25, luminosité 12–92 %) encore présentes, par fichier.
const Map<String, int> kGrayColorsAllowed = <String, int>{
};
