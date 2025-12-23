import 'dart:io' as io;

import 'core_print.dart' as dev;
import 'compilation_mode.dart';
import 'properties.dart';
import 'system_detector.dart';
import 'system_properties.dart';

/// {@template system}
/// Internal system facade for the JetLeaf framework.
///
/// The [_System] class wraps a [SystemProperties] implementation and delegates all
/// environment-related method calls to it. It is the central access point
/// for querying runtime information while also exposing system-level streams
/// ([out], [err]) and process management ([exit]).
///
/// This class is not intended to be used directly by end-users. Instead,
/// it acts as the internal bridge between JetLeaf's runtime environment
/// and the underlying system.
///
/// ### Example
/// ```dart
/// final system = _System();
/// system.setProperties(myProperties);
///
/// // Delegated calls
/// if (system.isDevelopmentMode()) {
///   print('Running in dev mode');
/// }
///
/// // System streams
/// system.out.writeln('Hello stdout');
/// system.err.writeln('Hello stderr');
///
/// // Exit process
/// system.exit(0);
/// ```
/// {@endtemplate}
class _System implements SystemProperties {
  SystemProperties _properties = SystemPropertiesBuilder();

  /// Replaces the current [SystemProperties] implementation with a new one.
  ///
  /// This must be called before any system queries are made.
  void setProperties(SystemProperties properties) {
    _properties = properties;
  }

  void fromArgs(List<String> args) => SystemDetector().detect(args);

  @override
  CompilationMode getCompilationMode() => _properties.getCompilationMode();

  @override
  int getConfigurationCount() => _properties.getConfigurationCount();

  @override
  int getDependencyCount() => _properties.getDependencyCount();

  @override
  String getEntrypoint() => _properties.getEntrypoint();

  @override
  String getLaunchCommand() => _properties.getLaunchCommand();

  @override
  bool isDevelopmentMode() => _properties.isDevelopmentMode();

  @override
  bool isIdeRunning() => _properties.isIdeRunning();

  @override
  bool isProductionMode() => _properties.isProductionMode();

  @override
  bool isRunningAot() => _properties.isRunningAot();

  @override
  bool isRunningFromDill() => _properties.isRunningFromDill();

  @override
  bool isRunningJit() => _properties.isRunningJit();

  @override
  bool isWatchModeEnabled() => _properties.isWatchModeEnabled();

  /// {@template system_out}
  /// Returns [stdout], the **standard output stream**.
  ///
  /// Example:
  /// ```dart
  /// system.out.writeln('Logging to stdout');
  /// ```
  /// {@endtemplate}
  io.Stdout get out => io.stdout;

  /// {@template system_err}
  /// Returns [stderr], the **standard error stream**.
  ///
  /// Example:
  /// ```dart
  /// system.err.writeln('Error occurred!');
  /// ```
  /// {@endtemplate}
  io.Stdout get err => io.stderr;

  /// Exit the Dart VM process immediately with the given exit code.
  ///
  /// This does not wait for any asynchronous operations to terminate nor execute
  /// `finally` blocks. Using [exit] is therefore very likely to lose data.
  ///
  /// Child processes are not explicitly terminated (but they may terminate
  /// themselves when they detect that their parent has exited).
  ///
  /// While debugging, the VM will not respect the `--pause-isolates-on-exit`
  /// flag if [exit] is called as invoking this method causes the Dart VM
  /// process to shutdown immediately. To properly break on exit, consider
  /// calling [debugger] from `dart:developer` or [Isolate.pause] from
  /// `dart:isolate` on [Isolate.current] to pause the isolate before
  /// invoking [exit].
  ///
  /// The handling of exit codes is platform specific.
  ///
  /// On Linux and OS X an exit code for normal termination will always
  /// be in the range `[0..255]`. If an exit code outside this range is
  /// set the actual exit code will be the lower 8 bits masked off and
  /// treated as an unsigned value. E.g. using an exit code of -1 will
  /// result in an actual exit code of 255 being reported.
  ///
  /// On Windows the exit code can be set to any 32-bit value. However
  /// some of these values are reserved for reporting system errors like
  /// crashes.
  ///
  /// Besides this the Dart executable itself uses an exit code of `254`
  /// for reporting compile time errors and an exit code of `255` for
  /// reporting runtime error (unhandled exception).
  ///
  /// Due to these facts it is recommended to only use exit codes in the
  /// range \[0..127\] for communicating the result of running a Dart
  /// program to the surrounding environment. This will avoid any
  /// cross-platform issues.
  Never exit(int exitCode) => io.exit(exitCode);
}

/// {@template std_extension}
/// Extension to simulate Java's `System.out` and `System.err` utilities in Dart.
///
/// Adds helper methods to [Stdout] for convenient output printing, such as:
/// - `println()`
/// - `printf()`
/// - `printErr()`
///
/// Example usage:
/// ```dart
/// stdout.println("Hello, world!");
/// stdout.printf('Welcome, %s. You have %d messages.\n', ['John', 5]);
/// stdout.printErr("Something went wrong.");
/// ```
/// {@endtemplate}
extension StdExtension on io.Stdout {
  /// Prints a string without a newline (like `System.out.print`)
  void print(String message) {
    try {
      write(message);
    } catch (_) {
      dev.print(message);
    }
  }

  /// Prints a string followed by a newline (like `System.out.println`)
  void println([Object? message = '']) {
    try {
      writeln(message);
    } catch (_) {
      print(message.toString());
    }
  }

  /// Prints a formatted string using Dart's string interpolation.
  /// Simulates Java-style `printf`.
  ///
  /// Example:
  /// ```dart
  /// stdout.printf('Hello, %s! You are %d years old.\n', ['John', 30]);
  /// ```
  void printf(String format, List<Object?> args) {
    String formatted = _format(format, args);
    print(formatted);
  }

  /// Prints to `stderr` with a newline.
  void printErr(Object? message) {
    try {
      io.stderr.writeln(message);
    } catch (_) {
      print(message.toString());
    }
  }

  /// Formats a Java-style printf string with %s and %d placeholders.
  String _format(String format, List<Object?> args) {
    var buffer = StringBuffer();
    var parts = format.split(RegExp(r'(%[sd])'));
    var argIndex = 0;

    for (var part in parts) {
      if (part == '%s' || part == '%d') {
        if (argIndex < args.length) {
          buffer.write(args[argIndex]);
          argIndex++;
        } else {
          buffer.write(part);
        }
      } else {
        buffer.write(part);
      }
    }

    return buffer.toString();
  }
}

/// Returns a map of all platform-related properties similar to Java's System.getProperties().
///
/// Includes information such as:
/// - Dart version
/// - Operating system
/// - OS version
/// - Dart executable
/// - Locale
/// - Number of processors, etc.
Map<String, String> _properties = {
  'dart.version': io.Platform.version,
  'os.name': io.Platform.operatingSystem,
  'os.version': io.Platform.operatingSystemVersion,
  'locale.name': io.Platform.localeName,
  'executable': io.Platform.executable,
  'resolvedExecutable': io.Platform.resolvedExecutable,
  'numberOfProcessors': io.Platform.numberOfProcessors.toString(),
  'pathSeparator': io.Platform.pathSeparator,
  'script': io.Platform.script.toString(),
  'packageConfig': io.Platform.packageConfig ?? '',
  'executableArguments': io.Platform.executableArguments.join(' '),
  'version': io.Platform.version,
};

/// {@template system_extension}
/// Extension on [InternalSystemContext] that provides access to system-level
/// and environment-related properties similar to Java's `System.getProperties()`
/// and `System.getenv()`.
///
/// This includes metadata about the Dart runtime, host operating system,
/// environment variables, and more.
///
/// ### Example
/// ```dart
/// final properties = context.getProperties();
/// print(properties['os.name']); // e.g., 'macos'
///
/// final dartVersion = context.getProperty('dart.version');
/// print(dartVersion); // e.g., '3.3.0'
///
/// final env = context.getEnv();
/// print(env['PATH']);
///
/// final home = context.getEnvVar('HOME');
/// print(home);
/// ```
///
/// Useful in cross-platform utilities, diagnostics, and configuration loading.
/// {@endtemplate}
extension SystemExtension on _System {
  /// {@macro system_extension}
  ///
  /// Returns a map of all available system-related properties.
  ///
  /// This is similar to Java's `System.getProperties()` and may include:
  /// - `dart.version`
  /// - `dart.executable`
  /// - `os.name`
  /// - `os.version`
  /// - `os.arch`
  /// - `locale`
  /// - `cpu.cores`
  ///
  /// You can retrieve a specific property using [getProperty].
  Map<String, String> getProperties() => _properties;

  /// Returns the system property value for the given [name], or `null` if not found.
  ///
  /// ### Example
  /// ```dart
  /// final version = context.getProperty('dart.version');
  /// ```
  String? getProperty(String name) => _properties[name];

  /// {@macro system_extension}
  ///
  /// Returns a map of the environment variables accessible to the current
  /// Dart process.
  ///
  /// Equivalent to Java’s `System.getenv()`.
  ///
  /// ### Example
  /// ```dart
  /// final env = context.getEnv();
  /// print(env['PATH']);
  /// ```
  Map<String, String> getEnv() => io.Platform.environment;

  /// Returns the environment variable value for the given [name], or `null` if not defined.
  ///
  /// ### Example
  /// ```dart
  /// final userHome = context.getEnvVar('HOME');
  /// ```
  String? getEnvVar(String name) => io.Platform.environment[name];
}

/// {@macro system}
final _System System = _System();