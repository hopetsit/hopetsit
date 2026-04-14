import 'package:hopetsit/utils/app_constants.dart';

/// Central place for API environment configuration.
class ApiConfig {
  ApiConfig._();

  /// Base URLs for each environment.
  static const String _devBaseUrl =
      'https://petinsta-backend-g7jn.onrender.com';

  //  static const String _devBaseUrl = 'https://petinsta-backend.onrender.com';
  // static const String _localBaseUrl = 'http://localhost:5000';
  static const String _prodBaseUrl = 'https://api.hopetsit.com';

  /// Timeout durations for HTTP calls.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Sprint 8 step 9 — API version path suffix. The backend mounts routes
  /// under /api/v1 (canonical) and keeps the root mount for 6-month backwards
  /// compatibility. We always hit the versioned path from the client.
  static const String _apiPrefix = '/api/v1';

  /// Returns the environment-aware base URL, including the API version prefix.
  /// Set useLocalhost to true to use localhost:5000 for local development.
  static String get baseUrl {
    final root = AppConstants.isDevelopment ? _devBaseUrl : _prodBaseUrl;
    return '$root$_apiPrefix';
  }

  /// Root URL without the version prefix (for legacy endpoints only — e.g. /webhooks).
  static String get rootUrl {
    return AppConstants.isDevelopment ? _devBaseUrl : _prodBaseUrl;
  }
}
