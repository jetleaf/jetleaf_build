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

import '../builder/runtime_builder.dart';
import '../runtime/scanner/runtime_scanner.dart';
import '../runtime/scanner/runtime_scanner_configuration.dart';
import '../generator/mock_library_generator.dart';
import '../runtime/scanner/mock_runtime_scanner.dart';
import '../runtime/scanner/runtime_scanner_summary.dart';

/// Executes a **mock runtime scan** and registers the resulting runtime
/// context for testing and validation purposes.
///
/// This utility method is intended for **development, debugging, and
/// automated tests**, allowing JetLeaf’s runtime scanner to be executed
/// without invoking the full production scanning pipeline.
///
/// Internally, it:
/// - Instantiates a [MockRuntimeScanner]
/// - Configures logging hooks
/// - Forces the loading of specific source files if requested
/// - Executes a scan using a customizable [RuntimeScannerConfiguration]
/// - Registers the produced runtime context into [Runtime]
///
/// This makes it possible to test:
/// - Reflection and mirror extraction
/// - Runtime hint resolution
/// - Type and link declaration generation
/// - Scanner configuration behaviors
///
/// without requiring a full application bootstrap.
///
/// ---
///
/// ### Parameters
///
/// #### `packagesToExclude`
/// A list of package names or paths to exclude from the scan.
///
/// This is merged with a default exclusion set that removes:
/// - Common test infrastructure packages
/// - Analyzer and tooling dependencies
/// - Internal Dart SDK utilities
///
/// Excluding these packages significantly improves scan performance and
/// reduces noise in test environments.
///
/// ---
///
/// #### `filesToLoad`
/// A list of absolute or relative file paths that should be **force-loaded**
/// into the mirror system before scanning.
///
/// This is useful when:
/// - Testing isolated source files
/// - Verifying behavior for files not reachable through normal imports
/// - Running focused regression tests
///
/// Each path is resolved to an absolute [File] before scanning.
///
/// ---
///
/// #### `config`
/// Optional [RuntimeScannerConfiguration] used to control scan behavior.
///
/// If omitted, a default configuration is created with:
/// - `skipTests: false`
/// - A predefined exclusion list
///
/// This allows callers to:
/// - Enable or disable tree shaking
/// - Control declaration output
/// - Customize scan depth and scope
///
/// ---
///
/// #### `onInfo`, `onWarning`, `onError`
/// Optional logging callbacks used during scanning.
///
/// If not provided, default implementations are used that print messages
/// to stdout with clear prefixes:
/// - `[MOCK INFO]`
/// - `[MOCK WARNING]`
/// - `[MOCK ERROR]`
///
/// These hooks make it easy to capture logs during automated tests or
/// route messages to a custom logger.
///
/// ---
///
/// ### Execution Flow
///
/// 1. A [MockRuntimeScanner] is created with:
///    - Logging callbacks
///    - Forced file loading configuration
///    - A custom library generator factory
///
/// 2. The scanner executes `.scan(...)` using the provided or default
///    [RuntimeScannerConfiguration].
///
/// 3. The resulting scan output produces a runtime context.
///
/// 4. The context is registered globally via [Runtime.register], making
///    it available for runtime hint resolution, invocation, and testing.
///
/// ---
///
/// ### Example
///
/// ```dart
/// await runTestScan(
///   filesToLoad: ['lib/models/user.dart'],
///   packagesToExclude: ['my_unused_package'],
///   onInfo: (msg) => logger.info(msg),
/// );
///
/// // Runtime is now fully initialized for tests
/// ```
///
/// ---
///
/// ### Intended Use Cases
///
/// - Unit tests for runtime scanners
/// - Integration tests for link generation
/// - Debugging mirror extraction issues
/// - Validating hint-driven execution paths
///
/// ---
///
/// ### See Also
///
/// - [MockRuntimeScanner]
/// - [RuntimeScannerConfiguration]
/// - [Runtime]
/// - [InternalMockLibraryGenerator]
Future<RuntimeScannerSummary> runTestScan({
  List<String> packagesToExclude = const [],
  List<String> filesToLoad = const [],
  RuntimeScannerConfiguration? config,
  OnLogged? onInfo,
  OnLogged? onWarning,
  OnLogged? onError,
  List<String> args = const [],
  Directory? source,
  RuntimeScanner? configuredScanner
}) async {
  final defaultConfig = RuntimeScannerConfiguration(
    skipTests: false,
    packagesToExclude: [
      "test",
      "lints",
      "args",
      "path",
      "source_span",
      "stack_trace",
      "stream_channel",
      "pool",
      "test_api",
      "test_core",
      "boolean_selector",
      "term_glyph",
      "string_scanner",
      "package:collection/src/list_extensions.dart",
      ...packagesToExclude
    ],
    // enableTreeShaking: true,
    // writeDeclarationsToFiles: true
  );

  final scanner = configuredScanner ?? MockRuntimeScanner(
    onInfo: onInfo ?? (msg, overwrite) => print('[MOCK INFO] ${overwrite ? '\r$msg' : msg}'),
    onWarning: onWarning ?? (msg, overwrite) => print('[MOCK WARNING] ${overwrite ? '\r$msg' : msg}'),
    onError: onError ?? (msg, overwrite) => print('[MOCK ERROR] ${overwrite ? '\r$msg' : msg}'),
    forceLoadFiles: filesToLoad.map((file) => File(file).absolute).toList(),
    libraryGeneratorFactory: (params) => InternalMockLibraryGenerator(
      mirrorSystem: params.mirrorSystem,
      forceLoadedMirrors: params.forceLoadedMirrors,
      configuration: params.configuration,
      packages: params.packages
    )
  );

  return await scanner.scan(config ?? defaultConfig, args, source: source);
}