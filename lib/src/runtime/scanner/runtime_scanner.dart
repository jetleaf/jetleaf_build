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

import 'dart:io' show Directory;

import 'runtime_scanner_summary.dart';
import 'runtime_scanner_configuration.dart';

/// {@template runtime_scanner}
/// Defines the contract for a reflection scanner that processes Dart source
/// files, extracts metadata, and optionally persists output.
///
/// Used during framework initialization or tooling that requires reflection
/// metadata (e.g., code analyzers, documentation generators, or runtime scanners).
///
/// Implementations should handle scanning efficiently and report meaningful
/// summaries including errors, warnings, and informational messages.
///
/// ## Example
/// ```dart
/// final scanner = MyRuntimeScanner();
/// final loader = RuntimeScanLoader(
///   reload: true,
///   updatePackages: false,
///   updateAssets: true,
///   baseFilesToScan: [File('lib/main.dart')],
///   packagesToScan: ['package:meta/', 'package:args/'],
/// );
/// final summary = await scanner.scan('build/meta', loader);
///
/// print(summary.getErrors());
/// ```
/// {@endtemplate}
abstract interface class RuntimeScanner {
  /// {@macro runtime_scanner}
  ///
  /// {@template runtime_scanner.scan}
  /// Performs the reflection scan and outputs a [RuntimeScannerSummary].
  ///
  /// - [loader] is the configuration for the scan.
  /// - [source] is the root directory to scan. Defaults to [Directory.current].
  /// - [args] is the build args to use
  ///
  /// Returns a [Future] that resolves to the final [RuntimeScannerSummary].
  /// {@endtemplate}
  Future<RuntimeScannerSummary> scan(RuntimeScannerConfiguration loader, List<String> args, {Directory? source});
}