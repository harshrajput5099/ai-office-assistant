import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _userCtrl    = TextEditingController();
  final _keyCtrl     = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _reset() async {
    if (_userCtrl.text.trim().isEmpty || _keyCtrl.text.trim().isEmpty || _newPassCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill all fields'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _userCtrl.text.trim(), 'recovery_key': _keyCtrl.text.trim(), 'new_password': _newPassCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await context.read<AuthProvider>().login(data['token'], data['username'], 'light');
      } else { setState(() => _error = data['detail'] ?? 'Reset failed'); }
    } catch (_) { setState(() => _error = 'Cannot connect to server'); }
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.smart_toy, size: 36, color: Colors.white)),
            const SizedBox(height: 10),
            const Text('AI Office Assistant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text('Your offline AI powered workspace', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFEBF5FB), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('Forgot Password?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('Enter your username and the recovery key\nyou saved when you registered.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
            const SizedBox(height: 32),
            _f(_userCtrl,    'Username',     Icons.person_outline),
            const SizedBox(height: 14),
            _f(_keyCtrl,     'Recovery Key', Icons.vpn_key_outlined),
            const SizedBox(height: 14),
            _f(_newPassCtrl, 'New Password', Icons.lock_outline),
            const SizedBox(height: 20),
            if (_error != null) Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFADBD8), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFC0392B), size: 18), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13)))]),
            ),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _reset,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Login', style: TextStyle(color: AppColors.textGrey))),
          ]),
        )),
      ]),
    );
  }

  Widget _f(TextEditingController c, String hint, IconData icon) => TextField(
    controller: c,
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: AppColors.textGrey),
      prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
      filled: true, fillColor: AppColors.inputBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}