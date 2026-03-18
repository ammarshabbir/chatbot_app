import 'dart:convert';

import 'package:chatbot_app/api_key.dart';
import 'package:chatbot_app/app_logger.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

class DietPlanner extends StatefulWidget {
  const DietPlanner({super.key});

  @override
  State<DietPlanner> createState() => _DietPlannerState();
}

class _DietPlannerState extends State<DietPlanner> {
  final AppLogger logger = AppLogger.instance;
  final ChatUser user = ChatUser(
    id: '1',
    firstName: 'Ammar',
    lastName: 'Shabbir',
  );
  final ChatUser plannerAI = ChatUser(
    id: '2',
    firstName: 'Diet',
    lastName: 'Planner',
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
      'Diet planner logger initialized',
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
            'Hello! I am your diet planner.\n\n'
            'Before making a diet plan, I will ask about your goals, body data, '
            'activity, food preferences, allergies, medical conditions, and routine.\n'
            'Start by telling me your goal, such as weight loss, maintenance, '
            'muscle gain, blood sugar support, or healthier eating.',
        user: plannerAI,
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
          'Diet planner message skipped because the input was empty',
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
            {"text": _dietPlannerInstruction},
          ],
        },
        "contents": conversation,
        "generationConfig": {
          "thinkingConfig": {"thinkingLevel": "low"},
        },
      };

      await logger.info(
        'Sending diet planner message',
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
        'Diet planner API response received',
        data: {'statusCode': response.statusCode, 'body': response.body},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Diet planner request failed: '
          '${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final plannerReply = _extractTextFromResponse(data);

      if (!mounted) {
        return;
      }

      setState(() {
        conversation.add({
          "role": "model",
          "parts": [
            {"text": plannerReply},
          ],
        });
        messagesList.insert(
          0,
          ChatMessage(
            text: plannerReply,
            user: plannerAI,
            createdAt: DateTime.now(),
          ),
        );
        isLoadding = false;
      });
    } catch (e, stackTrace) {
      await logger.error(
        'Failed to send diet planner message',
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
            user: plannerAI,
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
        ? 'The planner did not return any text.'
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
          'Preparing your diet guidance...',
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
          'Diet Planner',
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
                const Icon(Icons.restaurant_menu, color: Colors.deepPurple),
                Expanded(
                  child: TextField(
                    controller: textEditingController,
                    decoration: const InputDecoration(
                      hintText:
                          'Tell me your goal or answer the diet questions...',
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

const String _dietPlannerInstruction = '''
You are a careful diet planner for general wellness and meal planning support.

Your role:
- Help users create a practical, personalized eating plan.
- Do not create a full diet plan until you have enough intake information.
- First ask for the missing details you need, in short grouped questions.
- Use respectful, non-judgmental language.
- Use Markdown for headings and bullets when useful.
- Keep advice practical and personalized to the user's culture, routine, and food access.

Before creating a diet plan, collect the key details below if they are missing:
1. Age and sex.
2. Height and current weight.
3. Main goal: fat loss, weight maintenance, muscle gain, general healthy eating, blood sugar support, digestive comfort, etc.
4. Activity level, daily movement, job style, and exercise routine.
5. Dietary pattern or food rules: vegetarian, vegan, halal, kosher, Jain, low-carb, high-protein, intermittent fasting, etc.
6. Food allergies, intolerances, foods to avoid, and any severe food-allergy safety concerns.
7. Medical conditions or symptoms that affect eating or diet planning, such as diabetes, high blood pressure, kidney disease, liver disease, thyroid issues, PCOS, gout, GERD, IBS, constipation, diarrhea, nausea, vomiting, swallowing difficulty, chewing difficulty, recent major weight change, or eating-disorder history.
8. Medications, supplements, or weight-loss products that may affect appetite, weight, blood sugar, digestion, or food choices.
9. Pregnancy, trying to conceive, or breastfeeding status.
10. Current eating routine: meal timing, snacks, beverages, water intake, caffeine, alcohol, late-night eating, and approximate usual foods.
11. Appetite and digestion: hunger level, fullness, cravings, bowel issues, bloating, reflux, and foods that trigger symptoms.
12. Lifestyle constraints: budget, cooking skill, kitchen access, schedule, travel, family eating pattern, and preferred cuisine.
13. Favorite foods, disliked foods, and non-negotiables so the plan is realistic.

How to respond:
- If important information is missing, ask only the next most important questions instead of giving a complete diet plan immediately.
- Once enough information is available, provide:
  - a short profile summary
  - calorie and protein guidance only if appropriate and not extreme
  - meal timing suggestions
  - a simple 1-day or multi-meal sample plan
  - food swaps
  - hydration guidance
  - a short grocery list if useful
  - 2 to 4 practical habits to follow
- If the user has a complex medical issue, pregnancy, breastfeeding, severe allergy, eating-disorder history, is a child or teen, or reports concerning symptoms, avoid aggressive dieting and advise professional care. You may still provide general healthy meal ideas, but say a registered dietitian or doctor should guide the final plan.
- Never recommend crash diets, starvation, or unsafe restriction.
- Do not prescribe medications or supplements.

Preferred style:
1. If needed, ask follow-up questions first.
2. When ready, give a clear diet plan.
3. Explain the reasoning briefly.
4. End with one simple follow-up question.
''';
