import 'package:flutter/foundation.dart';

class AppSettings extends ChangeNotifier {
  String _ttsLanguage = 'en-US';
  Map<String, String>? _ttsVoice;
  String _speechLocaleId = 'en_US';

  String get ttsLanguage => _ttsLanguage;
  Map<String, String>? get ttsVoice => _ttsVoice;
  String get speechLocaleId => _speechLocaleId;

  void updateTtsLanguage(String language) {
    if (_ttsLanguage == language) {
      return;
    }
    _ttsLanguage = language;
    _ttsVoice = null;
    notifyListeners();
  }

  void updateTtsVoice(Map<String, String>? voice) {
    if (_ttsVoice != null &&
        voice != null &&
        mapEquals<String, String>(_ttsVoice, voice)) {
      return;
    }
    if (_ttsVoice == null && voice == null) {
      return;
    }
    _ttsVoice = voice;
    notifyListeners();
  }

  void updateSpeechLocale(String localeId) {
    if (_speechLocaleId == localeId) {
      return;
    }
    _speechLocaleId = localeId;
    notifyListeners();
  }
}
