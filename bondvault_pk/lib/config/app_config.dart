/// Centralized application configuration storing base URL and endpoint paths.
class AppConfig {
  // Base URL for the backend API.
  // Use http://10.0.2.2:8000 for Android emulator, or http://localhost:8000 for desktop/web.
  static const String baseUrl = 'http://192.168.100.134:8000';

  // System & Auth Endpoints
  static const String healthEndpoint = '/system/health';
  static const String activeUsersEndpoint = '/system/active-users';
  static const String loginEndpoint = '/users/auth/login';
  static const String adminLoginEndpoint = '/admins/auth/login';
  static const String registerEndpoint = '/users/auth/register';
  static const String adminUsersEndpoint = '/admins/users';
  static const String adminBlacklistEndpoint = '/admins/users/blacklist';
  static const String sendVerificationEndpoint = '/system/verification-code';
  static const String verifyCodeEndpoint = '/system/verification-code/verify';
  static const String checkAvailabilityEndpoint =
      '/users/auth/check-availability';
  static const String bondsEndpoint = '/bonds';
  static const String bondsRangeEndpoint = '/bonds/range';
  static const String bondlistsExtEndpoint = '/bonds/bondlists_ext';
}
