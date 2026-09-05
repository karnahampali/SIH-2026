import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/issued_document.dart';
import '../models/scan_record.dart';

class StorageService {
  static const _docsBoxName = 'issued_documents';
  static const _scansBoxName = 'scan_records';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(IssuedDocumentAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ScanRecordAdapter());
    }

    // Open boxes
    await Hive.openBox<IssuedDocument>(_docsBoxName);
    await Hive.openBox<ScanRecord>(_scansBoxName);
  }

  Box<IssuedDocument> get _docsBox => Hive.box<IssuedDocument>(_docsBoxName);
  Box<ScanRecord> get _scansBox => Hive.box<ScanRecord>(_scansBoxName);

  // ─── Issued Documents ───────────────────────────────────────────────────────

  Future<void> saveDocument(IssuedDocument doc) async {
    await _docsBox.put(doc.id, doc);
  }

  IssuedDocument? getDocument(String id) {
    return _docsBox.get(id);
  }

  List<IssuedDocument> getAllDocuments() {
    return _docsBox.values.toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  Future<void> deleteDocument(String id) async {
    await _docsBox.delete(id);
  }

  // ─── Scan Records ────────────────────────────────────────────────────────────

  Future<void> saveScan(ScanRecord scan) async {
    await _scansBox.put(scan.id, scan);
  }

  ScanRecord? getScan(String id) {
    return _scansBox.get(id);
  }

  List<ScanRecord> getAllScans() {
    return _scansBox.values.toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  /// Finds scan records where the face embedding is close to records
  /// linked to a *different* document ID — the "multiple identities" flag.
  List<DuplicateFaceAlert> findDuplicateFaces({double threshold = 0.85}) {
    final scans = getAllScans();
    final alerts = <DuplicateFaceAlert>[];

    for (int i = 0; i < scans.length; i++) {
      for (int j = i + 1; j < scans.length; j++) {
        final a = scans[i];
        final b = scans[j];

        // Only flag if different document IDs
        if (a.documentId == b.documentId) continue;
        if (a.faceEmbedding.isEmpty || b.faceEmbedding.isEmpty) continue;

        try {
          final embA = (jsonDecode(a.faceEmbedding) as List).cast<double>();
          final embB = (jsonDecode(b.faceEmbedding) as List).cast<double>();
          final similarity = _cosineSimilarity(embA, embB);

          if (similarity >= threshold) {
            alerts.add(DuplicateFaceAlert(
              scanA: a,
              scanB: b,
              similarity: similarity,
            ));
          }
        } catch (_) {
          continue;
        }
      }
    }

    return alerts;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (_sqrt(normA) * _sqrt(normB));
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 50; i++) {
      g = (g + x / g) / 2;
    }
    return g;
  }
}

class DuplicateFaceAlert {
  final ScanRecord scanA;
  final ScanRecord scanB;
  final double similarity;

  DuplicateFaceAlert({
    required this.scanA,
    required this.scanB,
    required this.similarity,
  });
}
