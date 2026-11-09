class DenominationResult {
  final int? denomination;
  final double confidence; // 0.0 to 1.0
  final String method;

  const DenominationResult({
    this.denomination,
    this.confidence = 0.0,
    required this.method,
  });
}

class DenominationDetector {
  static const List<int> validDenominations = [
    100,
    200,
    750,
    1500,
    25000,
    40000,
  ];

  /// Detects prize bond denomination from OCR text & color analysis.
  static DenominationResult detect({required String rawText}) {
    final cleanText = rawText.toUpperCase();

    // Word patterns
    if (cleanText.contains('ONE HUNDRED') || cleanText.contains('100')) {
      return const DenominationResult(
        denomination: 100,
        confidence: 0.95,
        method: 'ocr_text',
      );
    }
    if (cleanText.contains('TWO HUNDRED') || cleanText.contains('200')) {
      return const DenominationResult(
        denomination: 200,
        confidence: 0.95,
        method: 'ocr_text',
      );
    }
    if (cleanText.contains('SEVEN HUNDRED FIFTY') ||
        cleanText.contains('SEVEN HUNDRED') ||
        cleanText.contains('750')) {
      return const DenominationResult(
        denomination: 750,
        confidence: 0.95,
        method: 'ocr_text',
      );
    }
    if (cleanText.contains('FIFTEEN HUNDRED') || cleanText.contains('1500')) {
      return const DenominationResult(
        denomination: 1500,
        confidence: 0.95,
        method: 'ocr_text',
      );
    }
    if (cleanText.contains('TWENTY FIVE THOUSAND') ||
        cleanText.contains('TWENTY-FIVE THOUSAND') ||
        cleanText.contains('25000')) {
      return const DenominationResult(
        denomination: 25000,
        confidence: 0.95,
        method: 'ocr_text',
      );
    }
    if (cleanText.contains('FORTY THOUSAND') || cleanText.contains('40000')) {
      return const DenominationResult(
        denomination: 40000,
        confidence: 0.95,
        method: 'ocr_text',
      );
    }

    // Number matching in lines
    for (final denom in validDenominations) {
      if (cleanText.contains(denom.toString())) {
        return DenominationResult(
          denomination: denom,
          confidence: 0.80,
          method: 'ocr_text',
        );
      }
    }

    return const DenominationResult(
      denomination: null,
      confidence: 0.0,
      method: 'uncertain',
    );
  }
}
