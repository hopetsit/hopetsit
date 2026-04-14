# Frontend test suite — follow-up TODOs

Sprint 8 step 8 shipped pure-Dart unit tests covering:
- i18n locale completeness (canonical en_US vs fr/es/de/it — pt is partial by design).
- IbanValidator mirror of backend ISO 13616.
- PricingDisplayHelper.rateTypeLabelKey mapping.
- SitterModel.fromJson + hasConfiguredRates.

Widget tests that need the Flutter test harness (not runnable without `flutter
test` + the Flutter SDK in PATH) are intentionally deferred:

- [ ] **LoginScreen** — email/password validation, error snackbar on 401.
- [ ] **SignUpScreen** — all required fields, referral-code optional field, Google/Apple buttons.
- [ ] **BookingCard** — renders the right status pill + price per rateType.
- [ ] **StripePaymentScreen** — pay button disabled when no clientSecret or booking status ≠ agreed.
- [ ] **Controllers** (AuthController, BookingsController) — mock ApiClient and assert RxState transitions.
- [ ] **LoyaltyCard** — shows Premium badge when stats.isPremium = true.
- [ ] **Dark mode smoke** — MaterialApp.builder pumps the app in both themes, asserts no exceptions.

Run the existing pure tests with:
```
cd frontend
flutter pub get
flutter test
```
