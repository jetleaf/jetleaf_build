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
import '../../declaration/declaration.dart';
import '../../generator/default_library_generator.dart';
import '../../file_utility/file_utility.dart';
import '../../generator/library_generator.dart';
import '../executor/resolving/default_runtime_executor_resolving.dart';
import '../provider/standard_runtime_provider.dart';
import '../provider/configurable_runtime_provider.dart';
import '../../utils/utils.dart';
import 'default_runtime_scanner_summary.dart';
import 'configurable_runtime_scanner_summary.dart';
import 'runtime_scanner.dart';
import 'runtime_scanner_configuration.dart';
import 'runtime_scanner_summary.dart';

/// {@template default_runtime_scan}
/// A default implementation of [RuntimeScanner] that supports scanning,
/// logging, and context tracking.
///
/// This scanner allows optional logging hooks to handle messages during
/// the scanning process. If no callbacks are provided, messages are
/// buffered internally and can be retrieved later.
///
/// ## Example
/// ```dart
/// final scan = DefaultRuntimeScan(
///   onInfo: (msg) => print('[INFO] $msg'),
///   onWarning: (msg) => print('[WARN] $msg'),
///   onError: (msg) => print('[ERR] $msg'),
/// );
/// ```
///
/// The logs are tagged with the current `package` name when set, helping
/// identify the origin of messages during multi-package scans.
///
/// {@endtemplate}
class ApplicationRuntimeScanner implements RuntimeScanner {
  /// Optional info log callback.
  final OnLogged? onInfo;

  /// Optional warning log callback.
  final OnLogged? onWarning;

  /// Optional error log callback.
  final OnLogged? onError;

  /// {@macro default_runtime_scan}
  ApplicationRuntimeScanner({this.onInfo, this.onWarning, this.onError});

  @override
  Future<RuntimeScannerSummary> scan(RuntimeScannerConfiguration configuration, List<String> args, {Directory? source}) async {
    String? package;
    RuntimeBuilder.setContext(args, onError: onError, onInfo: onInfo, onWarning: onWarning, package: package);

    final result = await RuntimeBuilder.timeExecution(() async {
      bool refreshContext = configuration.reload;
      ConfigurableRuntimeProvider context = StandardRuntimeProvider();

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

      RuntimeBuilder.logVerboseInfo("${refreshContext ? "Reloading" : "Scanning"} $package application...");
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

      List<LibraryDeclaration> libraries = [];

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
      final result = await libraryGenerator.generate(locatedFiles.getAnalyzeableDartFiles().toList());
      RuntimeBuilder.logVerboseInfo('Resolved ${result.length} declaration libraries.');

      libraries.addAll(result);
      libraries.addAll(context.getAllLibraries());

      // 6. Generate AOT Runtime Resolvers
      final resolving = DefaultRuntimeExecutorResolving(libraries: mirrorLibraries);

      context.setRuntimeResolver(await resolving.resolve());

      if(resources.isNotEmpty) {
        context.addAssets(resources, replace: refreshContext);
      }

      if(packages.isNotEmpty) {
        context.addPackages(packages, replace: refreshContext);
      }

      if(libraries.isNotEmpty) {
        context.addLibraries(libraries, replace: refreshContext);
      }

      // Handle removals (now configuration.removals) by removing them from the context
      if(configuration.removals.isNotEmpty) {
        final libs = context.getAllLibraries();
        final urisToRemove = configuration.removals.map((f) => FileUtils.resolveToPackageUri(f.absolute.path, package!)).whereType<String>().toSet();
        final updatedLibs = libs.where((lib) => !urisToRemove.contains(lib.getUri())).toList();
        context.addLibraries(updatedLibs, replace: true);
      }

      return context;
    });

    RuntimeBuilder.logVerboseInfo("Application scanning completed in ${result.getFormatted()}.");

    ConfigurableRuntimeScannerSummary summary = DefaultRuntimeScannerSummary();
    summary.setContext(result.result);
    summary.setBuildTime(DateTime.fromMillisecondsSinceEpoch(result.watch.elapsedMilliseconds));
    summary.addInfos(RuntimeBuilder.onCompleted().getInfos());
    summary.addWarnings(RuntimeBuilder.onCompleted().getWarnings());
    summary.addErrors(RuntimeBuilder.onCompleted().getErrors());

    return summary;
  }

  /// Adds default packages to scan if none are specified.
  /// By default, the user's current package and 'jetleaf' are included.
  RuntimeScannerConfiguration _addDefaultPackagesToScan(RuntimeScannerConfiguration configuration, String currentPackage) {
    final defaultPackages = {
      currentPackage,
      ...configuration.packagesToScan
    }.toList();
    final filteredDefaults = defaultPackages.where((pkg) => !configuration.packagesToExclude.contains(pkg)).toList();
    
    return configuration.copyWith(packagesToScan: filteredDefaults);
  }
}