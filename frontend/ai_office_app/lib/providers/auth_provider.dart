import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  bool   _isLoggedIn = false;
  String _username   = '';
  String _theme      = 'light';

  bool   get isLoggedIn => _isLoggedIn;
  String get username   => _username;
  bool   get isDark     => _theme == 'dark';

  // ── Called at app startup ────────────────────────────────────
  Future<void> checkSession() async {
    _isLoggedIn = await AuthService.isLoggedIn();
    if (_isLoggedIn) {
      _username = await AuthService.getUsername() ?? '';
      _theme    = await AuthService.getTheme()    ?? 'light';
    }
    notifyListeners();
  }

  Future<void> login(String token, String username, String theme) async {
    await AuthService.saveSession(token: token, username: username, theme: theme);
    _isLoggedIn = true;
    _username   = username;
    _theme      = theme;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    _isLoggedIn = false;
    _username   = '';
    _theme      = 'light';
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    _theme = theme;
    notifyListeners();
  }
}
