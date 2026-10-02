import 'dart:convert';
import 'package:http/http.dart' as http;

/// Local-only security data service.
/// Uses ONLY the existing PC APIs. No changes required on the PC side.
class LocalSecurityService {
  static const String base = 'http://127.0.0.1:5000';

  /// Fetch all security events (spoof + unknown) from the existing API.
  Future<List<Map<String, dynamic>>> getSecurityEvents({int limit = 100}) async {
    try {
      final response = await http
          .get(Uri.parse('$base/api/security-events?limit=$limit'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetch current device status from the existing API.
  Future<Map<String, dynamic>?> getDeviceStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$base/api/device-status'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Image URL for a security event (already works with existing backend).
  String imageUrl(String eventId) {
    return '$base/api/security-events/$eventId/image';
  }

  // ========== HELPERS ==========

  DateTime? _parseTs(String? ts) {
    if (ts == null || ts.isEmpty) return null;
    try {
      final clean = ts.replaceAll('Z', '').split('+').first;
      return DateTime.parse(clean);
    } catch (_) {
      return null;
    }
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
  }

  bool _inLastHours(DateTime dt, int hours) {
    return dt.isAfter(DateTime.now().subtract(Duration(hours: hours)));
  }

  bool _inLastDays(DateTime dt, int days) {
    return dt.isAfter(DateTime.now().subtract(Duration(days: days)));
  }

  bool _isThisWeek(DateTime dt) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return dt.isAfter(startOfWeek) || dt.isAtSameMomentAs(startOfWeek);
  }

  bool _isThisMonth(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month;
  }

  List<Map<String, dynamic>> _filterByPeriod(
    List<Map<String, dynamic>> events,
    String period,
  ) {
    return events.where((e) {
      final dt = _parseTs(e['timestamp']?.toString());
      if (dt == null) return false;

      switch (period) {
        case 'today':
          return _isToday(dt);
        case 'yesterday':
          return _isYesterday(dt);
        case 'last_24_hours':
          return _inLastHours(dt, 24);
        case 'last_7_days':
          return _inLastDays(dt, 7);
        case 'this_week':
          return _isThisWeek(dt);
        case 'this_month':
          return _isThisMonth(dt);
        default:
          return true;
      }
    }).toList();
  }

  // ========== PUBLIC QUERY METHODS ==========

  Future<Map<String, dynamic>> getCounts({String period = 'today'}) async {
    final all = await getSecurityEvents(limit: 200);
    final filtered = _filterByPeriod(all, period);

    final spoof = filtered.where((e) => e['type'] == 'spoof').toList();
    final unknown = filtered.where((e) => e['type'] == 'unknown').toList();

    final status = await getDeviceStatus();
    final currentFailed = status?['failed_attempts'] ?? 0;

    return {
      'period': period,
      'spoof': spoof.length,
      'unknown': unknown.length,
      'total_suspicious': spoof.length + unknown.length,
      'current_failed_attempts': currentFailed,
      'events': filtered,
    };
  }

  Future<Map<String, dynamic>?> getLatestEvent({String? type}) async {
    final all = await getSecurityEvents(limit: 50);
    final filtered = type == null
        ? all
        : all.where((e) => e['type'] == type).toList();

    if (filtered.isEmpty) return null;
    // Events come newest-first from the API in most cases, but sort to be sure
    filtered.sort((a, b) =>
        (b['timestamp'] ?? '').toString().compareTo((a['timestamp'] ?? '').toString()));
    return filtered.first;
  }

  Future<List<Map<String, dynamic>>> getTimeline({String period = 'today'}) async {
    final data = await getCounts(period: period);
    final events = List<Map<String, dynamic>>.from(data['events'] ?? []);
    events.sort((a, b) =>
        (a['timestamp'] ?? '').toString().compareTo((b['timestamp'] ?? '').toString()));
    return events;
  }

  Future<Map<String, dynamic>> getSummary({String period = 'this_week'}) async {
    return getCounts(period: period);
  }
}