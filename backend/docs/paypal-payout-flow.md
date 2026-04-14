### PayPal Payout Flow

This document explains how sitter payouts are processed after a successful PayPal booking payment, how failures are handled, and how payouts can be retried safely.

---

## 1. Overview

The existing PayPal payment flow remains unchanged:

- Owner pays a booking via PayPal (Orders API).
- Money is collected into the **platform PayPal account**.
- The booking is marked as **paid**.

New behavior adds **automatic payouts** to sitters:

- After a booking is successfully captured and marked paid via PayPal:
  - **80%** of the `pricing.totalPrice` (`pricing.netPayout`) is sent to the sitter’s PayPal email using **PayPal Payouts API**.
  - **20%** (`pricing.commission`) remains as platform commission.

Payouts are tracked on the `Booking` document and are recoverable via an admin retry endpoint.

---

## 2. Data Model Changes

### Booking model (`src/models/Booking.js`)

New payout fields:

- `payoutStatus` (`String`, enum: `pending`, `processing`, `completed`, `failed`, default: `pending`)
  - Status of payout lifecycle, independent from `status` and `paymentStatus`.
- `sitterPaypalEmail` (`String`, default `''`)
  - Snapshot of the sitter’s PayPal email at the time of payout attempt.
- `payoutId` (`String`, default `null`)
  - PayPal payout item ID.
- `payoutBatchId` (`String`, default `null`)
  - PayPal payout batch ID.
- `payoutAt` (`Date`, default `null`)
  - Timestamp when payout completed successfully.
- `payoutError` (`String`, default `null`)
  - Last error encountered during payout.

Existing pricing fields used:

- `pricing.totalPrice` – amount owner pays.
- `pricing.commission` – platform commission (20%).
- `pricing.netPayout` – sitter payout (80%).

### Sitter model (`src/models/Sitter.js`)

New field:

- `paypalEmail` (`String`, default `''`)
  - Sitter’s PayPal email address, used as payout destination.

---

## 3. Sitter PayPal Email Management

### Endpoint: Update sitter PayPal email

- **Route**: `PUT /sitters/paypal-email`
- **Files**:
  - Route: `src/routes/sitterRoutes.js`
  - Controller: `updateSitterPaypalEmail` in `src/controllers/sitterController.js`

#### Behavior

- Requires JWT auth and role `sitter`:
  - Uses `requireAuth` and `requireRole('sitter')`.
- Request body:

```json
{
  "paypalEmail": "sitter-payments@example.com"
}
```

- Validation:
  - Must be a non-empty string.
  - Must match a basic email pattern (`^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$`).
- On success:
  - Updates `sitter.paypalEmail` (stored in lowercase).
  - Returns:

```json
{
  "message": "PayPal email updated successfully.",
  "paypalEmail": "sitter-payments@example.com"
}
```

This email is used as the payout receiver for PayPal Payouts.

---

## 4. PayPal Payout Service

### Service file

- `src/services/paypalPayoutService.js`

### Responsibilities

- Encapsulates the **PayPal Payouts API (v1)** integration.
- Does **not** change or depend on the existing Orders API service (`paypalService.js`).
- Reads PayPal credentials and environment from:
  - `PAYPAL_CLIENT_ID`
  - `PAYPAL_CLIENT_SECRET`
  - `PAYPAL_ENVIRONMENT` (`'live'` → production, anything else → sandbox).

### Access token retrieval

- Uses `https` and Basic Auth to call:
  - `POST /v1/oauth2/token` with `grant_type=client_credentials`.
- Returns an access token used for payouts:
  - Throws if no `access_token` is returned.

### Payout function

```js
sendPayoutToSitter({ bookingId, sitterEmail, amount, currency })
```

- **Parameters**:
  - `bookingId` (string) – internal booking ID.
  - `sitterEmail` (string) – sitter’s PayPal email.
  - `amount` (number) – sitter payout in major units (e.g. `80.0`).
  - `currency` (string) – `'EUR'` or `'USD'`.

- **Validations**:
  - Non-empty `bookingId` and `sitterEmail`.
  - `amount` must be a positive finite number.
  - `currency` must be non-empty.

- **Request to PayPal**:
  - Host: `api-m.paypal.com` or `api-m.sandbox.paypal.com` based on environment.
  - Endpoint: `POST /v1/payments/payouts?sync_mode=true`
  - Body:

```json
{
  "sender_batch_header": {
    "sender_batch_id": "batch_<bookingId>_<timestamp>",
    "email_subject": "You received a payment"
  },
  "items": [
    {
      "recipient_type": "EMAIL",
      "amount": {
        "value": "80.00",
        "currency": "EUR"
      },
      "receiver": "sitter-payments@example.com",
      "note": "Payout for booking <bookingId>",
      "sender_item_id": "<bookingId>"
    }
  ]
}
```

- **Return value**:
  - Extracts:
    - `batchId = response.batch_header.payout_batch_id`
    - `payoutItemId = response.items[0].payout_item_id`
  - Throws if either is missing.

### Logging

- Logs every payout attempt and response:
  - Booking ID, sitter email, amount, currency, and sender batch ID.
  - Full PayPal response object.

---

## 5. Automatic Payout Trigger After Capture

### Capture controller (unchanged core logic)

- **Route**: `POST /bookings/:id/paypal/capture/:orderId`
- **Controller**: `captureBookingPaypalPayment` in `src/controllers/bookingController.js`
- Existing logic (unchanged):
  - Captures PayPal order via `capturePaypalOrder`.
  - When `capturedOrder.status === 'COMPLETED'`:
    - Sets:
      - `booking.status = 'paid'`
      - `booking.paymentStatus = 'paid'`
      - `booking.paymentProvider = 'paypal'`
      - `booking.paidAt = new Date()`
      - Extracts and saves `booking.paypalCaptureId`.
      - Ensures `booking.paypalOrderId` is set.
    - Saves the booking.

### New helper: `processSitterPayoutForBooking`

Defined in `bookingController.js`:

```js
async function processSitterPayoutForBooking(booking) { ... }
```

**Key safeguards & behavior**:

- Preconditions:
  - `booking.status === 'paid'`
  - `booking.paymentStatus === 'paid'`
  - `booking.paymentProvider === 'paypal'`
- Idempotency:
  - If `booking.payoutStatus === 'completed'`, it logs and returns without sending another payout.
- Amount / currency validation:
  - Uses `booking.pricing.netPayout` and `booking.pricing.currency`.
  - Skips payout if `netPayout` is not a positive number.
- Sitter and email:
  - Loads sitter from `booking.sitterId`.
  - If sitter not found:
    - Sets `booking.payoutStatus = 'failed'`, `payoutError = 'Sitter not found for payout.'`.
  - If `sitter.paypalEmail` is missing:
    - Sets `booking.payoutStatus = 'failed'`, `payoutError = 'Sitter PayPal email is missing.'`.
  - On any early failure it logs a warning/error and saves the updated booking.
- On valid payout:
  - Sets `booking.payoutStatus = 'processing'`.
  - Copies sitter email into `booking.sitterPaypalEmail`.
  - Calls `sendPayoutToSitter(...)`.
  - On success:
    - `booking.payoutStatus = 'completed'`
    - `booking.payoutBatchId = batchId`
    - `booking.payoutId = payoutItemId`
    - `booking.payoutAt = new Date()`
    - `booking.payoutError = null`
  - On error:
    - `booking.payoutStatus = 'failed'`
    - `booking.payoutError = error.message`

All errors are caught and logged; the function never throws up to the capture controller.

### Where it is called

In `captureBookingPaypalPayment`, inside the `if (orderStatus === 'COMPLETED')` block, **after** the booking is saved as paid:

```js
await booking.save();
await processSitterPayoutForBooking(booking);
```

This ensures:

- The booking is always marked paid when capture succeeds.
- Payout runs right after capture but **does not block or rollback** the payment result.

---

## 6. Retry Mechanism (Admin Endpoint)

### Endpoint

- **Route**: `POST /admin/bookings/:id/retry-payout`
- **Files**:
  - Route: `src/routes/adminRoutes.js`
  - Controller: `retryBookingPayout` in `src/controllers/bookingController.js`

Mounted in `src/app.js`:

- `app.use('/admin', adminRoutes);`

### Security

- Requires JWT auth + role `owner`:
  - `requireAuth`, `requireRole('owner')`.
- Intended for admin/operations users (currently modeled as owners).

### Eligibility checks

`retryBookingPayout` performs the following checks:

- Booking must exist; otherwise `404`.
- `booking.paymentStatus === 'paid'` **and** `booking.status === 'paid'`:
  - Otherwise `400` – cannot retry payout on unpaid bookings.
- `booking.paymentProvider === 'paypal'`:
  - Otherwise `400` – retry is only defined for PayPal.
- `booking.payoutStatus !== 'completed'`:
  - If already completed → `400` to prevent double payouts.
- `booking.payoutStatus === 'failed'`:
  - If not failed → `400` with current status in message (e.g. `pending` or `processing`).

### Retry behavior

- On passing all checks:
  - Calls `processSitterPayoutForBooking(booking)`.
  - Reloads the booking and returns:

```json
{
  "bookingId": "<id>",
  "payoutStatus": "completed | failed | processing | pending",
  "payoutBatchId": "... or null",
  "payoutAt": "ISO date or null",
  "payoutError": "message or null",
  "message": "Payout retried and completed successfully."
  // or
  // "Payout retry attempted. Check payoutStatus and payoutError for details."
}
```

- Errors (invalid ID, internal issues) return standard `400`/`500` codes with messages, but do not change payment status.

---

## 7. Payment Status API Extension

### Endpoint

- **Route**: `GET /bookings/:id/payment-status`
- **Controller**: `getPaymentStatus` in `src/controllers/bookingController.js`

Existing behavior:

- Returns booking `status`, `paymentStatus`, Stripe and PayPal identifiers, and a human-readable message.

New payout fields added to the response:

- `payoutStatus` – current payout status (default `'pending'`).
- `payoutBatchId` – PayPal payout batch ID (or `null`).
- `payoutAt` – payout completion timestamp (or `null`).

This allows the frontend to:

- Display whether the sitter has been paid.
- Detect if payout is `failed` and surface retry flows to admins.

---

## 8. Error Handling & Safety

### Payout failures

Handled scenarios:

- Missing sitter PayPal email.
- Sitter not found.
- Invalid `netPayout` amount.
- PayPal access token failure.
- PayPal Payouts API errors (validation, network, 4xx/5xx).

Behavior in all failure cases:

- `booking.status` and `paymentStatus` remain **paid** (payment success is final).
- `booking.payoutStatus` set to `failed`.
- `booking.payoutError` populated with the error message.
- Logs are written with booking ID, sitter email (if available), amount, and PayPal response or error.

### No double payouts

Protections:

- `processSitterPayoutForBooking`:
  - Immediately returns when `booking.payoutStatus === 'completed'`.
- Admin retry endpoint:
  - Refuses to retry when `payoutStatus === 'completed'`.
- Payout IDs:
  - `payoutBatchId` and `payoutId` are stored on booking and can be audited or cross-checked if needed.

### Non-blocking payment capture

- Capture flow (`captureBookingPaypalPayment`) always:
  - Marks booking as paid when PayPal reports `COMPLETED`.
  - Returns success response to client regardless of payout result.
- Payout runs **after** the booking is saved as paid, and any payout errors:
  - Are caught and logged.
  - Only affect payout tracking fields on the booking.

This ensures that:

- A payout failure never causes the capture endpoint to fail for the owner.
- Capture latency impact is limited to the payout call, but not its success semantics.

---

## 9. Final Flow Summary

1. **Owner payment**
   - Owner approves and captures PayPal payment via existing flow.
   - Booking is updated:
     - `status = 'paid'`
     - `paymentStatus = 'paid'`
     - `paymentProvider = 'paypal'`

2. **Automatic sitter payout**
   - `processSitterPayoutForBooking` is called:
     - Validates booking state, net payout, and sitter PayPal email.
     - Calls PayPal Payouts API to send `pricing.netPayout` to `sitter.paypalEmail`.
     - On success:
       - `payoutStatus = 'completed'`
       - `payoutBatchId` and `payoutId` stored.
       - `payoutAt` timestamp set.
     - On failure:
       - `payoutStatus = 'failed'`
       - `payoutError` set.

3. **Monitoring & retries**
   - `GET /bookings/:id/payment-status` exposes payout status, batch ID, and timestamp.
   - Admins can call `POST /admin/bookings/:id/retry-payout` for:
     - Bookings with `status = 'paid'`, `paymentStatus = 'paid'`, `paymentProvider = 'paypal'`, and `payoutStatus = 'failed'`.
   - The same helper function is used for retries, preserving idempotency and safety guarantees.

Result:

- **Owner** pays full amount to platform.
- **Platform** keeps `pricing.commission` (20%).
- **Sitter** automatically receives `pricing.netPayout` (80%) via PayPal Payouts.

