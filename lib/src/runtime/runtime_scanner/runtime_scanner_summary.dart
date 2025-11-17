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
  ConfigurableRuntimeProvider getContext();

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

  /// {@template runtime_scanner_summary.generated_files}
  /// Returns the list of dart files generated during the scan.
  /// 
  /// These files are to be added to the user's code or consumed by the scanner to make sure that these
  /// files are alive in the [ReflectionContext]
  /// {@endtemplate}
  Map<String, String> getGeneratedFiles();
}