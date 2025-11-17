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

import 'dart:io';

import '../runtime/runtime_scanner/runtime_scanner.dart';
import '../runtime/runtime_scanner/runtime_scanner_configuration.dart';
import '../runtime/runtime_scanner/runtime_scanner_summary.dart';

/// {@template application_runtime_scanner}
/// A JetLeaf-specific implementation of [RuntimeScanner].
///
/// The [ApplicationRuntimeScanner] is responsible for scanning the runtime
/// environment (e.g., Dart sources, assets, or bytecode) to discover classes,
/// annotations, or metadata at startup.
///
/// It integrates with the JetLeaf runtime by providing structured callbacks
/// for logging scan progress and issues:
///
/// - [onInfo] → General informational messages
/// - [onWarning] → Non-critical warnings
/// - [onError] → Errors or failures that occur during scanning
///
/// This class is intended to be the **bridge** between the JetLeaf reflection
/// API (`RuntimeScanner`) and the application-level logging/reporting system.
///
/// Example:
/// ```dart
/// final scanner = ApplicationRuntimeScanner(
///   onInfo: (msg) => print('[INFO] $msg'),
///   onWarning: (msg) => print('[WARN] $msg'),
///   onError: (msg) => print('[ERROR] $msg'),
/// );
///
/// final summary = await scanner.scan(
///   'lib/',
///   RuntimeScannerConfiguration(scanAnnotations: true),
/// );
/// ```
/// {@endtemplate}
final class ApplicationRuntimeScanner implements RuntimeScanner {
  /// Callback for logging **informational messages** during scanning.
  final void Function(String) onInfo;

  /// Callback for logging **warnings** (non-fatal issues).
  final void Function(String) onWarning;

  /// Callback for logging **errors** (fatal or severe issues).
  final void Function(String) onError;

  /// {@macro application_runtime_scanner}
  ApplicationRuntimeScanner({
    required this.onInfo,
    required this.onWarning,
    required this.onError,
  });

  /// Scans the runtime at the given [path] according to the provided [configuration].
  ///
  /// - [path] → The directory or entry point file to scan.
  /// - [configuration] → Controls the scanning behavior
  ///   (e.g., whether to detect annotations, analyze imports, etc.).
  /// - [source] → An optional base [Directory] that provides a reference
  ///   for resolving relative paths.
  ///
  /// Returns a [Future] that completes with a [RuntimeScannerSummary]
  /// containing the scan results.
  ///
  /// Throws [UnimplementedError] until implemented.
  @override
  Future<RuntimeScannerSummary> scan(RuntimeScannerConfiguration configuration, {Directory? source}) {
    throw UnimplementedError();
  }
}