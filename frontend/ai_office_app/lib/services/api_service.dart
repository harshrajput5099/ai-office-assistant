import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.1.6:8000/api';

  // ─── PDF SUMMARIZATION ────────────────────────────────────────
  static Future<Map<String, dynamic>> summarizePdf(
      Uint8List fileBytes,
      String fileName, {
        bool useMistral = false,
      }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/summarize-pdf?use_mistral=$useMistral'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );
    var response = await request.send();
    var body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(body);
      throw Exception(error['detail'] ?? 'PDF summarization failed');
    }
  }

  // ─── MEETING TRANSCRIBE ───────────────────────────────────────
  static Future<Map<String, dynamic>> transcribeMeeting(
      Uint8List audioBytes,
      String fileName,
      ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/transcribe-meeting'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('audio', audioBytes, filename: fileName),
    );
    var response = await request.send();
    var body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
      // Returns: { 'transcript': '...', 'notes': '...', 'language': 'en' }
    } else {
      final error = jsonDecode(body);
      throw Exception(error['detail'] ?? 'Meeting transcription failed');
    }
  }

  // ─── EMAIL GENERATE ───────────────────────────────────────────
  static Future<Map<String, dynamic>> generateEmail({
    required String purpose,
    required String recipientRole,
    required String tone,
    required List<String> keyPoints,
    required String requiredResponse,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'purpose':           purpose,
        'recipient_role':    recipientRole,
        'tone':              tone,
        'key_points':        keyPoints,
        'required_response': requiredResponse,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
      // Returns: { 'email': '...', 'tone': 'formal' }
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Email generation failed');
    }
  }

  // ─── EXPORT: WORD (.docx) ─────────────────────────────────────
  static Future<List<int>> exportAsWord({
    required String summary,
    required String filename,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/export/word'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'summary': summary, 'filename': filename}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Word export failed');
    }
  }

  // ─── EXPORT: PDF ──────────────────────────────────────────────
  static Future<List<int>> exportAsPdf({
    required String summary,
    required String filename,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/export/pdf'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'summary': summary, 'filename': filename}),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'PDF export failed');
    }
  }
}