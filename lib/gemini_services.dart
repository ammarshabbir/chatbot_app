import 'dart:convert';

import 'package:chatbot_app/api_key.dart';
import 'package:http/http.dart' as http;

class GeminiServices {
  Future<String> askGemini(List<Map<String, Object>> conversation) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent',
    );

    final response = await http.post(
      url,
      headers: {
        'x-goog-api-key': geminiApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': conversation,
        'generationConfig': {
          'thinkingConfig': {'thinkingLevel': 'low'},
        },
      }),
    );

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error =
          responseBody['error']?['message'] as String? ?? response.body;
      throw Exception('API ${response.statusCode}: $error');
    }

    final candidates = responseBody['candidates'] as List<dynamic>?;
    final text =
        candidates?[0]?['content']?['parts']?[0]?['text'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    return text.trim();
  }
}
