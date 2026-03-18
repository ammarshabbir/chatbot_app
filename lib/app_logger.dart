import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  File? _logFile;
  Future<void> _writeQueue = Future<void>.value();

  Future<File> _resolveLogFile() async {
    if (_logFile != null) {
      return _logFile!;
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final logsDirectory = Directory('${appDirectory.path}/logs');

    if (!await logsDirectory.exists()) {
      await logsDirectory.create(recursive: true);
    }

    final file = File('${logsDirectory.path}/chatbot_app.log');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    _logFile = file;
    return file;
  }

  Future<String> getLogFilePath() async {
    final file = await _resolveLogFile();
    return file.path;
  }

  Future<String> readLogs() async {
    final file = await _resolveLogFile();
    return file.readAsString();
  }

  Future<void> clearLogs() async {
    final file = await _resolveLogFile();
    await file.writeAsString('', flush: true);
  }

  Future<void> info(String message, {Object? data}) {
    return _log('INFO', message, data: data);
  }

  Future<void> debug(String message, {Object? data}) {
    return _log('DEBUG', message, data: data);
  }

  Future<void> warning(String message, {Object? data}) {
    return _log('WARNING', message, data: data);
  }

  Future<void> error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Object? data,
  }) {
    return _log(
      'ERROR',
      message,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  Future<void> _log(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Object? data,
  }) {
    final entry = StringBuffer()
      ..writeln('[${DateTime.now().toIso8601String()}] [$level] $message');

    if (data != null) {
      entry.writeln(_formatSection('Data', data));
    }

    if (error != null) {
      entry.writeln(_formatSection('Error', error.toString()));
    }

    if (stackTrace != null) {
      entry.writeln(_formatSection('StackTrace', stackTrace.toString()));
    }

    entry.writeln(
      '----------------------------------------------------------------',
    );

    _writeQueue = _writeQueue.then((_) async {
      final file = await _resolveLogFile();
      await file.writeAsString(
        entry.toString(),
        mode: FileMode.append,
        flush: true,
      );
    });

    return _writeQueue;
  }

  String _formatSection(String title, Object value) {
    return '$title:\n${_stringify(value)}';
  }

  String _stringify(Object value) {
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return value;
      }
    }

    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }

    return value.toString();
  }
}
