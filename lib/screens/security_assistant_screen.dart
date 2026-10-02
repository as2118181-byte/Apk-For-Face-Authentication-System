import 'package:flutter/material.dart';
import '../services/local_assistant_service.dart';

class SecurityAssistantScreen extends StatefulWidget {
  const SecurityAssistantScreen({super.key});

  @override
  State<SecurityAssistantScreen> createState() => _SecurityAssistantScreenState();
}

class _SecurityAssistantScreenState extends State<SecurityAssistantScreen> {
  final LocalAssistantService _assistant = LocalAssistantService();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  static const List<String> _suggestions = [
    "Today's security summary",
    "How many spoof attempts today?",
    "Show latest spoof attempt",
    "What happened this week?",
    "Show unknown faces",
    "Security timeline today",
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text:
            "Hello! I am your Security Assistant.\n\n"
            "I read real security events (spoof & unknown faces) recorded by the PC system.\n\n"
            "Tap a suggestion below to get started.",
        isUser: false,
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: trimmed, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    final answer = await _assistant.answer(trimmed);

    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(text: answer, isUser: false));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: const Text(
          'AI Security Assistant',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.80,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0xFF2A1212)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                      ),
                      border: Border.all(
                        color: msg.isUser
                            ? Colors.redAccent.withOpacity(0.35)
                            : Colors.white10,
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Suggestion chips only (no text input box)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((s) {
                  return ActionChip(
                    label: Text(
                      s,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    backgroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Colors.white24),
                    onPressed: _isLoading ? null : () => _sendMessage(s),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}