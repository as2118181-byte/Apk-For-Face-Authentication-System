import 'local_security_service.dart';

/// Local rule-based Security Assistant (no Gemini).
class LocalAssistantService {
  final LocalSecurityService _svc = LocalSecurityService();

  Future<String> answer(String userText) async {
    final lower = userText.toLowerCase().trim();

    // ----- detect period -----
    String period = 'today';
    if (lower.contains('yesterday')) {
      period = 'yesterday';
    } else if (lower.contains('last 24') || lower.contains('last24') || lower.contains('past 24')) {
      period = 'last_24_hours';
    } else if (lower.contains('this week') || lower.contains('weekly')) {
      period = 'this_week';
    } else if (lower.contains('last 7') || lower.contains('7 days') || lower.contains('past week')) {
      period = 'last_7_days';
    } else if (lower.contains('this month') || lower.contains('monthly')) {
      period = 'this_month';
    }

    try {
      // ----- Latest spoof -----
      if (lower.contains('latest spoof') ||
          lower.contains('last spoof') ||
          lower.contains('most recent spoof') ||
          lower.contains('show me the latest spoof')) {
        final event = await _svc.getLatestEvent(type: 'spoof');
        if (event == null) {
          return 'No spoof attempts have been recorded yet.';
        }
        final ts = _formatTime(event['timestamp']?.toString());
        return '🚨 Latest Spoof Attempt\n'
            'Time: $ts\n'
            'Status: BLOCKED\n'
            'Event ID: ${event['event_id']}\n\n'
            'You can view the captured image from the main dashboard.';
      }

      // ----- Latest unknown -----
      if (lower.contains('latest unknown') ||
          lower.contains('last unknown') ||
          lower.contains('most recent unknown')) {
        final event = await _svc.getLatestEvent(type: 'unknown');
        if (event == null) {
          return 'No unknown face detections have been recorded yet.';
        }
        final ts = _formatTime(event['timestamp']?.toString());
        return '⚠️ Latest Unknown Face\n'
            'Time: $ts\n'
            'Status: BLOCKED\n'
            'Event ID: ${event['event_id']}';
      }

      // ----- Timeline -----
      if (lower.contains('timeline') ||
          lower.contains('what happened') ||
          lower.contains('happened between') ||
          lower.contains('show events')) {
        final events = await _svc.getTimeline(period: period);
        if (events.isEmpty) {
          return 'No security events found for the selected period ($period).';
        }
        final buffer = StringBuffer();
        buffer.writeln('📅 Security Timeline ($period)');
        buffer.writeln('');
        for (final e in events.take(25)) {
          final ts = _formatTime(e['timestamp']?.toString());
          final type = (e['type'] ?? 'event').toString().toUpperCase();
          buffer.writeln('$ts  →  $type');
        }
        if (events.length > 25) {
          buffer.writeln('\n... and ${events.length - 25} more events');
        }
        return buffer.toString();
      }

      // ----- Summary / Report -----
      if (lower.contains('summary') ||
          lower.contains('report') ||
          lower.contains('overview') ||
          lower.contains('how is my security')) {
        final data = await _svc.getSummary(period: period);
        return _buildSummary(data, period);
      }

      // ----- Spoof count -----
      if (lower.contains('spoof')) {
        final data = await _svc.getCounts(period: period);
        final count = data['spoof'] as int;
        if (count == 0) {
          return 'No spoof attempts were recorded for $period.';
        }
        return '🚨 Spoof Attempts ($period)\n'
            'Total: $count\n\n'
            'All of these attempts were blocked by the system.';
      }

      // ----- Unknown count -----
      if (lower.contains('unknown')) {
        final data = await _svc.getCounts(period: period);
        final count = data['unknown'] as int;
        if (count == 0) {
          return 'No unknown faces were detected for $period.';
        }
        return '⚠️ Unknown Faces ($period)\n'
            'Total: $count\n\n'
            'These faces did not match any enrolled person.';
      }

      // ----- Failed / attempts -----
      if (lower.contains('failed') ||
          lower.contains('attempt') ||
          lower.contains('how many') ||
          lower.contains('login')) {
        final data = await _svc.getCounts(period: period);
        final spoof = data['spoof'] as int;
        final unknown = data['unknown'] as int;
        final total = spoof + unknown;
        final currentFailed = data['current_failed_attempts'];

        return '📊 Authentication Activity ($period)\n\n'
            'Suspicious / Failed events: $total\n'
            '  • Spoof attempts : $spoof\n'
            '  • Unknown faces  : $unknown\n\n'
            'Current failed-attempt counter on device: $currentFailed';
      }

      // ----- Default help -----
      return 'I can help you with security information.\n\n'
          'Tap one of the suggestions below to get started.';
    } catch (e) {
      return 'Unable to reach the PC system right now.\n'
          'Please make sure:\n'
          '1. webcam.py is running on the PC\n'
          '2. adb reverse tcp:5000 tcp:5000 is active\n\n'
          'Error: $e';
    }
  }

  String _buildSummary(Map<String, dynamic> data, String period) {
    final spoof = data['spoof'] as int? ?? 0;
    final unknown = data['unknown'] as int? ?? 0;
    final total = spoof + unknown;

    final buffer = StringBuffer();
    buffer.writeln('🛡️ SECURITY SUMMARY');
    buffer.writeln('Period: $period');
    buffer.writeln('');
    buffer.writeln('Spoof attempts   : $spoof');
    buffer.writeln('Unknown faces    : $unknown');
    buffer.writeln('Total suspicious : $total');
    buffer.writeln('');

    if (total == 0) {
      buffer.writeln('No suspicious activity recorded in this period.');
    } else {
      buffer.writeln('The system blocked all of the above attempts.');
    }

    buffer.writeln('');
    buffer.writeln('You can open any event from the main dashboard to view the captured photo.');
    return buffer.toString();
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown time';
    try {
      final clean = raw.replaceAll('Z', '').split('+').first;
      final dt = DateTime.parse(clean);
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month/${dt.year}  $h:$min $ampm';
    } catch (_) {
      return raw.length >= 19 ? raw.substring(0, 19).replaceFirst('T', ' ') : raw;
    }
  }
}