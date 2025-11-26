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

import '../runtime_provider/configurable_runtime_provider.dart';
import 'runtime_scanner_summary.dart';

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
  /// {@template configurable_runtime_scanner_summary.set_context}
  /// Sets the scanning context associated with this summary.
  ///
  /// This typically contains the discovered types, annotations, and
  /// internal scanning metadata.
  /// {@endtemplate}
  void setContext(ConfigurableRuntimeProvider context);

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

  /// {@template configurable_runtime_scanner_summary.add_generated_files}
  /// Appends a list of generated files to the summary.
  ///
  /// These files are to be added to the user's code or consumed by the scanner to make sure that these
  /// files are alive in the [ReflectionContext]
  /// {@endtemplate}
  void addGeneratedFiles(Map<String, String> files);
}