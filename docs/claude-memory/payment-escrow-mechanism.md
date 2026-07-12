---
name: payment-escrow-mechanism
description: How HopeTSIT escrow works + the single chokepoint that must gate every payout release
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

HopeTSIT payout escrow (provider = sitter/walker) works like this:

- **"Blocked" money = a `credit_booking` WalletTransaction with `meta.withdrawable=false`** — it logs earnings history but does NOT increment the provider's `walletBalance` (the withdrawable balance lives on the Sitter/Walker doc as `walletBalance`). `creditWallet`'s `withdrawable` arg **defaults to `true`**, so any credit at payment time that forgets `withdrawable:false` instantly makes money withdrawable. At PAYMENT, both `airwallexWebhookController` and `bookingController.confirmBookingPayment` credit `withdrawable:false` (history only).
- **Release = `processProviderPayoutForBooking`** (bookingController) calls `creditWallet({withdrawable:true})` → increments `walletBalance`. This is the **single chokepoint** for every release path.
- **Escrow state machine** lives on Booking: `confirmationStatus` enum (`none|awaiting_start|in_progress|awaiting_confirmation|confirmed|disputed`), `scheduledPayoutAt`, `autoReleaseAt`. `schedulePayoutForBooking` initializes it at payment (cs='awaiting_start', scheduledPayoutAt = serviceEnd + 48h). Release allowed ONLY on owner confirmation (`confirmService` sets cs='confirmed' + scheduledPayoutAt=now) OR the 48h auto-release (scheduler `processScheduledSitterPayouts` fires when scheduledPayoutAt<=now). Never on 'disputed'.

**Why this keeps breaking (Daniel: "l'argent est libre, j'ai pu retirer sans confirmation"):** v339 found `confirmBookingPayment` called `processProviderPayoutForBooking` directly at payment (cs still 'none') → released immediately. Fix = (1) a STRICT GATE inside `processProviderPayoutForBooking` (return early unless cs==='confirmed' OR scheduledPayoutAt<=now; 'none' legacy still passes), and (2) `confirmBookingPayment` now calls `schedulePayoutForBooking` instead of releasing.

**How to apply:** any NEW payment path (publication, direct sitter/walker, owner→sitter, owner→walker) must call `schedulePayoutForBooking` (NOT `processProviderPayoutForBooking`) and credit `withdrawable:false`. The gate is the safety net — keep it. Backend-only change → needs Render redeploy to take effect. See [[python3-store-alias-hook-error]].

**v341 audit:** found + fixed the same hole in `POST /admin/reconcile-pending-payments` (adminRoutes ~261, credited `withdrawable:true` at payment — now `false`). Full audit checklist that passed: (1) gate present in chokepoint; (2) every `withdrawable:` flag at payment time = false (webhook, confirmBookingPayment, PayPal path, admin reconcile); (3) `withdrawable:true` only inside the gated chokepoint; (4) webhook never calls the chokepoint directly (only schedulePayoutForBooking); (5) confirmService sets confirmed+scheduledPayoutAt=now BEFORE releasing; (6) withdraw route uses atomic `debitWallet` ($gte balance guard). Service actions also surface in the band ([[bande-vs-cloche-vocabulary]]): `_Kind.serviceAction` opens a sheet embedding the reusable `ServiceConfirmationCard` (start/complete for provider, confirm/dispute for owner — owner's confirm is what releases the payment).
