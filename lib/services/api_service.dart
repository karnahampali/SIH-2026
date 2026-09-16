import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class VerificationSession {
  static String documentId = '';
  static String ocrText = '';
  static String documentPhotoPath = '';
  static String facePhotoPath = '';
  static Map<String, dynamic> result = <String, dynamic>{};

  static void start({
    required String id,
    required String text,
    required String photoPath,
    required Map<String, dynamic> report,
  }) {
    documentId = id;
    ocrText = text;
    documentPhotoPath = photoPath;
    facePhotoPath = '';
    result = Map<String, dynamic>.from(report);
  }
}

class ApiService {
  static String get baseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: '',
      ).isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : Platform.isAndroid
          ? 'http://127.0.0.1:8000'
          : 'http://127.0.0.1:8000';

  Future<String> _sendMultipart(http.MultipartRequest request) async {
    final response = await request.send();
    final bytes = await response.stream.toBytes();
    final body = utf8.decode(bytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = body;
      try {
        final decoded = json.decode(body);
        detail = decoded['detail']?.toString() ?? body;
      } catch (_) {}
      throw Exception('Server error ${response.statusCode}: $detail');
    }
    return body;
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final safeBody = body
        .replaceAll('-Infinity', 'null')
        .replaceAll('Infinity', 'null')
        .replaceAll('NaN', 'null');
    final decoded = json.decode(safeBody);
    if (decoded is! Map) {
      throw const FormatException('Backend returned a non-object response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> verifyDocument(String imagePath) async {
    final uri = Uri.parse('$baseUrl/api/v1/verify');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

    try {
      final body = await _sendMultipart(request);
      return _decodeResponse(body);
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  Future<Map<String, dynamic>> verifyFromImage(String imagePath) async {
    final uri = Uri.parse('$baseUrl/api/v1/verify_from_image');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

    try {
      await http.get(Uri.parse('$baseUrl/api/v1/health')).timeout(
        const Duration(seconds: 5),
      );
      final body = await _sendMultipart(request);
      return _decodeResponse(body);
    } on TimeoutException {
      throw Exception('Backend did not respond. Check that start.bat is running and API_BASE_URL is correct.');
    } on SocketException {
      throw Exception('Cannot reach backend at $baseUrl. Start the API or set API_BASE_URL to the laptop LAN address.');
    } catch (e) {
      throw Exception('Failed to verify document: $e');
    }
  }

  Future<Map<String, dynamic>> registerFromImage(String imagePath, {String identityKey = ''}) async {
    final uri = Uri.parse('$baseUrl/api/v1/register_from_image');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    try {
      if (identityKey.isNotEmpty) {
        request.headers['X-Identity-Key'] = identityKey;
      }
      final body = await _sendMultipart(request);
      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to register identity: $e');
    }
  }

  Future<Map<String, dynamic>> compareFaces(String idPhotoPath, String selfiePath) async {
    final uri = Uri.parse('$baseUrl/api/v1/compare_faces');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('id_photo', idPhotoPath, contentType: MediaType('image', 'jpeg')))
      ..files.add(await http.MultipartFile.fromPath('selfie', selfiePath, contentType: MediaType('image', 'jpeg')));
    try {
      final body = await _sendMultipart(request);
      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to compare faces: $e');
    }
  }

  Future<Map<String, dynamic>> registerIdentity(String documentHash, String issuerSignature) async {
    final uri = Uri.parse('$baseUrl/api/v1/register_identity');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'document_hash': documentHash,
          'issuer_signature': issuerSignature,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to register identity: $e');
    }
  }

  Future<Map<String, dynamic>> verifyIdentityHash(String documentHash) async {
    final uri = Uri.parse('$baseUrl/api/v1/verify_identity_hash');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'document_hash': documentHash,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to verify identity hash: $e');
    }
  }
}
