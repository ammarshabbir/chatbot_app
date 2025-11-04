import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chatbot_app/viewmodels/chatbot_view_model.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatBotViewModel>(
      create: (_) => ChatBotViewModel(),
      child: Consumer<ChatBotViewModel>(
        builder: (context, viewModel, _) {
          return SafeArea(
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Chat Bot'),
                actions: [
                  IconButton(
                    tooltip: 'Clear conversation',
                    onPressed: viewModel.messages.isEmpty
                        ? null
                        : () {
                            viewModel.clearChat();
                          },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              viewModel.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: DashChat(
                        readOnly: true,
                        currentUser: viewModel.user,
                        onSend: (ChatMessage m) {},
                        messages: viewModel.messages,
                        typingUsers: viewModel.isThinking
                            ? [viewModel.geminiModel]
                            : const [],
                      ),
                    ),
                  ),
                  Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(
                      left: 15,
                      right: 15,
                      bottom: 15,
                      top: 15,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            decoration: const InputDecoration(
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 15),
                              hintText: 'Type your message',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final text = _inputController.text;
                            if (text.trim().isEmpty) {
                              return;
                            }
                            viewModel.sendMessage(text);
                            _inputController.clear();
                          },
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
