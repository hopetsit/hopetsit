import sys, subprocess

REPO = '/sessions/relaxed-jolly-pasteur/mnt/HopeTSIT_FINAL_FIXED/HopeTSIT_FINAL'

def head(path):
    return subprocess.check_output(
        ['git', 'show', f'HEAD:{path}'], cwd=REPO, encoding='utf-8'
    )

# ============ 1. owner_repository.dart — add agreeToBooking method ============
or_path = 'frontend/lib/repositories/owner_repository.dart'
or_code = head(or_path)

# Insert the new method right before getBookingAgreement
insert_before = "  /// Gets the booking agreement/price details.\n  Future<Map<String, dynamic>> getBookingAgreement({"

new_method = """  /// Session v16.3b — transition a booking from status `accepted` to `agreed`.
  ///
  /// Required before payment can be initiated (backend enforces this).
  /// When called by the owner, the backend also auto-creates a Stripe
  /// PaymentIntent and returns its `clientSecret` in the response, which
  /// the payment screen can reuse to skip a round-trip.
  Future<Map<String, dynamic>> agreeToBooking({
    required String bookingId,
  }) async {
    AppLogger.logInfo(
      'Agreeing to booking (status accepted -> agreed)',
      data: {'bookingId': bookingId},
    );
    try {
      final response = await _apiClient.put(
        '${ApiEndpoints.bookings}/$bookingId/agree',
        body: {},
        requiresAuth: true,
      );
      if (response is Map<String, dynamic>) {
        AppLogger.logSuccess('Booking agreed', data: {'bookingId': bookingId});
        return response;
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      throw ApiException(
        'Unexpected agree to booking response.',
        details: response,
      );
    } catch (e) {
      AppLogger.logError('Failed to agree to booking', error: e);
      rethrow;
    }
  }

  /// Gets the booking agreement/price details.
  Future<Map<String, dynamic>> getBookingAgreement({"""

if insert_before not in or_code:
    sys.exit('getBookingAgreement marker not found in owner_repository')
# Replace by adding new method ABOVE the existing one. Only replace first occurrence.
or_new = or_code.replace(insert_before, new_method, 1)

with open(f'{REPO}/{or_path}', 'w') as f:
    f.write(or_new)
print(f'owner_repository.dart: +agreeToBooking method ({len(or_new)} bytes)')

# ============ 2. booking_agreement_screen.dart — auto-agree when tapping Pay if status=accepted ============
ba_path = 'frontend/lib/views/booking/booking_agreement_screen.dart'
ba_code = head(ba_path)

# Wrap the Stripe button onTap body with an agree-first logic.
# Current onTap: navigates directly to StripePaymentScreen.
# New onTap: if status is 'accepted', await agreeToBooking() first (with loading state), then navigate.

stripe_old = """                        CustomButton(
                          title: 'payment_pay_with_stripe'.tr.replaceAll(
                            '@amount',
                            CurrencyHelper.format(
                              _currency ??
                                  widget.booking.pricing?.currency ??
                                  widget.booking.sitter.currency,
                              finalTotal,
                            ),
                          ),
                          onTap: () {
                            Get.to(
                              () => StripePaymentScreen(
                                booking: widget.booking,
                                totalAmount: finalTotal,
                                currency:
                                    _currency ??
                                    widget.booking.pricing?.currency ??
                                    widget.booking.sitter.currency,
                              ),
                            );
                          },
                          bgColor: AppColors.primaryColor,
                          textColor: AppColors.whiteColor,
                          height: 48.h,
                          radius: 48.r,
                        ),"""

stripe_new = """                        CustomButton(
                          title: 'payment_pay_with_stripe'.tr.replaceAll(
                            '@amount',
                            CurrencyHelper.format(
                              _currency ??
                                  widget.booking.pricing?.currency ??
                                  widget.booking.sitter.currency,
                              finalTotal,
                            ),
                          ),
                          // Session v16.3b — if status is still 'accepted',
                          // transition it to 'agreed' before opening the
                          // Stripe sheet. Backend rejects payment intents
                          // on non-'agreed' bookings, which left owners
                          // stuck in a deadlock.
                          onTap: () async {
                            await _agreeAndPayWithStripe(finalTotal);
                          },
                          bgColor: AppColors.primaryColor,
                          textColor: AppColors.whiteColor,
                          height: 48.h,
                          radius: 48.r,
                        ),"""

if stripe_old not in ba_code:
    sys.exit('stripe button block not found in booking_agreement_screen')
ba_code = ba_code.replace(stripe_old, stripe_new, 1)

# Same pattern for PayPal button
paypal_old = """                          CustomButton(
                            title: 'payment_pay_with_paypal'.tr.replaceAll(
                              '@amount',
                              CurrencyHelper.format(
                                _currency ??
                                    widget.booking.pricing?.currency ??
                                    widget.booking.sitter.currency,
                                finalTotal,
                              ),
                            ),
                            onTap: () {
                              Get.to(
                                () => PayPalPaymentScreen(
                                  booking: widget.booking,
                                  totalAmount: finalTotal,
                                  currency:
                                      _currency ??
                                      widget.booking.pricing?.currency ??
                                      widget.booking.sitter.currency,
                                ),
                              );
                            },
                            bgColor: AppColors.whiteColor,
                            textColor: AppColors.grey700Color,
                            borderColor: AppColors.grey300Color,
                            height: 48.h,
                            radius: 48.r,
                          ),"""

paypal_new = """                          CustomButton(
                            title: 'payment_pay_with_paypal'.tr.replaceAll(
                              '@amount',
                              CurrencyHelper.format(
                                _currency ??
                                    widget.booking.pricing?.currency ??
                                    widget.booking.sitter.currency,
                                finalTotal,
                              ),
                            ),
                            // Session v16.3b — see Stripe onTap comment.
                            onTap: () async {
                              await _agreeAndPayWithPaypal(finalTotal);
                            },
                            bgColor: AppColors.whiteColor,
                            textColor: AppColors.grey700Color,
                            borderColor: AppColors.grey300Color,
                            height: 48.h,
                            radius: 48.r,
                          ),"""

if paypal_old not in ba_code:
    sys.exit('paypal button block not found')
ba_code = ba_code.replace(paypal_old, paypal_new, 1)

# Add the helper methods _agreeAndPayWithStripe / _agreeAndPayWithPaypal
# Insert them near the end of the state class, before the closing brace of _BookingAgreementScreenState.
# Insert right before _buildStatusBadge helper or similar. Find a safe anchor.
# Use the first occurrence of "Widget _buildStatusBadge" as insertion point.

anchor = "  Widget _buildStatusBadge()"
helpers = """  /// Session v16.3b — owner agrees to booking (if needed) then opens
  /// the Stripe payment sheet. Wrapping the Pay button removes the need
  /// for a separate "Agree" UI while still calling the required backend
  /// transition `accepted -> agreed`.
  Future<void> _agreeAndPayWithStripe(double finalTotal) async {
    final status = widget.booking.status.toLowerCase();
    if (status == 'accepted') {
      final ok = await _ensureAgreed();
      if (!ok) return;
    }
    if (!mounted) return;
    Get.to(
      () => StripePaymentScreen(
        booking: widget.booking,
        totalAmount: finalTotal,
        currency: _currency ??
            widget.booking.pricing?.currency ??
            widget.booking.sitter.currency,
      ),
    );
  }

  /// Session v16.3b — symmetric helper for the PayPal path.
  Future<void> _agreeAndPayWithPaypal(double finalTotal) async {
    final status = widget.booking.status.toLowerCase();
    if (status == 'accepted') {
      final ok = await _ensureAgreed();
      if (!ok) return;
    }
    if (!mounted) return;
    Get.to(
      () => PayPalPaymentScreen(
        booking: widget.booking,
        totalAmount: finalTotal,
        currency: _currency ??
            widget.booking.pricing?.currency ??
            widget.booking.sitter.currency,
      ),
    );
  }

  /// Calls PUT /bookings/:id/agree. Returns true on success.
  /// Mutates widget.booking.status to 'agreed' locally so the UI reflects
  /// the new state immediately if the user comes back before a refresh.
  Future<bool> _ensureAgreed() async {
    try {
      setState(() => _isLoading = true);
      await _ownerRepository.agreeToBooking(bookingId: widget.booking.id);
      widget.booking.status = 'agreed';
      return true;
    } on ApiException catch (e) {
      AppLogger.logError('Failed to agree before payment', error: e.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.message.isNotEmpty ? e.message : 'common_error_generic'.tr,
      );
      return false;
    } catch (e) {
      AppLogger.logError('Failed to agree before payment', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusBadge()"""

if anchor not in ba_code:
    sys.exit('_buildStatusBadge anchor not found')
# Replace first occurrence (declaration)
ba_code = ba_code.replace(anchor, helpers, 1)

with open(f'{REPO}/{ba_path}', 'w') as f:
    f.write(ba_code)
print(f'booking_agreement_screen.dart: +_agreeAndPay helpers ({len(ba_code)} bytes)')

# Sanity: must contain new methods now
with open(f'{REPO}/{ba_path}', 'r') as f:
    check = f.read()
for token in ['_agreeAndPayWithStripe', '_agreeAndPayWithPaypal', '_ensureAgreed', 'agreeToBooking(bookingId']:
    if token not in check:
        sys.exit(f'missing token in result: {token}')
print('Sanity: all helper methods present')

# ============ 3. booking_model.dart — make status mutable (final -> var) ============
# The helper sets widget.booking.status = 'agreed'. This requires status to be non-final.
bm_path = 'frontend/lib/models/booking_model.dart'
bm_code = head(bm_path)

# Look for "final String status;"
if 'final String status;' in bm_code:
    bm_new = bm_code.replace('final String status;', 'String status;', 1)
    with open(f'{REPO}/{bm_path}', 'w') as f:
        f.write(bm_new)
    print(f'booking_model.dart: status made mutable ({len(bm_new)} bytes)')
else:
    print('booking_model.dart: status already mutable or pattern different — skipping')

print('\nALL BUG 6 EDITS APPLIED')
