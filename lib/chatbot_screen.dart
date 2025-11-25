import 'dart:async';
import 'package:chatbot_app/settings_screen.dart';
import 'package:chatbot_app/viewmodels/app_settings.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:chatbot_app/viewmodels/chatbot_view_model.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _inputController = TextEditingController();
  late final FlutterTts _flutterTts;
  late final SpeechToText _speechToText;
  bool _isTtsReady = false;
  bool _isRecording = false;
  bool _speechAvailable = false;
  String? _speechError;
  String? _currentTtsLanguage;
  Map<String, String>? _currentTtsVoice;
  String _currentSpeechLocaleId = 'en_US';
  bool _isListeningDialogOpen = false;

  @override
  void dispose() {
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _speechToText = SpeechToText();
    _inputController.addListener(_onTextChanged);
    _configureTts();
    _initializeSpeech();
  }

  Future<void> _configureTts() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    if (!mounted) {
      return;
    }
    setState(() {
      _isTtsReady = true;
    });
  }

  Future<void> _initializeSpeech() async {
    final available = await _speechToText.initialize(
      onError: (error) {
        debugPrint('Speech error: $error');
        if (!mounted) {
          return;
        }
        setState(() {
          _isRecording = false;
          _speechError = error.errorMsg;
        });
      },
      onStatus: (status) {
        debugPrint('Speech status: $status');
      },
      debugLogging: false,
    );
    final hasPermission = await _speechToText.hasPermission;
    if (!mounted) {
      return;
    }
    setState(() {
      _speechAvailable = available && hasPermission;
      if (_speechAvailable) {
        _speechError = null;
      } else if (!hasPermission) {
        _speechError =
            'Microphone permission denied. Please enable it in system settings.';
      }
    });
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _speakMessage(ChatMessage message) async {
    if (!_isTtsReady) {
      return;
    }
    final text = message.text.trim();
    if (text.isEmpty) {
      return;
    }
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      return;
    }
    if (!await _speechToText.hasPermission) {
      final permissionGranted = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech error: $error');
          _speechError = error.errorMsg;
        },
        onStatus: (_) {},
      );
      final hasPermission = await _speechToText.hasPermission;
      if (!permissionGranted || !hasPermission) {
        if (!mounted) {
          return;
        }
        setState(() {
          _speechError ??=
              'Microphone permission required. Please grant access and try again.';
        });
        return;
      }
    }
    await _flutterTts.stop();
    bool started = false;
    try {
      started = await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: _currentSpeechLocaleId.isNotEmpty
            ? _currentSpeechLocaleId
            : null,
      );
    } catch (error) {
      debugPrint('Speech listen failed: $error');
      if (mounted) {
        setState(() {
          _speechError =
              'Unable to start listening (${error.runtimeType}). Please try again.';
        });
        _hideListeningDialog();
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = started;
      if (started) {
        _speechError = null;
        _showListeningDialog();
      } else {
        _speechError ??= 'Unable to start listening. Please try again.';
      }
    });
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    _hideListeningDialog();
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = false;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.recognizedWords.isEmpty) {
      return;
    }
    _inputController.text = result.recognizedWords;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
    if (result.finalResult) {
      _stopListening();
    }
  }

  Future<void> _syncSettings(AppSettings settings) async {
    if (_currentSpeechLocaleId != settings.speechLocaleId) {
      _currentSpeechLocaleId = settings.speechLocaleId;
    }

    if (_currentTtsLanguage != settings.ttsLanguage) {
      _currentTtsLanguage = settings.ttsLanguage;
      try {
        await _flutterTts.setLanguage(settings.ttsLanguage);
      } catch (error) {
        debugPrint(
          'Failed to set TTS language ${settings.ttsLanguage}: $error',
        );
      }
    }

    final selectedVoice = settings.ttsVoice;
    final hasVoiceChanged =
        (selectedVoice == null && _currentTtsVoice != null) ||
        (selectedVoice != null &&
            (_currentTtsVoice == null ||
                !mapEquals<String, String>(_currentTtsVoice!, selectedVoice)));
    if (hasVoiceChanged) {
      _currentTtsVoice = selectedVoice;
      if (selectedVoice != null &&
          selectedVoice.containsKey('name') &&
          selectedVoice.containsKey('locale')) {
        try {
          await _flutterTts.setVoice({
            'name': selectedVoice['name']!,
            'locale': selectedVoice['locale']!,
          });
        } catch (error) {
          debugPrint('Failed to set TTS voice: $error');
        }
      }
    }
  }

  Widget _buildActionButton(ChatBotViewModel viewModel) {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (_isRecording) {
      return IconButton(
        onPressed: _stopListening,
        icon: const Icon(Icons.stop),
        color: Colors.red,
      );
    }
    if (hasText) {
      return IconButton(
        onPressed: viewModel.isThinking
            ? null
            : () {
                final text = _inputController.text;
                if (text.trim().isEmpty) {
                  return;
                }
                viewModel.sendMessage(text);
                _inputController.clear();
              },
        icon: const Icon(Icons.send),
      );
    }
    return IconButton(
      onPressed: _speechAvailable && !viewModel.isThinking ? _startListening : null,
      icon: const Icon(Icons.mic),
    );
  }

  Widget _buildImageButton(ChatBotViewModel viewModel) {
    final hasText = _inputController.text.trim().isNotEmpty;
    return IconButton(
      tooltip: 'Generate image',
      onPressed: hasText && !viewModel.isThinking
          ? () {
              final text = _inputController.text;
              if (text.trim().isEmpty) {
                return;
              }
              viewModel.generateImageFromPrompt(text);
              _inputController.clear();
            }
          : null,
      icon: const Icon(Icons.image_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();
    unawaited(_syncSettings(appSettings));

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
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings),
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
                          const Icon(Icons.error_outline, color: Colors.red),
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
                  if (_speechError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mic_off_outlined,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _speechError!,
                              style: const TextStyle(color: Colors.orange),
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
                        messageOptions: MessageOptions(
                          bottom: (message, previous, next) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Align(
                                alignment: message.user.id == viewModel.user.id
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: IconButton(
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Speak message',
                                  onPressed: _isTtsReady
                                      ? () => _speakMessage(message)
                                      : null,
                                  icon: const Icon(Icons.volume_up_outlined),
                                ),
                              ),
                            );
                          },
                        ),
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
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              hintText: 'Type your message',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        _buildImageButton(viewModel),
                        _buildActionButton(viewModel),
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

  void _showListeningDialog() {
    if (_isListeningDialogOpen || !mounted) {
      return;
    }
    _isListeningDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isListeningDialogOpen = false;
        return;
      }
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            content: SizedBox(
              width: 220,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Listening...',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _hideListeningDialog() {
    if (!_isListeningDialogOpen || !mounted) {
      return;
    }
    _isListeningDialogOpen = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
