import 'package:hive/hive.dart';

part 'scan_record.g.dart';

@HiveType(typeId: 1)
class ScanRecord extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String documentId;

  @HiveField(2)
  late DateTime scannedAt;

  @HiveField(3)
  late String officerNote;

  // Module results (0.0 = fail, 1.0 = pass)
  @HiveField(4)
  late double docIntegrityScore; // signature check

  @HiveField(5)
  late double photoMatchScore; // perceptual hash match

  @HiveField(6)
  late double faceMatchScore; // live face vs stored photo

  @HiveField(7)
  late double livenessScore; // liveness heuristic

  @HiveField(8)
  late double dbStatusScore; // identity history check

  // Composite
  @HiveField(9)
  late double riskScore; // 0–100

  @HiveField(10)
  late String riskLevel; // LOW / MEDIUM / HIGH / CRITICAL

  @HiveField(11)
  late String action; // APPROVED / FLAGGED / PENDING

  // Per-module reasons (plain-language strings)
  @HiveField(12)
  late String docIntegrityReason;

  @HiveField(13)
  late String photoMatchReason;

  @HiveField(14)
  late String faceMatchReason;

  @HiveField(15)
  late String livenessReason;

  @HiveField(16)
  late String dbStatusReason;

  @HiveField(17)
  late String liveFacePhotoPath;

  /// Face "embedding" (simplified: average RGB of face crop, stored as csv)
  @HiveField(18)
  late String faceEmbedding;

  @HiveField(19)
  late String documentName; // denormalized for display

  @HiveField(20)
  late String documentType;

  ScanRecord();

  String get displayId => id.substring(0, 8).toUpperCase();

  bool get isApproved => action == 'APPROVED';
  bool get isFlagged => action == 'FLAGGED';
}
