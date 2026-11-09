import 'package:http/http.dart' as http;

import '../../../../utils/api_service.dart';

class BondScanRepository {
  /// Submits confirmed denomination and 6-digit serial number to FastAPI backend.
  static Future<http.Response> submitScannedBond({
    required String accessToken,
    required int denomination,
    required String serialNumber,
  }) async {
    return await ApiService.addBonds(
      accessToken: accessToken,
      denomination: denomination,
      bonds: [serialNumber],
    );
  }
}
