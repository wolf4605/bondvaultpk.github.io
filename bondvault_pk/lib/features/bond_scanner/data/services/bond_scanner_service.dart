import 'dart:io';

import '../models/recognition_result.dart';
import 'denomination_detector.dart';
import 'image_processor.dart';
import 'serial_ocr_service.dart';

class BondScannerService {
  final SerialOcrService _ocrService = SerialOcrService();

  /// Runs the entire recognition pipeline on a captured photograph file.
  Future<RecognitionResult> scanBond(File imageFile) async {
    final isValid = await ImageProcessor.validateImage(imageFile);
    if (!isValid) {
      return RecognitionResult(
        imagePath: imageFile.path,
        status: RecognitionStatus.failed,
        errorMessage: 'Invalid or corrupt image file.',
        requiresManualConfirmation: true,
      );
    }

    final ocrResult = await _ocrService.processImage(imageFile);
    final denomResult = DenominationDetector.detect(rawText: ocrResult.rawText);

    RecognitionStatus status;
    if (denomResult.denomination != null && ocrResult.primarySerial != null) {
      status = RecognitionStatus.success;
    } else if (denomResult.denomination != null ||
        ocrResult.primarySerial != null) {
      status = RecognitionStatus.partial;
    } else {
      status = RecognitionStatus.uncertain;
    }

    return RecognitionResult(
      imagePath: imageFile.path,
      detectedDenomination: denomResult.denomination,
      denominationConfidence: denomResult.confidence,
      detectedSerial: ocrResult.primarySerial,
      serialConfidence: ocrResult.confidence,
      serialCandidates: ocrResult.candidates,
      status: status,
      requiresManualConfirmation: true,
    );
  }

  Future<void> dispose() async {
    await _ocrService.dispose();
  }
}
