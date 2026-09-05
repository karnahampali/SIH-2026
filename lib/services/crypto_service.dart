import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles Ed25519 key generation, signing, and verification.
class CryptoService {
  static const _privateKeyStorageKey = 'pramaan_ed25519_private_key';
  static const _publicKeyStorageKey = 'pramaan_ed25519_public_key';

  final _algo = Ed25519();
  final _secureStorage = const FlutterSecureStorage();

  SimpleKeyPair? _cachedKeyPair;

  /// Returns the issuer key pair (generates once, persists in secure storage).
  Future<SimpleKeyPair> getOrCreateKeyPair() async {
    if (_cachedKeyPair != null) return _cachedKeyPair!;

    // Try to load from secure storage
    final storedPrivate = await _secureStorage.read(key: _privateKeyStorageKey);
    final storedPublic = await _secureStorage.read(key: _publicKeyStorageKey);

    if (storedPrivate != null && storedPublic != null) {
      try {
        final privateBytes = base64Decode(storedPrivate);
        final publicBytes = base64Decode(storedPublic);
        _cachedKeyPair = SimpleKeyPairData(
          privateBytes,
          publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
          type: KeyPairType.ed25519,
        );
        return _cachedKeyPair!;
      } catch (_) {
        // Fall through to generate a new key pair
      }
    }

    // Generate new key pair
    _cachedKeyPair = await _algo.newKeyPair();

    // Persist
    final privateBytes = await _cachedKeyPair!.extractPrivateKeyBytes();
    final publicKey = await _cachedKeyPair!.extractPublicKey();

    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(privateBytes),
    );
    await _secureStorage.write(
      key: _publicKeyStorageKey,
      value: base64Encode(publicKey.bytes),
    );

    return _cachedKeyPair!;
  }

  /// Returns the issuer public key as base64.
  Future<String> getPublicKeyBase64() async {
    final kp = await getOrCreateKeyPair();
    final pk = await kp.extractPublicKey();
    return base64Encode(pk.bytes);
  }

  /// Signs [data] with the issuer private key.
  /// Returns the signature as a base64 string.
  Future<String> sign(Uint8List data) async {
    final kp = await getOrCreateKeyPair();
    final sig = await _algo.sign(data, keyPair: kp);
    return base64Encode(sig.bytes);
  }

  /// Verifies [signatureBase64] over [data] using [publicKeyBase64].
  Future<bool> verify(
    Uint8List data,
    String signatureBase64,
    String publicKeyBase64,
  ) async {
    try {
      final sigBytes = base64Decode(signatureBase64);
      final pkBytes = base64Decode(publicKeyBase64);
      final pk = SimplePublicKey(pkBytes, type: KeyPairType.ed25519);
      final sig = Signature(sigBytes, publicKey: pk);
      return await _algo.verify(data, signature: sig);
    } catch (e) {
      return false;
    }
  }
}
