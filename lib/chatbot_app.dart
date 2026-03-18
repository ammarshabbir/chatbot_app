import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chatbot_app/api_key.dart';
import 'package:chatbot_app/app_logger.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

class ChatBotApp extends StatefulWidget {
  const ChatBotApp({super.key});

  @override
  State<ChatBotApp> createState() => _ChatBotAppState();
}

enum _AttachmentType { image, video, audio, pdf }

class _SelectedAttachment {
  const _SelectedAttachment({
    required this.type,
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.fileUri,
    this.remoteName,
  });

  final _AttachmentType type;
  final String path;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String? fileUri;
  final String? remoteName;

  String get label {
    switch (type) {
      case _AttachmentType.image:
        return 'image';
      case _AttachmentType.video:
        return 'video';
      case _AttachmentType.audio:
        return 'audio';
      case _AttachmentType.pdf:
        return 'PDF';
    }
  }

  IconData get icon {
    switch (type) {
      case _AttachmentType.image:
        return Icons.image_outlined;
      case _AttachmentType.video:
        return Icons.videocam_outlined;
      case _AttachmentType.audio:
        return Icons.audio_file_outlined;
      case _AttachmentType.pdf:
        return Icons.picture_as_pdf_outlined;
    }
  }

  bool get usesInlineData => type == _AttachmentType.image;

  _SelectedAttachment copyWith({String? fileUri, String? remoteName}) {
    return _SelectedAttachment(
      type: type,
      path: path,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      fileUri: fileUri ?? this.fileUri,
      remoteName: remoteName ?? this.remoteName,
    );
  }
}

class _ChatBotAppState extends State<ChatBotApp> {
  final AppLogger logger = AppLogger.instance;
  final ChatUser user = ChatUser(
    id: '1',
    firstName: 'Ammar',
    lastName: 'Shabbir',
  );
  final ChatUser geminiAI = ChatUser(
    id: '2',
    firstName: 'Gemini',
    lastName: 'AI',
  );
  final TextEditingController textEditingController = TextEditingController();
  final List<Map<String, dynamic>> conversation = [];
  final List<ChatMessage> messagesList = [];
  String message = 'message should be shown there';
  bool isLoadding = false;
  String? logFilePath;
  _SelectedAttachment? selectedAttachment;

  @override
  void initState() {
    super.initState();
    initializeLogger();
  }

  Future<void> initializeLogger() async {
    final path = await logger.getLogFilePath();
    await logger.info('Logger initialized', data: {'logFilePath': path});

    if (!mounted) {
      return;
    }

    setState(() {
      logFilePath = path;
    });
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
          'Chat message skipped because the input was empty',
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
        "contents": conversation,
        "generationConfig": {
          "thinkingConfig": {"thinkingLevel": "low"},
        },
      };

      await logger.info(
        'Sending chat message',
        data: {
          'endpoint':
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent',
          'message': userMessage,
          'conversationLength': conversation.length,
          'requestBody': requestBody,
        },
      );

      var respose = await http.post(
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
        'Chat API response received',
        data: {'statusCode': respose.statusCode, 'body': respose.body},
      );

      if (respose.statusCode == 200) {
        final data = jsonDecode(respose.body) as Map<String, dynamic>;
        final responseText = _extractTextFromResponse(data);
        if (mounted) {
          setState(() {
            message = responseText;
            messagesList.insert(
              0,
              ChatMessage(
                text: responseText,
                user: geminiAI,
                createdAt: DateTime.now(),
              ),
            );
            conversation.add({
              "role": "model",
              "parts": [
                {"text": responseText},
              ],
            });
            isLoadding = false;
          });
        }
      } else {
        await logger.error(
          'Chat API returned a non-success status',
          data: {'statusCode': respose.statusCode, 'body': respose.body},
        );
        if (mounted) {
          setState(() {
            isLoadding = false;
            messagesList.insert(
              0,
              ChatMessage(
                text: respose.body,
                user: geminiAI,
                createdAt: DateTime.now(),
              ),
            );
          });
        }
      }
    } catch (e, stackTrace) {
      await logger.error(
        'Failed to send chat message',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          isLoadding = false;
          messagesList.insert(
            0,
            ChatMessage(
              text: e.toString(),
              user: geminiAI,
              createdAt: DateTime.now(),
            ),
          );
        });
      }
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
        ? 'The model did not return any text.'
        : textBuffer.toString();
  }

  Future<void> showAttachmentOptions() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Pick Image'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  pickAttachment(_AttachmentType.image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Pick Video'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  pickAttachment(_AttachmentType.video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.audio_file_outlined),
                title: const Text('Pick Audio'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  pickAttachment(_AttachmentType.audio);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Pick PDF'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  pickAttachment(_AttachmentType.pdf);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> pickAttachment(_AttachmentType type) async {
    try {
      FilePickerResult? result;

      switch (type) {
        case _AttachmentType.image:
          result = await FilePicker.platform.pickFiles(type: FileType.image);
        case _AttachmentType.video:
          result = await FilePicker.platform.pickFiles(type: FileType.video);
        case _AttachmentType.audio:
          result = await FilePicker.platform.pickFiles(type: FileType.audio);
        case _AttachmentType.pdf:
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
      }

      if (result == null || result.files.isEmpty) {
        return;
      }

      final platformFile = result.files.single;
      final filePath = platformFile.path;
      if (filePath == null) {
        throw Exception('The selected file path is unavailable.');
      }

      final attachment = _SelectedAttachment(
        type: type,
        path: filePath,
        fileName: platformFile.name,
        mimeType: lookupMimeType(filePath) ?? _defaultMimeType(type),
        sizeBytes: platformFile.size,
      );

      await logger.info(
        'Attachment selected',
        data: {
          'type': attachment.label,
          'path': attachment.path,
          'mimeType': attachment.mimeType,
          'sizeBytes': attachment.sizeBytes,
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        selectedAttachment = attachment;
        messagesList.insert(0, _buildAttachmentMessage(attachment));
      });
    } catch (e, stackTrace) {
      await logger.error(
        'Failed to pick attachment',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        messagesList.insert(
          0,
          ChatMessage(
            text: 'Unable to pick file: $e',
            user: geminiAI,
            createdAt: DateTime.now(),
          ),
        );
      });
    }
  }

  ChatMessage _buildAttachmentMessage(_SelectedAttachment attachment) {
    return ChatMessage(
      text:
          'Attached ${attachment.label}: ${attachment.fileName}\n'
          'Type: ${attachment.mimeType}\n'
          'Size: ${_formatFileSize(attachment.sizeBytes)}\n'
          'Ask a question about this file to get details.',
      user: user,
      createdAt: DateTime.now(),
      medias: [
        ChatMedia(
          url: attachment.path,
          fileName: attachment.fileName,
          type: attachment.type == _AttachmentType.image
              ? MediaType.image
              : MediaType.file,
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _defaultMimeType(_AttachmentType type) {
    switch (type) {
      case _AttachmentType.image:
        return 'image/jpeg';
      case _AttachmentType.video:
        return 'video/mp4';
      case _AttachmentType.audio:
        return 'audio/mpeg';
      case _AttachmentType.pdf:
        return 'application/pdf';
    }
  }

  String _defaultPromptForAttachment(_AttachmentType type) {
    switch (type) {
      case _AttachmentType.image:
        return 'Describe this image in detail.';
      case _AttachmentType.video:
        return 'Summarize this video and list the important moments.';
      case _AttachmentType.audio:
        return 'Transcribe and summarize this audio.';
      case _AttachmentType.pdf:
        return 'Summarize this PDF and extract the key points.';
    }
  }

  Future<void> analyzeSelectedAttachment() async {
    final attachment = selectedAttachment;
    if (attachment == null) {
      return;
    }

    try {
      final typedPrompt = textEditingController.text.trim();
      final prompt = typedPrompt.isEmpty
          ? _defaultPromptForAttachment(attachment.type)
          : typedPrompt;

      if (mounted) {
        setState(() {
          isLoadding = true;
          messagesList.insert(
            0,
            ChatMessage(text: prompt, user: user, createdAt: DateTime.now()),
          );
          textEditingController.clear();
        });
      }

      await logger.info(
        'Analyzing selected attachment',
        data: {
          'type': attachment.label,
          'fileName': attachment.fileName,
          'mimeType': attachment.mimeType,
          'prompt': prompt,
        },
      );

      final responseText = attachment.usesInlineData
          ? await _analyzeInlineAttachment(attachment, prompt)
          : await _analyzeUploadedAttachment(attachment, prompt);

      if (!mounted) {
        return;
      }

      setState(() {
        messagesList.insert(
          0,
          ChatMessage(
            text: responseText,
            user: geminiAI,
            createdAt: DateTime.now(),
          ),
        );
        isLoadding = false;
      });
    } catch (e, stackTrace) {
      await logger.error(
        'Failed to analyze attachment',
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
            user: geminiAI,
            createdAt: DateTime.now(),
          ),
        );
      });
    }
  }

  Future<String> _analyzeInlineAttachment(
    _SelectedAttachment attachment,
    String prompt,
  ) async {
    final bytes = await File(attachment.path).readAsBytes();
    final requestBody = {
      "contents": [
        {
          "parts": [
            {
              "inline_data": {
                "mime_type": attachment.mimeType,
                "data": base64Encode(bytes),
              },
            },
            {"text": prompt},
          ],
        },
      ],
    };

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
      'Inline attachment response received',
      data: {'statusCode': response.statusCode, 'body': response.body},
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Attachment request failed: ${response.statusCode} ${response.body}',
      );
    }

    return _extractTextFromResponse(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> _analyzeUploadedAttachment(
    _SelectedAttachment attachment,
    String prompt,
  ) async {
    final uploadedAttachment = await _ensureAttachmentUploaded(attachment);

    final requestBody = {
      "contents": [
        {
          "parts": [
            {
              "file_data": {
                "mime_type": uploadedAttachment.mimeType,
                "file_uri": uploadedAttachment.fileUri,
              },
            },
            {"text": prompt},
          ],
        },
      ],
    };

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
      'Uploaded attachment response received',
      data: {'statusCode': response.statusCode, 'body': response.body},
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Attachment request failed: ${response.statusCode} ${response.body}',
      );
    }

    return _extractTextFromResponse(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<_SelectedAttachment> _ensureAttachmentUploaded(
    _SelectedAttachment attachment,
  ) async {
    if (attachment.fileUri != null && attachment.remoteName != null) {
      return attachment;
    }

    final bytes = await File(attachment.path).readAsBytes();
    final startUploadResponse = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/upload/v1beta/files',
      ),
      headers: {
        'x-goog-api-key': geminiApiKey,
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': bytes.length.toString(),
        'X-Goog-Upload-Header-Content-Type': attachment.mimeType,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file': {'display_name': attachment.fileName},
      }),
    );

    if (startUploadResponse.statusCode < 200 ||
        startUploadResponse.statusCode >= 300) {
      throw HttpException(
        'Failed to start upload: '
        '${startUploadResponse.statusCode} ${startUploadResponse.body}',
      );
    }

    final uploadUrl = startUploadResponse.headers['x-goog-upload-url'];
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw Exception('Gemini did not return an upload URL.');
    }

    final finalizeUploadResponse = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Length': bytes.length.toString(),
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
      },
      body: bytes,
    );

    if (finalizeUploadResponse.statusCode < 200 ||
        finalizeUploadResponse.statusCode >= 300) {
      throw HttpException(
        'Failed to upload file: '
        '${finalizeUploadResponse.statusCode} ${finalizeUploadResponse.body}',
      );
    }

    final uploadData =
        jsonDecode(finalizeUploadResponse.body) as Map<String, dynamic>;
    final fileData = (uploadData['file'] ?? uploadData) as Map<String, dynamic>;
    final uploadedAttachment = attachment.copyWith(
      fileUri: fileData['uri'] as String?,
      remoteName: fileData['name'] as String?,
    );

    final readyAttachment = await _waitUntilFileIsReady(
      uploadedAttachment,
      initialState: fileData['state'],
    );

    if (mounted) {
      setState(() {
        selectedAttachment = readyAttachment;
      });
    }

    return readyAttachment;
  }

  Future<_SelectedAttachment> _waitUntilFileIsReady(
    _SelectedAttachment attachment, {
    Object? initialState,
  }) async {
    final currentState = _extractFileState(initialState);
    if (currentState == null || currentState == 'ACTIVE') {
      return attachment;
    }

    if (attachment.remoteName == null) {
      throw Exception('Uploaded file is missing a remote name.');
    }

    for (var attempt = 0; attempt < 15; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));

      final response = await http.get(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/${attachment.remoteName}',
        ),
        headers: {'x-goog-api-key': geminiApiKey},
      );

      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to check file status: ${response.statusCode} ${response.body}',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final fileData = (body['file'] ?? body) as Map<String, dynamic>;
      final state = _extractFileState(fileData['state']);

      if (state == 'ACTIVE' || state == null) {
        return attachment.copyWith(
          fileUri: fileData['uri'] as String?,
          remoteName: fileData['name'] as String?,
        );
      }

      if (state == 'FAILED') {
        throw Exception('Gemini failed to process the selected file.');
      }
    }

    throw TimeoutException(
      'Gemini is still processing the file. Try again in a moment.',
    );
  }

  String? _extractFileState(Object? state) {
    if (state == null) {
      return null;
    }

    if (state is String) {
      return state;
    }

    if (state is Map<String, dynamic>) {
      return state['name'] as String?;
    }

    return state.toString();
  }

  void generateImage() async {
    try {
      final originalPrompt = textEditingController.text.trim();
      final imagePrompt = _extractImagePrompt(originalPrompt);
      if (imagePrompt.isEmpty) {
        await logger.warning(
          'Image generation skipped because the prompt was empty',
          data: {'originalPrompt': originalPrompt},
        );
        return;
      }

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": imagePrompt},
            ],
          },
        ],
        "generationConfig": {
          "imageConfig": {"aspectRatio": "1:1"},
        },
      };

      await logger.info(
        'Generating image',
        data: {
          'endpoint':
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent',
          'originalPrompt': originalPrompt,
          'imagePrompt': imagePrompt,
          'requestBody': requestBody,
        },
      );

      if (mounted) {
        setState(() {
          isLoadding = true;
          messagesList.insert(
            0,
            ChatMessage(
              text: imagePrompt,
              user: user,
              createdAt: DateTime.now(),
            ),
          );

          textEditingController.clear();
        });
      }
      var respose = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent',
        ),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': geminiApiKey,
        },

        body: jsonEncode(requestBody),
      );

      await logger.debug(
        'Image API response received',
        data: {'statusCode': respose.statusCode, 'body': respose.body},
      );

      if (respose.statusCode == 200) {
        var data = jsonDecode(respose.body);

        var candidates = data['candidates'] as List<dynamic>;
        var content = candidates[0]['content'];
        var parts = content['parts'] as List<dynamic>;
        final generatedText = StringBuffer();
        ChatMedia? generatedMedia;

        for (var part in parts) {
          if (part.containsKey('text')) {
            if (generatedText.isNotEmpty) {
              generatedText.writeln();
            }
            generatedText.write(part['text']);
          } else if (generatedMedia == null &&
              (part.containsKey('inlineData') ||
                  part.containsKey('inline_data'))) {
            final inlineData =
                (part['inlineData'] ?? part['inline_data'])
                    as Map<String, dynamic>;
            final mimeType =
                (inlineData['mimeType'] ?? inlineData['mime_type'])
                    as String? ??
                'image/png';
            final base64Data = inlineData['data'] as String;
            final bytes = base64Decode(base64Data);
            final fileExtension = extensionFromMime(mimeType) ?? 'png';

            final imagePath = await saveTemporaryFile(
              bytes,
              extension: fileExtension,
            );
            generatedMedia = ChatMedia(
              url: imagePath,
              type: mimeType.startsWith('image/')
                  ? MediaType.image
                  : MediaType.file,
              fileName: 'generated_image.$fileExtension',
            );
          }
        }

        if (generatedMedia == null && generatedText.isEmpty) {
          await logger.error(
            'Image response did not contain displayable content',
            data: {'body': data},
          );
        }

        if (mounted) {
          setState(() {
            messagesList.insert(
              0,
              ChatMessage(
                text: generatedText.isEmpty
                    ? (generatedMedia != null
                          ? 'Generated image'
                          : 'The model did not return an image.')
                    : generatedText.toString(),
                user: geminiAI,
                createdAt: DateTime.now(),
                medias: generatedMedia == null ? [] : [generatedMedia],
              ),
            );
            isLoadding = false;
          });
        } else {
          isLoadding = false;
        }
      } else {
        await logger.error(
          'Image API returned a non-success status',
          data: {'statusCode': respose.statusCode, 'body': respose.body},
        );
        if (mounted) {
          setState(() {
            isLoadding = false;
            messagesList.insert(
              0,
              ChatMessage(
                text: respose.body,
                user: geminiAI,
                createdAt: DateTime.now(),
              ),
            );
          });
        }
      }
    } catch (e, stackTrace) {
      await logger.error(
        'Failed to generate image',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          isLoadding = false;
          messagesList.insert(
            0,
            ChatMessage(
              text: e.toString(),
              user: geminiAI,
              createdAt: DateTime.now(),
            ),
          );
        });
      }
    }
  }

  void indentifyPromt() {
    if (selectedAttachment != null) {
      analyzeSelectedAttachment();
    } else if (_isImagePrompt(textEditingController.text)) {
      generateImage();
    } else {
      sendMessage();
    }
  }

  bool _isImagePrompt(String input) {
    final normalizedInput = input.trim().toLowerCase();
    const imagePromptPrefixes = [
      'generate image',
      'generate an image',
      'create image',
      'create an image',
      'draw image',
      'draw an image',
      'image:',
    ];

    return imagePromptPrefixes.any(normalizedInput.startsWith);
  }

  String _extractImagePrompt(String input) {
    final trimmedInput = input.trim();
    final lowerInput = trimmedInput.toLowerCase();
    const imagePromptPrefixes = [
      'generate an image',
      'generate image',
      'create an image',
      'create image',
      'draw an image',
      'draw image',
      'image:',
    ];

    for (final prefix in imagePromptPrefixes) {
      if (lowerInput.startsWith(prefix)) {
        return trimmedInput.substring(prefix.length).trim();
      }
    }

    return trimmedInput;
  }

  Future<String> saveTemporaryFile(
    Uint8List bytes, {
    String extension = 'png',
  }) async {
    final temDir = await getTemporaryDirectory();
    final timeStamp = DateTime.now().microsecondsSinceEpoch;
    final normalizedExtension = extension.startsWith('.')
        ? extension.substring(1)
        : extension;
    final filePath = File(
      '${temDir.path}/generated_$timeStamp.$normalizedExtension',
    );
    await filePath.writeAsBytes(bytes);
    return filePath.path;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ChatBot App',
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
                  ? const CircularProgressIndicator()
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
          if (selectedAttachment != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(selectedAttachment!.icon, color: Colors.deepPurple),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected ${selectedAttachment!.label}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            selectedAttachment!.fileName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          selectedAttachment = null;
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: showAttachmentOptions,
                  icon: const Icon(Icons.attachment_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: textEditingController,
                    decoration: InputDecoration(
                      hintText: selectedAttachment == null
                          ? 'Type a message or generate image...'
                          : 'Ask about the selected file',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (m) {
                      indentifyPromt();
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    indentifyPromt();
                  },
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
