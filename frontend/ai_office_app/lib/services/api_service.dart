import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api';       // Chrome / web browser
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';        // Android emulator
    }
    return 'http://192.168.1.8:8000/api';       // Real phone on WiFi
  }

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

  // ─── HISTORY ──────────────────────────────────────────────────
  static Future<List<dynamic>> getHistory() async {
    final headers = await AuthService.authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/history'),
      headers: headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as List;
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to load history');
  }

  static Future<void> addHistory({
    required String type,
    required String title,
    required String content,
  }) async {
    final headers = await AuthService.authHeaders();
    await http.post(
      Uri.parse('$baseUrl/history'),
      headers: headers,
      body: jsonEncode({'type': type, 'title': title, 'content': content}),
    );
  }

  static Future<void> deleteHistory(int id) async {
    final headers = await AuthService.authHeaders();
    await http.delete(
      Uri.parse('$baseUrl/history/$id'),
      headers: headers,
    );
  }

  // ─── SETTINGS ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSettings() async {
    final headers = await AuthService.authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/settings'), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load settings');
  }

  static Future<void> updateTheme(String theme) async {
    final headers = await AuthService.authHeaders();
    await http.post(
      Uri.parse('$baseUrl/settings'),
      headers: headers,
      body: jsonEncode({'theme': theme}),
    );
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await AuthService.authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/settings/change-password'),
      headers: headers,
      body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to change password');
    }
  }

  static Future<void> deleteAccount() async {
    final headers = await AuthService.authHeaders();
    await http.delete(Uri.parse('$baseUrl/settings/account'), headers: headers);
  }

  // ─── PIPELINE ─────────────────────────────────────────────────
  // Runs all 3 stages: audio→transcript→summary+extract→email
  // audioBytes is null when user pastes transcript text instead
  static Future<Map<String, dynamic>> runPipeline({
    Uint8List? audioBytes,
    String? audioFileName,
    String? transcriptText,
    String tone = 'formal',
    String recipientRole = '',
  }) async {
    final headers = await AuthService.authHeaders();
    // Remove Content-Type — multipart sets its own boundary
    headers.remove('Content-Type');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/pipeline/run'),
    );
    request.headers.addAll(headers);
    request.fields['tone']           = tone;
    request.fields['recipient_role'] = recipientRole;

    if (audioBytes != null && audioFileName != null) {
      // Audio file provided
      request.files.add(
        http.MultipartFile.fromBytes('audio', audioBytes, filename: audioFileName),
      );
    } else if (transcriptText != null) {
      // Plain text transcript provided
      request.fields['transcript_text'] = transcriptText;
    } else {
      throw Exception('Provide either audio file or transcript text');
    }

    final streamed = await request.send().timeout(const Duration(minutes: 5));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      final err = jsonDecode(body);
      throw Exception(err['detail'] ?? 'Pipeline failed');
    }
  }
} 