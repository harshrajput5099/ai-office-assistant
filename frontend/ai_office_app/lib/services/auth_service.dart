import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey    = 'jwt_token';
  static const _usernameKey = 'username';
  static const _themeKey    = 'theme';

  // ── Store token after login/register ────────────────────────
  static Future<void> saveSession({
    required String token,
    required String username,
    String theme = 'light',
  }) async {
    await _storage.write(key: _tokenKey,    value: token);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _themeKey,    value: theme);
  }

  // ── Read token (attach to API requests) ─────────────────────
  static Future<String?> getToken()    => _storage.read(key: _tokenKey);
  static Future<String?> getUsername() => _storage.read(key: _usernameKey);
  static Future<String?> getTheme()    => _storage.read(key: _themeKey);

  // ── Check if user is logged in ───────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  // ── Clear everything on logout ───────────────────────────────
  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ── Build Authorization header ───────────────────────────────
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
