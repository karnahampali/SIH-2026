import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/crypto_service.dart';
import 'services/face_service.dart';
import 'services/hash_service.dart';
import 'services/storage_service.dart';
import 'services/verification_service.dart';
import 'services/api_service.dart';

// ─── Service Providers ────────────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final hashServiceProvider = Provider<HashService>((ref) {
  return HashService();
});

final faceServiceProvider = Provider<FaceService>((ref) {
  final service = FaceService();
  ref.onDispose(() => service.dispose());
  return service;
});

final verificationServiceProvider = Provider((ref) {
  return VerificationService(
    ref.read(cryptoServiceProvider),
    ref.read(hashServiceProvider),
    ref.read(faceServiceProvider),
    ref.read(storageServiceProvider),
  );
});

// ─── App State Providers ──────────────────────────────────────────────────────

/// Issued documents list
final issuedDocumentsProvider = StateNotifierProvider<IssuedDocumentsNotifier, AsyncValue<List>>(
  (ref) => IssuedDocumentsNotifier(ref.watch(storageServiceProvider)),
);

class IssuedDocumentsNotifier extends StateNotifier<AsyncValue<List>> {
  final StorageService _storage;

  IssuedDocumentsNotifier(this._storage) : super(const AsyncValue.loading()) {
    load();
  }

  void load() {
    state = AsyncValue.data(_storage.getAllDocuments());
  }

  Future<void> refresh() async {
    load();
  }
}

/// Current issuance form data (passed between issuance flow screens)
class IssuanceFormData {
  final String name;
  final String dob;
  final String idNumber;
  final String nationality;
  final String expiry;
  final String docType;
  final String? photoPath;

  IssuanceFormData({
    this.name = '',
    this.dob = '',
    this.idNumber = '',
    this.nationality = '',
    this.expiry = '',
    this.docType = 'Passport',
    this.photoPath,
  });

  IssuanceFormData copyWith({
    String? name,
    String? dob,
    String? idNumber,
    String? nationality,
    String? expiry,
    String? docType,
    String? photoPath,
  }) {
    return IssuanceFormData(
      name: name ?? this.name,
      dob: dob ?? this.dob,
      idNumber: idNumber ?? this.idNumber,
      nationality: nationality ?? this.nationality,
      expiry: expiry ?? this.expiry,
      docType: docType ?? this.docType,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  bool get isComplete =>
      name.isNotEmpty &&
      dob.isNotEmpty &&
      idNumber.isNotEmpty &&
      nationality.isNotEmpty &&
      expiry.isNotEmpty &&
      photoPath != null;
}

final issuanceFormProvider = StateNotifierProvider<IssuanceFormNotifier, IssuanceFormData>(
  (ref) => IssuanceFormNotifier(),
);

class IssuanceFormNotifier extends StateNotifier<IssuanceFormData> {
  IssuanceFormNotifier() : super(IssuanceFormData());

  void update(IssuanceFormData data) => state = data;
  void reset() => state = IssuanceFormData();
}
