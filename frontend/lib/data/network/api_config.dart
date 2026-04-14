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

  /// Returns the environment-aware base URL.
  /// Set useLocalhost to true to use localhost:5000 for local development.
  static String get baseUrl {
    // Use localhost for local development
    // if (AppConstants.isDevelopment && AppConstants.useLocalhost) {
    //   return _localBaseUrl;
    // }
    return AppConstants.isDevelopment ? _devBaseUrl : _prodBaseUrl;
  }
}
