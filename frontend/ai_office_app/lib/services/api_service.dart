import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.1.6:8000/api';

  // ─── PDF SUMMARIZATION ────────────────────────────────────────
  static Future<Map<String, dynamic>> summarizePdf(
      File pdfFile, {
        bool useMistral = false,
      }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/summarize-pdf?use_mistral=$useMistral'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', pdfFile.path),
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

  // ─── MEETING TRANSCRIBE ───────────────────────────────────
  // UPDATED: field name 'file' → 'audio' to match backend parameter
  // UPDATED: returns full Map (transcript + notes + language)
  static Future<Map<String, dynamic>> transcribeMeeting(File audioFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/transcribe-meeting'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path), // 'audio' not 'file'
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

  // ─── EMAIL GENERATE ───────────────────────────────────────
  // UPDATED: call_to_action → required_response (matches backend)
  // UPDATED: returns Map<String, dynamic> instead of String
  static Future<Map<String, dynamic>> generateEmail({
    required String purpose,
    required String recipientRole,
    required String tone,
    required List<String> keyPoints,
    required String requiredResponse,   // was callToAction
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'purpose':           purpose,
        'recipient_role':    recipientRole,
        'tone':              tone,
        'key_points':        keyPoints,          // still List<String> ✅
        'required_response': requiredResponse,   // was 'call_to_action'
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

  // ─── EXPORT: WORD (.docx) ────────────────────────────────
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

  // ─── EXPORT: PDF ─────────────────────────────────────────
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