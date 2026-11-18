import 'package:flutter/material.dart';

import '../utils/app_utils.dart';

/// Centralized application configuration storing base URL and endpoint paths.
class AppConfig {
  // Base URL for the backend API.
  // Use http://10.0.2.2:8000 for Android emulator, or http://localhost:8000 for desktop/web.
  //static const String baseUrl = 'http://10.0.2.2:8000';
  static const String baseUrl = 'http://192.168.1.117:8000';

  //static const String baseUrl = 'http://20.196.144.37:8000';
  static const String healthEndpoint = '/system/health';
  static const String activeUsersEndpoint = '/system/active-users';
  static const String loginEndpoint = '/user/auth/login';
  static const String adminLoginEndpoint = '/admins/auth/login';
  static const String registerEndpoint = '/user/auth/register';
  static const String adminUsersEndpoint = '/admins/users';
  static const String adminBlacklistEndpoint = '/admins/users/blacklist';
  static const String sendVerificationEndpoint = '/system/verification-code';
  static const String verifyCodeEndpoint = '/system/verification-code/verify';
  static const String checkAvailabilityEndpoint =
      '/user/auth/check-availability';
  static const String bondsEndpoint = '/bonds';
  static const String bondsRangeEndpoint = '/bonds/range';
  static const String bondlistsExtEndpoint = '/bonds/bondlists_ext';
  static const String drawScheduleEndpoint = '/user/drawlists/schedule';
  static const String userDrawlistsEndpoint = '/user/drawlists';
  static const String marketListingsEndpoint = '/user/market/listings';
  static const String adminAuditEndpoint = '/admins/audit';
  static const String adminChangePasswordEndpoint = '/admins/change-password';
  static const String userChangePasswordEndpoint = '/user/change-password';
  static const String userPasswordRecoveryEndpoint =
      '/user/auth/password-recovery';
  static const String userPasswordRecoveryCompleteEndpoint =
      '/user/auth/password-recovery/complete';
}

/// Centralized list of supported prize bond denominations throughout the mobile application:
/// 100, 200, 750, 1500, 25000, 40000
class AppDenominations {
  static const List<int> supported = [100, 200, 750, 1500, 25000, 40000];

  /// Format denomination display label (e.g. "Rs. 750 Prize Bond" or "Rs. 25,000 Premium Bond")
  static String formatLabel(int denom) {
    if (denom >= 25000) {
      return 'Rs. ${formatNumber(denom)} Premium Bond';
    }
    return 'Rs. ${formatNumber(denom)} Prize Bond';
  }

  /// Generate dropdown items for any denomination dropdown throughout the mobile app
  static List<DropdownMenuItem<int>> dropdownItems({
    bool includeAllOption = false,
    String allLabel = 'All Denominations',
  }) {
    final list = <DropdownMenuItem<int>>[];
    if (includeAllOption) {
      list.add(
        DropdownMenuItem<int>(
          value: 0,
          child: Text(allLabel, overflow: TextOverflow.ellipsis),
        ),
      );
    }
    for (final denom in supported) {
      list.add(
        DropdownMenuItem<int>(
          value: denom,
          child: Text(formatLabel(denom), overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return list;
  }
}
