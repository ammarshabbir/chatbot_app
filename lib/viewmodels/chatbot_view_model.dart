import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/foundation.dart';

import 'package:chatbot_app/models/chat_entry.dart';
import 'package:chatbot_app/services/chatbot_service.dart';

class ChatBotViewModel extends ChangeNotifier {
  ChatBotViewModel({
    ChatBotService? chatBotService,
  }) : _service = chatBotService ?? ChatBotService();

  final ChatBotService _service;

  final ChatUser user = ChatUser(
    id: '1',
    firstName: 'Ammar',
    lastName: 'Shabbir',
  );

  final ChatUser geminiModel = ChatUser(
    id: '2',
    firstName: 'Gemini',
    lastName: 'Model',
  );

  final List<ChatMessage> _messages = [];
  final List<ChatEntry> _conversation = [];

  bool _isThinking = false;
  String? _errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isThinking => _isThinking;
  String? get errorMessage => _errorMessage;

  Future<void> generateImageFromPrompt(String rawInput) async {
    final prompt = rawInput.trim();
    if (prompt.isEmpty) {
      return;
    }

    _appendUserMessage(prompt);
    _setError(null);
    _setThinking(true);

    try {
      final imageData =
          await _service.generateImage(conversation: _conversation);
      if (imageData == null || imageData.trim().isEmpty) {
        _setError('No image received from Gemini.');
        return;
      }
      _appendModelImage(imageData.trim());
    } catch (error, stackTrace) {
      debugPrint('Failed to generate image: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setError('Unable to generate image right now. Please try again.');
    } finally {
      _setThinking(false);
    }
  }

  Future<void> sendMessage(String rawInput) async {
    final message = rawInput.trim();
    if (message.isEmpty) {
      return;
    }

    _appendUserMessage(message);
    _setError(null);
    _setThinking(true);

    try {
      final reply = await _service.fetchReply(conversation: _conversation);
      if (reply == null || reply.trim().isEmpty) {
        _setError('No response received from Gemini.');
        return;
      }
      _appendModelMessage(reply);
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch reply: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setError('Unable to reach Gemini right now. Please try again.');
    } finally {
      _setThinking(false);
    }
  }

  void clearChat() {
    _messages.clear();
    _conversation.clear();
    _setError(null);
    notifyListeners();
  }

  void _appendUserMessage(String message) {
    _conversation.add(
      ChatEntry(role: ChatRole.user, text: message),
    );
    _messages.insert(
      0,
      ChatMessage(
        user: user,
        createdAt: DateTime.now(),
        text: message,
      ),
    );
    notifyListeners();
  }

  void _appendModelMessage(String reply) {
    _conversation.add(
      ChatEntry(role: ChatRole.model, text: reply),
    );
    _messages.insert(
      0,
      ChatMessage(
        user: geminiModel,
        createdAt: DateTime.now(),
        text: reply,
        isMarkdown: true,
      ),
    );
    notifyListeners();
  }

  void _appendModelImage(String base64Image) {
    _conversation.add(
      const ChatEntry(
        role: ChatRole.model,
        text: 'Image generated.',
      ),
    );
    _messages.insert(
      0,
      ChatMessage(
        user: geminiModel,
        createdAt: DateTime.now(),
        text: 'Here is your image.',
        medias: [
          ChatMedia(
            url: 'data:image/png;base64,$base64Image',
            fileName: 'gemini-image.png',
            type: MediaType.image,
          ),
        ],
      ),
    );
    notifyListeners();
  }

  void _setThinking(bool value) {
    if (_isThinking == value) {
      return;
    }
    _isThinking = value;
    notifyListeners();
  }

  void _setError(String? value) {
    if (_errorMessage == value) {
      return;
    }
    _errorMessage = value;
    notifyListeners();
  }
}
