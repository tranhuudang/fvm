import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' as material;
import 'package:dart_console/dart_console.dart';
import 'package:interact/interact.dart' as interact;
import 'package:mason_logger/mason_logger.dart';
import 'package:tint/tint.dart';

import '../utils/context.dart';
import 'base_service.dart';

/// This files has been modify to best working with Parrot

/// Sets default logger mode
LoggerService get logger => getProvider();

class LoggerService extends ContextService {
  final Logger _logger;

  /// Constructor
  LoggerService({Level? level, FVMContext? context})
      : _logger = Logger(level: level ?? Level.info),
        super(context);

  void get spacer => _logger.info('');

  bool get isVerbose => _logger.level == Level.verbose;

  Level get level => _logger.level;

  String get stdout {
    return logger.stdout;
  }

  void get divider {
    _logger.info(
      '------------------------------------------------------------',
    );
  }

  set level(Level level) => _logger.level = level;

  void success(String message) {
    _logger.info('${Icons.success.green()} $message');
    consoleController.fine.add(utf8.encode(message));
  }

  void fail(String message) {
    _logger.info('${Icons.failure.red()} $message');
    consoleController.error.add(utf8.encode(message));
  }

  void warn(String message) {
    _logger.warn(message);
    consoleController.warning.add(utf8.encode(message));
  }

  void info(String message) {
    _logger.info(message);
    consoleController.info.add(utf8.encode(message));
  }

  void err(String message) {
    _logger.err(message);
    consoleController.error.add(utf8.encode(message));
  }

  void detail(String message) {
    _logger.detail(message);
    consoleController.fine.add(utf8.encode(message));
  }

  void write(String message) => _logger.write(message);
  Progress progress(String message) {
    final progress = _logger.progress(message);
    if (isVerbose) {
      // if verbose then cancel for other data been displayed and overlapping
      progress.cancel();
      // Replace for a normal log
      logger.info(message);
    }
    consoleController.fine.add(utf8.encode(message));
    return progress;
  }

  bool confirm(String? message, {required bool defaultValue}) {
    // When running tests, always return true.
    if (context.isTest) return true;

    if (context.isCI || context.skipInput) {
      logger.info(message ?? '');
      logger
        ..warn('Skipping input confirmation')
        ..warn('Using default value of $defaultValue');

      return defaultValue;
    }

    return interact.Confirm(prompt: message ?? '', defaultValue: defaultValue)
        .interact();
  }

  String select(
    String? message, {
    required List<String> options,
    int? defaultSelection,
  }) {
    if (context.skipInput) {
      if (defaultSelection != null) {
        return options[defaultSelection];
      }
      exit(ExitCode.usage.code);
    }

    final selection = interact.Select(
      prompt: message ?? '',
      options: options,
      initialIndex: defaultSelection ?? 0,
    ).interact();

    return options[selection];
  }

  void notice(String message) {
    // Add 2 due to the warning icon.

    final label = '${Icons.warning} $message'.brightYellow();

    final table = Table()
      ..insertRow([label])
      ..borderColor = ConsoleColor.yellow
      ..borderType = BorderType.outline
      ..borderStyle = BorderStyle.square;

    _logger.write(table.toString());
  }

  void important(String message) {
    // Add 2 due to the warning icon.

    final label = '${Icons.success} $message'.cyan();

    final table = Table()
      ..insertRow([label])
      ..borderColor = ConsoleColor.cyan
      ..borderType = BorderType.outline
      ..borderStyle = BorderStyle.square;

    _logger.write(table.toString());
  }
}

final dot = '\u{25CF}'; // ●
final rightArrow = '\u{2192}'; // →

final consoleController = ConsoleController();

/// Console Controller
class ConsoleController {
  /// stdout stream
  final stdout = StreamController<List<int>>.broadcast();

  /// stderr stream
  final stderr = StreamController<List<int>>.broadcast();

  /// warning stream
  final warning = StreamController<List<int>>.broadcast();

  /// fine stream
  final fine = StreamController<List<int>>.broadcast();

  /// info stream
  final info = StreamController<List<int>>.broadcast();

  /// error stream
  final error = StreamController<List<int>>.broadcast();

  // Add new unified stream
  final _unifiedController = StreamController<LogMessage>.broadcast();
  Stream<LogMessage> get unifiedStream => _unifiedController.stream;

  ConsoleController() {
    // Listen to all existing streams and forward to unified stream
    stdout.stream.listen((data) => _addToUnified(LogMessageType.stdout, data));
    stderr.stream.listen((data) => _addToUnified(LogMessageType.stderr, data));
    warning.stream
        .listen((data) => _addToUnified(LogMessageType.warning, data));
    fine.stream.listen((data) => _addToUnified(LogMessageType.fine, data));
    info.stream.listen((data) => _addToUnified(LogMessageType.info, data));
    error.stream.listen((data) => _addToUnified(LogMessageType.error, data));
  }

  void _addToUnified(LogMessageType type, List<int> data) {
    _unifiedController.add(LogMessage(
      type: type,
      message: utf8.decode(data),
    ));
  }

  void dispose() {
    stdout.close();
    stderr.close();
    warning.close();
    fine.close();
    info.close();
    error.close();
    _unifiedController.close();
  }
}

class Icons {
  const Icons._();
  // Success: ✓
  static String get success => '✓';

  // Failure: ✗
  static String get failure => '✗';

  // Information: ℹ
  static String get info => 'ℹ';

  // Warning: ⚠
  static String get warning => '⚠';

  // Arrow Right: →
  static String get arrowRight => '→';

  // Arrow Left: ←
  static String get arrowLeft => '←';

  // Check Box: ☑
  static String get checkBox => '☑';

  // Star: ★
  static String get star => '★';

  // Circle: ●
  static String get circle => '●';

  // Square: ■
  static String get square => '■';
}

class LogMessage {
  final LogMessageType type;
  final String message;
  final DateTime timestamp;

  LogMessage({
    required this.type,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  material.Color get color {
    switch (type) {
      case LogMessageType.error:
        return material.Colors.red;
      case LogMessageType.warning:
        return material.Colors.orange;
      case LogMessageType.info:
        return material.Colors.blue;
      case LogMessageType.fine:
        return material.Colors.green;
      case LogMessageType.stdout:
        return material.Colors.grey;
      case LogMessageType.stderr:
        return material.Colors.red.shade300;
    }
  }
}

enum LogMessageType {
  stdout,
  stderr,
  warning,
  fine,
  info,
  error,
}
