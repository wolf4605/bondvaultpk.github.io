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

  /// Fetch user upcoming draw schedule from GET /user/drawlists/schedule
  static Future<List<dynamic>?> fetchDrawSchedule([String? accessToken]) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.drawScheduleEndpoint}',
      );
      final headers = <String, String>{};
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
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
      } else if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
    } catch (_) {
      showServiceUnavailable();
    }
    return null;
  }

  /// Fetch available user draw lists from GET /user/drawlists
  static Future<List<dynamic>?> fetchUserDrawlists(String accessToken) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.userDrawlistsEndpoint}',
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data;
        } else if (data is Map<String, dynamic>) {
          return data['drawlists'] ?? data['draws'] ?? data['results'] ?? [];
        }
      } else if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
    } catch (_) {
      showServiceUnavailable();
    }
    return null;
  }

  /// Fetch winning bonds and prize details for a draw from GET /user/drawlists/{draw_id}/bonds
  static Future<Map<String, dynamic>?> fetchUserDrawlistBonds({
    required String accessToken,
    required String drawId,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.userDrawlistsEndpoint}/$drawId/bonds',
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

  /// Download PDF gazette for a draw from GET /user/drawlists/{draw_id}/pdf
  static Future<http.Response?> downloadUserDrawlistPdf({
    required String accessToken,
    required String drawId,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.userDrawlistsEndpoint}/$drawId/pdf',
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
      return res;
    } catch (_) {
      showServiceUnavailable();
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
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data;
        } else if (data is Map<String, dynamic>) {
          return data['listings'] ?? data['market'] ?? [];
        }
      } else if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
    } catch (_) {
      showServiceUnavailable();
    }
    return null;
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
      if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
      return res;
    } catch (e) {
      showServiceUnavailable();
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
      if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
      return res;
    } catch (e) {
      showServiceUnavailable();
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
      if (res.statusCode >= 500 || res.statusCode == 503) {
        showServiceUnavailable();
      }
      return res;
    } catch (e) {
      showServiceUnavailable();
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
