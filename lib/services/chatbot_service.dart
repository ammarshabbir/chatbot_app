import 'package:dio/dio.dart';

import 'package:chatbot_app/models/chat_entry.dart';

class ChatBotService {
  ChatBotService({
    Dio? dioClient,
  }) : _dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: 'https://generativelanguage.googleapis.com',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  final Dio _dio;

  Future<String?> fetchReply({
    required List<ChatEntry> conversation,
  }) async {
    final List<Map<String, Object>> payload = conversation
        .map((ChatEntry entry) => entry.toContentPayload())
        .toList();

    final response = await _dio.post(
      '/v1beta/models/gemini-2.5-flash:generateContent',
      queryParameters: const {
        'key': 'AIzaSyB4kx4B4ujUWZsD3MfZEZVZwOiMVnbXbpA',
      },
      data: {
        'system_instruction': {
          'parts': [
            {'text': 'You are a senior flutter developer.'},
          ],
        },
        'contents': payload,
        'generationConfig': {
          'thinkingConfig': {'thinkingBudget': 0},
        },
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final candidates = response.data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return null;
    }
    final reply = candidates.first['content']['parts'][0]['text'] as String?;
    return reply;
  }
}
