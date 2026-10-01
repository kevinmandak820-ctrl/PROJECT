import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Low-level HTTP client that:
/// - Points at the backend base URL
/// - Automatically attaches the stored JWT access token
/// - On 401: attempts a token refresh, then retries once
class ApiService {
  // Use localhost for Windows/macOS/Linux desktop & iOS Simulator.
  // Change to http://10.0.2.2:3000/api for Android emulator.
  static const String _baseUrl = 'http://localhost:3000/api';
  static String get baseUrl => _baseUrl;

  static const String _keyAccess = 'access_token';
  static const String _keyRefresh = 'refresh_token';

  // ── Token helpers ────────────────────────────────────────────────────────

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess);
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, accessToken);
    await prefs.setString(_keyRefresh, refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
  }

  static Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefresh);
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  static Map<String, String> _buildHeaders({String? accessToken}) {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (accessToken != null) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $accessToken';
    }
    return headers;
  }

  static Map<String, dynamic> _decode(http.Response response) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Try to refresh the access token; returns new access token or null.
  static Future<String?> _refresh() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: _buildHeaders(),
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode == 200) {
        final body = _decode(response);
        final newAccess = body['data']['accessToken'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAccess, newAccess);
        return newAccess;
      }
    } catch (_) {}
    return null;
  }

  // ── Public API methods ───────────────────────────────────────────────────

  /// POST to a public (no-auth) endpoint.
  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _buildHeaders(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  /// POST to an authenticated endpoint. Retries once after token refresh on 401.
  static Future<Map<String, dynamic>> authPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    String? token = await getAccessToken();
    http.Response response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _buildHeaders(accessToken: token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      // Try refresh
      token = await _refresh();
      if (token != null) {
        response = await http.post(
          Uri.parse('$_baseUrl$path'),
          headers: _buildHeaders(accessToken: token),
          body: jsonEncode(body),
        );
      }
    }
    return _decode(response);
  }

  /// GET from an authenticated endpoint.
  static Future<Map<String, dynamic>> authGet(String path) async {
    String? token = await getAccessToken();
    http.Response response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: _buildHeaders(accessToken: token),
    );

    if (response.statusCode == 401) {
      token = await _refresh();
      if (token != null) {
        response = await http.get(
          Uri.parse('$_baseUrl$path'),
          headers: _buildHeaders(accessToken: token),
        );
      }
    }
    return _decode(response);
  }

  /// PUT to an authenticated endpoint. Retries once after token refresh on 401.
  static Future<Map<String, dynamic>> authPut(
    String path,
    Map<String, dynamic> body,
  ) async {
    String? token = await getAccessToken();
    http.Response response = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: _buildHeaders(accessToken: token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      token = await _refresh();
      if (token != null) {
        response = await http.put(
          Uri.parse('$_baseUrl$path'),
          headers: _buildHeaders(accessToken: token),
          body: jsonEncode(body),
        );
      }
    }
    return _decode(response);
  }

  /// PATCH to an authenticated endpoint. Retries once after token refresh on 401.
  static Future<Map<String, dynamic>> authPatch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    String? token = await getAccessToken();
    http.Response response = await http.patch(
      Uri.parse('$_baseUrl$path'),
      headers: _buildHeaders(accessToken: token),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      token = await _refresh();
      if (token != null) {
        response = await http.patch(
          Uri.parse('$_baseUrl$path'),
          headers: _buildHeaders(accessToken: token),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return _decode(response);
  }

  /// DELETE to an authenticated endpoint. Retries once after token refresh on 401.
  static Future<Map<String, dynamic>> authDelete(String path) async {
    String? token = await getAccessToken();
    http.Response response = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: _buildHeaders(accessToken: token),
    );

    if (response.statusCode == 401) {
      token = await _refresh();
      if (token != null) {
        response = await http.delete(
          Uri.parse('$_baseUrl$path'),
          headers: _buildHeaders(accessToken: token),
        );
      }
    }
    return _decode(response);
  }

  /// Multipart upload to an authenticated endpoint.
  static Future<Map<String, dynamic>> authMultipart(
    String path, {
    String method = 'POST',
    Map<String, String>? fields,
    List<int>? fileBytes,
    String? filename,
    String fieldName = 'image',
  }) async {
    String? token = await getAccessToken();

    Future<http.Response> sendRequest(String? currentToken) async {
      final request = http.MultipartRequest(
        method,
        Uri.parse('$_baseUrl$path'),
      );
      if (currentToken != null) {
        request.headers[HttpHeaders.authorizationHeader] = 'Bearer $currentToken';
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }
      if (fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            fileBytes,
            filename: filename ?? 'upload.png',
          ),
        );
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    http.Response response = await sendRequest(token);

    if (response.statusCode == 401) {
      token = await _refresh();
      if (token != null) {
        response = await sendRequest(token);
      }
    }

    return _decode(response);
  }
}
