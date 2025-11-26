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
import 'dart:mirrors' as mirrors;
import 'dart:async';

import 'package:path/path.dart' as p;

import '../declaration/declaration.dart';
import '../utils/file_utility.dart';
import '../runtime_provider/standard_runtime_provider.dart';
import '../runtime_provider/configurable_runtime_provider.dart';
import '../runtime_resolver/runtime_resolving.dart';
import 'default_runtime_scanner_summary.dart';
import 'runtime_scanner.dart';
import 'runtime_scanner_configuration.dart';
import 'runtime_scanner_summary.dart';
import '../generators/mock_library_generator.dart';

/// {@template mock_runtime_scan}
/// A lightweight mock implementation of [RuntimeScanner] for testing and development.
///
/// This scanner provides a simplified reflection system that:
/// - Operates only on the current isolate's libraries
/// - Supports force-loading specific files
/// - Uses Dart's mirrors API instead of filesystem scanning
/// - Provides configurable logging
/// - Allows custom library generator injection
///
/// {@template mock_runtime_scan_features}
/// ## Key Features
/// - **Isolated Scanning**: Only processes currently loaded libraries by default
/// - **Selective Loading**: Can force-load specific files via `forceLoadFiles`
/// - **Pluggable Logging**: Configurable info/warning/error callbacks
/// - **Custom Generators**: Supports alternative library generators via factory
/// - **Primitive Type Support**: Automatically includes Dart core types
///
/// ## When to Use
/// - Unit testing reflection-dependent code
/// - Development environments where full scanning is unnecessary
/// - CI pipelines requiring lightweight reflection
/// - Debugging specific library reflection
/// {@endtemplate}
///
/// {@template mock_runtime_scan_example}
/// ## Basic Usage
/// ```dart
/// final mockScan = MockRuntimeScan(
///   onInfo: (msg) => debugPrint(msg),
///   onError: (err) => debugPrint('ERROR: $err'),
///   forceLoadFiles: [
///     File('lib/src/critical.dart'),
///     File('lib/models/user.dart'),
///   ],
/// );
///
/// final summary = await mockScan.scan(
///   'output',
///   RuntimeScanLoader(
///     scanClasses: [User, CriticalService],
///   ),
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
class MockRuntimeScanner implements RuntimeScanner {
  final OnLogged? _onInfo;
  final OnLogged? _onWarning;
  final OnLogged? _onError;
  final List<File> _forceLoadFiles;
  final MockLibraryGeneratorFactory? _libraryGeneratorFactory;
  
  ConfigurableRuntimeProvider? _context;
  String? _package;

  /// {@macro mock_runtime_scan}
  ///
  /// {@template mock_runtime_scan_constructor}
  /// Creates a mock runtime scanner with configurable behavior.
  ///
  /// Parameters:
  /// - [onInfo]: Optional callback for informational messages
  /// - [onWarning]: Optional callback for warning messages
  /// - [onError]: Optional callback for error messages
  /// - [forceLoadFiles]: Additional files to load for scanning (default empty)
  /// - [libraryGeneratorFactory]: Custom generator factory (defaults to [MockLibraryGenerator])
  /// - [includeCurrentIsolateLibraries]: Whether to scan current isolate (default true)
  ///
  /// Example:
  /// ```dart
  /// final mockScan = MockRuntimeScan(
  ///   onError: (err) => Sentry.captureException(err),
  ///   forceLoadFiles: criticalFiles,
  /// );
  /// ```
  /// {@endtemplate}
  MockRuntimeScanner({
    OnLogged? onInfo,
    OnLogged? onWarning,
    OnLogged? onError,
    List<File> forceLoadFiles = const [],
    MockLibraryGeneratorFactory? libraryGeneratorFactory,
    bool includeCurrentIsolateLibraries = true,
  }) : _onInfo = onInfo,
       _onWarning = onWarning,
       _onError = onError,
       _forceLoadFiles = forceLoadFiles,
       _libraryGeneratorFactory = libraryGeneratorFactory;

  /// {@template mock_runtime_scan_scan}
  /// Executes a mock reflection scan with the given configuration.
  ///
  /// This simplified scan process:
  /// 1. Sets up the mirror system
  /// 2. Force-loads specified files
  /// 3. Generates reflection metadata
  /// 4. Updates the runtime context
  /// 5. Includes core Dart types
  ///
  /// Parameters:
  /// - [outputFolder]: Output directory path (unused in mock implementation)
  /// - [configuration]: Configuration for the scanning process
  /// - [source]: Optional source directory (defaults to current)
  ///
  /// Returns a [RuntimeScannerSummary] containing the scan results.
  ///
  /// Example:
  /// ```dart
  /// final summary = await mockScan.scan(
  ///   'build',
  ///   RuntimeScanLoader(
  ///     reload: true,
  ///     scanClasses: [MyImportantClass],
  ///   ),
  /// );
  /// ```
  /// {@endtemplate}
  @override
  Future<RuntimeScannerSummary> scan(RuntimeScannerConfiguration configuration, {Directory? source}) async {
    final stopwatch = Stopwatch()..start();
    _logInfo("Starting mock runtime scan...");

    FileUtility FileUtils = FileUtility(_logInfo, _logWarning, _logError, configuration, false);

    // 1. Setup directory and verify its existence
    Directory directory = source ?? Directory.current;
    _package ??= await _readPackageName(directory);

    // 2. Get current mirror system
    _logInfo('Setting up mirror system...');
    mirrors.MirrorSystem access = mirrors.currentMirrorSystem();
    
    // 3. Force load specified files
    final dartFiles = await FileUtils.findDartFiles(directory);
    final resources = await FileUtils.discoverAllResources(_package!, access);
    dartFiles.addAll(_forceLoadFiles);

    _logInfo('Loading dart files that are not present in the [currentMirrorSystem#(${access.isolate.debugName})]...');
    Map<File, Uri> urisToLoad = FileUtils.getUrisToLoad(dartFiles, _package!);
    List<mirrors.LibraryMirror> forceLoadedMirrors = [];
    for (final uriEntry in urisToLoad.entries) {
      mirrors.LibraryMirror? mirror = await FileUtils.forceLoadLibrary(uriEntry.value, uriEntry.key, access);
      if(mirror != null) {
        forceLoadedMirrors.add(mirror);
      }
    }

    List<Uri> dartUris = [
      Uri.parse('dart:async')
    ];

    for (final uri in dartUris) {
      mirrors.LibraryMirror? mirror = await FileUtils.forceLoadLibrary(uri, File(''), access);
      if(mirror != null) {
        forceLoadedMirrors.add(mirror);
      }
    }
    _logInfo('Loaded ${forceLoadedMirrors.length} dart files into the mirror system.');

    configuration = _addDefaultPackagesToScan(configuration, _package!);

    // 4. Generate reflection metadata
    _logInfo('Generating declaration metadata...');
    final params = MockLibraryGeneratorParams(
      mirrorSystem: access,
      forceLoadedMirrors: forceLoadedMirrors,
      onInfo: _logInfo,
      onWarning: _logWarning,
      onError: _logError,
      configuration: configuration,
      packages: [_createPackage(_package!)],
    );
    
    final libraryGenerator = _libraryGeneratorFactory?.call(params) ?? MockLibraryGenerator(
      mirrorSystem: params.mirrorSystem,
      forceLoadedMirrors: params.forceLoadedMirrors,
      onInfo: params.onInfo,
      onWarning: params.onWarning,
      onError: params.onError,
      configuration: params.configuration,
      packages: params.packages,
    );

    List<LibraryDeclaration> libraries = [];
    libraries = await libraryGenerator.generate(dartFiles.toList());
    _logInfo('Generated declaration metadata for ${libraries.length} libraries');

    // 5. Create or update context
    final refreshContext = _context == null || configuration.reload;
    if (refreshContext) {
      _context = StandardRuntimeProvider();
    }

    if (libraries.isNotEmpty) {
      _context?.addLibraries(libraries, replace: refreshContext);
    }
    
    // 6. Generate AOT Runtime Resolvers
    RuntimeResolving resolving = RuntimeResolving(
      access: access,
      libraries: libraries,
      forceLoadedMirrors: forceLoadedMirrors,
      outputFolder: configuration.outputPath,
      fileUtils: FileUtils,
      package: _package!,
      logInfo: _logInfo,
      logWarning: _logWarning,
      logError: _logError,
    );
    _context?.addAssets(resources);
    _context?.setRuntimeResolver(await resolving.resolve());

    stopwatch.stop();
    _logInfo("Mock scan completed in ${stopwatch.elapsedMilliseconds}ms");

    final summary = DefaultRuntimeScannerSummary();
    summary.setContext(_context!);
    summary.setBuildTime(DateTime.now());
    
    return summary;
  }

  /// Reads the package name from pubspec.yaml in the given directory.
  ///
  /// {@template read_package_name}
  /// Parameters:
  /// - [directory]: The directory containing pubspec.yaml
  ///
  /// Returns:
  /// - The package name if found
  /// - 'unknown' if reading fails
  ///
  /// Logs warnings through the configured [onWarning] callback.
  /// {@endtemplate}
  Future<String> _readPackageName(Directory directory) async {
    try {
      final pubspecFile = File(p.join(directory.path, 'pubspec.yaml'));
      final content = await pubspecFile.readAsString();
      final nameMatch = RegExp(r'name:\s*(\S+)').firstMatch(content);
      if (nameMatch != null && nameMatch.group(1) != null) {
        return nameMatch.group(1)!;
      }
    } catch (e) {
      _logWarning('Could not read package name from pubspec.yaml: $e');
    }
    return 'unknown';
  }

  /// Creates a package representation for the current project.
  ///
  /// {@template create_package}
  /// Parameters:
  /// - [name]: The package name
  ///
  /// Returns a [Package] with default mock values:
  /// - version: '0.0.0'
  /// - isRootPackage: true
  /// {@endtemplate}
  Package _createPackage(String name) {
    return PackageImplementation(
      name: name,
      version: '0.0.0',
      languageVersion: null,
      isRootPackage: true,
      rootUri: null,
      filePath: null,
    );
  }

  /// Logs an informational message through the configured [onInfo] callback.
  void _logInfo(String message) {
    final msg = _package != null ? "[$_package] $message" : message;
    _onInfo?.call(msg);
  }

  /// Logs a warning message through the configured [onWarning] callback.
  void _logWarning(String message) {
    final msg = _package != null ? "[$_package] $message" : message;
    _onWarning?.call(msg);
  }

  /// Logs an error message through the configured [onError] callback.
  void _logError(String message) {
    final msg = _package != null ? "[$_package] $message" : message;
    _onError?.call(msg);
  }
}

RuntimeScannerConfiguration _addDefaultPackagesToScan(RuntimeScannerConfiguration configuration, String currentPackage) {
  final defaultPackages = {currentPackage, 'analyzer', 'meta', 'path', ...configuration.packagesToScan}.toList();
  final filteredDefaults = defaultPackages.where((pkg) => !configuration.packagesToExclude.contains(pkg)).toList();
  
  return RuntimeScannerConfiguration(
    reload: configuration.reload,
    updatePackages: configuration.updatePackages,
    updateAssets: configuration.updateAssets,
    packagesToScan: filteredDefaults,
    packagesToExclude: configuration.packagesToExclude,
    filesToScan: configuration.filesToScan,
    filesToExclude: configuration.filesToExclude,
    additions: configuration.additions,
    removals: configuration.removals,
    writeDeclarationsToFiles: configuration.writeDeclarationsToFiles,
    enableTreeShaking: configuration.enableTreeShaking,
    outputPath: configuration.outputPath,
    scanClasses: configuration.scanClasses,
    excludeClasses: configuration.excludeClasses,
    skipTests: configuration.skipTests
  );
}