import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SecureDeviceApp());
}

class SecureDeviceApp extends StatelessWidget {
  const SecureDeviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Device',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  bool _pcOnline = false;
  Map<String, dynamic>? _status;
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchStatus());
  }

  Future<void> _fetchStatus() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:5000/api/device-status'))
          .timeout(const Duration(milliseconds: 900));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _pcOnline = true;
            _status = data;
            _lastError = '';
          });
        }
      } else {
        _setOffline('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _setOffline(e.toString());
    }
  }

  void _setOffline(String err) {
    if (mounted) {
      setState(() {
        _pcOnline = false;
        _lastError = err;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = (_status?['status']?.toString().toLowerCase() ?? 'locked') == 'locked';
    final auth = _status?['authentication'] == true;
    final user = _status?['user']?.toString() ?? '—';
    final idConf = (_status?['identity_confidence'] as num?)?.toDouble() ?? 0.0;
    final liveConf = (_status?['liveness_confidence'] as num?)?.toDouble() ?? 0.0;
    final liveScore = (_status?['liveness_score'] as num?)?.toDouble() ?? 0.0;
    final simScore = (_status?['similarity_score'] as num?)?.toDouble() ?? 0.0;
    final message = _status?['message']?.toString() ?? 'Waiting for authentication...';
    final failed = _status?['failed_attempts'] ?? 0;
    final maxFailed = _status?['max_failed_attempts'] ?? 4;
    final ts = _status?['timestamp']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            tooltip: 'About Us',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              // Logo
              Image.asset(
                'assets/logo.png',
                height: 75,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.security, size: 70, color: Colors.redAccent);
                },
              ),
              const SizedBox(height: 14),

              const Text(
                'SECURE DEVICE',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'FACE AUTHENTICATION',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 22),

              // Online / Offline badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: _pcOnline ? const Color(0xFF0D2A0D) : const Color(0xFF2A0D0D),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _pcOnline ? Colors.greenAccent : Colors.redAccent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pcOnline ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _pcOnline ? 'PC SYSTEM ONLINE' : 'PC SYSTEM OFFLINE',
                      style: TextStyle(
                        color: _pcOnline ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              Icon(
                locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 100,
                color: locked ? Colors.redAccent : Colors.greenAccent,
              ),
              const SizedBox(height: 16),
              Text(
                locked ? 'DEVICE LOCKED' : 'DEVICE UNLOCKED',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: locked ? Colors.redAccent : Colors.greenAccent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),

              const SizedBox(height: 32),

              _infoCard(icon: Icons.shield_outlined, label: 'Security Status', value: 'PROTECTED'),
              _infoCard(
                icon: Icons.camera_alt_outlined,
                label: 'Authentication',
                value: _pcOnline ? (auth ? 'AUTHENTICATED' : 'WAITING') : 'OFFLINE',
                valueColor: _pcOnline
                    ? (auth ? Colors.greenAccent : Colors.orangeAccent)
                    : Colors.redAccent,
              ),
              if (user != '—' && user != 'null' && user.isNotEmpty)
                _infoCard(
                  icon: Icons.person_outline,
                  label: 'User',
                  value: user,
                  valueColor: Colors.greenAccent,
                ),
              _infoCard(
                icon: Icons.fingerprint,
                label: 'Identity Confidence',
                value: '${idConf.toStringAsFixed(1)}%',
              ),
              _infoCard(
                icon: Icons.visibility_outlined,
                label: 'Liveness Confidence',
                value: '${liveConf.toStringAsFixed(1)}%',
              ),
              _infoCard(
                icon: Icons.score_outlined,
                label: 'Liveness Score',
                value: liveScore.toStringAsFixed(4),
              ),
              _infoCard(
                icon: Icons.compare_arrows,
                label: 'Similarity Score',
                value: simScore.toStringAsFixed(4),
              ),
              _infoCard(
                icon: Icons.warning_amber_rounded,
                label: 'Failed Attempts',
                value: '$failed / $maxFailed',
              ),
              if (ts.isNotEmpty)
                _infoCard(
                  icon: Icons.access_time,
                  label: 'Last Updated',
                  value: ts.length >= 19 ? ts.substring(11, 19) : ts,
                ),

              const SizedBox(height: 28),
              const Text(
                'AI FACE AUTHENTICATION',
                style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5),
              ),
              const SizedBox(height: 4),
              const Text(
                'Secure Device Demonstration',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.white,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ==================== ABOUT US SCREEN ====================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('About Us', style: TextStyle(letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'assets/logo.png',
                height: 90,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.security, size: 80, color: Colors.redAccent);
                },
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Secure Device\nFace Authentication System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 30),

            const Text(
              'About the Project',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            const Text(
              'This project is a complete AI-powered Face Authentication and Device Unlocking System. '
              'It uses advanced computer vision techniques including Face Detection, Face Recognition (FaceNet), '
              'and Liveness Detection (DeepPixBiS) to securely unlock a device only for authorized live users.\n\n'
              'The system can detect spoof attacks (photos/videos), unknown persons, and emotional states such as fear. '
              'It features real-time confidence scoring, failed attempt locking, email alerts, and a live Android dashboard '
              'that shows the current security status of the PC system over a USB connection.',
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.white70),
            ),

            const SizedBox(height: 28),
            const Text(
              'Key Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            _feature('Real-time Face Detection & Recognition'),
            _feature('Liveness Detection (Anti-Spoofing)'),
            _feature('Unknown Person & Spoof Attack Alerts'),
            _feature('Failed Attempt Locking Mechanism'),
            _feature('Email Security Notifications'),
            _feature('Live Android Security Dashboard'),
            _feature('USB-only communication (ADB Reverse)'),

            const SizedBox(height: 36),
            const Text(
              'Performed by',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),

            _teamMember('Arun Sharma', 'A-29'),
            _teamMember('Devan Patel', 'A-46'),
            _teamMember('Arya Tabhane', 'A-03'),
            _teamMember('Pratiksha Hadekar', 'B-60'),

            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Final Year Project\nAI Secure Face Authentication System',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _teamMember(String name, String roll) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.redAccent,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Text(
                roll,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}