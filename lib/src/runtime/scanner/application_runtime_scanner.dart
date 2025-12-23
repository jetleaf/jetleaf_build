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

import '../../builder/runtime_builder.dart';
import '../../generator/default_library_generator.dart';
import '../../file_utility/file_utility.dart';
import '../../generator/library_generator.dart';
import '../declaration/declaration.dart';
import '../executor/resolving/default_runtime_executor_resolving.dart';
import '../../utils/utils.dart';
import '../provider/runtime_provider.dart';
import 'default_runtime_scanner_summary.dart';
import 'runtime_scanner.dart';
import 'runtime_scanner_configuration.dart';
import 'runtime_scanner_summary.dart';

/// {@template application_runtime_scanner}
/// A runtime scanner responsible for analyzing **application-level Dart code**
/// and generating runtime metadata required for reflection, asset discovery,
/// and package resolution.
///
/// `ApplicationRuntimeScanner` operates on the current application package,
/// scanning Dart source files, loading libraries into the mirror system,
/// resolving declarations, and registering runtime assets and packages.
///
/// ## Responsibilities
/// - Discover Dart source files within the application
/// - Load application libraries into the current mirror system
/// - Generate reflection metadata using [DefaultLibraryGenerator]
/// - Discover runtime assets and package dependencies
/// - Build and register runtime resolvers for AOT execution
///
/// ## Logging
/// The scanner supports optional logging callbacks:
/// - [onInfo] for informational messages
/// - [onWarning] for recoverable or non-fatal issues
/// - [onError] for errors encountered during scanning
///
/// ## Configuration
/// Behavior is controlled through [RuntimeScannerConfiguration], allowing:
/// - Incremental or full reloads
/// - Selective file and package scanning
/// - Conditional asset and package updates
/// - Library force-loading and exclusion rules
///
/// This scanner is typically used for **production or application builds**
/// where accurate runtime metadata is required for execution.
/// {@endtemplate}
final class ApplicationRuntimeScanner implements RuntimeScanner {
  /// Optional callback invoked for **informational log messages**
  /// emitted during the application runtime scanning process.
  ///
  /// This is typically used for general progress reporting,
  /// diagnostics, and verbose output during scanning.
  final OnLogged? onInfo;

  /// Optional callback invoked for **warning log messages**
  /// emitted during the application runtime scanning process.
  ///
  /// Warnings usually indicate recoverable issues or non-fatal
  /// conditions encountered while scanning application code.
  final OnLogged? onWarning;

  /// Optional callback invoked for **error log messages**
  /// emitted during the application runtime scanning process.
  ///
  /// Errors reported here may indicate failures in file discovery,
  /// library loading, or declaration generation.
  final OnLogged? onError;

  /// {@macro application_runtime_scanner}
  ApplicationRuntimeScanner({this.onInfo, this.onWarning, this.onError});

  @override
  Future<RuntimeScannerSummary> scan(RuntimeScannerConfiguration configuration, List<String> args, {Directory? source}) async {
    String? package;
    RuntimeBuilder.setContext(args, onError: onError, onInfo: onInfo, onWarning: onWarning, package: package);

    final result = await RuntimeBuilder.timeAsyncExecution(() async {
      bool refreshContext = configuration.reload;
      FileUtility FileUtils = FileUtility(
        RuntimeBuilder.logInfo,
        RuntimeBuilder.logWarning,
        RuntimeBuilder.logError,
        configuration,
        configuration.tryOutsideIsolate ?? (file, uri) => true
      );

      // 1. Setup directory and verify its existence
      Directory directory = source ?? Directory.current;

      // 2. Read package name from pubspec.yaml
      package ??= await FileUtils.readPackageName();
      RuntimeBuilder.setPackage(package);

      // 3. Add default packages to scan if none specified
      configuration = _addDefaultPackagesToScan(configuration, package!);

      // 4. Setup mirror system and access domain
      RuntimeBuilder.logVerboseInfo('Setting up mirror system and access domain...');
      mirrors.MirrorSystem access = mirrors.currentMirrorSystem();
      final iso = access.isolate;
      RuntimeBuilder.logVerboseInfo('Mirror system and access domain set up for ${iso.rootLibrary.uri}');
      setRuntimeLibraryTag(iso.rootLibrary.uri.toString());

      RuntimeBuilder.logVerboseInfo("Scanning $package application...");
      final locatedFiles = await FileUtils.findDartFiles(directory);
      Set<File> dartFiles = {};

      if(refreshContext) {
        dartFiles = locatedFiles.getScannableDartFiles();
      } else {
        // For non-rebuilds, only process additions/removals if specified
        if(configuration.additions.isNotEmpty || configuration.removals.isNotEmpty || configuration.filesToScan.isNotEmpty) {
          dartFiles = (configuration.filesToScan + configuration.additions).where((file) => file.path.endsWith('.dart')).toSet();
        }
      }

      RuntimeBuilder.logVerboseInfo("Found ${dartFiles.length} dart files.");

      // 5. Load dart files that are not present in the [currentMirrorSystem]
      List<mirrors.LibraryMirror> forceLoadedMirrors = [];
      if (configuration.forceLoadLibraries) {
        RuntimeBuilder.logVerboseInfo('Loading dart files not present in the currentMirrorSystem [#${iso.debugName}*${iso.rootLibrary.uri}]...');
        final forceLoaded = <String>{};
        Map<File, Uri> urisToLoad = FileUtils.getUrisToLoad(dartFiles, package!);

        for (final uriEntry in urisToLoad.entries) {
          if(RuntimeUtils.isNonLoadableJetLeafFile(uriEntry.value) || await RuntimeUtils.shouldNotIncludeLibrary(uriEntry.value, configuration)) {
            continue;
          }

          if (!forceLoaded.add(uriEntry.value.toString())) {
            continue;
          }

          mirrors.LibraryMirror? mirror = await FileUtils.forceLoadLibrary(uriEntry.value, uriEntry.key, access);
          if(mirror != null) {
            forceLoadedMirrors.add(mirror);
          }
        }
      }

      final mirrorLibraries = refreshContext ? [...access.libraries.values, ...forceLoadedMirrors] : [...forceLoadedMirrors];
      List<Asset> resources = [];
      List<Package> packages = [];

      if(refreshContext) {
        resources = await FileUtils.discoverAllResources(package!, access, mirrorLibraries);
        packages = await FileUtils.readPackageGraphDependencies(directory, access, mirrorLibraries);
      } else {
        if(configuration.updateAssets) {
          resources = await FileUtils.discoverAllResources(package!, access, mirrorLibraries);
        }

        if(configuration.updatePackages) {
          packages = await FileUtils.readPackageGraphDependencies(directory, access, mirrorLibraries);
        }
      }

      RuntimeBuilder.logVerboseInfo("Found ${resources.length} resources.");
      RuntimeBuilder.logVerboseInfo("Found ${packages.length} packages.");

      // 5. Generate reflection metadata
      RuntimeBuilder.logVerboseInfo('Resolving declaration metadata libraries...');
      LibraryGenerator libraryGenerator = DefaultLibraryGenerator(
        mirrorSystem: access,
        forceLoadedMirrors: forceLoadedMirrors,
        configuration: configuration,
        packages: packages,
        refresh: refreshContext
      );
      await libraryGenerator.generate(locatedFiles.getAnalyzeableDartFiles().toList());
      RuntimeBuilder.logVerboseInfo('Done generating declaration libraries.');

      // 6. Generate AOT Runtime Resolvers
      final resolving = DefaultRuntimeExecutorResolving(libraries: mirrorLibraries);
      setRuntimeResolver(await resolving.resolve());

      if(resources.isNotEmpty) {
        addRuntimeAssets(resources, replace: refreshContext);
      }

      if(packages.isNotEmpty) {
        addRuntimePackages(packages, replace: refreshContext);
      }

      freezeRuntimeLibrary();
    });

    RuntimeBuilder.logVerboseInfo("Application scanning completed in ${result.getFormatted()}.");

    ConfigurableRuntimeScannerSummary summary = DefaultRuntimeScannerSummary();
    summary.setBuildTime(DateTime.fromMillisecondsSinceEpoch(result.watch.elapsedMilliseconds));
    summary.addInfos(RuntimeBuilder.onCompleted().getInfos());
    summary.addWarnings(RuntimeBuilder.onCompleted().getWarnings());
    summary.addErrors(RuntimeBuilder.onCompleted().getErrors());
    summary.addAll(RuntimeBuilder.onCompleted().getLogs());

    RuntimeBuilder.clearTrackedLogs();

    return summary;
  }

  /// Returns a new [RuntimeScannerConfiguration] with default packages
  /// added to the scan list when not explicitly excluded.
  ///
  /// This helper ensures that the **current application package**
  /// is always included in the scan scope, alongside any packages
  /// already specified in [RuntimeScannerConfiguration.packagesToScan].
  ///
  /// Behavior:
  /// - Adds [currentPackage] to the list of packages to scan
  /// - Preserves any user-defined packages already present
  /// - Removes packages listed in [RuntimeScannerConfiguration.packagesToExclude]
  /// - Does not mutate the original [configuration]
  ///
  /// The returned configuration is created using [RuntimeScannerConfiguration.copyWith],
  /// ensuring all other configuration options remain unchanged.
  ///
  /// This function is typically invoked during scanner initialization
  /// to normalize the effective package scan set.
  RuntimeScannerConfiguration _addDefaultPackagesToScan(RuntimeScannerConfiguration configuration, String currentPackage) {
    final defaultPackages = {
      currentPackage,
      ...configuration.packagesToScan
    }.toList();
    final filteredDefaults = defaultPackages.where((pkg) => !configuration.packagesToExclude.contains(pkg)).toList();
    
    return configuration.copyWith(packagesToScan: filteredDefaults);
  }
}