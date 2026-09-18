// v565 — interface commune des contrôleurs de profil (ProfileController pour
// owner/walker, SitterProfileController pour sitter) : permet aux sous-pages
// Préférences / Sécurité d'être partagées par les 3 rôles sans dupliquer.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/profile_model.dart';

abstract class ProfileSettingsHost {
  Rxn<ProfileModel> get profile;
  RxBool get prefsSaving;
  Future<void> savePreferences(Map<String, dynamic> prefsJson);
  Future<void> setTwoFactor(bool enabled);
  void showLanguageDialog();
  void showDeleteAccountDialog(BuildContext context);
  void navigateToChangePassword();
  void navigateToBlockedUsers();
  Future<void> loadMyProfile();
}
