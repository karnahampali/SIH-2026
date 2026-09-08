import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Using 127.0.0.1 because we have an adb reverse proxy script keeping it alive!
  static const String baseUrl = 'http://127.0.0.1:8000';

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
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        throw Exception('Server error: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }
}
