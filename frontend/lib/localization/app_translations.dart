import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../utils/storage_keys.dart';

/// Centralizes supported locales and translation keys for the app.
class LocalizationService {
  LocalizationService._();

  /// Storage key for persisting the selected language code.
  static const String _languageCodeKey = StorageKeys.languageCode;

  /// Fallback locale when nothing is stored or device locale is unsupported.
  static const Locale fallbackLocale = Locale('en', 'US');

  /// Mapping from simple language codes to concrete [Locale]s.
  static final Map<String, Locale> _supportedLocaleMap = <String, Locale>{
    'en': const Locale('en', 'US'),
    'fr': const Locale('fr', 'FR'),
    'es': const Locale('es', 'ES'),
    'de': const Locale('de', 'DE'),
    'it': const Locale('it', 'IT'),
    'pt': const Locale('pt', 'PT'),
  };

  /// Human‑readable language names used in selection UIs.
  static final Map<String, String> languageLabels = <String, String>{
    'en': 'English',
    'fr': 'Français',
    'es': 'Español',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
  };

  /// All supported locales for Flutter / GetX.
  static List<Locale> get supportedLocales =>
      _supportedLocaleMap.values.toList(growable: false);

  /// Determine the initial locale using persisted value, then device locale.
  static Locale getInitialLocale() {
    final storage = GetStorage();
    final storedCode = storage.read<String>(_languageCodeKey);

    if (storedCode != null && _supportedLocaleMap.containsKey(storedCode)) {
      return _supportedLocaleMap[storedCode]!;
    }

    final deviceLocale = Get.deviceLocale;
    if (deviceLocale != null &&
        _supportedLocaleMap.containsKey(deviceLocale.languageCode)) {
      return _supportedLocaleMap[deviceLocale.languageCode]!;
    }

    return fallbackLocale;
  }

  /// Persist and apply the new locale at runtime.
  static Future<void> updateLocale(String languageCode) async {
    final storage = GetStorage();
    final locale = _supportedLocaleMap[languageCode] ?? fallbackLocale;
    await storage.write(_languageCodeKey, languageCode);
    Get.updateLocale(locale);
  }

  /// Returns the simple language code currently persisted, or the fallback.
  static String getCurrentLanguageCode() {
    final storage = GetStorage();
    final storedCode = storage.read<String>(_languageCodeKey);
    if (storedCode != null && _supportedLocaleMap.containsKey(storedCode)) {
      return storedCode;
    }
    return fallbackLocale.languageCode;
  }
}

/// GetX translations for the app, organized by locale key.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
    'en_US': <String, String>{
      // General
      'common_yes': 'Yes',
      'common_no': 'No',
      'common_cancel': 'Cancel',
      'common_error': 'Error',
      'common_success': 'Success',
      'common_select_value': 'Select value',
      'label_not_available': 'N/A',
      'common_user': 'User',
      'common_refresh': 'Refresh',
      'common_search': 'Search',

      'Application accepted successfully': 'Application accepted successfully',
      'Application rejected successfully': 'Application rejected successfully',
      'Blocked users saved successfully': 'Blocked users saved successfully',
      'Card saved successfully!': 'Card saved successfully!',
      'Could not detect your location. Please enable location services.':
          'Could not detect your location. Please enable location services.',
      'Could not load nearby sitters. Please try again.':
          'Could not load nearby sitters. Please try again.',
      'Email verified successfully!': 'Email verified successfully!',
      'Failed to add task. Please try again.':
          'Failed to add task. Please try again.',
      'Failed to change password. Please try again.':
          'Failed to change password. Please try again.',
      'Failed to complete profile. Please try again.':
          'Failed to complete profile. Please try again.',
      'Failed to fetch tasks.': 'Failed to fetch tasks.',
      'Failed to get your location. Please try again.':
          'Failed to get your location. Please try again.',
      'Failed to load booking details. Using default pricing.':
          'Failed to load booking details. Using default pricing.',
      'Failed to load pet data. Please try again.':
          'Failed to load pet data. Please try again.',
      'Failed to load pets. Please try again.':
          'Failed to load pets. Please try again.',
      'Failed to load profile data. Please try again.':
          'Failed to load profile data. Please try again.',
      'Failed to load sitter details. Please try again.':
          'Failed to load sitter details. Please try again.',
      'Failed to pick image. Please try again.':
          'Failed to pick image. Please try again.',
      'Failed to pick passport image. Please try again.':
          'Failed to pick passport image. Please try again.',
      'Failed to pick pet pictures or videos. Please try again.':
          'Failed to pick pet pictures or videos. Please try again.',
      'Failed to pick pet profile image. Please try again.':
          'Failed to pick pet profile image. Please try again.',
      'Failed to save card. Please try again.':
          'Failed to save card. Please try again.',
      'Failed to start conversation. Please try again.':
          'Failed to start conversation. Please try again.',
      'Failed to submit review. Please try again.':
          'Failed to submit review. Please try again.',
      'Failed to switch role. Please try again.':
          'Failed to switch role. Please try again.',
      'Height is required.': 'Height is required.',
      'Height must be greater than 0.': 'Height must be greater than 0.',
      'Hourly rate must be greater than 0.':
          'Hourly rate must be greater than 0.',
      'Image uploaded successfully!': 'Image uploaded successfully!',
      'Password changed successfully!': 'Password changed successfully!',
      'Passwords do not match': 'Passwords do not match',
      'Pet profile created but media upload failed. You can add media later.':
          'Pet profile created but media upload failed. You can add media later.',
      'Pet profile created successfully!': 'Pet profile created successfully!',
      'Pet profile updated successfully!': 'Pet profile updated successfully!',
      'Please accept the Terms and Conditions':
          'Please accept the Terms and Conditions',
      'Please agree to the Terms and Conditions':
          'Please agree to the Terms and Conditions',
      'Please enter a new password.': 'Please enter a new password.',
      'Please enter the complete verification code':
          'Please enter the complete verification code',
      'Please enter your PayPal email.': 'Please enter your PayPal email.',
      'Please fill in all fields correctly.':
          'Please fill in all fields correctly.',
      'Please fill in all required fields':
          'Please fill in all required fields',
      'Please fill in at least one field.':
          'Please fill in at least one field.',
      'Please fix the highlighted fields and try again.':
          'Please fix the highlighted fields and try again.',
      'Please try logging in again': 'Please try logging in again',
      'Please verify your email to continue.':
          'Please verify your email to continue.',
      'Profile completed successfully!': 'Profile completed successfully!',
      'Profile picture updated successfully!':
          'Profile picture updated successfully!',
      'Profile updated successfully!': 'Profile updated successfully!',
      'Review submitted successfully!': 'Review submitted successfully!',
      'Selected image file is not accessible. Please try again.':
          'Selected image file is not accessible. Please try again.',
      'Sitter blocked successfully!': 'Sitter blocked successfully!',
      'Something went wrong. Please try again.':
          'Something went wrong. Please try again.',
      'Something went wrong. Please try logging in again.':
          'Something went wrong. Please try logging in again.',
      'Task added successfully!': 'Task added successfully!',
      'Unknown user role. Please try again.':
          'Unknown user role. Please try again.',
      'Verification code has been resent to your email':
          'Verification code has been resent to your email',
      'Verification code resent': 'Verification code resent',
      'Welcome back!': 'Welcome back!',
      'You have already reviewed this sitter. You can only submit one review per sitter.':
          'You have already reviewed this sitter. You can only submit one review per sitter.',
      'Your city (@city) has been detected':
          'Your city (@city) has been detected',
      'Profile updated but image upload failed. Please try again.':
          'Profile updated but image upload failed. Please try again.',
      'Profile updated but image upload failed: @error':
          'Profile updated but image upload failed: @error',

      // Posts / Comments
      'post_action_like': 'Like',
      'post_action_comment': 'Comment',
      'post_action_share': 'Share',
      'post_comments_title': 'Comments',
      'post_comments_hint': 'Add a comment...',
      'post_comments_empty_title': 'No comments yet',
      'post_comments_empty_subtitle': 'Be the first to comment!',
      'post_comment_added_success': 'Comment added successfully!',
      'post_comment_add_failed': 'Failed to add comment. Please try again.',
      'post_comments_count_singular': '@count comment',
      'post_comments_count_plural': '@count comments',

      // Relative time
      'time_days_ago': '@count d ago',
      'time_hours_ago': '@count h ago',
      'time_minutes_ago': '@count m ago',
      'time_just_now': 'Just now',
      'posts_empty_title': 'No posts available',
      'posts_load_failed': 'Failed to load posts. Please try again.',
      'posts_like_login_required': 'Please login to like posts.',
      'posts_like_failed': 'Failed to like post. Please try again.',
      'posts_unlike_failed': 'Failed to unlike post. Please try again.',
      'application_accept_success': 'Application accepted successfully!',
      'application_reject_success': 'Application rejected successfully!',
      'application_action_failed':
          'Failed to respond to application. Please try again.',
      'request_card_pet_owner': 'Pet Owner: @name',
      'sitter_reservation_requests': 'Reservation requests',
      'sitter_filters': 'Filters',
      'sitter_filters_on': 'Filters on',
      'sitter_no_requests_match': 'No requests match your filters.',
      'filter_requests_title': 'Filter requests',
      'filter_clear': 'Clear',
      'filter_apply': 'Apply',
      'filter_location': 'Location',
      'filter_service_type': 'Service type',
      'filter_dates': 'Dates',
      'filter_city_hint': 'City or area',
      'filter_any_dates': 'Any dates',

      // Profile: Apple connection
      'profile_connect_with_apple': 'Connect with Apple',
      'profile_connection_connected': 'Connected',

      // Auth / Sign up
      'sign_up_as_pet_owner': 'Sign Up as Pet Owner',
      'sign_up_as_pet_sitter': 'Sign Up as Pet Sitter',
      'label_name': 'Name',
      'hint_name': 'Enter your name',
      'label_email': 'Email',
      'hint_email': 'Enter your email',
      'label_mobile_number': 'Mobile Number',
      'hint_phone': 'Enter your phone number',
      'profile_no_phone_added': 'No phone added',
      'profile_no_email_added': 'No email added',
      'label_password': 'Password',
      'hint_password': 'Create a password',
      'password_requirement':
          'Must be at least 8 characters and contain upper, lower case letters and a number.',
      'label_language': 'Language',
      'hint_language': 'Enter languages you speak',
      'label_address': 'Address',
      'hint_address': 'Location',
      'label_rate_per_hour': 'Rate Per Hour',
      'hint_rate_per_hour': 'e.g., 20',
      'price_per_hour': 'Price / hour',
      'price_per_day': 'Price / day',
      'price_per_week': 'Price / week',
      'price_per_month': 'Price / month',
      'chat_payment_required_banner': 'Chat opens after the booking is paid.',
      'chat_pay_now_button': 'Pay now',
      'chat_share_phone_button': 'Share my phone',
      'terms_read_button': 'Read the Terms & Conditions',
      'service_prefs_at_owner_label': 'I accept service at my home',
      'service_prefs_at_sitter_label': 'I accept service at the sitter\'s home',
      'service_location_label': 'Where should the service happen?',
      'service_location_at_owner': 'At my home',
      'service_location_at_sitter': 'At the sitter\'s home',
      'service_location_both': 'Either',
      'profile_my_availability': 'My availability calendar',
      'profile_verify_identity': 'Verify my identity',
      'profile_identity_verified': 'Identity verified',
      'theme_setting_title': 'Theme',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'theme_system': 'Follow system',
      'common_close': 'Close',
      'label_skills': 'Skills',
      'hint_skills': 'Veterinarian, Educator',
      'label_bio': 'Bio',
      'hint_bio': 'Tell us about yourself',
      'label_terms_prefix': 'I accept the ',
      'label_terms_title': 'Terms & Privacy Policy.',
      'or_sign_up_with': 'Or sign up with',
      'button_google': 'Google',
      'button_apple': 'Apple',
      'button_create_account': 'Create Account',
      'button_creating_account': 'Creating Account...',
      'button_logout': 'Logout',
      'title_login': 'Log in',
      'welcome_back': 'Welcome back 👋',
      'login_subtitle': 'Log in to continue to Hopetsit.',
      'hint_password_login': 'Enter your password',
      'forgot_password': 'Forgot password?',
      'forgot_password_reset_title': 'Reset your password',
      'forgot_password_reset_message':
          'Enter your email address and we\'ll send you a code to reset your password.',
      'forgot_password_email_label': 'Email address',
      'forgot_password_sending_code': 'Sending code...',
      'forgot_password_send_code': 'Send verification code',
      'forgot_password_remember': 'Remember your password? ',
      'forgot_password_otp_sent_title': 'OTP Sent',
      'forgot_password_otp_sent_message':
          'Verification code has been sent to your email',
      'forgot_password_request_failed': 'Request Failed',
      'forgot_password_verified_title': 'Verified',
      'forgot_password_verified_message': 'You can now reset your password',
      'forgot_password_verification_failed': 'Verification Failed',
      'forgot_password_reset_success':
          'Your password has been reset successfully',
      'forgot_password_reset_failed': 'Reset Failed',
      'forgot_password_code_resent_title': 'Code Resent',
      'forgot_password_code_resent_message':
          'Verification code has been resent to your email',
      'forgot_password_resend_failed': 'Resend Failed',
      'forgot_password_verify_code_title': 'Verify code',
      'forgot_password_enter_code_title': 'Enter verification code',
      'forgot_password_code_sent_to': 'We\'ve sent a 6-digit code to @email',
      'forgot_password_verifying': 'Verifying...',
      'forgot_password_resend_in': 'Resend code in @seconds s',
      'forgot_password_resend_code': 'Resend code',
      'forgot_password_wrong_email': 'Wrong email? ',
      'forgot_password_change_email': 'Change it',
      'forgot_password_create_new_title': 'Create new password',
      'forgot_password_set_new_title': 'Set your new password',
      'forgot_password_set_new_message':
          'Create a strong password to secure your account. Make sure it\'s at least 8 characters long.',
      'forgot_password_new_hint': 'Enter new password',
      'forgot_password_confirm_hint': 'Re-enter your password',
      'forgot_password_resetting': 'Resetting password...',
      'forgot_password_reset_button': 'Reset password',
      'forgot_password_reset_success_title': 'Password reset successful!',
      'forgot_password_reset_success_message':
          'Your password has been successfully reset. You can now log in with your new password.',
      'forgot_password_email_verified_title': 'Email verified',
      'forgot_password_email_verified_subtitle': 'Your email has been verified',
      'forgot_password_password_updated_title': 'Password updated',
      'forgot_password_password_updated_subtitle':
          'Your password has been changed',
      'forgot_password_login_new_password': 'Log in with new password',
      'forgot_password_security_warning':
          'If you didn\'t request this change, please secure your account immediately.',
      'logging_in': 'Logging in...',
      'or_continue_with': 'Or continue with',
      'dont_have_account': "Don't have an account? ",
      'sign_up': 'Sign Up',
      // Onboarding screen
      'onboarding_app_title': 'Home Pets Sitting',
      'onboarding_continue_with_google': 'Continue with Google',
      'onboarding_continue_with_apple': 'Continue with Apple',
      'onboarding_have_account': 'Have an account?',

      // Validation / errors
      'error_invalid_details_title': 'Invalid Details',
      'error_invalid_details_message':
          'Please fix the highlighted fields and try again.',
      'error_terms_required_title': 'Terms Required',
      'error_terms_required_message':
          'Please agree to the Terms and Conditions',
      'error_name_required': 'Please enter your name',
      'error_name_length': 'Name must be at least 2 characters',
      'error_email_required': 'Please enter your email',
      'error_email_invalid': 'Please enter a valid email',
      'error_phone_invalid': 'Please enter a valid phone number',
      'error_phone_required': 'Please enter your phone number',
      'error_password_required': 'Please enter a password',
      'error_password_length': 'Password must be at least 8 characters long',
      'error_password_uppercase':
          'Password must contain at least one uppercase letter',
      'error_password_lowercase':
          'Password must contain at least one lowercase letter',
      'error_password_number': 'Password must contain at least one number',
      'error_password_confirm_required': 'Please confirm your password',
      'error_password_match': 'Passwords do not match',
      'error_otp_required': 'OTP is required',
      'error_otp_length': 'OTP must be 6 digits',
      'error_otp_numbers_only': 'OTP must contain only numbers',
      'common_error_generic': 'Something went wrong. Please try again.',
      'error_address_required': 'Please enter your address',
      'error_address_length': 'Address must be at least 2 characters',
      'error_rate_required': 'Please enter your rate per hour',
      'error_rate_invalid': 'Please enter a valid rate',
      'error_rate_zero': 'Hourly rate cannot be 0',
      'error_skills_required': 'Please enter your skills',
      'error_skills_length': 'Skills must be at least 2 characters',

      // Location
      'location_found_title': 'Location Found',
      'location_found_message': 'Your city (@city) has been detected',
      'location_not_found_title': 'Location Not Found',
      'location_not_found_message':
          'Could not detect your location. Please enable location services.',
      'location_error_title': 'Error',
      'location_error_message':
          'Failed to get your location. Please try again.',
      // Location picker
      'label_city': 'City',
      'location_getting': 'Getting...',
      'location_auto': 'Auto',
      'location_map': 'Map',
      'location_detected': 'Detected: @city',
      'location_enter_city': 'Enter your city',
      'error_city_required': 'Please enter your city',
      'location_detected_message':
          'Your location has been detected. You\'ll be connected with service providers in this area.',
      'location_select_title': 'Select Location',
      'location_selected': 'Selected Location',
      'location_selected_city': 'Selected City',
      'location_no_city': 'No city selected',
      'location_latitude': 'Latitude: @value',
      'location_longitude': 'Longitude: @value',
      'location_current': 'Current',
      'location_confirm': 'Confirm',
      'location_select_error': 'Please select a location',
      'location_get_error': 'Unable to get your location',

      // Signup flow
      'signup_account_created_title': 'Account Created',
      'signup_account_created_message': 'Please verify your email to continue.',
      'signup_failed_title': 'Sign Up Failed',
      'signup_failed_generic_message':
          'Something went wrong. Please try again.',

      // Profile / language
      'language_dialog_title': 'Choose Language',
      'language_dialog_message': 'Select your preferred language for the app.',
      'language_updated_title': 'Language Updated',
      'language_updated_message': 'App language has been changed.',
      'title_profile': 'Profile',
      'edit_profile_title': 'Edit Profile',
      'edit_profile_button': 'Update Profile',
      'edit_profile_button_updating': 'Updating Profile...',
      // Choose service screen
      'choose_service_title': 'Choose a Service',
      'choose_service_choose_all': 'Choose all',
      'choose_service_saving': 'Saving...',
      'choose_service_selecting': 'Selecting...',
      'choose_service_save': 'Save',
      'choose_service_continue': 'Continue',
      'choose_service_card_pet_sitting_title': 'Pet Sitting',
      'choose_service_card_house_sitting_title': 'House Sitting',
      'choose_service_card_day_care_title': 'Day Care',
      'choose_service_card_dog_walking_title': 'Dog Walking',
      'choose_service_card_subtitle_at_owners_home': "At owner's home",
      'choose_service_card_subtitle_in_your_home': 'In your Home',
      'choose_service_card_subtitle_in_neighborhood': 'In your neighborhood',
      'section_settings': 'Settings',
      'role_pet_owner': 'Pet Owner',
      'role_pet_sitter': 'Pet Sitter',
      'auth_role_pet_owner': 'Pet Owner',
      'auth_role_pet_sitter': 'Pet Sitter',
      'profile_add_tasks': 'Add Tasks',
      'profile_view_tasks': 'View Tasks',
      'profile_bookings_history': 'Bookings History',
      'profile_edit_profile': 'Edit Profile',
      'profile_edit_pets_profile': 'Edit Pets Profile',
      'profile_choose_service': 'Choose Service',
      'profile_change_password': 'Change Password',
      'profile_change_language': 'Change Language',
      'profile_blocked_users': 'Blocked Users',
      'profile_delete_account': 'Delete Account',
      'profile_donate_us': 'Donate Us',
      'blocked_users_title': 'Blocked Users',
      'blocked_users_empty_title': 'No blocked users',
      'blocked_users_empty_message': 'Users you block will appear here',
      'blocked_users_unblock_button': 'Unblock',
      'blocked_users_unblock_dialog_message':
          'Are you sure you want to unblock @name?',
      'delete_account_dialog_message':
          'Are you sure you want to delete your account? This action cannot be undone.',
      'delete_account_success_title': 'Account Deleted',
      'delete_account_success_message':
          'Your account has been deleted successfully',
      'delete_account_failed_title': 'Delete Failed',
      'delete_account_failed_generic':
          'Something went wrong. Please try again.',
      'logout_dialog_message': 'Are you sure you want to logout?',
      'profile_switch_role_card_title': 'Switch to @role',
      'profile_switch_role_card_description':
          'Switch your account to @role to start receiving requests.',
      'dialog_switch_role_title': 'Switch Role',
      'dialog_switch_role_switching': 'Switching to @role...\n\nPlease wait.',
      'dialog_switch_role_confirm':
          'Are you sure you want to switch to @role?\n\nYou will be able to switch back anytime.',
      'dialog_switch_role_button': 'Switch to @role',
      'profile_switch_to_sitter': 'Switch to Pet Sitter',
      'profile_switch_to_owner': 'Switch to Pet Owner',
      'profile_switch_to_sitter_description':
          'Switch your account to Pet Sitter to start receiving requests.',
      'profile_switch_to_owner_description':
          'Switch your account to Pet Owner to start receiving requests.',
      'profile_switch_role_dialog_title': 'Switch Role',
      'profile_switch_to_sitter_loading':
          'Switching to Pet Sitter...\n\nPlease wait.',
      'profile_switch_to_owner_loading':
          'Switching to Pet Owner...\n\nPlease wait.',
      'profile_switch_to_sitter_confirm':
          'Are you sure you want to switch to Pet Sitter?\n\nYou will be able to switch back anytime.',
      'profile_switch_to_owner_confirm':
          'Are you sure you want to switch to Pet Owner?\n\nYou will be able to switch back anytime.',
      'common_continue': 'Continue',
      'common_cancelled': 'Cancelled',
      'common_coming_soon': 'Coming Soon',
      'common_go_to_home': 'Go to Home',
      'common_back_to_home': 'Back to Home',
      'error_login_required': 'Please login again',
      'error_email_not_found': 'User email not found. Please login again.',
      'profile_load_error': 'Failed to load profile',
      'blocked_users_unblock_success': 'User unblocked successfully',
      'blocked_users_save_success': 'Blocked users saved successfully',
      'donate_coming_soon': 'Donate feature will be available soon',
      'stripe_connect_title': 'Connect Stripe Account',
      'payout_status_screen_title': 'Payout Status',
      'payout_connect_stripe_account': 'Connect Stripe Account',
      'payout_paypal_email_title': 'PayPal Payout Email',
      'payout_status_saved': 'Saved',
      'payout_status_not_set': 'Not Set',
      'payout_paypal_email_hint': 'Add an email to receive payouts via PayPal.',
      'payout_add_paypal_email_title': 'Add PayPal payout email',
      'payout_add_paypal_email_subtitle':
          'Set the email where you want to receive payouts. You can update it later from Payout Status.',
      'payout_update_paypal_email': 'Update PayPal Email',
      'payout_paypal_dialog_subtitle':
          'This email will be used for PayPal payouts. Make sure it matches your PayPal account.',
      'payout_stripe_connect_title': 'Stripe Connect',
      'payout_status_connected': 'Connected',
      'payout_status_not_connected': 'Not Connected',
      'payout_stripe_connected_message':
          'Your Stripe account is connected and ready to receive payments.',
      'payout_stripe_not_connected_message':
          'Connect your Stripe account to start receiving payouts.',
      'payout_account_id_label': 'Account ID',
      'payout_verification_title': 'Verification Status',
      'payout_status_title': 'Payout Status',
      'payout_verification_step_identity': 'Identity verification',
      'payout_verification_step_bank': 'Bank account verification',
      'payout_verification_step_business': 'Business information',
      'payout_next_payout_label': 'Next Payout',
      'payout_schedule_label': 'Payout Schedule',
      'payout_schedule_daily': 'Daily',
      'payout_minimum_amount_label': 'Minimum Amount',
      'payout_status_verified': 'Verified',
      'payout_status_pending': 'Pending',
      'payout_status_rejected': 'Rejected',
      'payout_status_not_started': 'Not Started',
      'payout_status_active': 'Active',
      'payout_status_restricted': 'Restricted',
      'payout_verification_message_verified':
          'Your account has been verified. You can now receive payouts.',
      'payout_verification_message_pending':
          'Your verification is being reviewed. This usually takes 1-2 business days.',
      'payout_verification_message_rejected':
          'Your verification was rejected. Please update your information and try again.',
      'payout_verification_message_not_started':
          'Please complete the verification process to start receiving payouts.',
      'payout_message_active':
          'Your payouts are active. Earnings will be transferred to your bank account daily.',
      'payout_message_pending':
          'Your payout account is being set up. This may take a few business days.',
      'payout_message_restricted':
          'Your payouts are currently restricted. Please contact support for assistance.',
      'payout_message_not_connected':
          'Connect your Stripe account to start receiving payouts.',
      'stripe_get_paid_title': 'Get Paid with Stripe',
      'stripe_connect_description':
          'Connect your Stripe account to receive payments directly from pet owners. Your earnings will be transferred to your bank account.',
      'stripe_account_status_title': 'Account Status',
      'stripe_continue_onboarding': 'Continue Onboarding',
      'stripe_connect_account_button': 'Connect Stripe Account',
      'stripe_benefit_secure': 'Secure payment processing',
      'stripe_benefit_fast_payouts': 'Fast payouts to your bank account',
      'stripe_benefit_no_fees': 'No setup fees',
      'stripe_benefit_support': '24/7 customer support',
      'stripe_benefit_required': 'Required to receive payments from pet owners',
      'stripe_account_connected': 'Account Connected',
      'stripe_account_created_pending': 'Account Created - Onboarding Pending',
      'stripe_account_created': 'Account Created',
      'stripe_account_connected_message':
          'Your Stripe account is fully set up and ready to receive payments.',
      'stripe_account_created_message':
          'Your Stripe account has been created. Please complete the onboarding process to start receiving payments.',
      'stripe_account_created_partial_message':
          'Your payment account has been created. Some verification steps are remaining. You can complete them in your account settings.',
      'stripe_account_id_label': 'Account ID',
      'stripe_loading_onboarding': 'Loading Stripe onboarding...',
      'stripe_account_connected_success':
          'Stripe account connected successfully!',
      'stripe_onboarding_completed': 'Stripe onboarding completed!',
      'stripe_onboarding_cancelled': 'Stripe onboarding was cancelled.',
      'stripe_onboarding_load_error':
          'Failed to load Stripe onboarding page: @error',
      'stripe_cancel_onboarding_title': 'Cancel Onboarding?',
      'stripe_cancel_onboarding_message':
          'Are you sure you want to cancel Stripe onboarding? You can complete it later from settings.',
      'stripe_connect_payment_title': 'Connect Your Payment Account',
      'stripe_connect_payment_description':
          'To start receiving payments as a Pet Sitter, you need to connect your payment account. This is a required step to complete your profile setup.',
      'stripe_connect_payment_partial_description':
          'Your payment account has been created. Some verification steps are remaining. You can complete them later in your account settings.',
      'stripe_connect_payment_partial_info':
          'Your account is connected, but some verification steps are remaining. You can complete them in your account settings.',
      'stripe_payment_connected_success': 'Payment Connected Successfully!',
      'stripe_connect_now': 'Connect Now',
      'stripe_already_connected': 'Already Connected',
      'stripe_already_connected_message':
          'Your Stripe account is already connected and active.',
      'stripe_connect_error':
          'Failed to connect Stripe account. Please try again.',
      'stripe_no_onboarding_url':
          'No onboarding URL available. Please create a Stripe account first.',
      'stripe_onboarding_expired_title': 'Expired',
      'stripe_onboarding_expired_message':
          'The onboarding link has expired. Please create a new one.',
      'stripe_disconnect_success': 'Stripe account disconnected successfully!',
      'stripe_disconnect_error':
          'Failed to disconnect Stripe account. Please try again.',
      'payment_title': 'Payment',
      'payment_info_message':
          'Click "Pay" below to securely enter your payment details using Stripe\'s secure payment form.',
      'payment_paypal_info':
          'You will be redirected to PayPal to approve the payment, then we will confirm it here.',
      'payment_pay_with_stripe': 'Pay with Stripe @amount',
      'payment_pay_with_paypal': 'Pay with PayPal @amount',
      'payment_method_paypal': 'PayPal',
      'payment_pay_button': 'Pay @amount',
      'payment_amount_label': 'Amount to Pay',
      'payment_loading_page': 'Loading payment page...',
      'payment_cancel_title': 'Cancel Payment?',
      'payment_cancel_message': 'Are you sure you want to cancel this payment?',
      'payment_continue': 'Continue Payment',
      'payment_load_error': 'Failed to load payment page: @error',
      'payment_success_title': 'Payment Successful!',
      'payment_failed_title': 'Payment Failed',
      'payment_success_message':
          'Your payment has been processed successfully.',
      'payment_rate_sitter': 'Rate the sitter',
      'payment_try_again': 'Try Again',
      'payment_transaction_details': 'Transaction Details',
      'payment_transaction_id_label': 'Transaction ID',
      'payment_date_label': 'Date',
      'payment_error_client_secret_missing':
          'Failed to create payment intent. Client secret is missing.',
      'payment_error_publishable_key_missing':
          'Stripe publishable key missing.',
      'payment_error_invalid_publishable_key':
          'Invalid Stripe publishable key.',
      'payment_processing_failed':
          'Payment processing failed. Please try again.',
      'payment_error_title': 'Payment Error',
      'payment_unavailable_title': 'Payment Unavailable',
      'payment_unavailable_message':
          'The sitter\'s Stripe account is not fully verified yet. They need to complete their account verification (including identity, bank account, and business details) before they can receive payments. Please contact the sitter to complete their Stripe account setup.',
      'payment_invalid_amount_title': 'Invalid Amount',
      'payment_invalid_amount_message':
          'The payment amount is invalid. Please contact support.',
      'payment_initiate_error': 'Failed to initiate payment. Please try again.',
      'payment_confirmation_failed':
          'Payment confirmation failed. Please contact support.',
      'review_already_reviewed_title': 'Already Reviewed',
      'review_already_reviewed_message':
          'You have already reviewed this sitter. You can only submit one review per sitter.',
      'sitter_applications_tab': 'Applications',
      'sitter_no_bookings_found': 'No bookings found',
      'sitter_application_accepted_success':
          'Application accepted successfully',
      'sitter_application_accept_failed':
          'Failed to accept application. Please try again.',
      'sitter_application_rejected_success':
          'Application rejected successfully',
      'sitter_application_reject_failed':
          'Failed to reject application. Please try again.',
      'sitter_chat_start_failed':
          'Failed to start conversation. Please try again.',
      'sitter_chat_with_owner': 'Chat with Owner',
      'sitter_pet_weight': 'Weight',
      'sitter_pet_height': 'Height',
      'sitter_pet_color': 'Color',
      'sitter_not_yet_available': 'Not yet available',
      'sitter_detail_date': 'Date',
      'sitter_detail_time': 'Time',
      'sitter_detail_phone': 'Phone',
      'sitter_detail_email': 'Email',
      'sitter_detail_location': 'Location',
      'sitter_not_available_yet': 'Not available yet',
      'sitter_reject': 'Reject',
      'sitter_accept': 'Accept',
      'sitter_status_label': 'Status: @status',
      'sitter_payment_status_label': 'Payment: @status',
      'sitter_time_just_now': 'Just now',
      'sitter_time_mins_ago': '@minutes mins ago',
      'sitter_time_hours_ago': '@hours hours ago',
      'sitter_time_days_ago': '@days days ago',
      'sitter_weekday_mon': 'Mon',
      'sitter_weekday_tue': 'Tue',
      'sitter_weekday_wed': 'Wed',
      'sitter_weekday_thu': 'Thu',
      'sitter_weekday_fri': 'Fri',
      'sitter_weekday_sat': 'Sat',
      'sitter_weekday_sun': 'Sun',
      'sitter_month_jan': 'Jan',
      'sitter_month_feb': 'Feb',
      'sitter_month_mar': 'Mar',
      'sitter_month_apr': 'Apr',
      'sitter_month_may': 'May',
      'sitter_month_jun': 'Jun',
      'sitter_month_jul': 'Jul',
      'sitter_month_aug': 'Aug',
      'sitter_month_sep': 'Sep',
      'sitter_month_oct': 'Oct',
      'sitter_month_nov': 'Nov',
      'sitter_month_dec': 'Dec',
      'sitter_service_long_term_care': 'Long Term Care',
      'sitter_service_dog_walking': 'Dog Walking',
      'sitter_service_overnight_stay': 'Overnight Stay',
      'sitter_service_home_visit': 'Home Visit',
      'sitter_request_details_title': 'Request Details',
      'sitter_requests_section': 'Requests',
      'sitter_info_pets': 'Pets',
      'sitter_no_pets': 'No pets',
      'sitter_info_service': 'Service',
      'sitter_no_service_type': 'No service type available',
      'sitter_info_date': 'Date',
      'sitter_no_date_available': 'No date available',
      'sitter_pets_section': 'Pets',
      'sitter_note_section': 'Note',
      'sitter_no_note_provided': 'No note provided.',
      'sitter_decline': 'Decline',
      'owner_booking_details_title': 'Booking Details',
      'owner_service_provider_section': 'Service Provider',
      'owner_info_pets': 'Pets',
      'owner_no_pets': 'No pets',
      'owner_info_service': 'Service',
      'owner_no_service_type': 'No service type available',
      'owner_info_date': 'Date',
      'owner_no_date_available': 'No date available',
      'owner_info_total_amount': 'Total Amount',
      'owner_pets_section': 'Pets',
      'owner_note_section': 'Note',
      'owner_no_note_provided': 'No note provided.',
      'owner_chat_with_sitter': 'Chat with Sitter',
      'owner_pay_now': 'Pay Now',
      'owner_pay_with_amount': 'Pay \$@amount',
      'owner_cancel_booking': 'Cancel Booking',
      'owner_time_just_now': 'Just now',
      'owner_time_mins_ago': '@minutes mins ago',
      'owner_time_hours_ago': '@hours hours ago',
      'owner_time_days_ago': '@days days ago',
      'owner_weekday_mon': 'Mon',
      'owner_weekday_tue': 'Tue',
      'owner_weekday_wed': 'Wed',
      'owner_weekday_thu': 'Thu',
      'owner_weekday_fri': 'Fri',
      'owner_weekday_sat': 'Sat',
      'owner_weekday_sun': 'Sun',
      'owner_month_jan': 'Jan',
      'owner_month_feb': 'Feb',
      'owner_month_mar': 'Mar',
      'owner_month_apr': 'Apr',
      'owner_month_may': 'May',
      'owner_month_jun': 'Jun',
      'owner_month_jul': 'Jul',
      'owner_month_aug': 'Aug',
      'owner_month_sep': 'Sep',
      'owner_month_oct': 'Oct',
      'owner_month_nov': 'Nov',
      'owner_month_dec': 'Dec',
      'owner_service_long_term_care': 'Long Term Care',
      'owner_service_dog_walking': 'Dog Walking',
      'owner_service_overnight_stay': 'Overnight Stay',
      'owner_service_home_visit': 'Home Visit',
      'owner_rating_with_reviews': '@rating (@count reviews)',
      'owner_pet_needs_medication': 'Needs medication / @medication',
      // Home screen & applications
      'home_default_user_name': 'User',
      'home_no_sitters_message': 'No sitters available at the moment.',
      'home_block_sitter_message':
          'Are you sure you want to block @name? You won\'t be able to see their profile or send requests.',
      'home_block_sitter_yes': 'Cancel',
      'home_block_sitter_no': 'Block',
      'status_available': 'available',
      'applications_tab_title': 'Applications',
      'bookings_tab_title': 'Bookings',
      'applications_empty_message': 'No applications found',
      'bookings_empty_message': 'No booking found',
      'booking_cancel_dialog_message':
          'Are you sure you want to cancel this booking?',
      // Common UI
      'common_select': 'Select',
      'common_save': 'Save',
      'common_later': 'Later',
      'common_saving': 'Saving...',
      // Expandable post input
      'post_input_label': 'Post',
      'post_input_hint': 'Write your post here...',
      'post_button': 'Post',
      'post_button_posting': 'Posting...',
      'my_posts_title': 'My Posts',
      'home_segment_sitters': 'Pet Sitters',
      'my_posts_no_posts': 'No posts found',
      'my_posts_delete_title': 'Delete post?',
      'my_posts_delete_message':
          'Are you sure you want to delete this post? This action cannot be undone.',
      'my_posts_delete_success': 'Post deleted successfully.',
      'my_posts_delete_failed': 'Failed to delete post. Please try again.',
      'my_posts_sort_label': 'Sort',
      'my_posts_sort_newest': 'Newest first',
      'my_posts_sort_oldest': 'Oldest first',
      'notifications_title': 'Notifications',
      'notifications_empty_title': 'No notifications yet',
      'notifications_empty_subtitle':
          'When something happens, you will see it here.',
      'notifications_mark_all_read': 'Mark all read',
      'notifications_load_failed': 'Could not load notifications.',
      'notifications_fallback_title': 'Notification',
      'notifications_post_view_title': 'Post',
      'notifications_request_view_title': 'Sitter request',
      'notifications_application_not_found':
          'This request is no longer available or could not be loaded.',
      'notifications_open_sitter_profile': 'View sitter profile',
      'notifications_loading': 'Loading notifications…',
      'notifications_loading_more': 'Loading more…',
      'post_action_delete': 'Delete',
      'post_request_default': 'Looking for a pet sitter',
      // Tasks screens
      'view_task_title': 'View Task',
      'view_task_empty': 'No tasks found',
      'view_task_date_not_available': 'Date not available',
      'add_task_title': 'Add Task',
      'add_task_title_label': 'Title',
      'add_task_title_hint': 'Enter title',
      'add_task_description_label': 'Description',
      'add_task_description_hint': 'Text...',
      'add_task_save_button': 'Save',
      'add_task_saving': 'Saving...',
      // Change password
      'change_password_title': 'Change Password',
      'change_password_new_label': 'New Password',
      'change_password_confirm_label': 'Confirm Password',
      'change_password_confirm_hint': 'Confirm Password',
      // Add card
      'add_card_title': 'Add Card',
      'add_card_holder_label': 'Card holder name',
      'add_card_holder_hint': 'John Smith',
      'add_card_number_label': 'Card Number',
      'add_card_number_hint': '0987 0986 5543 0980',
      'add_card_exp_label': 'Exp Date',
      'add_card_exp_hint': '10/23',
      'add_card_cvc_label': 'CVC',
      'add_card_cvc_hint': '345',
      // My pets
      'my_pets_title': 'My Pets',
      'my_pets_add_pet': 'Add Pet',
      'my_pets_error_loading': 'Error loading pets',
      'my_pets_retry': 'Retry',
      'my_pets_empty': 'No pets found',
      'my_pets_color_label': 'Color',
      'my_pets_profile_label': 'Profile',
      'my_pets_passport_label': 'Passport',
      'my_pets_chip_label': 'Chip',
      'my_pets_allergies_label': 'Allergies',
      // Create pet profile
      'create_pet_appbar_title': 'User',
      'create_pet_skip': 'Skip',
      'create_pet_header': 'Create a Pet profile',
      'create_pet_name_label': 'Pet name',
      'create_pet_name_hint': 'Enter your Pet name',
      'create_pet_breed_label': 'Breed',
      'create_pet_breed_hint': 'Enter your Breed',
      'create_pet_dob_label': 'Date of Birth',
      'create_pet_dob_hint': 'Enter your pet\'s date of birth',
      'create_pet_weight_label': 'Weight (KG)',
      'create_pet_weight_hint': 'eg 12kgs',
      'create_pet_height_label': 'Height (CM)',
      'create_pet_height_hint': 'eg 50cms',
      'create_pet_passport_label': 'Passport number',
      'create_pet_passport_hint': 'Enter Passport number',
      'create_pet_chip_label': 'Chip number',
      'create_pet_chip_hint': 'Enter Chip number',
      'create_pet_med_allergies_label': 'Medication Allergies',
      'create_pet_med_allergies_hint': 'Enter Medication Allergies',
      'create_pet_category_label': 'Category',
      'create_pet_category_dog': 'Dog',
      'create_pet_category_cat': 'Cat',
      'create_pet_category_bird': 'Bird',
      'create_pet_category_rabbit': 'Rabbit',
      'create_pet_category_other': 'Other',
      'create_pet_vaccination_label': 'Vaccination',
      'create_pet_vaccination_up_to_date': 'Up to Date',
      'create_pet_vaccination_not_vaccinated': 'Not Vaccinated',
      'create_pet_vaccination_partial': 'Partially Vaccinated',
      'create_pet_profile_view_label': 'Profile View',
      'create_pet_profile_view_public': 'Public',
      'create_pet_profile_view_private': 'Private',
      'create_pet_profile_view_friends': 'Friends Only',
      'create_pet_upload_media_label': 'Upload pet\'s pictures and videos',
      'create_pet_upload_media_upload': 'Upload',
      'create_pet_upload_media_change': 'Change (@count)',
      'create_pet_upload_media_selected': '@count file(s) selected',
      'create_pet_upload_passport_label': 'Upload pet\'s passport picture',
      'create_pet_upload_passport_change': 'Change',
      'create_pet_upload_passport_upload': 'Upload',
      'create_pet_upload_passport_selected': 'Passport image selected',
      'create_pet_button_creating': 'Creating Profile...',
      'create_pet_button': 'Create Pet\'s Profile',
      // Send request screen
      'send_request_title': 'Send Request',
      'send_request_description_label': 'Description',
      'send_request_description_hint': 'Enter additional details...',
      'label_pets': 'Pets',
      'send_request_no_pets_message': 'No pets. Add a pet to continue.',
      'send_request_pets_select_placeholder': 'Select',
      'send_request_dates_label': 'Dates',
      'send_request_start_label': 'Start',
      'send_request_end_label': 'End',
      'send_request_select_date': 'Select date',
      'send_request_select_time': 'Select time',
      'send_request_service_type_label': 'Service Type',
      'send_request_service_long_term_care': 'Long Term Care',
      'send_request_service_dog_walking': 'Dog Walking',
      'send_request_service_overnight_stay': 'Overnight Stay',
      'send_request_service_home_visit': 'Home Visit',
      'send_request_duration_label': 'Duration (minutes)',
      'send_request_duration_minutes_label': '@minutes min',
      'send_request_button': 'Send Request',
      'send_request_button_sending': 'Sending...',
      'send_request_validation_error_title': 'Validation Error',
      'send_request_invalid_time_title': 'Invalid Time',
      'send_request_invalid_time_message': 'End time must be after start time.',
      // Publish reservation request (owner) - UI only
      'publish_request_home_cta': 'Publish reservation request',
      'publish_request_title': 'Publish Reservation Request',
      'publish_request_select_pets': 'Select pet(s)',
      'publish_request_selected_pets': '@count selected',
      'publish_request_select_pets_title': 'Select pets',
      'publish_request_notes_label': 'Additional notes',
      'publish_request_notes_hint': 'Anything the sitter should know...',
      'publish_request_address_label': 'Address (optional)',
      'publish_request_address_hint': 'Street, building, etc.',
      'publish_request_images_label': 'Images',
      'publish_request_add_images': 'Add images',
      'publish_request_add_more_images': 'Add more images',
      'publish_request_publish_button': 'Publish Request',
      'publish_request_fill_required': 'Please fill in all required fields.',
      'publish_request_ui_only_success': 'Request UI created (not posted yet).',
      'publish_request_success': 'Reservation request published successfully!',
      'publish_request_service_walking': 'Walking',
      'publish_request_service_boarding': 'Boarding',
      'publish_request_service_daycare': 'Daycare',
      'publish_request_service_pet_sitting': 'Pet Sitting',
      'publish_request_service_house_sitting': 'House Sitting',
      'house_sitting_venue_label': 'House Sitting Venue',
      'house_sitting_venue_owners_home': "At owner's home",
      'house_sitting_venue_sitters_home': "At sitter's home",
      // Chat screens
      'chat_error_loading_conversations': 'Error loading conversations',
      'chat_retry': 'Retry',
      'chat_no_conversations': 'No conversations yet',
      'chat_error_loading_messages': 'Error loading messages',
      'chat_no_messages': 'No messages yet. Start the conversation!',
      'chat_input_hint': 'Write a message...',
      'chat_locked_title': 'Chat locked',
      'chat_locked_after_payment':
          'Chat is available only after booking payment is completed.',
      // Pets map screen
      'map_search_hint': 'Search city or area',
      'map_search_empty': 'Please enter a location.',
      'map_search_not_found': 'Could not find location: @query',
      'map_search_failed': 'Search failed. Please try again.',
      'map_offers_near_me': 'Offers near me',
      'map_radius_label': 'Radius:',
      // IBAN payout
      'iban_title': 'Bank Account (IBAN)',
      'iban_info_message': 'Enter your bank account details to receive payouts directly. Your IBAN will be verified before first transfer.',
      'iban_holder_label': 'Account Holder Name',
      'iban_holder_hint': 'Full name as on your bank account',
      'iban_holder_required': 'Account holder name is required.',
      'iban_number_label': 'IBAN Number',
      'iban_number_hint': 'e.g. ES91 2100 0418 4502 0005 1332',
      'iban_number_example': 'Format: Country code + 2 digits + account number',
      'iban_required': 'IBAN number is required.',
      'iban_invalid_format': 'Invalid IBAN format.',
      'iban_bic_label': 'BIC / SWIFT Code',
      'iban_bic_hint': 'e.g. CAIXESBBXXX',
      'iban_bic_required': 'BIC must be at least 8 characters.',
      'iban_save_button': 'Save Bank Account',
      'iban_saved_success': 'Bank account saved! Our team will verify it shortly.',
      'iban_save_failed': 'Failed to save. Please try again.',
      'iban_status_verified': 'Verified — payouts active',
      'iban_status_pending': 'Pending admin verification',
      'iban_security_note': 'Your data is encrypted and securely stored.',
      // IBAN Payout
      'payout_iban_title': 'Bank Payout (IBAN)',
      'payout_iban_info': 'Add your bank account to receive payments directly, like Vinted. An admin will verify your IBAN before your first payout.',
      'payout_current_iban': 'Current bank account',
      'payout_method_label': 'Payout method',
      'payout_add_iban': 'Add / Update IBAN',
      'payout_iban_holder': 'Account holder name',
      'payout_iban_holder_required': 'Account holder name is required',
      'payout_iban_required': 'IBAN is required',
      'payout_iban_invalid': 'Invalid IBAN format',
      'payout_save_iban': 'Save bank account',
      'map_distance_filter_label': 'Distance: @km km',
      'map_no_nearby_sitters': 'No nearby sitters',
      'map_sitter_services_distance': '@services • @distance km',
      // Service provider detail screen
      'sitter_detail_loading_name': 'Loading...',
      'sitter_detail_load_error': 'Failed to load sitter details',
      'sitter_detail_no_rating': 'No rating yet',
      'sitter_detail_about_title': 'About @name',
      'sitter_detail_no_bio': 'No bio available.',
      'sitter_detail_booking_details_title': 'Booking Details',
      'sitter_detail_availability_pricing_title': 'Availability & Pricing',
      'sitter_detail_hourly_rate_label': 'Hourly Rate',
      'sitter_detail_weekly_rate_label': 'Weekly Rate',
      'sitter_detail_monthly_rate_label': 'Monthly Rate',
      'sitter_detail_current_status_label': 'Current Status',
      'sitter_detail_application_status_label': 'Application Status',
      'sitter_detail_skills_title': 'Skills',
      'sitter_detail_no_skills': 'No skills listed.',
      'sitter_detail_reviews_title': 'Reviews',
      'sitter_detail_no_reviews': 'No reviews yet.',
      'sitter_detail_anonymous_reviewer': 'Anonymous',
      'sitter_detail_starting_chat': 'Starting...',
      'sitter_detail_unlock_after_payment': 'Unlock after payment',
      'sitter_detail_start_chat': 'Start Chat',
      'sitter_detail_start_chat_failed':
          'Failed to start conversation. Please try again.',
      'status_available_label': 'Available',
      'status_cancelled_label': 'Cancelled',
      'status_rejected_label': 'Rejected',
      'status_pending_label': 'Pending',
      'status_agreed_label': 'Agreed',
      'status_paid_label': 'Paid',
      'status_accepted_label': 'Accepted',
      // Pet detail screen
      'pet_detail_loading': 'Loading pet details...',
      'pet_detail_about': 'About @name',
      'pet_detail_weight': 'Weight',
      'pet_detail_height': 'Height',
      'pet_detail_color': 'Color',
      'pet_detail_passport_number': 'Passport Number',
      'pet_detail_chip_number': 'Chip Number',
      'pet_detail_medication_allergies': 'Medication/Allergies',
      'pet_detail_date_of_birth': 'Date of Birth',
      'pet_detail_category': 'Category',
      'pet_detail_vaccinations': '@name Vaccinations',
      'pet_detail_gallery': '@name Gallery',
      'pet_detail_no_photos': 'No photos available',
      'pet_detail_owner_information': 'Owner Information',
      'pet_detail_owner_name': 'Name',
      'pet_detail_owner_created_at': 'Created At',
      'pet_detail_owner_updated_at': 'Updated At',
      'pet_detail_no_description': 'No description available',
      'pet_detail_gender_unknown': 'Unknown',
      'pet_detail_breed_unknown': 'Unknown',
      'pet_detail_no_vaccinations': 'No vaccinations listed',
      'pet_detail_load_error': 'Failed to load pet details. Please try again.',
      // Sitter bookings screen
      'sitter_bookings_title': 'My Bookings',
      'sitter_bookings_empty_all': 'No bookings found',
      'sitter_bookings_empty_filtered': 'No @status bookings found',
      'sitter_bookings_pet_label': 'Pet',
      'sitter_bookings_date_label': 'Date',
      'sitter_bookings_time_label': 'Time',
      'sitter_bookings_rate_label': 'Rate',
      'sitter_bookings_description_label': 'Description',
      'sitter_bookings_cancel_button': 'Cancel Booking',
      'sitter_bookings_cancel_dialog_message':
          'Are you sure you want to cancel this booking?',
      'sitter_bookings_cancel_dialog_yes': 'Yes, Cancel',
      'sitter_bookings_cancel_success':
          'Cancellation request submitted successfully!',
      'sitter_bookings_cancel_error':
          'Failed to request cancellation. Please try again.',
      // Owner bookings controller
      'bookings_cancel_success': 'Booking cancelled successfully!',
      'bookings_cancel_error': 'Failed to cancel booking. Please try again.',
      'bookings_cancel_request_success':
          'Cancellation request submitted successfully!',
      'bookings_cancel_request_error':
          'Failed to request cancellation. Please try again.',
      'request_cancel_button': 'Cancel Request',
      'request_cancel_button_cancelling': 'Cancelling...',
      'request_cancel_success': 'Request cancelled successfully!',
      'request_cancel_error': 'Failed to cancel request. Please try again.',
      'bookings_payment_status_error':
          'Failed to get payment status. Please try again.',
      // Service provider card
      'service_card_no_phone': 'No phone available',
      'service_card_no_location': 'No location available',
      'service_card_block': 'Block',
      'service_card_per_hour_label': 'Per Hour @price',
      'service_card_send_request': 'Send Request',
      'sitter_post_pet_details': 'Pet Details',
      'service_card_accept': 'Accept',
      'service_card_reject': 'Reject',
      'service_card_cancel': 'Cancel',
      'service_card_pay_with_amount': 'Pay @amount',
      'service_card_pay_now': 'Pay Now',
      'service_card_chat': 'Chat',
      // Sitter bottom sheet
      'sitter_view_profile': 'View Profile',
      'sitter_rating_with_count': '@rating (@count reviews)',
      // Bookings history
      'bookings_history_title': 'Bookings History',
      'status_all_label': 'All',
      'status_failed_label': 'Failed',
      'status_refunded_label': 'Refunded',
      'status_payment_pending_label': 'Payment pending',
      'status_payment_failed_label': 'Payment failed',
      'bookings_history_empty_all': 'No bookings found',
      'bookings_history_empty_filtered': 'No @status bookings found',
      'bookings_detail_pet_label': 'Pet',
      'bookings_detail_date_label': 'Date',
      'bookings_detail_time_label': 'Time',
      'bookings_detail_total_amount_label': 'Total Amount',
      'bookings_detail_phone_label': 'Phone',
      'bookings_detail_location_label': 'Location',
      'bookings_detail_rating_label': 'Rating',
      'bookings_detail_description_label': 'Description',
      'bookings_action_view_details': 'View Details',

      // Missing profile controller translations
      'profile_blocked_users_load_error': 'Failed to load blocked users',
      'profile_user_not_found': 'User not found',
      'profile_unblock_success': 'User unblocked successfully',
      'profile_unblock_failed': 'Unblock Failed',
      'profile_unblock_failed_generic':
          'Something went wrong. Please try again.',
      'profile_edit_coming_soon':
          'Edit profile functionality will be available soon',
      'profile_invalid_file_type': 'Invalid File Type',
      'profile_invalid_file_type_message':
          'Please select a JPEG, PNG, or WebP image.',
      'profile_image_pick_failed': 'Failed to pick image. Please try again.',
      'profile_picture_update_success': 'Profile picture updated successfully',
      'profile_upload_failed': 'Upload Failed',
      'profile_upload_failed_generic':
          'Something went wrong. Please try again.',

      // Missing auth controller translations
      'auth_google_signin_title': 'Google Sign-In',
      'auth_google_signin_web_required': 'This platform requires web sign-in.',
      'auth_google_signin_failed': 'Google Sign-In failed. Try again.',
      'auth_google_signin_token_missing': 'Google ID Token is missing.',
      'auth_google_signin_firebase_token_failed':
          'Failed to obtain Firebase ID token.',
      'auth_google_signin_choose_services': 'Please choose your services',
      'auth_google_signin_success': 'Successfully signed in with Google',
      'auth_apple_signin_success': 'Successfully signed in with Apple',
      'auth_apple_signin_failed': 'Apple Sign In Failed',
      'auth_apple_signin_failed_generic':
          'Something went wrong. Please try again.',
      'auth_role_required': 'Role Required',
      'auth_role_required_message':
          'Please contact support to set up your account role.',
      'auth_welcome': 'Welcome!',
      'auth_welcome_back': 'Welcome back!',
      'auth_role_switched': 'Role Switched',
      'auth_role_switched_message': 'Successfully switched to @role',
      'auth_role_switch_failed': 'Failed to switch role. Please try again.',

      // Missing send request controller translations
      'request_validation_error': 'Validation Error',
      'request_sitter_pricing_error':
          'Please set your hourly price first from Profile.',
      'request_duration_required':
          'Please select a duration for dog walking service.',
      'request_pet_required': 'Please select at least one pet.',
      'request_send_success': 'Request sent successfully!',
      'request_send_failed': 'Failed to send request. Please try again.',

      // Missing sitter application screen translations
      'sitter_application_accept_success': 'Application accepted successfully',
      'sitter_application_reject_success': 'Application rejected successfully',

      // Missing choose service controller translations
      'service_selection_required': 'Selection Required',
      'service_selection_required_message':
          'Please select at least one valid service for your role.',
      'service_selection_required_single': 'Please select a service',
      'service_selection_required_at_least_one':
          'Please select at least one service.',
      'service_updated': 'Service Updated',
      'service_updated_message': 'Your services have been updated',
      'service_selected': 'Services Selected',
      'service_selected_message':
          'Your services have been selected successfully',
      'service_selection_failed': 'Selection Failed',
      'service_selection_failed_generic':
          'Something went wrong. Please try again.',

      // Missing sign up controller translations
      'signup_location_found': 'Location Found',
      'signup_location_not_found': 'Location Not Found',
      'signup_location_error': 'Failed to get your location. Please try again.',
      'signup_failed_generic': 'Something went wrong. Please try again.',

      // Missing edit profile controller translations
      'edit_profile_load_error':
          'Failed to load profile data. Please try again.',
      'edit_profile_image_pick_failed':
          'Failed to pick image. Please try again.',
      'edit_profile_update_success': 'Profile updated successfully!',
      'edit_profile_picture_update_success':
          'Profile picture updated successfully!',
      'edit_profile_location_error':
          'Failed to get your location. Please try again.',
      'edit_profile_invalid_hourly_rate': 'Invalid Hourly Rate',

      // Missing home controller translations
      'home_post_success': 'Post created successfully!',
      'home_post_failed': 'Post Failed',
      'home_post_failed_generic': 'Something went wrong. Please try again.',
      'home_image_pick_failed': 'Failed to pick images. Please try again.',
      'home_block_success': 'User blocked successfully',
      'home_block_failed': 'Block Failed',
      'home_block_failed_generic': 'Something went wrong. Please try again.',

      // Missing edit pet controller translations
      'pet_load_error': 'Failed to load pet data. Please try again.',
      'pet_image_pick_failed': 'Failed to pick image. Please try again.',
      'pet_profile_image_pick_failed':
          'Failed to pick pet profile image. Please try again.',
      'pet_passport_image_pick_failed':
          'Failed to pick passport image. Please try again.',
      'pet_media_pick_failed':
          'Failed to pick pet pictures or videos. Please try again.',
      'pet_update_success': 'Pet profile updated successfully!',
      'pet_update_failed': 'Update Failed',
      'pet_update_failed_generic': 'Something went wrong. Please try again.',
      'pet_validation_error': 'Validation Error',
      'pet_validation_error_message': 'Please fill in all required fields',

      // Missing application screen translations
      'application_chat_start_failed':
          'Failed to start conversation. Please try again.',

      // Missing booking agreement screen translations
      'booking_agreement_load_error':
          'Failed to load booking details. Using default pricing.',
      'booking_agreement_title': 'Booking Agreement',
      'booking_agreement_payment_completed': 'Payment Completed',
      'booking_agreement_booking_cancelled': 'Booking Cancelled',
      'booking_agreement_status_label': 'Status: @status',
      'booking_agreement_start_date_label': 'Start Date',
      'booking_agreement_end_date_label': 'End Date',
      'booking_agreement_time_slot_label': 'Time Slot',
      'booking_agreement_service_provider_label': 'Service Provider',
      'booking_agreement_service_type_label': 'Service Type',
      'booking_agreement_special_instructions_label': 'Special Instructions',
      'booking_agreement_cancelled_at_label': 'Cancelled At',
      'booking_agreement_cancellation_reason_label': 'Cancellation Reason',
      'booking_agreement_price_breakdown_title': 'Price Breakdown',
      'booking_agreement_pricing_tier_label': 'Pricing tier',
      'booking_agreement_total_hours_label': 'Total hours',
      'booking_agreement_total_days_label': 'Total days',
      'booking_agreement_base_price_label': 'Base Price',
      'booking_agreement_platform_fee_label': 'Platform Fee',
      'booking_agreement_net_amount_label': 'Net Amount (to sitter)',
      'booking_agreement_today_at': 'Today at @time',
      'booking_agreement_yesterday_at': 'Yesterday at @time',
      'booking_agreement_at': 'at',

      // Missing add card controller translations
      'card_save_success': 'Card saved successfully!',
      'card_save_failed': 'Failed to save card. Please try again.',

      // Missing petsitter onboarding controller translations
      'onboarding_terms_required': 'Please accept the Terms and Conditions',
      'onboarding_profile_complete_success': 'Profile completed successfully!',
      'onboarding_profile_complete_failed':
          'Failed to complete profile. Please try again.',

      // Missing post comment translations
      'comment_add_success': 'Comment added successfully!',
      'comment_add_failed': 'Failed to add comment. Please try again.',

      // Missing reviews controller translations
      'review_submit_failed': 'Failed to submit review. Please try again.',

      // Missing pets map controller translations
      'map_load_error': 'Failed to load map data. Please try again.',

      // Missing OTP verification controller translations
      'otp_complete_code_required':
          'Please enter the complete verification code',
      'otp_verification_success': 'Verification successful!',
      'otp_login_again': 'Please try logging in again',

      // Missing create pet profile controller translations
      'pet_create_validation_error': 'Validation Error',
      'pet_create_validation_error_message':
          'Please fill in all required fields',
      'pet_create_success': 'Pet profile created successfully!',
      'pet_create_failed': 'Failed to create pet profile. Please try again.',

      // Missing task controller translations
      'task_fetch_failed': 'Failed to fetch tasks.',
      'task_fields_required': 'Please fill in at least one field.',
      'task_add_success': 'Task added successfully!',
      'task_add_failed': 'Failed to add task. Please try again.',

      // Missing posts controller translations
      'posts_load_error': 'Failed to load posts. Please try again.',

      // Missing my pets controller translations
      'my_pets_load_error': 'Failed to load pets. Please try again.',

      // Missing email verification controller translations
      'email_verification_success': 'Email verified successfully!',
      'email_verification_code_required':
          'Please enter the complete verification code',

      // Missing change password controller translations
      'change_password_validation_error': 'Validation Error',
      'change_password_fields_required': 'Please fill in all fields correctly.',
      'change_password_new_required': 'Please enter a new password.',
      'change_password_success': 'Password changed successfully!',
      'change_password_failed': 'Failed to change password. Please try again.',

      // Missing applications controller translations
      'application_action_success': 'Application @action successfully!',
      'Email Not Verified': 'Email Not Verified',
      'Image Error': 'Image Error',
      'Invalid Hourly Rate': 'Invalid Hourly Rate',
      'Location Found': 'Location Found',
      'Location Not Found': 'Location Not Found',
      'Required': 'Required',
      'Role Switched': 'Role Switched',
      'Selection Failed': 'Selection Failed',
      'Selection Required': 'Selection Required',
      'Service Updated': 'Service Updated',
      'Services Selected': 'Services Selected',
      'Success': 'Success',
      'Switch Role Failed': 'Switch Role Failed',
      'Verification Code Sent': 'Verification Code Sent',
      'share_failed': 'Failed to share. Please try again.',
      'snackbar_choose_service_controller_001':
          'Please select valid services for your account type.',
      'snackbar_choose_service_controller_002':
          'Your services have been updated successfully!',
      'snackbar_choose_service_controller_003':
          'Your services have been selected successfully!',
      'snackbar_choose_service_controller_004':
          'Failed to update services. Please try again.',
      'snackbar_choose_service_controller_005':
          'Please select at least one service to continue.',
      'snackbar_choose_service_controller_006':
          'Please select a valid service to continue.',
      'snackbar_choose_service_controller_007':
          'Please select at least one service.',
      'snackbar_sitter_paypal_payout_controller_001':
          'PayPal payout email is required.',
      'snackbar_sitter_paypal_payout_controller_002':
          'PayPal payout email updated successfully!',
      'snackbar_sitter_paypal_payout_controller_003':
          'Failed to update PayPal payout email. Please try again.',

      'snackbar_text_application_accepted_successfully':
          'Application accepted successfully',
      'snackbar_text_application_rejected_successfully':
          'Application rejected successfully',
      'snackbar_text_blocked_users_saved_successfully':
          'Blocked users saved successfully',
      'snackbar_text_card_saved_successfully': 'Card saved successfully!',
      'snackbar_text_could_not_detect_your_location_please_enable_location_servic':
          'Could not detect your location. Please enable location services.',
      'snackbar_text_could_not_load_nearby_sitters_please_try_again':
          'Could not load nearby sitters. Please try again.',
      'snackbar_text_email_not_verified': 'Email Not Verified',
      'snackbar_text_failed_to_complete_profile_please_try_again':
          'Failed to complete profile. Please try again.',
      'snackbar_text_failed_to_load_booking_details_using_default_pricing':
          'Failed to load booking details. Using default pricing.',
      'snackbar_text_failed_to_load_pet_data_please_try_again':
          'Failed to load pet data. Please try again.',
      'snackbar_text_failed_to_load_sitter_details_please_try_again':
          'Failed to load sitter details. Please try again.',
      'snackbar_text_failed_to_pick_passport_image_please_try_again':
          'Failed to pick passport image. Please try again.',
      'snackbar_text_failed_to_pick_pet_pictures_or_videos_please_try_again':
          'Failed to pick pet pictures or videos. Please try again.',
      'snackbar_text_failed_to_pick_pet_profile_image_please_try_again':
          'Failed to pick pet profile image. Please try again.',
      'snackbar_text_failed_to_save_card_please_try_again':
          'Failed to save card. Please try again.',
      'snackbar_text_failed_to_start_conversation_please_try_again':
          'Failed to start conversation. Please try again.',
      'snackbar_text_failed_to_switch_role_please_try_again':
          'Failed to switch role. Please try again.',
      'snackbar_text_height_is_required': 'Height is required.',
      'snackbar_text_height_must_be_greater_than_0':
          'Height must be greater than 0.',
      'snackbar_text_hourly_rate_must_be_greater_than_0':
          'Hourly rate must be greater than 0.',
      'snackbar_text_weekly_rate_must_be_greater_than_0':
          'Weekly rate must be greater than 0.',
      'snackbar_text_monthly_rate_must_be_greater_than_0':
          'Monthly rate must be greater than 0.',
      'snackbar_text_invalid_url': 'Invalid URL',
      'snackbar_text_unknown_error': 'Unknown error',
      'snackbar_text_image_error': 'Image Error',
      'snackbar_text_image_uploaded_successfully':
          'Image uploaded successfully!',
      'snackbar_text_invalid_hourly_rate': 'Invalid Hourly Rate',
      'snackbar_text_location_not_found': 'Location Not Found',
      'snackbar_text_passwords_do_not_match': 'Passwords do not match',
      'snackbar_text_pet_profile_created_but_media_upload_failed_you_can_add_medi':
          'Pet profile created but media upload failed. You can add media later.',
      'snackbar_text_pet_profile_created_successfully':
          'Pet profile created successfully!',
      'snackbar_text_pet_profile_updated_successfully':
          'Pet profile updated successfully!',
      'snackbar_text_please_accept_the_terms_and_conditions':
          'Please accept the Terms and Conditions',
      'snackbar_text_please_enter_your_paypal_email':
          'Please enter your PayPal email.',
      'snackbar_text_please_fill_in_all_required_fields':
          'Please fill in all required fields',
      'snackbar_text_please_try_logging_in_again':
          'Please try logging in again',
      'snackbar_text_profile_completed_successfully':
          'Profile completed successfully!',
      'snackbar_text_profile_updated_but_image_upload_failed_please_try_again':
          'Profile updated but image upload failed. Please try again.',
      'snackbar_text_required': 'Required',
      'snackbar_text_review_submitted_successfully':
          'Review submitted successfully!',
      'snackbar_text_role_switched': 'Role Switched',
      'snackbar_text_selected_image_file_is_not_accessible_please_try_again':
          'Selected image file is not accessible. Please try again.',
      'snackbar_text_selection_failed': 'Selection Failed',
      'snackbar_text_sitter_blocked_successfully':
          'Sitter blocked successfully!',
      'snackbar_text_something_went_wrong_please_try_logging_in_again':
          'Something went wrong. Please try logging in again.',
      'snackbar_text_success': 'Success',
      'snackbar_text_successfully_switched_to_userrole_value':
          'Successfully switched role successfully.',
      'snackbar_text_switch_role_failed': 'Switch Role Failed',
      'snackbar_text_unknown_user_role_please_try_again':
          'Unknown user role. Please try again.',
      'snackbar_text_verification_code_has_been_resent_to_your_email':
          'Verification code has been resent to your email',
      'snackbar_text_verification_code_resent': 'Verification code resent',
      'snackbar_text_verification_code_sent': 'Verification Code Sent',
      'snackbar_text_welcome_back': 'Welcome back!',
      'snackbar_text_you_have_already_reviewed_this_sitter_you_can_only_submit_on':
          'You have already reviewed this sitter. You can only submit one review per sitter.',
    'post_more_options': 'More options',
    'post_action_block_user': 'Block user',
    'post_action_report': 'Report post',
    'block_user_title': 'Block user',
    'block_user_action': 'Block',
    'block_user_confirm_message': 'Are you sure you want to block this user? You will no longer see their content.',
    'block_user_success': 'User blocked successfully.',
    'block_user_failed': 'Failed to block user. Please try again.',
    'report_post_received': 'Report received. Thank you.',
    'pet_photo_delete_title': 'Delete photo',
    'pet_photo_delete_confirm': 'Are you sure you want to delete this photo?',
    'pet_photo_deleted': 'Photo deleted successfully.',
    'pet_photo_delete_failed': 'Failed to delete photo. Please try again.',
    'new_publication_button': 'New publication',
    },
    'fr_FR': <String, String>{
      'common_yes': 'Oui',
      'common_no': 'Non',
      'common_cancel': 'Annuler',
      'common_error': 'Erreur',
      'common_success': 'Succès',
      'common_select_value': 'Sélectionner une valeur',
      'label_not_available': 'N/D',
      'common_user': 'Utilisateur',
      'common_refresh': 'Rafraîchir',
      'common_search': 'Rechercher',

      'Application accepted successfully': 'Candidature acceptee avec succes',
      'Application rejected successfully': 'Candidature rejetee avec succes',
      'Blocked users saved successfully':
          'Utilisateurs bloques enregistres avec succes',
      'Card saved successfully!': 'Carte enregistree avec succes !',
      'Could not detect your location. Please enable location services.':
          'Impossible de detecter votre position. Veuillez activer les services de localisation.',
      'Could not load nearby sitters. Please try again.':
          'Impossible de charger les pet sitters a proximite. Veuillez reessayer.',
      'Email verified successfully!': 'E-mail verifie avec succes !',
      'Failed to add task. Please try again.':
          'Impossible d\'ajouter la tache. Veuillez reessayer.',
      'Failed to change password. Please try again.':
          'Impossible de changer le mot de passe. Veuillez reessayer.',
      'Failed to complete profile. Please try again.':
          'Impossible de terminer le profil. Veuillez reessayer.',
      'Failed to fetch tasks.': 'Impossible de recuperer les taches.',
      'Failed to get your location. Please try again.':
          'Impossible d\'obtenir votre position. Veuillez reessayer.',
      'Failed to load booking details. Using default pricing.':
          'Impossible de charger les details de reservation. Tarification par defaut utilisee.',
      'Failed to load pet data. Please try again.':
          'Impossible de charger les donnees de l\'animal. Veuillez reessayer.',
      'Failed to load pets. Please try again.':
          'Impossible de charger les animaux. Veuillez reessayer.',
      'Failed to load profile data. Please try again.':
          'Impossible de charger les donnees du profil. Veuillez reessayer.',
      'Failed to load sitter details. Please try again.':
          'Impossible de charger les details du pet sitter. Veuillez reessayer.',
      'Failed to pick image. Please try again.':
          'Impossible de selectionner l\'image. Veuillez reessayer.',
      'Failed to pick passport image. Please try again.':
          'Impossible de selectionner l\'image du passeport. Veuillez reessayer.',
      'Failed to pick pet pictures or videos. Please try again.':
          'Impossible de selectionner les photos ou videos de l\'animal. Veuillez reessayer.',
      'Failed to pick pet profile image. Please try again.':
          'Impossible de selectionner l\'image de profil de l\'animal. Veuillez reessayer.',
      'Failed to save card. Please try again.':
          'Impossible d\'enregistrer la carte. Veuillez reessayer.',
      'Failed to start conversation. Please try again.':
          'Impossible de demarrer la conversation. Veuillez reessayer.',
      'Failed to submit review. Please try again.':
          'Impossible d\'envoyer l\'avis. Veuillez reessayer.',
      'Failed to switch role. Please try again.':
          'Impossible de changer de role. Veuillez reessayer.',
      'Height is required.': 'La taille est requise.',
      'Height must be greater than 0.': 'La taille doit etre superieure a 0.',
      'Hourly rate must be greater than 0.':
          'Le tarif horaire doit etre superieur a 0.',
      'Image uploaded successfully!': 'Image telechargee avec succes !',
      'Password changed successfully!': 'Mot de passe modifie avec succes !',
      'Passwords do not match': 'Les mots de passe ne correspondent pas',
      'Pet profile created but media upload failed. You can add media later.':
          'Profil de l\'animal cree, mais le telechargement des medias a echoue. Vous pouvez ajouter des medias plus tard.',
      'Pet profile created successfully!':
          'Profil de l\'animal cree avec succes !',
      'Pet profile updated successfully!':
          'Profil de l\'animal mis a jour avec succes !',
      'Please accept the Terms and Conditions':
          'Veuillez accepter les conditions generales.',
      'Please agree to the Terms and Conditions':
          'Veuillez accepter les conditions generales.',
      'Please enter a new password.':
          'Veuillez saisir un nouveau mot de passe.',
      'Please enter the complete verification code':
          'Veuillez saisir le code de verification complet',
      'Please enter your PayPal email.': 'Veuillez saisir votre e-mail PayPal.',
      'Please fill in all fields correctly.':
          'Veuillez remplir correctement tous les champs.',
      'Please fill in all required fields':
          'Veuillez remplir tous les champs obligatoires',
      'Please fill in at least one field.':
          'Veuillez remplir au moins un champ.',
      'Please fix the highlighted fields and try again.':
          'Veuillez corriger les champs en surbrillance et reessayer.',
      'Please try logging in again': 'Veuillez vous reconnecter',
      'Please verify your email to continue.':
          'Veuillez verifier votre e-mail pour continuer.',
      'Profile completed successfully!': 'Profil complete avec succes !',
      'Profile picture updated successfully!':
          'Photo de profil mise a jour avec succes !',
      'Profile updated successfully!': 'Profil mis a jour avec succes !',
      'Review submitted successfully!': 'Avis envoye avec succes !',
      'Selected image file is not accessible. Please try again.':
          'Le fichier image selectionne est inaccessible. Veuillez reessayer.',
      'Sitter blocked successfully!': 'Pet sitter bloque avec succes !',
      'Something went wrong. Please try again.':
          'Une erreur est survenue. Veuillez reessayer.',
      'Something went wrong. Please try logging in again.':
          'Une erreur est survenue. Veuillez vous reconnecter.',
      'Task added successfully!': 'Tache ajoutee avec succes !',
      'Unknown user role. Please try again.':
          'Role utilisateur inconnu. Veuillez reessayer.',
      'Verification code has been resent to your email':
          'Le code de verification a ete renvoye a votre e-mail',
      'Verification code resent': 'Code de verification renvoye',
      'Welcome back!': 'Bon retour !',
      'You have already reviewed this sitter. You can only submit one review per sitter.':
          'Vous avez deja evalue ce pet sitter. Vous ne pouvez soumettre qu\'un seul avis par pet sitter.',
      'Your city (@city) has been detected':
          'Votre ville (@city) a ete detectee',
      'Profile updated but image upload failed. Please try again.':
          'Profil mis a jour mais l\'envoi de l\'image a echoue. Veuillez reessayer.',
      'Profile updated but image upload failed: @error':
          'Profil mis a jour mais l\'envoi de l\'image a echoue : @error',

      // Posts / Comments
      'post_action_like': 'J’aime',
      'post_action_comment': 'Commenter',
      'post_action_share': 'Partager',
      'post_comments_title': 'Commentaires',
      'post_comments_hint': 'Ajouter un commentaire…',
      'post_comments_empty_title': 'Aucun commentaire',
      'post_comments_empty_subtitle': 'Soyez le premier à commenter !',
      'post_comment_added_success': 'Commentaire ajouté avec succès !',
      'post_comment_add_failed':
          'Impossible d’ajouter le commentaire. Réessayez.',
      'post_comments_count_singular': '@count commentaire',
      'post_comments_count_plural': '@count commentaires',

      // Relative time
      'time_days_ago': 'il y a @count j',
      'time_hours_ago': 'il y a @count h',
      'time_minutes_ago': 'il y a @count min',
      'time_just_now': 'À l’instant',
      'posts_empty_title': 'Aucune publication disponible',
      'posts_load_failed':
          'Impossible de charger les publications. Veuillez réessayer.',
      'posts_like_login_required':
          'Veuillez vous connecter pour aimer les publications.',
      'posts_like_failed':
          'Impossible d’aimer la publication. Veuillez réessayer.',
      'posts_unlike_failed':
          'Impossible de retirer le j’aime. Veuillez réessayer.',
      'application_accept_success': 'Candidature acceptée avec succès !',
      'application_reject_success': 'Candidature refusée avec succès !',
      'application_action_failed':
          'Échec de la réponse à la candidature. Veuillez réessayer.',
      'request_card_pet_owner': 'Propriétaire : @name',
      'sitter_reservation_requests': 'Demandes de réservation',
      'sitter_filters': 'Filtres',
      'sitter_filters_on': 'Filtres actifs',
      'sitter_no_requests_match': 'Aucune demande ne correspond à vos filtres.',
      'filter_requests_title': 'Filtrer les demandes',
      'filter_clear': 'Effacer',
      'filter_apply': 'Appliquer',
      'filter_location': 'Lieu',
      'filter_service_type': 'Type de service',
      'filter_dates': 'Dates',
      'filter_city_hint': 'Ville ou zone',
      'filter_any_dates': 'Toutes dates',

      // Profile: Apple connection
      'profile_connect_with_apple': 'Se connecter avec Apple',
      'profile_connection_connected': 'Connecté',

      'sign_up_as_pet_owner': 'Inscription comme propriétaire',
      'sign_up_as_pet_sitter': 'Inscription comme pet sitter',
      'label_name': 'Nom',
      'hint_name': 'Entrez votre nom',
      'label_email': 'E‑mail',
      'hint_email': 'Entrez votre e‑mail',
      'label_mobile_number': 'Numéro de mobile',
      'hint_phone': 'Entrez votre numéro de téléphone',
      'profile_no_phone_added': 'Aucun numéro ajouté',
      'profile_no_email_added': 'Aucun e-mail ajouté',
      'label_password': 'Mot de passe',
      'hint_password': 'Créez un mot de passe',
      'password_requirement':
          'Doit comporter au moins 8 caractères avec des lettres majuscules, minuscules et un chiffre.',
      'label_language': 'Langue',
      'hint_language': 'Entrez les langues que vous parlez',
      'label_address': 'Adresse',
      'hint_address': 'Localisation',
      'label_rate_per_hour': 'Tarif horaire',
      'hint_rate_per_hour': 'ex. 20',
      'price_per_hour': 'Prix / heure',
      'price_per_day': 'Prix / jour',
      'price_per_week': 'Prix / semaine',
      'price_per_month': 'Prix / mois',
      'chat_payment_required_banner': 'Le chat s\'ouvre après confirmation du paiement.',
      'chat_pay_now_button': 'Payer maintenant',
      'chat_share_phone_button': 'Partager mon numéro',
      'terms_read_button': 'Lire les Conditions Générales',
      'service_prefs_at_owner_label': 'J\'accepte les services chez moi',
      'service_prefs_at_sitter_label': 'J\'accepte les services chez le petsitter',
      'service_location_label': 'Où doit se dérouler le service ?',
      'service_location_at_owner': 'Chez moi',
      'service_location_at_sitter': 'Chez le petsitter',
      'service_location_both': 'Les deux',
      'profile_my_availability': 'Mon calendrier de disponibilité',
      'profile_verify_identity': 'Vérifier mon identité',
      'profile_identity_verified': 'Identité vérifiée',
      'theme_setting_title': 'Thème',
      'theme_light': 'Clair',
      'theme_dark': 'Sombre',
      'theme_system': 'Suivre le système',
      'common_close': 'Fermer',
      'label_skills': 'Compétences',
      'hint_skills': 'Vétérinaire, Éducateur',
      'label_bio': 'Bio',
      'hint_bio': 'Parlez-nous de vous',
      'label_terms_prefix': "J'accepte les ",
      'label_terms_title': 'conditions et la politique de confidentialité.',
      'or_sign_up_with': 'Ou inscrivez‑vous avec',
      'button_google': 'Google',
      'button_apple': 'Apple',
      'button_create_account': 'Créer un compte',
      'button_creating_account': 'Création du compte…',
      'button_logout': 'Se déconnecter',
      'title_login': 'Se connecter',
      'welcome_back': 'Bon retour 👋',
      'login_subtitle': 'Connectez-vous pour continuer sur Hopetsit.',
      'hint_password_login': 'Entrez votre mot de passe',
      'forgot_password': 'Mot de passe oublié ?',
      'forgot_password_reset_title': 'Réinitialiser votre mot de passe',
      'forgot_password_reset_message':
          'Entrez votre adresse e-mail et nous vous enverrons un code pour réinitialiser votre mot de passe.',
      'forgot_password_email_label': 'Adresse e-mail',
      'forgot_password_sending_code': 'Envoi du code...',
      'forgot_password_send_code': 'Envoyer le code de vérification',
      'forgot_password_remember': 'Vous vous souvenez de votre mot de passe ? ',
      'forgot_password_otp_sent_title': 'Code envoyé',
      'forgot_password_otp_sent_message':
          'Le code de vérification a été envoyé à votre e-mail',
      'forgot_password_request_failed': 'Échec de la demande',
      'forgot_password_verified_title': 'Vérifié',
      'forgot_password_verified_message':
          'Vous pouvez maintenant réinitialiser votre mot de passe',
      'forgot_password_verification_failed': 'Échec de la vérification',
      'forgot_password_reset_success':
          'Votre mot de passe a été réinitialisé avec succès',
      'forgot_password_reset_failed': 'Échec de la réinitialisation',
      'forgot_password_code_resent_title': 'Code renvoyé',
      'forgot_password_code_resent_message':
          'Le code de vérification a été renvoyé à votre e-mail',
      'forgot_password_resend_failed': 'Échec du renvoi',
      'forgot_password_verify_code_title': 'Vérifier le code',
      'forgot_password_enter_code_title': 'Entrez le code de vérification',
      'forgot_password_code_sent_to':
          'Nous avons envoyé un code à 6 chiffres à @email',
      'forgot_password_verifying': 'Vérification...',
      'forgot_password_resend_in': 'Renvoyer le code dans @seconds s',
      'forgot_password_resend_code': 'Renvoyer le code',
      'forgot_password_wrong_email': 'Mauvais e-mail ? ',
      'forgot_password_change_email': 'Le changer',
      'forgot_password_create_new_title': 'Créer un nouveau mot de passe',
      'forgot_password_set_new_title': 'Définissez votre nouveau mot de passe',
      'forgot_password_set_new_message':
          'Créez un mot de passe fort pour sécuriser votre compte. Assurez-vous qu\'il contient au moins 8 caractères.',
      'forgot_password_new_hint': 'Entrez le nouveau mot de passe',
      'forgot_password_confirm_hint': 'Réentrez votre mot de passe',
      'forgot_password_resetting': 'Réinitialisation du mot de passe...',
      'forgot_password_reset_button': 'Réinitialiser le mot de passe',
      'forgot_password_reset_success_title':
          'Mot de passe réinitialisé avec succès !',
      'forgot_password_reset_success_message':
          'Votre mot de passe a été réinitialisé avec succès. Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
      'forgot_password_email_verified_title': 'E-mail vérifié',
      'forgot_password_email_verified_subtitle': 'Votre e-mail a été vérifié',
      'forgot_password_password_updated_title': 'Mot de passe mis à jour',
      'forgot_password_password_updated_subtitle':
          'Votre mot de passe a été modifié',
      'forgot_password_login_new_password':
          'Se connecter avec le nouveau mot de passe',
      'forgot_password_security_warning':
          'Si vous n\'avez pas demandé ce changement, veuillez sécuriser votre compte immédiatement.',
      'logging_in': 'Connexion en cours...',
      'or_continue_with': 'Ou continuer avec',
      'dont_have_account': 'Vous n\'avez pas de compte ? ',
      'sign_up': 'S\'inscrire',
      // Onboarding screen
      'onboarding_app_title': 'Home Pets Sitting',
      'onboarding_continue_with_google': 'Continuer avec Google',
      'onboarding_continue_with_apple': 'Continuer avec Apple',
      'onboarding_have_account': 'Vous avez un compte ?',

      'error_invalid_details_title': 'Détails invalides',
      'error_invalid_details_message':
          'Veuillez corriger les champs en surbrillance puis réessayer.',
      'error_terms_required_title': 'Conditions requises',
      'error_terms_required_message':
          'Veuillez accepter les conditions générales.',
      'error_name_required': 'Veuillez entrer votre nom',
      'error_name_length': 'Le nom doit contenir au moins 2 caractères',
      'error_email_required': 'Veuillez entrer votre e‑mail',
      'error_email_invalid': 'Veuillez entrer un e‑mail valide',
      'error_phone_invalid': 'Veuillez entrer un numéro de téléphone valide',
      'error_phone_required': 'Veuillez entrer votre numéro de téléphone',
      'error_password_required': 'Veuillez entrer un mot de passe',
      'error_password_length':
          'Le mot de passe doit contenir au moins 8 caractères',
      'error_password_uppercase':
          'Le mot de passe doit contenir au moins une lettre majuscule',
      'error_password_lowercase':
          'Le mot de passe doit contenir au moins une lettre minuscule',
      'error_password_number':
          'Le mot de passe doit contenir au moins un chiffre',
      'error_password_confirm_required':
          'Veuillez confirmer votre mot de passe',
      'error_password_match': 'Les mots de passe ne correspondent pas',
      'error_otp_required': 'Le code OTP est requis',
      'error_otp_length': 'Le code OTP doit contenir 6 chiffres',
      'error_otp_numbers_only': 'Le code OTP ne doit contenir que des chiffres',
      'common_error_generic': 'Une erreur est survenue. Veuillez réessayer.',
      'error_address_required': 'Veuillez entrer votre adresse',
      'error_address_length': 'L’adresse doit contenir au moins 2 caractères',
      'error_rate_required': 'Veuillez entrer votre tarif horaire',
      'error_rate_invalid': 'Veuillez entrer un tarif valide',
      'error_rate_zero': 'Le tarif horaire ne peut pas être 0',
      'error_skills_required': 'Veuillez entrer vos compétences',
      'error_skills_length':
          'Les compétences doivent contenir au moins 2 caractères',

      'location_found_title': 'Localisation trouvée',
      'location_found_message': 'Votre ville (@city) a été détectée',
      'location_not_found_title': 'Localisation introuvable',
      'location_not_found_message':
          'Impossible de détecter votre localisation. Veuillez activer les services de localisation.',
      'location_error_title': 'Erreur',
      'location_error_message':
          'Échec de la récupération de votre localisation. Veuillez réessayer.',
      // Location picker
      'label_city': 'Ville',
      'location_getting': 'Obtention...',
      'location_auto': 'Auto',
      'location_map': 'Carte',
      'location_detected': 'Détecté : @city',
      'location_enter_city': 'Entrez votre ville',
      'error_city_required': 'Veuillez entrer votre ville',
      'location_detected_message':
          'Votre localisation a été détectée. Vous serez connecté avec des prestataires de services dans cette zone.',
      'location_select_title': 'Sélectionner l\'emplacement',
      'location_selected': 'Emplacement sélectionné',
      'location_selected_city': 'Ville sélectionnée',
      'location_no_city': 'Aucune ville sélectionnée',
      'location_latitude': 'Latitude : @value',
      'location_longitude': 'Longitude : @value',
      'location_current': 'Actuel',
      'location_confirm': 'Confirmer',
      'location_select_error': 'Veuillez sélectionner un emplacement',
      'location_get_error': 'Impossible d\'obtenir votre localisation',

      'signup_account_created_title': 'Compte créé',
      'signup_account_created_message':
          'Veuillez vérifier votre e‑mail pour continuer.',
      'signup_failed_title': "Échec de l’inscription",
      'signup_failed_generic_message':
          'Une erreur est survenue. Veuillez réessayer.',

      'language_dialog_title': 'Choisir la langue',
      'language_dialog_message':
          "Sélectionnez votre langue préférée pour l'application.",
      'language_updated_title': 'Langue mise à jour',
      'language_updated_message': "La langue de l'application a été modifiée.",
      'title_profile': 'Profil',
      'edit_profile_title': 'Modifier le profil',
      'edit_profile_button': 'Mettre à jour le profil',
      'edit_profile_button_updating': 'Mise à jour du profil...',
      'service_selection_required': 'Selection requise',
      'service_updated': 'Service mis à jour',
      'service_selected': 'Services sélectionnés',
      'edit_profile_update_success': 'Profil mis à jour avec succès !',
      'edit_profile_picture_update_success':
          'Photo de profil mise à jour avec succès !',
      // Choose service screen
      'choose_service_title': 'Choisir un service',
      'choose_service_choose_all': 'Tout choisir',
      'choose_service_saving': 'Enregistrement...',
      'choose_service_selecting': 'Sélection en cours...',
      'choose_service_save': 'Enregistrer',
      'choose_service_continue': 'Continuer',
      'choose_service_card_pet_sitting_title': 'Garde à domicile',
      'choose_service_card_house_sitting_title': 'Gardiennage de maison',
      'choose_service_card_day_care_title': 'Garderie pour animaux',
      'choose_service_card_dog_walking_title': 'Promenade de chiens',
      'choose_service_card_subtitle_at_owners_home': 'Chez le propriétaire',
      'choose_service_card_subtitle_in_your_home': 'Chez vous',
      'choose_service_card_subtitle_in_neighborhood': 'Dans votre quartier',
      'section_settings': 'Paramètres',
      'role_pet_owner': 'Propriétaire',
      'role_pet_sitter': 'Garde d\'animaux',
      'auth_role_pet_owner': 'Propriétaire',
      'auth_role_pet_sitter': 'Garde d\'animaux',
      'profile_add_tasks': 'Ajouter des tâches',
      'profile_view_tasks': 'Voir les tâches',
      'profile_bookings_history': 'Historique des réservations',
      'profile_edit_profile': 'Modifier le profil',
      'profile_edit_pets_profile': 'Modifier le profil des animaux',
      'profile_choose_service': 'Choisir un service',
      'profile_change_password': 'Modifier le mot de passe',
      'profile_change_language': 'Changer de langue',
      'profile_blocked_users': 'Utilisateurs bloqués',
      'profile_delete_account': 'Supprimer le compte',
      'profile_donate_us': 'Faire un don',
      'blocked_users_title': 'Utilisateurs bloqués',
      'blocked_users_empty_title': 'Aucun utilisateur bloqué',
      'blocked_users_empty_message':
          'Les utilisateurs que vous bloquez apparaîtront ici',
      'blocked_users_unblock_button': 'Débloquer',
      'blocked_users_unblock_dialog_message':
          'Voulez-vous vraiment débloquer @name ?',
      'delete_account_dialog_message':
          'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.',
      'delete_account_success_title': 'Compte supprimé',
      'delete_account_success_message':
          'Votre compte a été supprimé avec succès',
      'delete_account_failed_title': 'Échec de la suppression',
      'delete_account_failed_generic':
          'Une erreur est survenue. Veuillez réessayer.',
      'logout_dialog_message': 'Êtes-vous sûr de vouloir vous déconnecter ?',
      'profile_switch_role_card_title': 'Passer à @role',
      'profile_switch_role_card_description':
          'Passez votre compte en @role pour commencer à recevoir des demandes.',
      'dialog_switch_role_title': 'Changer de rôle',
      'dialog_switch_role_switching':
          'Changement pour @role...\n\nVeuillez patienter.',
      'dialog_switch_role_confirm':
          'Voulez-vous vraiment passer en @role ?\n\nVous pourrez revenir en arrière à tout moment.',
      'dialog_switch_role_button': 'Passer à @role',
      'profile_switch_to_sitter': 'Passer à Pet Sitter',
      'profile_switch_to_owner': 'Passer à Propriétaire d\'Animal',
      'profile_switch_to_sitter_description':
          'Passez votre compte en Pet Sitter pour commencer à recevoir des demandes.',
      'profile_switch_to_owner_description':
          'Passez votre compte en Propriétaire d\'Animal pour commencer à recevoir des demandes.',
      'profile_switch_role_dialog_title': 'Changer de rôle',
      'profile_switch_to_sitter_loading':
          'Changement pour Pet Sitter...\n\nVeuillez patienter.',
      'profile_switch_to_owner_loading':
          'Changement pour Propriétaire d\'Animal...\n\nVeuillez patienter.',
      'profile_switch_to_sitter_confirm':
          'Voulez-vous vraiment passer en Pet Sitter ?\n\nVous pourrez revenir en arrière à tout moment.',
      'profile_switch_to_owner_confirm':
          'Voulez-vous vraiment passer en Propriétaire d\'Animal ?\n\nVous pourrez revenir en arrière à tout moment.',
      'common_continue': 'Continuer',
      'common_cancelled': 'Annulé',
      'common_coming_soon': 'Bientôt disponible',
      'common_go_to_home': 'Aller à l\'accueil',
      'common_back_to_home': 'Retour à l\'accueil',
      'error_login_required': 'Veuillez vous reconnecter',
      'error_email_not_found':
          'E-mail utilisateur introuvable. Veuillez vous reconnecter.',
      'profile_load_error': 'Échec du chargement du profil',
      'blocked_users_unblock_success': 'Utilisateur débloqué avec succès',
      'blocked_users_save_success':
          'Utilisateurs bloqués enregistrés avec succès',
      'donate_coming_soon': 'La fonctionnalité de don sera bientôt disponible',
      'stripe_connect_title': 'Connecter le compte Stripe',
      'payout_status_screen_title': 'Statut des paiements',
      'payout_connect_stripe_account': 'Connecter le compte Stripe',
      'payout_paypal_email_title': 'Email de paiement PayPal',
      'payout_add_paypal_email_title': 'Ajouter un email de paiement PayPal',
      'payout_add_paypal_email_subtitle':
          'Definissez l\'email ou vous souhaitez recevoir les paiements. Vous pourrez le modifier plus tard depuis le statut des paiements.',
      'payout_status_saved': 'Enregistre',
      'payout_status_not_set': 'Non defini',
      'payout_paypal_email_hint':
          'Ajoutez un email pour recevoir les paiements via PayPal.',
      'payout_update_paypal_email': 'Mettre a jour l\'email PayPal',
      'payout_paypal_dialog_subtitle':
          'Cet email sera utilise pour les paiements PayPal. Assurez-vous qu\'il correspond a votre compte PayPal.',
      'payout_stripe_connect_title': 'Stripe Connect',
      'payout_status_connected': 'Connecte',
      'payout_status_not_connected': 'Non connecte',
      'payout_stripe_connected_message':
          'Votre compte Stripe est connecte et pret a recevoir des paiements.',
      'payout_stripe_not_connected_message':
          'Connectez votre compte Stripe pour commencer a recevoir des paiements.',
      'payout_account_id_label': 'ID du compte',
      'payout_verification_title': 'Statut de verification',
      'payout_status_title': 'Statut des paiements',
      'payout_verification_step_identity': 'Verification d\'identite',
      'payout_verification_step_bank': 'Verification du compte bancaire',
      'payout_verification_step_business': 'Informations de l\'entreprise',
      'payout_next_payout_label': 'Prochain paiement',
      'payout_schedule_label': 'Frequence des paiements',
      'payout_schedule_daily': 'Quotidien',
      'payout_minimum_amount_label': 'Montant minimum',
      'payout_status_verified': 'Verifie',
      'payout_status_pending': 'En attente',
      'payout_status_rejected': 'Rejete',
      'payout_status_not_started': 'Non commence',
      'payout_status_active': 'Actif',
      'payout_status_restricted': 'Restreint',
      'payout_verification_message_verified':
          'Votre compte a ete verifie. Vous pouvez maintenant recevoir des paiements.',
      'payout_verification_message_pending':
          'Votre verification est en cours d\'examen. Cela prend generalement 1 a 2 jours ouvrables.',
      'payout_verification_message_rejected':
          'Votre verification a ete rejetee. Veuillez mettre a jour vos informations et reessayer.',
      'payout_verification_message_not_started':
          'Veuillez terminer la verification pour commencer a recevoir des paiements.',
      'payout_message_active':
          'Vos paiements sont actifs. Les gains seront transferes quotidiennement sur votre compte bancaire.',
      'payout_message_pending':
          'Votre compte de paiement est en cours de configuration. Cela peut prendre quelques jours ouvrables.',
      'payout_message_restricted':
          'Vos paiements sont actuellement restreints. Veuillez contacter le support.',
      'payout_message_not_connected':
          'Connectez votre compte Stripe pour commencer a recevoir des paiements.',
      'stripe_get_paid_title': 'Recevez des paiements avec Stripe',
      'stripe_connect_description':
          'Connectez votre compte Stripe pour recevoir des paiements directement des propriétaires d\'animaux. Vos gains seront transférés sur votre compte bancaire.',
      'stripe_account_status_title': 'État du compte',
      'stripe_continue_onboarding': 'Continuer l\'intégration',
      'stripe_connect_account_button': 'Connecter le compte Stripe',
      'stripe_benefit_secure': 'Traitement sécurisé des paiements',
      'stripe_benefit_fast_payouts':
          'Paiements rapides sur votre compte bancaire',
      'stripe_benefit_no_fees': 'Aucuns frais d\'installation',
      'stripe_benefit_support': 'Support client 24/7',
      'stripe_benefit_required':
          'Requis pour recevoir des paiements des propriétaires d\'animaux',
      'stripe_account_connected': 'Compte connecté',
      'stripe_account_created_pending': 'Compte créé - Intégration en attente',
      'stripe_account_created': 'Compte créé',
      'stripe_account_connected_message':
          'Votre compte Stripe est entièrement configuré et prêt à recevoir des paiements.',
      'stripe_account_created_message':
          'Votre compte Stripe a été créé. Veuillez compléter le processus d\'intégration pour commencer à recevoir des paiements.',
      'stripe_account_created_partial_message':
          'Votre compte de paiement a été créé. Certaines étapes de vérification restent à compléter. Vous pouvez les compléter dans les paramètres de votre compte.',
      'stripe_account_id_label': 'ID du compte',
      'stripe_loading_onboarding': 'Chargement de l\'intégration Stripe...',
      'stripe_account_connected_success':
          'Compte Stripe connecté avec succès !',
      'stripe_onboarding_completed': 'Intégration Stripe terminée !',
      'stripe_onboarding_cancelled': 'L\'intégration Stripe a été annulée.',
      'stripe_onboarding_load_error':
          'Échec du chargement de la page d\'intégration Stripe : @error',
      'stripe_cancel_onboarding_title': 'Annuler l\'intégration ?',
      'stripe_cancel_onboarding_message':
          'Voulez-vous vraiment annuler l\'intégration Stripe ? Vous pourrez la compléter plus tard depuis les paramètres.',
      'stripe_connect_payment_title': 'Connectez votre compte de paiement',
      'stripe_connect_payment_description':
          'Pour commencer à recevoir des paiements en tant que Pet Sitter, vous devez connecter votre compte de paiement. C\'est une étape requise pour compléter la configuration de votre profil.',
      'stripe_connect_payment_partial_description':
          'Votre compte de paiement a été créé. Certaines étapes de vérification restent à compléter. Vous pouvez les compléter plus tard dans les paramètres de votre compte.',
      'stripe_connect_payment_partial_info':
          'Votre compte est connecté, mais certaines étapes de vérification restent à compléter. Vous pouvez les compléter dans les paramètres de votre compte.',
      'stripe_payment_connected_success': 'Paiement connecté avec succès !',
      'stripe_connect_now': 'Connecter maintenant',
      'stripe_already_connected': 'Déjà connecté',
      'stripe_already_connected_message':
          'Votre compte Stripe est déjà connecté et actif.',
      'stripe_connect_error':
          'Échec de la connexion du compte Stripe. Veuillez réessayer.',
      'stripe_no_onboarding_url':
          'Aucune URL d\'intégration disponible. Veuillez d\'abord créer un compte Stripe.',
      'stripe_onboarding_expired_title': 'Expiré',
      'stripe_onboarding_expired_message':
          'Le lien d\'intégration a expiré. Veuillez en créer un nouveau.',
      'stripe_disconnect_success': 'Compte Stripe déconnecté avec succès !',
      'stripe_disconnect_error':
          'Échec de la déconnexion du compte Stripe. Veuillez réessayer.',
      'payment_title': 'Paiement',
      'payment_info_message':
          'Cliquez sur "Payer" ci-dessous pour saisir en toute sécurité vos informations de paiement en utilisant le formulaire de paiement sécurisé de Stripe.',
      'payment_paypal_info':
          'Vous serez redirigé vers PayPal pour approuver le paiement, puis nous le confirmerons ici.',
      'payment_pay_with_stripe': 'Payer avec Stripe @amount',
      'payment_pay_with_paypal': 'Payer avec PayPal @amount',
      'booking_agreement_title': 'Accord de réservation',
      'booking_agreement_payment_completed': 'Paiement effectué',
      'booking_agreement_booking_cancelled': 'Réservation annulée',
      'booking_agreement_status_label': 'Statut : @status',
      'booking_agreement_start_date_label': 'Date de début',
      'booking_agreement_end_date_label': 'Date de fin',
      'booking_agreement_time_slot_label': 'Créneau horaire',
      'booking_agreement_service_provider_label': 'Prestataire',
      'booking_agreement_service_type_label': 'Type de service',
      'booking_agreement_special_instructions_label': 'Instructions spéciales',
      'booking_agreement_cancelled_at_label': 'Annulé le',
      'booking_agreement_cancellation_reason_label': 'Motif d\'annulation',
      'booking_agreement_price_breakdown_title': 'Détail des prix',
      'booking_agreement_pricing_tier_label': 'Palier tarifaire',
      'booking_agreement_total_hours_label': 'Total heures',
      'booking_agreement_total_days_label': 'Total jours',
      'booking_agreement_base_price_label': 'Prix de base',
      'booking_agreement_platform_fee_label': 'Frais de plateforme',
      'booking_agreement_net_amount_label': 'Montant net (au pet sitter)',
      'booking_agreement_today_at': 'Aujourd\'hui à @time',
      'booking_agreement_yesterday_at': 'Hier à @time',
      'booking_agreement_at': 'à',
      'payment_method_paypal': 'PayPal',
      'payment_pay_button': 'Payer @amount',
      'payment_amount_label': 'Montant à payer',
      'payment_loading_page': 'Chargement de la page de paiement...',
      'payment_cancel_title': 'Annuler le paiement ?',
      'payment_cancel_message': 'Voulez-vous vraiment annuler ce paiement ?',
      'payment_continue': 'Continuer le paiement',
      'payment_load_error':
          'Échec du chargement de la page de paiement : @error',
      'payment_success_title': 'Paiement réussi !',
      'payment_failed_title': 'Échec du paiement',
      'payment_success_message': 'Votre paiement a été traité avec succès.',
      'payment_rate_sitter': 'Noter le pet sitter',
      'payment_try_again': 'Réessayer',
      'payment_transaction_details': 'Détails de la transaction',
      'payment_transaction_id_label': 'ID de transaction',
      'payment_date_label': 'Date',
      'payment_error_client_secret_missing':
          'Échec de la création de l\'intention de paiement. Le secret client est manquant.',
      'payment_error_publishable_key_missing': 'Clé publique Stripe manquante.',
      'payment_error_invalid_publishable_key': 'Clé publique Stripe invalide.',
      'payment_processing_failed':
          'Échec du traitement du paiement. Veuillez réessayer.',
      'payment_error_title': 'Erreur de paiement',
      'payment_unavailable_title': 'Paiement indisponible',
      'payment_unavailable_message':
          'Le compte Stripe du pet sitter n\'est pas encore entièrement vérifié. Il doit compléter la vérification de son compte (y compris l\'identité, le compte bancaire et les détails de l\'entreprise) avant de pouvoir recevoir des paiements. Veuillez contacter le pet sitter pour compléter la configuration de son compte Stripe.',
      'payment_invalid_amount_title': 'Montant invalide',
      'payment_invalid_amount_message':
          'Le montant du paiement est invalide. Veuillez contacter le support.',
      'payment_initiate_error':
          'Échec de l\'initiation du paiement. Veuillez réessayer.',
      'payment_confirmation_failed':
          'Échec de la confirmation du paiement. Veuillez contacter le support.',
      'review_already_reviewed_title': 'Déjà noté',
      'review_already_reviewed_message':
          'Vous avez déjà noté ce pet sitter. Vous ne pouvez soumettre qu\'une seule note par pet sitter.',
      'sitter_applications_tab': 'Candidatures',
      'sitter_no_bookings_found': 'Aucune réservation trouvée',
      'sitter_application_accepted_success': 'Candidature acceptée avec succès',
      'sitter_application_accept_failed':
          'Échec de l\'acceptation de la candidature. Veuillez réessayer.',
      'sitter_application_rejected_success': 'Candidature rejetée avec succès',
      'sitter_application_reject_failed':
          'Échec du rejet de la candidature. Veuillez réessayer.',
      'sitter_chat_start_failed':
          'Échec du démarrage de la conversation. Veuillez réessayer.',
      'sitter_chat_with_owner': 'Discuter avec le propriétaire',
      'sitter_pet_weight': 'Poids',
      'sitter_pet_height': 'Taille',
      'sitter_pet_color': 'Couleur',
      'sitter_not_yet_available': 'Pas encore disponible',
      'sitter_detail_date': 'Date',
      'sitter_detail_time': 'Heure',
      'sitter_detail_phone': 'Téléphone',
      'sitter_detail_email': 'E-mail',
      'sitter_detail_location': 'Localisation',
      'sitter_not_available_yet': 'Pas encore disponible',
      'sitter_reject': 'Rejeter',
      'sitter_accept': 'Accepter',
      'sitter_status_label': 'Statut : @status',
      'sitter_payment_status_label': 'Paiement : @status',
      'sitter_time_just_now': 'À l\'instant',
      'sitter_time_mins_ago': 'Il y a @minutes min',
      'sitter_time_hours_ago': 'Il y a @hours h',
      'sitter_time_days_ago': 'Il y a @days jours',
      'sitter_weekday_mon': 'Lun',
      'sitter_weekday_tue': 'Mar',
      'sitter_weekday_wed': 'Mer',
      'sitter_weekday_thu': 'Jeu',
      'sitter_weekday_fri': 'Ven',
      'sitter_weekday_sat': 'Sam',
      'sitter_weekday_sun': 'Dim',
      'sitter_month_jan': 'Jan',
      'sitter_month_feb': 'Fév',
      'sitter_month_mar': 'Mar',
      'sitter_month_apr': 'Avr',
      'sitter_month_may': 'Mai',
      'sitter_month_jun': 'Juin',
      'sitter_month_jul': 'Juil',
      'sitter_month_aug': 'Août',
      'sitter_month_sep': 'Sep',
      'sitter_month_oct': 'Oct',
      'sitter_month_nov': 'Nov',
      'sitter_month_dec': 'Déc',
      'sitter_service_long_term_care': 'Garde à long terme',
      'sitter_service_dog_walking': 'Promenade de chien',
      'sitter_service_overnight_stay': 'Séjour nocturne',
      'sitter_service_home_visit': 'Visite à domicile',
      'sitter_request_details_title': 'Détails de la demande',
      'sitter_requests_section': 'Demandes',
      'sitter_info_pets': 'Animaux',
      'sitter_no_pets': 'Aucun animal',
      'sitter_info_service': 'Service',
      'sitter_no_service_type': 'Aucun type de service disponible',
      'sitter_info_date': 'Date',
      'sitter_no_date_available': 'Aucune date disponible',
      'sitter_pets_section': 'Animaux',
      'sitter_note_section': 'Note',
      'sitter_no_note_provided': 'Aucune note fournie.',
      'sitter_decline': 'Refuser',
      'owner_booking_details_title': 'Détails de la réservation',
      'owner_service_provider_section': 'Prestataire de services',
      'owner_info_pets': 'Animaux',
      'owner_no_pets': 'Aucun animal',
      'owner_info_service': 'Service',
      'owner_no_service_type': 'Aucun type de service disponible',
      'owner_info_date': 'Date',
      'owner_no_date_available': 'Aucune date disponible',
      'owner_info_total_amount': 'Montant total',
      'owner_pets_section': 'Animaux',
      'owner_note_section': 'Note',
      'owner_no_note_provided': 'Aucune note fournie.',
      'owner_chat_with_sitter': 'Discuter avec le pet sitter',
      'owner_pay_now': 'Payer maintenant',
      'owner_pay_with_amount': 'Payer \$@amount',
      'owner_cancel_booking': 'Annuler la réservation',
      'owner_time_just_now': 'À l\'instant',
      'owner_time_mins_ago': 'Il y a @minutes min',
      'owner_time_hours_ago': 'Il y a @hours h',
      'owner_time_days_ago': 'Il y a @days jours',
      'owner_weekday_mon': 'Lun',
      'owner_weekday_tue': 'Mar',
      'owner_weekday_wed': 'Mer',
      'owner_weekday_thu': 'Jeu',
      'owner_weekday_fri': 'Ven',
      'owner_weekday_sat': 'Sam',
      'owner_weekday_sun': 'Dim',
      'owner_month_jan': 'Jan',
      'owner_month_feb': 'Fév',
      'owner_month_mar': 'Mar',
      'owner_month_apr': 'Avr',
      'owner_month_may': 'Mai',
      'owner_month_jun': 'Juin',
      'owner_month_jul': 'Juil',
      'owner_month_aug': 'Août',
      'owner_month_sep': 'Sep',
      'owner_month_oct': 'Oct',
      'owner_month_nov': 'Nov',
      'owner_month_dec': 'Déc',
      'owner_service_long_term_care': 'Garde à long terme',
      'owner_service_dog_walking': 'Promenade de chien',
      'owner_service_overnight_stay': 'Séjour nocturne',
      'owner_service_home_visit': 'Visite à domicile',
      'owner_rating_with_reviews': '@rating (@count avis)',
      'owner_pet_needs_medication': 'Nécessite des médicaments / @medication',
      // Home screen & applications
      'home_default_user_name': 'Utilisateur',
      'home_no_sitters_message': 'Aucun pet sitter disponible pour le moment.',
      'home_block_sitter_message':
          'Voulez-vous vraiment bloquer @name ? Vous ne pourrez plus voir son profil ni lui envoyer de demandes.',
      'home_block_sitter_yes': 'Annuler',
      'home_block_sitter_no': 'Bloquer',
      'status_available': 'disponible',
      'applications_tab_title': 'Candidatures',
      'bookings_tab_title': 'Réservations',
      'applications_empty_message': 'Aucune candidature trouvée',
      'bookings_empty_message': 'Aucune réservation trouvée',
      'booking_cancel_dialog_message':
          'Voulez-vous vraiment annuler cette réservation ?',
      // Common UI
      'common_select': 'Sélectionner',
      'common_save': 'Enregistrer',
      'common_later': 'Plus tard',
      'common_saving': 'Enregistrement...',
      // Expandable post input
      'post_input_label': 'Publication',
      'post_input_hint': 'Écrivez votre publication ici...',
      'post_button': 'Publier',
      'post_button_posting': 'Publication en cours...',
      'my_posts_title': 'Mes publications',
      'home_segment_sitters': 'Pet-sitters',
      'my_posts_no_posts': 'Aucune publication trouvée',
      'my_posts_delete_title': 'Supprimer la publication ?',
      'my_posts_delete_message':
          'Voulez-vous vraiment supprimer cette publication ? Cette action est irreversible.',
      'my_posts_delete_success': 'Publication supprimee avec succes.',
      'my_posts_delete_failed':
          'Echec de la suppression de la publication. Veuillez reessayer.',
      'my_posts_sort_label': 'Trier',
      'my_posts_sort_newest': 'Plus recent en premier',
      'my_posts_sort_oldest': 'Plus ancien en premier',
      'notifications_title': 'Notifications',
      'notifications_empty_title': 'Aucune notification',
      'notifications_empty_subtitle':
          'Quand il se passe quelque chose, vous le verrez ici.',
      'notifications_mark_all_read': 'Tout marquer comme lu',
      'notifications_load_failed': 'Impossible de charger les notifications.',
      'notifications_fallback_title': 'Notification',
      'notifications_post_view_title': 'Publication',
      'notifications_request_view_title': 'Demande du sitter',
      'notifications_application_not_found':
          'Cette demande n\'est plus disponible ou n\'a pas pu etre chargee.',
      'notifications_open_sitter_profile': 'Voir le profil du sitter',
      'notifications_loading': 'Chargement des notifications…',
      'notifications_loading_more': 'Chargement…',
      'post_action_delete': 'Supprimer',
      'post_request_default': 'Recherche d\'un pet sitter',
      // Tasks screens
      'view_task_title': 'Voir les tâches',
      'view_task_empty': 'Aucune tâche trouvée',
      'view_task_date_not_available': 'Date non disponible',
      'add_task_title': 'Ajouter une tâche',
      'add_task_title_label': 'Titre',
      'add_task_title_hint': 'Saisissez un titre',
      'add_task_description_label': 'Description',
      'add_task_description_hint': 'Texte...',
      'add_task_save_button': 'Enregistrer',
      'add_task_saving': 'Enregistrement...',
      // Change password
      'change_password_title': 'Changer le mot de passe',
      'change_password_new_label': 'Nouveau mot de passe',
      'change_password_confirm_label': 'Confirmer le mot de passe',
      'change_password_confirm_hint': 'Confirmez le mot de passe',
      // Add card
      'add_card_title': 'Ajouter une carte',
      'add_card_holder_label': 'Nom du titulaire',
      'add_card_holder_hint': 'Jean Dupont',
      'add_card_number_label': 'Numéro de carte',
      'add_card_number_hint': '0987 0986 5543 0980',
      'add_card_exp_label': 'Date d\'expiration',
      'add_card_exp_hint': '10/23',
      'add_card_cvc_label': 'CVC',
      'add_card_cvc_hint': '345',
      // My pets
      'my_pets_title': 'Mes animaux',
      'my_pets_add_pet': 'Ajouter un animal',
      'my_pets_error_loading': 'Erreur lors du chargement des animaux',
      'my_pets_retry': 'Réessayer',
      'my_pets_empty': 'Aucun animal trouvé',
      'my_pets_color_label': 'Couleur',
      'my_pets_profile_label': 'Profil',
      'my_pets_passport_label': 'Passeport',
      'my_pets_chip_label': 'Puce',
      'my_pets_allergies_label': 'Allergies',
      // Create pet profile
      'create_pet_appbar_title': 'Utilisateur',
      'create_pet_skip': 'Passer',
      'create_pet_header': 'Créer un profil pour l’animal',
      'create_pet_name_label': 'Nom de l’animal',
      'create_pet_name_hint': 'Entrez le nom de votre animal',
      'create_pet_breed_label': 'Race',
      'create_pet_breed_hint': 'Entrez la race',
      'create_pet_dob_label': 'Date de naissance',
      'create_pet_dob_hint': 'Entrez la date de naissance de votre animal',
      'create_pet_weight_label': 'Poids (KG)',
      'create_pet_weight_hint': 'ex. 12 kg',
      'create_pet_height_label': 'Taille (CM)',
      'create_pet_height_hint': 'ex. 50 cm',
      'create_pet_passport_label': 'Numéro de passeport',
      'create_pet_passport_hint': 'Entrez le numéro de passeport',
      'create_pet_chip_label': 'Numéro de puce',
      'create_pet_chip_hint': 'Entrez le numéro de puce',
      'create_pet_med_allergies_label': 'Allergies médicamenteuses',
      'create_pet_med_allergies_hint': 'Entrez les allergies médicamenteuses',
      'create_pet_category_label': 'Catégorie',
      'create_pet_category_dog': 'Chien',
      'create_pet_category_cat': 'Chat',
      'create_pet_category_bird': 'Oiseau',
      'create_pet_category_rabbit': 'Lapin',
      'create_pet_category_other': 'Autre',
      'create_pet_vaccination_label': 'Vaccination',
      'create_pet_vaccination_up_to_date': 'À jour',
      'create_pet_vaccination_not_vaccinated': 'Non vacciné',
      'create_pet_vaccination_partial': 'Partiellement vacciné',
      'create_pet_profile_view_label': 'Visibilité du profil',
      'create_pet_profile_view_public': 'Public',
      'create_pet_profile_view_private': 'Privé',
      'create_pet_profile_view_friends': 'Amis uniquement',
      'create_pet_upload_media_label':
          'Télécharger des photos et vidéos de l’animal',
      'create_pet_upload_media_upload': 'Télécharger',
      'create_pet_upload_media_change': 'Modifier (@count)',
      'create_pet_upload_media_selected': '@count fichier(s) sélectionné(s)',
      'create_pet_upload_passport_label':
          'Télécharger la photo du passeport de l’animal',
      'create_pet_upload_passport_change': 'Modifier',
      'create_pet_upload_passport_upload': 'Télécharger',
      'create_pet_upload_passport_selected': 'Photo du passeport sélectionnée',
      'create_pet_button_creating': 'Création du profil...',
      'create_pet_button': 'Créer le profil de l’animal',
      // Send request screen
      'send_request_title': 'Envoyer une demande',
      'send_request_description_label': 'Description',
      'send_request_description_hint': 'Ajoutez des détails supplémentaires...',
      'label_pets': 'Animaux',
      'send_request_no_pets_message':
          'Aucun animal. Ajoutez un animal pour continuer.',
      'send_request_pets_select_placeholder': 'Sélectionner',
      'send_request_dates_label': 'Dates',
      'send_request_start_label': 'Début',
      'send_request_end_label': 'Fin',
      'send_request_select_date': 'Sélectionner une date',
      'send_request_select_time': 'Sélectionner une heure',
      'send_request_service_type_label': 'Type de service',
      'send_request_service_long_term_care': 'Garde à long terme',
      'send_request_service_dog_walking': 'Promenade de chien',
      'send_request_service_overnight_stay': 'Séjour nocturne',
      'send_request_service_home_visit': 'Visite à domicile',
      'send_request_duration_label': 'Durée (minutes)',
      'send_request_duration_minutes_label': '@minutes min',
      'send_request_button': 'Envoyer la demande',
      'send_request_button_sending': 'Envoi en cours...',
      'send_request_validation_error_title': 'Erreur de validation',
      'send_request_invalid_time_title': 'Heure invalide',
      'send_request_invalid_time_message':
          "L'heure de fin doit être postérieure à l'heure de début.",
      // Publier une demande de réservation (propriétaire) - UI uniquement
      'publish_request_home_cta': 'Publier une demande de réservation',
      'publish_request_title': 'Publier une demande',
      'publish_request_select_pets': 'Sélectionner un/des animal(aux)',
      'publish_request_selected_pets': '@count sélectionné(s)',
      'publish_request_select_pets_title': 'Sélectionner des animaux',
      'publish_request_notes_label': 'Notes supplémentaires',
      'publish_request_notes_hint': 'Tout ce que le pet sitter doit savoir...',
      'publish_request_address_label': 'Adresse (optionnelle)',
      'publish_request_address_hint': 'Rue, bâtiment, etc.',
      'publish_request_images_label': 'Images',
      'publish_request_add_images': 'Ajouter des images',
      'publish_request_add_more_images': 'Ajouter plus d\'images',
      'publish_request_publish_button': 'Publier la demande',
      'publish_request_fill_required':
          'Veuillez remplir tous les champs requis.',
      'publish_request_ui_only_success': 'UI créée (pas encore publiée).',
      'publish_request_success': 'Demande de réservation publiée avec succès !',
      'publish_request_service_walking': 'Promenade',
      'publish_request_service_boarding': 'Hébergement',
      'publish_request_service_daycare': 'Garderie',
      'publish_request_service_pet_sitting': 'Garde d\'animaux',
      'publish_request_service_house_sitting': 'Garde à domicile',
      'house_sitting_venue_label': 'Lieu du house sitting',
      'house_sitting_venue_owners_home': 'Chez le propriétaire',
      'house_sitting_venue_sitters_home': 'Chez le pet-sitter',
      // Chat screens
      'chat_error_loading_conversations':
          'Erreur lors du chargement des conversations',
      'chat_retry': 'Réessayer',
      'chat_no_conversations': 'Aucune conversation pour le moment',
      'chat_error_loading_messages': 'Erreur lors du chargement des messages',
      'chat_no_messages':
          'Aucun message pour le moment. Commencez la conversation !',
      'chat_input_hint': 'Écrire un message...',
      'chat_locked_title': 'Chat verrouillé',
      'chat_locked_after_payment':
          'Le chat est disponible uniquement après le paiement de la réservation.',
      // Pets map screen
      'map_search_hint': 'Rechercher une ville ou une zone',
      'map_search_empty': 'Veuillez entrer un lieu.',
      'map_search_not_found': 'Lieu introuvable : @query',
      'map_search_failed': 'La recherche a échoué. Veuillez réessayer.',
      'map_offers_near_me': 'Offres près de moi',
      'map_radius_label': 'Rayon :',
      // IBAN Payout
      'payout_iban_title': 'Paiement bancaire (IBAN)',
      'payout_iban_info': 'Ajoutez votre compte bancaire pour recevoir vos paiements directement, comme Vinted. Un admin vérifiera votre IBAN avant votre premier virement.',
      'payout_current_iban': 'Compte bancaire actuel',
      'payout_method_label': 'Méthode de paiement',
      'payout_add_iban': 'Ajouter / Modifier IBAN',
      'payout_iban_holder': 'Titulaire du compte',
      'payout_iban_holder_required': 'Le nom du titulaire est requis',
      'payout_iban_required': 'L\'IBAN est requis',
      'payout_iban_invalid': 'Format IBAN invalide',
      'payout_save_iban': 'Enregistrer le compte bancaire',
      'map_distance_filter_label': 'Distance : @km km',
      'map_no_nearby_sitters': 'Aucun pet sitter à proximité',
      'map_sitter_services_distance': '@services • @distance km',
      // Service provider detail screen
      'sitter_detail_loading_name': 'Chargement...',
      'sitter_detail_load_error':
          'Impossible de charger les détails du pet sitter',
      'sitter_detail_no_rating': 'Aucune note pour le moment',
      'sitter_detail_about_title': 'À propos de @name',
      'sitter_detail_no_bio': 'Aucune biographie disponible.',
      'sitter_detail_booking_details_title': 'Détails de la réservation',
      'sitter_detail_availability_pricing_title': 'Disponibilités et tarifs',
      'sitter_detail_hourly_rate_label': 'Tarif horaire',
      'sitter_detail_weekly_rate_label': 'Tarif hebdomadaire',
      'sitter_detail_monthly_rate_label': 'Tarif mensuel',
      'sitter_detail_current_status_label': 'Statut actuel',
      'sitter_detail_application_status_label': 'Statut de la demande',
      'sitter_detail_skills_title': 'Compétences',
      'sitter_detail_no_skills': 'Aucune compétence indiquée.',
      'sitter_detail_reviews_title': 'Avis',
      'sitter_detail_no_reviews': 'Aucun avis pour le moment.',
      'sitter_detail_anonymous_reviewer': 'Anonyme',
      'sitter_detail_starting_chat': 'Démarrage...',
      'sitter_detail_unlock_after_payment': 'Déverrouiller après paiement',
      'sitter_detail_start_chat': 'Démarrer le chat',
      'sitter_detail_start_chat_failed':
          'Échec du démarrage de la conversation. Veuillez réessayer.',
      'status_available_label': 'Disponible',
      'status_cancelled_label': 'Annulée',
      'status_rejected_label': 'Refusée',
      'status_pending_label': 'En attente',
      'status_agreed_label': 'Acceptée',
      'status_paid_label': 'Payée',
      'status_accepted_label': 'Acceptée',
      // Pet detail screen
      'pet_detail_loading': 'Chargement des détails de l\'animal...',
      'pet_detail_about': 'À propos de @name',
      'pet_detail_weight': 'Poids',
      'pet_detail_height': 'Taille',
      'pet_detail_color': 'Couleur',
      'pet_detail_passport_number': 'Numéro de passeport',
      'pet_detail_chip_number': 'Numéro de puce',
      'pet_detail_medication_allergies': 'Médicaments/Allergies',
      'pet_detail_date_of_birth': 'Date de naissance',
      'pet_detail_category': 'Catégorie',
      'pet_detail_vaccinations': 'Vaccinations de @name',
      'pet_detail_gallery': 'Galerie de @name',
      'pet_detail_no_photos': 'Aucune photo disponible',
      'pet_detail_owner_information': 'Informations sur le propriétaire',
      'pet_detail_owner_name': 'Nom',
      'pet_detail_owner_created_at': 'Créé le',
      'pet_detail_owner_updated_at': 'Mis à jour le',
      'pet_detail_no_description': 'Aucune description disponible',
      'pet_detail_gender_unknown': 'Inconnu',
      'pet_detail_breed_unknown': 'Inconnu',
      'pet_detail_no_vaccinations': 'Aucune vaccination répertoriée',
      'pet_detail_load_error':
          'Échec du chargement des détails de l\'animal. Veuillez réessayer.',
      // Sitter bookings screen
      'sitter_bookings_title': 'Mes réservations',
      'sitter_bookings_empty_all': 'Aucune réservation trouvée',
      'sitter_bookings_empty_filtered': 'Aucune réservation @status trouvée',
      'sitter_bookings_pet_label': 'Animal',
      'sitter_bookings_date_label': 'Date',
      'sitter_bookings_time_label': 'Heure',
      'sitter_bookings_rate_label': 'Tarif',
      'sitter_bookings_description_label': 'Description',
      'sitter_bookings_cancel_button': 'Annuler la réservation',
      'sitter_bookings_cancel_dialog_message':
          'Êtes-vous sûr de vouloir annuler cette réservation ?',
      'sitter_bookings_cancel_dialog_yes': 'Oui, annuler',
      'sitter_bookings_cancel_success':
          'Demande d\'annulation soumise avec succès !',
      'sitter_bookings_cancel_error':
          'Échec de la demande d\'annulation. Veuillez réessayer.',
      // Owner bookings controller
      'bookings_cancel_success': 'Réservation annulée avec succès !',
      'bookings_cancel_error':
          'Échec de l\'annulation de la réservation. Veuillez réessayer.',
      'bookings_cancel_request_success':
          'Demande d\'annulation soumise avec succès !',
      'bookings_cancel_request_error':
          'Échec de la demande d\'annulation. Veuillez réessayer.',
      'request_cancel_button': 'Annuler la demande',
      'request_cancel_button_cancelling': 'Annulation...',
      'request_cancel_success': 'Demande annulée avec succès !',
      'request_cancel_error':
          'Échec de l\'annulation de la demande. Veuillez réessayer.',
      'bookings_payment_status_error':
          'Échec de l\'obtention du statut de paiement. Veuillez réessayer.',
      // Service provider card
      'service_card_no_phone': 'Aucun numéro disponible',
      'service_card_no_location': 'Aucun lieu disponible',
      'service_card_block': 'Bloquer',
      'service_card_per_hour_label': 'Par heure @price',
      'service_card_send_request': 'Envoyer une demande',
      'sitter_post_pet_details': 'Détails de l\'animal',
      'service_card_accept': 'Accepter',
      'service_card_reject': 'Refuser',
      'service_card_cancel': 'Annuler',
      'service_card_pay_with_amount': 'Payer @amount',
      'service_card_pay_now': 'Payer maintenant',
      'service_card_chat': 'Discussion',
      // Sitter bottom sheet
      'sitter_view_profile': 'Voir le profil',
      'sitter_rating_with_count': '@rating (@count avis)',
      // Bookings history
      'bookings_history_title': 'Historique des réservations',
      'status_all_label': 'Tout',
      'status_failed_label': 'Échoué',
      'status_refunded_label': 'Remboursé',
      'status_payment_pending_label': 'Paiement en attente',
      'status_payment_failed_label': 'Paiement échoué',
      'bookings_history_empty_all': 'Aucune réservation trouvée',
      'bookings_history_empty_filtered': 'Aucune réservation @status trouvée',
      'bookings_detail_pet_label': 'Animal',
      'bookings_detail_date_label': 'Date',
      'bookings_detail_time_label': 'Heure',
      'bookings_detail_total_amount_label': 'Montant total',
      'bookings_detail_phone_label': 'Téléphone',
      'bookings_detail_location_label': 'Lieu',
      'bookings_detail_rating_label': 'Note',
      'bookings_detail_description_label': 'Description',
      'bookings_action_view_details': 'Voir les détails',
      'Email Not Verified': 'Email Not Verified',
      'Image Error': 'Image Error',
      'Invalid Hourly Rate': 'Invalid Hourly Rate',
      'Location Found': 'Location Found',
      'Location Not Found': 'Location Not Found',
      'Required': 'Required',
      'Role Switched': 'Role Switched',
      'Selection Failed': 'Selection Failed',
      'Selection Required': 'Selection Required',
      'Service Updated': 'Service Updated',
      'Services Selected': 'Services Selected',
      'Success': 'Success',
      'Switch Role Failed': 'Switch Role Failed',
      'Verification Code Sent': 'Verification Code Sent',
      'auth_apple_signin_failed': 'Échec de la connexion Apple',
      'auth_apple_signin_failed_generic':
          'Un problème est survenu. Veuillez réessayer.',
      'auth_apple_signin_success': 'Connexion avec Apple réussie',
      'auth_google_signin_choose_services': 'Veuillez choisir vos services',
      'auth_google_signin_failed': 'La connexion Google a échoué. Réessayez.',
      'auth_google_signin_firebase_token_failed':
          'Impossible d\'obtenir le jeton Firebase ID.',
      'auth_google_signin_success': 'Connexion avec Google réussie',
      'auth_google_signin_title': 'Connexion Google',
      'auth_google_signin_token_missing': 'Le jeton Google ID est manquant.',
      'auth_google_signin_web_required':
          'Cette plateforme nécessite une connexion web.',
      'auth_role_switch_failed':
          'Impossible de changer de rôle. Veuillez réessayer.',
      'auth_role_switched': 'Rôle changé',
      'auth_role_switched_message': 'Passage réussi à @role',
      'auth_welcome_back': 'Bon retour !',
      'change_password_failed': 'Failed to change password. Please try again.',
      'change_password_fields_required': 'Please fill in all fields correctly.',
      'change_password_new_required': 'Please enter a new password.',
      'change_password_success': 'Password changed successfully!',
      'change_password_validation_error': 'Validation Error',
      'email_verification_code_required':
          'Please enter the complete verification code',
      'email_verification_success': 'Email verified successfully!',
      'map_load_error': 'Failed to load map data. Please try again.',
      'my_pets_load_error': 'Failed to load pets. Please try again.',
      'pet_create_validation_error': 'Validation Error',
      'pet_update_failed': 'Update Failed',
      'pet_validation_error': 'Validation Error',
      'profile_blocked_users_load_error': 'Failed to load blocked users',
      'profile_edit_coming_soon':
          'Edit profile functionality will be available soon',
      'profile_image_pick_failed': 'Failed to pick image. Please try again.',
      'profile_invalid_file_type': 'Invalid File Type',
      'profile_invalid_file_type_message':
          'Please select a JPEG, PNG, or WebP image.',
      'profile_picture_update_success':
          'Photo de profil mise à jour avec succès',
      'profile_unblock_failed': 'Unblock Failed',
      'profile_unblock_failed_generic':
          'Something went wrong. Please try again.',
      'profile_unblock_success': 'User unblocked successfully',
      'profile_upload_failed': 'Upload Failed',
      'profile_upload_failed_generic':
          'Something went wrong. Please try again.',
      'profile_user_not_found': 'User not found',
      'request_duration_required':
          'Please select a duration for dog walking service.',
      'request_pet_required': 'Please select at least one pet.',
      'request_send_failed':
          'Impossible d\'envoyer la demande. Veuillez réessayer.',
      'request_send_success': 'Demande envoyée avec succès !',
      'request_sitter_pricing_error':
          'Veuillez d’abord définir votre tarif horaire dans le profil.',
      'request_validation_error': 'Validation Error',
      'review_submit_failed': 'Failed to submit review. Please try again.',
      'share_failed': 'Failed to share. Please try again.',
      'snackbar_choose_service_controller_001':
          'Please select valid services for your account type.',
      'snackbar_choose_service_controller_002':
          'Your services have been updated successfully!',
      'snackbar_choose_service_controller_003':
          'Your services have been selected successfully!',
      'snackbar_choose_service_controller_004':
          'Failed to update services. Please try again.',
      'snackbar_choose_service_controller_005':
          'Please select at least one service to continue.',
      'snackbar_choose_service_controller_006':
          'Please select a valid service to continue.',
      'snackbar_choose_service_controller_007':
          'Please select at least one service.',
      'snackbar_sitter_paypal_payout_controller_001':
          'L\'e-mail PayPal de paiement est requis.',
      'snackbar_sitter_paypal_payout_controller_002':
          'E-mail PayPal de paiement mis a jour avec succes !',
      'snackbar_sitter_paypal_payout_controller_003':
          'Echec de la mise a jour de l\'e-mail PayPal de paiement. Veuillez reessayer.',
      'task_add_failed': 'Failed to add task. Please try again.',
      'task_add_success': 'Task added successfully!',
      'task_fetch_failed': 'Failed to fetch tasks.',
      'task_fields_required': 'Please fill in at least one field.',

      'snackbar_text_application_accepted_successfully':
          'Candidature acceptee avec succes',
      'snackbar_text_application_rejected_successfully':
          'Candidature rejetee avec succes',
      'snackbar_text_blocked_users_saved_successfully':
          'Utilisateurs bloques enregistres avec succes',
      'snackbar_text_card_saved_successfully':
          'Carte enregistree avec succes !',
      'snackbar_text_could_not_detect_your_location_please_enable_location_servic':
          'Impossible de detecter votre position. Veuillez activer les services de localisation.',
      'snackbar_text_could_not_load_nearby_sitters_please_try_again':
          'Impossible de charger les pet sitters a proximite. Veuillez reessayer.',
      'snackbar_text_email_not_verified': 'E-mail non vérifié',
      'snackbar_text_failed_to_complete_profile_please_try_again':
          'Impossible de terminer le profil. Veuillez reessayer.',
      'snackbar_text_failed_to_load_booking_details_using_default_pricing':
          'Impossible de charger les details de reservation. Tarification par defaut utilisee.',
      'snackbar_text_failed_to_load_pet_data_please_try_again':
          'Impossible de charger les donnees de l\'animal. Veuillez reessayer.',
      'snackbar_text_failed_to_load_sitter_details_please_try_again':
          'Impossible de charger les details du pet sitter. Veuillez reessayer.',
      'snackbar_text_failed_to_pick_passport_image_please_try_again':
          'Impossible de selectionner l\'image du passeport. Veuillez reessayer.',
      'snackbar_text_failed_to_pick_pet_pictures_or_videos_please_try_again':
          'Impossible de selectionner les photos ou videos de l\'animal. Veuillez reessayer.',
      'snackbar_text_failed_to_pick_pet_profile_image_please_try_again':
          'Impossible de selectionner l\'image de profil de l\'animal. Veuillez reessayer.',
      'snackbar_text_failed_to_save_card_please_try_again':
          'Impossible d\'enregistrer la carte. Veuillez reessayer.',
      'snackbar_text_failed_to_start_conversation_please_try_again':
          'Impossible de demarrer la conversation. Veuillez reessayer.',
      'snackbar_text_failed_to_switch_role_please_try_again':
          'Impossible de changer de role. Veuillez reessayer.',
      'snackbar_text_height_is_required': 'La taille est requise.',
      'snackbar_text_height_must_be_greater_than_0':
          'La taille doit etre superieure a 0.',
      'snackbar_text_hourly_rate_must_be_greater_than_0':
          'Le tarif horaire doit etre superieur a 0.',
      'snackbar_text_weekly_rate_must_be_greater_than_0':
          'Le tarif hebdomadaire doit etre superieur a 0.',
      'snackbar_text_monthly_rate_must_be_greater_than_0':
          'Le tarif mensuel doit etre superieur a 0.',
      'snackbar_text_invalid_url': 'URL invalide',
      'snackbar_text_unknown_error': 'Erreur inconnue',
      'snackbar_text_image_error': 'Erreur d\'image',
      'snackbar_text_image_uploaded_successfully':
          'Image telechargee avec succes !',
      'snackbar_text_invalid_hourly_rate': 'Taux horaire invalide',
      'snackbar_text_location_not_found': 'Emplacement introuvable',
      'snackbar_text_passwords_do_not_match':
          'Les mots de passe ne correspondent pas',
      'snackbar_text_pet_profile_created_but_media_upload_failed_you_can_add_medi':
          'Profil de l\'animal cree, mais le telechargement des medias a echoue. Vous pouvez ajouter des medias plus tard.',
      'snackbar_text_pet_profile_created_successfully':
          'Profil de l\'animal cree avec succes !',
      'snackbar_text_pet_profile_updated_successfully':
          'Profil de l\'animal mis a jour avec succes !',
      'snackbar_text_please_accept_the_terms_and_conditions':
          'Veuillez accepter les conditions generales.',
      'snackbar_text_please_enter_your_paypal_email':
          'Veuillez saisir votre e-mail PayPal.',
      'snackbar_text_please_fill_in_all_required_fields':
          'Veuillez remplir tous les champs obligatoires',
      'snackbar_text_please_try_logging_in_again': 'Veuillez vous reconnecter',
      'snackbar_text_profile_completed_successfully':
          'Profil complete avec succes !',
      'snackbar_text_profile_updated_but_image_upload_failed_please_try_again':
          'Profil mis a jour mais l\'envoi de l\'image a echoue. Veuillez reessayer.',
      'snackbar_text_required': 'Requis',
      'snackbar_text_review_submitted_successfully':
          'Avis envoye avec succes !',
      'snackbar_text_role_switched': 'Rôle commuté',
      'snackbar_text_selected_image_file_is_not_accessible_please_try_again':
          'Le fichier image selectionne est inaccessible. Veuillez reessayer.',
      'snackbar_text_selection_failed': 'Échec de la sélection',
      'snackbar_text_sitter_blocked_successfully':
          'Pet sitter bloque avec succes !',
      'snackbar_text_something_went_wrong_please_try_logging_in_again':
          'Une erreur est survenue. Veuillez vous reconnecter.',
      'snackbar_text_success': 'Succès',
      'snackbar_text_successfully_switched_to_userrole_value':
          'Changement de rôle réussi.',
      'snackbar_text_switch_role_failed': 'Échec du changement de rôle',
      'snackbar_text_unknown_user_role_please_try_again':
          'Role utilisateur inconnu. Veuillez reessayer.',
      'snackbar_text_verification_code_has_been_resent_to_your_email':
          'Le code de verification a ete renvoye a votre e-mail',
      'snackbar_text_verification_code_resent': 'Code de verification renvoye',
      'snackbar_text_verification_code_sent': 'Code de vérification envoyé',
      'snackbar_text_welcome_back': 'Bon retour !',
      'snackbar_text_you_have_already_reviewed_this_sitter_you_can_only_submit_on':
          'Vous avez deja evalue ce pet sitter. Vous ne pouvez soumettre qu\'un seul avis par pet sitter.',
    'post_more_options': 'Plus d\'options',
    'post_action_block_user': 'Bloquer l\'utilisateur',
    'post_action_report': 'Signaler la publication',
    'block_user_title': 'Bloquer l\'utilisateur',
    'block_user_action': 'Bloquer',
    'block_user_confirm_message': 'Etes-vous sur de vouloir bloquer cet utilisateur? Vous ne verrez plus son contenu.',
    'block_user_success': 'Utilisateur bloque avec succes.',
    'block_user_failed': 'Echec du blocage. Veuillez reessayer.',
    'report_post_received': 'Signalement recu. Merci.',
    'pet_photo_delete_title': 'Supprimer la photo',
    'pet_photo_delete_confirm': 'Voulez-vous vraiment supprimer cette photo?',
    'pet_photo_deleted': 'Photo supprimee avec succes.',
    'pet_photo_delete_failed': 'Echec de la suppression. Veuillez reessayer.',
    'new_publication_button': 'Nouvelle publication',
    },
    'es_ES': <String, String>{
      'common_yes': 'Sí',
      'common_no': 'No',
      'common_cancel': 'Cancelar',
      'common_error': 'Error',
      'common_success': 'Éxito',
      'common_select_value': 'Seleccionar valor',
      'label_not_available': 'N/D',
      'common_user': 'Usuario',
      'common_refresh': 'Actualizar',
      'common_search': 'Buscar',

      'Application accepted successfully': 'Application accepted successfully',
      'Application rejected successfully': 'Application rejected successfully',
      'Blocked users saved successfully': 'Blocked users saved successfully',
      'Card saved successfully!': 'Card saved successfully!',
      'Could not detect your location. Please enable location services.':
          'Could not detect your location. Please enable location services.',
      'Could not load nearby sitters. Please try again.':
          'Could not load nearby sitters. Please try again.',
      'Email verified successfully!': 'Email verified successfully!',
      'Failed to add task. Please try again.':
          'Failed to add task. Please try again.',
      'Failed to change password. Please try again.':
          'Failed to change password. Please try again.',
      'Failed to complete profile. Please try again.':
          'Failed to complete profile. Please try again.',
      'Failed to fetch tasks.': 'Failed to fetch tasks.',
      'Failed to get your location. Please try again.':
          'Failed to get your location. Please try again.',
      'Failed to load booking details. Using default pricing.':
          'Failed to load booking details. Using default pricing.',
      'Failed to load pet data. Please try again.':
          'Failed to load pet data. Please try again.',
      'Failed to load pets. Please try again.':
          'Failed to load pets. Please try again.',
      'Failed to load profile data. Please try again.':
          'Failed to load profile data. Please try again.',
      'Failed to load sitter details. Please try again.':
          'Failed to load sitter details. Please try again.',
      'Failed to pick image. Please try again.':
          'Failed to pick image. Please try again.',
      'Failed to pick passport image. Please try again.':
          'Failed to pick passport image. Please try again.',
      'Failed to pick pet pictures or videos. Please try again.':
          'Failed to pick pet pictures or videos. Please try again.',
      'Failed to pick pet profile image. Please try again.':
          'Failed to pick pet profile image. Please try again.',
      'Failed to save card. Please try again.':
          'Failed to save card. Please try again.',
      'Failed to start conversation. Please try again.':
          'Failed to start conversation. Please try again.',
      'Failed to submit review. Please try again.':
          'Failed to submit review. Please try again.',
      'Failed to switch role. Please try again.':
          'Failed to switch role. Please try again.',
      'Height is required.': 'Height is required.',
      'Height must be greater than 0.': 'Height must be greater than 0.',
      'Hourly rate must be greater than 0.':
          'Hourly rate must be greater than 0.',
      'Image uploaded successfully!': 'Image uploaded successfully!',
      'Password changed successfully!': 'Password changed successfully!',
      'Passwords do not match': 'Passwords do not match',
      'Pet profile created but media upload failed. You can add media later.':
          'Pet profile created but media upload failed. You can add media later.',
      'Pet profile created successfully!': 'Pet profile created successfully!',
      'Pet profile updated successfully!': 'Pet profile updated successfully!',
      'Please accept the Terms and Conditions':
          'Please accept the Terms and Conditions',
      'Please agree to the Terms and Conditions':
          'Please agree to the Terms and Conditions',
      'Please enter a new password.': 'Please enter a new password.',
      'Please enter the complete verification code':
          'Please enter the complete verification code',
      'Please enter your PayPal email.': 'Please enter your PayPal email.',
      'Please fill in all fields correctly.':
          'Please fill in all fields correctly.',
      'Please fill in all required fields':
          'Please fill in all required fields',
      'Please fill in at least one field.':
          'Please fill in at least one field.',
      'Please fix the highlighted fields and try again.':
          'Please fix the highlighted fields and try again.',
      'Please try logging in again': 'Please try logging in again',
      'Please verify your email to continue.':
          'Please verify your email to continue.',
      'Profile completed successfully!': 'Profile completed successfully!',
      'Profile picture updated successfully!':
          'Profile picture updated successfully!',
      'Profile updated successfully!': 'Profile updated successfully!',
      'Review submitted successfully!': 'Review submitted successfully!',
      'Selected image file is not accessible. Please try again.':
          'Selected image file is not accessible. Please try again.',
      'Sitter blocked successfully!': 'Sitter blocked successfully!',
      'Something went wrong. Please try again.':
          'Something went wrong. Please try again.',
      'Something went wrong. Please try logging in again.':
          'Something went wrong. Please try logging in again.',
      'Task added successfully!': 'Task added successfully!',
      'Unknown user role. Please try again.':
          'Unknown user role. Please try again.',
      'Verification code has been resent to your email':
          'Verification code has been resent to your email',
      'Verification code resent': 'Verification code resent',
      'Welcome back!': 'Welcome back!',
      'You have already reviewed this sitter. You can only submit one review per sitter.':
          'You have already reviewed this sitter. You can only submit one review per sitter.',
      'Your city (@city) has been detected':
          'Your city (@city) has been detected',
      'Profile updated but image upload failed. Please try again.':
          'Profile updated but image upload failed. Please try again.',
      'Profile updated but image upload failed: @error':
          'Profile updated but image upload failed: @error',

      // Posts / Comments
      'post_action_like': 'Me gusta',
      'post_action_comment': 'Comentar',
      'post_action_share': 'Compartir',
      'post_comments_title': 'Comentarios',
      'post_comments_hint': 'Añadir un comentario...',
      'post_comments_empty_title': 'Aún no hay comentarios',
      'post_comments_empty_subtitle': '¡Sé el primero en comentar!',
      'post_comment_added_success': '¡Comentario añadido con éxito!',
      'post_comment_add_failed':
          'No se pudo añadir el comentario. Inténtalo de nuevo.',
      'post_comments_count_singular': '@count comentario',
      'post_comments_count_plural': '@count comentarios',

      // Relative time
      'time_days_ago': 'hace @count d',
      'time_hours_ago': 'hace @count h',
      'time_minutes_ago': 'hace @count min',
      'time_just_now': 'Ahora mismo',
      'posts_empty_title': 'No hay publicaciones disponibles',
      'posts_load_failed':
          'No se pudieron cargar las publicaciones. Inténtalo de nuevo.',
      'posts_like_login_required':
          'Inicia sesión para dar me gusta a las publicaciones.',
      'posts_like_failed':
          'No se pudo dar me gusta a la publicación. Inténtalo de nuevo.',
      'posts_unlike_failed':
          'No se pudo quitar el me gusta. Inténtalo de nuevo.',
      'application_accept_success': '¡Solicitud aceptada con éxito!',
      'application_reject_success': '¡Solicitud rechazada con éxito!',
      'application_action_failed':
          'No se pudo responder a la solicitud. Inténtalo de nuevo.',
      'request_card_pet_owner': 'Dueño: @name',
      'sitter_reservation_requests': 'Solicitudes de reserva',
      'sitter_filters': 'Filtros',
      'sitter_filters_on': 'Filtros activos',
      'sitter_no_requests_match': 'Ninguna solicitud coincide con los filtros.',
      'filter_requests_title': 'Filtrar solicitudes',
      'filter_clear': 'Borrar',
      'filter_apply': 'Aplicar',
      'filter_location': 'Ubicación',
      'filter_service_type': 'Tipo de servicio',
      'filter_dates': 'Fechas',
      'filter_city_hint': 'Ciudad o zona',
      'filter_any_dates': 'Cualquier fecha',

      // Profile: Apple connection
      'profile_connect_with_apple': 'Conectar con Apple',
      'profile_connection_connected': 'Conectado',

      'sign_up_as_pet_owner': 'Registrarse como dueño',
      'sign_up_as_pet_sitter': 'Registrarse como cuidador',
      'label_name': 'Nombre',
      'hint_name': 'Introduce tu nombre',
      'label_email': 'Correo electrónico',
      'hint_email': 'Introduce tu correo electrónico',
      'label_mobile_number': 'Número de móvil',
      'hint_phone': 'Introduce tu número de teléfono',
      'profile_no_phone_added': 'Sin número añadido',
      'profile_no_email_added': 'Sin correo añadido',
      'label_password': 'Contraseña',
      'hint_password': 'Crea una contraseña',
      'password_requirement':
          'Debe tener al menos 8 caracteres e incluir mayúsculas, minúsculas y un número.',
      'label_language': 'Idioma',
      'hint_language': 'Indica los idiomas que hablas',
      'label_address': 'Dirección',
      'hint_address': 'Ubicación',
      'label_rate_per_hour': 'Tarifa por hora',
      'hint_rate_per_hour': 'p. ej., 20',
      'price_per_hour': 'Precio / hora',
      'price_per_day': 'Precio / día',
      'price_per_week': 'Precio / semana',
      'price_per_month': 'Precio / mes',
      'chat_payment_required_banner': 'El chat se abre tras la confirmación del pago.',
      'chat_pay_now_button': 'Pagar ahora',
      'chat_share_phone_button': 'Compartir mi número',
      'terms_read_button': 'Leer las Condiciones Generales',
      'service_prefs_at_owner_label': 'Acepto el servicio en mi casa',
      'service_prefs_at_sitter_label': 'Acepto el servicio en casa del cuidador',
      'service_location_label': '¿Dónde se realizará el servicio?',
      'service_location_at_owner': 'En mi casa',
      'service_location_at_sitter': 'En casa del cuidador',
      'service_location_both': 'Cualquiera',
      'profile_my_availability': 'Mi calendario de disponibilidad',
      'profile_verify_identity': 'Verificar mi identidad',
      'profile_identity_verified': 'Identidad verificada',
      'theme_setting_title': 'Tema',
      'theme_light': 'Claro',
      'theme_dark': 'Oscuro',
      'theme_system': 'Seguir el sistema',
      'common_close': 'Cerrar',
      'label_skills': 'Habilidades',
      'hint_skills': 'Veterinario, Educador',
      'label_bio': 'Biografía',
      'hint_bio': 'Cuéntanos sobre ti',
      'label_terms_prefix': 'Acepto los ',
      'label_terms_title': 'Términos y la Política de privacidad.',
      'or_sign_up_with': 'O regístrate con',
      'button_google': 'Google',
      'button_apple': 'Apple',
      'button_create_account': 'Crear cuenta',
      'button_creating_account': 'Creando cuenta…',
      'button_logout': 'Cerrar sesión',
      'title_login': 'Iniciar sesión',
      'welcome_back': 'Bienvenido de nuevo 👋',
      'login_subtitle': 'Inicia sesión para continuar en Hopetsit.',
      'hint_password_login': 'Introduce tu contraseña',
      'forgot_password': '¿Olvidaste tu contraseña?',
      'forgot_password_reset_title': 'Restablecer tu contraseña',
      'forgot_password_reset_message':
          'Introduce tu dirección de correo electrónico y te enviaremos un código para restablecer tu contraseña.',
      'forgot_password_email_label': 'Dirección de correo electrónico',
      'forgot_password_sending_code': 'Enviando código...',
      'forgot_password_send_code': 'Enviar código de verificación',
      'forgot_password_remember': '¿Recuerdas tu contraseña? ',
      'forgot_password_otp_sent_title': 'Código Enviado',
      'forgot_password_otp_sent_message':
          'El código de verificación ha sido enviado a tu correo electrónico',
      'forgot_password_request_failed': 'Solicitud Fallida',
      'forgot_password_verified_title': 'Verificado',
      'forgot_password_verified_message':
          'Ahora puedes restablecer tu contraseña',
      'forgot_password_verification_failed': 'Verificación Fallida',
      'forgot_password_reset_success':
          'Tu contraseña ha sido restablecida exitosamente',
      'forgot_password_reset_failed': 'Restablecimiento Fallido',
      'forgot_password_code_resent_title': 'Código Reenviado',
      'forgot_password_code_resent_message':
          'El código de verificación ha sido reenviado a tu correo electrónico',
      'forgot_password_resend_failed': 'Reenvío Fallido',
      'forgot_password_verify_code_title': 'Verificar código',
      'forgot_password_enter_code_title': 'Introduce el código de verificación',
      'forgot_password_code_sent_to':
          'Hemos enviado un código de 6 dígitos a @email',
      'forgot_password_verifying': 'Verificando...',
      'forgot_password_resend_in': 'Reenviar código en @seconds s',
      'forgot_password_resend_code': 'Reenviar código',
      'forgot_password_wrong_email': '¿Correo incorrecto? ',
      'forgot_password_change_email': 'Cambiarlo',
      'forgot_password_create_new_title': 'Crear nueva contraseña',
      'forgot_password_set_new_title': 'Establece tu nueva contraseña',
      'forgot_password_set_new_message':
          'Crea una contraseña segura para proteger tu cuenta. Asegúrate de que tenga al menos 8 caracteres.',
      'forgot_password_new_hint': 'Introduce la nueva contraseña',
      'forgot_password_confirm_hint': 'Vuelve a introducir tu contraseña',
      'forgot_password_resetting': 'Restableciendo contraseña...',
      'forgot_password_reset_button': 'Restablecer contraseña',
      'forgot_password_reset_success_title':
          '¡Contraseña restablecida con éxito!',
      'forgot_password_reset_success_message':
          'Tu contraseña ha sido restablecida exitosamente. Ahora puedes iniciar sesión con tu nueva contraseña.',
      'forgot_password_email_verified_title': 'Correo verificado',
      'forgot_password_email_verified_subtitle':
          'Tu correo electrónico ha sido verificado',
      'forgot_password_password_updated_title': 'Contraseña actualizada',
      'forgot_password_password_updated_subtitle':
          'Tu contraseña ha sido cambiada',
      'forgot_password_login_new_password':
          'Iniciar sesión con nueva contraseña',
      'forgot_password_security_warning':
          'Si no solicitaste este cambio, por favor protege tu cuenta inmediatamente.',
      'logging_in': 'Iniciando sesión...',
      'or_continue_with': 'O continuar con',
      'dont_have_account': '¿No tienes una cuenta? ',
      'sign_up': 'Registrarse',
      // Onboarding screen
      'onboarding_app_title': 'Home Pets Sitting',
      'onboarding_continue_with_google': 'Continuar con Google',
      'onboarding_continue_with_apple': 'Continuar con Apple',
      'onboarding_have_account': '¿Tienes una cuenta?',

      'error_invalid_details_title': 'Datos no válidos',
      'error_invalid_details_message':
          'Corrige los campos marcados y vuelve a intentarlo.',
      'error_terms_required_title': 'Términos requeridos',
      'error_terms_required_message': 'Acepta los Términos y Condiciones.',
      'error_name_required': 'Introduce tu nombre',
      'error_name_length': 'El nombre debe tener al menos 2 caracteres',
      'error_email_required': 'Introduce tu correo electrónico',
      'error_email_invalid':
          'Introduce una dirección de correo electrónico válida',
      'error_phone_invalid': 'Introduce un número de teléfono válido',
      'error_phone_required': 'Introduce tu número de teléfono',
      'error_password_required': 'Introduce una contraseña',
      'error_password_length': 'La contraseña debe tener al menos 8 caracteres',
      'error_password_uppercase':
          'La contraseña debe contener al menos una letra mayúscula',
      'error_password_lowercase':
          'La contraseña debe contener al menos una letra minúscula',
      'error_password_number': 'La contraseña debe contener al menos un número',
      'error_password_confirm_required': 'Por favor confirma tu contraseña',
      'error_password_match': 'Las contraseñas no coinciden',
      'error_otp_required': 'El código OTP es obligatorio',
      'error_otp_length': 'El código OTP debe tener 6 dígitos',
      'error_otp_numbers_only': 'El código OTP solo debe contener números',
      'common_error_generic': 'Algo salió mal. Por favor inténtalo de nuevo.',
      'error_address_required': 'Introduce tu dirección',
      'error_address_length': 'La dirección debe tener al menos 2 caracteres',
      'error_rate_required': 'Introduce tu tarifa por hora',
      'error_rate_invalid': 'Introduce una tarifa válida',
      'error_rate_zero': 'La tarifa por hora no puede ser 0',
      'error_skills_required': 'Introduce tus habilidades',
      'error_skills_length':
          'Las habilidades deben tener al menos 2 caracteres',

      'location_found_title': 'Ubicación encontrada',
      'location_found_message': 'Se ha detectado tu ciudad (@city)',
      'location_not_found_title': 'Ubicación no encontrada',
      'location_not_found_message':
          'No se pudo detectar tu ubicación. Activa los servicios de ubicación.',
      'location_error_title': 'Error',
      'location_error_message':
          'No se pudo obtener tu ubicación. Inténtalo de nuevo.',
      // Location picker
      'label_city': 'Ciudad',
      'location_getting': 'Obteniendo...',
      'location_auto': 'Auto',
      'location_map': 'Mapa',
      'location_detected': 'Detectado: @city',
      'location_enter_city': 'Introduce tu ciudad',
      'error_city_required': 'Por favor introduce tu ciudad',
      'location_detected_message':
          'Tu ubicación ha sido detectada. Te conectarás con proveedores de servicios en esta zona.',
      'location_select_title': 'Seleccionar Ubicación',
      'location_selected': 'Ubicación Seleccionada',
      'location_selected_city': 'Ciudad Seleccionada',
      'location_no_city': 'Ninguna ciudad seleccionada',
      'location_latitude': 'Latitud: @value',
      'location_longitude': 'Longitud: @value',
      'location_current': 'Actual',
      'location_confirm': 'Confirmar',
      'location_select_error': 'Por favor selecciona una ubicación',
      'location_get_error': 'No se pudo obtener tu ubicación',

      'signup_account_created_title': 'Cuenta creada',
      'signup_account_created_message':
          'Verifica tu correo electrónico para continuar.',
      'signup_failed_title': 'Error en el registro',
      'signup_failed_generic_message': 'Algo salió mal. Inténtalo de nuevo.',

      'language_dialog_title': 'Elegir idioma',
      'language_dialog_message':
          'Selecciona tu idioma preferido para la aplicación.',
      'language_updated_title': 'Idioma actualizado',
      'language_updated_message': 'Se ha cambiado el idioma de la aplicación.',
      'title_profile': 'Perfil',
      'edit_profile_title': 'Editar perfil',
      'edit_profile_button': 'Actualizar perfil',
      'edit_profile_button_updating': 'Actualizando perfil...',
      'service_selection_required': 'Seleccion requerida',
      'service_updated': 'Servicio actualizado',
      'service_selected': 'Servicios seleccionados',
      'edit_profile_update_success': '¡Perfil actualizado correctamente!',
      'edit_profile_picture_update_success':
          '¡Foto de perfil actualizada correctamente!',
      // Choose service screen
      'choose_service_title': 'Elige un servicio',
      'choose_service_choose_all': 'Elegir todo',
      'choose_service_saving': 'Guardando...',
      'choose_service_selecting': 'Seleccionando...',
      'choose_service_save': 'Guardar',
      'choose_service_continue': 'Continuar',
      'choose_service_card_pet_sitting_title': 'Cuidado de mascotas',
      'choose_service_card_house_sitting_title': 'Cuidado de la casa',
      'choose_service_card_day_care_title': 'Guardería diurna',
      'choose_service_card_dog_walking_title': 'Paseo de perros',
      'choose_service_card_subtitle_at_owners_home': 'En casa del dueño',
      'choose_service_card_subtitle_in_your_home': 'En tu hogar',
      'choose_service_card_subtitle_in_neighborhood': 'En tu barrio',
      'section_settings': 'Ajustes',
      'role_pet_owner': 'Dueño',
      'role_pet_sitter': 'Cuidador',
      'auth_role_pet_owner': 'Dueño',
      'auth_role_pet_sitter': 'Cuidador',
      'profile_add_tasks': 'Añadir tareas',
      'profile_view_tasks': 'Ver tareas',
      'profile_bookings_history': 'Historial de reservas',
      'profile_edit_profile': 'Editar perfil',
      'profile_edit_pets_profile': 'Editar perfil de mascotas',
      'profile_choose_service': 'Elegir servicio',
      'profile_change_password': 'Cambiar contraseña',
      'profile_change_language': 'Cambiar idioma',
      'profile_blocked_users': 'Usuarios bloqueados',
      'profile_delete_account': 'Eliminar cuenta',
      'profile_donate_us': 'Haz una donación',
      'blocked_users_title': 'Usuarios bloqueados',
      'blocked_users_empty_title': 'No hay usuarios bloqueados',
      'blocked_users_empty_message':
          'Los usuarios que bloquees aparecerán aquí',
      'blocked_users_unblock_button': 'Desbloquear',
      'blocked_users_unblock_dialog_message':
          '¿Seguro que quieres desbloquear a @name?',
      'delete_account_dialog_message':
          '¿Seguro que quieres eliminar tu cuenta? Esta acción no se puede deshacer.',
      'delete_account_success_title': 'Cuenta eliminada',
      'delete_account_success_message':
          'Tu cuenta se ha eliminado correctamente',
      'delete_account_failed_title': 'Error al eliminar',
      'delete_account_failed_generic': 'Algo salió mal. Inténtalo de nuevo.',
      'logout_dialog_message': '¿Seguro que quieres cerrar sesión?',
      'profile_switch_role_card_title': 'Cambiar a @role',
      'profile_switch_role_card_description':
          'Cambia tu cuenta a @role para empezar a recibir solicitudes.',
      'dialog_switch_role_title': 'Cambiar rol',
      'dialog_switch_role_switching':
          'Cambiando a @role...\n\nPor favor espera.',
      'dialog_switch_role_confirm':
          '¿Seguro que quieres cambiar a @role?\n\nPodrás volver atrás en cualquier momento.',
      'dialog_switch_role_button': 'Cambiar a @role',
      'profile_switch_to_sitter': 'Cambiar a Pet Sitter',
      'profile_switch_to_owner': 'Cambiar a Dueño de Mascota',
      'profile_switch_to_sitter_description':
          'Cambia tu cuenta a Pet Sitter para empezar a recibir solicitudes.',
      'profile_switch_to_owner_description':
          'Cambia tu cuenta a Dueño de Mascota para empezar a recibir solicitudes.',
      'profile_switch_role_dialog_title': 'Cambiar rol',
      'profile_switch_to_sitter_loading':
          'Cambiando a Pet Sitter...\n\nPor favor espera.',
      'profile_switch_to_owner_loading':
          'Cambiando a Dueño de Mascota...\n\nPor favor espera.',
      'profile_switch_to_sitter_confirm':
          '¿Seguro que quieres cambiar a Pet Sitter?\n\nPodrás volver atrás en cualquier momento.',
      'profile_switch_to_owner_confirm':
          '¿Seguro que quieres cambiar a Dueño de Mascota?\n\nPodrás volver atrás en cualquier momento.',
      'common_continue': 'Continuar',
      'common_cancelled': 'Cancelado',
      'common_coming_soon': 'Próximamente',
      'common_go_to_home': 'Ir al inicio',
      'common_back_to_home': 'Volver al inicio',
      'error_login_required': 'Por favor, inicia sesión nuevamente',
      'error_email_not_found':
          'Correo electrónico del usuario no encontrado. Por favor, inicia sesión nuevamente.',
      'profile_load_error': 'Error al cargar el perfil',
      'blocked_users_unblock_success': 'Usuario desbloqueado exitosamente',
      'blocked_users_save_success':
          'Usuarios bloqueados guardados exitosamente',
      'donate_coming_soon': 'La función de donación estará disponible pronto',
      'stripe_connect_title': 'Conectar cuenta de Stripe',
      'payout_status_screen_title': 'Estado de pagos',
      'payout_connect_stripe_account': 'Conectar cuenta de Stripe',
      'payout_paypal_email_title': 'Correo de pago PayPal',
      'payout_add_paypal_email_title': 'Agregar correo de pagos de PayPal',
      'payout_add_paypal_email_subtitle':
          'Define el correo donde quieres recibir pagos. Podras actualizarlo mas tarde desde el estado de pagos.',
      'payout_status_saved': 'Guardado',
      'payout_status_not_set': 'Sin configurar',
      'payout_paypal_email_hint':
          'Agrega un correo para recibir pagos a traves de PayPal.',
      'payout_update_paypal_email': 'Actualizar correo PayPal',
      'payout_paypal_dialog_subtitle':
          'Este correo se usara para pagos de PayPal. Asegurate de que coincida con tu cuenta de PayPal.',
      'payout_stripe_connect_title': 'Stripe Connect',
      'payout_status_connected': 'Conectado',
      'payout_status_not_connected': 'No conectado',
      'payout_stripe_connected_message':
          'Tu cuenta de Stripe esta conectada y lista para recibir pagos.',
      'payout_stripe_not_connected_message':
          'Conecta tu cuenta de Stripe para comenzar a recibir pagos.',
      'payout_account_id_label': 'ID de cuenta',
      'payout_verification_title': 'Estado de verificacion',
      'payout_status_title': 'Estado de pagos',
      'payout_verification_step_identity': 'Verificacion de identidad',
      'payout_verification_step_bank': 'Verificacion de cuenta bancaria',
      'payout_verification_step_business': 'Informacion del negocio',
      'payout_next_payout_label': 'Proximo pago',
      'payout_schedule_label': 'Frecuencia de pago',
      'payout_schedule_daily': 'Diario',
      'payout_minimum_amount_label': 'Monto minimo',
      'payout_status_verified': 'Verificado',
      'payout_status_pending': 'Pendiente',
      'payout_status_rejected': 'Rechazado',
      'payout_status_not_started': 'No iniciado',
      'payout_status_active': 'Activo',
      'payout_status_restricted': 'Restringido',
      'payout_verification_message_verified':
          'Tu cuenta ha sido verificada. Ahora puedes recibir pagos.',
      'payout_verification_message_pending':
          'Tu verificacion esta siendo revisada. Esto suele tardar 1-2 dias habiles.',
      'payout_verification_message_rejected':
          'Tu verificacion fue rechazada. Actualiza tu informacion e intentalo de nuevo.',
      'payout_verification_message_not_started':
          'Completa la verificacion para comenzar a recibir pagos.',
      'payout_message_active':
          'Tus pagos estan activos. Las ganancias se transferiran diariamente a tu cuenta bancaria.',
      'payout_message_pending':
          'Tu cuenta de pagos se esta configurando. Esto puede tardar algunos dias habiles.',
      'payout_message_restricted':
          'Tus pagos estan restringidos actualmente. Contacta con soporte.',
      'payout_message_not_connected':
          'Conecta tu cuenta de Stripe para comenzar a recibir pagos.',
      'stripe_get_paid_title': 'Recibe pagos con Stripe',
      'stripe_connect_description':
          'Conecta tu cuenta de Stripe para recibir pagos directamente de los dueños de mascotas. Tus ganancias se transferirán a tu cuenta bancaria.',
      'stripe_account_status_title': 'Estado de la cuenta',
      'stripe_continue_onboarding': 'Continuar integración',
      'stripe_connect_account_button': 'Conectar cuenta de Stripe',
      'stripe_benefit_secure': 'Procesamiento seguro de pagos',
      'stripe_benefit_fast_payouts': 'Pagos rápidos a tu cuenta bancaria',
      'stripe_benefit_no_fees': 'Sin tarifas de configuración',
      'stripe_benefit_support': 'Soporte al cliente 24/7',
      'stripe_benefit_required':
          'Requerido para recibir pagos de dueños de mascotas',
      'stripe_account_connected': 'Cuenta conectada',
      'stripe_account_created_pending': 'Cuenta creada - Integración pendiente',
      'stripe_account_created': 'Cuenta creada',
      'stripe_account_connected_message':
          'Tu cuenta de Stripe está completamente configurada y lista para recibir pagos.',
      'stripe_account_created_message':
          'Tu cuenta de Stripe ha sido creada. Por favor completa el proceso de integración para comenzar a recibir pagos.',
      'stripe_account_created_partial_message':
          'Tu cuenta de pago ha sido creada. Algunos pasos de verificación están pendientes. Puedes completarlos en la configuración de tu cuenta.',
      'stripe_account_id_label': 'ID de cuenta',
      'stripe_loading_onboarding': 'Cargando integración de Stripe...',
      'stripe_account_connected_success':
          '¡Cuenta de Stripe conectada exitosamente!',
      'stripe_onboarding_completed': '¡Integración de Stripe completada!',
      'stripe_onboarding_cancelled': 'La integración de Stripe fue cancelada.',
      'stripe_onboarding_load_error':
          'Error al cargar la página de integración de Stripe: @error',
      'stripe_cancel_onboarding_title': '¿Cancelar integración?',
      'stripe_cancel_onboarding_message':
          '¿Seguro que quieres cancelar la integración de Stripe? Puedes completarla más tarde desde la configuración.',
      'stripe_connect_payment_title': 'Conecta tu cuenta de pago',
      'stripe_connect_payment_description':
          'Para comenzar a recibir pagos como Pet Sitter, necesitas conectar tu cuenta de pago. Este es un paso requerido para completar la configuración de tu perfil.',
      'stripe_connect_payment_partial_description':
          'Tu cuenta de pago ha sido creada. Algunos pasos de verificación están pendientes. Puedes completarlos más tarde en la configuración de tu cuenta.',
      'stripe_connect_payment_partial_info':
          'Tu cuenta está conectada, pero algunos pasos de verificación están pendientes. Puedes completarlos en la configuración de tu cuenta.',
      'stripe_payment_connected_success': '¡Pago conectado exitosamente!',
      'stripe_connect_now': 'Conectar ahora',
      'stripe_already_connected': 'Ya conectado',
      'stripe_already_connected_message':
          'Tu cuenta de Stripe ya está conectada y activa.',
      'stripe_connect_error':
          'Error al conectar la cuenta de Stripe. Por favor intenta de nuevo.',
      'stripe_no_onboarding_url':
          'No hay URL de integración disponible. Por favor crea una cuenta de Stripe primero.',
      'stripe_onboarding_expired_title': 'Expirado',
      'stripe_onboarding_expired_message':
          'El enlace de integración ha expirado. Por favor crea uno nuevo.',
      'stripe_disconnect_success':
          '¡Cuenta de Stripe desconectada exitosamente!',
      'stripe_disconnect_error':
          'Error al desconectar la cuenta de Stripe. Por favor intenta de nuevo.',
      'payment_title': 'Pago',
      'payment_info_message':
          'Haz clic en "Pagar" a continuación para ingresar de forma segura tus datos de pago usando el formulario de pago seguro de Stripe.',
      'payment_paypal_info':
          'Serás redirigido a PayPal para aprobar el pago y luego lo confirmaremos aquí.',
      'payment_pay_with_stripe': 'Pagar con Stripe @amount',
      'payment_pay_with_paypal': 'Pagar con PayPal @amount',
      'booking_agreement_title': 'Acuerdo de reserva',
      'booking_agreement_payment_completed': 'Pago completado',
      'booking_agreement_booking_cancelled': 'Reserva cancelada',
      'booking_agreement_status_label': 'Estado: @status',
      'booking_agreement_start_date_label': 'Fecha de inicio',
      'booking_agreement_end_date_label': 'Fecha de fin',
      'booking_agreement_time_slot_label': 'Franja horaria',
      'booking_agreement_service_provider_label': 'Proveedor de servicio',
      'booking_agreement_service_type_label': 'Tipo de servicio',
      'booking_agreement_special_instructions_label':
          'Instrucciones especiales',
      'booking_agreement_cancelled_at_label': 'Cancelado el',
      'booking_agreement_cancellation_reason_label': 'Motivo de cancelación',
      'booking_agreement_price_breakdown_title': 'Desglose de precios',
      'booking_agreement_pricing_tier_label': 'Nivel de precio',
      'booking_agreement_total_hours_label': 'Horas totales',
      'booking_agreement_total_days_label': 'Días totales',
      'booking_agreement_base_price_label': 'Precio base',
      'booking_agreement_platform_fee_label': 'Tarifa de plataforma',
      'booking_agreement_net_amount_label': 'Importe neto (al cuidador)',
      'booking_agreement_today_at': 'Hoy a las @time',
      'booking_agreement_yesterday_at': 'Ayer a las @time',
      'booking_agreement_at': 'a las',
      'payment_method_paypal': 'PayPal',
      'payment_pay_button': 'Pagar @amount',
      'payment_amount_label': 'Monto a pagar',
      'payment_loading_page': 'Cargando página de pago...',
      'payment_cancel_title': '¿Cancelar pago?',
      'payment_cancel_message': '¿Seguro que quieres cancelar este pago?',
      'payment_continue': 'Continuar pago',
      'payment_load_error': 'Error al cargar la página de pago: @error',
      'payment_success_title': '¡Pago exitoso!',
      'payment_failed_title': 'Pago fallido',
      'payment_success_message': 'Tu pago ha sido procesado exitosamente.',
      'payment_rate_sitter': 'Calificar al pet sitter',
      'payment_try_again': 'Intentar de nuevo',
      'payment_transaction_details': 'Detalles de la transacción',
      'payment_transaction_id_label': 'ID de transacción',
      'payment_date_label': 'Fecha',
      'payment_error_client_secret_missing':
          'Error al crear la intención de pago. Falta el secreto del cliente.',
      'payment_error_publishable_key_missing':
          'Falta la clave pública de Stripe.',
      'payment_error_invalid_publishable_key':
          'Clave pública de Stripe inválida.',
      'payment_processing_failed':
          'Error al procesar el pago. Por favor intenta de nuevo.',
      'payment_error_title': 'Error de pago',
      'payment_unavailable_title': 'Pago no disponible',
      'payment_unavailable_message':
          'La cuenta de Stripe del pet sitter aún no está completamente verificada. Necesita completar la verificación de su cuenta (incluyendo identidad, cuenta bancaria y detalles del negocio) antes de poder recibir pagos. Por favor contacta al pet sitter para completar la configuración de su cuenta de Stripe.',
      'payment_invalid_amount_title': 'Monto inválido',
      'payment_invalid_amount_message':
          'El monto del pago es inválido. Por favor contacta al soporte.',
      'payment_initiate_error':
          'Error al iniciar el pago. Por favor intenta de nuevo.',
      'payment_confirmation_failed':
          'Error al confirmar el pago. Por favor contacta al soporte.',
      'review_already_reviewed_title': 'Ya calificado',
      'review_already_reviewed_message':
          'Ya has calificado a este pet sitter. Solo puedes enviar una calificación por pet sitter.',
      'sitter_applications_tab': 'Aplicaciones',
      'sitter_no_bookings_found': 'No se encontraron reservas',
      'sitter_application_accepted_success': 'Aplicación aceptada exitosamente',
      'sitter_application_accept_failed':
          'Error al aceptar la aplicación. Por favor intenta de nuevo.',
      'sitter_application_rejected_success':
          'Aplicación rechazada exitosamente',
      'sitter_application_reject_failed':
          'Error al rechazar la aplicación. Por favor intenta de nuevo.',
      'sitter_chat_start_failed':
          'Error al iniciar la conversación. Por favor intenta de nuevo.',
      'sitter_chat_with_owner': 'Chatear con el propietario',
      'sitter_pet_weight': 'Peso',
      'sitter_pet_height': 'Altura',
      'sitter_pet_color': 'Color',
      'sitter_not_yet_available': 'Aún no disponible',
      'sitter_detail_date': 'Fecha',
      'sitter_detail_time': 'Hora',
      'sitter_detail_phone': 'Teléfono',
      'sitter_detail_email': 'Correo electrónico',
      'sitter_detail_location': 'Ubicación',
      'sitter_not_available_yet': 'Aún no disponible',
      'sitter_reject': 'Rechazar',
      'sitter_accept': 'Aceptar',
      'sitter_status_label': 'Estado: @status',
      'sitter_payment_status_label': 'Pago: @status',
      'sitter_time_just_now': 'Ahora mismo',
      'sitter_time_mins_ago': 'Hace @minutes min',
      'sitter_time_hours_ago': 'Hace @hours h',
      'sitter_time_days_ago': 'Hace @days días',
      'sitter_weekday_mon': 'Lun',
      'sitter_weekday_tue': 'Mar',
      'sitter_weekday_wed': 'Mié',
      'sitter_weekday_thu': 'Jue',
      'sitter_weekday_fri': 'Vie',
      'sitter_weekday_sat': 'Sáb',
      'sitter_weekday_sun': 'Dom',
      'sitter_month_jan': 'Ene',
      'sitter_month_feb': 'Feb',
      'sitter_month_mar': 'Mar',
      'sitter_month_apr': 'Abr',
      'sitter_month_may': 'May',
      'sitter_month_jun': 'Jun',
      'sitter_month_jul': 'Jul',
      'sitter_month_aug': 'Ago',
      'sitter_month_sep': 'Sep',
      'sitter_month_oct': 'Oct',
      'sitter_month_nov': 'Nov',
      'sitter_month_dec': 'Dic',
      'sitter_service_long_term_care': 'Cuidado a largo plazo',
      'sitter_service_dog_walking': 'Paseo de perros',
      'sitter_service_overnight_stay': 'Estancia nocturna',
      'sitter_service_home_visit': 'Visita a domicilio',
      'sitter_request_details_title': 'Detalles de la solicitud',
      'sitter_requests_section': 'Solicitudes',
      'sitter_info_pets': 'Mascotas',
      'sitter_no_pets': 'Sin mascotas',
      'sitter_info_service': 'Servicio',
      'sitter_no_service_type': 'No hay tipo de servicio disponible',
      'sitter_info_date': 'Fecha',
      'sitter_no_date_available': 'No hay fecha disponible',
      'sitter_pets_section': 'Mascotas',
      'sitter_note_section': 'Nota',
      'sitter_no_note_provided': 'No se proporcionó ninguna nota.',
      'sitter_decline': 'Rechazar',
      'owner_booking_details_title': 'Detalles de la reserva',
      'owner_service_provider_section': 'Proveedor de servicios',
      'owner_info_pets': 'Mascotas',
      'owner_no_pets': 'Sin mascotas',
      'owner_info_service': 'Servicio',
      'owner_no_service_type': 'No hay tipo de servicio disponible',
      'owner_info_date': 'Fecha',
      'owner_no_date_available': 'No hay fecha disponible',
      'owner_info_total_amount': 'Monto total',
      'owner_pets_section': 'Mascotas',
      'owner_note_section': 'Nota',
      'owner_no_note_provided': 'No se proporcionó ninguna nota.',
      'owner_chat_with_sitter': 'Chatear con el pet sitter',
      'owner_pay_now': 'Pagar ahora',
      'owner_pay_with_amount': 'Pagar \$@amount',
      'owner_cancel_booking': 'Cancelar reserva',
      'owner_time_just_now': 'Ahora mismo',
      'owner_time_mins_ago': 'Hace @minutes min',
      'owner_time_hours_ago': 'Hace @hours h',
      'owner_time_days_ago': 'Hace @days días',
      'owner_weekday_mon': 'Lun',
      'owner_weekday_tue': 'Mar',
      'owner_weekday_wed': 'Mié',
      'owner_weekday_thu': 'Jue',
      'owner_weekday_fri': 'Vie',
      'owner_weekday_sat': 'Sáb',
      'owner_weekday_sun': 'Dom',
      'owner_month_jan': 'Ene',
      'owner_month_feb': 'Feb',
      'owner_month_mar': 'Mar',
      'owner_month_apr': 'Abr',
      'owner_month_may': 'May',
      'owner_month_jun': 'Jun',
      'owner_month_jul': 'Jul',
      'owner_month_aug': 'Ago',
      'owner_month_sep': 'Sep',
      'owner_month_oct': 'Oct',
      'owner_month_nov': 'Nov',
      'owner_month_dec': 'Dic',
      'owner_service_long_term_care': 'Cuidado a largo plazo',
      'owner_service_dog_walking': 'Paseo de perros',
      'owner_service_overnight_stay': 'Estancia nocturna',
      'owner_service_home_visit': 'Visita a domicilio',
      'owner_rating_with_reviews': '@rating (@count reseñas)',
      'owner_pet_needs_medication': 'Necesita medicación / @medication',
      // Home screen & applications
      'home_default_user_name': 'Usuario',
      'home_no_sitters_message':
          'No hay cuidadores disponibles en este momento.',
      'home_block_sitter_message':
          '¿Seguro que quieres bloquear a @name? No podrás ver su perfil ni enviarle solicitudes.',
      'home_block_sitter_yes': 'Cancelar',
      'home_block_sitter_no': 'Bloquear',
      'status_available': 'disponible',
      'applications_tab_title': 'Solicitudes',
      'bookings_tab_title': 'Reservas',
      'applications_empty_message': 'No se encontraron solicitudes',
      'bookings_empty_message': 'No se encontraron reservas',
      'booking_cancel_dialog_message':
          '¿Seguro que quieres cancelar esta reserva?',
      // Common UI
      'common_select': 'Seleccionar',
      'common_save': 'Guardar',
      'common_later': 'Mas tarde',
      'common_saving': 'Guardando...',
      // Expandable post input
      'post_input_label': 'Publicación',
      'post_input_hint': 'Escribe tu publicación aquí...',
      'post_button': 'Publicar',
      'post_button_posting': 'Publicando...',
      'my_posts_title': 'Mis publicaciones',
      'home_segment_sitters': 'Cuidadores de mascotas',
      'my_posts_no_posts': 'No se encontraron publicaciones',
      'my_posts_delete_title': 'Eliminar publicacion?',
      'my_posts_delete_message':
          'Estas seguro de que deseas eliminar esta publicacion? Esta accion no se puede deshacer.',
      'my_posts_delete_success': 'Publicacion eliminada correctamente.',
      'my_posts_delete_failed':
          'No se pudo eliminar la publicacion. Intentalo de nuevo.',
      'my_posts_sort_label': 'Ordenar',
      'my_posts_sort_newest': 'Mas recientes primero',
      'my_posts_sort_oldest': 'Mas antiguos primero',
      'notifications_title': 'Notificaciones',
      'notifications_empty_title': 'Sin notificaciones',
      'notifications_empty_subtitle': 'Cuando pase algo, lo veras aqui.',
      'notifications_mark_all_read': 'Marcar todo como leido',
      'notifications_load_failed': 'No se pudieron cargar las notificaciones.',
      'notifications_fallback_title': 'Notificacion',
      'notifications_post_view_title': 'Publicacion',
      'notifications_request_view_title': 'Solicitud del cuidador',
      'notifications_application_not_found':
          'Esta solicitud ya no esta disponible o no se pudo cargar.',
      'notifications_open_sitter_profile': 'Ver perfil del cuidador',
      'notifications_loading': 'Cargando notificaciones…',
      'notifications_loading_more': 'Cargando m\u00E1s...',
      'post_action_delete': 'Eliminar',
      'post_request_default': 'Buscando un cuidador de mascotas',
      // Tasks screens
      'view_task_title': 'Ver tareas',
      'view_task_empty': 'No se encontraron tareas',
      'view_task_date_not_available': 'Fecha no disponible',
      'add_task_title': 'Añadir tarea',
      'add_task_title_label': 'Título',
      'add_task_title_hint': 'Introduce un título',
      'add_task_description_label': 'Descripción',
      'add_task_description_hint': 'Texto...',
      'add_task_save_button': 'Guardar',
      'add_task_saving': 'Guardando...',
      // Change password
      'change_password_title': 'Cambiar contraseña',
      'change_password_new_label': 'Nueva contraseña',
      'change_password_confirm_label': 'Confirmar contraseña',
      'change_password_confirm_hint': 'Confirma la contraseña',
      // Add card
      'add_card_title': 'Añadir tarjeta',
      'add_card_holder_label': 'Nombre del titular',
      'add_card_holder_hint': 'Juan Pérez',
      'add_card_number_label': 'Número de tarjeta',
      'add_card_number_hint': '0987 0986 5543 0980',
      'add_card_exp_label': 'Fecha de caducidad',
      'add_card_exp_hint': '10/23',
      'add_card_cvc_label': 'CVC',
      'add_card_cvc_hint': '345',
      // My pets
      'my_pets_title': 'Mis mascotas',
      'my_pets_add_pet': 'Añadir mascota',
      'my_pets_error_loading': 'Error al cargar las mascotas',
      'my_pets_retry': 'Reintentar',
      'my_pets_empty': 'No se encontraron mascotas',
      'my_pets_color_label': 'Color',
      'my_pets_profile_label': 'Perfil',
      'my_pets_passport_label': 'Pasaporte',
      'my_pets_chip_label': 'Chip',
      'my_pets_allergies_label': 'Alergias',
      // Create pet profile
      'create_pet_appbar_title': 'Usuario',
      'create_pet_skip': 'Omitir',
      'create_pet_header': 'Crea un perfil para tu mascota',
      'create_pet_name_label': 'Nombre de la mascota',
      'create_pet_name_hint': 'Introduce el nombre de tu mascota',
      'create_pet_breed_label': 'Raza',
      'create_pet_breed_hint': 'Introduce la raza',
      'create_pet_dob_label': 'Fecha de nacimiento',
      'create_pet_dob_hint': 'Introduce la fecha de nacimiento de tu mascota',
      'create_pet_weight_label': 'Peso (KG)',
      'create_pet_weight_hint': 'ej. 12 kg',
      'create_pet_height_label': 'Altura (CM)',
      'create_pet_height_hint': 'ej. 50 cm',
      'create_pet_passport_label': 'Número de pasaporte',
      'create_pet_passport_hint': 'Introduce el número de pasaporte',
      'create_pet_chip_label': 'Número de chip',
      'create_pet_chip_hint': 'Introduce el número de chip',
      'create_pet_med_allergies_label': 'Alergias a medicamentos',
      'create_pet_med_allergies_hint': 'Introduce las alergias a medicamentos',
      'create_pet_category_label': 'Categoría',
      'create_pet_category_dog': 'Perro',
      'create_pet_category_cat': 'Gato',
      'create_pet_category_bird': 'Pájaro',
      'create_pet_category_rabbit': 'Conejo',
      'create_pet_category_other': 'Otro',
      'create_pet_vaccination_label': 'Vacunación',
      'create_pet_vaccination_up_to_date': 'Al día',
      'create_pet_vaccination_not_vaccinated': 'No vacunado',
      'create_pet_vaccination_partial': 'Parcialmente vacunado',
      'create_pet_profile_view_label': 'Visibilidad del perfil',
      'create_pet_profile_view_public': 'Público',
      'create_pet_profile_view_private': 'Privado',
      'create_pet_profile_view_friends': 'Solo amigos',
      'create_pet_upload_media_label': 'Sube fotos y vídeos de tu mascota',
      'create_pet_upload_media_upload': 'Subir',
      'create_pet_upload_media_change': 'Cambiar (@count)',
      'create_pet_upload_media_selected': '@count archivo(s) seleccionado(s)',
      'create_pet_upload_passport_label':
          'Sube la foto del pasaporte de tu mascota',
      'create_pet_upload_passport_change': 'Cambiar',
      'create_pet_upload_passport_upload': 'Subir',
      'create_pet_upload_passport_selected':
          'Imagen del pasaporte seleccionada',
      'create_pet_button_creating': 'Creando perfil...',
      'create_pet_button': 'Crear perfil de la mascota',
      // Send request screen
      'send_request_title': 'Enviar solicitud',
      'send_request_description_label': 'Descripción',
      'send_request_description_hint': 'Introduce detalles adicionales...',
      'label_pets': 'Mascotas',
      'send_request_no_pets_message':
          'No hay mascotas. Añade una mascota para continuar.',
      'send_request_pets_select_placeholder': 'Seleccionar',
      'send_request_dates_label': 'Fechas',
      'send_request_start_label': 'Inicio',
      'send_request_end_label': 'Fin',
      'send_request_select_date': 'Seleccionar fecha',
      'send_request_select_time': 'Seleccionar hora',
      'send_request_service_type_label': 'Tipo de servicio',
      'send_request_service_long_term_care': 'Cuidado a largo plazo',
      'send_request_service_dog_walking': 'Paseo de perros',
      'send_request_service_overnight_stay': 'Estancia nocturna',
      'send_request_service_home_visit': 'Visita a domicilio',
      'send_request_duration_label': 'Duración (minutos)',
      'send_request_duration_minutes_label': '@minutes min',
      'send_request_button': 'Enviar solicitud',
      'send_request_button_sending': 'Enviando...',
      'send_request_validation_error_title': 'Error de validación',
      'send_request_invalid_time_title': 'Hora no válida',
      'send_request_invalid_time_message':
          'La hora de finalización debe ser posterior a la hora de inicio.',
      // Publicar solicitud de reserva (dueño) - solo UI
      'publish_request_home_cta': 'Publicar solicitud de reserva',
      'publish_request_title': 'Publicar solicitud',
      'publish_request_select_pets': 'Seleccionar mascota(s)',
      'publish_request_selected_pets': '@count seleccionada(s)',
      'publish_request_select_pets_title': 'Seleccionar mascotas',
      'publish_request_notes_label': 'Notas adicionales',
      'publish_request_notes_hint':
          'Cualquier cosa que el cuidador deba saber...',
      'publish_request_address_label': 'Dirección (opcional)',
      'publish_request_address_hint': 'Calle, edificio, etc.',
      'publish_request_images_label': 'Imágenes',
      'publish_request_add_images': 'Agregar imágenes',
      'publish_request_add_more_images': 'Agregar más imágenes',
      'publish_request_publish_button': 'Publicar solicitud',
      'publish_request_fill_required':
          'Completa todos los campos obligatorios.',
      'publish_request_ui_only_success': 'UI creada (aún no publicada).',
      'publish_request_success': '¡Solicitud de reserva publicada con éxito!',
      'publish_request_service_walking': 'Paseo',
      'publish_request_service_boarding': 'Alojamiento',
      'publish_request_service_daycare': 'Guardería',
      'publish_request_service_pet_sitting': 'Cuidado de mascotas',
      'publish_request_service_house_sitting': 'Cuidado en casa',
      'house_sitting_venue_label': 'Lugar del house sitting',
      'house_sitting_venue_owners_home': 'En casa del dueño',
      'house_sitting_venue_sitters_home': 'En casa del cuidador',
      // Chat screens
      'chat_error_loading_conversations': 'Error al cargar las conversaciones',
      'chat_retry': 'Reintentar',
      'chat_no_conversations': 'No hay conversaciones todavía',
      'chat_error_loading_messages': 'Error al cargar los mensajes',
      'chat_no_messages': 'No hay mensajes aún. ¡Empieza la conversación!',
      'chat_input_hint': 'Escribe un mensaje...',
      'chat_locked_title': 'Chat bloqueado',
      'chat_locked_after_payment':
          'El chat solo está disponible después de completar el pago de la reserva.',
      // Pets map screen
      'map_search_hint': 'Buscar ciudad o zona',
      'map_search_empty': 'Introduce una ubicación.',
      'map_search_not_found': 'No se pudo encontrar la ubicación: @query',
      'map_search_failed': 'La búsqueda ha fallado. Inténtalo de nuevo.',
      'map_offers_near_me': 'Ofertas cerca de mí',
      'map_radius_label': 'Radio:',
      // IBAN Payout
      'payout_iban_title': 'Pago bancario (IBAN)',
      'payout_iban_info': 'Añade tu cuenta bancaria para recibir pagos directamente, como Vinted. Un administrador verificará tu IBAN antes del primer pago.',
      'payout_current_iban': 'Cuenta bancaria actual',
      'payout_method_label': 'Método de cobro',
      'payout_add_iban': 'Añadir / Actualizar IBAN',
      'payout_iban_holder': 'Titular de la cuenta',
      'payout_iban_holder_required': 'El nombre del titular es obligatorio',
      'payout_iban_required': 'El IBAN es obligatorio',
      'payout_iban_invalid': 'Formato IBAN inválido',
      'payout_save_iban': 'Guardar cuenta bancaria',
      'map_distance_filter_label': 'Distancia: @km km',
      'map_no_nearby_sitters': 'No hay cuidadores cercanos',
      'map_sitter_services_distance': '@services • @distance km',
      // Service provider detail screen
      'sitter_detail_loading_name': 'Cargando...',
      'sitter_detail_load_error':
          'No se pudieron cargar los datos del cuidador',
      'sitter_detail_no_rating': 'Aún sin valoraciones',
      'sitter_detail_about_title': 'Acerca de @name',
      'sitter_detail_no_bio': 'No hay biografía disponible.',
      'sitter_detail_booking_details_title': 'Detalles de la reserva',
      'sitter_detail_availability_pricing_title': 'Disponibilidad y precios',
      'sitter_detail_hourly_rate_label': 'Tarifa por hora',
      'sitter_detail_weekly_rate_label': 'Tarifa semanal',
      'sitter_detail_monthly_rate_label': 'Tarifa mensual',
      'sitter_detail_current_status_label': 'Estado actual',
      'sitter_detail_application_status_label': 'Estado de la solicitud',
      'sitter_detail_skills_title': 'Habilidades',
      'sitter_detail_no_skills': 'No hay habilidades indicadas.',
      'sitter_detail_reviews_title': 'Reseñas',
      'sitter_detail_no_reviews': 'Aún no hay reseñas.',
      'sitter_detail_anonymous_reviewer': 'Anónimo',
      'sitter_detail_starting_chat': 'Iniciando...',
      'sitter_detail_unlock_after_payment': 'Desbloquear después del pago',
      'sitter_detail_start_chat': 'Iniciar chat',
      'sitter_detail_start_chat_failed':
          'No se pudo iniciar la conversación. Inténtalo de nuevo.',
      'status_available_label': 'Disponible',
      'status_cancelled_label': 'Cancelada',
      'status_rejected_label': 'Rechazada',
      'status_pending_label': 'Pendiente',
      'status_agreed_label': 'Acordada',
      'status_paid_label': 'Pagada',
      'status_accepted_label': 'Aceptada',
      // Pet detail screen
      'pet_detail_loading': 'Cargando detalles de la mascota...',
      'pet_detail_about': 'Acerca de @name',
      'pet_detail_weight': 'Peso',
      'pet_detail_height': 'Altura',
      'pet_detail_color': 'Color',
      'pet_detail_passport_number': 'Número de pasaporte',
      'pet_detail_chip_number': 'Número de chip',
      'pet_detail_medication_allergies': 'Medicamentos/Alergias',
      'pet_detail_date_of_birth': 'Fecha de nacimiento',
      'pet_detail_category': 'Categoría',
      'pet_detail_vaccinations': 'Vacunaciones de @name',
      'pet_detail_gallery': 'Galería de @name',
      'pet_detail_no_photos': 'No hay fotos disponibles',
      'pet_detail_owner_information': 'Información del propietario',
      'pet_detail_owner_name': 'Nombre',
      'pet_detail_owner_created_at': 'Creado en',
      'pet_detail_owner_updated_at': 'Actualizado en',
      'pet_detail_no_description': 'No hay descripción disponible',
      'pet_detail_gender_unknown': 'Desconocido',
      'pet_detail_breed_unknown': 'Desconocido',
      'pet_detail_no_vaccinations': 'No hay vacunaciones listadas',
      'pet_detail_load_error':
          'Error al cargar los detalles de la mascota. Por favor, inténtalo de nuevo.',
      // Sitter bookings screen
      'sitter_bookings_title': 'Mis reservas',
      'sitter_bookings_empty_all': 'No se encontraron reservas',
      'sitter_bookings_empty_filtered': 'No se encontraron reservas @status',
      'sitter_bookings_pet_label': 'Mascota',
      'sitter_bookings_date_label': 'Fecha',
      'sitter_bookings_time_label': 'Hora',
      'sitter_bookings_rate_label': 'Tarifa',
      'sitter_bookings_description_label': 'Descripción',
      'sitter_bookings_cancel_button': 'Cancelar reserva',
      'sitter_bookings_cancel_dialog_message':
          '¿Estás seguro de que quieres cancelar esta reserva?',
      'sitter_bookings_cancel_dialog_yes': 'Sí, cancelar',
      'sitter_bookings_cancel_success':
          '¡Solicitud de cancelación enviada con éxito!',
      'sitter_bookings_cancel_error':
          'Error al solicitar la cancelación. Por favor, inténtalo de nuevo.',
      // Owner bookings controller
      'bookings_cancel_success': '¡Reserva cancelada con éxito!',
      'bookings_cancel_error':
          'Error al cancelar la reserva. Por favor, inténtalo de nuevo.',
      'bookings_cancel_request_success':
          '¡Solicitud de cancelación enviada con éxito!',
      'bookings_cancel_request_error':
          'Error al solicitar la cancelación. Por favor, inténtalo de nuevo.',
      'request_cancel_button': 'Cancelar solicitud',
      'request_cancel_button_cancelling': 'Cancelando...',
      'request_cancel_success': '¡Solicitud cancelada con éxito!',
      'request_cancel_error':
          'Error al cancelar la solicitud. Por favor, inténtalo de nuevo.',
      'bookings_payment_status_error':
          'Error al obtener el estado del pago. Por favor, inténtalo de nuevo.',
      // Service provider card
      'service_card_no_phone': 'No hay teléfono disponible',
      'service_card_no_location': 'No hay ubicación disponible',
      'service_card_block': 'Bloquear',
      'service_card_per_hour_label': 'Por hora @price',
      'service_card_send_request': 'Enviar solicitud',
      'sitter_post_pet_details': 'Detalles de la mascota',
      'service_card_accept': 'Aceptar',
      'service_card_reject': 'Rechazar',
      'service_card_cancel': 'Cancelar',
      'service_card_pay_with_amount': 'Pagar @amount',
      'service_card_pay_now': 'Pagar ahora',
      'service_card_chat': 'Chat',
      // Sitter bottom sheet
      'sitter_view_profile': 'Ver perfil',
      'sitter_rating_with_count': '@rating (@count reseñas)',
      // Bookings history
      'bookings_history_title': 'Historial de reservas',
      'status_all_label': 'Todas',
      'status_failed_label': 'Fallida',
      'status_refunded_label': 'Reembolsada',
      'status_payment_pending_label': 'Pago pendiente',
      'status_payment_failed_label': 'Pago fallido',
      'bookings_history_empty_all': 'No se encontraron reservas',
      'bookings_history_empty_filtered': 'No se encontraron reservas @status',
      'bookings_detail_pet_label': 'Mascota',
      'bookings_detail_date_label': 'Fecha',
      'bookings_detail_time_label': 'Hora',
      'bookings_detail_total_amount_label': 'Importe total',
      'bookings_detail_phone_label': 'Teléfono',
      'bookings_detail_location_label': 'Ubicación',
      'bookings_detail_rating_label': 'Valoración',
      'bookings_detail_description_label': 'Descripción',
      'bookings_action_view_details': 'Ver detalles',
      'Email Not Verified': 'Email Not Verified',
      'Image Error': 'Image Error',
      'Invalid Hourly Rate': 'Invalid Hourly Rate',
      'Location Found': 'Location Found',
      'Location Not Found': 'Location Not Found',
      'Required': 'Required',
      'Role Switched': 'Role Switched',
      'Selection Failed': 'Selection Failed',
      'Selection Required': 'Selection Required',
      'Service Updated': 'Service Updated',
      'Services Selected': 'Services Selected',
      'Success': 'Success',
      'Switch Role Failed': 'Switch Role Failed',
      'Verification Code Sent': 'Verification Code Sent',
      'auth_apple_signin_failed': 'Error de inicio de sesión con Apple',
      'auth_apple_signin_failed_generic':
          'Algo salió mal. Por favor, inténtalo de nuevo.',
      'auth_apple_signin_success': 'Inicio de sesión con Apple exitoso',
      'auth_google_signin_choose_services': 'Selecciona tus servicios',
      'auth_google_signin_failed':
          'El inicio de sesión con Google falló. Inténtalo de nuevo.',
      'auth_google_signin_firebase_token_failed':
          'No se pudo obtener el token de Firebase ID.',
      'auth_google_signin_success': 'Inicio de sesión con Google exitoso',
      'auth_google_signin_title': 'Inicio de sesión con Google',
      'auth_google_signin_token_missing': 'Falta el token de Google ID.',
      'auth_google_signin_web_required':
          'Esta plataforma requiere inicio de sesión web.',
      'auth_role_switch_failed':
          'No se pudo cambiar el rol. Inténtalo de nuevo.',
      'auth_role_switched': 'Rol cambiado',
      'auth_role_switched_message': 'Se cambió correctamente a @role',
      'auth_welcome_back': '¡Bienvenido de nuevo!',
      'change_password_failed': 'Failed to change password. Please try again.',
      'change_password_fields_required': 'Please fill in all fields correctly.',
      'change_password_new_required': 'Please enter a new password.',
      'change_password_success': 'Password changed successfully!',
      'change_password_validation_error': 'Validation Error',
      'email_verification_code_required':
          'Please enter the complete verification code',
      'email_verification_success': 'Email verified successfully!',
      'map_load_error': 'Failed to load map data. Please try again.',
      'my_pets_load_error': 'Failed to load pets. Please try again.',
      'pet_create_validation_error': 'Validation Error',
      'pet_update_failed': 'Update Failed',
      'pet_validation_error': 'Validation Error',
      'profile_blocked_users_load_error': 'Failed to load blocked users',
      'profile_edit_coming_soon':
          'Edit profile functionality will be available soon',
      'profile_image_pick_failed': 'Failed to pick image. Please try again.',
      'profile_invalid_file_type': 'Invalid File Type',
      'profile_invalid_file_type_message':
          'Please select a JPEG, PNG, or WebP image.',
      'profile_picture_update_success':
          'Foto de perfil actualizada correctamente',
      'profile_unblock_failed': 'Unblock Failed',
      'profile_unblock_failed_generic':
          'Something went wrong. Please try again.',
      'profile_unblock_success': 'User unblocked successfully',
      'profile_upload_failed': 'Upload Failed',
      'profile_upload_failed_generic':
          'Something went wrong. Please try again.',
      'profile_user_not_found': 'User not found',
      'request_duration_required':
          'Please select a duration for dog walking service.',
      'request_pet_required': 'Please select at least one pet.',
      'request_send_failed':
          'No se pudo enviar la solicitud. Inténtalo de nuevo.',
      'request_send_success': '¡Solicitud enviada con éxito!',
      'request_sitter_pricing_error':
          'Primero configura tu tarifa por hora en el perfil.',
      'request_validation_error': 'Validation Error',
      'review_submit_failed': 'Failed to submit review. Please try again.',
      'share_failed': 'Failed to share. Please try again.',
      'snackbar_choose_service_controller_001':
          'Please select valid services for your account type.',
      'snackbar_choose_service_controller_002':
          'Your services have been updated successfully!',
      'snackbar_choose_service_controller_003':
          'Your services have been selected successfully!',
      'snackbar_choose_service_controller_004':
          'Failed to update services. Please try again.',
      'snackbar_choose_service_controller_005':
          'Please select at least one service to continue.',
      'snackbar_choose_service_controller_006':
          'Please select a valid service to continue.',
      'snackbar_choose_service_controller_007':
          'Please select at least one service.',
      'snackbar_sitter_paypal_payout_controller_001':
          'Se requiere el correo de pagos de PayPal.',
      'snackbar_sitter_paypal_payout_controller_002':
          'Correo de pagos de PayPal actualizado correctamente!',
      'snackbar_sitter_paypal_payout_controller_003':
          'No se pudo actualizar el correo de pagos de PayPal. Intentalo de nuevo.',
      'task_add_failed': 'Failed to add task. Please try again.',
      'task_add_success': 'Task added successfully!',
      'task_fetch_failed': 'Failed to fetch tasks.',
      'task_fields_required': 'Please fill in at least one field.',

      'snackbar_text_application_accepted_successfully':
          'Solicitud aceptada exitosamente',
      'snackbar_text_application_rejected_successfully':
          'Solicitud rechazada exitosamente',
      'snackbar_text_blocked_users_saved_successfully':
          'Los usuarios bloqueados se guardaron correctamente',
      'snackbar_text_card_saved_successfully':
          '¡Tarjeta guardada exitosamente!',
      'snackbar_text_could_not_detect_your_location_please_enable_location_servic':
          'No se pudo detectar tu ubicación. ',
      'snackbar_text_could_not_load_nearby_sitters_please_try_again':
          'No se pudieron cargar los asistentes cercanos. ',
      'snackbar_text_email_not_verified': 'Correo electrónico no verificado',
      'snackbar_text_failed_to_complete_profile_please_try_again':
          'No se pudo completar el perfil. ',
      'snackbar_text_failed_to_load_booking_details_using_default_pricing':
          'No se pudieron cargar los detalles de la reserva. ',
      'snackbar_text_failed_to_load_pet_data_please_try_again':
          'No se pudieron cargar los datos de la mascota. ',
      'snackbar_text_failed_to_load_sitter_details_please_try_again':
          'No se pudieron cargar los detalles de la niñera. ',
      'snackbar_text_failed_to_pick_passport_image_please_try_again':
          'No se pudo elegir la imagen del pasaporte. ',
      'snackbar_text_failed_to_pick_pet_pictures_or_videos_please_try_again':
          'No se pudieron seleccionar fotos o videos de mascotas. ',
      'snackbar_text_failed_to_pick_pet_profile_image_please_try_again':
          'No se pudo elegir la imagen de perfil de la mascota. ',
      'snackbar_text_failed_to_save_card_please_try_again':
          'No se pudo guardar la tarjeta. ',
      'snackbar_text_failed_to_start_conversation_please_try_again':
          'No se pudo iniciar la conversación. ',
      'snackbar_text_failed_to_switch_role_please_try_again':
          'No se pudo cambiar de rol. ',
      'snackbar_text_height_is_required': 'Se requiere altura.',
      'snackbar_text_height_must_be_greater_than_0':
          'La altura debe ser mayor que 0.',
      'snackbar_text_hourly_rate_must_be_greater_than_0':
          'La tarifa por hora debe ser mayor que 0.',
      'snackbar_text_weekly_rate_must_be_greater_than_0':
          'La tarifa semanal debe ser mayor que 0.',
      'snackbar_text_monthly_rate_must_be_greater_than_0':
          'La tarifa mensual debe ser mayor que 0.',
      'snackbar_text_invalid_url': 'URL no válida',
      'snackbar_text_unknown_error': 'Error desconocido',
      'snackbar_text_image_error': 'Error de imagen',
      'snackbar_text_image_uploaded_successfully':
          '¡Imagen cargada exitosamente!',
      'snackbar_text_invalid_hourly_rate': 'Tarifa por hora no válida',
      'snackbar_text_location_not_found': 'Ubicación no encontrada',
      'snackbar_text_passwords_do_not_match': 'Las contraseñas no coinciden',
      'snackbar_text_pet_profile_created_but_media_upload_failed_you_can_add_medi':
          'Se creó el perfil de mascota pero falló la carga de medios. ',
      'snackbar_text_pet_profile_created_successfully':
          '¡Perfil de mascota creado exitosamente!',
      'snackbar_text_pet_profile_updated_successfully':
          '¡Perfil de mascota actualizado exitosamente!',
      'snackbar_text_please_accept_the_terms_and_conditions':
          'Por favor acepte los Términos y Condiciones',
      'snackbar_text_please_enter_your_paypal_email':
          'Por favor ingrese su correo electrónico de PayPal.',
      'snackbar_text_please_fill_in_all_required_fields':
          'Por favor complete todos los campos requeridos',
      'snackbar_text_please_try_logging_in_again':
          'Por favor intenta iniciar sesión nuevamente',
      'snackbar_text_profile_completed_successfully':
          '¡Perfil completado exitosamente!',
      'snackbar_text_profile_updated_but_image_upload_failed_please_try_again':
          'Perfil actualizado pero falla la carga de la imagen. ',
      'snackbar_text_required': 'Requerido',
      'snackbar_text_review_submitted_successfully':
          '¡Revisión enviada exitosamente!',
      'snackbar_text_role_switched': 'Rol cambiado',
      'snackbar_text_selected_image_file_is_not_accessible_please_try_again':
          'No se puede acceder al archivo de imagen seleccionado. ',
      'snackbar_text_selection_failed': 'Selección fallida',
      'snackbar_text_sitter_blocked_successfully':
          '¡La niñera se bloqueó con éxito!',
      'snackbar_text_something_went_wrong_please_try_logging_in_again':
          'Algo salió mal. ',
      'snackbar_text_success': 'Éxito',
      'snackbar_text_successfully_switched_to_userrole_value':
          'Se cambió de rol con éxito.',
      'snackbar_text_switch_role_failed': 'Error al cambiar de rol',
      'snackbar_text_unknown_user_role_please_try_again':
          'Rol de usuario desconocido. ',
      'snackbar_text_verification_code_has_been_resent_to_your_email':
          'El código de verificación ha sido reenviado a su correo electrónico',
      'snackbar_text_verification_code_resent':
          'Código de verificación reenviado',
      'snackbar_text_verification_code_sent': 'Código de verificación enviado',
      'snackbar_text_welcome_back': '¡Bienvenido de nuevo!',
      'snackbar_text_you_have_already_reviewed_this_sitter_you_can_only_submit_on':
          'Ya has reseñado a esta niñera. ',
    'post_more_options': 'Mas opciones',
    'post_action_block_user': 'Bloquear usuario',
    'post_action_report': 'Reportar publicacion',
    'block_user_title': 'Bloquear usuario',
    'block_user_action': 'Bloquear',
    'block_user_confirm_message': 'Estas seguro de bloquear a este usuario? Ya no veras su contenido.',
    'block_user_success': 'Usuario bloqueado con exito.',
    'block_user_failed': 'No se pudo bloquear. Intentalo de nuevo.',
    'report_post_received': 'Reporte recibido. Gracias.',
    'pet_photo_delete_title': 'Eliminar foto',
    'pet_photo_delete_confirm': 'Seguro que quieres eliminar esta foto?',
    'pet_photo_deleted': 'Foto eliminada con exito.',
    'pet_photo_delete_failed': 'No se pudo eliminar. Intentalo de nuevo.',
    'new_publication_button': 'Nueva publicacion',
    },
    'de_DE': <String, String>{
      'common_yes': 'Ja',
      'common_no': 'Nein',
      'common_cancel': 'Abbrechen',
      'common_error': 'Fehler',
      'common_success': 'Erfolg',
      'common_select_value': 'Wert auswählen',
      'label_not_available': 'k. A.',
      'common_user': 'Benutzer',
      'common_refresh': 'Aktualisieren',
      'common_search': 'Suchen',

      'Application accepted successfully': 'Application accepted successfully',
      'Application rejected successfully': 'Application rejected successfully',
      'Blocked users saved successfully': 'Blocked users saved successfully',
      'Card saved successfully!': 'Card saved successfully!',
      'Could not detect your location. Please enable location services.':
          'Could not detect your location. Please enable location services.',
      'Could not load nearby sitters. Please try again.':
          'Could not load nearby sitters. Please try again.',
      'Email verified successfully!': 'Email verified successfully!',
      'Failed to add task. Please try again.':
          'Failed to add task. Please try again.',
      'Failed to change password. Please try again.':
          'Failed to change password. Please try again.',
      'Failed to complete profile. Please try again.':
          'Failed to complete profile. Please try again.',
      'Failed to fetch tasks.': 'Failed to fetch tasks.',
      'Failed to get your location. Please try again.':
          'Failed to get your location. Please try again.',
      'Failed to load booking details. Using default pricing.':
          'Failed to load booking details. Using default pricing.',
      'Failed to load pet data. Please try again.':
          'Failed to load pet data. Please try again.',
      'Failed to load pets. Please try again.':
          'Failed to load pets. Please try again.',
      'Failed to load profile data. Please try again.':
          'Failed to load profile data. Please try again.',
      'Failed to load sitter details. Please try again.':
          'Failed to load sitter details. Please try again.',
      'Failed to pick image. Please try again.':
          'Failed to pick image. Please try again.',
      'Failed to pick passport image. Please try again.':
          'Failed to pick passport image. Please try again.',
      'Failed to pick pet pictures or videos. Please try again.':
          'Failed to pick pet pictures or videos. Please try again.',
      'Failed to pick pet profile image. Please try again.':
          'Failed to pick pet profile image. Please try again.',
      'Failed to save card. Please try again.':
          'Failed to save card. Please try again.',
      'Failed to start conversation. Please try again.':
          'Failed to start conversation. Please try again.',
      'Failed to submit review. Please try again.':
          'Failed to submit review. Please try again.',
      'Failed to switch role. Please try again.':
          'Failed to switch role. Please try again.',
      'Height is required.': 'Height is required.',
      'Height must be greater than 0.': 'Height must be greater than 0.',
      'Hourly rate must be greater than 0.':
          'Hourly rate must be greater than 0.',
      'Image uploaded successfully!': 'Image uploaded successfully!',
      'Password changed successfully!': 'Password changed successfully!',
      'Passwords do not match': 'Passwords do not match',
      'Pet profile created but media upload failed. You can add media later.':
          'Pet profile created but media upload failed. You can add media later.',
      'Pet profile created successfully!': 'Pet profile created successfully!',
      'Pet profile updated successfully!': 'Pet profile updated successfully!',
      'Please accept the Terms and Conditions':
          'Please accept the Terms and Conditions',
      'Please agree to the Terms and Conditions':
          'Please agree to the Terms and Conditions',
      'Please enter a new password.': 'Please enter a new password.',
      'Please enter the complete verification code':
          'Please enter the complete verification code',
      'Please enter your PayPal email.': 'Please enter your PayPal email.',
      'Please fill in all fields correctly.':
          'Please fill in all fields correctly.',
      'Please fill in all required fields':
          'Please fill in all required fields',
      'Please fill in at least one field.':
          'Please fill in at least one field.',
      'Please fix the highlighted fields and try again.':
          'Please fix the highlighted fields and try again.',
      'Please try logging in again': 'Please try logging in again',
      'Please verify your email to continue.':
          'Please verify your email to continue.',
      'Profile completed successfully!': 'Profile completed successfully!',
      'Profile picture updated successfully!':
          'Profile picture updated successfully!',
      'Profile updated successfully!': 'Profile updated successfully!',
      'Review submitted successfully!': 'Review submitted successfully!',
      'Selected image file is not accessible. Please try again.':
          'Selected image file is not accessible. Please try again.',
      'Sitter blocked successfully!': 'Sitter blocked successfully!',
      'Something went wrong. Please try again.':
          'Something went wrong. Please try again.',
      'Something went wrong. Please try logging in again.':
          'Something went wrong. Please try logging in again.',
      'Task added successfully!': 'Task added successfully!',
      'Unknown user role. Please try again.':
          'Unknown user role. Please try again.',
      'Verification code has been resent to your email':
          'Verification code has been resent to your email',
      'Verification code resent': 'Verification code resent',
      'Welcome back!': 'Welcome back!',
      'You have already reviewed this sitter. You can only submit one review per sitter.':
          'You have already reviewed this sitter. You can only submit one review per sitter.',
      'Your city (@city) has been detected':
          'Your city (@city) has been detected',
      'Profile updated but image upload failed. Please try again.':
          'Profile updated but image upload failed. Please try again.',
      'Profile updated but image upload failed: @error':
          'Profile updated but image upload failed: @error',

      // Posts / Comments
      'post_action_like': 'Gefällt mir',
      'post_action_comment': 'Kommentieren',
      'post_action_share': 'Teilen',
      'post_comments_title': 'Kommentare',
      'post_comments_hint': 'Kommentar hinzufügen...',
      'post_comments_empty_title': 'Noch keine Kommentare',
      'post_comments_empty_subtitle': 'Sei der Erste, der kommentiert!',
      'post_comment_added_success': 'Kommentar erfolgreich hinzugefügt!',
      'post_comment_add_failed':
          'Kommentar konnte nicht hinzugefügt werden. Bitte versuche es erneut.',
      'post_comments_count_singular': '@count Kommentar',
      'post_comments_count_plural': '@count Kommentare',

      // Relative time
      'time_days_ago': 'vor @count T',
      'time_hours_ago': 'vor @count Std.',
      'time_minutes_ago': 'vor @count Min.',
      'time_just_now': 'Gerade eben',
      'posts_empty_title': 'Keine Beiträge verfügbar',
      'posts_load_failed':
          'Beiträge konnten nicht geladen werden. Bitte versuche es erneut.',
      'posts_like_login_required': 'Bitte melde dich an, um Beiträge zu liken.',
      'posts_like_failed':
          'Beitrag konnte nicht geliked werden. Bitte versuche es erneut.',
      'posts_unlike_failed':
          'Like konnte nicht entfernt werden. Bitte versuche es erneut.',
      'application_accept_success': 'Anfrage erfolgreich angenommen!',
      'application_reject_success': 'Anfrage erfolgreich abgelehnt!',
      'application_action_failed':
          'Auf die Anfrage konnte nicht geantwortet werden. Bitte versuche es erneut.',
      'request_card_pet_owner': 'Tierhalter: @name',
      'sitter_reservation_requests': 'Buchungsanfragen',
      'sitter_filters': 'Filter',
      'sitter_filters_on': 'Filter an',
      'sitter_no_requests_match': 'Keine Anfragen entsprechen Ihren Filtern.',
      'filter_requests_title': 'Anfragen filtern',
      'filter_clear': 'Zurücksetzen',
      'filter_apply': 'Anwenden',
      'filter_location': 'Ort',
      'filter_service_type': 'Serviceart',
      'filter_dates': 'Daten',
      'filter_city_hint': 'Stadt oder Gebiet',
      'filter_any_dates': 'Beliebige Daten',

      // Profile: Apple connection
      'profile_connect_with_apple': 'Mit Apple verbinden',
      'profile_connection_connected': 'Verbunden',

      'my_posts_title': 'Meine Beiträge',
      'home_segment_sitters': 'Tiersitter',
      'my_posts_no_posts': 'Keine Beiträge gefunden',
      'my_posts_delete_title': 'Beitrag loeschen?',
      'my_posts_delete_message':
          'Moechtest du diesen Beitrag wirklich loeschen? Diese Aktion kann nicht rueckgaengig gemacht werden.',
      'my_posts_delete_success': 'Beitrag erfolgreich geloescht.',
      'my_posts_delete_failed':
          'Beitrag konnte nicht geloescht werden. Bitte versuche es erneut.',
      'my_posts_sort_label': 'Sortieren',
      'my_posts_sort_newest': 'Neueste zuerst',
      'my_posts_sort_oldest': 'Aelteste zuerst',
      'notifications_title': 'Benachrichtigungen',
      'notifications_empty_title': 'Noch keine Benachrichtigungen',
      'notifications_empty_subtitle': 'Wenn etwas passiert, siehst du es hier.',
      'notifications_mark_all_read': 'Alle als gelesen markieren',
      'notifications_load_failed':
          'Benachrichtigungen konnten nicht geladen werden.',
      'notifications_fallback_title': 'Benachrichtigung',
      'notifications_post_view_title': 'Beitrag',
      'notifications_request_view_title': 'Sitter-Anfrage',
      'notifications_application_not_found':
          'Diese Anfrage ist nicht mehr verfuegbar oder konnte nicht geladen werden.',
      'notifications_open_sitter_profile': 'Sitter-Profil anzeigen',
      'notifications_loading': 'Benachrichtigungen werden geladen…',
      'notifications_loading_more': 'Weitere werden geladen…',
      'post_action_delete': 'Loeschen',
      'post_request_default': 'Suche nach einem Tiersitter',

      'sign_up_as_pet_owner': 'Als Tierhalter registrieren',
      'sign_up_as_pet_sitter': 'Als Tiersitter registrieren',
      'label_name': 'Name',
      'hint_name': 'Gib deinen Namen ein',
      'label_email': 'E‑Mail',
      'hint_email': 'Gib deine E‑Mail ein',
      'label_mobile_number': 'Handynummer',
      'hint_phone': 'Gib deine Telefonnummer ein',
      'profile_no_phone_added': 'Keine Telefonnummer hinzugefügt',
      'profile_no_email_added': 'Keine E-Mail hinzugefügt',
      'label_password': 'Passwort',
      'hint_password': 'Erstelle ein Passwort',
      'password_requirement':
          'Mindestens 8 Zeichen mit Groß‑, Kleinbuchstaben und einer Zahl.',
      'label_language': 'Sprache',
      'hint_language': 'Gib die Sprachen ein, die du sprichst',
      'label_address': 'Adresse',
      'hint_address': 'Standort',
      'label_rate_per_hour': 'Stundensatz',
      'hint_rate_per_hour': 'z. B. 20',
      'price_per_hour': 'Preis / Stunde',
      'price_per_day': 'Preis / Tag',
      'price_per_week': 'Preis / Woche',
      'price_per_month': 'Preis / Monat',
      'chat_payment_required_banner': 'Der Chat öffnet sich nach Zahlungsbestätigung.',
      'chat_pay_now_button': 'Jetzt bezahlen',
      'chat_share_phone_button': 'Nummer teilen',
      'terms_read_button': 'AGB lesen',
      'service_prefs_at_owner_label': 'Ich akzeptiere den Service bei mir zu Hause',
      'service_prefs_at_sitter_label': 'Ich akzeptiere den Service beim Sitter',
      'service_location_label': 'Wo soll der Service stattfinden?',
      'service_location_at_owner': 'Bei mir zu Hause',
      'service_location_at_sitter': 'Beim Sitter',
      'service_location_both': 'Beides',
      'profile_my_availability': 'Mein Verfügbarkeitskalender',
      'profile_verify_identity': 'Identität verifizieren',
      'profile_identity_verified': 'Identität verifiziert',
      'theme_setting_title': 'Design',
      'theme_light': 'Hell',
      'theme_dark': 'Dunkel',
      'theme_system': 'System folgen',
      'common_close': 'Schließen',
      'label_skills': 'Fähigkeiten',
      'hint_skills': 'Tierarzt, Erzieher',
      'label_bio': 'Biografie',
      'hint_bio': 'Erzähle etwas über dich',
      'label_terms_prefix': 'Ich akzeptiere die ',
      'label_terms_title': 'Allgemeinen Geschäftsbedingungen und Datenschutz.',
      'or_sign_up_with': 'Oder registriere dich mit',
      'button_google': 'Google',
      'button_apple': 'Apple',
      'button_create_account': 'Konto erstellen',
      'button_creating_account': 'Konto wird erstellt…',
      'button_logout': 'Abmelden',
      'title_login': 'Anmelden',
      'welcome_back': 'Willkommen zurück 👋',
      'login_subtitle': 'Melde dich an, um bei Hopetsit fortzufahren.',
      'hint_password_login': 'Gib dein Passwort ein',
      'forgot_password': 'Passwort vergessen?',
      'forgot_password_reset_title': 'Passwort zurücksetzen',
      'forgot_password_reset_message':
          'Gib deine E-Mail-Adresse ein und wir senden dir einen Code zum Zurücksetzen deines Passworts.',
      'forgot_password_email_label': 'E-Mail-Adresse',
      'forgot_password_sending_code': 'Code wird gesendet...',
      'forgot_password_send_code': 'Bestätigungscode senden',
      'forgot_password_remember': 'Erinnerst du dich an dein Passwort? ',
      'forgot_password_otp_sent_title': 'Code gesendet',
      'forgot_password_otp_sent_message':
          'Der Bestätigungscode wurde an deine E-Mail gesendet',
      'forgot_password_request_failed': 'Anfrage fehlgeschlagen',
      'forgot_password_verified_title': 'Bestätigt',
      'forgot_password_verified_message':
          'Du kannst jetzt dein Passwort zurücksetzen',
      'forgot_password_verification_failed': 'Bestätigung fehlgeschlagen',
      'forgot_password_reset_success':
          'Dein Passwort wurde erfolgreich zurückgesetzt',
      'forgot_password_reset_failed': 'Zurücksetzen fehlgeschlagen',
      'forgot_password_code_resent_title': 'Code erneut gesendet',
      'forgot_password_code_resent_message':
          'Der Bestätigungscode wurde erneut an deine E-Mail gesendet',
      'forgot_password_resend_failed': 'Erneutes Senden fehlgeschlagen',
      'forgot_password_verify_code_title': 'Code verifizieren',
      'forgot_password_enter_code_title': 'Bestätigungscode eingeben',
      'forgot_password_code_sent_to':
          'Wir haben einen 6-stelligen Code an @email gesendet',
      'forgot_password_verifying': 'Wird verifiziert...',
      'forgot_password_resend_in': 'Code erneut senden in @seconds s',
      'forgot_password_resend_code': 'Code erneut senden',
      'forgot_password_wrong_email': 'Falsche E-Mail? ',
      'forgot_password_change_email': 'Ändern',
      'forgot_password_create_new_title': 'Neues Passwort erstellen',
      'forgot_password_set_new_title': 'Lege dein neues Passwort fest',
      'forgot_password_set_new_message':
          'Erstelle ein sicheres Passwort, um dein Konto zu schützen. Stelle sicher, dass es mindestens 8 Zeichen lang ist.',
      'forgot_password_new_hint': 'Neues Passwort eingeben',
      'forgot_password_confirm_hint': 'Passwort erneut eingeben',
      'forgot_password_resetting': 'Passwort wird zurückgesetzt...',
      'forgot_password_reset_button': 'Passwort zurücksetzen',
      'forgot_password_reset_success_title':
          'Passwort erfolgreich zurückgesetzt!',
      'forgot_password_reset_success_message':
          'Dein Passwort wurde erfolgreich zurückgesetzt. Du kannst dich jetzt mit deinem neuen Passwort anmelden.',
      'forgot_password_email_verified_title': 'E-Mail verifiziert',
      'forgot_password_email_verified_subtitle':
          'Deine E-Mail wurde verifiziert',
      'forgot_password_password_updated_title': 'Passwort aktualisiert',
      'forgot_password_password_updated_subtitle':
          'Dein Passwort wurde geändert',
      'forgot_password_login_new_password': 'Mit neuem Passwort anmelden',
      'forgot_password_security_warning':
          'Wenn du diese Änderung nicht angefordert hast, schütze bitte sofort dein Konto.',
      'logging_in': 'Anmeldung läuft...',
      'or_continue_with': 'Oder fortfahren mit',
      'dont_have_account': 'Hast du kein Konto? ',
      'sign_up': 'Registrieren',
      // Onboarding screen
      'onboarding_app_title': 'Home Pets Sitting',
      'onboarding_continue_with_google': 'Mit Google fortfahren',
      'onboarding_continue_with_apple': 'Mit Apple fortfahren',
      'onboarding_have_account': 'Hast du ein Konto?',

      'error_invalid_details_title': 'Ungültige Angaben',
      'error_invalid_details_message':
          'Bitte korrigiere die markierten Felder und versuche es erneut.',
      'error_terms_required_title': 'Bedingungen erforderlich',
      'error_terms_required_message':
          'Bitte akzeptiere die Allgemeinen Geschäftsbedingungen.',
      'error_name_required': 'Bitte gib deinen Namen ein',
      'error_name_length': 'Der Name muss mindestens 2 Zeichen enthalten',
      'error_email_required': 'Bitte gib deine E‑Mail ein',
      'error_email_invalid': 'Bitte gib eine gültige E‑Mail ein',
      'error_phone_invalid': 'Bitte gib eine gültige Telefonnummer ein',
      'error_phone_required': 'Bitte gib deine Telefonnummer ein',
      'error_password_required': 'Bitte gib ein Passwort ein',
      'error_password_length': 'Das Passwort muss mindestens 8 Zeichen haben',
      'error_password_uppercase':
          'Das Passwort muss mindestens einen Großbuchstaben enthalten',
      'error_password_lowercase':
          'Das Passwort muss mindestens einen Kleinbuchstaben enthalten',
      'error_password_number':
          'Das Passwort muss mindestens eine Zahl enthalten',
      'error_password_confirm_required': 'Bitte bestätige dein Passwort',
      'error_password_match': 'Die Passwörter stimmen nicht überein',
      'error_otp_required': 'OTP ist erforderlich',
      'error_otp_length': 'OTP muss 6 Ziffern haben',
      'error_otp_numbers_only': 'OTP darf nur Zahlen enthalten',
      'common_error_generic':
          'Etwas ist schiefgelaufen. Bitte versuche es erneut.',
      'error_address_required': 'Bitte gib deine Adresse ein',
      'error_address_length': 'Die Adresse muss mindestens 2 Zeichen enthalten',
      'error_rate_required': 'Bitte gib deinen Stundensatz ein',
      'error_rate_invalid': 'Bitte gib einen gültigen Satz ein',
      'error_rate_zero': 'Der Stundensatz darf nicht 0 sein',
      'error_skills_required': 'Bitte gib deine Fähigkeiten ein',
      'error_skills_length':
          'Die Fähigkeiten müssen mindestens 2 Zeichen enthalten',

      'location_found_title': 'Standort gefunden',
      'location_found_message': 'Deine Stadt (@city) wurde erkannt',
      'location_not_found_title': 'Standort nicht gefunden',
      'location_not_found_message':
          'Dein Standort konnte nicht ermittelt werden. Bitte aktiviere die Ortungsdienste.',
      'location_error_title': 'Fehler',
      'location_error_message':
          'Der Standort konnte nicht abgerufen werden. Bitte versuche es erneut.',
      // Location picker
      'label_city': 'Stadt',
      'location_getting': 'Wird abgerufen...',
      'location_auto': 'Auto',
      'location_map': 'Karte',
      'location_detected': 'Erkannt: @city',
      'location_enter_city': 'Gib deine Stadt ein',
      'error_city_required': 'Bitte gib deine Stadt ein',
      'location_detected_message':
          'Dein Standort wurde erkannt. Du wirst mit Dienstleistern in diesem Bereich verbunden.',
      'location_select_title': 'Standort auswählen',
      'location_selected': 'Ausgewählter Standort',
      'location_selected_city': 'Ausgewählte Stadt',
      'location_no_city': 'Keine Stadt ausgewählt',
      'location_latitude': 'Breitengrad: @value',
      'location_longitude': 'Längengrad: @value',
      'location_current': 'Aktuell',
      'location_confirm': 'Bestätigen',
      'location_select_error': 'Bitte wähle einen Standort aus',
      'location_get_error': 'Standort konnte nicht abgerufen werden',

      'signup_account_created_title': 'Konto erstellt',
      'signup_account_created_message':
          'Bitte bestätige deine E‑Mail, um fortzufahren.',
      'signup_failed_title': 'Registrierung fehlgeschlagen',
      'signup_failed_generic_message':
          'Etwas ist schiefgelaufen. Bitte versuche es erneut.',

      'language_dialog_title': 'Sprache wählen',
      'language_dialog_message': 'Wähle deine bevorzugte Sprache für die App.',
      'language_updated_title': 'Sprache aktualisiert',
      'language_updated_message': 'Die App-Sprache wurde geändert.',
      'title_profile': 'Profil',
      'edit_profile_title': 'Profil bearbeiten',
      'edit_profile_button': 'Profil aktualisieren',
      'edit_profile_button_updating': 'Profil wird aktualisiert...',
      'service_selection_required': 'Auswahl erforderlich',
      'service_updated': 'Service aktualisiert',
      'service_selected': 'Services ausgewählt',
      'edit_profile_update_success': 'Profil erfolgreich aktualisiert!',
      'edit_profile_picture_update_success':
          'Profilbild erfolgreich aktualisiert!',
      // Choose service screen
      'choose_service_title': 'Dienst auswählen',
      'choose_service_choose_all': 'Alle auswählen',
      'choose_service_saving': 'Wird gespeichert...',
      'choose_service_selecting': 'Wird ausgewählt...',
      'choose_service_save': 'Speichern',
      'choose_service_continue': 'Weiter',
      'choose_service_card_pet_sitting_title': 'Haustierbetreuung',
      'choose_service_card_house_sitting_title': 'Hausbetreuung',
      'choose_service_card_day_care_title': 'Tagesbetreuung',
      'choose_service_card_dog_walking_title': 'Gassi gehen',
      'choose_service_card_subtitle_at_owners_home': 'Beim Tierhalter',
      'choose_service_card_subtitle_in_your_home': 'Bei dir zu Hause',
      'choose_service_card_subtitle_in_neighborhood': 'In deiner Nachbarschaft',
      'section_settings': 'Einstellungen',
      'role_pet_owner': 'Tierhalter',
      'role_pet_sitter': 'Tiersitter',
      'auth_role_pet_owner': 'Tierhalter',
      'auth_role_pet_sitter': 'Tiersitter',
      'profile_add_tasks': 'Aufgaben hinzufügen',
      'profile_view_tasks': 'Aufgaben anzeigen',
      'profile_bookings_history': 'Buchungsverlauf',
      'profile_edit_profile': 'Profil bearbeiten',
      'profile_edit_pets_profile': 'Tierprofil bearbeiten',
      'profile_choose_service': 'Dienstleistung wählen',
      'profile_change_password': 'Passwort ändern',
      'profile_change_language': 'Sprache ändern',
      'profile_blocked_users': 'Blockierte Benutzer',
      'profile_delete_account': 'Konto löschen',
      'profile_donate_us': 'Spenden',
      'blocked_users_title': 'Blockierte Benutzer',
      'blocked_users_empty_title': 'Keine blockierten Benutzer',
      'blocked_users_empty_message':
          'Benutzer, die du blockierst, werden hier angezeigt',
      'blocked_users_unblock_button': 'Entsperren',
      'blocked_users_unblock_dialog_message':
          'Möchtest du @name wirklich entsperren?',
      'delete_account_dialog_message':
          'Möchtest du dein Konto wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
      'delete_account_success_title': 'Konto gelöscht',
      'delete_account_success_message': 'Dein Konto wurde erfolgreich gelöscht',
      'delete_account_failed_title': 'Löschen fehlgeschlagen',
      'delete_account_failed_generic':
          'Etwas ist schiefgelaufen. Bitte versuche es erneut.',
      'logout_dialog_message': 'Möchtest du dich wirklich abmelden?',
      'profile_switch_role_card_title': 'Zu @role wechseln',
      'profile_switch_role_card_description':
          'Wechsle dein Konto zu @role, um Anfragen zu erhalten.',
      'dialog_switch_role_title': 'Rolle wechseln',
      'dialog_switch_role_switching': 'Wechsel zu @role...\n\nBitte warten.',
      'dialog_switch_role_confirm':
          'Möchtest du wirklich zu @role wechseln?\n\nDu kannst jederzeit wieder zurück wechseln.',
      'dialog_switch_role_button': 'Zu @role wechseln',
      'profile_switch_to_sitter': 'Zu Pet Sitter wechseln',
      'profile_switch_to_owner': 'Zu Tierbesitzer wechseln',
      'profile_switch_to_sitter_description':
          'Wechsle dein Konto zu Pet Sitter, um Anfragen zu erhalten.',
      'profile_switch_to_owner_description':
          'Wechsle dein Konto zu Tierbesitzer, um Anfragen zu erhalten.',
      'profile_switch_role_dialog_title': 'Rolle wechseln',
      'profile_switch_to_sitter_loading':
          'Wechsel zu Pet Sitter...\n\nBitte warten.',
      'profile_switch_to_owner_loading':
          'Wechsel zu Tierbesitzer...\n\nBitte warten.',
      'profile_switch_to_sitter_confirm':
          'Möchtest du wirklich zu Pet Sitter wechseln?\n\nDu kannst jederzeit wieder zurück wechseln.',
      'profile_switch_to_owner_confirm':
          'Möchtest du wirklich zu Tierbesitzer wechseln?\n\nDu kannst jederzeit wieder zurück wechseln.',
      'common_continue': 'Fortfahren',
      'common_cancelled': 'Abgebrochen',
      'common_coming_soon': 'Demnächst verfügbar',
      'common_go_to_home': 'Zum Startbildschirm',
      'common_back_to_home': 'Zurück zum Startbildschirm',
      'error_login_required': 'Bitte melde dich erneut an',
      'error_email_not_found':
          'Benutzer-E-Mail nicht gefunden. Bitte melde dich erneut an.',
      'profile_load_error': 'Profil konnte nicht geladen werden',
      'blocked_users_unblock_success': 'Benutzer erfolgreich entsperrt',
      'blocked_users_save_success':
          'Blockierte Benutzer erfolgreich gespeichert',
      'donate_coming_soon': 'Die Spendenfunktion wird bald verfügbar sein',
      'stripe_connect_title': 'Stripe-Konto verbinden',
      'payout_status_screen_title': 'Auszahlungsstatus',
      'payout_connect_stripe_account': 'Stripe-Konto verbinden',
      'payout_paypal_email_title': 'PayPal-Auszahlungs-E-Mail',
      'payout_add_paypal_email_title': 'PayPal-Auszahlungs-E-Mail hinzufuegen',
      'payout_add_paypal_email_subtitle':
          'Lege die E-Mail fest, an die Auszahlungen gesendet werden. Du kannst sie spaeter im Auszahlungsstatus aktualisieren.',
      'payout_status_saved': 'Gespeichert',
      'payout_status_not_set': 'Nicht gesetzt',
      'payout_paypal_email_hint':
          'Fuege eine E-Mail hinzu, um Auszahlungen ueber PayPal zu erhalten.',
      'payout_update_paypal_email': 'PayPal-E-Mail aktualisieren',
      'payout_paypal_dialog_subtitle':
          'Diese E-Mail wird fuer PayPal-Auszahlungen verwendet. Stelle sicher, dass sie zu deinem PayPal-Konto passt.',
      'payout_stripe_connect_title': 'Stripe Connect',
      'payout_status_connected': 'Verbunden',
      'payout_status_not_connected': 'Nicht verbunden',
      'payout_stripe_connected_message':
          'Dein Stripe-Konto ist verbunden und bereit, Zahlungen zu empfangen.',
      'payout_stripe_not_connected_message':
          'Verbinde dein Stripe-Konto, um Auszahlungen zu erhalten.',
      'payout_account_id_label': 'Konto-ID',
      'payout_verification_title': 'Verifizierungsstatus',
      'payout_status_title': 'Auszahlungsstatus',
      'payout_verification_step_identity': 'Identitaetspruefung',
      'payout_verification_step_bank': 'Bankkonto-Verifizierung',
      'payout_verification_step_business': 'Unternehmensinformationen',
      'payout_next_payout_label': 'Naechste Auszahlung',
      'payout_schedule_label': 'Auszahlungsrhythmus',
      'payout_schedule_daily': 'Taeglich',
      'payout_minimum_amount_label': 'Mindestbetrag',
      'payout_status_verified': 'Verifiziert',
      'payout_status_pending': 'Ausstehend',
      'payout_status_rejected': 'Abgelehnt',
      'payout_status_not_started': 'Nicht gestartet',
      'payout_status_active': 'Aktiv',
      'payout_status_restricted': 'Eingeschraenkt',
      'payout_verification_message_verified':
          'Dein Konto wurde verifiziert. Du kannst jetzt Auszahlungen erhalten.',
      'payout_verification_message_pending':
          'Deine Verifizierung wird geprueft. Das dauert normalerweise 1-2 Werktage.',
      'payout_verification_message_rejected':
          'Deine Verifizierung wurde abgelehnt. Bitte aktualisiere deine Daten und versuche es erneut.',
      'payout_verification_message_not_started':
          'Bitte schliesse die Verifizierung ab, um Auszahlungen zu erhalten.',
      'payout_message_active':
          'Deine Auszahlungen sind aktiv. Einnahmen werden taeglich auf dein Bankkonto ueberwiesen.',
      'payout_message_pending':
          'Dein Auszahlungskonto wird eingerichtet. Das kann einige Werktage dauern.',
      'payout_message_restricted':
          'Deine Auszahlungen sind derzeit eingeschraenkt. Bitte kontaktiere den Support.',
      'payout_message_not_connected':
          'Verbinde dein Stripe-Konto, um Auszahlungen zu erhalten.',
      'stripe_get_paid_title': 'Mit Stripe bezahlt werden',
      'stripe_connect_description':
          'Verbinde dein Stripe-Konto, um Zahlungen direkt von Tierbesitzern zu erhalten. Deine Einnahmen werden auf dein Bankkonto überwiesen.',
      'stripe_account_status_title': 'Kontostatus',
      'stripe_continue_onboarding': 'Onboarding fortsetzen',
      'stripe_connect_account_button': 'Stripe-Konto verbinden',
      'stripe_benefit_secure': 'Sichere Zahlungsabwicklung',
      'stripe_benefit_fast_payouts': 'Schnelle Auszahlungen auf dein Bankkonto',
      'stripe_benefit_no_fees': 'Keine Einrichtungsgebühren',
      'stripe_benefit_support': '24/7 Kundensupport',
      'stripe_benefit_required':
          'Erforderlich, um Zahlungen von Tierbesitzern zu erhalten',
      'stripe_account_connected': 'Konto verbunden',
      'stripe_account_created_pending':
          'Konto erstellt - Onboarding ausstehend',
      'stripe_account_created': 'Konto erstellt',
      'stripe_account_connected_message':
          'Dein Stripe-Konto ist vollständig eingerichtet und bereit, Zahlungen zu empfangen.',
      'stripe_account_created_message':
          'Dein Stripe-Konto wurde erstellt. Bitte schließe den Onboarding-Prozess ab, um Zahlungen zu empfangen.',
      'stripe_account_created_partial_message':
          'Dein Zahlungskonto wurde erstellt. Einige Verifizierungsschritte stehen noch aus. Du kannst sie in den Kontoeinstellungen abschließen.',
      'stripe_account_id_label': 'Konto-ID',
      'stripe_loading_onboarding': 'Stripe-Onboarding wird geladen...',
      'stripe_account_connected_success': 'Stripe-Konto erfolgreich verbunden!',
      'stripe_onboarding_completed': 'Stripe-Onboarding abgeschlossen!',
      'stripe_onboarding_cancelled': 'Das Stripe-Onboarding wurde abgebrochen.',
      'stripe_onboarding_load_error':
          'Fehler beim Laden der Stripe-Onboarding-Seite: @error',
      'stripe_cancel_onboarding_title': 'Onboarding abbrechen?',
      'stripe_cancel_onboarding_message':
          'Möchtest du das Stripe-Onboarding wirklich abbrechen? Du kannst es später in den Einstellungen abschließen.',
      'stripe_connect_payment_title': 'Zahlungskonto verbinden',
      'stripe_connect_payment_description':
          'Um als Pet Sitter Zahlungen zu erhalten, musst du dein Zahlungskonto verbinden. Dies ist ein erforderlicher Schritt, um die Einrichtung deines Profils abzuschließen.',
      'stripe_connect_payment_partial_description':
          'Dein Zahlungskonto wurde erstellt. Einige Verifizierungsschritte stehen noch aus. Du kannst sie später in den Kontoeinstellungen abschließen.',
      'stripe_connect_payment_partial_info':
          'Dein Konto ist verbunden, aber einige Verifizierungsschritte stehen noch aus. Du kannst sie in den Kontoeinstellungen abschließen.',
      'stripe_payment_connected_success': 'Zahlung erfolgreich verbunden!',
      'stripe_connect_now': 'Jetzt verbinden',
      'stripe_already_connected': 'Bereits verbunden',
      'stripe_already_connected_message':
          'Dein Stripe-Konto ist bereits verbunden und aktiv.',
      'stripe_connect_error':
          'Fehler beim Verbinden des Stripe-Kontos. Bitte versuche es erneut.',
      'stripe_no_onboarding_url':
          'Keine Onboarding-URL verfügbar. Bitte erstelle zuerst ein Stripe-Konto.',
      'stripe_onboarding_expired_title': 'Abgelaufen',
      'stripe_onboarding_expired_message':
          'Der Onboarding-Link ist abgelaufen. Bitte erstelle einen neuen.',
      'stripe_disconnect_success': 'Stripe-Konto erfolgreich getrennt!',
      'stripe_disconnect_error':
          'Fehler beim Trennen des Stripe-Kontos. Bitte versuche es erneut.',
      'payment_title': 'Zahlung',
      'payment_info_message':
          'Klicke unten auf "Bezahlen", um deine Zahlungsdaten sicher über das sichere Stripe-Zahlungsformular einzugeben.',
      'payment_paypal_info':
          'Du wirst zu PayPal weitergeleitet, um die Zahlung zu bestätigen. Danach bestätigen wir sie hier.',
      'payment_pay_with_stripe': 'Mit Stripe bezahlen @amount',
      'payment_pay_with_paypal': 'Mit PayPal bezahlen @amount',
      'booking_agreement_title': 'Buchungsvereinbarung',
      'booking_agreement_payment_completed': 'Zahlung abgeschlossen',
      'booking_agreement_booking_cancelled': 'Buchung storniert',
      'booking_agreement_status_label': 'Status: @status',
      'booking_agreement_start_date_label': 'Startdatum',
      'booking_agreement_end_date_label': 'Enddatum',
      'booking_agreement_time_slot_label': 'Zeitfenster',
      'booking_agreement_service_provider_label': 'Dienstleister',
      'booking_agreement_service_type_label': 'Serviceart',
      'booking_agreement_special_instructions_label': 'Besondere Hinweise',
      'booking_agreement_cancelled_at_label': 'Storniert am',
      'booking_agreement_cancellation_reason_label': 'Stornierungsgrund',
      'booking_agreement_price_breakdown_title': 'Preisaufschlüsselung',
      'booking_agreement_pricing_tier_label': 'Preisstufe',
      'booking_agreement_total_hours_label': 'Gesamtstunden',
      'booking_agreement_total_days_label': 'Gesamttage',
      'booking_agreement_base_price_label': 'Grundpreis',
      'booking_agreement_platform_fee_label': 'Plattformgebühr',
      'booking_agreement_net_amount_label': 'Nettobetrag (an Tiersitter)',
      'booking_agreement_today_at': 'Heute um @time',
      'booking_agreement_yesterday_at': 'Gestern um @time',
      'booking_agreement_at': 'um',
      'payment_method_paypal': 'PayPal',
      'payment_pay_button': '@amount bezahlen',
      'payment_amount_label': 'Zu zahlender Betrag',
      'payment_loading_page': 'Zahlungsseite wird geladen...',
      'payment_cancel_title': 'Zahlung abbrechen?',
      'payment_cancel_message': 'Möchtest du diese Zahlung wirklich abbrechen?',
      'payment_continue': 'Zahlung fortsetzen',
      'payment_load_error': 'Fehler beim Laden der Zahlungsseite: @error',
      'payment_success_title': 'Zahlung erfolgreich!',
      'payment_failed_title': 'Zahlung fehlgeschlagen',
      'payment_success_message': 'Deine Zahlung wurde erfolgreich verarbeitet.',
      'payment_rate_sitter': 'Pet Sitter bewerten',
      'payment_try_again': 'Erneut versuchen',
      'payment_transaction_details': 'Transaktionsdetails',
      'payment_transaction_id_label': 'Transaktions-ID',
      'payment_date_label': 'Datum',
      'payment_error_client_secret_missing':
          'Fehler beim Erstellen der Zahlungsabsicht. Client-Geheimnis fehlt.',
      'payment_error_publishable_key_missing':
          'Stripe-Veröffentlichungsschlüssel fehlt.',
      'payment_error_invalid_publishable_key':
          'Ungültiger Stripe-Veröffentlichungsschlüssel.',
      'payment_processing_failed':
          'Zahlungsverarbeitung fehlgeschlagen. Bitte versuche es erneut.',
      'payment_error_title': 'Zahlungsfehler',
      'payment_unavailable_title': 'Zahlung nicht verfügbar',
      'payment_unavailable_message':
          'Das Stripe-Konto des Pet Sitters ist noch nicht vollständig verifiziert. Er muss die Kontoverifizierung (einschließlich Identität, Bankkonto und Geschäftsdetails) abschließen, bevor er Zahlungen erhalten kann. Bitte kontaktiere den Pet Sitter, um die Einrichtung seines Stripe-Kontos abzuschließen.',
      'payment_invalid_amount_title': 'Ungültiger Betrag',
      'payment_invalid_amount_message':
          'Der Zahlungsbetrag ist ungültig. Bitte kontaktiere den Support.',
      'payment_initiate_error':
          'Fehler beim Initiieren der Zahlung. Bitte versuche es erneut.',
      'payment_confirmation_failed':
          'Zahlungsbestätigung fehlgeschlagen. Bitte kontaktiere den Support.',
      'review_already_reviewed_title': 'Bereits bewertet',
      'review_already_reviewed_message':
          'Du hast diesen Pet Sitter bereits bewertet. Du kannst nur eine Bewertung pro Pet Sitter abgeben.',
      'sitter_applications_tab': 'Bewerbungen',
      'sitter_no_bookings_found': 'Keine Buchungen gefunden',
      'sitter_application_accepted_success': 'Bewerbung erfolgreich angenommen',
      'sitter_application_accept_failed':
          'Fehler beim Annehmen der Bewerbung. Bitte versuche es erneut.',
      'sitter_application_rejected_success': 'Bewerbung erfolgreich abgelehnt',
      'sitter_application_reject_failed':
          'Fehler beim Ablehnen der Bewerbung. Bitte versuche es erneut.',
      'sitter_chat_start_failed':
          'Fehler beim Starten der Unterhaltung. Bitte versuche es erneut.',
      'sitter_chat_with_owner': 'Mit Besitzer chatten',
      'sitter_pet_weight': 'Gewicht',
      'sitter_pet_height': 'Größe',
      'sitter_pet_color': 'Farbe',
      'sitter_not_yet_available': 'Noch nicht verfügbar',
      'sitter_detail_date': 'Datum',
      'sitter_detail_time': 'Uhrzeit',
      'sitter_detail_phone': 'Telefon',
      'sitter_detail_email': 'E-Mail',
      'sitter_detail_location': 'Standort',
      'sitter_not_available_yet': 'Noch nicht verfügbar',
      'sitter_reject': 'Ablehnen',
      'sitter_accept': 'Annehmen',
      'sitter_status_label': 'Status: @status',
      'sitter_payment_status_label': 'Zahlung: @status',
      'sitter_time_just_now': 'Gerade eben',
      'sitter_time_mins_ago': 'Vor @minutes Min',
      'sitter_time_hours_ago': 'Vor @hours Std',
      'sitter_time_days_ago': 'Vor @days Tagen',
      'sitter_weekday_mon': 'Mo',
      'sitter_weekday_tue': 'Di',
      'sitter_weekday_wed': 'Mi',
      'sitter_weekday_thu': 'Do',
      'sitter_weekday_fri': 'Fr',
      'sitter_weekday_sat': 'Sa',
      'sitter_weekday_sun': 'So',
      'sitter_month_jan': 'Jan',
      'sitter_month_feb': 'Feb',
      'sitter_month_mar': 'Mär',
      'sitter_month_apr': 'Apr',
      'sitter_month_may': 'Mai',
      'sitter_month_jun': 'Jun',
      'sitter_month_jul': 'Jul',
      'sitter_month_aug': 'Aug',
      'sitter_month_sep': 'Sep',
      'sitter_month_oct': 'Okt',
      'sitter_month_nov': 'Nov',
      'sitter_month_dec': 'Dez',
      'sitter_service_long_term_care': 'Langzeitpflege',
      'sitter_service_dog_walking': 'Hundespaziergang',
      'sitter_service_overnight_stay': 'Übernachtung',
      'sitter_service_home_visit': 'Hausbesuch',
      'sitter_request_details_title': 'Anfragedetails',
      'sitter_requests_section': 'Anfragen',
      'sitter_info_pets': 'Haustiere',
      'sitter_no_pets': 'Keine Haustiere',
      'sitter_info_service': 'Service',
      'sitter_no_service_type': 'Kein Servicetyp verfügbar',
      'sitter_info_date': 'Datum',
      'sitter_no_date_available': 'Kein Datum verfügbar',
      'sitter_pets_section': 'Haustiere',
      'sitter_note_section': 'Notiz',
      'sitter_no_note_provided': 'Keine Notiz angegeben.',
      'sitter_decline': 'Ablehnen',
      'owner_booking_details_title': 'Buchungsdetails',
      'owner_service_provider_section': 'Dienstleister',
      'owner_info_pets': 'Haustiere',
      'owner_no_pets': 'Keine Haustiere',
      'owner_info_service': 'Service',
      'owner_no_service_type': 'Kein Servicetyp verfügbar',
      'owner_info_date': 'Datum',
      'owner_no_date_available': 'Kein Datum verfügbar',
      'owner_info_total_amount': 'Gesamtbetrag',
      'owner_pets_section': 'Haustiere',
      'owner_note_section': 'Notiz',
      'owner_no_note_provided': 'Keine Notiz angegeben.',
      'owner_chat_with_sitter': 'Mit Pet Sitter chatten',
      'owner_pay_now': 'Jetzt bezahlen',
      'owner_pay_with_amount': '\$@amount bezahlen',
      'owner_cancel_booking': 'Buchung stornieren',
      'owner_time_just_now': 'Gerade eben',
      'owner_time_mins_ago': 'Vor @minutes Min',
      'owner_time_hours_ago': 'Vor @hours Std',
      'owner_time_days_ago': 'Vor @days Tagen',
      'owner_weekday_mon': 'Mo',
      'owner_weekday_tue': 'Di',
      'owner_weekday_wed': 'Mi',
      'owner_weekday_thu': 'Do',
      'owner_weekday_fri': 'Fr',
      'owner_weekday_sat': 'Sa',
      'owner_weekday_sun': 'So',
      'owner_month_jan': 'Jan',
      'owner_month_feb': 'Feb',
      'owner_month_mar': 'Mär',
      'owner_month_apr': 'Apr',
      'owner_month_may': 'Mai',
      'owner_month_jun': 'Jun',
      'owner_month_jul': 'Jul',
      'owner_month_aug': 'Aug',
      'owner_month_sep': 'Sep',
      'owner_month_oct': 'Okt',
      'owner_month_nov': 'Nov',
      'owner_month_dec': 'Dez',
      'owner_service_long_term_care': 'Langzeitpflege',
      'owner_service_dog_walking': 'Hundespaziergang',
      'owner_service_overnight_stay': 'Übernachtung',
      'owner_service_home_visit': 'Hausbesuch',
      'owner_rating_with_reviews': '@rating (@count Bewertungen)',
      'owner_pet_needs_medication': 'Benötigt Medikamente / @medication',
      // Home screen & applications
      'home_default_user_name': 'Benutzer',
      'home_no_sitters_message': 'Derzeit sind keine Tiersitter verfügbar.',
      'home_block_sitter_message':
          'Möchtest du @name wirklich blockieren? Du kannst sein Profil dann nicht mehr sehen oder Anfragen senden.',
      'home_block_sitter_yes': 'Abbrechen',
      'home_block_sitter_no': 'Blockieren',
      'status_available': 'verfügbar',
      'applications_tab_title': 'Anfragen',
      'bookings_tab_title': 'Buchungen',
      'applications_empty_message': 'Keine Anfragen gefunden',
      'bookings_empty_message': 'Keine Buchungen gefunden',
      'booking_cancel_dialog_message':
          'Möchtest du diese Buchung wirklich stornieren?',
      // Common UI
      'common_select': 'Auswählen',
      'common_save': 'Speichern',
      'common_later': 'Spaeter',
      'common_saving': 'Wird gespeichert...',
      // Expandable post input
      'post_input_label': 'Beitrag',
      'post_input_hint': 'Schreibe deinen Beitrag hier...',
      'post_button': 'Veröffentlichen',
      'post_button_posting': 'Wird veröffentlicht...',
      // Tasks screens
      'view_task_title': 'Aufgaben anzeigen',
      'view_task_empty': 'Keine Aufgaben gefunden',
      'view_task_date_not_available': 'Datum nicht verfügbar',
      'add_task_title': 'Aufgabe hinzufügen',
      'add_task_title_label': 'Titel',
      'add_task_title_hint': 'Titel eingeben',
      'add_task_description_label': 'Beschreibung',
      'add_task_description_hint': 'Text...',
      'add_task_save_button': 'Speichern',
      'add_task_saving': 'Wird gespeichert...',
      // Change password
      'change_password_title': 'Passwort ändern',
      'change_password_new_label': 'Neues Passwort',
      'change_password_confirm_label': 'Passwort bestätigen',
      'change_password_confirm_hint': 'Passwort bestätigen',
      // Add card
      'add_card_title': 'Karte hinzufügen',
      'add_card_holder_label': 'Karteninhaber',
      'add_card_holder_hint': 'Max Mustermann',
      'add_card_number_label': 'Kartennummer',
      'add_card_number_hint': '0987 0986 5543 0980',
      'add_card_exp_label': 'Ablaufdatum',
      'add_card_exp_hint': '10/23',
      'add_card_cvc_label': 'CVC',
      'add_card_cvc_hint': '345',
      // My pets
      'my_pets_title': 'Meine Haustiere',
      'my_pets_add_pet': 'Haustier hinzufügen',
      'my_pets_error_loading': 'Fehler beim Laden der Haustiere',
      'my_pets_retry': 'Erneut versuchen',
      'my_pets_empty': 'Keine Haustiere gefunden',
      'my_pets_color_label': 'Farbe',
      'my_pets_profile_label': 'Profil',
      'my_pets_passport_label': 'Pass',
      'my_pets_chip_label': 'Chip',
      'my_pets_allergies_label': 'Allergien',
      // Create pet profile
      'create_pet_appbar_title': 'Benutzer',
      'create_pet_skip': 'Überspringen',
      'create_pet_header': 'Erstelle ein Profil für dein Haustier',
      'create_pet_name_label': 'Name des Haustiers',
      'create_pet_name_hint': 'Gib den Namen deines Haustiers ein',
      'create_pet_breed_label': 'Rasse',
      'create_pet_breed_hint': 'Gib die Rasse ein',
      'create_pet_dob_label': 'Geburtsdatum',
      'create_pet_dob_hint': 'Gib das Geburtsdatum deines Haustiers ein',
      'create_pet_weight_label': 'Gewicht (KG)',
      'create_pet_weight_hint': 'z. B. 12 kg',
      'create_pet_height_label': 'Größe (CM)',
      'create_pet_height_hint': 'z. B. 50 cm',
      'create_pet_passport_label': 'Passnummer',
      'create_pet_passport_hint': 'Gib die Passnummer ein',
      'create_pet_chip_label': 'Chipnummer',
      'create_pet_chip_hint': 'Gib die Chipnummer ein',
      'create_pet_med_allergies_label': 'Medikamentenallergien',
      'create_pet_med_allergies_hint': 'Gib die Medikamentenallergien ein',
      'create_pet_category_label': 'Kategorie',
      'create_pet_category_dog': 'Hund',
      'create_pet_category_cat': 'Katze',
      'create_pet_category_bird': 'Vogel',
      'create_pet_category_rabbit': 'Kaninchen',
      'create_pet_category_other': 'Andere',
      'create_pet_vaccination_label': 'Impfstatus',
      'create_pet_vaccination_up_to_date': 'Aktuell',
      'create_pet_vaccination_not_vaccinated': 'Nicht geimpft',
      'create_pet_vaccination_partial': 'Teilweise geimpft',
      'create_pet_profile_view_label': 'Profilansicht',
      'create_pet_profile_view_public': 'Öffentlich',
      'create_pet_profile_view_private': 'Privat',
      'create_pet_profile_view_friends': 'Nur Freunde',
      'create_pet_upload_media_label':
          'Bilder und Videos deines Haustiers hochladen',
      'create_pet_upload_media_upload': 'Hochladen',
      'create_pet_upload_media_change': 'Ändern (@count)',
      'create_pet_upload_media_selected': '@count Datei(en) ausgewählt',
      'create_pet_upload_passport_label': 'Passfoto deines Haustiers hochladen',
      'create_pet_upload_passport_change': 'Ändern',
      'create_pet_upload_passport_upload': 'Hochladen',
      'create_pet_upload_passport_selected': 'Passbild ausgewählt',
      'create_pet_button_creating': 'Profil wird erstellt...',
      'create_pet_button': 'Profil für das Haustier erstellen',
      // Send request screen
      'send_request_title': 'Anfrage senden',
      'send_request_description_label': 'Beschreibung',
      'send_request_description_hint': 'Gib zusätzliche Details ein...',
      'label_pets': 'Haustiere',
      'send_request_no_pets_message':
          'Keine Haustiere. Füge ein Haustier hinzu, um fortzufahren.',
      'send_request_pets_select_placeholder': 'Auswählen',
      'send_request_dates_label': 'Daten',
      'send_request_start_label': 'Beginn',
      'send_request_end_label': 'Ende',
      'send_request_select_date': 'Datum auswählen',
      'send_request_select_time': 'Uhrzeit auswählen',
      'send_request_service_type_label': 'Servicetyp',
      'send_request_service_long_term_care': 'Langzeitpflege',
      'send_request_service_dog_walking': 'Hundespaziergang',
      'send_request_service_overnight_stay': 'Übernachtung',
      'send_request_service_home_visit': 'Hausbesuch',
      'send_request_duration_label': 'Dauer (Minuten)',
      'send_request_duration_minutes_label': '@minutes Min',
      'send_request_button': 'Anfrage senden',
      'send_request_button_sending': 'Wird gesendet...',
      'send_request_validation_error_title': 'Validierungsfehler',
      'send_request_invalid_time_title': 'Ungültige Uhrzeit',
      'send_request_invalid_time_message':
          'Die Endzeit muss nach der Startzeit liegen.',
      // Reservierungsanfrage veröffentlichen (Besitzer) – nur UI
      'publish_request_home_cta': 'Reservierungsanfrage veröffentlichen',
      'publish_request_title': 'Anfrage veröffentlichen',
      'publish_request_select_pets': 'Haustier(e) auswählen',
      'publish_request_selected_pets': '@count ausgewählt',
      'publish_request_select_pets_title': 'Haustiere auswählen',
      'publish_request_notes_label': 'Zusätzliche Hinweise',
      'publish_request_notes_hint': 'Alles, was der Sitter wissen sollte...',
      'publish_request_address_label': 'Adresse (optional)',
      'publish_request_address_hint': 'Straße, Gebäude usw.',
      'publish_request_images_label': 'Bilder',
      'publish_request_add_images': 'Bilder hinzufügen',
      'publish_request_add_more_images': 'Mehr Bilder hinzufügen',
      'publish_request_publish_button': 'Anfrage veröffentlichen',
      'publish_request_fill_required': 'Bitte alle Pflichtfelder ausfüllen.',
      'publish_request_ui_only_success':
          'UI erstellt (noch nicht veröffentlicht).',
      'publish_request_success':
          'Reservierungsanfrage erfolgreich veröffentlicht!',
      'publish_request_service_walking': 'Spaziergang',
      'publish_request_service_boarding': 'Unterbringung',
      'publish_request_service_daycare': 'Tagesbetreuung',
      'publish_request_service_pet_sitting': 'Tiersitting',
      'publish_request_service_house_sitting': 'Haussitting',
      'house_sitting_venue_label': 'Ort des Haussittings',
      'house_sitting_venue_owners_home': 'Beim Tierhalter zu Hause',
      'house_sitting_venue_sitters_home': 'Beim Tiersitter zu Hause',
      // Chat screens
      'chat_error_loading_conversations':
          'Fehler beim Laden der Unterhaltungen',
      'chat_retry': 'Erneut versuchen',
      'chat_no_conversations': 'Noch keine Unterhaltungen',
      'chat_error_loading_messages': 'Fehler beim Laden der Nachrichten',
      'chat_no_messages': 'Noch keine Nachrichten. Starte die Unterhaltung!',
      'chat_input_hint': 'Schreibe eine Nachricht...',
      'chat_locked_title': 'Chat gesperrt',
      'chat_locked_after_payment':
          'Der Chat ist erst nach abgeschlossener Buchungszahlung verfügbar.',
      // Pets map screen
      'map_search_hint': 'Stadt oder Gebiet suchen',
      'map_search_empty': 'Bitte gib einen Ort ein.',
      'map_search_not_found': 'Ort konnte nicht gefunden werden: @query',
      'map_search_failed':
          'Die Suche ist fehlgeschlagen. Bitte versuche es erneut.',
      'map_offers_near_me': 'Angebote in meiner Nähe',
      'map_radius_label': 'Radius:',
      'map_distance_filter_label': 'Entfernung: @km km',
      'map_no_nearby_sitters': 'Keine Tiersitter in der Nähe',
      'map_sitter_services_distance': '@services • @distance km',
      // Service provider detail screen
      'sitter_detail_loading_name': 'Wird geladen...',
      'sitter_detail_load_error': 'Sitterdetails konnten nicht geladen werden',
      'sitter_detail_no_rating': 'Noch keine Bewertung',
      'sitter_detail_about_title': 'Über @name',
      'sitter_detail_no_bio': 'Keine Beschreibung verfügbar.',
      'sitter_detail_booking_details_title': 'Buchungsdetails',
      'sitter_detail_availability_pricing_title': 'Verfügbarkeit & Preise',
      'sitter_detail_hourly_rate_label': 'Stundensatz',
      'sitter_detail_weekly_rate_label': 'Wochenpreis',
      'sitter_detail_monthly_rate_label': 'Monatspreis',
      'sitter_detail_current_status_label': 'Aktueller Status',
      'sitter_detail_application_status_label': 'Anfragestatus',
      'sitter_detail_skills_title': 'Fähigkeiten',
      'sitter_detail_no_skills': 'Keine Fähigkeiten eingetragen.',
      'sitter_detail_reviews_title': 'Bewertungen',
      'sitter_detail_no_reviews': 'Noch keine Bewertungen.',
      'sitter_detail_anonymous_reviewer': 'Anonym',
      'sitter_detail_starting_chat': 'Wird gestartet...',
      'sitter_detail_unlock_after_payment': 'Nach Zahlung freischalten',
      'sitter_detail_start_chat': 'Chat starten',
      'sitter_detail_start_chat_failed':
          'Konversation konnte nicht gestartet werden. Bitte versuche es erneut.',
      'status_available_label': 'Verfügbar',
      'status_cancelled_label': 'Storniert',
      'status_rejected_label': 'Abgelehnt',
      'status_pending_label': 'Ausstehend',
      'status_agreed_label': 'Vereinbart',
      'status_paid_label': 'Bezahlt',
      'status_accepted_label': 'Akzeptiert',
      // Pet detail screen
      'pet_detail_loading': 'Haustierdetails werden geladen...',
      'pet_detail_about': 'Über @name',
      'pet_detail_weight': 'Gewicht',
      'pet_detail_height': 'Größe',
      'pet_detail_color': 'Farbe',
      'pet_detail_passport_number': 'Passnummer',
      'pet_detail_chip_number': 'Chipnummer',
      'pet_detail_medication_allergies': 'Medikamente/Allergien',
      'pet_detail_date_of_birth': 'Geburtsdatum',
      'pet_detail_category': 'Kategorie',
      'pet_detail_vaccinations': '@name Impfungen',
      'pet_detail_gallery': '@name Galerie',
      'pet_detail_no_photos': 'Keine Fotos verfügbar',
      'pet_detail_owner_information': 'Besitzerinformationen',
      'pet_detail_owner_name': 'Name',
      'pet_detail_owner_created_at': 'Erstellt am',
      'pet_detail_owner_updated_at': 'Aktualisiert am',
      'pet_detail_no_description': 'Keine Beschreibung verfügbar',
      'pet_detail_gender_unknown': 'Unbekannt',
      'pet_detail_breed_unknown': 'Unbekannt',
      'pet_detail_no_vaccinations': 'Keine Impfungen aufgeführt',
      'pet_detail_load_error':
          'Fehler beim Laden der Haustierdetails. Bitte versuchen Sie es erneut.',
      // Sitter bookings screen
      'sitter_bookings_title': 'Meine Buchungen',
      'sitter_bookings_empty_all': 'Keine Buchungen gefunden',
      'sitter_bookings_empty_filtered': 'Keine @status Buchungen gefunden',
      'sitter_bookings_pet_label': 'Haustier',
      'sitter_bookings_date_label': 'Datum',
      'sitter_bookings_time_label': 'Uhrzeit',
      'sitter_bookings_rate_label': 'Tarif',
      'sitter_bookings_description_label': 'Beschreibung',
      'sitter_bookings_cancel_button': 'Buchung stornieren',
      'sitter_bookings_cancel_dialog_message':
          'Sind Sie sicher, dass Sie diese Buchung stornieren möchten?',
      'sitter_bookings_cancel_dialog_yes': 'Ja, stornieren',
      'sitter_bookings_cancel_success':
          'Stornierungsanfrage erfolgreich übermittelt!',
      'sitter_bookings_cancel_error':
          'Fehler bei der Stornierungsanfrage. Bitte versuchen Sie es erneut.',
      // Owner bookings controller
      'bookings_cancel_success': 'Buchung erfolgreich storniert!',
      'bookings_cancel_error':
          'Fehler beim Stornieren der Buchung. Bitte versuchen Sie es erneut.',
      'bookings_cancel_request_success':
          'Stornierungsanfrage erfolgreich übermittelt!',
      'bookings_cancel_request_error':
          'Fehler bei der Stornierungsanfrage. Bitte versuchen Sie es erneut.',
      'request_cancel_button': 'Anfrage stornieren',
      'request_cancel_button_cancelling': 'Wird storniert...',
      'request_cancel_success': 'Anfrage erfolgreich storniert!',
      'request_cancel_error':
          'Anfrage konnte nicht storniert werden. Bitte versuchen Sie es erneut.',
      'bookings_payment_status_error':
          'Fehler beim Abrufen des Zahlungsstatus. Bitte versuchen Sie es erneut.',
      // Service provider card
      'service_card_no_phone': 'Keine Telefonnummer verfügbar',
      'service_card_no_location': 'Kein Ort verfügbar',
      'service_card_block': 'Blockieren',
      'service_card_per_hour_label': 'Pro Stunde @price',
      'service_card_send_request': 'Anfrage senden',
      'sitter_post_pet_details': 'Haustierdetails',
      'service_card_accept': 'Annehmen',
      'service_card_reject': 'Ablehnen',
      'service_card_cancel': 'Abbrechen',
      'service_card_pay_with_amount': '@amount bezahlen',
      'service_card_pay_now': 'Jetzt bezahlen',
      'service_card_chat': 'Chat',
      // Sitter bottom sheet
      'sitter_view_profile': 'Profil ansehen',
      'sitter_rating_with_count': '@rating (@count Bewertungen)',
      // Bookings history
      'bookings_history_title': 'Buchungsverlauf',
      'status_all_label': 'Alle',
      'status_failed_label': 'Fehlgeschlagen',
      'status_refunded_label': 'Erstattet',
      'status_payment_pending_label': 'Zahlung ausstehend',
      'status_payment_failed_label': 'Zahlung fehlgeschlagen',
      'bookings_history_empty_all': 'Keine Buchungen gefunden',
      'bookings_history_empty_filtered':
          'Keine Buchungen mit Status @status gefunden',
      'bookings_detail_pet_label': 'Tier',
      'bookings_detail_date_label': 'Datum',
      'bookings_detail_time_label': 'Uhrzeit',
      'bookings_detail_total_amount_label': 'Gesamtbetrag',
      'bookings_detail_phone_label': 'Telefon',
      'bookings_detail_location_label': 'Ort',
      'bookings_detail_rating_label': 'Bewertung',
      'bookings_detail_description_label': 'Beschreibung',
      'bookings_action_view_details': 'Details anzeigen',
      'Email Not Verified': 'Email Not Verified',
      'Image Error': 'Image Error',
      'Invalid Hourly Rate': 'Invalid Hourly Rate',
      'Location Found': 'Location Found',
      'Location Not Found': 'Location Not Found',
      'Required': 'Required',
      'Role Switched': 'Role Switched',
      'Selection Failed': 'Selection Failed',
      'Selection Required': 'Selection Required',
      'Service Updated': 'Service Updated',
      'Services Selected': 'Services Selected',
      'Success': 'Success',
      'Switch Role Failed': 'Switch Role Failed',
      'Verification Code Sent': 'Verification Code Sent',
      'auth_apple_signin_failed': 'Apple-Anmeldung fehlgeschlagen',
      'auth_apple_signin_failed_generic':
          'Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut.',
      'auth_apple_signin_success': 'Erfolgreich mit Apple angemeldet',
      'auth_google_signin_choose_services':
          'Bitte wählen Sie Ihre Dienstleistungen aus',
      'auth_google_signin_failed':
          'Google-Anmeldung fehlgeschlagen. Bitte versuchen Sie es erneut.',
      'auth_google_signin_firebase_token_failed':
          'Firebase-ID-Token konnte nicht abgerufen werden.',
      'auth_google_signin_success': 'Erfolgreich mit Google angemeldet',
      'auth_google_signin_title': 'Google-Anmeldung',
      'auth_google_signin_token_missing': 'Google-ID-Token fehlt.',
      'auth_google_signin_web_required':
          'Diese Plattform erfordert eine Web-Anmeldung.',
      'auth_role_switch_failed':
          'Rollenwechsel fehlgeschlagen. Bitte versuchen Sie es erneut.',
      'auth_role_switched': 'Rolle gewechselt',
      'auth_role_switched_message': 'Erfolgreich zu @role gewechselt',
      'auth_welcome_back': 'Willkommen zurück!',
      'change_password_failed': 'Failed to change password. Please try again.',
      'change_password_fields_required': 'Please fill in all fields correctly.',
      'change_password_new_required': 'Please enter a new password.',
      'change_password_success': 'Password changed successfully!',
      'change_password_validation_error': 'Validation Error',
      'email_verification_code_required':
          'Please enter the complete verification code',
      'email_verification_success': 'Email verified successfully!',
      'map_load_error': 'Failed to load map data. Please try again.',
      'my_pets_load_error': 'Failed to load pets. Please try again.',
      'pet_create_validation_error': 'Validation Error',
      'pet_update_failed': 'Update Failed',
      'pet_validation_error': 'Validation Error',
      'profile_blocked_users_load_error': 'Failed to load blocked users',
      'profile_edit_coming_soon':
          'Edit profile functionality will be available soon',
      'profile_image_pick_failed': 'Failed to pick image. Please try again.',
      'profile_invalid_file_type': 'Invalid File Type',
      'profile_invalid_file_type_message':
          'Please select a JPEG, PNG, or WebP image.',
      'profile_picture_update_success': 'Profilbild erfolgreich aktualisiert',
      'profile_unblock_failed': 'Unblock Failed',
      'profile_unblock_failed_generic':
          'Something went wrong. Please try again.',
      'profile_unblock_success': 'User unblocked successfully',
      'profile_upload_failed': 'Upload Failed',
      'profile_upload_failed_generic':
          'Something went wrong. Please try again.',
      'profile_user_not_found': 'User not found',
      'request_duration_required':
          'Please select a duration for dog walking service.',
      'request_pet_required': 'Please select at least one pet.',
      'request_send_failed':
          'Anfrage konnte nicht gesendet werden. Bitte versuchen Sie es erneut.',
      'request_send_success': 'Anfrage erfolgreich gesendet!',
      'request_sitter_pricing_error':
          'Bitte legen Sie zuerst Ihren Stundensatz im Profil fest.',
      'request_validation_error': 'Validation Error',
      'review_submit_failed': 'Failed to submit review. Please try again.',
      'share_failed': 'Failed to share. Please try again.',
      'snackbar_choose_service_controller_001':
          'Please select valid services for your account type.',
      'snackbar_choose_service_controller_002':
          'Your services have been updated successfully!',
      'snackbar_choose_service_controller_003':
          'Your services have been selected successfully!',
      'snackbar_choose_service_controller_004':
          'Failed to update services. Please try again.',
      'snackbar_choose_service_controller_005':
          'Please select at least one service to continue.',
      'snackbar_choose_service_controller_006':
          'Please select a valid service to continue.',
      'snackbar_choose_service_controller_007':
          'Please select at least one service.',
      'snackbar_sitter_paypal_payout_controller_001':
          'Die PayPal-Auszahlungs-E-Mail ist erforderlich.',
      'snackbar_sitter_paypal_payout_controller_002':
          'PayPal-Auszahlungs-E-Mail erfolgreich aktualisiert!',
      'snackbar_sitter_paypal_payout_controller_003':
          'PayPal-Auszahlungs-E-Mail konnte nicht aktualisiert werden. Bitte versuche es erneut.',
      'task_add_failed': 'Failed to add task. Please try again.',
      'task_add_success': 'Task added successfully!',
      'task_fetch_failed': 'Failed to fetch tasks.',
      'task_fields_required': 'Please fill in at least one field.',

      'snackbar_text_application_accepted_successfully':
          'Bewerbung erfolgreich angenommen',
      'snackbar_text_application_rejected_successfully':
          'Antrag erfolgreich abgelehnt',
      'snackbar_text_blocked_users_saved_successfully':
          'Blockierte Benutzer erfolgreich gespeichert',
      'snackbar_text_card_saved_successfully': 'Karte erfolgreich gespeichert!',
      'snackbar_text_could_not_detect_your_location_please_enable_location_servic':
          'Ihr Standort konnte nicht ermittelt werden. ',
      'snackbar_text_could_not_load_nearby_sitters_please_try_again':
          'Es konnten keine Sitter in der Nähe geladen werden. ',
      'snackbar_text_email_not_verified': 'E-Mail nicht bestätigt',
      'snackbar_text_failed_to_complete_profile_please_try_again':
          'Profil konnte nicht vervollständigt werden. ',
      'snackbar_text_failed_to_load_booking_details_using_default_pricing':
          'Buchungsdetails konnten nicht geladen werden. ',
      'snackbar_text_failed_to_load_pet_data_please_try_again':
          'Haustierdaten konnten nicht geladen werden. ',
      'snackbar_text_failed_to_load_sitter_details_please_try_again':
          'Details zum Sitter konnten nicht geladen werden. ',
      'snackbar_text_failed_to_pick_passport_image_please_try_again':
          'Passbild konnte nicht ausgewählt werden. ',
      'snackbar_text_failed_to_pick_pet_pictures_or_videos_please_try_again':
          'Die Auswahl von Haustierbildern oder -videos ist fehlgeschlagen. ',
      'snackbar_text_failed_to_pick_pet_profile_image_please_try_again':
          'Das Profilbild des Haustiers konnte nicht ausgewählt werden. ',
      'snackbar_text_failed_to_save_card_please_try_again':
          'Karte konnte nicht gespeichert werden. ',
      'snackbar_text_failed_to_start_conversation_please_try_again':
          'Konversation konnte nicht gestartet werden. ',
      'snackbar_text_failed_to_switch_role_please_try_again':
          'Rollenwechsel fehlgeschlagen. ',
      'snackbar_text_height_is_required': 'Höhe ist erforderlich.',
      'snackbar_text_height_must_be_greater_than_0':
          'Die Höhe muss größer als 0 sein.',
      'snackbar_text_hourly_rate_must_be_greater_than_0':
          'Der Stundensatz muss größer als 0 sein.',
      'snackbar_text_weekly_rate_must_be_greater_than_0':
          'Der Wochenpreis muss groesser als 0 sein.',
      'snackbar_text_monthly_rate_must_be_greater_than_0':
          'Der Monatspreis muss groesser als 0 sein.',
      'snackbar_text_invalid_url': 'Ungültige URL',
      'snackbar_text_unknown_error': 'Unbekannter Fehler',
      'snackbar_text_image_error': 'Bildfehler',
      'snackbar_text_image_uploaded_successfully':
          'Bild erfolgreich hochgeladen!',
      'snackbar_text_invalid_hourly_rate': 'Ungültiger Stundensatz',
      'snackbar_text_location_not_found': 'Standort nicht gefunden',
      'snackbar_text_passwords_do_not_match':
          'Passwörter stimmen nicht überein',
      'snackbar_text_pet_profile_created_but_media_upload_failed_you_can_add_medi':
          'Haustierprofil erstellt, aber das Hochladen der Medien ist fehlgeschlagen. ',
      'snackbar_text_pet_profile_created_successfully':
          'Haustierprofil erfolgreich erstellt!',
      'snackbar_text_pet_profile_updated_successfully':
          'Haustierprofil erfolgreich aktualisiert!',
      'snackbar_text_please_accept_the_terms_and_conditions':
          'Bitte akzeptieren Sie die Allgemeinen Geschäftsbedingungen',
      'snackbar_text_please_enter_your_paypal_email':
          'Bitte geben Sie Ihre PayPal-E-Mail-Adresse ein.',
      'snackbar_text_please_fill_in_all_required_fields':
          'Bitte füllen Sie alle erforderlichen Felder aus',
      'snackbar_text_please_try_logging_in_again':
          'Bitte versuchen Sie erneut, sich anzumelden',
      'snackbar_text_profile_completed_successfully':
          'Profil erfolgreich abgeschlossen!',
      'snackbar_text_profile_updated_but_image_upload_failed_please_try_again':
          'Profil aktualisiert, aber das Hochladen des Bildes ist fehlgeschlagen. ',
      'snackbar_text_required': 'Erforderlich',
      'snackbar_text_review_submitted_successfully':
          'Bewertung erfolgreich eingereicht!',
      'snackbar_text_role_switched': 'Rolle gewechselt',
      'snackbar_text_selected_image_file_is_not_accessible_please_try_again':
          'Auf die ausgewählte Bilddatei kann nicht zugegriffen werden. ',
      'snackbar_text_selection_failed': 'Auswahl fehlgeschlagen',
      'snackbar_text_sitter_blocked_successfully':
          'Sitter erfolgreich blockiert!',
      'snackbar_text_something_went_wrong_please_try_logging_in_again':
          'Etwas ist schief gelaufen. ',
      'snackbar_text_success': 'Erfolg',
      'snackbar_text_successfully_switched_to_userrole_value':
          'Erfolgreicher Rollenwechsel erfolgreich.',
      'snackbar_text_switch_role_failed': 'Rollenwechsel fehlgeschlagen',
      'snackbar_text_unknown_user_role_please_try_again':
          'Unbekannte Benutzerrolle. ',
      'snackbar_text_verification_code_has_been_resent_to_your_email':
          'Der Bestätigungscode wurde erneut an Ihre E-Mail-Adresse gesendet',
      'snackbar_text_verification_code_resent':
          'Bestätigungscode erneut gesendet',
      'snackbar_text_verification_code_sent': 'Bestätigungscode gesendet',
      'snackbar_text_welcome_back': 'Willkommen zurück!',
      'snackbar_text_you_have_already_reviewed_this_sitter_you_can_only_submit_on':
          'Sie haben diesen Sitter bereits bewertet. ',
    'post_more_options': 'Weitere Optionen',
    'post_action_block_user': 'Nutzer blockieren',
    'post_action_report': 'Beitrag melden',
    'block_user_title': 'Nutzer blockieren',
    'block_user_action': 'Blockieren',
    'block_user_confirm_message': 'Mochtest du diesen Nutzer wirklich blockieren? Du siehst seine Inhalte nicht mehr.',
    'block_user_success': 'Nutzer erfolgreich blockiert.',
    'block_user_failed': 'Blockieren fehlgeschlagen. Bitte erneut versuchen.',
    'report_post_received': 'Meldung erhalten. Danke.',
    'pet_photo_delete_title': 'Foto loschen',
    'pet_photo_delete_confirm': 'Mochtest du dieses Foto wirklich loschen?',
    'pet_photo_deleted': 'Foto erfolgreich geloscht.',
    'pet_photo_delete_failed': 'Foto konnte nicht geloscht werden.',
    'new_publication_button': 'Neue Veroffentlichung',
    },
    'it_IT': <String, String>{
      'common_yes': 'Sì',
      'common_no': 'No',
      'common_cancel': 'Annulla',
      'common_error': 'Errore',
      'common_success': 'Successo',
      'common_select_value': 'Seleziona un valore',
      'label_not_available': 'N/D',
      'common_user': 'Utente',
      'common_refresh': 'Aggiorna',
      'common_search': 'Cerca',

      'Application accepted successfully': 'Application accepted successfully',
      'Application rejected successfully': 'Application rejected successfully',
      'Blocked users saved successfully': 'Blocked users saved successfully',
      'Card saved successfully!': 'Card saved successfully!',
      'Could not detect your location. Please enable location services.':
          'Could not detect your location. Please enable location services.',
      'Could not load nearby sitters. Please try again.':
          'Could not load nearby sitters. Please try again.',
      'Email verified successfully!': 'Email verified successfully!',
      'Failed to add task. Please try again.':
          'Failed to add task. Please try again.',
      'Failed to change password. Please try again.':
          'Failed to change password. Please try again.',
      'Failed to complete profile. Please try again.':
          'Failed to complete profile. Please try again.',
      'Failed to fetch tasks.': 'Failed to fetch tasks.',
      'Failed to get your location. Please try again.':
          'Failed to get your location. Please try again.',
      'Failed to load booking details. Using default pricing.':
          'Failed to load booking details. Using default pricing.',
      'Failed to load pet data. Please try again.':
          'Failed to load pet data. Please try again.',
      'Failed to load pets. Please try again.':
          'Failed to load pets. Please try again.',
      'Failed to load profile data. Please try again.':
          'Failed to load profile data. Please try again.',
      'Failed to load sitter details. Please try again.':
          'Failed to load sitter details. Please try again.',
      'Failed to pick image. Please try again.':
          'Failed to pick image. Please try again.',
      'Failed to pick passport image. Please try again.':
          'Failed to pick passport image. Please try again.',
      'Failed to pick pet pictures or videos. Please try again.':
          'Failed to pick pet pictures or videos. Please try again.',
      'Failed to pick pet profile image. Please try again.':
          'Failed to pick pet profile image. Please try again.',
      'Failed to save card. Please try again.':
          'Failed to save card. Please try again.',
      'Failed to start conversation. Please try again.':
          'Failed to start conversation. Please try again.',
      'Failed to submit review. Please try again.':
          'Failed to submit review. Please try again.',
      'Failed to switch role. Please try again.':
          'Failed to switch role. Please try again.',
      'Height is required.': 'Height is required.',
      'Height must be greater than 0.': 'Height must be greater than 0.',
      'Hourly rate must be greater than 0.':
          'Hourly rate must be greater than 0.',
      'Image uploaded successfully!': 'Image uploaded successfully!',
      'Password changed successfully!': 'Password changed successfully!',
      'Passwords do not match': 'Passwords do not match',
      'Pet profile created but media upload failed. You can add media later.':
          'Pet profile created but media upload failed. You can add media later.',
      'Pet profile created successfully!': 'Pet profile created successfully!',
      'Pet profile updated successfully!': 'Pet profile updated successfully!',
      'Please accept the Terms and Conditions':
          'Please accept the Terms and Conditions',
      'Please agree to the Terms and Conditions':
          'Please agree to the Terms and Conditions',
      'Please enter a new password.': 'Please enter a new password.',
      'Please enter the complete verification code':
          'Please enter the complete verification code',
      'Please enter your PayPal email.': 'Please enter your PayPal email.',
      'Please fill in all fields correctly.':
          'Please fill in all fields correctly.',
      'Please fill in all required fields':
          'Please fill in all required fields',
      'Please fill in at least one field.':
          'Please fill in at least one field.',
      'Please fix the highlighted fields and try again.':
          'Please fix the highlighted fields and try again.',
      'Please try logging in again': 'Please try logging in again',
      'Please verify your email to continue.':
          'Please verify your email to continue.',
      'Profile completed successfully!': 'Profile completed successfully!',
      'Profile picture updated successfully!':
          'Profile picture updated successfully!',
      'Profile updated successfully!': 'Profile updated successfully!',
      'Review submitted successfully!': 'Review submitted successfully!',
      'Selected image file is not accessible. Please try again.':
          'Selected image file is not accessible. Please try again.',
      'Sitter blocked successfully!': 'Sitter blocked successfully!',
      'Something went wrong. Please try again.':
          'Something went wrong. Please try again.',
      'Something went wrong. Please try logging in again.':
          'Something went wrong. Please try logging in again.',
      'Task added successfully!': 'Task added successfully!',
      'Unknown user role. Please try again.':
          'Unknown user role. Please try again.',
      'Verification code has been resent to your email':
          'Verification code has been resent to your email',
      'Verification code resent': 'Verification code resent',
      'Welcome back!': 'Welcome back!',
      'You have already reviewed this sitter. You can only submit one review per sitter.':
          'You have already reviewed this sitter. You can only submit one review per sitter.',
      'Your city (@city) has been detected':
          'Your city (@city) has been detected',
      'Profile updated but image upload failed. Please try again.':
          'Profile updated but image upload failed. Please try again.',
      'Profile updated but image upload failed: @error':
          'Profile updated but image upload failed: @error',

      // Posts / Comments
      'post_action_like': 'Mi piace',
      'post_action_comment': 'Commenta',
      'post_action_share': 'Condividi',
      'post_comments_title': 'Commenti',
      'post_comments_hint': 'Aggiungi un commento...',
      'post_comments_empty_title': 'Ancora nessun commento',
      'post_comments_empty_subtitle': 'Sii il primo a commentare!',
      'post_comment_added_success': 'Commento aggiunto con successo!',
      'post_comment_add_failed': 'Impossibile aggiungere il commento. Riprova.',
      'post_comments_count_singular': '@count commento',
      'post_comments_count_plural': '@count commenti',

      // Relative time
      'time_days_ago': '@count g fa',
      'time_hours_ago': '@count h fa',
      'time_minutes_ago': '@count min fa',
      'time_just_now': 'Proprio ora',
      'posts_empty_title': 'Nessun post disponibile',
      'posts_load_failed': 'Impossibile caricare i post. Riprova.',
      'posts_like_login_required': 'Accedi per mettere mi piace ai post.',
      'posts_like_failed': 'Impossibile mettere mi piace al post. Riprova.',
      'posts_unlike_failed': 'Impossibile rimuovere il mi piace. Riprova.',
      'application_accept_success': 'Candidatura accettata con successo!',
      'application_reject_success': 'Candidatura rifiutata con successo!',
      'application_action_failed':
          'Impossibile rispondere alla candidatura. Riprova.',
      'request_card_pet_owner': 'Proprietario: @name',
      'sitter_reservation_requests': 'Richieste di prenotazione',
      'sitter_filters': 'Filtri',
      'sitter_filters_on': 'Filtri attivi',
      'sitter_no_requests_match': 'Nessuna richiesta corrisponde ai filtri.',
      'filter_requests_title': 'Filtra richieste',
      'filter_clear': 'Cancella',
      'filter_apply': 'Applica',
      'filter_location': 'Posizione',
      'filter_service_type': 'Tipo di servizio',
      'filter_dates': 'Date',
      'filter_city_hint': 'Città o zona',
      'filter_any_dates': 'Qualsiasi data',

      // Profile: Apple connection
      'profile_connect_with_apple': 'Connetti con Apple',
      'profile_connection_connected': 'Connesso',

      'my_posts_title': 'I miei post',
      'home_segment_sitters': 'Sitter per animali',
      'my_posts_no_posts': 'Nessun post trovato',
      'my_posts_delete_title': 'Eliminare il post?',
      'my_posts_delete_message':
          'Sei sicuro di voler eliminare questo post? Questa azione non puo essere annullata.',
      'my_posts_delete_success': 'Post eliminato con successo.',
      'my_posts_delete_failed': 'Impossibile eliminare il post. Riprova.',
      'my_posts_sort_label': 'Ordina',
      'my_posts_sort_newest': 'Piu recenti prima',
      'my_posts_sort_oldest': 'Piu vecchi prima',
      'notifications_title': 'Notifiche',
      'notifications_empty_title': 'Nessuna notifica',
      'notifications_empty_subtitle': 'Quando succede qualcosa, la vedrai qui.',
      'notifications_mark_all_read': 'Segna tutte come lette',
      'notifications_load_failed': 'Impossibile caricare le notifiche.',
      'notifications_fallback_title': 'Notifica',
      'notifications_post_view_title': 'Post',
      'notifications_request_view_title': 'Richiesta del sitter',
      'notifications_application_not_found':
          'Questa richiesta non e piu disponibile o non e stata caricata.',
      'notifications_open_sitter_profile': 'Vedi profilo sitter',
      'notifications_loading': 'Caricamento notifiche…',
      'notifications_loading_more': 'Caricamento altre…',
      'post_action_delete': 'Elimina',
      'post_request_default': 'Cerco un pet sitter',

      'sign_up_as_pet_owner': 'Registrati come proprietario',
      'sign_up_as_pet_sitter': 'Registrati come pet sitter',
      'label_name': 'Nome',
      'hint_name': 'Inserisci il tuo nome',
      'label_email': 'Email',
      'hint_email': 'Inserisci la tua email',
      'label_mobile_number': 'Numero di cellulare',
      'hint_phone': 'Inserisci il tuo numero di telefono',
      'profile_no_phone_added': 'Nessun numero aggiunto',
      'profile_no_email_added': 'Nessuna email aggiunta',
      'label_password': 'Password',
      'hint_password': 'Crea una password',
      'password_requirement':
          'Almeno 8 caratteri con lettere maiuscole, minuscole e un numero.',
      'label_language': 'Lingua',
      'hint_language': 'Indica le lingue che parli',
      'label_address': 'Indirizzo',
      'hint_address': 'Posizione',
      'label_rate_per_hour': 'Tariffa oraria',
      'hint_rate_per_hour': 'es. 20',
      'price_per_hour': 'Prezzo / ora',
      'price_per_day': 'Prezzo / giorno',
      'price_per_week': 'Prezzo / settimana',
      'price_per_month': 'Prezzo / mese',
      'chat_payment_required_banner': 'La chat si apre dopo la conferma del pagamento.',
      'chat_pay_now_button': 'Paga ora',
      'chat_share_phone_button': 'Condividi il mio numero',
      'terms_read_button': 'Leggi i Termini e Condizioni',
      'service_prefs_at_owner_label': 'Accetto il servizio a casa mia',
      'service_prefs_at_sitter_label': 'Accetto il servizio a casa del sitter',
      'service_location_label': 'Dove deve svolgersi il servizio?',
      'service_location_at_owner': 'A casa mia',
      'service_location_at_sitter': 'A casa del sitter',
      'service_location_both': 'Entrambi',
      'profile_my_availability': 'Il mio calendario di disponibilità',
      'profile_verify_identity': 'Verifica la mia identità',
      'profile_identity_verified': 'Identità verificata',
      'theme_setting_title': 'Tema',
      'theme_light': 'Chiaro',
      'theme_dark': 'Scuro',
      'theme_system': 'Segui il sistema',
      'common_close': 'Chiudi',
      'label_skills': 'Competenze',
      'hint_skills': 'Veterinario, Educatore',
      'label_bio': 'Biografia',
      'hint_bio': 'Parlaci di te',
      'label_terms_prefix': 'Accetto i ',
      'label_terms_title': 'Termini e l’Informativa sulla privacy.',
      'or_sign_up_with': 'Oppure registrati con',
      'button_google': 'Google',
      'button_apple': 'Apple',
      'button_create_account': 'Crea account',
      'button_creating_account': 'Creazione account…',
      'button_logout': 'Esci',
      'title_login': 'Accedi',
      'welcome_back': 'Bentornato 👋',
      'login_subtitle': 'Accedi per continuare su Hopetsit.',
      'hint_password_login': 'Inserisci la tua password',
      'forgot_password': 'Password dimenticata?',
      'forgot_password_reset_title': 'Reimposta la tua password',
      'forgot_password_reset_message':
          'Inserisci il tuo indirizzo email e ti invieremo un codice per reimpostare la tua password.',
      'forgot_password_email_label': 'Indirizzo email',
      'forgot_password_sending_code': 'Invio codice...',
      'forgot_password_send_code': 'Invia codice di verifica',
      'forgot_password_remember': 'Ricordi la tua password? ',
      'forgot_password_otp_sent_title': 'Codice Inviato',
      'forgot_password_otp_sent_message':
          'Il codice di verifica è stato inviato alla tua email',
      'forgot_password_request_failed': 'Richiesta Fallita',
      'forgot_password_verified_title': 'Verificato',
      'forgot_password_verified_message':
          'Ora puoi reimpostare la tua password',
      'forgot_password_verification_failed': 'Verifica Fallita',
      'forgot_password_reset_success':
          'La tua password è stata reimpostata con successo',
      'forgot_password_reset_failed': 'Reimpostazione Fallita',
      'forgot_password_code_resent_title': 'Codice Reinviato',
      'forgot_password_code_resent_message':
          'Il codice di verifica è stato reinviato alla tua email',
      'forgot_password_resend_failed': 'Reinvio Fallito',
      'forgot_password_verify_code_title': 'Verifica codice',
      'forgot_password_enter_code_title': 'Inserisci il codice di verifica',
      'forgot_password_code_sent_to':
          'Abbiamo inviato un codice a 6 cifre a @email',
      'forgot_password_verifying': 'Verifica in corso...',
      'forgot_password_resend_in': 'Invia di nuovo il codice tra @seconds s',
      'forgot_password_resend_code': 'Invia di nuovo il codice',
      'forgot_password_wrong_email': 'Email sbagliata? ',
      'forgot_password_change_email': 'Cambiala',
      'forgot_password_create_new_title': 'Crea nuova password',
      'forgot_password_set_new_title': 'Imposta la tua nuova password',
      'forgot_password_set_new_message':
          'Crea una password sicura per proteggere il tuo account. Assicurati che abbia almeno 8 caratteri.',
      'forgot_password_new_hint': 'Inserisci la nuova password',
      'forgot_password_confirm_hint': 'Reinserisci la tua password',
      'forgot_password_resetting': 'Reimpostazione password in corso...',
      'forgot_password_reset_button': 'Reimposta password',
      'forgot_password_reset_success_title':
          'Password reimpostata con successo!',
      'forgot_password_reset_success_message':
          'La tua password è stata reimpostata con successo. Ora puoi accedere con la tua nuova password.',
      'forgot_password_email_verified_title': 'Email verificata',
      'forgot_password_email_verified_subtitle':
          'La tua email è stata verificata',
      'forgot_password_password_updated_title': 'Password aggiornata',
      'forgot_password_password_updated_subtitle':
          'La tua password è stata modificata',
      'forgot_password_login_new_password': 'Accedi con la nuova password',
      'forgot_password_security_warning':
          'Se non hai richiesto questa modifica, proteggi immediatamente il tuo account.',
      'logging_in': 'Accesso in corso...',
      'or_continue_with': 'Oppure continua con',
      'dont_have_account': 'Non hai un account? ',
      'sign_up': 'Registrati',
      // Onboarding screen
      'onboarding_app_title': 'Home Pets Sitting',
      'onboarding_continue_with_google': 'Continua con Google',
      'onboarding_continue_with_apple': 'Continua con Apple',
      'onboarding_have_account': 'Hai un account?',

      'error_invalid_details_title': 'Dati non validi',
      'error_invalid_details_message':
          'Correggi i campi evidenziati e riprova.',
      'error_terms_required_title': 'Termini richiesti',
      'error_terms_required_message': 'Accetta i Termini e le Condizioni.',
      'error_name_required': 'Inserisci il tuo nome',
      'error_name_length': 'Il nome deve contenere almeno 2 caratteri',
      'error_email_required': 'Inserisci la tua email',
      'error_email_invalid': 'Inserisci un’email valida',
      'error_phone_invalid': 'Inserisci un numero di telefono valido',
      'error_phone_required': 'Inserisci il tuo numero di telefono',
      'error_password_required': 'Inserisci una password',
      'error_password_length': 'La password deve contenere almeno 8 caratteri',
      'error_password_uppercase':
          'La password deve contenere almeno una lettera maiuscola',
      'error_password_lowercase':
          'La password deve contenere almeno una lettera minuscola',
      'error_password_number': 'La password deve contenere almeno un numero',
      'error_password_confirm_required': 'Conferma la tua password',
      'error_password_match': 'Le password non corrispondono',
      'error_otp_required': 'Il codice OTP è obbligatorio',
      'error_otp_length': 'Il codice OTP deve essere di 6 cifre',
      'error_otp_numbers_only': 'Il codice OTP deve contenere solo numeri',
      'common_error_generic': 'Qualcosa è andato storto. Riprova.',
      'error_address_required': 'Inserisci il tuo indirizzo',
      'error_address_length': 'L’indirizzo deve contenere almeno 2 caratteri',
      'error_rate_required': 'Inserisci la tua tariffa oraria',
      'error_rate_invalid': 'Inserisci una tariffa valida',
      'error_rate_zero': 'La tariffa oraria non può essere 0',
      'error_skills_required': 'Inserisci le tue competenze',
      'error_skills_length':
          'Le competenze devono contenere almeno 2 caratteri',

      'location_found_title': 'Posizione trovata',
      'location_found_message': 'La tua città (@city) è stata rilevata',
      'location_not_found_title': 'Posizione non trovata',
      'location_not_found_message':
          'Impossibile rilevare la tua posizione. Abilita i servizi di localizzazione.',
      'location_error_title': 'Errore',
      'location_error_message':
          'Impossibile ottenere la tua posizione. Riprova.',
      // Location picker
      'label_city': 'Città',
      'location_getting': 'Recupero...',
      'location_auto': 'Auto',
      'location_map': 'Mappa',
      'location_detected': 'Rilevato: @city',
      'location_enter_city': 'Inserisci la tua città',
      'error_city_required': 'Inserisci la tua città',
      'location_detected_message':
          'La tua posizione è stata rilevata. Sarai collegato con fornitori di servizi in questa zona.',
      'location_select_title': 'Seleziona Posizione',
      'location_selected': 'Posizione Selezionata',
      'location_selected_city': 'Città Selezionata',
      'location_no_city': 'Nessuna città selezionata',
      'location_latitude': 'Latitudine: @value',
      'location_longitude': 'Longitudine: @value',
      'location_current': 'Attuale',
      'location_confirm': 'Conferma',
      'location_select_error': 'Seleziona una posizione',
      'location_get_error': 'Impossibile ottenere la tua posizione',

      'signup_account_created_title': 'Account creato',
      'signup_account_created_message': 'Verifica la tua email per continuare.',
      'signup_failed_title': 'Registrazione non riuscita',
      'signup_failed_generic_message': 'Si è verificato un errore. Riprova.',

      'language_dialog_title': 'Scegli la lingua',
      'language_dialog_message': 'Seleziona la lingua preferita per l’app.',
      'language_updated_title': 'Lingua aggiornata',
      'language_updated_message': 'La lingua dell’app è stata modificata.',
      'title_profile': 'Profilo',
      'edit_profile_title': 'Modifica profilo',
      'edit_profile_button': 'Aggiorna profilo',
      'edit_profile_button_updating': 'Aggiornamento del profilo in corso...',
      'service_selection_required': 'Selezione richiesta',
      'service_updated': 'Servizio aggiornato',
      'service_selected': 'Servizi selezionati',
      'edit_profile_update_success': 'Profilo aggiornato con successo!',
      'edit_profile_picture_update_success':
          'Foto del profilo aggiornata con successo!',
      // Choose service screen
      'choose_service_title': 'Scegli un servizio',
      'choose_service_choose_all': 'Seleziona tutto',
      'choose_service_saving': 'Salvataggio in corso...',
      'choose_service_selecting': 'Selezione in corso...',
      'choose_service_save': 'Salva',
      'choose_service_continue': 'Continua',
      'choose_service_card_pet_sitting_title': 'Pet sitting',
      'choose_service_card_house_sitting_title': 'House sitting',
      'choose_service_card_day_care_title': 'Asilo diurno',
      'choose_service_card_dog_walking_title': 'Passeggiata con il cane',
      'choose_service_card_subtitle_at_owners_home': 'A casa del proprietario',
      'choose_service_card_subtitle_in_your_home': 'A casa tua',
      'choose_service_card_subtitle_in_neighborhood': 'Nel tuo quartiere',
      'section_settings': 'Impostazioni',
      'role_pet_owner': 'Proprietario',
      'role_pet_sitter': 'Pet sitter',
      'auth_role_pet_owner': 'Proprietario',
      'auth_role_pet_sitter': 'Pet sitter',
      'profile_add_tasks': 'Aggiungi attività',
      'profile_view_tasks': 'Vedi attività',
      'profile_bookings_history': 'Cronologia prenotazioni',
      'profile_edit_profile': 'Modifica profilo',
      'profile_edit_pets_profile': 'Modifica profilo animali',
      'profile_choose_service': 'Scegli servizio',
      'profile_change_password': 'Cambia password',
      'profile_change_language': 'Cambia lingua',
      'profile_blocked_users': 'Utenti bloccati',
      'profile_delete_account': 'Elimina account',
      'profile_donate_us': 'Fai una donazione',
      'blocked_users_title': 'Utenti bloccati',
      'blocked_users_empty_title': 'Nessun utente bloccato',
      'blocked_users_empty_message':
          'Gli utenti che blocchi verranno mostrati qui',
      'blocked_users_unblock_button': 'Sblocca',
      'blocked_users_unblock_dialog_message':
          'Sei sicuro di voler sbloccare @name?',
      'delete_account_dialog_message':
          'Sei sicuro di voler eliminare il tuo account? Questa azione non può essere annullata.',
      'delete_account_success_title': 'Account eliminato',
      'delete_account_success_message':
          'Il tuo account è stato eliminato con successo',
      'delete_account_failed_title': 'Eliminazione non riuscita',
      'delete_account_failed_generic': 'Qualcosa è andato storto. Riprova.',
      'logout_dialog_message': 'Sei sicuro di voler uscire?',
      'profile_switch_role_card_title': 'Passa a @role',
      'profile_switch_role_card_description':
          'Passa il tuo account a @role per iniziare a ricevere richieste.',
      'dialog_switch_role_title': 'Cambia ruolo',
      'dialog_switch_role_switching':
          'Passaggio a @role...\n\nAttendere prego.',
      'dialog_switch_role_confirm':
          'Sei sicuro di voler passare a @role?\n\nPotrai tornare indietro in qualsiasi momento.',
      'dialog_switch_role_button': 'Passa a @role',
      'profile_switch_to_sitter': 'Passa a Pet Sitter',
      'profile_switch_to_owner': 'Passa a Proprietario di Animali',
      'profile_switch_to_sitter_description':
          'Passa il tuo account a Pet Sitter per iniziare a ricevere richieste.',
      'profile_switch_to_owner_description':
          'Passa il tuo account a Proprietario di Animali per iniziare a ricevere richieste.',
      'profile_switch_role_dialog_title': 'Cambia ruolo',
      'profile_switch_to_sitter_loading':
          'Passaggio a Pet Sitter...\n\nAttendere prego.',
      'profile_switch_to_owner_loading':
          'Passaggio a Proprietario di Animali...\n\nAttendere prego.',
      'profile_switch_to_sitter_confirm':
          'Sei sicuro di voler passare a Pet Sitter?\n\nPotrai tornare indietro in qualsiasi momento.',
      'profile_switch_to_owner_confirm':
          'Sei sicuro di voler passare a Proprietario di Animali?\n\nPotrai tornare indietro in qualsiasi momento.',
      'common_continue': 'Continua',
      'common_cancelled': 'Annullato',
      'common_coming_soon': 'Prossimamente',
      'common_go_to_home': 'Vai alla home',
      'common_back_to_home': 'Torna alla home',
      'error_login_required': 'Effettua nuovamente l\'accesso',
      'error_email_not_found':
          'Email utente non trovata. Effettua nuovamente l\'accesso.',
      'profile_load_error': 'Impossibile caricare il profilo',
      'blocked_users_unblock_success': 'Utente sbloccato con successo',
      'blocked_users_save_success': 'Utenti bloccati salvati con successo',
      'donate_coming_soon': 'La funzione di donazione sarà disponibile a breve',
      'stripe_connect_title': 'Collega account Stripe',
      'payout_status_screen_title': 'Stato pagamenti',
      'payout_connect_stripe_account': 'Collega account Stripe',
      'payout_paypal_email_title': 'Email pagamenti PayPal',
      'payout_add_paypal_email_title': 'Aggiungi email pagamenti PayPal',
      'payout_add_paypal_email_subtitle':
          'Imposta l\'email su cui ricevere i pagamenti. Potrai aggiornarla piu tardi dallo stato pagamenti.',
      'payout_status_saved': 'Salvato',
      'payout_status_not_set': 'Non impostato',
      'payout_paypal_email_hint':
          'Aggiungi un\'email per ricevere pagamenti tramite PayPal.',
      'payout_update_paypal_email': 'Aggiorna email PayPal',
      'payout_paypal_dialog_subtitle':
          'Questa email verra usata per i pagamenti PayPal. Assicurati che corrisponda al tuo account PayPal.',
      'payout_stripe_connect_title': 'Stripe Connect',
      'payout_status_connected': 'Connesso',
      'payout_status_not_connected': 'Non connesso',
      'payout_stripe_connected_message':
          'Il tuo account Stripe e connesso e pronto a ricevere pagamenti.',
      'payout_stripe_not_connected_message':
          'Collega il tuo account Stripe per iniziare a ricevere pagamenti.',
      'payout_account_id_label': 'ID account',
      'payout_verification_title': 'Stato verifica',
      'payout_status_title': 'Stato pagamenti',
      'payout_verification_step_identity': 'Verifica identita',
      'payout_verification_step_bank': 'Verifica conto bancario',
      'payout_verification_step_business': 'Informazioni aziendali',
      'payout_next_payout_label': 'Prossimo pagamento',
      'payout_schedule_label': 'Frequenza pagamenti',
      'payout_schedule_daily': 'Giornaliero',
      'payout_minimum_amount_label': 'Importo minimo',
      'payout_status_verified': 'Verificato',
      'payout_status_pending': 'In attesa',
      'payout_status_rejected': 'Rifiutato',
      'payout_status_not_started': 'Non iniziato',
      'payout_status_active': 'Attivo',
      'payout_status_restricted': 'Limitato',
      'payout_verification_message_verified':
          'Il tuo account e stato verificato. Ora puoi ricevere pagamenti.',
      'payout_verification_message_pending':
          'La tua verifica e in revisione. Di solito richiede 1-2 giorni lavorativi.',
      'payout_verification_message_rejected':
          'La tua verifica e stata rifiutata. Aggiorna le informazioni e riprova.',
      'payout_verification_message_not_started':
          'Completa la verifica per iniziare a ricevere pagamenti.',
      'payout_message_active':
          'I tuoi pagamenti sono attivi. I guadagni verranno trasferiti quotidianamente sul tuo conto bancario.',
      'payout_message_pending':
          'Il tuo account pagamenti e in configurazione. Potrebbero volerci alcuni giorni lavorativi.',
      'payout_message_restricted':
          'I tuoi pagamenti sono attualmente limitati. Contatta il supporto.',
      'payout_message_not_connected':
          'Collega il tuo account Stripe per iniziare a ricevere pagamenti.',
      'stripe_get_paid_title': 'Ricevi pagamenti con Stripe',
      'stripe_connect_description':
          'Collega il tuo account Stripe per ricevere pagamenti direttamente dai proprietari di animali. I tuoi guadagni verranno trasferiti sul tuo conto bancario.',
      'stripe_account_status_title': 'Stato account',
      'stripe_continue_onboarding': 'Continua onboarding',
      'stripe_connect_account_button': 'Collega account Stripe',
      'stripe_benefit_secure': 'Elaborazione pagamenti sicura',
      'stripe_benefit_fast_payouts': 'Pagamenti rapidi sul tuo conto bancario',
      'stripe_benefit_no_fees': 'Nessuna commissione di configurazione',
      'stripe_benefit_support': 'Supporto clienti 24/7',
      'stripe_benefit_required':
          'Richiesto per ricevere pagamenti dai proprietari di animali',
      'stripe_account_connected': 'Account collegato',
      'stripe_account_created_pending':
          'Account creato - Onboarding in sospeso',
      'stripe_account_created': 'Account creato',
      'stripe_account_connected_message':
          'Il tuo account Stripe è completamente configurato e pronto per ricevere pagamenti.',
      'stripe_account_created_message':
          'Il tuo account Stripe è stato creato. Completa il processo di onboarding per iniziare a ricevere pagamenti.',
      'stripe_account_created_partial_message':
          'Il tuo account di pagamento è stato creato. Alcuni passaggi di verifica sono ancora in sospeso. Puoi completarli nelle impostazioni dell\'account.',
      'stripe_account_id_label': 'ID account',
      'stripe_loading_onboarding': 'Caricamento onboarding Stripe...',
      'stripe_account_connected_success':
          'Account Stripe collegato con successo!',
      'stripe_onboarding_completed': 'Onboarding Stripe completato!',
      'stripe_onboarding_cancelled': 'L\'onboarding Stripe è stato annullato.',
      'stripe_onboarding_load_error':
          'Impossibile caricare la pagina di onboarding Stripe: @error',
      'stripe_cancel_onboarding_title': 'Annullare onboarding?',
      'stripe_cancel_onboarding_message':
          'Sei sicuro di voler annullare l\'onboarding Stripe? Puoi completarlo più tardi dalle impostazioni.',
      'stripe_connect_payment_title': 'Collega il tuo account di pagamento',
      'stripe_connect_payment_description':
          'Per iniziare a ricevere pagamenti come Pet Sitter, devi collegare il tuo account di pagamento. Questo è un passaggio richiesto per completare la configurazione del tuo profilo.',
      'stripe_connect_payment_partial_description':
          'Il tuo account di pagamento è stato creato. Alcuni passaggi di verifica sono ancora in sospeso. Puoi completarli più tardi nelle impostazioni dell\'account.',
      'stripe_connect_payment_partial_info':
          'Il tuo account è collegato, ma alcuni passaggi di verifica sono ancora in sospeso. Puoi completarli nelle impostazioni dell\'account.',
      'stripe_payment_connected_success': 'Pagamento collegato con successo!',
      'stripe_connect_now': 'Collega ora',
      'stripe_already_connected': 'Già collegato',
      'stripe_already_connected_message':
          'Il tuo account Stripe è già collegato e attivo.',
      'stripe_connect_error':
          'Impossibile collegare l\'account Stripe. Riprova.',
      'stripe_no_onboarding_url':
          'Nessuna URL di onboarding disponibile. Crea prima un account Stripe.',
      'stripe_onboarding_expired_title': 'Scaduto',
      'stripe_onboarding_expired_message':
          'Il link di onboarding è scaduto. Crea un nuovo link.',
      'stripe_disconnect_success': 'Account Stripe disconnesso con successo!',
      'stripe_disconnect_error':
          'Impossibile disconnettere l\'account Stripe. Riprova.',
      'payment_title': 'Pagamento',
      'payment_info_message':
          'Clicca su "Paga" qui sotto per inserire in modo sicuro i tuoi dati di pagamento utilizzando il modulo di pagamento sicuro di Stripe.',
      'payment_paypal_info':
          'Verrai reindirizzato a PayPal per approvare il pagamento, poi lo confermeremo qui.',
      'payment_pay_with_stripe': 'Paga con Stripe @amount',
      'payment_pay_with_paypal': 'Paga con PayPal @amount',
      'booking_agreement_title': 'Accordo di prenotazione',
      'booking_agreement_payment_completed': 'Pagamento completato',
      'booking_agreement_booking_cancelled': 'Prenotazione annullata',
      'booking_agreement_status_label': 'Stato: @status',
      'booking_agreement_start_date_label': 'Data di inizio',
      'booking_agreement_end_date_label': 'Data di fine',
      'booking_agreement_time_slot_label': 'Fascia oraria',
      'booking_agreement_service_provider_label': 'Fornitore del servizio',
      'booking_agreement_service_type_label': 'Tipo di servizio',
      'booking_agreement_special_instructions_label': 'Istruzioni speciali',
      'booking_agreement_cancelled_at_label': 'Annullato il',
      'booking_agreement_cancellation_reason_label':
          'Motivo dell\'annullamento',
      'booking_agreement_price_breakdown_title': 'Riepilogo costi',
      'booking_agreement_pricing_tier_label': 'Fascia di prezzo',
      'booking_agreement_total_hours_label': 'Ore totali',
      'booking_agreement_total_days_label': 'Giorni totali',
      'booking_agreement_base_price_label': 'Prezzo base',
      'booking_agreement_platform_fee_label': 'Commissione piattaforma',
      'booking_agreement_net_amount_label': 'Importo netto (al pet sitter)',
      'booking_agreement_today_at': 'Oggi alle @time',
      'booking_agreement_yesterday_at': 'Ieri alle @time',
      'booking_agreement_at': 'alle',
      'payment_method_paypal': 'PayPal',
      'payment_pay_button': 'Paga @amount',
      'payment_amount_label': 'Importo da pagare',
      'payment_loading_page': 'Caricamento pagina di pagamento...',
      'payment_cancel_title': 'Annullare pagamento?',
      'payment_cancel_message':
          'Sei sicuro di voler annullare questo pagamento?',
      'payment_continue': 'Continua pagamento',
      'payment_load_error':
          'Impossibile caricare la pagina di pagamento: @error',
      'payment_success_title': 'Pagamento riuscito!',
      'payment_failed_title': 'Pagamento fallito',
      'payment_success_message':
          'Il tuo pagamento è stato elaborato con successo.',
      'payment_rate_sitter': 'Valuta il pet sitter',
      'payment_try_again': 'Riprova',
      'payment_transaction_details': 'Dettagli transazione',
      'payment_transaction_id_label': 'ID transazione',
      'payment_date_label': 'Data',
      'payment_error_client_secret_missing':
          'Impossibile creare l\'intento di pagamento. Manca il segreto del client.',
      'payment_error_publishable_key_missing':
          'Chiave pubblicabile Stripe mancante.',
      'payment_error_invalid_publishable_key':
          'Chiave pubblicabile Stripe non valida.',
      'payment_processing_failed': 'Elaborazione pagamento fallita. Riprova.',
      'payment_error_title': 'Errore di pagamento',
      'payment_unavailable_title': 'Pagamento non disponibile',
      'payment_unavailable_message':
          'L\'account Stripe del pet sitter non è ancora completamente verificato. Deve completare la verifica dell\'account (inclusi identità, conto bancario e dettagli aziendali) prima di poter ricevere pagamenti. Contatta il pet sitter per completare la configurazione del suo account Stripe.',
      'payment_invalid_amount_title': 'Importo non valido',
      'payment_invalid_amount_message':
          'L\'importo del pagamento non è valido. Contatta il supporto.',
      'payment_initiate_error': 'Impossibile avviare il pagamento. Riprova.',
      'payment_confirmation_failed':
          'Conferma pagamento fallita. Contatta il supporto.',
      'review_already_reviewed_title': 'Già recensito',
      'review_already_reviewed_message':
          'Hai già recensito questo pet sitter. Puoi inviare solo una recensione per pet sitter.',
      'sitter_applications_tab': 'Candidature',
      'sitter_no_bookings_found': 'Nessuna prenotazione trovata',
      'sitter_application_accepted_success':
          'Candidatura accettata con successo',
      'sitter_application_accept_failed':
          'Errore nell\'accettazione della candidatura. Riprova.',
      'sitter_application_rejected_success':
          'Candidatura rifiutata con successo',
      'sitter_application_reject_failed':
          'Errore nel rifiuto della candidatura. Riprova.',
      'sitter_chat_start_failed':
          'Errore nell\'avvio della conversazione. Riprova.',
      'sitter_chat_with_owner': 'Chatta con il proprietario',
      'sitter_pet_weight': 'Peso',
      'sitter_pet_height': 'Altezza',
      'sitter_pet_color': 'Colore',
      'sitter_not_yet_available': 'Non ancora disponibile',
      'sitter_detail_date': 'Data',
      'sitter_detail_time': 'Ora',
      'sitter_detail_phone': 'Telefono',
      'sitter_detail_email': 'Email',
      'sitter_detail_location': 'Posizione',
      'sitter_not_available_yet': 'Non ancora disponibile',
      'sitter_reject': 'Rifiuta',
      'sitter_accept': 'Accetta',
      'sitter_status_label': 'Stato: @status',
      'sitter_payment_status_label': 'Pagamento: @status',
      'sitter_time_just_now': 'Proprio ora',
      'sitter_time_mins_ago': '@minutes min fa',
      'sitter_time_hours_ago': '@hours ore fa',
      'sitter_time_days_ago': '@days giorni fa',
      'sitter_weekday_mon': 'Lun',
      'sitter_weekday_tue': 'Mar',
      'sitter_weekday_wed': 'Mer',
      'sitter_weekday_thu': 'Gio',
      'sitter_weekday_fri': 'Ven',
      'sitter_weekday_sat': 'Sab',
      'sitter_weekday_sun': 'Dom',
      'sitter_month_jan': 'Gen',
      'sitter_month_feb': 'Feb',
      'sitter_month_mar': 'Mar',
      'sitter_month_apr': 'Apr',
      'sitter_month_may': 'Mag',
      'sitter_month_jun': 'Giu',
      'sitter_month_jul': 'Lug',
      'sitter_month_aug': 'Ago',
      'sitter_month_sep': 'Set',
      'sitter_month_oct': 'Ott',
      'sitter_month_nov': 'Nov',
      'sitter_month_dec': 'Dic',
      'sitter_service_long_term_care': 'Cura a lungo termine',
      'sitter_service_dog_walking': 'Passeggiata con il cane',
      'sitter_service_overnight_stay': 'Pernottamento',
      'sitter_service_home_visit': 'Visita a domicilio',
      'sitter_request_details_title': 'Dettagli della richiesta',
      'sitter_requests_section': 'Richieste',
      'sitter_info_pets': 'Animali',
      'sitter_no_pets': 'Nessun animale',
      'sitter_info_service': 'Servizio',
      'sitter_no_service_type': 'Nessun tipo di servizio disponibile',
      'sitter_info_date': 'Data',
      'sitter_no_date_available': 'Nessuna data disponibile',
      'sitter_pets_section': 'Animali',
      'sitter_note_section': 'Nota',
      'sitter_no_note_provided': 'Nessuna nota fornita.',
      'sitter_decline': 'Rifiuta',
      'owner_booking_details_title': 'Dettagli della prenotazione',
      'owner_service_provider_section': 'Fornitore di servizi',
      'owner_info_pets': 'Animali',
      'owner_no_pets': 'Nessun animale',
      'owner_info_service': 'Servizio',
      'owner_no_service_type': 'Nessun tipo di servizio disponibile',
      'owner_info_date': 'Data',
      'owner_no_date_available': 'Nessuna data disponibile',
      'owner_info_total_amount': 'Importo totale',
      'owner_pets_section': 'Animali',
      'owner_note_section': 'Nota',
      'owner_no_note_provided': 'Nessuna nota fornita.',
      'owner_chat_with_sitter': 'Chatta con il pet sitter',
      'owner_pay_now': 'Paga ora',
      'owner_pay_with_amount': 'Paga \$@amount',
      'owner_cancel_booking': 'Annulla prenotazione',
      'owner_time_just_now': 'Proprio ora',
      'owner_time_mins_ago': '@minutes min fa',
      'owner_time_hours_ago': '@hours ore fa',
      'owner_time_days_ago': '@days giorni fa',
      'owner_weekday_mon': 'Lun',
      'owner_weekday_tue': 'Mar',
      'owner_weekday_wed': 'Mer',
      'owner_weekday_thu': 'Gio',
      'owner_weekday_fri': 'Ven',
      'owner_weekday_sat': 'Sab',
      'owner_weekday_sun': 'Dom',
      'owner_month_jan': 'Gen',
      'owner_month_feb': 'Feb',
      'owner_month_mar': 'Mar',
      'owner_month_apr': 'Apr',
      'owner_month_may': 'Mag',
      'owner_month_jun': 'Giu',
      'owner_month_jul': 'Lug',
      'owner_month_aug': 'Ago',
      'owner_month_sep': 'Set',
      'owner_month_oct': 'Ott',
      'owner_month_nov': 'Nov',
      'owner_month_dec': 'Dic',
      'owner_service_long_term_care': 'Cura a lungo termine',
      'owner_service_dog_walking': 'Passeggiata con il cane',
      'owner_service_overnight_stay': 'Pernottamento',
      'owner_service_home_visit': 'Visita a domicilio',
      'owner_rating_with_reviews': '@rating (@count recensioni)',
      'owner_pet_needs_medication': 'Necessita farmaci / @medication',
      // Home screen & applications
      'home_default_user_name': 'Utente',
      'home_no_sitters_message': 'Nessun pet sitter disponibile al momento.',
      'home_block_sitter_message':
          'Sei sicuro di voler bloccare @name? Non potrai più vedere il suo profilo o inviare richieste.',
      'home_block_sitter_yes': 'Annulla',
      'home_block_sitter_no': 'Blocca',
      'status_available': 'disponibile',
      'applications_tab_title': 'Candidature',
      'bookings_tab_title': 'Prenotazioni',
      'applications_empty_message': 'Nessuna candidatura trovata',
      'bookings_empty_message': 'Nessuna prenotazione trovata',
      'booking_cancel_dialog_message':
          'Sei sicuro di voler annullare questa prenotazione?',
      // Expandable post input
      'post_input_label': 'Post',
      'post_input_hint': 'Scrivi qui il tuo post...',
      'post_button': 'Pubblica',
      'post_button_posting': 'Pubblicazione in corso...',
      // Common UI
      'common_select': 'Seleziona',
      'common_save': 'Salva',
      'common_later': 'Piu tardi',
      'common_saving': 'Salvataggio in corso...',
      // Tasks screens
      'view_task_title': 'Visualizza attività',
      'view_task_empty': 'Nessuna attività trovata',
      'view_task_date_not_available': 'Data non disponibile',
      'add_task_title': 'Aggiungi attività',
      'add_task_title_label': 'Titolo',
      'add_task_title_hint': 'Inserisci il titolo',
      'add_task_description_label': 'Descrizione',
      'add_task_description_hint': 'Testo...',
      'add_task_save_button': 'Salva',
      'add_task_saving': 'Salvataggio in corso...',
      // Change password
      'change_password_title': 'Cambia password',
      'change_password_new_label': 'Nuova password',
      'change_password_confirm_label': 'Conferma password',
      'change_password_confirm_hint': 'Conferma la password',
      // Add card
      'add_card_title': 'Aggiungi carta',
      'add_card_holder_label': 'Nome del titolare',
      'add_card_holder_hint': 'Mario Rossi',
      'add_card_number_label': 'Numero di carta',
      'add_card_number_hint': '0987 0986 5543 0980',
      'add_card_exp_label': 'Data di scadenza',
      'add_card_exp_hint': '10/23',
      'add_card_cvc_label': 'CVC',
      'add_card_cvc_hint': '345',
      // My pets
      'my_pets_title': 'I miei animali',
      'my_pets_add_pet': 'Aggiungi animale',
      'my_pets_error_loading': 'Errore nel caricamento degli animali',
      'my_pets_retry': 'Riprova',
      'my_pets_empty': 'Nessun animale trovato',
      'my_pets_color_label': 'Colore',
      'my_pets_profile_label': 'Profilo',
      'my_pets_passport_label': 'Passaporto',
      'my_pets_chip_label': 'Microchip',
      'my_pets_allergies_label': 'Allergie',
      // Create pet profile
      'create_pet_appbar_title': 'Utente',
      'create_pet_skip': 'Salta',
      'create_pet_header': 'Crea un profilo per il tuo animale',
      'create_pet_name_label': 'Nome dell’animale',
      'create_pet_name_hint': 'Inserisci il nome del tuo animale',
      'create_pet_breed_label': 'Razza',
      'create_pet_breed_hint': 'Inserisci la razza',
      'create_pet_dob_label': 'Data di nascita',
      'create_pet_dob_hint':
          'Inserisci la data di nascita del tuo animale domestico',
      'create_pet_weight_label': 'Peso (KG)',
      'create_pet_weight_hint': 'es. 12 kg',
      'create_pet_height_label': 'Altezza (CM)',
      'create_pet_height_hint': 'es. 50 cm',
      'create_pet_passport_label': 'Numero di passaporto',
      'create_pet_passport_hint': 'Inserisci il numero di passaporto',
      'create_pet_chip_label': 'Numero di microchip',
      'create_pet_chip_hint': 'Inserisci il numero di microchip',
      'create_pet_med_allergies_label': 'Allergie ai farmaci',
      'create_pet_med_allergies_hint': 'Inserisci le allergie ai farmaci',
      'create_pet_category_label': 'Categoria',
      'create_pet_category_dog': 'Cane',
      'create_pet_category_cat': 'Gatto',
      'create_pet_category_bird': 'Uccello',
      'create_pet_category_rabbit': 'Coniglio',
      'create_pet_category_other': 'Altro',
      'create_pet_vaccination_label': 'Vaccinazioni',
      'create_pet_vaccination_up_to_date': 'Aggiornate',
      'create_pet_vaccination_not_vaccinated': 'Non vaccinato',
      'create_pet_vaccination_partial': 'Parzialmente vaccinato',
      'create_pet_profile_view_label': 'Visibilità del profilo',
      'create_pet_profile_view_public': 'Pubblico',
      'create_pet_profile_view_private': 'Privato',
      'create_pet_profile_view_friends': 'Solo amici',
      'create_pet_upload_media_label': 'Carica foto e video del tuo animale',
      'create_pet_upload_media_upload': 'Carica',
      'create_pet_upload_media_change': 'Modifica (@count)',
      'create_pet_upload_media_selected': '@count file selezionato/i',
      'create_pet_upload_passport_label':
          'Carica la foto del passaporto del tuo animale',
      'create_pet_upload_passport_change': 'Modifica',
      'create_pet_upload_passport_upload': 'Carica',
      'create_pet_upload_passport_selected':
          'Immagine del passaporto selezionata',
      'create_pet_button_creating': 'Creazione del profilo...',
      'create_pet_button': 'Crea il profilo dell’animale',
      // Send request screen
      'send_request_title': 'Invia richiesta',
      'send_request_description_label': 'Descrizione',
      'send_request_description_hint': 'Inserisci dettagli aggiuntivi...',
      'label_pets': 'Animali',
      'send_request_no_pets_message':
          'Nessun animale. Aggiungi un animale per continuare.',
      'send_request_pets_select_placeholder': 'Seleziona',
      'send_request_dates_label': 'Date',
      'send_request_start_label': 'Inizio',
      'send_request_end_label': 'Fine',
      'send_request_select_date': 'Seleziona data',
      'send_request_select_time': "Seleziona l'ora",
      'send_request_service_type_label': 'Tipo di servizio',
      'send_request_service_long_term_care': 'Cura a lungo termine',
      'send_request_service_dog_walking': 'Passeggiata con il cane',
      'send_request_service_overnight_stay': 'Pernottamento',
      'send_request_service_home_visit': 'Visita a domicilio',
      'publish_request_service_walking': 'Passeggiata',
      'publish_request_service_boarding': 'Pensione',
      'publish_request_service_daycare': 'Asilo diurno',
      'publish_request_service_pet_sitting': 'Pet sitting',
      'publish_request_service_house_sitting': 'House sitting',
      'house_sitting_venue_label': 'Luogo del house sitting',
      'house_sitting_venue_owners_home': 'A casa del proprietario',
      'house_sitting_venue_sitters_home': 'A casa del pet sitter',
      'send_request_duration_label': 'Durata (minuti)',
      'send_request_duration_minutes_label': '@minutes min',
      'send_request_button': 'Invia richiesta',
      'send_request_button_sending': 'Invio in corso...',
      'send_request_validation_error_title': 'Errore di convalida',
      'send_request_invalid_time_title': 'Ora non valida',
      'send_request_invalid_time_message':
          "L'ora di fine deve essere successiva all'ora di inizio.",
      // Chat screens
      'chat_error_loading_conversations':
          'Errore durante il caricamento delle conversazioni',
      'chat_retry': 'Riprova',
      'chat_no_conversations': 'Nessuna conversazione ancora',
      'chat_error_loading_messages':
          'Errore durante il caricamento dei messaggi',
      'chat_no_messages': 'Nessun messaggio ancora. Inizia la conversazione!',
      'chat_input_hint': 'Scrivi un messaggio...',
      'chat_locked_title': 'Chat bloccata',
      'chat_locked_after_payment':
          'La chat e disponibile solo dopo il completamento del pagamento della prenotazione.',
      // Pets map screen
      'map_search_hint': 'Pet sitter nelle vicinanze',
      'map_offers_near_me': 'Offerte vicino a me',
      'map_radius_label': 'Raggio:',
      'map_distance_filter_label': 'Distanza: @km km',
      'map_no_nearby_sitters': 'Nessun pet sitter nelle vicinanze',
      'map_sitter_services_distance': '@services • @distance km',
      // Service provider detail screen
      'sitter_detail_loading_name': 'Caricamento...',
      'sitter_detail_load_error':
          'Impossibile caricare i dettagli del pet sitter',
      'sitter_detail_no_rating': 'Ancora nessuna valutazione',
      'sitter_detail_about_title': 'Informazioni su @name',
      'sitter_detail_no_bio': 'Nessuna biografia disponibile.',
      'sitter_detail_booking_details_title': 'Dettagli della prenotazione',
      'sitter_detail_availability_pricing_title': 'Disponibilità e prezzi',
      'sitter_detail_hourly_rate_label': 'Tariffa oraria',
      'sitter_detail_weekly_rate_label': 'Tariffa settimanale',
      'sitter_detail_monthly_rate_label': 'Tariffa mensile',
      'sitter_detail_current_status_label': 'Stato attuale',
      'sitter_detail_application_status_label': 'Stato della richiesta',
      'sitter_detail_skills_title': 'Competenze',
      'sitter_detail_no_skills': 'Nessuna competenza indicata.',
      'sitter_detail_reviews_title': 'Recensioni',
      'sitter_detail_no_reviews': 'Ancora nessuna recensione.',
      'sitter_detail_anonymous_reviewer': 'Anonimo',
      'sitter_detail_starting_chat': 'Avvio in corso...',
      'sitter_detail_unlock_after_payment': 'Sbloccabile dopo il pagamento',
      'sitter_detail_start_chat': 'Avvia chat',
      'sitter_detail_start_chat_failed':
          'Impossibile avviare la conversazione. Riprova.',
      'status_available_label': 'Disponibile',
      'status_cancelled_label': 'Annullata',
      'status_rejected_label': 'Rifiutata',
      'status_pending_label': 'In attesa',
      'status_agreed_label': 'Concordata',
      'status_paid_label': 'Pagata',
      'status_accepted_label': 'Accettata',
      // Pet detail screen
      'pet_detail_loading': 'Caricamento dettagli dell\'animale...',
      'pet_detail_about': 'Informazioni su @name',
      'pet_detail_weight': 'Peso',
      'pet_detail_height': 'Altezza',
      'pet_detail_color': 'Colore',
      'pet_detail_passport_number': 'Numero di passaporto',
      'pet_detail_chip_number': 'Numero di chip',
      'pet_detail_medication_allergies': 'Farmaci/Allergie',
      'pet_detail_date_of_birth': 'Data di nascita',
      'pet_detail_category': 'Categoria',
      'pet_detail_vaccinations': 'Vaccinazioni di @name',
      'pet_detail_gallery': 'Galleria di @name',
      'pet_detail_no_photos': 'Nessuna foto disponibile',
      'pet_detail_owner_information': 'Informazioni sul proprietario',
      'pet_detail_owner_name': 'Nome',
      'pet_detail_owner_created_at': 'Creato il',
      'pet_detail_owner_updated_at': 'Aggiornato il',
      'pet_detail_no_description': 'Nessuna descrizione disponibile',
      'pet_detail_gender_unknown': 'Sconosciuto',
      'pet_detail_breed_unknown': 'Sconosciuto',
      'pet_detail_no_vaccinations': 'Nessuna vaccinazione elencata',
      'pet_detail_load_error':
          'Impossibile caricare i dettagli dell\'animale. Riprova.',
      // Sitter bookings screen
      'sitter_bookings_title': 'Le mie prenotazioni',
      'sitter_bookings_empty_all': 'Nessuna prenotazione trovata',
      'sitter_bookings_empty_filtered': 'Nessuna prenotazione @status trovata',
      'sitter_bookings_pet_label': 'Animale',
      'sitter_bookings_date_label': 'Data',
      'sitter_bookings_time_label': 'Ora',
      'sitter_bookings_rate_label': 'Tariffa',
      'sitter_bookings_description_label': 'Descrizione',
      'sitter_bookings_cancel_button': 'Annulla prenotazione',
      'sitter_bookings_cancel_dialog_message':
          'Sei sicuro di voler annullare questa prenotazione?',
      'sitter_bookings_cancel_dialog_yes': 'Sì, annulla',
      'sitter_bookings_cancel_success':
          'Richiesta di annullamento inviata con successo!',
      'sitter_bookings_cancel_error':
          'Errore nell\'invio della richiesta di annullamento. Riprova.',
      // Owner bookings controller
      'bookings_cancel_success': 'Prenotazione annullata con successo!',
      'bookings_cancel_error':
          'Errore nell\'annullamento della prenotazione. Riprova.',
      'bookings_cancel_request_success':
          'Richiesta di annullamento inviata con successo!',
      'bookings_cancel_request_error':
          'Errore nell\'invio della richiesta di annullamento. Riprova.',
      'request_cancel_button': 'Annulla richiesta',
      'request_cancel_button_cancelling': 'Annullamento...',
      'request_cancel_success': 'Richiesta annullata con successo!',
      'request_cancel_error':
          'Errore nell\'annullamento della richiesta. Riprova.',
      'bookings_payment_status_error':
          'Errore nel recupero dello stato del pagamento. Riprova.',
      // Service provider card
      'service_card_no_phone': 'Nessun numero disponibile',
      'service_card_no_location': 'Nessuna posizione disponibile',
      'service_card_block': 'Blocca',
      'service_card_per_hour_label': 'All’ora @price',
      'service_card_send_request': 'Invia richiesta',
      'sitter_post_pet_details': 'Dettagli dell\'animale',
      'service_card_accept': 'Accetta',
      'service_card_reject': 'Rifiuta',
      'service_card_cancel': 'Annulla',
      'service_card_pay_with_amount': 'Paga @amount',
      'service_card_pay_now': 'Paga ora',
      'service_card_chat': 'Chat',
      // Sitter bottom sheet
      'sitter_view_profile': 'Vedi profilo',
      'sitter_rating_with_count': '@rating (@count recensioni)',
      'Email Not Verified': 'Email Not Verified',
      'Image Error': 'Image Error',
      'Invalid Hourly Rate': 'Invalid Hourly Rate',
      'Location Found': 'Location Found',
      'Location Not Found': 'Location Not Found',
      'Required': 'Required',
      'Role Switched': 'Role Switched',
      'Selection Failed': 'Selection Failed',
      'Selection Required': 'Selection Required',
      'Service Updated': 'Service Updated',
      'Services Selected': 'Services Selected',
      'Success': 'Success',
      'Switch Role Failed': 'Switch Role Failed',
      'Verification Code Sent': 'Verification Code Sent',
      'auth_apple_signin_failed': 'Accesso Apple non riuscito',
      'auth_apple_signin_failed_generic': 'Qualcosa è andato storto. Riprova.',
      'auth_apple_signin_success': 'Accesso con Apple riuscito',
      'auth_google_signin_choose_services': 'Seleziona i tuoi servizi',
      'auth_google_signin_failed': 'Accesso con Google non riuscito. Riprova.',
      'auth_google_signin_firebase_token_failed':
          'Impossibile ottenere il token Firebase ID.',
      'auth_google_signin_success': 'Accesso con Google riuscito',
      'auth_google_signin_title': 'Accesso con Google',
      'auth_google_signin_token_missing': 'Token Google ID mancante.',
      'auth_google_signin_web_required':
          'Questa piattaforma richiede l\'accesso web.',
      'auth_role_switch_failed': 'Impossibile cambiare ruolo. Riprova.',
      'auth_role_switched': 'Ruolo cambiato',
      'auth_role_switched_message': 'Passaggio riuscito a @role',
      'auth_welcome_back': 'Bentornato!',
      'change_password_failed': 'Failed to change password. Please try again.',
      'change_password_fields_required': 'Please fill in all fields correctly.',
      'change_password_new_required': 'Please enter a new password.',
      'change_password_success': 'Password changed successfully!',
      'change_password_validation_error': 'Validation Error',
      'email_verification_code_required':
          'Please enter the complete verification code',
      'email_verification_success': 'Email verified successfully!',
      'map_load_error': 'Failed to load map data. Please try again.',
      'my_pets_load_error': 'Failed to load pets. Please try again.',
      'pet_create_validation_error': 'Validation Error',
      'pet_update_failed': 'Update Failed',
      'pet_validation_error': 'Validation Error',
      'profile_blocked_users_load_error': 'Failed to load blocked users',
      'profile_edit_coming_soon':
          'Edit profile functionality will be available soon',
      'profile_image_pick_failed': 'Failed to pick image. Please try again.',
      'profile_invalid_file_type': 'Invalid File Type',
      'profile_invalid_file_type_message':
          'Please select a JPEG, PNG, or WebP image.',
      'profile_picture_update_success':
          'Foto del profilo aggiornata con successo',
      'profile_unblock_failed': 'Unblock Failed',
      'profile_unblock_failed_generic':
          'Something went wrong. Please try again.',
      'profile_unblock_success': 'User unblocked successfully',
      'profile_upload_failed': 'Upload Failed',
      'profile_upload_failed_generic':
          'Something went wrong. Please try again.',
      'profile_user_not_found': 'User not found',
      'publish_request_fill_required': 'Please fill in all required fields.',
      'publish_request_success':
          'Richiesta di prenotazione pubblicata con successo!',
      'request_duration_required':
          'Please select a duration for dog walking service.',
      'request_pet_required': 'Please select at least one pet.',
      'request_send_failed': 'Impossibile inviare la richiesta. Riprova.',
      'request_send_success': 'Richiesta inviata con successo!',
      'request_sitter_pricing_error':
          'Imposta prima la tua tariffa oraria nel profilo.',
      'request_validation_error': 'Validation Error',
      'review_submit_failed': 'Failed to submit review. Please try again.',
      'share_failed': 'Failed to share. Please try again.',
      'snackbar_choose_service_controller_001':
          'Please select valid services for your account type.',
      'snackbar_choose_service_controller_002':
          'Your services have been updated successfully!',
      'snackbar_choose_service_controller_003':
          'Your services have been selected successfully!',
      'snackbar_choose_service_controller_004':
          'Failed to update services. Please try again.',
      'snackbar_choose_service_controller_005':
          'Please select at least one service to continue.',
      'snackbar_choose_service_controller_006':
          'Please select a valid service to continue.',
      'snackbar_choose_service_controller_007':
          'Please select at least one service.',
      'snackbar_sitter_paypal_payout_controller_001':
          'L\'email PayPal per i pagamenti e obbligatoria.',
      'snackbar_sitter_paypal_payout_controller_002':
          'Email PayPal per i pagamenti aggiornata con successo!',
      'snackbar_sitter_paypal_payout_controller_003':
          'Impossibile aggiornare l\'email PayPal per i pagamenti. Riprova.',
      'task_add_failed': 'Failed to add task. Please try again.',
      'task_add_success': 'Task added successfully!',
      'task_fetch_failed': 'Failed to fetch tasks.',
      'task_fields_required': 'Please fill in at least one field.',

      'snackbar_text_application_accepted_successfully':
          'Richiesta accettata con successo',
      'snackbar_text_application_rejected_successfully':
          'Richiesta respinta con successo',
      'snackbar_text_blocked_users_saved_successfully':
          'Gli utenti bloccati sono stati salvati correttamente',
      'snackbar_text_card_saved_successfully': 'Carta salvata con successo!',
      'snackbar_text_could_not_detect_your_location_please_enable_location_servic':
          'Impossibile rilevare la tua posizione. ',
      'snackbar_text_could_not_load_nearby_sitters_please_try_again':
          'Impossibile caricare i sitter nelle vicinanze. ',
      'snackbar_text_email_not_verified': 'E-mail non verificata',
      'snackbar_text_failed_to_complete_profile_please_try_again':
          'Impossibile completare il profilo. ',
      'snackbar_text_failed_to_load_booking_details_using_default_pricing':
          'Impossibile caricare i dettagli della prenotazione. ',
      'snackbar_text_failed_to_load_pet_data_please_try_again':
          'Impossibile caricare i dati dell\'animale domestico. ',
      'snackbar_text_failed_to_load_sitter_details_please_try_again':
          'Impossibile caricare i dettagli del sitter. ',
      'snackbar_text_failed_to_pick_passport_image_please_try_again':
          'Impossibile selezionare l\'immagine del passaporto. ',
      'snackbar_text_failed_to_pick_pet_pictures_or_videos_please_try_again':
          'Impossibile selezionare foto o video degli animali domestici. ',
      'snackbar_text_failed_to_pick_pet_profile_image_please_try_again':
          'Impossibile scegliere l\'immagine del profilo dell\'animale domestico. ',
      'snackbar_text_failed_to_save_card_please_try_again':
          'Impossibile salvare la carta. ',
      'snackbar_text_failed_to_start_conversation_please_try_again':
          'Impossibile avviare la conversazione. ',
      'snackbar_text_failed_to_switch_role_please_try_again':
          'Impossibile cambiare ruolo. ',
      'snackbar_text_height_is_required': 'L\'altezza è richiesta.',
      'snackbar_text_height_must_be_greater_than_0':
          'L\'altezza deve essere maggiore di 0.',
      'snackbar_text_hourly_rate_must_be_greater_than_0':
          'La tariffa oraria deve essere maggiore di 0.',
      'snackbar_text_weekly_rate_must_be_greater_than_0':
          'La tariffa settimanale deve essere maggiore di 0.',
      'snackbar_text_monthly_rate_must_be_greater_than_0':
          'La tariffa mensile deve essere maggiore di 0.',
      'snackbar_text_invalid_url': 'URL non valida',
      'snackbar_text_unknown_error': 'Errore sconosciuto',
      'snackbar_text_image_error': 'Errore immagine',
      'snackbar_text_image_uploaded_successfully':
          'Immagine caricata con successo!',
      'snackbar_text_invalid_hourly_rate': 'Tariffa oraria non valida',
      'snackbar_text_location_not_found': 'Posizione non trovata',
      'snackbar_text_passwords_do_not_match': 'Le password non corrispondono',
      'snackbar_text_pet_profile_created_but_media_upload_failed_you_can_add_medi':
          'Profilo dell\'animale domestico creato ma caricamento multimediale non riuscito. ',
      'snackbar_text_pet_profile_created_successfully':
          'Profilo dell\'animale domestico creato con successo!',
      'snackbar_text_pet_profile_updated_successfully':
          'Profilo dell\'animale domestico aggiornato con successo!',
      'snackbar_text_please_accept_the_terms_and_conditions':
          'Si prega di accettare i Termini e Condizioni',
      'snackbar_text_please_enter_your_paypal_email':
          'Inserisci la tua email PayPal.',
      'snackbar_text_please_fill_in_all_required_fields':
          'Si prega di compilare tutti i campi obbligatori',
      'snackbar_text_please_try_logging_in_again': 'Prova ad accedere di nuovo',
      'snackbar_text_profile_completed_successfully':
          'Profilo completato con successo!',
      'snackbar_text_profile_updated_but_image_upload_failed_please_try_again':
          'Profilo aggiornato ma caricamento dell\'immagine non riuscito. ',
      'snackbar_text_required': 'Necessario',
      'snackbar_text_review_submitted_successfully':
          'Recensione inviata con successo!',
      'snackbar_text_role_switched': 'Ruolo scambiato',
      'snackbar_text_selected_image_file_is_not_accessible_please_try_again':
          'Il file immagine selezionato non è accessibile. ',
      'snackbar_text_selection_failed': 'Selezione non riuscita',
      'snackbar_text_sitter_blocked_successfully':
          'Sitter bloccato con successo!',
      'snackbar_text_something_went_wrong_please_try_logging_in_again':
          'Qualcosa è andato storto. ',
      'snackbar_text_success': 'Successo',
      'snackbar_text_successfully_switched_to_userrole_value':
          'Cambio di ruolo riuscito con successo.',
      'snackbar_text_switch_role_failed': 'Cambio ruolo non riuscito',
      'snackbar_text_unknown_user_role_please_try_again':
          'Ruolo utente sconosciuto. ',
      'snackbar_text_verification_code_has_been_resent_to_your_email':
          'Il codice di verifica è stato inviato nuovamente alla tua email',
      'snackbar_text_verification_code_resent':
          'Codice di verifica inviato nuovamente',
      'snackbar_text_verification_code_sent': 'Codice di verifica inviato',
      'snackbar_text_welcome_back': 'Bentornato!',
      'snackbar_text_you_have_already_reviewed_this_sitter_you_can_only_submit_on':
          'Hai già recensito questo sitter. ',
    'post_more_options': 'Altre opzioni',
    'post_action_block_user': 'Blocca utente',
    'post_action_report': 'Segnala post',
    'block_user_title': 'Blocca utente',
    'block_user_action': 'Blocca',
    'block_user_confirm_message': 'Sei sicuro di voler bloccare questo utente? Non vedrai piu i suoi contenuti.',
    'block_user_success': 'Utente bloccato con successo.',
    'block_user_failed': 'Blocco non riuscito. Riprova.',
    'report_post_received': 'Segnalazione ricevuta. Grazie.',
    'pet_photo_delete_title': 'Elimina foto',
    'pet_photo_delete_confirm': 'Vuoi davvero eliminare questa foto?',
    'pet_photo_deleted': 'Foto eliminata con successo.',
    'pet_photo_delete_failed': 'Eliminazione non riuscita. Riprova.',
    'new_publication_button': 'Nuova pubblicazione',
    },
    // Sprint 4 step 7 — partial Portuguese locale. Missing keys fall back to en_US via GetX.
    'pt_PT': <String, String>{
      'price_per_hour': 'Preço / hora',
      'price_per_day': 'Preço / dia',
      'price_per_week': 'Preço / semana',
      'price_per_month': 'Preço / mês',
      'chat_payment_required_banner': 'O chat abre após a confirmação do pagamento.',
      'chat_pay_now_button': 'Pagar agora',
      'chat_share_phone_button': 'Partilhar o meu número',
      'terms_read_button': 'Ler os Termos e Condições',
      'service_prefs_at_owner_label': 'Aceito o serviço em minha casa',
      'service_prefs_at_sitter_label': 'Aceito o serviço em casa do cuidador',
      'service_location_label': 'Onde deve ocorrer o serviço?',
      'service_location_at_owner': 'Em minha casa',
      'service_location_at_sitter': 'Em casa do cuidador',
      'service_location_both': 'Ambos',
      'profile_my_availability': 'O meu calendário de disponibilidade',
      'profile_verify_identity': 'Verificar a minha identidade',
      'profile_identity_verified': 'Identidade verificada',
      'theme_setting_title': 'Tema',
      'theme_light': 'Claro',
      'theme_dark': 'Escuro',
      'theme_system': 'Seguir o sistema',
      'common_close': 'Fechar',
    },
  };
}
