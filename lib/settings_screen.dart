import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:chatbot_app/viewmodels/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();

  bool _isLoading = true;
  bool _speechSupported = false;
  String? _speechError;

  List<String> _ttsLanguages = [];
  List<Map<String, String>> _ttsVoices = [];
  List<LocaleName> _speechLocales = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      final languagesDynamic = await _flutterTts.getLanguages;
      final voicesDynamic = await _flutterTts.getVoices;

      final List<String> languages = languagesDynamic is List
          ? languagesDynamic.map((dynamic lang) => lang.toString()).toList()
          : <String>[];

      final List<Map<String, String>> voices = <Map<String, String>>[];
      if (voicesDynamic is List) {
        for (final dynamic voice in voicesDynamic) {
          if (voice is Map) {
            voices.add(
              voice.map(
                (dynamic key, dynamic value) => MapEntry(
                  key.toString(),
                  value.toString(),
                ),
              ),
            );
          }
        }
      }

      bool speechAvailable = false;
      List<LocaleName> locales = [];
      try {
        speechAvailable = await _speechToText.initialize(
          onError: (SpeechRecognitionError error) {
            _speechError = error.errorMsg;
          },
          onStatus: (_) {},
        );
        if (speechAvailable) {
          locales = await _speechToText.locales();
        }
      } catch (error) {
        _speechError = error.toString();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        final fallbackLanguages =
            languages.isNotEmpty ? languages : <String>['en-US', 'en_US'];
        _ttsLanguages = fallbackLanguages.toSet().toList()..sort();
        _ttsVoices = voices;
        _speechSupported = speechAvailable;
        _speechLocales = locales.isNotEmpty
            ? locales
            : <LocaleName>[LocaleName('en_US', 'English')];
        _isLoading = false;
        _speechError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speechError = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  List<Map<String, String>> _voicesForLanguage(String language) {
    if (_ttsVoices.isEmpty) {
      return const [];
    }
    return _ttsVoices.where((voice) {
      final locale = voice['locale'] ?? '';
      return locale.toLowerCase() == language.toLowerCase();
    }).toList()
      ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AppSettings>(
        builder: (context, settings, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final voicesForLanguage = _voicesForLanguage(settings.ttsLanguage);
          Map<String, String>? selectedVoice;
          if (settings.ttsVoice != null) {
            try {
              selectedVoice = voicesForLanguage.firstWhere(
                (voice) =>
                    mapEquals<String, String>(voice, settings.ttsVoice),
              );
            } catch (_) {
              selectedVoice = null;
            }
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Text to Speech',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Voice language',
                  border: OutlineInputBorder(),
                ),
                initialValue: _ttsLanguages.contains(settings.ttsLanguage)
                    ? settings.ttsLanguage
                    : (_ttsLanguages.isNotEmpty ? _ttsLanguages.first : null),
                items: _ttsLanguages
                    .map(
                      (lang) => DropdownMenuItem<String>(
                        value: lang,
                        child: Text(lang),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    context.read<AppSettings>().updateTtsLanguage(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, String>?>(
                decoration: const InputDecoration(
                  labelText: 'Voice style',
                  border: OutlineInputBorder(),
                ),
                initialValue: selectedVoice,
                items: [
                  const DropdownMenuItem<Map<String, String>?>(
                    value: null,
                    child: Text('System default'),
                  ),
                  ...voicesForLanguage
                    .map(
                      (voice) => DropdownMenuItem<Map<String, String>?>(
                        value: voice,
                        child: Text(
                          '${voice['name']} (${voice['locale']})',
                        ),
                      ),
                    ),
                ],
                onChanged: voicesForLanguage.isEmpty
                    ? null
                    : (voice) =>
                        context.read<AppSettings>().updateTtsVoice(voice),
              ),
              if (voicesForLanguage.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No voices available for ${settings.ttsLanguage}.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Speech Recognition',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (_speechSupported)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Listening language',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _speechLocales.any((locale) =>
                          locale.localeId == settings.speechLocaleId)
                      ? settings.speechLocaleId
                      : (_speechLocales.isNotEmpty
                          ? _speechLocales.first.localeId
                          : null),
                  items: _speechLocales
                      .map(
                        (locale) => DropdownMenuItem<String>(
                          value: locale.localeId,
                          child: Text(locale.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<AppSettings>().updateSpeechLocale(value);
                    }
                  },
                )
              else
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _speechError == null
                          ? 'Speech recognition is unavailable on this device.'
                          : 'Speech recognition error: $_speechError',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
