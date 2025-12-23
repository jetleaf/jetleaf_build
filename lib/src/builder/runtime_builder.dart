import '../annotations.dart';
import 'build_arg.dart';

/// {@template on_logged}
/// Signature for logging callbacks used to report runtime scanning messages.
///
/// ```dart
/// void logInfo(String msg) => print('[INFO] $msg');
/// final scanner = DefaultRuntimeScan(onInfo: logInfo);
/// ```
///
/// {@endtemplate}
typedef OnLogged = void Function(String message, bool overwrite);

/// {@template runtime_builder}
/// Centralized build-time logging and execution context manager for JetLeaf.
///
/// `RuntimeBuilder` provides static, global facilities for:
/// - Logging messages at various severity levels (info, warning, error)
/// - Tracking build-time execution context such as package name
/// - Timing operations for performance analysis
///
/// It is an **abstract final class**, meaning it cannot be instantiated or
/// extended externally, and all functionality is exposed via static methods
/// and fields.
/// {@endtemplate}
abstract final class RuntimeBuilder {
  /// Internal buffer of all log entries.
  ///
  /// Logs are stored as [_LogEntry] instances and categorized by severity.
  static List<_LogEntry> _logs = [];

  /// Internal tracking of messages by their trackWith identifier
  static Map<String, _TrackedLog> _trackedLogs = {};

  /// Optional name of the package currently being scanned.
  ///
  /// Automatically prepended to log messages if set.
  static String? _package;

  /// Optional callback for info-level log messages.
  static OnLogged? _onInfo;

  /// Optional callback for warning-level log messages.
  static OnLogged? _onWarning;

  /// Optional callback for error-level log messages.
  static OnLogged? _onError;

  /// Private constructor to prevent instantiation.
  /// 
  /// {@macro runtime_builder}
  RuntimeBuilder._();

  /// Initializes the runtime builder context.
  ///
  /// Sets the optional logging callbacks, package name, and command-line arguments.
  ///
  /// ### Parameters
  /// - [args] — Raw arguments for build-time configuration.
  /// - [onInfo] — Callback for info messages.
  /// - [onWarning] — Callback for warnings.
  /// - [onError] — Callback for errors.
  /// - [package] — Optional package name to prepend to log messages.
  static void setContext(List<String> args, {OnLogged? onInfo, OnLogged? onWarning, OnLogged? onError, String? package}) {
    _onError = onError;
    _onInfo = onInfo;
    _onWarning = onWarning;
    _package = package;
    BuildArg.setArgs(args);
  }

  /// Sets the current package name for log message prefixing.
  ///
  /// If a package name has already been set, this method does nothing.
  /// Otherwise, the provided [package] will be prepended to all log messages.
  static void setPackage(String? package) => _package ??= package;

  /// Prepares a log message by optionally prepending the current package name.
  ///
  /// [message] — The original log message.
  /// [level] — Nesting or hierarchical level (currently used for formatting or future extensions).
  ///
  /// Returns a string that includes the package name if `_package` is not null.
  static String _prepareMessage(String message, int nestLevel) {
    final String indentation = '  ' * nestLevel; // 2 spaces per nest level
    final String baseMessage = _package != null ? "[$_package] $message" : message;
    return '$indentation$baseMessage';
  }

  /// Returns the appropriate logging callback for the given [_LogLevel].
  ///
  /// - [_LogLevel.info] returns [_onInfo] unless info logs are globally skipped.
  /// - [_LogLevel.warning] returns [_onWarning] unless warning logs are skipped.
  /// - [_LogLevel.error] returns [_onError] unless error logs are skipped.
  ///
  /// Returns `null` if logging is disabled for the specified level.
  static OnLogged? _getLogger(_LogLevel level) => switch(level) {
    _LogLevel.info => BuildArg.shouldSkipInfo() ? null : _onInfo,
    _LogLevel.warning => BuildArg.shouldSkipWarning() ? null : _onWarning,
    _LogLevel.error => BuildArg.shouldSkipError() ? null : _onError,
  };

  /// Internal logging implementation.
  ///
  /// Adds a log entry to the [_logs] buffer and invokes the associated callback
  /// unless [skip] is `true`.
  ///
  /// [level] — Severity of the log entry (_LogLevel).
  /// [message] — Message content to log.
  /// [nestLevel] — Hierarchical or indentation level for formatting purposes.
  /// [skip] — Whether to skip invoking the logger callback (only buffer the message).
  /// [overwrite] — Whether to overwrite an existing tracked log.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void _log(_LogLevel level, String message, int nestLevel, bool skip, bool overwrite, [String? trackWith]) {
    final prepared = _prepareMessage(message, nestLevel);
    final callback = _getLogger(level);
    
    if (trackWith != null) {
      // Check if we have a tracked log with this identifier
      final existingTrackedLog = _trackedLogs[trackWith];
      
      if (existingTrackedLog != null) {
        // Update existing tracked log
        final existingIndex = _logs.indexWhere((entry) => entry == existingTrackedLog.entry);
        if (existingIndex != -1) {
          // Create new entry with updated message
          final updatedEntry = _LogEntry(level, prepared);
          _logs[existingIndex] = updatedEntry;
          _trackedLogs[trackWith] = _TrackedLog(updatedEntry, trackWith);
          
          // Call callback with overwrite flag if not skipping
          if (!skip && callback != null) {
            callback(prepared, true);
          }
          return;
        }
      }
      
      // Create new tracked log
      final newEntry = _LogEntry(level, prepared);
      _logs.add(newEntry);
      _trackedLogs[trackWith] = _TrackedLog(newEntry, trackWith);
    } else {
      // Regular log entry (not tracked)
      _logs.add(_LogEntry(level, prepared));
    }

    if (!skip && callback != null) {
      // For new entries or non-tracked entries, overwrite is false
      callback(prepared, false);
    }
  }

  /// Logs an **info-level** message.
  ///
  /// This method uses the `_onInfo` callback if available, or buffers the
  /// message in `_logs` if logging is deferred. The current package name
  /// (if set) is automatically prepended.
  ///
  /// The message is skipped if `BuildArg.isImportantlyVerbose()` is `false`.
  ///
  /// [message] — The info message to log.
  /// [overwrite] — Whether to overwrite an existing tracked log.
  static void logInfo(String message, bool overwrite) => logFullyVerboseInfo(message);

  /// Logs a **warning-level** message.
  ///
  /// Uses `_onWarning` callback or buffers the message in `_logs`. Automatically
  /// prepends the current package name. Skipped if `BuildArg.isImportantlyVerbose()` is `false`.
  ///
  /// [message] — The warning message to log.
  /// [overwrite] — Whether to overwrite an existing tracked log.
  static void logWarning(String message, bool overwrite) => logFullyVerboseWarning(message);

  /// Logs an **error-level** message.
  ///
  /// Uses `_onError` callback or buffers the message in `_logs`. Automatically
  /// prepends the current package name. Skipped if `BuildArg.isImportantlyVerbose()` is `false`.
  ///
  /// [message] — The error message to log.
  /// [overwrite] — Whether to overwrite an existing tracked log.
  static void logError(String message, bool overwrite) => logFullyVerboseError(message);

  /// Logs an **info-level** message.
  ///
  /// This method uses the `_onInfo` callback if available, or buffers the
  /// message in `_logs` if logging is deferred. The current package name
  /// (if set) is automatically prepended.
  ///
  /// The message is skipped if `BuildArg.isImportantlyVerbose()` is `false`.
  ///
  /// [message] — The info message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logVerboseInfo(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.info,
    message,
    level,
    !BuildArg.isImportantlyVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs a **warning-level** message.
  ///
  /// Uses `_onWarning` callback or buffers the message in `_logs`. Automatically
  /// prepends the current package name. Skipped if `BuildArg.isImportantlyVerbose()` is `false`.
  ///
  /// [message] — The warning message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logVerboseWarning(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.warning,
    message,
    level,
    !BuildArg.isImportantlyVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs an **error-level** message.
  ///
  /// Uses `_onError` callback or buffers the message in `_logs`. Automatically
  /// prepends the current package name. Skipped if `BuildArg.isImportantlyVerbose()` is `false`.
  ///
  /// [message] — The error message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logVerboseError(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.error,
    message,
    level,
    !BuildArg.isImportantlyVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs an **info-level** message when **full verbosity** is enabled.
  /// 
  /// This message is skipped if `BuildArg.isFullyVerbose()` returns `false`.
  /// The current package name, if set, is automatically prepended to the message.
  /// Useful for detailed debugging information that is normally suppressed.
  ///
  /// [message] — The info message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logFullyVerboseInfo(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.info,
    message,
    level,
    !BuildArg.isFullyVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs a **warning-level** message when **full verbosity** is enabled.
  /// 
  /// This message is skipped if `BuildArg.isFullyVerbose()` returns `false`.
  /// The current package name, if set) is automatically prepended to the message.
  /// Useful for detailed warnings that are normally hidden.
  ///
  /// [message] — The warning message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logFullyVerboseWarning(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.warning,
    message,
    level,
    !BuildArg.isFullyVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs an **error-level** message when **full verbosity** is enabled.
  /// 
  /// This message is skipped if `BuildArg.isFullyVerbose()` returns `false`.
  /// The current package name, if set, is automatically prepended to the message.
  /// Useful for detailed error diagnostics that are normally hidden.
  ///
  /// [message] — The error message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logFullyVerboseError(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.error,
    message,
    level,
    !BuildArg.isFullyVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs an **info-level** message when **library-level verbosity** is enabled.
  /// 
  /// This message is skipped if `BuildArg.isLibraryVerbose()` returns `false`.
  /// Automatically prepends the current package name if it is set.
  /// Useful for logging information specific to libraries while keeping other logs minimal.
  ///
  /// [message] — The info message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logLibraryVerboseInfo(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.info,
    message,
    level,
    !BuildArg.isLibraryVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs a **warning-level** message when **library-level verbosity** is enabled.
  /// 
  /// This message is skipped if `BuildArg.isLibraryVerbose()` returns `false`.
  /// Automatically prepends the current package name if it is set.
  /// Useful for library-specific warnings that are normally suppressed.
  ///
  /// [message] — The warning message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logLibraryVerboseWarning(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.warning,
    message,
    level,
    !BuildArg.isLibraryVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs an **error-level** message when **library-level verbosity** is enabled.
  /// 
  /// This message is skipped if `BuildArg.isLibraryVerbose()` returns `false`.
  /// Automatically prepends the current package name if it is set.
  /// Useful for library-specific errors that are normally hidden.
  ///
  /// [message] — The error message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logLibraryVerboseError(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.error,
    message,
    level,
    !BuildArg.isLibraryVerbose(),
    true,
    trackWith ?? message
  );

  /// Logs a **cycle-detection warning** message.
  ///
  /// This message is specifically for notifying about detected cycles in
  /// runtime operations or type resolution. It is skipped unless
  /// `BuildArg.shouldShowCycle()` returns `true`. Automatically prepends
  /// the current package name if it is set.
  ///
  /// [message] — The warning message to log.
  /// [level] — Optional nesting or hierarchical level for formatting.
  /// [trackWith] — Optional identifier to track this log for future updates.
  static void logCycle(String message, {String? trackWith, int level = 0}) => _log(
    _LogLevel.warning,
    message,
    level,
    !BuildArg.shouldShowCycle(),
    true,
    trackWith ?? message
  );

  /// Measures the execution time of an asynchronous or synchronous action.
  ///
  /// [action] — A function returning a type `T`.
  /// Returns a [_TimeResult<T>] containing the result and the elapsed time.
  /// Useful for profiling or benchmarking specific runtime operations.
  static _TimeResult<T> timeExecution<T>(T Function() action) {
    final watch = Stopwatch()..start();
    final result = action();
    watch.stop();
    return _TimeResult(result, watch);
  }

  /// Measures the execution time of an asynchronous or synchronous action.
  ///
  /// [action] — A function returning a type `T`.
  /// Returns a [_TimeResult<T>] containing the result and the elapsed time.
  /// Useful for profiling or benchmarking specific runtime operations.
  static Future<_TimeResult<T>> timeAsyncExecution<T>(Future<T> Function() action) async {
    final watch = Stopwatch()..start();
    final result = await action();
    watch.stop();
    return _TimeResult(result, watch);
  }

  /// Returns a [_BuilderDetails] object after the runtime builder completes.
  ///
  /// Provides access to collected logs, including info, warnings, and errors,
  /// allowing for post-build inspection and reporting.
  static _BuilderDetails onCompleted() {
    try {
      return _BuilderDetails._();
    } finally {
      clearTrackedLogs();
    }
  }

  /// Clears all tracked logs. Useful for testing or resetting state.
  static void clearTrackedLogs() {
    _trackedLogs.clear();
    _trackedLogs = {};
    _logs.clear();
    _logs = [];
  }
}

/// Internal severity classification for log messages.
///
/// `_LogLevel` is a lightweight enum used internally by JetLeaf’s logging
/// infrastructure to categorize log entries by importance and intent.
///
/// This enum is **not part of the public API** and exists to provide a
/// type-safe alternative to string-based log levels.
///
/// ### Values
/// - `info`  
///   Represents informational messages that describe normal execution
///   flow, progress updates, and diagnostic details.
///
/// - `warning`  
///   Represents non-fatal issues that may indicate potential problems,
///   misconfigurations, or suboptimal states.
///
/// - `error`  
///   Represents fatal or critical failures that prevent correct execution
///   or indicate unrecoverable conditions.
enum _LogLevel { info, warning, error }

/// Internal class to track logs for updates
class _TrackedLog {
  final _LogEntry entry;
  final String identifier;
  
  _TrackedLog(this.entry, this.identifier);
}

/// Base representation of a single log entry.
///
/// `_LogEntry` bundles a log message together with its associated severity
/// level. It serves as the foundational data structure for JetLeaf’s internal
/// logging pipeline and may be extended or wrapped by higher-level log
/// processors.
///
/// This class is immutable and intentionally minimal to reduce allocation
/// overhead during intensive logging phases.
///
/// ## Fields
///
/// ### `level`
/// The [_LogLevel] indicating the severity of this log entry.
///
/// ### `message`
/// The human-readable message associated with the log entry.
///
/// Messages are expected to be fully formatted before construction.
base class _LogEntry {
  /// Severity level of the log entry.
  final _LogLevel level;

  /// Human-readable log message.
  final String message;

  /// Creates a new immutable log entry with the given [level] and [message].
  const _LogEntry(this.level, this.message);
}

/// Container for capturing a result together with its execution duration.
///
/// `_TimeResult<T>` is a small utility type used to measure and report the
/// execution time of an operation while preserving its result value.
///
/// It is commonly used in:
/// - Performance instrumentation
/// - Diagnostic logging
/// - Benchmarking internal operations
///
/// The associated [Stopwatch] is expected to have been started before the
/// operation and stopped immediately after completion.
///
/// ## Type Parameters
/// - `T` — The type of the operation result.
///
/// ## Fields
///
/// ### `watch`
/// The [Stopwatch] used to measure execution duration.
///
/// ### `result`
/// The result produced by the timed operation.
///
/// Both fields are immutable after construction.
@Generic(_TimeResult)
base class _TimeResult<T> {
  /// Stopwatch tracking the elapsed execution time.
  final Stopwatch watch;

  /// Result produced by the timed operation.
  final T result;

  /// Creates a new time/result container.
  ///
  /// The [watch] should already be stopped or ready for inspection.
  const _TimeResult(this.result, this.watch);

  /// Returns the elapsed time formatted in milliseconds.
  ///
  /// This is a convenience accessor for logging and diagnostics.
  String getFormatted() => "${watch.elapsedMilliseconds}ms";
}

/// Provides **aggregated access to build-time log details**.
///
/// `_BuilderDetails` is a base class for retrieving logs produced by the
/// `RuntimeBuilder`. It offers convenient methods to filter and categorize
/// log messages by severity level.
///
/// This class is primarily used internally for:
/// - Diagnostics and reporting
/// - Test verification of build results
/// - Logging inspection during development
///
/// The class is **non-instantiable** outside its library, as indicated by
/// the private constructor `_BuilderDetails._()`.
base class _BuilderDetails {
  /// Private constructor to prevent direct instantiation.
  _BuilderDetails._();

  /// Returns all **error messages** logged during the build.
  ///
  /// Filters `_logs` from `RuntimeBuilder` by `_LogLevel.error` and
  /// returns only the message strings.
  List<String> getErrors() => RuntimeBuilder._logs.where((e) => e.level == _LogLevel.error).map((e) => e.message).toList();
  
  /// Returns all **warning messages** logged during the build.
  ///
  /// Filters `_logs` from `RuntimeBuilder` by `_LogLevel.warning` and
  /// returns only the message strings.
  List<String> getWarnings() => RuntimeBuilder._logs.where((e) => e.level == _LogLevel.warning).map((e) => e.message).toList();
  
  /// Returns all **info messages** logged during the build.
  ///
  /// Filters `_logs` from `RuntimeBuilder` by `_LogLevel.info` and
  /// returns only the message strings.
  List<String> getInfos() => RuntimeBuilder._logs.where((e) => e.level == _LogLevel.info).map((e) => e.message).toList();
  
  /// Returns **all log messages** regardless of severity.
  ///
  /// This includes info, warning, and error messages in the order they
  /// were logged.
  List<String> getLogs() => RuntimeBuilder._logs.map((e) => e.message).toList();
}