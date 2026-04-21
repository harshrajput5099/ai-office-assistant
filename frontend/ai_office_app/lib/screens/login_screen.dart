import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _userCtrl.text.trim(), 'password': _passCtrl.text}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await context.read<AuthProvider>().login(data['token'], data['username'], data['theme'] ?? 'light');
      } else { setState(() => _error = data['detail'] ?? 'Login failed'); }
    } catch (_) { setState(() => _error = 'Cannot connect to server'); }
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            const Text('Welcome Back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const Text('Sign in to continue', style: TextStyle(fontSize: 14, color: AppColors.textGrey)),
            const SizedBox(height: 28),
            _inputField(_userCtrl, 'Email address', Icons.email_outlined, false),
            const SizedBox(height: 14),
            _inputField(_passCtrl, 'Password', Icons.lock_outline, true),
            Align(alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text('Forgot Password?', style: TextStyle(color: AppColors.accent)),
                )),
            if (_error != null) _errorBanner(_error!),
            const SizedBox(height: 4),
            _bigButton('Log In', _loading ? null : _login, _loading),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text("Don't have an account? ", style: TextStyle(color: AppColors.textGrey)),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('Register', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ])),
          ]),
        )),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.smart_toy, size: 40, color: Colors.white)),
      const SizedBox(height: 12),
      const Text('AI Office Assistant', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      const Text('Your offline AI powered workspace', style: TextStyle(fontSize: 13, color: Colors.white70)),
    ]),
  );

  Widget _inputField(TextEditingController c, String hint, IconData icon, bool isPass) =>
      TextField(
        controller: c,
        obscureText: isPass ? _obscure : false,
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppColors.textGrey),
          prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
          suffixIcon: isPass ? IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textGrey, size: 20), onPressed: () => setState(() => _obscure = !_obscure)) : null,
          filled: true, fillColor: AppColors.inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );

  Widget _bigButton(String label, VoidCallback? onTap, bool loading) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
      child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );

  Widget _errorBanner(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFADBD8), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFC0392B), size: 18), const SizedBox(width: 8), Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13)))]),
  );
}
