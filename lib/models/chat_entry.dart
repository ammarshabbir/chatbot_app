enum ChatRole { user, model }

class ChatEntry {
  const ChatEntry({
    required this.role,
    required this.text,
  });

  final ChatRole role;
  final String text;

  Map<String, Object> toContentPayload() {
    return {
      'role': role == ChatRole.user ? 'user' : 'model',
      'parts': [
        {'text': text},
      ],
    };
  }
}
