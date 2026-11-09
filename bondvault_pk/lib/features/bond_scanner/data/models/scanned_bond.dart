class ScannedBond {
  final String id;
  final int denomination;
  final String serialNumber;
  final DateTime scannedAt;
  final String imagePath;
  final bool isVerifiedByBackend;

  ScannedBond({
    required this.id,
    required this.denomination,
    required this.serialNumber,
    required this.scannedAt,
    required this.imagePath,
    this.isVerifiedByBackend = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'denomination': denomination,
    'serial_number': serialNumber,
    'scanned_at': scannedAt.toIso8601String(),
    'image_path': imagePath,
    'is_verified': isVerifiedByBackend,
  };

  factory ScannedBond.fromJson(Map<String, dynamic> json) => ScannedBond(
    id: json['id'] ?? '',
    denomination: json['denomination'] as int? ?? 100,
    serialNumber: json['serial_number'] ?? '',
    scannedAt: DateTime.tryParse(json['scanned_at'] ?? '') ?? DateTime.now(),
    imagePath: json['image_path'] ?? '',
    isVerifiedByBackend: json['is_verified'] == true,
  );
}
