import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Handles perceptual hashing and SHA-256 combined hashing.
class HashService {
  /// Computes an average-hash (aHash) perceptual fingerprint of [imageFile].
  ///
  /// Steps:
  ///   1. Decode image
  ///   2. Resize to 8×9 (extra row needed for difference hash)
  ///   3. Convert to grayscale
  ///   4. Compute 8×8 difference hash (compare each pixel to its right neighbor)
  ///   5. Return as 16-char hex string (64 bits)
  Future<String> perceptualHash(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) throw Exception('Cannot decode image');

      // Resize to 9×8 for dHash
      final resized = img.copyResize(original, width: 9, height: 8);
      final gray = img.grayscale(resized);

      int hashValue = 0;
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final left = img.getLuminance(gray.getPixel(x, y));
          final right = img.getLuminance(gray.getPixel(x + 1, y));
          hashValue = (hashValue << 1) | (left < right ? 1 : 0);
        }
      }

      // Convert to 16-char hex (64-bit)
      return hashValue.toRadixString(16).padLeft(16, '0');
    } catch (e) {
      // Fallback: hash the raw bytes
      final bytes = await imageFile.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString().substring(0, 16);
    }
  }

  /// Computes SHA-256 of the canonical document string.
  /// [canonicalString] must be identical at issuance and checkpoint.
  Uint8List combinedHash(String canonicalString) {
    final bytes = utf8.encode(canonicalString);
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  /// Returns SHA-256 of [canonicalString] as hex string.
  String combinedHashHex(String canonicalString) {
    final bytes = utf8.encode(canonicalString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Computes Hamming distance between two 16-char hex perceptual hashes.
  /// Returns a similarity score between 0.0 (completely different) and 1.0 (identical).
  double compareHashes(String hashA, String hashB) {
    if (hashA.length != hashB.length) return 0.0;

    int diffBits = 0;
    try {
      final a = int.parse(hashA, radix: 16);
      final b = int.parse(hashB, radix: 16);
      int xor = a ^ b;
      // Count set bits (Hamming weight)
      while (xor > 0) {
        diffBits += xor & 1;
        xor >>= 1;
      }
    } catch (_) {
      return 0.0;
    }

    // 64 total bits; similarity = 1 - diffBits/64
    return 1.0 - (diffBits / 64.0);
  }

  /// Returns average luminance (0–255) of an 8×8 thumbnail.
  /// Used as a simplified "embedding" for face cross-check.
  Future<List<double>> simpleFaceEmbedding(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return List.filled(64, 0.0);

      final resized = img.copyResize(original, width: 8, height: 8);
      final result = <double>[];
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = resized.getPixel(x, y);
          result.add(img.getLuminance(pixel).toDouble());
        }
      }
      return result;
    } catch (_) {
      return List.filled(64, 0.0);
    }
  }

  /// Cosine similarity between two embedding vectors.
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }
}
