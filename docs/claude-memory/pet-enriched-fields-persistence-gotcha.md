# Pet enriched fields — persistence gotcha (v440)

Two hand-built backend spots silently DROPPED the enriched fiche fields (À propos / Santé / Habitudes), breaking the edit round-trip:

1. **`updatePetProfile`** (PUT `/pets/:id` → what `PetRepository.updatePet` hits) whitelists only basic fields (petName, breed, weight…). It ignored characterTraits, compatibilities, habits, vaccinationStatus, sterilized, microchipped, foodRestrictions, deworming, healthInsurance, behavior, age, vaccinations, regularVet, emergencyVet. Fix v440: `ENRICHED_PASSTHROUGH` array copied from `normalizedData` into `updateData` when defined.
2. **`getPetById`** (GET `/pets/:id`) is hand-built (like the getSitterProfile gotcha) and returned ONLY basic fields → fiche came back empty after a gallery reload / edit-by-id. Fix v440: added every enriched block to `petResponse`.

Create works fine (POST → `Pet.create({...petData})` spreads everything).

New additive fields (v440), all on `Pet.js` + `PetModel` + `EnrichedPetFormState`:
- `sterilized` (bool), `microchipped` (bool), `foodRestrictions` (string)
- `compatibilities.withNac` (string)
- `habits.sleep` / `habits.housetrained` / `habits.leashBehaviour` / `habits.fears`
- vaccinationStatus now also accepts `'partial'`; char trait `dominant` added.

Section 6 sync: the 3 identical `petsData` blocks in postController (listPosts / getMediaPosts / getRequestPosts, built via `resolvePostPets`) now also emit `compatibilities`, `vaccinationStatus`, `sterilized`, `microchipped`. `PostPet` (frontend post_model.dart) parses them; PetPostCard shows them as info chips in the "Caractère des animaux" block.

Section 7 annonce horaire: shared helper `lib/utils/post_date_label.dart` (`PostDateLabel.forPost`) includes HH:mm when a non-midnight time is present; wired into home_screen, my_posts_screen, notification_post_view_screen (sitter feed already had its own time-aware version).

i18n: ~37 new `pet_*` keys added to ALL 6 translation files (anchor: after `'pet_section_habits'`). The old fiche showed RAW keys `my_pets_breed_label` / `edit_pet_weight` / `edit_pet_height` (never existed) — replaced with `pet_breed` / `pet_weight` / `pet_height`.
