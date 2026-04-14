import 'package:hopetsit/data/network/api_config.dart';

/// Service for handling Stripe payment via webview.
class StripePaymentService {
  StripePaymentService._();

  /// Constructs the Stripe payment page URL
  /// The backend should provide either:
  /// 1. A custom payment page URL (preferred)
  /// 2. Or we construct one using the backend's payment endpoint
  static String getStripePaymentUrl({
    required String clientSecret,
    String? publishableKey,
    String? returnUrl,
    String? cancelUrl,
    String? paymentPageUrl,
  }) {
    // If backend provides a custom payment page URL, use it
    if (paymentPageUrl != null && paymentPageUrl.isNotEmpty) {
      final uri = Uri.parse(paymentPageUrl);
      return uri.replace(queryParameters: {
        'client_secret': clientSecret,
        if (returnUrl != null) 'return_url': returnUrl,
        if (cancelUrl != null) 'cancel_url': cancelUrl,
      }).toString();
    }

    // Otherwise, construct URL using backend's payment checkout endpoint
    // This assumes your backend has a payment page endpoint
    final backendPaymentUrl = '${ApiConfig.baseUrl}/payment/checkout';
    
    final returnUrlParam = returnUrl ?? 'hopetsit://payment-return';
    final cancelUrlParam = cancelUrl ?? 'hopetsit://payment-cancel';

    final uri = Uri.parse(backendPaymentUrl);
    
    return uri.replace(queryParameters: {
      'client_secret': clientSecret,
      'return_url': returnUrlParam,
      'cancel_url': cancelUrlParam,
      if (publishableKey != null) 'publishable_key': publishableKey,
    }).toString();
  }


  /// Parses the return URL to check payment status
  static Map<String, String>? parseReturnUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      
      // Check if it's a success or failure callback
      if (path.contains('payment-return')) {
        final paymentIntentId = uri.queryParameters['payment_intent'];
        final paymentIntentClientSecret = uri.queryParameters['payment_intent_client_secret'];
        final redirectStatus = uri.queryParameters['redirect_status'];
        
        return {
          'status': redirectStatus ?? 'unknown',
          'payment_intent_id': paymentIntentId ?? '',
          'client_secret': paymentIntentClientSecret ?? '',
        };
      }
      
      if (path.contains('payment-cancel')) {
        return {'status': 'cancelled'};
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Checks if a URL is a Stripe callback URL
  static bool isStripeCallbackUrl(String url) {
    return url.contains('payment-return') || 
           url.contains('payment-cancel') ||
           url.contains('stripe.com') && 
           (url.contains('payment_intent') || url.contains('client_secret'));
  }
}

