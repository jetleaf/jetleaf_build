// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

/// {@template runtime_scanner_summary}
/// Represents a summary of the reflection scan process, containing
/// diagnostics and metadata such as build time and scanning context.
///
/// This is useful for debugging and analyzing what was discovered or
/// failed during reflection-based scanning.
///
/// ## Example
/// ```dart
/// void printScanSummary(RuntimeScannerSummary summary) {
///   print('Build Time: ${summary.getBuildTime()}');
///   print('Errors: ${summary.getErrors()}');
///   print('Warnings: ${summary.getWarnings()}');
///   print('Info: ${summary.getInfos()}');
/// }
/// ```
/// {@endtemplate}
abstract interface class RuntimeScannerSummary {
  /// {@macro runtime_scanner_summary}
  const RuntimeScannerSummary();

  /// {@template runtime_scanner_summary.build_time}
  /// Returns the timestamp when the scan completed.
  ///
  /// This can be used to determine when the reflection data was generated,
  /// especially useful for cache invalidation or versioning systems.
  /// {@endtemplate}
  DateTime getBuildTime();

  /// {@template runtime_scanner_summary.errors}
  /// A list of error messages encountered during the scan.
  ///
  /// This typically includes missing annotations, malformed types, or
  /// critical failures that prevented successful reflection.
  /// {@endtemplate}
  List<String> getErrors();

  /// {@template runtime_scanner_summary.warnings}
  /// A list of non-critical warnings during the reflection scan.
  ///
  /// These may include deprecated annotations or types that were
  /// partially resolved.
  /// {@endtemplate}
  List<String> getWarnings();

  /// {@template runtime_scanner_summary.infos}
  /// Informational messages collected during the scan.
  ///
  /// These might include details like number of scanned classes,
  /// paths scanned, or success messages.
  /// {@endtemplate}
  List<String> getInfos();

  /// {@template runtime_scanner_summary.infos}
  /// This retrieves the logs as they were written or collected.
  /// {@endtemplate}
  List<String> getLogsAsIs();

  /// {@template runtime_scanner_summary.generated_files}
  /// Returns the list of dart files generated during the scan.
  /// 
  /// These files are to be added to the user's code or consumed by the scanner to make sure that these
  /// files are alive in the [ReflectionContext]
  /// {@endtemplate}
  Map<String, String> getGeneratedFiles();
}

/// {@template configurable_runtime_scanner_summary}
/// An extension of [RuntimeScannerSummary] that allows mutating
/// its state during or after the scanning process.
///
/// This is intended for internal use during the scanning operation,
/// before being passed to consumers as an immutable [RuntimeScannerSummary].
///
/// ## Example
/// ```dart
/// final summary = MyConfigurableRuntimeScannerSummary();
/// summary.setBuildTime(DateTime.now());
/// summary.addError("Failed to scan class X");
/// summary.addInfo("Scanning completed.");
/// ```
/// {@endtemplate}
abstract class ConfigurableRuntimeScannerSummary implements RuntimeScannerSummary {
  /// {@template configurable_runtime_scanner_summary.set_build_time}
  /// Sets the build time when the scan was performed.
  ///
  /// This is important for reproducibility and logging.
  /// {@endtemplate}
  void setBuildTime(DateTime buildTime);

  /// {@template configurable_runtime_scanner_summary.add_error}
  /// Appends an error message to the summary.
  ///
  /// Should be used when an irrecoverable issue occurs.
  /// {@endtemplate}
  void addErrors(List<String> errors);

  /// {@template configurable_runtime_scanner_summary.add_warning}
  /// Appends a warning message to the summary.
  ///
  /// Used for non-fatal issues discovered during scanning.
  /// {@endtemplate}
  void addWarnings(List<String> warnings);

  /// {@template configurable_runtime_scanner_summary.add_info}
  /// Appends an informational message to the summary.
  ///
  /// Useful for recording insights, performance data, or discovered types.
  /// {@endtemplate}
  void addInfos(List<String> infos);

  /// {@template configurable_runtime_scanner_summary.add_info}
  /// Appends the entire logs to the summary.
  ///
  /// Useful for recording insights, performance data, or discovered types.
  /// {@endtemplate}
  void addAll(List<String> logs);

  /// {@template configurable_runtime_scanner_summary.add_generated_files}
  /// Appends a list of generated files to the summary.
  ///
  /// These files are to be added to the user's code or consumed by the scanner to make sure that these
  /// files are alive in the [ReflectionContext]
  /// {@endtemplate}
  void addGeneratedFiles(Map<String, String> files);
}