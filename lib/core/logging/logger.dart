import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/logging/log_buffer.dart';

/// Shared in-memory buffer behind "Export debug log".
final LogBuffer logBuffer = LogBuffer();

/// Formats one log record. Never put tokens, emails or UPI IDs in messages.
String formatRecord(LogRecord r) {
  final error = r.error == null ? '' : ' | ${scrubLogText('${r.error}')}';
  return '${r.time.toIso8601String()} ${r.level.name} [${r.loggerName}] '
      '${scrubLogText(r.message)}$error';
}

/// Drops what error texts quote of people's data (R4, S-477): a SQLite error lists the failing statement
/// and ALL its parameters (descriptions, names, notes, UPI IDs), a FormatException the text it failed on.
/// Messages interpolate `$e`, so "Export debug log" keeps the error's code and message only.
String scrubLogText(String text) {
  var out = text;
  final statement = out.indexOf('Causing statement');
  if (statement >= 0) out = '${out.substring(0, statement).trimRight()} [statement hidden]';
  final format = out.indexOf('FormatException');
  if (format >= 0) {
    final end = out.indexOf('\n', format);
    if (end >= 0) out = '${out.substring(0, end)} [source hidden]';
  }
  return out;
}

/// Routes all [Logger] output to the ring buffer and (debug only) the console.
void initLogging({LogBuffer? buffer, bool? toConsole}) {
  final target = buffer ?? logBuffer;
  final console = toConsole ?? kDebugMode;
  Logger.root.level = Level.ALL;
  Logger.root.clearListeners();
  Logger.root.onRecord.listen((record) {
    final line = formatRecord(record);
    target.add(line);
    if (console) debugPrint(line);
  });
}

/// Sends framework and platform errors to the logger.
void installErrorHandlers() {
  final log = Logger('error');
  FlutterError.onError = (details) {
    log.severe(details.exceptionAsString(), details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.severe('Uncaught error', error, stack);
    return true;
  };
}
