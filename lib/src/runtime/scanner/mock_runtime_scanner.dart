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

import '../../builder/runtime_builder.dart';
import '../../declaration/declaration.dart';
import '../../file_utility/file_utility.dart';
import '../executor/resolving/default_runtime_executor_resolving.dart';
import '../provider/standard_runtime_provider.dart';
import 'default_runtime_scanner_summary.dart';
import 'runtime_scanner.dart';
import 'runtime_scanner_configuration.dart';
import 'runtime_scanner_summary.dart';
import '../../generator/mock_library_generator.dart';

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
  final OnLogged? onInfo;
  final OnLogged? onWarning;
  final OnLogged? onError;
  final List<File> _forceLoadFiles;
  final MockLibraryGeneratorFactory? _libraryGeneratorFactory;

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
    this.onInfo,
    this.onWarning,
    this.onError,
    List<File> forceLoadFiles = const [],
    MockLibraryGeneratorFactory? libraryGeneratorFactory,
    bool includeCurrentIsolateLibraries = true,
  }) : _forceLoadFiles = forceLoadFiles, _libraryGeneratorFactory = libraryGeneratorFactory;

  @override
  Future<RuntimeScannerSummary> scan(RuntimeScannerConfiguration configuration, List<String> args, {Directory? source}) async {
    String? package;
    RuntimeBuilder.setContext(args, onError: onError, onInfo: onInfo, onWarning: onWarning, package: package);

    final result = await RuntimeBuilder.timeExecution(() async {
      RuntimeBuilder.logVerboseInfo("Starting mock runtime scan...");

      final context = StandardRuntimeProvider();
      final FileUtils = FileUtility(
        RuntimeBuilder.logInfo,
        RuntimeBuilder.logWarning,
        RuntimeBuilder.logError,
        configuration,
        configuration.tryOutsideIsolate ?? (file, uri) => true
      );

      // 1. Setup directory and verify its existence
      Directory directory = source ?? Directory.current;
      package ??= await _readPackageName(directory);
      RuntimeBuilder.setPackage(package);

      // 2. Get current mirror system
      RuntimeBuilder.logVerboseInfo('Setting up mirror system...');
      mirrors.MirrorSystem access = mirrors.currentMirrorSystem();
      final iso = access.isolate;
      RuntimeBuilder.logVerboseInfo('Mirror system and access domain set up for ${iso.rootLibrary.uri}');
      
      // 3. Force load specified files
      final locatedFiles = await FileUtils.findDartFiles(directory);
      final dartFiles = Set<File>.from(locatedFiles.getScannableDartFiles());
      dartFiles.addAll(_forceLoadFiles);

      RuntimeBuilder.logVerboseInfo('Loading dart files not present in the currentMirrorSystem [#${iso.debugName}*${iso.rootLibrary.uri}]...');
      Map<File, Uri> urisToLoad = FileUtils.getUrisToLoad(dartFiles, package!);
      List<mirrors.LibraryMirror> forceLoadedMirrors = [];
      for (final uriEntry in urisToLoad.entries) {
        mirrors.LibraryMirror? mirror = await FileUtils.forceLoadLibrary(uriEntry.value, uriEntry.key, access);
        if(mirror != null) {
          forceLoadedMirrors.add(mirror);
        }
      }

      List<Uri> dartUris = [Uri.parse('dart:async')];

      for (final uri in dartUris) {
        mirrors.LibraryMirror? mirror = await FileUtils.forceLoadLibrary(uri, File(''), access);
        if(mirror != null) {
          forceLoadedMirrors.add(mirror);
        }
      }
      RuntimeBuilder.logVerboseInfo('Loaded ${forceLoadedMirrors.length} dart files into the mirror system.');

      configuration = _addDefaultPackagesToScan(configuration, package!);

      final refreshContext = configuration.reload;
      final mirrorLibraries = refreshContext ? [...access.libraries.values, ...forceLoadedMirrors] : [...forceLoadedMirrors];
      final resources = await FileUtils.discoverAllResources(package!, access, mirrorLibraries);
      final packages = await FileUtils.readPackageGraphDependencies(directory, access, mirrorLibraries);

      RuntimeBuilder.logVerboseInfo("Found ${resources.length} resources.");
      RuntimeBuilder.logVerboseInfo("Found ${packages.length} packages.");

      // 4. Generate reflection metadata
      RuntimeBuilder.logVerboseInfo('Generating declaration metadata...');
      final params = MockLibraryGeneratorParams(
        mirrorSystem: access,
        forceLoadedMirrors: forceLoadedMirrors,
        configuration: configuration,
        packages: [_createPackage(package!), ...packages],
      );
      
      final libraryGenerator = _libraryGeneratorFactory?.call(params) ?? MockLibraryGenerator(
        mirrorSystem: params.mirrorSystem,
        forceLoadedMirrors: params.forceLoadedMirrors,
        configuration: params.configuration,
        packages: params.packages,
      );

      List<LibraryDeclaration> libraries = [];
      final dartFilesToAnalyze = Set<File>.from(locatedFiles.getAnalyzeableDartFiles());
      dartFilesToAnalyze.addAll(_forceLoadFiles);
      libraries = await libraryGenerator.generate(dartFilesToAnalyze.toList());
      RuntimeBuilder.logVerboseInfo('Generated declaration metadata for ${libraries.length} libraries');

      if (libraries.isNotEmpty) {
        context.addLibraries(libraries, replace: refreshContext);
      }
      
      // 6. Generate AOT Runtime Resolvers
      final resolving = DefaultRuntimeExecutorResolving(libraries: mirrorLibraries);
      if(resources.isNotEmpty) {
        context.addAssets(resources, replace: refreshContext);
      }

      if(packages.isNotEmpty) {
        context.addPackages(packages, replace: refreshContext);
      }
      context.setRuntimeResolver(await resolving.resolve());
      
      return context;
    });
    
    RuntimeBuilder.logVerboseInfo("Mock scan completed in ${result.getFormatted()}");

    final summary = DefaultRuntimeScannerSummary();
    summary.setContext(result.result);
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
      RuntimeBuilder.logVerboseWarning('Could not read package name from pubspec.yaml: $e');
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