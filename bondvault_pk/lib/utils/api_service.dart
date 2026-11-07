import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../main.dart';
import 'app_utils.dart';

class ApiService {
  static bool _dialogIsShowing = false;

  /// Show application-wide "Services Not Available" bottom sheet modal.
  static void showServiceUnavailable() {
    if (_dialogIsShowing) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    _dialogIsShowing = true;

    showErrorBottomSheet(
      context: context,
      title: 'Internal Error',
      message: 'Something went wrong on our end. Please try again or return to safety.',
      onDismiss: () {},
    );
  }

  /// Fetch all bondlists for the user.
  static Future<Map<String, dynamic>?> fetchBondlists(
    String accessToken,
  ) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.bondlistsExtEndpoint}',
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
    } catch (_) {
      showServiceUnavailable();
    }
    return null;
  }

  /// Add bonds by range.
  static Future<http.Response> addBondsRange({
    required String accessToken,
    required int denomination,
    required String startNumber,
    required String endNumber,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.bondsRangeEndpoint}',
      );
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'denomination': denomination,
          'start_number': startNumber,
          'end_number': endNumber,
        }),
      );
      if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
      return res;
    } catch (e) {
      showServiceUnavailable();
      rethrow;
    }
  }

  /// Add bonds by list of numbers.
  static Future<http.Response> addBonds({
    required String accessToken,
    required int denomination,
    required List<String> bonds,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.bondsEndpoint}');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'denomination': denomination, 'bonds': bonds}),
      );
      if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
      return res;
    } catch (e) {
      showServiceUnavailable();
      rethrow;
    }
  }

  /// Fetch user bond winnings.
  static Future<Map<String, dynamic>?> fetchBondWinnings(
    String accessToken,
  ) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/user/bond-winnings');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
    } catch (_) {
      showServiceUnavailable();
    }
    return null;
  }

  /// Delete specific bonds.
  static Future<http.Response> deleteBonds({
    required String accessToken,
    required int denomination,
    required List<String> bonds,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.bondsEndpoint}');
      final res = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'denomination': denomination, 'bonds': bonds}),
      );
      if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
      return res;
    } catch (e) {
      showServiceUnavailable();
      rethrow;
    }
  }
}
