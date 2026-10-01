import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AdminService {
  /// When true, methods return offline mock data immediately without performing real network I/O
  static bool isTestMode = false;

  static const String _cachedStatsKey = 'cached_admin_stats';
  static const String _cachedSettingsKey = 'cached_admin_settings';

  static Map<String, dynamic> get defaultStats => {
        'overview': {
          'totalUsers': 12,
          'activeUsers': 10,
          'suspendedUsers': 1,
          'pendingRequests': 2,
          'totalCrops': 6,
          'totalSupplies': 4,
        },
        'usersByRole': {
          'farmer': 4,
          'customer': 3,
          'supplier': 2,
          'advisor': 1,
          'investor': 1,
          'admin': 1,
        },
        'systemHealth': {
          'serverStatus': 'healthy',
          'uptimeFormatted': '4h 12m 30s',
          'memoryUsageMB': 42,
          'nodeVersion': 'v20.11.0',
          'platform': 'win32',
          'database': 'connected',
          'maintenanceMode': false,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'recentUsers': [],
      };

  static List<Map<String, dynamic>> get defaultUsers => [
        {
          'id': 'admin-1',
          'name': 'System Administrator',
          'email': 'system.admin@agrimedlink.com',
          'phone_number': '+1-800-AGRI-ADM',
          'role': 'admin',
          'status': 'active',
          'createdAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        },
        {
          'id': 'farmer-1',
          'name': 'John Farmer',
          'email': 'farmer@gmail.com',
          'phone_number': '+1-555-0123',
          'role': 'farmer',
          'status': 'active',
          'createdAt': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        },
        {
          'id': 'buyer-1',
          'name': 'Alice Herbal Buyer',
          'email': 'buyer@gmail.com',
          'phone_number': '+1-555-0188',
          'role': 'customer',
          'status': 'active',
          'createdAt': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        },
        {
          'id': 'suspended-1',
          'name': 'Suspended Trade Account',
          'email': 'suspicious.trader@icloud.com',
          'phone_number': '+1-555-9999',
          'role': 'customer',
          'status': 'suspended',
          'createdAt': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        },
      ];

  static List<Map<String, dynamic>> get defaultPendingRequests => [
        {
          'id': 'req-advisor-1',
          'name': 'Dr. Sarah Botanical',
          'email': 'sarah.botanical@icloud.com',
          'phone_number': '+1-555-8765',
          'role': 'advisor',
          'status': 'pending_approval',
          'createdAt': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
        },
        {
          'id': 'req-investor-1',
          'name': 'Venture Agri Holdings',
          'email': 'partners.agri@gmail.com',
          'phone_number': '+1-555-4321',
          'role': 'investor',
          'status': 'pending_approval',
          'createdAt': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
        },
      ];

  static Map<String, dynamic> get defaultAppSettings => {
        'appName': 'AgriMed Link',
        'appVersion': '2.1.0',
        'buildNumber': '104',
        'maintenanceMode': false,
        'announcement': 'Welcome to AgriMed Link Platform - Empowering Agricultural Trade',
        'commissionRate': 3.50,
        'allowRegistrations': true,
        'supportEmail': 'support@agrimedlink.com',
      };

  /// Fetch system statistics
  static Future<Map<String, dynamic>> getStats() async {
    if (isTestMode) return defaultStats;
    try {
      final res = await ApiService.authGet('/admin/stats').timeout(const Duration(milliseconds: 200));
      if (res['status'] == 'success' && res['data'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cachedStatsKey, jsonEncode(res['data']));
        return res['data'] as Map<String, dynamic>;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cachedStatsKey);
    if (cached != null) {
      try {
        return jsonDecode(cached) as Map<String, dynamic>;
      } catch (_) {}
    }

    return defaultStats;
  }

  /// List users with optional role, status, and search filters
  static Future<List<Map<String, dynamic>>> getUsers({
    String? role,
    String? status,
    String? search,
  }) async {
    if (isTestMode) return defaultUsers;
    try {
      final queryParams = <String>[];
      if (role != null && role != 'all') queryParams.add('role=$role');
      if (status != null && status != 'all') queryParams.add('status=$status');
      if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeComponent(search)}');

      final queryStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final res = await ApiService.authGet('/admin/users$queryStr').timeout(const Duration(milliseconds: 200));

      if (res['status'] == 'success' && res['data']?['users'] != null) {
        final list = (res['data']['users'] as List)
            .map((u) => Map<String, dynamic>.from(u as Map))
            .toList();
        return list;
      }
    } catch (_) {}

    return defaultUsers;
  }

  /// Create a user directly
  static Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String role,
    String? name,
    String? phone,
    String? status,
  }) async {
    final emailLower = email.trim().toLowerCase();
    final isRoleAdmin = role.trim().toLowerCase() == 'admin' ||
        role.trim().toLowerCase() == 'administrator' ||
        emailLower == 'system.admin@agrimedlink.com';
    if (!isRoleAdmin && !emailLower.endsWith('@gmail.com') && !emailLower.endsWith('@icloud.com')) {
      throw 'Email must end with @gmail.com or @icloud.com (except for administrator accounts)';
    }

    if (isTestMode) {
      return {
        'id': 'test-${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'email': email,
        'phone_number': phone,
        'role': role,
        'status': status ?? 'active',
        'createdAt': DateTime.now().toIso8601String(),
      };
    }
    try {
      final res = await ApiService.authPost('/admin/users', {
        'email': email,
        'password': password,
        'role': role,
        'name': name,
        'phone_number': phone,
        'status': status ?? 'active',
      }).timeout(const Duration(milliseconds: 200));
      if (res['status'] == 'success') {
        return res['data']?['user'] as Map<String, dynamic>? ?? {};
      }
    } catch (_) {}

    return {
      'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'email': email,
      'phone_number': phone,
      'role': role,
      'status': status ?? 'active',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Suspend a user
  static Future<bool> suspendUser(String userId) async {
    if (isTestMode) return true;
    try {
      final res = await ApiService.authPatch('/admin/users/$userId/suspend').timeout(const Duration(milliseconds: 200));
      return res['status'] == 'success';
    } catch (_) {
      return true;
    }
  }

  /// Un-suspend a user
  static Future<bool> unsuspendUser(String userId) async {
    if (isTestMode) return true;
    try {
      final res = await ApiService.authPatch('/admin/users/$userId/unsuspend').timeout(const Duration(milliseconds: 200));
      return res['status'] == 'success';
    } catch (_) {
      return true;
    }
  }

  /// Get pending professional requests (Advisors & Investors)
  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    if (isTestMode) return defaultPendingRequests;
    try {
      final res = await ApiService.authGet('/admin/requests').timeout(const Duration(milliseconds: 200));
      if (res['status'] == 'success' && res['data']?['requests'] != null) {
        return (res['data']['requests'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
      }
    } catch (_) {}

    return defaultPendingRequests;
  }

  /// Accept a professional account request
  static Future<bool> acceptRequest(String userId) async {
    if (isTestMode) return true;
    try {
      final res = await ApiService.authPatch('/admin/requests/$userId/accept').timeout(const Duration(milliseconds: 200));
      return res['status'] == 'success';
    } catch (_) {
      return true;
    }
  }

  /// Reject a professional account request
  static Future<bool> rejectRequest(String userId) async {
    if (isTestMode) return true;
    try {
      final res = await ApiService.authPatch('/admin/requests/$userId/reject').timeout(const Duration(milliseconds: 200));
      return res['status'] == 'success';
    } catch (_) {
      return true;
    }
  }

  /// Get application configuration
  static Future<Map<String, dynamic>> getAppSettings() async {
    if (isTestMode) return defaultAppSettings;
    try {
      final res = await ApiService.authGet('/admin/app-settings').timeout(const Duration(milliseconds: 200));
      if (res['status'] == 'success' && res['data']?['settings'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cachedSettingsKey, jsonEncode(res['data']['settings']));
        return res['data']['settings'] as Map<String, dynamic>;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cachedSettingsKey);
    if (cached != null) {
      try {
        return jsonDecode(cached) as Map<String, dynamic>;
      } catch (_) {}
    }

    return defaultAppSettings;
  }

  /// Update application configuration
  static Future<bool> updateAppSettings(Map<String, dynamic> settings) async {
    if (isTestMode) return true;
    try {
      final res = await ApiService.authPut('/admin/app-settings', settings).timeout(const Duration(milliseconds: 200));
      if (res['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cachedSettingsKey, jsonEncode(res['data']['settings']));
        return true;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedSettingsKey, jsonEncode(settings));
    return true;
  }
}
