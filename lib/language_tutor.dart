import 'dart:convert';

import 'package:chatbot_app/api_key.dart';
import 'package:chatbot_app/app_logger.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

class LanguageTutor extends StatefulWidget {
  const LanguageTutor({super.key});

  @override
  State<LanguageTutor> createState() => _LanguageTutorState();
}

class _LanguageTutorState extends State<LanguageTutor> {
  final AppLogger logger = AppLogger.instance;
  final ChatUser user = ChatUser(
    id: '1',
    firstName: 'Ammar',
    lastName: 'Shabbir',
  );
  final ChatUser tutorAI = ChatUser(
    id: '2',
    firstName: 'Language',
    lastName: 'Tutor',
  );
  final TextEditingController textEditingController = TextEditingController();
  final List<Map<String, dynamic>> conversation = [];
  final List<ChatMessage> messagesList = [];

  bool isLoadding = false;
  String? logFilePath;

  @override
  void initState() {
    super.initState();
    initializeLogger();
    seedWelcomeMessage();
  }

  Future<void> initializeLogger() async {
    final path = await logger.getLogFilePath();
    await logger.info(
      'Language tutor logger initialized',
      data: {'logFilePath': path},
    );

    if (!mounted) {
      return;
    }

    setState(() {
      logFilePath = path;
    });
  }

  void seedWelcomeMessage() {
    messagesList.insert(
      0,
      ChatMessage(
        text:
            'Hello! I am your language tutor.\n\n'
            'Send me any sentence, question, or short paragraph.\n'
            'I will help you with grammar, vocabulary, pronunciation tips, '
            'better phrasing, and natural examples.',
        user: tutorAI,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> showLogsDialog() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Application Logs'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<String>(
              future: logger.readLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data?.trim();
                return SingleChildScrollView(
                  child: SelectableText(
                    [
                      if (logFilePath != null) 'Log file: $logFilePath',
                      '',
                      if (logs == null || logs.isEmpty)
                        'No logs available yet.'
                      else
                        logs,
                    ].join('\n'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await logger.clearLogs();
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Clear Logs'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  void sendMessage() async {
    try {
      final userMessage = textEditingController.text.trim();
      if (userMessage.isEmpty) {
        await logger.warning(
          'Language tutor message skipped because the input was empty',
        );
        return;
      }

      if (mounted) {
        setState(() {
          isLoadding = true;
          messagesList.insert(
            0,
            ChatMessage(
              text: userMessage,
              user: user,
              createdAt: DateTime.now(),
            ),
          );
          conversation.add({
            "role": "user",
            "parts": [
              {"text": userMessage},
            ],
          });
          textEditingController.clear();
        });
      }

      final requestBody = {
        "system_instruction": {
          "parts": [
            {"text": _languageTutorInstruction},
          ],
        },
        "contents": conversation,
        "generationConfig": {
          "thinkingConfig": {"thinkingLevel": "low"},
        },
      };

      await logger.info(
        'Sending language tutor message',
        data: {
          'endpoint':
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent',
          'message': userMessage,
          'conversationLength': conversation.length,
        },
      );

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent',
        ),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': geminiApiKey,
        },
        body: jsonEncode(requestBody),
      );

      await logger.debug(
        'Language tutor API response received',
        data: {'statusCode': response.statusCode, 'body': response.body},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Language tutor request failed: '
          '${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tutorReply = _extractTextFromResponse(data);

      if (!mounted) {
        return;
      }

      setState(() {
        conversation.add({
          "role": "model",
          "parts": [
            {"text": tutorReply},
          ],
        });
        messagesList.insert(
          0,
          ChatMessage(
            text: tutorReply,
            user: tutorAI,
            createdAt: DateTime.now(),
          ),
        );
        isLoadding = false;
      });
    } catch (e, stackTrace) {
      await logger.error(
        'Failed to send language tutor message',
        error: e,
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isLoadding = false;
        messagesList.insert(
          0,
          ChatMessage(
            text: e.toString(),
            user: tutorAI,
            createdAt: DateTime.now(),
          ),
        );
      });
    }
  }

  String _extractTextFromResponse(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>? ?? [];
    final textBuffer = StringBuffer();

    for (final candidate in candidates) {
      final content =
          (candidate as Map<String, dynamic>)['content']
              as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>? ?? [];

      for (final part in parts) {
        final partMap = part as Map<String, dynamic>;
        final text = partMap['text'] as String?;
        if (text == null || text.trim().isEmpty) {
          continue;
        }

        if (textBuffer.isNotEmpty) {
          textBuffer.writeln();
        }
        textBuffer.write(text.trim());
      }
    }

    return textBuffer.isEmpty
        ? 'The tutor did not return any text.'
        : textBuffer.toString();
  }

  Widget _buildMessageText(
    ChatMessage message,
    ChatMessage? previousMessage,
    ChatMessage? nextMessage,
  ) {
    final isOwnMessage = message.user.id == user.id;
    final textColor = isOwnMessage ? Colors.white : Colors.black87;

    return MarkdownBody(
      data: message.text,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(color: textColor, fontSize: 16, height: 1.35),
        h1: TextStyle(
          color: textColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
        listBullet: TextStyle(color: textColor, fontSize: 16),
        blockquote: TextStyle(
          color: textColor.withValues(alpha: 0.9),
          fontStyle: FontStyle.italic,
          height: 1.35,
        ),
        code: TextStyle(
          color: isOwnMessage ? Colors.white : Colors.deepPurple.shade700,
          fontFamily: 'monospace',
          backgroundColor: isOwnMessage
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.deepPurple.shade50,
        ),
        codeblockDecoration: BoxDecoration(
          color: isOwnMessage
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset(
          'assets/animations/language_tutor_loader.json',
          width: 140,
          height: 140,
          repeat: true,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your tutor is preparing a better answer...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.deepPurple,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Language Tutor',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            onPressed: showLogsDialog,
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'View logs',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: isLoadding
                  ? _buildLoader()
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: DashChat(
                        currentUser: user,
                        onSend: (ChatMessage message) {},
                        messages: messagesList,
                        messageOptions: MessageOptions(
                          messageTextBuilder: _buildMessageText,
                        ),
                        readOnly: true,
                      ),
                    ),
            ),
          ),
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.translate_outlined, color: Colors.deepPurple),
                Expanded(
                  child: TextField(
                    controller: textEditingController,
                    decoration: const InputDecoration(
                      hintText: 'Type anything for language practice...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      sendMessage();
                    },
                  ),
                ),
                IconButton(
                  onPressed: sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const String _languageTutorInstruction = '''
You are a professional language tutor.

Your job:
- Help the user practice English or any language they request.
- Teach naturally, clearly, and patiently.
- If the target language is unclear, ask one short clarifying question.
- If the user writes a sentence, first respond to the meaning, then improve it.
- Correct grammar, spelling, punctuation, and word choice gently.
- Explain mistakes briefly and clearly.
- Give a more natural or native-like version when useful.
- Provide 1 to 3 short example sentences when they help learning.
- When pronunciation help is useful, provide an easy pronunciation hint.
- Keep responses practical, encouraging, and easy to follow.
- Use Markdown for headings, bullet points, and bold emphasis when it helps readability.
- Do not be overly verbose unless the user asks for detail.

Preferred response style:
1. Quick answer or correction.
2. Why it should be said that way.
3. Better examples.
4. A short practice question when useful.
''';
