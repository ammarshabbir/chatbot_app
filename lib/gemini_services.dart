import 'dart:convert';

import 'package:chatbot_app/api_key.dart';
import 'package:http/http.dart' as http;

class GeminiServices {
  Future<http.Response> askGemini(
    List<Map<String, Object>> conversationHistory,
  ) async {
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

    return http.post(url, headers: headers, body: body);
  }
}
