import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your PC's local IP address
  static const String baseUrl = 'http://192.168.1.8:8000/api';

  // ─── PDF SUMMARIZE ────────────────────────────────────────
  // UNCHANGED — already returns Map<String, dynamic> ✅
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
  // UNCHANGED ✅
  static Future<Map<String, dynamic>> transcribeMeeting(File audioFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/transcribe-meeting'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', audioFile.path),
    );
    var response = await request.send();
    var body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(body);
      throw Exception(error['detail'] ?? 'Meeting transcription failed');
    }
  }

  // ─── EMAIL GENERATE ───────────────────────────────────────
  // UNCHANGED ✅
  static Future<String> generateEmail({
    required String purpose,
    required String recipientRole,
    required String tone,
    required List<String> keyPoints,
    required String callToAction,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'purpose': purpose,
        'recipient_role': recipientRole,
        'tone': tone,
        'key_points': keyPoints,
        'call_to_action': callToAction,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['email'] as String;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Email generation failed');
    }
  }

  // ─── EXPORT: WORD (.docx) ─────────────────────────────────
  // NEW — calls /api/export/word, returns raw bytes for saving
  static Future<List<int>> exportAsWord({
    required String summary,
    required String filename,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/export/word'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'summary': summary,
        'filename': filename,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return response.bodyBytes; // raw .docx bytes → save to file
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Word export failed');
    }
  }

  // ─── EXPORT: PDF ──────────────────────────────────────────
  // NEW — calls /api/export/pdf, returns raw bytes for saving
  static Future<List<int>> exportAsPdf({
    required String summary,
    required String filename,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/export/pdf'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'summary': summary,
        'filename': filename,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      return response.bodyBytes; // raw .pdf bytes → save to file
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'PDF export failed');
    }
  }
}