import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:dash_chat_2/dash_chat_2.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://generativelanguage.googleapis.com',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  var result = 'Ask me anything!';

  Future<void> askGemini() async {
    try {
      var input = _inputController.text;
      _inputController.clear();
      messages.insert(
        0,
        ChatMessage(user: user, createdAt: DateTime.now(), text: input),
      );
      setState(() {
        messages;
      });

      final response = await dio.post(
        '/v1beta/models/gemini-2.5-flash:generateContent',
        queryParameters: {
          'key':
              'AIzaSyB4kx4B4ujUWZsD3MfZEZVZwOiMVnbXbpA', // move your key here
        },
        data: {
          'contents': [
            {
              'parts': [
                {'text': input},
              ],
            },
          ],
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print(response.data);
      if (response.statusCode == 200) {
        final generations = response.data['candidates'] as List<dynamic>;
        if (generations.isNotEmpty) {
          result = generations[0]['content']['parts'][0]['text'];
          messages.insert(
            0,
            ChatMessage(
              user: gameniModel,
              createdAt: DateTime.now(),
              text: result,
            ),
          );
          setState(() {
            messages;
          });
        }
      }
    } on DioException catch (e) {
      // Helpful diagnostics
      print('Dio error: ${e.type} ${e.message}');
      if (e.response != null) {
        print('Status: ${e.response?.statusCode}');
        print('Body: ${e.response?.data}');
      }
    } catch (e) {
      print('Unexpected error: $e');
    }
  }

  TextEditingController _inputController = TextEditingController();

  ChatUser user = ChatUser(id: '1', firstName: 'Ammar', lastName: 'Shabbir');
  ChatUser gameniModel = ChatUser(
    id: '2',
    firstName: 'Gameni',
    lastName: 'Model',
  );

  List<ChatMessage> messages = [];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Chat Bot')),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: DashChat(
                  readOnly: true,
                  currentUser: user,
                  onSend: (ChatMessage m) {},
                  messages: messages,
                ),
              ),
            ),
            Card(
              color: Colors.white,
              margin: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 15),
                        hintText: 'Type your message',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      askGemini();
                    },
                    icon: Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
