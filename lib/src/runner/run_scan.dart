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
import '../builder/runtime_builder.dart';
import '../runtime/scanner/application_runtime_scanner.dart';
import '../runtime/scanner/runtime_scanner.dart';
import '../runtime/scanner/runtime_scanner_configuration.dart';
import '../runtime/scanner/runtime_scanner_summary.dart';
// import 'jet_runtime_stub_scanner.dart'
//     if (dart.library.mirrors) '../runtime/runtime_scanner/application_runtime_scanner.dart';

/// Executes a **full application runtime scan**, builds a runtime context,
/// and registers it globally.
///
/// This method is the **primary entry point** for initializing JetLeaf’s
/// runtime model in real applications. It orchestrates:
/// - Source discovery
/// - Package scanning and exclusion
/// - Declaration and link generation
/// - Runtime context creation
///
/// The resulting runtime context is automatically registered into
/// [Runtime], making all scanned types, hints, and declarations immediately
/// available for runtime execution.
///
/// ---
///
/// ## Parameters
///
/// ### `source`
/// Optional root [Directory] used as the base for scanning.
///
/// If omitted, the scanner will infer the source root using the current
/// working directory and runtime environment.
///
/// This is commonly used when:
/// - Running scans in monorepos
/// - Testing alternate project layouts
/// - Executing scans from tooling or build systems
///
/// ---
///
/// ### `config`
/// Optional [RuntimeScannerConfiguration] used to customize scanning behavior.
///
/// When provided, this configuration is **merged** with JetLeaf’s
/// default production-safe configuration:
/// - Default exclusions are preserved
/// - Provided values override defaults selectively
///
/// This prevents accidental scanning of:
/// - Tests
/// - Tooling
/// - Build artifacts
/// - Analyzer internals
///
/// ---
///
/// ### `forceLoadLibraries`
/// Forces all discovered libraries to be loaded eagerly.
///
/// This flag is useful when:
/// - Performing deep reflection analysis
/// - Generating complete declaration graphs
/// - Debugging missing type resolution
///
/// If [config.forceLoadLibraries] is set, it takes precedence over this value.
///
/// ---
///
/// ### `onInfo`, `onWarning`, `onError`
/// Optional logging callbacks invoked during scanning.
///
/// If not provided, default handlers print messages to stdout using
/// clearly distinguishable markers:
/// - `(∞INFO∞)`
/// - `(∞WARN∞)`
/// - `(∞ERROR∞)`
///
/// These callbacks allow integration with structured loggers,
/// CI pipelines, or developer tooling.
///
/// ---
///
/// ### `args`
/// Command-line arguments forwarded to the scanner.
///
/// These arguments may influence:
/// - Conditional compilation
/// - Environment-specific scanning logic
/// - Feature toggles used by generators
///
/// ---
///
/// ## Configuration Merging Strategy
///
/// The scanner builds a **derived configuration** that:
/// - Uses JetLeaf-safe defaults
/// - Applies user overrides selectively
/// - Preserves exclusion rules critical to performance and correctness
///
/// Key defaults include:
/// - Skipping test directories
/// - Excluding analyzer and compiler internals
/// - Preventing accidental scans of `.dart_tool` and `build` directories
///
/// ---
///
/// ## Execution Flow
///
/// 1. An [ApplicationRuntimeScanner] is instantiated with logging hooks.
/// 2. A merged [RuntimeScannerConfiguration] is constructed.
/// 3. The scanner performs a full runtime scan using:
///    - The resolved configuration
///    - Command-line arguments
///    - Optional source directory
/// 4. A [RuntimeScannerSummary] is produced.
/// 5. The resulting runtime context is registered globally via
///    [Runtime.register].
///
/// ---
///
/// ## Returns
///
/// A [RuntimeScannerSummary] containing:
/// - Scan statistics
/// - Discovered libraries and declarations
/// - Generated runtime context
///
/// This object can be used for:
/// - Diagnostics
/// - Build tooling
/// - Reporting and analysis
///
/// ---
///
/// ## Example
///
/// ```dart
/// final summary = await runScan(
///   source: Directory('lib'),
///   config: RuntimeScannerConfiguration(
///     enableTreeShaking: true,
///   ),
/// );
///
/// print('Scanned ${summary.libraryCount} libraries');
/// ```
///
/// ---
///
/// ## Intended Use Cases
///
/// - Application startup initialization
/// - Build-time runtime generation
/// - Tooling and code generation pipelines
/// - Production runtime bootstrapping
///
/// ---
///
/// ## See Also
///
/// - [ApplicationRuntimeScanner]
/// - [RuntimeScannerConfiguration]
/// - [RuntimeScannerSummary]
/// - [Runtime]
Future<RuntimeScannerSummary> runScan({
  Directory? source,
  RuntimeScannerConfiguration? config,
  bool forceLoadLibraries = false,
  OnLogged? onInfo,
  OnLogged? onWarning,
  OnLogged? onError,
  List<String> args = const [],
  RuntimeScanner? configuredScanner,
  bool overrideConfig = false
}) async {
  final scanner = configuredScanner ?? ApplicationRuntimeScanner(
    onInfo: onInfo ?? (msg, overwrite) => print("(∞INFO∞) ${overwrite ? '\r$msg' : msg}"),
    onWarning: onWarning ?? (msg, overwrite) => print("(∞WARN∞) ${overwrite ? '\r$msg' : msg}"),
    onError: onError ?? (msg, overwrite) => print("(∞ERROR∞) ${overwrite ? '\r$msg' : msg}"),
  );

  final defaultConfig = RuntimeScannerConfiguration(
    skipTests: config?.skipTests ?? true,
    reload: config?.reload ?? true,
    packagesToScan: config?.packagesToScan ?? [],
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
      ...config?.packagesToExclude ?? []
    ],
    additions: config?.additions ?? [],
    updateAssets: config?.updateAssets ?? false,
    writeDeclarationsToFiles: config?.writeDeclarationsToFiles ?? false,
    forceLoadLibraries: config?.forceLoadLibraries ?? forceLoadLibraries,
    scanClasses: config?.scanClasses ?? [],
    filesToScan: config?.filesToScan ?? [],
    filesToExclude: config?.filesToExclude ?? [],
    enableTreeShaking: config?.enableTreeShaking ?? false,
    excludeClasses: config?.excludeClasses ?? [],
    updatePackages: config?.updatePackages ?? false,
    removals: config?.removals ?? [],
    outputPath: config?.outputPath ?? "build/generated"
  );

  return await scanner.scan(overrideConfig ? config ?? defaultConfig : defaultConfig, args, source: source);
}