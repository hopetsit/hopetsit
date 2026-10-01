// 606 (ZOE, 01/10/2026) — refus Apple 1.25/605, guideline 3.1.1 :
// « the app uses promo codes to unlock access ».
//
// Sur iOS, AUCUN code maison ne doit débloquer quoi que ce soit (PawPremium,
// boost, réduction…). Toutes les entrées « Code promo » / « J'ai un code » /
// pop-up promo pré-rempli passent par [houseCodesAllowed] : faux sur iOS,
// vrai ailleurs (Android et web inchangés). Le seul chemin restant sur iOS est
// la feuille OFFICIELLE d'Apple (offer codes, StoreKit), dans la boutique.
//
// `defaultTargetPlatform` (et non `Platform.isIOS`) : c'est la vraie plateforme
// sur l'appareil, et les tests peuvent la simuler
// (`debugDefaultTargetPlatformOverride`).
import 'package:flutter/foundation.dart';

/// Vrai quand l'app tourne sur iOS / iPadOS.
bool get isAppleStoreBuild606 => defaultTargetPlatform == TargetPlatform.iOS;

/// Les codes promo MAISON (serveur /promo/*) sont-ils proposés ? Jamais sur iOS.
bool houseCodesAllowed() => !isAppleStoreBuild606;

/// 607 (ZOE, 01/10/2026) — décision de Daniel : les codes de PARRAINAGE suivent
/// la même règle. Un code de parrainage débloque -10 % sur PawFollow/PawFamily
/// pour le parrain (serveur `referralService`) : sur iOS, ni saisie à
/// l'inscription, ni écran « Parrainage » (code, partage, réductions).
/// L'invitation d'AMIS (lien /invite?from=…) reste : elle n'envoie qu'une
/// demande d'ami et ne débloque rien.
bool referralCodesAllowed() => houseCodesAllowed();
