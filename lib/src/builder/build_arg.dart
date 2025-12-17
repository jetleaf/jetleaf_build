/// {@template build_arg}
/// Centralized parser and accessor for **build-time command-line arguments**.
///
/// `BuildArg` provides a lightweight, static API for interpreting CLI flags
/// passed to JetLeaf build tools, scanners, and generators. It is designed
/// specifically for **build-time configuration**, not runtime configuration,
/// and focuses on logging verbosity, diagnostics, and safety controls.
///
/// The class is:
/// - **Stateless by design** (arguments are stored once via [setArgs])
/// - **Non-instantiable** (private constructor)
/// - **Optimized for fast flag lookup**
///
/// Flags may be provided in either:
/// - **Long form** (`--fully-verbose`)
/// - **Short form** (`--jfv`)
/// - **Key/value form** (`--fully-verbose=true`)
///
/// Boolean flags default to either `true` or `false` depending on their
/// semantic intent.
///
/// ---
///
/// ## Internal State
///
/// ### `_args`
/// ```dart
/// static List<String> _args = [];
/// ```
///
/// Stores the raw argument list passed from the build or tool entry point.
/// This list is treated as immutable after initialization and is queried
/// by all flag-accessor methods.
///
/// ---
///
/// ## Verbosity Flags
///
/// ### `FULLY_VERBOSE` / `FULLY_VERBOSE_SN`
/// Enables **maximum verbosity**.
///
/// When enabled, the build system logs **all internal events**, including:
/// - Library discovery
/// - Class, mixin, and enum analysis
/// - Annotation and metadata resolution
/// - Generator and scanner internals
///
/// Default: `false`
///
/// ---
///
/// ### `LIBRARY_VERBOSE` / `LIBRARY_VERBOSE_SN`
/// Enables logging at the **library level only**.
///
/// This is the default verbosity mode and provides:
/// - High-level progress information
/// - Library scanning and generation logs
///
/// Default: `true`
///
/// ---
///
/// ### `IMP_VERBOSE` / `IMP_VERBOSE_SN`
/// Enables **important-only logging**.
///
/// When enabled, all non-essential logs are suppressed, leaving only:
/// - Critical status updates
/// - Warnings and errors (unless skipped)
///
/// Default: `true`
///
/// ---
///
/// ## Log Suppression Flags
///
/// ### `SKIP_WARNING` / `SKIP_WARNING_SN`
/// Suppresses all **warning-level** logs.
///
/// Useful in CI pipelines where warnings are expected or non-actionable.
///
/// Default: `false`
///
/// ---
///
/// ### `SKIP_ERROR` / `SKIP_ERROR_SN`
/// Suppresses all **error-level** logs.
///
/// Intended primarily for debugging or experimental tooling; errors are
/// still raised internally, but logging is muted.
///
/// Default: `false`
///
/// ---
///
/// ### `SKIP_INFO` / `SKIP_INFO_SN`
/// Suppresses all **info-level** logs.
///
/// Allows users to see only warnings and errors without changing verbosity
/// modes.
///
/// Default: `false`
///
/// ---
///
/// ## Diagnostic Flags
///
/// ### `SHOW_CYCLE` / `SHOW_CYCLE_SN`
/// Enables logging of **cycle detection events**.
///
/// When enabled, the build system emits diagnostic output for:
/// - Circular type references
/// - Recursive generic resolution
/// - Dependency loops during scanning
///
/// Default: `false`
///
/// ---
///
/// ## Constructors
///
/// ### `BuildArg._()`
/// Private constructor to prevent instantiation.
///
/// `BuildArg` is intended to be used purely as a static utility.
///
/// ---
///
/// ## Methods
///
/// ### `setArgs`
/// ```dart
/// static void setArgs(List<String> args)
/// ```
///
/// Registers the raw command-line arguments to be parsed.
///
/// This method should be called **once** during tool or build initialization,
/// typically at the entry point of a build or generator.
///
/// ---
///
/// ### `_boolFlag`
/// ```dart
/// static bool _boolFlag(String key, String? short, {bool defaultValue = false})
/// ```
///
/// Internal helper for parsing boolean flags.
///
/// Supported formats:
/// - `--flag`
/// - `--short`
/// - `--flag=true` / `--flag=false`
/// - `--short=true` / `--short=false`
///
/// The first matching flag determines the value. If no match is found,
/// [defaultValue] is returned.
///
/// ---
///
/// ### `isFullyVerbose`
/// Returns `true` if **full verbosity** is enabled.
///
/// ---
///
/// ### `isLibraryVerbose`
/// Returns `true` if **library-level verbosity** is enabled.
///
/// Default behavior enables this unless explicitly overridden.
///
/// ---
///
/// ### `isImportantlyVerbose`
/// Returns `true` if **important-only verbosity** is enabled.
///
/// ---
///
/// ### `shouldSkipWarning`
/// Returns `true` if **warning logs** should be suppressed.
///
/// ---
///
/// ### `shouldSkipError`
/// Returns `true` if **error logs** should be suppressed.
///
/// ---
///
/// ### `shouldSkipInfo`
/// Returns `true` if **info logs** should be suppressed.
///
/// ---
///
/// ### `shouldShowCycle`
/// Returns `true` if **cycle detection logs** should be emitted.
///
/// ---
///
/// ## Example
///
/// ```dart
/// void main(List<String> args) {
///   BuildArg.setArgs(args);
///
///   if (BuildArg.isFullyVerbose()) {
///     enableFullLogging();
///   }
///
///   if (BuildArg.shouldSkipWarning()) {
///     disableWarningLogs();
///   }
/// }
/// ```
///
/// ---
///
/// ## Design Notes
///
/// - Optimized for **build-time performance**
/// - Avoids argument re-parsing
/// - No external dependencies
/// - Safe for concurrent reads
///
/// ---
///
/// ## See Also
///
/// - Runtime scanner logging utilities
/// - Generator diagnostic configuration
/// - JetLeaf build tooling entry points
/// {@endtemplate}
abstract final class BuildArg {
  /// Internal storage for raw command-line arguments passed to the build tool.
  ///
  /// This list is populated once via `BuildArg.setArgs(...)` and is subsequently
  /// queried by all flag-resolution helpers. The contents are treated as
  /// immutable after initialization and are not modified during execution.
  static List<String> _args = [];

  /// {@template build_arg_fv}
  /// Enables **full verbosity logging**.
  ///
  /// When this flag is present, JetLeaf emits **exhaustive diagnostic output**
  /// describing nearly every stage of the build and scan process, including:
  /// - Library discovery and loading
  /// - Class, mixin, enum, and extension analysis
  /// - Annotation and metadata extraction
  /// - Generator and scanner internals
  ///
  /// This mode is primarily intended for:
  /// - Deep debugging
  /// - Framework development
  /// - Diagnosing reflection or generation issues
  ///
  /// ### Default
  /// `false`
  ///
  /// ### Flags
  /// - Long form: `--fully-verbose`
  /// - Short form: `--jfv`
  /// {@endtemplate}
  static const String FULLY_VERBOSE = "--fully-verbose";

  /// {@macro build_arg_fv}
  static const String FULLY_VERBOSE_SN = "--jfv";

  /// {@template build_arg_lv}
  /// Enables **library-level verbosity only**.
  ///
  /// When enabled, logging is restricted to high-level events such as:
  /// - Library scanning start/end
  /// - Declaration generation per library
  /// - Major processing milestones
  ///
  /// Detailed logs for individual classes, mixins, or members are suppressed
  /// unless overridden by other verbosity flags.
  ///
  /// This is the **default verbosity mode** and provides a good balance between
  /// insight and signal-to-noise ratio.
  ///
  /// ### Default
  /// `true`
  ///
  /// ### Flags
  /// - Long form: `--lib-verbose`
  /// - Short form: `--jlv`
  /// {@endtemplate}
  static const String LIBRARY_VERBOSE = "--lib-verbose";

  /// {@macro build_arg_lv}
  static const String LIBRARY_VERBOSE_SN = "--jlv";

  /// {@template build_arg_iv}
  /// Enables **important-only logging**.
  ///
  /// When this flag is active, JetLeaf suppresses all non-essential logs and
  /// retains only messages deemed critical, such as:
  /// - Key status updates
  /// - Warnings and errors (unless explicitly skipped)
  ///
  /// This mode is well-suited for:
  /// - CI environments
  /// - Large projects where log volume must be minimized
  /// - Automated tooling and scripts
  ///
  /// ### Default
  /// `true`
  ///
  /// ### Flags
  /// - Long form: `--imp-verbose`
  /// - Short form: `--jiv`
  /// {@endtemplate}
  static const String IMP_VERBOSE = "--imp-verbose";

  /// {@macro build_arg_iv}
  static const String IMP_VERBOSE_SN = "--jiv";

  /// {@template build_arg_sw}
  /// Suppresses all **warning-level** log messages.
  ///
  /// When enabled, warnings are still generated internally but are not printed
  /// to the output stream. This is useful when warnings are expected or
  /// intentionally ignored during specific build phases.
  ///
  /// ### Default
  /// `false`
  ///
  /// ### Flags
  /// - Long form: `--skip-warn`
  /// - Short form: `--jsw`
  /// {@endtemplate}
  static const String SKIP_WARNING = "--skip-warn";

  /// {@macro build_arg_sw}
  static const String SKIP_WARNING_SN = "--jsw";

  /// {@template build_arg_se}
  /// Suppresses all **error-level** log messages.
  ///
  /// Errors are still raised and may affect build behavior, but their log output
  /// is muted. This option should be used with caution and is generally reserved
  /// for controlled debugging scenarios.
  ///
  /// ### Default
  /// `false`
  ///
  /// ### Flags
  /// - Long form: `--skip-err`
  /// - Short form: `--jse`
  /// {@endtemplate}
  static const String SKIP_ERROR = "--skip-err";

  /// {@macro build_arg_se}
  static const String SKIP_ERROR_SN = "--jse";

  /// {@template build_arg_si}
  /// Suppresses all **info-level** log messages.
  ///
  /// When enabled, informational logs are skipped while warnings and errors
  /// remain visible (unless suppressed separately). This allows users to reduce
  /// noise without altering verbosity modes.
  ///
  /// ### Default
  /// `false`
  ///
  /// ### Flags
  /// - Long form: `--skip-info`
  /// - Short form: `--jsi`
  /// {@endtemplate}
  static const String SKIP_INFO = "--skip-info";

  /// {@macro build_arg_si}
  static const String SKIP_INFO_SN = "--jsi";

  /// {@template build_arg_sc}
  /// Enables logging of **cycle detection diagnostics**.
  ///
  /// When this flag is present, JetLeaf emits detailed information whenever
  /// circular references are detected, including:
  /// - Recursive type dependencies
  /// - Cycles in generic bounds
  /// - Dependency loops during scanning or generation
  ///
  /// This flag is particularly useful for:
  /// - Debugging complex generic hierarchies
  /// - Investigating unexpected resolution failures
  ///
  /// ### Default
  /// `false`
  ///
  /// ### Flags
  /// - Long form: `--show-cycle`
  /// - Short form: `--jsc`
  /// {@endtemplate}
  static const String SHOW_CYCLE = "--show-cycle";

  /// {@macro build_arg_sc}
  static const String SHOW_CYCLE_SN = "--jsc";

  /// {@macro build_arg}
  BuildArg._();

  /// Registers the raw command-line arguments used by JetLeaf build tooling.
  ///
  /// This method initializes the internal argument store that is later queried
  /// by all verbosity and diagnostic flag accessors. It should be invoked
  /// **exactly once**, typically at the entry point of a build script, generator,
  /// or scanner.
  ///
  /// The provided argument list is stored as-is and is not modified or copied.
  /// Subsequent flag lookups operate on this list directly.
  ///
  /// ### Parameters
  /// - [args] — The raw argument list, usually obtained from `main(List<String>)`.
  static void setArgs(List<String> args) {
    _args = args;
  }

  /// A mapping of **CLI build flags** to their human-readable descriptions.
  ///
  /// This static map provides a quick reference for all recognized
  /// JetLeaf build-time flags and their corresponding behaviors.
  ///
  /// Format:
  /// ```text
  /// 'flag / shortFlag' : 'Description of behavior'
  /// ```
  ///
  /// Examples:
  /// - `$FULLY_VERBOSE / $FULLY_VERBOSE_SN` → "Enable full logging of all events"
  /// - `$SKIP_WARNING / $SKIP_WARNING_SN` → "Suppress warning logs"
  ///
  /// This map is used internally by the build system to:
  /// - Validate CLI arguments
  /// - Generate usage hints
  /// - Explain flag behavior to users
  static final flagDescriptions = <String, String>{
    '$FULLY_VERBOSE / $FULLY_VERBOSE_SN': 'Enable full logging of all events',
    '$LIBRARY_VERBOSE / $LIBRARY_VERBOSE_SN': 'Log library-level events only (default)',
    '$IMP_VERBOSE / $IMP_VERBOSE_SN': 'Important-only logging (warnings & errors)',
    '$SKIP_WARNING / $SKIP_WARNING_SN': 'Suppress warning logs',
    '$SKIP_ERROR / $SKIP_ERROR_SN': 'Suppress error logs',
    '$SKIP_INFO / $SKIP_INFO_SN': 'Suppress info logs',
    '$SHOW_CYCLE / $SHOW_CYCLE_SN': 'Show cycle detection diagnostics',
  };

  /// Prints a usage hint if no recognized CLI flags are supplied.
  ///
  /// This method scans the provided `_args` for any known flags. If none
  /// are found, it outputs the formatted command-line usage message
  /// to guide the user.
  ///
  /// Typical usage:
  /// ```dart
  /// BuildTool.showUsageHintIfNoFlags();
  /// ```
  ///
  /// This helps developers avoid running the build tool without any logging
  /// or flag configuration, which could result in silent failures or missed diagnostics.
  static void showUsageHintIfNoFlags() {
    // Check if _args contains any known flag
    final hasValidFlag = _args.any((arg) =>
        flagDescriptions.keys.any((flagPair) => flagPair.split(' / ').any((f) => arg.startsWith(f))));

    if (!hasValidFlag) {
      print(getCommandLineUsage());
    }
  }

  /// Returns a detailed **command-line usage guide** for the JetLeaf build tool.
  ///
  /// The returned string includes:
  /// - A summary message if no recognized CLI flags are detected
  /// - A list of all supported flags and their descriptions
  /// - Example commands demonstrating how to use the flags
  ///
  /// Example output:
  /// ```
  /// 🚀 JetLeaf Build Arguments - No recognized CLI flags detected!
  /// You can customize logging and verbosity using the following flags:
  ///
  /// 🔹 Flags:
  ///   $FULLY_VERBOSE / $FULLY_VERBOSE_SN   : Enable full logging of all events
  ///   ...
  ///
  /// 💡 Example Usage:
  ///   dart run build.dart $FULLY_VERBOSE
  ///   dart run build.dart $LIBRARY_VERBOSE $SKIP_WARNING
  /// ```
  ///
  /// Returns:
  /// A string suitable for printing to the console.
  static String getCommandLineUsage() {
    final buffer = StringBuffer()
      ..writeln('🚀 JetLeaf Build Arguments - No recognized CLI flags detected!')
      ..writeln('You can customize logging and verbosity using the following flags:\n');

    buffer.writeln('🔹 Flags:');
    for (final entry in flagDescriptions.entries) {
      buffer.writeln('  ${entry.key.padRight(30)}: ${entry.value}');
    }

    buffer
      ..writeln()
      ..writeln('💡 Example Usage:')
      ..writeln('  dart run build.dart $FULLY_VERBOSE')
      ..writeln('  dart run build.dart $LIBRARY_VERBOSE $SKIP_WARNING')
      ..writeln()
      ..writeln('Combine flags according to your desired log detail level.');

    return buffer.toString();
  }

  /// Resolves a **boolean command-line flag** from the registered arguments.
  ///
  /// This internal helper supports multiple flag representations:
  /// - Exact flags:
  ///   - `--flag`
  ///   - `--short`
  /// - Key/value pairs:
  ///   - `--flag=true` / `--flag=false`
  ///   - `--short=true` / `--short=false`
  ///
  /// Resolution follows a **first-match-wins** strategy:
  /// - The argument list is scanned in order
  /// - The first occurrence of the flag determines the value
  ///
  /// If the flag is present without an explicit value, it is treated as `true`.
  /// If the flag is not present at all, [defaultValue] is returned.
  ///
  /// ### Parameters
  /// - [key] — The long-form flag name (e.g. `--fully-verbose`).
  /// - [short] — The short-form flag name (e.g. `--jfv`), or `null` if none.
  /// - [defaultValue] — The value returned when the flag is not specified.
  ///
  /// ### Returns
  /// `true` or `false` based on the resolved flag value.
  static bool _boolFlag(String key, String? short, {bool defaultValue = false}) {
    for (final arg in _args) {
      // Exact flag → true
      if (arg == key || arg == short) return true;

      // key=value or short=value
      String? value;
      if (arg.startsWith('$key=')) {
        value = arg.substring(key.length + 1);
      } else if (short != null && arg.startsWith('$short=')) {
        value = arg.substring(short.length + 1);
      }

      if (value != null) {
        return value.toLowerCase() == 'true';
      }
    }

    return defaultValue;
  }

  /// Returns `true` if **full verbosity logging** is enabled.
  ///
  /// This corresponds to the `--fully-verbose` / `--jfv` flags and enables
  /// exhaustive diagnostic output.
  static bool isFullyVerbose() => _boolFlag(FULLY_VERBOSE, FULLY_VERBOSE_SN);

  /// Returns `true` if **library-level verbosity** is enabled.
  ///
  /// This is the default logging mode and is enabled unless explicitly disabled
  /// via command-line arguments.
  static bool isLibraryVerbose() => _boolFlag(LIBRARY_VERBOSE, LIBRARY_VERBOSE_SN, defaultValue: true);

  /// Returns `true` if **important-only verbosity** is enabled.
  ///
  /// When active, only essential logs are emitted.
  static bool isImportantlyVerbose() => _boolFlag(IMP_VERBOSE, IMP_VERBOSE_SN, defaultValue: true);

  /// Returns `true` if **warning-level logs** should be suppressed.
  static bool shouldSkipWarning() => _boolFlag(SKIP_WARNING, SKIP_WARNING_SN);

  /// Returns `true` if **error-level logs** should be suppressed.
  static bool shouldSkipError() => _boolFlag(SKIP_ERROR, SKIP_ERROR_SN);

  /// Returns `true` if **info-level logs** should be suppressed.
  static bool shouldSkipInfo() => _boolFlag(SKIP_INFO, SKIP_INFO_SN);

  /// Returns `true` if **cycle detection diagnostics** should be logged.
  ///
  /// When enabled, JetLeaf emits detailed information about detected
  /// circular dependencies during scanning and type resolution.
  static bool shouldShowCycle() => _boolFlag(SHOW_CYCLE, SHOW_CYCLE_SN);
}