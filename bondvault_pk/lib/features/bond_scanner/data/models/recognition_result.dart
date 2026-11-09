enum RecognitionStatus { success, partial, uncertain, failed }

class RecognitionResult {
  final String imagePath;
  final int? detectedDenomination;
  final double denominationConfidence; // 0.0 to 1.0
  final String? detectedSerial;
  final double serialConfidence; // 0.0 to 1.0
  final List<String> serialCandidates;
  final RecognitionStatus status;
  final String? errorMessage;
  final bool requiresManualConfirmation;

  const RecognitionResult({
    required this.imagePath,
    this.detectedDenomination,
    this.denominationConfidence = 0.0,
    this.detectedSerial,
    this.serialConfidence = 0.0,
    this.serialCandidates = const [],
    this.status = RecognitionStatus.uncertain,
    this.errorMessage,
    this.requiresManualConfirmation = true,
  });

  bool get isSuccessful =>
      detectedDenomination != null &&
      detectedSerial != null &&
      detectedSerial!.length == 6;

  RecognitionResult copyWith({
    String? imagePath,
    int? detectedDenomination,
    double? denominationConfidence,
    String? detectedSerial,
    double? serialConfidence,
    List<String>? serialCandidates,
    RecognitionStatus? status,
    String? errorMessage,
    bool? requiresManualConfirmation,
  }) {
    return RecognitionResult(
      imagePath: imagePath ?? this.imagePath,
      detectedDenomination: detectedDenomination ?? this.detectedDenomination,
      denominationConfidence:
          denominationConfidence ?? this.denominationConfidence,
      detectedSerial: detectedSerial ?? this.detectedSerial,
      serialConfidence: serialConfidence ?? this.serialConfidence,
      serialCandidates: serialCandidates ?? this.serialCandidates,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      requiresManualConfirmation:
          requiresManualConfirmation ?? this.requiresManualConfirmation,
    );
  }
}
