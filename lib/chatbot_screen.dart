import 'package:chatbot_app/gemini_services.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final GeminiServices _geminiServices = GeminiServices();

  bool _isSpeakEnable = false;

  FlutterTts flutterTts = FlutterTts();

  bool _isLoading = false;
  final ChatUser user = ChatUser(
    id: '1',
    firstName: 'Ammar',
    lastName: 'Ammar',
  );
  final ChatUser geminiAI = ChatUser(
    id: '2',
    firstName: 'Gemini',
    lastName: 'AI',
  );
  final List<ChatMessage> messages = [];
  final List<Map<String, Object>> conversation = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> askGemini() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _messageController.clear();
      messages.insert(
        0,
        ChatMessage(user: user, text: message, createdAt: DateTime.now()),
      );
      conversation.add({
        'role': 'user',
        'parts': [
          {'text': message},
        ],
      });
      _isLoading = true;
    });

    try {
      final reply = await _geminiServices.askGemini(conversation);

      if (!mounted) {
        return;
      }

      setState(() {
        messages.insert(
          0,
          ChatMessage(user: geminiAI, text: reply, createdAt: DateTime.now()),
        );
        conversation.add({
          'role': 'model',
          'parts': [
            {'text': reply},
          ],
        });
        flutterTts.speak(reply);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        messages.insert(
          0,
          ChatMessage(
            user: geminiAI,
            text: error.toString(),
            createdAt: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatBot', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSpeakEnable = !_isSpeakEnable;
              });
              if (!_isSpeakEnable) {
                setState(() {
                  flutterTts.stop();
                });
              }
            },
            icon: Icon(
              _isSpeakEnable ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : DashChat(
                    currentUser: user,
                    onSend: (_) {},
                    messages: messages,
                    readOnly: true,
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: CircularProgressIndicator(),
            ),
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type your message',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => askGemini(),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : askGemini,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
