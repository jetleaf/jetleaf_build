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

// Conditional import: use `reflection.dart` if dart:mirrors is available,
// otherwise fall back to a stubbed scanner implementation.
import '../runtime_provider/runtime_provider.dart';
import '../runtime_scanner/runtime_scanner_configuration.dart';
import 'jet_runtime_stub_scanner.dart'
    if (dart.library.mirrors) '../runtime/runtime_scanner/application_runtime_scanner.dart';

/// {@template run_scan}
/// Executes a runtime scan using the [ApplicationRuntimeScanner].
///
/// This function initializes a scanner that inspects the runtime environment
/// (classes, annotations, metadata) and collects a [RuntimeProvider] context
/// for JetLeaf to use during application startup.
///
/// The scan is configured via [RuntimeScannerConfiguration], which allows
/// customization such as skipping tests or forcing reloads.
///
/// Logging integration:
/// - **Info** messages are logged with [print], or printed to stderr
///   if info-level logging is disabled.
/// - **Warnings** are logged with [print], or printed to stderr
///   if warn-level logging is disabled.
/// - **Errors** are logged with [print], or printed to stderr
///   if error-level logging is disabled.
///
/// Example:
/// ```dart
/// final logger = LogFactory.getLog('JetLeafScanner');
/// final runtimeProvider = await runScan(logger);
///
/// // Access discovered pods, classes, or metadata
/// print(runtimeProvider.getPods());
/// ```
///
/// Returns a [Future] that resolves to the discovered [RuntimeProvider].
/// {@endtemplate}
Future<RuntimeProvider> runScan({Directory? source, RuntimeScannerConfiguration? config, bool forceLoadLibraries = false}) async {
  final scanner = ApplicationRuntimeScanner(
    onInfo: (msg) => print("(∞INFO∞) $msg"),
    onWarning: (msg) => print("(∞WARN∞) $msg"),
    onError: (msg) => print("(∞ERROR∞) $msg"),
  );

  final scan = await scanner.scan(config ?? RuntimeScannerConfiguration(
    skipTests: true,
    reload: true,
    packagesToScan: [],
    packagesToExclude: [
      'collection',
      'analyzer',
      '_fe_analyzer',
      "r:.*/example/.*",
      "r:.*/test/.*",
      "r:.*/tool/.*",
      "r:.*/benchmark/.*",
      "r:.*/.dart_tool/.*",
      "r:.*/build/.*",
    ],
    forceLoadLibraries: forceLoadLibraries
  ), source: source);

  return scan.getContext();
}