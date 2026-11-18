import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class ChatMessage {
  final String id;
  final String role; // 'user' or 'model'
  final String content;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isError = false,
  });

  bool get isUser => role == 'user';
}

class GeminiAiService extends ChangeNotifier {
  static final GeminiAiService _instance = GeminiAiService._internal();
  factory GeminiAiService() => _instance;
  GeminiAiService._internal() {
    _initDefaultMessage();
  }

  final ApiClient _apiClient = ApiClient.instance;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _customApiKey;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get customApiKey => _customApiKey;

  void _initDefaultMessage() {
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          id: 'welcome_0',
          role: 'model',
          content: "👋 **Hello! I'm Gemini Copilot**, your intelligent assistant for **NT-MMS**.\n\n"
              "Ask me anything about your manufacturing workflows, Bill of Materials (BOM), Purchase Orders, Stock Transfers, or master setups!",
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void setCustomApiKey(String? key) {
    _customApiKey = (key != null && key.trim().isNotEmpty) ? key.trim() : null;
    notifyListeners();
  }

  void clearConversation() {
    _messages.clear();
    _initDefaultMessage();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final cleanPrompt = text.trim();
    if (cleanPrompt.isEmpty || _isLoading) return;

    final userMsg = ChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: cleanPrompt,
      timestamp: DateTime.now(),
    );

    _messages.add(userMsg);
    _isLoading = true;
    notifyListeners();

    try {
      // Build history payload for contextual memory
      final historyPayload = _messages
          .where((m) => !m.isError && m.id != userMsg.id && m.id != 'welcome_0')
          .take(8)
          .map((m) => {
                'role': m.role,
                'content': m.content,
              })
          .toList();

      final body = {
        'message': cleanPrompt,
        'history': historyPayload,
        if (_customApiKey != null) 'clientApiKey': _customApiKey,
      };

      final response = await _apiClient.post(
        '${ApiConfig.baseUrl}/ai/chat',
        body: body,
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final data = parsed['data'];
        final replyText = data != null && data['reply'] != null
            ? data['reply'].toString()
            : "Received empty response from Gemini.";

        _messages.add(
          ChatMessage(
            id: 'gemini_${DateTime.now().millisecondsSinceEpoch}',
            role: 'model',
            content: replyText,
            timestamp: DateTime.now(),
          ),
        );
      } else {
        String errMsg = "Error ${response.statusCode}: Failed to get response.";
        try {
          final errJson = jsonDecode(response.body);
          if (errJson['message'] != null) {
            errMsg = errJson['message'].toString();
          }
        } catch (_) {}

        _messages.add(
          ChatMessage(
            id: 'err_${DateTime.now().millisecondsSinceEpoch}',
            role: 'model',
            content: "⚠️ **Service Notice**: $errMsg",
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      }
    } catch (e) {
      _messages.add(
        ChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          role: 'model',
          content: "⚠️ **Network Error**: Unable to reach backend AI service. ($e)",
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
