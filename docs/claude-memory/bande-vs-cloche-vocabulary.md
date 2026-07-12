---
name: bande-vs-cloche-vocabulary
description: "Daniel's \"la bande\" = HomeQuickActionBar orange action banner, NOT the bell notification feed"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

When Daniel says **"la bande"** / **"le bandeau"** (home screen), he means the **`HomeQuickActionBar`** orange action banner under the header (`frontend/lib/widgets/home_quick_action_bar.dart`) — the card that shows "Tout est à jour" / "Payer X€" / "Nouvelle demande". He does **NOT** mean the 🔔 **bell notification feed** (top-right, `notifications_screen.dart`). This mismatch caused a wrong v329 implementation (built in the bell feed; he then said "non je parle de la bande pas de la cloche").

**Why:** the two surfaces look similar in French shorthand but are different widgets; guessing wrong wastes a whole iteration.

**How to apply:** for "afficher X dans la bande", edit `HomeQuickActionBar`. It renders ONE action at a time via `_QuickAction`/`_Kind`; new action types are a fallback before `_NeutralBar`. It's shared across all 3 home screens (owner/sitter/walker via `widget.role`), so one edit covers all 3 profiles. v337 added `_Kind.friendRequest`; v338 added `_Kind.familyInvitation` (violet 0xFF8B5CF6) — both read `FriendController` (`incomingRequests` / `incomingFamilyInvitations`), which must be `Get.put` in the band's `initState` since it's only lazily registered by the friends/map screens. Tap → bottom sheet with the requester/holder profile + Accept/Refuse; on accept/refuse it navigates to `FriendsScreen(initialIndex:)` — tabs are **0=Amis, 1=Demandes, 2=Ajouter, 3=Famille**. See [[getsitterprofile-manual-response-gotcha]].
