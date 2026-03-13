import 'dart:convert';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chatbot_app/api_key.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  List<Map<String, Object>> conversationHistory = [];

  Future<void> askGemini() async {
    final question = _questionController.text.trim();

    if (question.isEmpty) {
      return;
    }

    setState(() {
      conversationHistory.add({
        "role": "user",
        "parts": [
          {"text": question},
        ],
      });
      messages.insert(
        0,
        ChatMessage(
          user: currentUser,
          createdAt: DateTime.now(),
          text: question,
        ),
      );
      _isLoading = true;
    });

    _questionController.clear();
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent',
    );
    final headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': geminiApiKey,
    };
    final body = jsonEncode({
      "contents": conversationHistory,
      "generationConfig": {
        "thinkingConfig": {"thinkingLevel": "low"},
      },
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final text =
            decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
                as String?;
        final reply = text?.trim();

        setState(() {
          messages.insert(
            0,
            ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: reply?.isNotEmpty == true
                  ? reply!
                  : 'Empty response from Gemini.',
            ),
          );
          conversationHistory.add({
            "role": "model",
            "parts": [
              {
                "text": reply?.isNotEmpty == true
                    ? reply!
                    : 'Empty response from Gemini.',
              },
            ],
          });
        });
      } else {
        setState(() {
          messages.insert(
            0,
            ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: 'Error ${response.statusCode}: ${response.body}',
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.insert(
          0,
          ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: 'Request failed: $e',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<ChatMessage> messages = [];
  final ChatUser currentUser = ChatUser(
    id: '1',
    firstName: 'Ammar',
    lastName: 'Shabbir',
  );

  final ChatUser geminiUser = ChatUser(
    id: '2',
    firstName: 'Gemini',
    lastName: 'AI',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: Text('Gemini ChatBot', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DashChat(
                    currentUser: currentUser,
                    onSend: (m) {},
                    messages: messages,
                    readOnly: true,
                  ),
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,

                      decoration: InputDecoration(
                        hintText: 'Type your message here...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                        ),
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
