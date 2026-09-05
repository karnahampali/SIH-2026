import 'package:hive/hive.dart';

part 'issued_document.g.dart';

@HiveType(typeId: 0)
class IssuedDocument extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String dob; // ISO 8601 date string

  @HiveField(3)
  late String idNumber;

  @HiveField(4)
  late String nationality;

  @HiveField(5)
  late String expiry; // ISO 8601 date string

  @HiveField(6)
  late String docType; // Passport, Visa, National ID

  @HiveField(7)
  late String photoPath; // absolute local file path

  @HiveField(8)
  late String photoHash; // perceptual average-hash (hex)

  @HiveField(9)
  late String combinedHash; // SHA-256 hex of all fields + photoHash

  @HiveField(10)
  late String signature; // Ed25519 signature (base64)

  @HiveField(11)
  late String publicKeyBase64; // issuer public key (base64)

  @HiveField(12)
  late DateTime issuedAt;

  @HiveField(13)
  late String issuingAuthority;

  // Constructed for display
  String get displayId => id.substring(0, 8).toUpperCase();

  IssuedDocument();

  factory IssuedDocument.create({
    required String id,
    required String name,
    required String dob,
    required String idNumber,
    required String nationality,
    required String expiry,
    required String docType,
    required String photoPath,
    required String photoHash,
    required String combinedHash,
    required String signature,
    required String publicKeyBase64,
    String issuingAuthority = 'Ministry of External Affairs',
  }) {
    return IssuedDocument()
      ..id = id
      ..name = name
      ..dob = dob
      ..idNumber = idNumber
      ..nationality = nationality
      ..expiry = expiry
      ..docType = docType
      ..photoPath = photoPath
      ..photoHash = photoHash
      ..combinedHash = combinedHash
      ..signature = signature
      ..publicKeyBase64 = publicKeyBase64
      ..issuedAt = DateTime.now()
      ..issuingAuthority = issuingAuthority;
  }

  /// Canonical string used for signing/verification.
  /// MUST be identical at issuance and checkpoint.
  String get canonicalString =>
      '$name|$dob|$idNumber|$nationality|$expiry|$docType|$photoHash';

  /// Returns a map of all display fields
  Map<String, String> get displayFields => {
        'Full Name': name,
        'Date of Birth': dob,
        'Document Number': idNumber,
        'Nationality': nationality,
        'Expiry Date': expiry,
        'Document Type': docType,
        'Issuing Authority': issuingAuthority,
        'Issued At': issuedAt.toLocal().toString().substring(0, 10),
        'Record ID': displayId,
      };
}
