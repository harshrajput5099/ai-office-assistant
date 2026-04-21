import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false, _obs1 = true, _obs2 = true;
  String? _error;

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) { setState(() => _error = 'Please fill all fields'); return; }
    if (_passCtrl.text != _pass2Ctrl.text) { setState(() => _error = 'Passwords do not match'); return; }
    if (_passCtrl.text.length < 6) { setState(() => _error = 'Password must be at least 6 characters'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _nameCtrl.text.trim(), 'password': _passCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await _showRecoveryKey(data['recovery_key'] ?? '---');
        await context.read<AuthProvider>().login(data['token'], data['username'], 'light');
      } else { setState(() => _error = data['detail'] ?? 'Registration failed'); }
    } catch (_) { setState(() => _error = 'Cannot connect to server'); }
    finally { setState(() => _loading = false); }
  }

  Future<void> _showRecoveryKey(String key) async {
    await showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save Your Recovery Key!', style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This is shown ONCE. Write it down or screenshot it. You need it to reset your password.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF0F3F7), borderRadius: BorderRadius.circular(10)),
            child: SelectableText(key, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 2, color: Color(0xFF1B4F72))),
          ),
        ]),
        actions: [ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B), foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context),
          child: const Text('I have saved it'),
        )],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _header(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            const Text('Create Account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const Text('Start your AI journey', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
            const SizedBox(height: 28),
            _field(_nameCtrl, 'Full Name', Icons.person_outline, false, null, null),
            const SizedBox(height: 14),
            _field(_passCtrl, 'Password', Icons.lock_outline, true, _obs1, () => setState(() => _obs1 = !_obs1)),
            const SizedBox(height: 14),
            _field(_pass2Ctrl, 'Confirm Password', Icons.lock_outline, true, _obs2, () => setState(() => _obs2 = !_obs2)),
            const SizedBox(height: 20),
            if (_error != null) _errBox(_error!),
            _btn('Register', _loading ? null : _register, _loading),
            const SizedBox(height: 20),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Already have an account? ', style: TextStyle(color: AppColors.textGrey)),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Log In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ])),
          ]),
        )),
      ]),
    );
  }

  Widget _header() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.smart_toy, size: 36, color: Colors.white)),
      const SizedBox(height: 10),
      const Text('AI Office Assistant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      const Text('Your offline AI powered workspace', style: TextStyle(fontSize: 12, color: Colors.white70)),
    ]),
  );

  Widget _field(TextEditingController c, String hint, IconData icon, bool isPass, bool? obs, VoidCallback? toggle) =>
      TextField(
        controller: c, obscureText: isPass ? (obs ?? true) : false,
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppColors.textGrey),
          prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
          suffixIcon: isPass ? IconButton(icon: Icon((obs ?? true) ? Icons.visibility_off : Icons.visibility, color: AppColors.textGrey, size: 20), onPressed: toggle) : null,
          filled: true, fillColor: AppColors.inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );

  Widget _btn(String label, VoidCallback? onTap, bool loading) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
      child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );

  Widget _errBox(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFADBD8), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFC0392B), size: 18), const SizedBox(width: 8), Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13)))]),
  );
}
