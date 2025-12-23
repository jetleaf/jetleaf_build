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
import '../../file_utility/file_utility.dart';
import '../executor/resolving/default_runtime_executor_resolving.dart';
import '../provider/runtime_provider.dart';
import 'default_runtime_scanner_summary.dart';
import 'runtime_scanner.dart';
import 'runtime_scanner_configuration.dart';
import 'runtime_scanner_summary.dart';
import '../../generator/mock_library_generator.dart';

/// {@template mock_runtime_scanner}
/// A **mock implementation** of [RuntimeScanner] designed for testing,
/// experimentation, and controlled runtime scanning scenarios.
///
/// [MockRuntimeScanner] simulates JetLeaf’s runtime scanning pipeline while
/// allowing fine-grained control over:
/// - Logging and error handling
/// - Forced file inclusion
/// - Library generation behavior
///
/// It is primarily intended for:
/// - Unit and integration testing
/// - Tooling and development environments
/// - Scenarios where full production scanning is unnecessary or undesirable
///
/// ---
///
/// #### Key Characteristics
///
/// - Uses Dart mirrors to inspect the current isolate
/// - Supports force-loading Dart files not discoverable via mirrors
/// - Allows custom library generator injection
/// - Produces deterministic reflection metadata
///
/// This scanner follows the same **lifecycle semantics** as production
/// scanners:
///
/// ```text
/// initialize
///   → discover files & libraries
///   → generate declarations
///   → resolve runtime executors
///   → freeze runtime registry
/// ```
///
/// While behaviorally compatible with production scanners, this
/// implementation prioritizes **flexibility and observability** over
/// performance and isolation.
///
/// Consumers should rely on [RuntimeScanner] abstractions rather than
/// this concrete type directly.
/// {@endtemplate}
final class MockRuntimeScanner implements RuntimeScanner {
  /// Optional callback invoked for **informational log messages**
  /// emitted during the mock runtime scanning process.
  ///
  /// This is typically used for verbose logging, diagnostics,
  /// or progress reporting.
  final OnLogged? onInfo;

  /// Optional callback invoked for **warning log messages**
  /// emitted during the mock runtime scanning process.
  ///
  /// Warnings usually indicate recoverable issues or non-fatal
  /// inconsistencies encountered during scanning.
  final OnLogged? onWarning;

  /// Optional callback invoked for **error log messages**
  /// emitted during the mock runtime scanning process.
  ///
  /// Errors reported here may indicate failures in file loading,
  /// analysis, or metadata generation.
  final OnLogged? onError;

  /// A list of Dart [File]s that should be **force-loaded**
  /// into the mirror system, even if they are not discovered
  /// through standard scanning.
  ///
  /// This is useful for:
  /// - Ensuring critical libraries are always analyzed
  /// - Injecting test or synthetic Dart files
  /// - Working around mirror discovery limitations
  final List<File> _forceLoadFiles;

  /// An optional factory used to create a custom
  /// [MockLibraryGenerator] implementation.
  ///
  /// When provided, this allows callers to override the default
  /// library generation behavior, enabling advanced testing,
  /// instrumentation, or experimental generation strategies.
  ///
  /// If `null`, the default [MockLibraryGenerator] is used.
  final MockLibraryGeneratorFactory? _libraryGeneratorFactory;

  /// {@macro mock_runtime_scanner}
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

    final result = await RuntimeBuilder.timeAsyncExecution(() async {
      RuntimeBuilder.logVerboseInfo("Starting mock runtime scan...");
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
      setRuntimeLibraryTag(iso.rootLibrary.uri.toString());
      
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
        packages: [createDefaultPackage(package!), ...packages],
      );
      
      final libraryGenerator = _libraryGeneratorFactory?.call(params) ?? MockLibraryGenerator(
        mirrorSystem: params.mirrorSystem,
        forceLoadedMirrors: params.forceLoadedMirrors,
        configuration: params.configuration,
        packages: params.packages,
      );

      final dartFilesToAnalyze = Set<File>.from(locatedFiles.getAnalyzeableDartFiles());
      dartFilesToAnalyze.addAll(_forceLoadFiles);
      await libraryGenerator.generate(dartFilesToAnalyze.toList());
      RuntimeBuilder.logVerboseInfo('Done generating declaration metadata');
      
      // 6. Generate AOT Runtime Resolvers
      final resolving = DefaultRuntimeExecutorResolving(libraries: mirrorLibraries);
      if(resources.isNotEmpty) {
        addRuntimeAssets(resources, replace: refreshContext);
      }

      if(packages.isNotEmpty) {
        addRuntimePackages(packages, replace: refreshContext);
      }

      setRuntimeResolver(await resolving.resolve());
      freezeRuntimeLibrary();
    });
    
    RuntimeBuilder.logVerboseInfo("Mock scan completed in ${result.getFormatted()}");

    final summary = DefaultRuntimeScannerSummary();
    summary.setBuildTime(DateTime.now());
    summary.addInfos(RuntimeBuilder.onCompleted().getInfos());
    summary.addWarnings(RuntimeBuilder.onCompleted().getWarnings());
    summary.addErrors(RuntimeBuilder.onCompleted().getErrors());
    summary.addAll(RuntimeBuilder.onCompleted().getLogs());

    RuntimeBuilder.clearTrackedLogs();
    
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

  /// Returns a new [RuntimeScannerConfiguration] with **default packages**
  /// automatically added to the scan list.
  ///
  /// This helper ensures that essential packages required for reflection
  /// and analysis are always included, while still respecting user-defined
  /// exclusions.
  ///
  /// The following packages are added by default:
  /// - The current application package ([currentPackage])
  /// - `analyzer`
  /// - `meta`
  /// - `path`
  /// - Any packages already specified in [RuntimeScannerConfiguration.packagesToScan]
  ///
  /// Packages explicitly listed in [RuntimeScannerConfiguration.packagesToExclude]
  /// are filtered out of the final scan list.
  ///
  /// The returned configuration:
  /// - Preserves all other configuration flags and options
  /// - Does not mutate the original [configuration]
  /// - Produces a deterministic, de-duplicated package list
  ///
  /// This function is typically invoked during runtime scanner
  /// initialization to normalize the effective scan scope.
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
}