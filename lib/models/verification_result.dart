import '../widgets/pramaan_theme.dart';

/// Plain (non-Hive) model representing a full verification result.
class VerificationResult {
  final String documentId;
  final String documentName;
  final String documentType;

  // Module scores (0.0–1.0, where 1.0 = fully passing)
  final double docIntegrityScore;
  final double photoMatchScore;
  final double faceMatchScore;
  final double livenessScore;
  final double dbStatusScore;

  // Module reasons (plain language)
  final String docIntegrityReason;
  final String photoMatchReason;
  final String faceMatchReason;
  final String livenessReason;
  final String dbStatusReason;

  // Composite risk
  final double riskScore;
  final RiskLevel riskLevel;

  // Metadata
  final String liveFacePhotoPath;
  final String faceEmbedding;
  final DateTime verifiedAt;

  VerificationResult({
    required this.documentId,
    required this.documentName,
    required this.documentType,
    required this.docIntegrityScore,
    required this.photoMatchScore,
    required this.faceMatchScore,
    required this.livenessScore,
    required this.dbStatusScore,
    required this.docIntegrityReason,
    required this.photoMatchReason,
    required this.faceMatchReason,
    required this.livenessReason,
    required this.dbStatusReason,
    required this.liveFacePhotoPath,
    required this.faceEmbedding,
    DateTime? verifiedAt,
  })  : riskScore = _computeRisk(
          docIntegrityScore,
          photoMatchScore,
          faceMatchScore,
          livenessScore,
          dbStatusScore,
        ),
        riskLevel = RiskLevelExt.fromScore(
          _computeRisk(
            docIntegrityScore,
            photoMatchScore,
            faceMatchScore,
            livenessScore,
            dbStatusScore,
          ),
        ),
        verifiedAt = verifiedAt ?? DateTime.now();

  /// risk = 25×(1−doc) + 25×(1−photo) + 25×(1−face) + 15×(1−db) + 10×(1−liveness)
  static double _computeRisk(
    double doc,
    double photo,
    double face,
    double liveness,
    double db,
  ) {
    final risk = 25 * (1 - doc.clamp(0.0, 1.0)) +
        25 * (1 - photo.clamp(0.0, 1.0)) +
        25 * (1 - face.clamp(0.0, 1.0)) +
        15 * (1 - db.clamp(0.0, 1.0)) +
        10 * (1 - liveness.clamp(0.0, 1.0));
    return risk.clamp(0.0, 100.0);
  }

  List<ModuleResult> get modules => [
        ModuleResult(
          name: 'Document Signature',
          icon: 'document',
          score: docIntegrityScore,
          reason: docIntegrityReason,
          weight: 25,
        ),
        ModuleResult(
          name: 'Photo Fingerprint',
          icon: 'fingerprint',
          score: photoMatchScore,
          reason: photoMatchReason,
          weight: 25,
        ),
        ModuleResult(
          name: 'Face Match',
          icon: 'face',
          score: faceMatchScore,
          reason: faceMatchReason,
          weight: 25,
        ),
        ModuleResult(
          name: 'Identity History',
          icon: 'database',
          score: dbStatusScore,
          reason: dbStatusReason,
          weight: 15,
        ),
        ModuleResult(
          name: 'Liveness Check',
          icon: 'liveness',
          score: livenessScore,
          reason: livenessReason,
          weight: 10,
        ),
      ];
}

class ModuleResult {
  final String name;
  final String icon;
  final double score; // 0.0–1.0
  final String reason;
  final int weight; // percentage weight in risk formula

  ModuleResult({
    required this.name,
    required this.icon,
    required this.score,
    required this.reason,
    required this.weight,
  });

  bool get passed => score >= 0.6;

  String get scorePercent => '${(score * 100).toStringAsFixed(0)}%';
}
