import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class SerialOcrResult {
  final String? primarySerial;
  final List<String> candidates;
  final String rawText;
  final double confidence;

  const SerialOcrResult({
    this.primarySerial,
    this.candidates = const [],
    required this.rawText,
    this.confidence = 0.0,
  });
}

class SerialOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Process image file and extract serial number candidates.
  Future<SerialOcrResult> processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      final String rawText = recognizedText.text;
      final Set<String> candidates = {};

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final String cleaned = _cleanAndNormalize(line.text);
          final String? serial = _extract6DigitSerial(cleaned);
          if (serial != null) {
            candidates.add(serial);
          }
        }
      }

      // Fallback: search entire raw text block
      if (candidates.isEmpty) {
        final lines = rawText.split('\n');
        for (final l in lines) {
          final s = _extract6DigitSerial(_cleanAndNormalize(l));
          if (s != null) candidates.add(s);
        }
      }

      final candidateList = candidates.toList();
      String? primary;
      double confidence = 0.0;

      if (candidateList.isNotEmpty) {
        primary = candidateList.first;
        confidence = candidateList.length == 1 ? 0.95 : 0.80;
      }

      return SerialOcrResult(
        primarySerial: primary,
        candidates: candidateList,
        rawText: rawText,
        confidence: confidence,
      );
    } catch (_) {
      return const SerialOcrResult(rawText: '');
    }
  }

  /// Replaces common OCR letter-to-digit mistakes.
  String _cleanAndNormalize(String text) {
    var s = text.trim();
    s = s.replaceAll('O', '0').replaceAll('o', '0');
    s = s.replaceAll('I', '1').replaceAll('l', '1').replaceAll('|', '1');
    s = s.replaceAll('S', '5').replaceAll('s', '5');
    s = s.replaceAll('B', '8');
    s = s.replaceAll('Z', '2').replaceAll('z', '2');
    s = s.replaceAll(RegExp(r'[^0-9]'), '');
    return s;
  }

  /// Extracts or pads a 6-digit serial number.
  String? _extract6DigitSerial(String digitsOnly) {
    if (digitsOnly.length == 6) {
      return digitsOnly;
    }
    if (digitsOnly.length >= 4 && digitsOnly.length < 6) {
      return digitsOnly.padLeft(6, '0');
    }
    if (digitsOnly.length > 6) {
      final match = RegExp(r'\d{6}').firstMatch(digitsOnly);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
