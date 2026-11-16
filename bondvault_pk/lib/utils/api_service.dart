import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../main.dart';
import '../screens/login_screen.dart';
import '../widgets/widgets.dart';
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

  static bool _sessionDialogShowing = false;

  /// Global error handler for an invalid or revoked user/admin session.
  static Future<void> handleInvalidSession([String? reason]) async {
    if (_sessionDialogShowing) return;
    _sessionDialogShowing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    if (navigatorKey.currentContext != null) {
      showAppNotificationSheet(
        context: navigatorKey.currentContext!,
        title: 'Session Expired',
        message:
            reason ??
            'Your session has expired or was revoked. Please sign in again.',
        type: AppNotificationType.warning,
        dismissLabel: 'Sign In Again',
        onDismiss: () {
          _sessionDialogShowing = false;
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        },
      );
    } else {
      _sessionDialogShowing = false;
    }
  }

  /// Centralized API response status code handler.
  static bool handleApiResponse(
    http.Response res, {
    BuildContext? context,
    bool showToastOnError = true,
  }) {
    final activeContext = context ?? navigatorKey.currentContext;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return true;
    }

    if (res.statusCode == 401) {
      handleInvalidSession();
      return false;
    }

    if (res.statusCode >= 500 || res.statusCode == 503) {
      showServiceUnavailable();
      return false;
    }

    if (!showToastOnError || activeContext == null) return false;

    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {}

    String errorMessage = 'Request failed (${res.statusCode})';

    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        errorMessage = detail;
      } else if (detail is List && detail.isNotEmpty) {
        final first = detail[0];
        if (first is Map) {
          final msg = first['msg']?.toString() ?? '';
          final loc = first['loc'] is List ? (first['loc'] as List) : [];
          final field = loc.isNotEmpty ? loc.last.toString() : '';
          errorMessage = field.isNotEmpty ? '$field: $msg' : msg;
        }
      } else if (data.containsKey('message')) {
        errorMessage = data['message'].toString();
      }
    }

    if (res.statusCode == 429) {
      errorMessage = 'Too many requests. Please wait a moment and try again.';
    } else if (res.statusCode == 403 &&
        errorMessage == 'Request failed (403)') {
      errorMessage =
          'Access denied. You do not have permission to perform this action.';
    } else if (res.statusCode == 404 &&
        errorMessage == 'Request failed (404)') {
      errorMessage = 'The requested resource was not found.';
    } else if (res.statusCode == 409 &&
        errorMessage == 'Request failed (409)') {
      errorMessage = 'Conflict error: The requested resource already exists.';
    }

    showAppToast(activeContext, errorMessage, type: AppNotificationType.error);

    return false;
  }

  /// Centralized exception handler for network timeouts and server offline issues.
  static void handleNetworkError([BuildContext? context]) {
    final activeContext = context ?? navigatorKey.currentContext;
    if (activeContext == null) return;
    showAppToast(
      activeContext,
      'Unable to connect to server. Please check your internet connection or server status.',
      type: AppNotificationType.error,
    );
  }

  /// Fetch admin audit logs from GET /admins/audit
  static Future<Map<String, dynamic>?> fetchAdminAuditLogs({
    required String adminToken,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.adminAuditEndpoint}?limit=$limit&offset=$offset',
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $adminToken'},
      );
      if (handleApiResponse(res, showToastOnError: false)) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else if (decoded is List) {
          return {'events': decoded, 'total': decoded.length};
        }
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Search a prize bond number in official gazette draw results via GET /bonds/draw-results/{denomination}/number/{bond_number}
  static Future<Map<String, dynamic>?> searchDrawResultsByNumber({
    required int denomination,
    required String bondNumber,
  }) async {
    try {
      final padded = bondNumber.trim().padLeft(6, '0');
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/bonds/draw-results/$denomination/number/$padded',
      );
      final res = await http.get(uri);
      if (handleApiResponse(res, showToastOnError: false)) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
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
      if (handleApiResponse(res, showToastOnError: false)) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Fetch upcoming draw schedule from GET /drawlists/schedule (Admin) or GET /user/drawlists/schedule (User)
  static Future<List<dynamic>?> fetchDrawSchedule({
    String? accessToken,
    bool isAdmin = false,
  }) async {
    try {
      final endpoint = isAdmin
          ? '/drawlists/schedule'
          : AppConfig.drawScheduleEndpoint;
      final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final headers = <String, String>{};
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
      final res = await http.get(uri, headers: headers);
      if (handleApiResponse(res, showToastOnError: false)) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data;
        } else if (data is Map<String, dynamic>) {
          return data['schedules'] ??
              data['draws'] ??
              data['results'] ??
              data['upcoming_draws'] ??
              data['data'] ??
              [];
        }
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Fetch available draw lists from GET /user/drawlists (User) or GET /drawlists (Admin)
  static Future<List<dynamic>?> fetchUserDrawlists(
    String accessToken, {
    bool isAdmin = false,
  }) async {
    try {
      final endpoint = isAdmin ? '/drawlists' : AppConfig.userDrawlistsEndpoint;
      final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (handleApiResponse(res, showToastOnError: false)) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data;
        } else if (data is Map<String, dynamic>) {
          return data['drawlists'] ?? data['draws'] ?? data['results'] ?? [];
        }
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Fetch winning bonds and prize details for a draw
  static Future<Map<String, dynamic>?> fetchUserDrawlistBonds({
    required String accessToken,
    required String drawId,
    bool isAdmin = false,
  }) async {
    try {
      final endpoint = isAdmin
          ? '/drawlists/$drawId/bonds'
          : '${AppConfig.userDrawlistsEndpoint}/$drawId/bonds';
      final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (handleApiResponse(res, showToastOnError: false)) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Download PDF gazette for a draw
  static Future<http.Response?> downloadUserDrawlistPdf({
    required String accessToken,
    required String drawId,
    bool isAdmin = false,
  }) async {
    try {
      final endpoint = isAdmin
          ? '/drawlists/$drawId/pdf'
          : '${AppConfig.userDrawlistsEndpoint}/$drawId/pdf';
      final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (handleApiResponse(res, showToastOnError: true)) {
        return res;
      }
      return res;
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Fetch all marketplace listings from GET /user/market/listings
  static Future<List<dynamic>?> fetchMarketListings(String accessToken) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.marketListingsEndpoint}',
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (handleApiResponse(res, showToastOnError: false)) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data;
        } else if (data is Map<String, dynamic>) {
          return data['listings'] ?? data['market'] ?? [];
        }
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Fetch all marketplace listings for admin from GET /admins/market/listings
  static Future<List<dynamic>?> fetchAdminMarketListings(
    String accessToken,
  ) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/admins/market/listings');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (handleApiResponse(res, showToastOnError: false)) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return data['listings'] as List? ?? [];
        } else if (data is List) {
          return data;
        }
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Delete a marketplace listing as an admin with removal reason via DELETE /admins/market/listings/{listing_id}
  static Future<http.Response> deleteAdminMarketListing({
    required String accessToken,
    required String listingId,
    required String reason,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/admins/market/listings/$listingId',
      );
      final res = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Create a new marketplace listing via POST /user/market/listings
  static Future<http.Response> createMarketListing({
    required String accessToken,
    required String title,
    required int price,
    required String category, // 'buy' or 'sell'
    String? description,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.marketListingsEndpoint}',
      );
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'price': price,
          'category': category,
          'description': description,
        }),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Update an existing marketplace listing via PATCH /user/market/listings/{listing_id}
  static Future<http.Response> updateMarketListing({
    required String accessToken,
    required String listingId,
    String? title,
    int? price,
    String? category,
    String? description,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.marketListingsEndpoint}/$listingId',
      );
      final payload = <String, dynamic>{};
      if (title != null) payload['title'] = title;
      if (price != null) payload['price'] = price;
      if (category != null) payload['category'] = category;
      if (description != null) payload['description'] = description;

      final res = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Delete a marketplace listing via DELETE /user/market/listings/{listing_id}
  static Future<http.Response> deleteMarketListing({
    required String accessToken,
    required String listingId,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.marketListingsEndpoint}/$listingId',
      );
      final res = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
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
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
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
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Delete an imported gazette drawlist via DELETE /drawlists/{draw_id}
  static Future<http.Response> deleteDrawlist({
    required String accessToken,
    required String drawId,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/drawlists/$drawId');
      final res = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Delete an upcoming draw schedule via DELETE /drawlists/schedule/{denomination}/{draw_date}
  static Future<http.Response> deleteDrawSchedule({
    required String accessToken,
    required int denomination,
    required String drawDate,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/drawlists/schedule/$denomination/$drawDate',
      );
      final res = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Add a new upcoming draw schedule via POST /drawlists/schedule
  static Future<http.Response> addDrawSchedule({
    required String accessToken,
    required int denomination,
    required String drawDate,
    String? location,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/drawlists/schedule');
      final body = <String, dynamic>{
        'denomination': denomination,
        'draw_date': drawDate,
      };
      if (location != null && location.trim().isNotEmpty) {
        body['location'] = location.trim();
      }
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Import a new gazette drawlist via POST /drawlists
  static Future<http.Response> importDrawlist({
    required String accessToken,
    required int denomination,
    required String drawDate,
    required List<String> firstPrizeBonds,
    required List<String> secondPrizeBonds,
    required List<String> thirdPrizeBonds,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/drawlists');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'denomination': denomination,
          'draw_date': drawDate,
          'first_prize_numbers': firstPrizeBonds,
          'second_prize_numbers': secondPrizeBonds,
          'third_prize_numbers': thirdPrizeBonds,
        }),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Add a winning bond number to an existing gazette drawlist via POST /drawlists/{draw_id}/bonds
  static Future<http.Response> addDrawWinner({
    required String accessToken,
    required String drawId,
    required String bondNumber,
    required int prizePosition,
    required int prizeAmount,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/drawlists/$drawId/bonds');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bond_number': bondNumber,
          'prize_position': prizePosition,
          'prize_amount': prizeAmount,
        }),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Update a winning bond entry in a gazette drawlist via PATCH /drawlists/{draw_id}/bonds/{bond_number}
  static Future<http.Response> updateDrawWinner({
    required String accessToken,
    required String drawId,
    required String bondNumber,
    String? newBondNumber,
    int? prizePosition,
    int? prizeAmount,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/drawlists/$drawId/bonds/$bondNumber',
      );
      final body = <String, dynamic>{};
      if (newBondNumber != null && newBondNumber.trim().isNotEmpty) {
        body['new_bond_number'] = newBondNumber.trim();
      }
      if (prizePosition != null) {
        body['prize_position'] = prizePosition;
      }
      if (prizeAmount != null) {
        body['prize_amount'] = prizeAmount;
      }

      final res = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Remove a winning bond entry from a gazette drawlist via DELETE /drawlists/{draw_id}/bonds/{bond_number}
  static Future<http.Response> deleteDrawWinner({
    required String accessToken,
    required String drawId,
    required String bondNumber,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/drawlists/$drawId/bonds/$bondNumber',
      );
      final res = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
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
      if (handleApiResponse(res, showToastOnError: false)) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      handleNetworkError();
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
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Fetch user support reports from GET /user/reports
  static Future<List<dynamic>?> fetchUserReports(String accessToken) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/user/reports');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (handleApiResponse(res, showToastOnError: false)) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Create a new support report ticket via POST /user/reports
  static Future<http.Response> createUserReport({
    required String accessToken,
    required String subject,
    required String category,
    required String content,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/user/reports');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'subject': subject,
          'category': category,
          'content': content,
        }),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Fetch chat message thread for a report ticket
  static Future<List<dynamic>?> fetchReportMessages({
    required String accessToken,
    required String reportId,
    bool isAdmin = false,
  }) async {
    try {
      final base = isAdmin ? '/admins/reports' : '/user/reports';
      final uri = Uri.parse('${AppConfig.baseUrl}$base/$reportId/messages');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (handleApiResponse(res, showToastOnError: false)) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Post a chat message in a report ticket thread
  static Future<http.Response> sendReportMessage({
    required String accessToken,
    required String reportId,
    required String message,
    bool isAdmin = false,
  }) async {
    try {
      final base = isAdmin ? '/admins/reports' : '/user/reports';
      final uri = Uri.parse('${AppConfig.baseUrl}$base/$reportId/messages');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message}),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }

  /// Fetch admin support reports from GET /admins/reports
  static Future<List<dynamic>?> fetchAdminReports({
    required String accessToken,
    String statusFilter = 'all',
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/admins/reports?status=$statusFilter',
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (handleApiResponse(res, showToastOnError: false)) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {
      handleNetworkError();
    }
    return null;
  }

  /// Update report ticket status via PATCH /admins/reports/{report_id}/status
  static Future<http.Response> updateReportStatus({
    required String accessToken,
    required String reportId,
    required String status,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/admins/reports/$reportId/status',
      );
      final res = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );
      handleApiResponse(res);
      return res;
    } catch (e) {
      handleNetworkError();
      rethrow;
    }
  }
}
