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

import 'dart:io' show File;

import '../../file_utility/abstract_file_utility.dart';

/// {@template runtime_scanner_configuration}
/// Configuration controller for reflection scanning operations in JetLeaf.
///
/// This class provides fine-grained control over how reflection metadata is collected,
/// allowing customization of scanning behavior through various flags and inclusion/exclusion
/// lists. It's used to configure reflection operations in both development and production.
///
/// {@template scan_loader_usage}
/// ## Typical Use Cases
/// - Incremental scanning during development
/// - Full reloads for code generation
/// - Selective scanning of specific packages/files
/// - Test environment configuration
///
/// ## Example Configuration
/// ```dart
/// final loader = RuntimeScanLoader(
///   reload: true,  // Force full reload
///   skipTests: true,  // Exclude test files
///   packagesToScan: ['my_package', 'r:package:my_other.*'],
///   filesToScan: [
///     File('lib/main.dart'),
///     File('lib/src/core.dart'),
///   ],
///   excludeClasses: [GeneratedClass],  // Skip generated code
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
class RuntimeScannerConfiguration {
  /// When true, performs a complete reload of all reflection data.
  ///
  /// This flag forces the scanner to:
  /// - Clear existing metadata
  /// - Rescan all specified sources
  /// - Rebuild all derived data structures
  ///
  /// Defaults to `false` for incremental scanning.
  final bool reload;

  /// When true, updates package metadata including dependencies and exports.
  ///
  /// This includes:
  /// - Package version information
  /// - Dependency graphs
  /// - Export visibility
  ///
  /// Defaults to `false` to optimize performance when unchanged.
  final bool updatePackages;

  /// When true, updates asset metadata including non-code resources.
  ///
  /// This includes:
  /// - Images and fonts
  /// - Configuration files
  /// - Localization resources
  ///
  /// Defaults to `false` to optimize performance when unchanged.
  final bool updateAssets;

  /// When true, excludes test files from scanning.
  ///
  /// Test files are identified by:
  /// - Location in `test/` directories
  /// - Package test imports
  /// - Conventional test file naming
  ///
  /// Defaults to `true` for production scanning.
  final bool skipTests;

  /// List of package patterns to include in scanning.
  ///
  /// Patterns can be:
  /// - Exact package names (`my_package`)
  /// - Regular expressions prefixed with `r:` (`r:package:my_.*`)
  /// 
  ///  r:.*/(test|tests)/.*',
  ///  r:.*/_test\.dart$',
  ///  r:.*/tool/.*',
  ///  r:.*/example/.*',
  ///  r:.*/benchmark/.*',
  ///  r:.*/\.dart_tool/.*',
  ///  r:.*/build/.*',
  ///
  /// When empty, scans all non-excluded packages.
  final List<String> packagesToScan;

  /// List of package patterns to exclude from scanning.
  ///
  /// Uses same pattern format as [packagesToScan].
  /// Exclusion takes precedence over inclusion.
  final List<String> packagesToExclude;

  /// Specific files to include in scanning.
  ///
  /// When specified, only these files will be scanned
  /// (unless [packagesToScan] is also specified).
  final List<File> filesToScan;

  /// Specific files to exclude from scanning.
  ///
  /// Exclusion takes precedence over all inclusion rules.
  final List<File> filesToExclude;

  /// Specific class types to include in scanning.
  ///
  /// When specified, only these classes will have their metadata collected.
  final List<Type> scanClasses;

  /// Specific class types to exclude from scanning.
  ///
  /// Exclusion takes precedence over [scanClasses].
  final List<Type> excludeClasses;

  /// Files added since last scan for incremental processing.
  ///
  /// Used to optimize scanning by only processing changed files.
  final List<File> additions;

  /// Files removed since last scan for cache invalidation.
  ///
  /// Used to clean up metadata from deleted sources.
  final List<File> removals;

  /// Whether to enable tree-shaking to only include used classes
  final bool enableTreeShaking;
  
  /// Whether to write declarations to separate files
  final bool writeDeclarationsToFiles;
  
  /// Output path for generated files
  final String outputPath;

  /// Whether to force load libraries - Mostly for dev env
  final bool forceLoadLibraries;

  /// Whether to try loading the file or uri outside isolate.
  final TryOutsideIsolate? tryOutsideIsolate;

  /// {@macro runtime_scanner_configuration}
  ///
  /// {@template scan_loader_constructor}
  /// Creates a scan configuration with customizable behavior.
  ///
  /// All parameters are optional with sensible defaults for typical use cases.
  ///
  /// ```dart
  /// // Minimal configuration
  /// final minimalLoader = RuntimeScanLoader();
  ///
  /// // Full configuration
  /// final fullLoader = RuntimeScanLoader(
  ///   reload: true,
  ///   updatePackages: true,
  ///   skipTests: Platform.environment['CI'] != 'true',
  ///   packagesToExclude: ['test_utils'],
  ///   filesToScan: [File('lib/main.dart')],
  /// );
  /// ```
  /// {@endtemplate}
  const RuntimeScannerConfiguration({
    this.reload = true,
    this.updatePackages = false,
    this.updateAssets = false,
    this.skipTests = true,
    this.packagesToScan = const [],
    this.packagesToExclude = const [],
    this.filesToScan = const [],
    this.filesToExclude = const [],
    this.scanClasses = const [],
    this.excludeClasses = const [],
    this.additions = const [],
    this.removals = const [],
    this.enableTreeShaking = false,
    this.writeDeclarationsToFiles = false,
    this.outputPath = 'build/generated',
    this.forceLoadLibraries = false,
    this.tryOutsideIsolate
  });

  /// Returns a copy of this configuration with updated values.
  ///
  /// Example usage:
  /// ```dart
  /// final config = RuntimeScannerConfiguration();
  /// final newConfig = config.copyWith(reload: true, outputPath: 'lib/generated');
  /// ```
  RuntimeScannerConfiguration copyWith({
    bool? reload,
    bool? updatePackages,
    bool? updateAssets,
    bool? skipTests,
    List<String>? packagesToScan,
    List<String>? packagesToExclude,
    List<File>? filesToScan,
    List<File>? filesToExclude,
    List<Type>? scanClasses,
    List<Type>? excludeClasses,
    List<File>? additions,
    List<File>? removals,
    bool? enableTreeShaking,
    bool? writeDeclarationsToFiles,
    String? outputPath,
    bool? forceLoadLibraries
  }) {
    return RuntimeScannerConfiguration(
      reload: reload ?? this.reload,
      updatePackages: updatePackages ?? this.updatePackages,
      updateAssets: updateAssets ?? this.updateAssets,
      skipTests: skipTests ?? this.skipTests,
      packagesToScan: packagesToScan ?? this.packagesToScan,
      packagesToExclude: packagesToExclude ?? this.packagesToExclude,
      filesToScan: filesToScan ?? this.filesToScan,
      filesToExclude: filesToExclude ?? this.filesToExclude,
      scanClasses: scanClasses ?? this.scanClasses,
      excludeClasses: excludeClasses ?? this.excludeClasses,
      additions: additions ?? this.additions,
      removals: removals ?? this.removals,
      enableTreeShaking: enableTreeShaking ?? this.enableTreeShaking,
      writeDeclarationsToFiles: writeDeclarationsToFiles ?? this.writeDeclarationsToFiles,
      outputPath: outputPath ?? this.outputPath,
      forceLoadLibraries: forceLoadLibraries ?? this.forceLoadLibraries
    );
  }

  /// Returns a string representation of the scan configuration.
  ///
  /// {@template scan_loader_tostring}
  /// Shows all configuration parameters and their values for debugging purposes.
  ///
  /// Example output:
  /// ```text
  /// RuntimeScanLoader(
  ///   reload: true,
  ///   updatePackages: false,
  ///   filesToScan: [File: 'lib/main.dart'],
  ///   ...
  /// )
  /// ```
  /// {@endtemplate}
  @override
  String toString() {
    return '''
RuntimeScanLoader(
  reload: $reload,
  updatePackages: $updatePackages,
  updateAssets: $updateAssets,
  packagesToScan: $packagesToScan,
  packagesToExclude: $packagesToExclude,
  filesToScan: $filesToScan,
  filesToExclude: $filesToExclude,
  scanClasses: $scanClasses,
  excludeClasses: $excludeClasses,
  additions: $additions,
  removals: $removals,
  skipTests: $skipTests,
  enableTreeShaking: $enableTreeShaking,
  writeDeclarationsToFiles: $writeDeclarationsToFiles,
  outputPath: $outputPath,
  forceLoadLibraries: $forceLoadLibraries
)
''';
  }
}