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

import '../declaration/declaration.dart';
import '../generators/default_library_generator.dart';
import '../utils/file_utility.dart';
import '../generators/library_generator.dart';
import '../runtime_provider/standard_runtime_provider.dart';
import '../runtime_provider/configurable_runtime_provider.dart';
import '../runtime_resolver/runtime_resolving.dart';
import '../utils/utils.dart';
import 'default_runtime_scanner_summary.dart';
import 'configurable_runtime_scanner_summary.dart';
import 'runtime_scanner.dart';
import 'runtime_scanner_configuration.dart';
import 'runtime_scanner_summary.dart';

/// {@template on_logged}
/// Signature for logging callbacks used to report runtime scanning messages.
///
/// This is typically passed to [ApplicationRuntimeScanner] for custom logging:
///
/// ```dart
/// void logInfo(String msg) => print('[INFO] $msg');
/// final scanner = DefaultRuntimeScan(onInfo: logInfo);
/// ```
///
/// {@endtemplate}
typedef OnLogged = void Function(String message);

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
/// The logs are tagged with the current `_package` name when set, helping
/// identify the origin of messages during multi-package scans.
///
/// {@endtemplate}
class ApplicationRuntimeScanner implements RuntimeScanner {
  /// Optional info log callback.
  final OnLogged? _onInfo;

  /// Optional warning log callback.
  final OnLogged? _onWarning;

  /// Optional error log callback.
  final OnLogged? _onError;

  /// {@macro default_runtime_scan}
  ApplicationRuntimeScanner({
    OnLogged? onInfo, 
    OnLogged? onWarning, 
    OnLogged? onError,
  }) : _onInfo = onInfo, _onWarning = onWarning, _onError = onError;

  /// Holds the runtime factory or context being scanned, if any.
  ConfigurableRuntimeProvider? _context;

  /// Optional name of the package currently being scanned.
  String? _package;

  /// Buffer for info-level logs when no info callback is provided.
  final List<String> _infoLogs = [];

  /// Buffer for warning-level logs when no warning callback is provided.
  final List<String> _warningLogs = [];

  /// Buffer for error-level logs when no error callback is provided.
  final List<String> _errorLogs = [];

  /// Logs an info-level message to the [onInfo] callback or buffers it.
  ///
  /// Automatically prepends the current package name if set.
  void _logInfo(String message) {
    String msg = _package != null ? "[$_package] $message" : message;
    if (_onInfo != null) {
      _onInfo(msg);
    } else {
      _infoLogs.add(msg);
    }
  }

  /// Logs a warning-level message to the [onWarning] callback or buffers it.
  ///
  /// Automatically prepends the current package name if set.
  void _logWarning(String message) {
    String msg = _package != null ? "[$_package] $message" : message;
    if (_onWarning != null) {
      _onWarning(msg);
    } else {
      _warningLogs.add(msg);
    }
  }

  /// Logs an error-level message to the [onError] callback or buffers it.
  ///
  /// Automatically prepends the current package name if set.
  void _logError(String message) {
    String msg = _package != null ? "[$_package] $message" : message;
    if (_onError != null) {
      _onError(msg);
    } else {
      _errorLogs.add(msg);
    }
  }

  @override
  Future<RuntimeScannerSummary> scan(RuntimeScannerConfiguration configuration, {Directory? source}) async {
    bool refreshContext = _context == null || !configuration.reload;
    final stopwatch = Stopwatch()..start();
    FileUtility FileUtils = FileUtility(_logInfo, _logWarning, _logError, configuration, true);

    // 1. Setup directory and verify its existence
    if(refreshContext) {
      _logInfo('Creating target directory structure...');
    }

    Directory directory = source ?? Directory.current;

    // 2. Read package name from pubspec.yaml
    _package ??= await FileUtils.readPackageName();

    // 3. Add default packages to scan if none specified
    configuration = _addDefaultPackagesToScan(configuration, _package!);

    // 4. Setup mirror system and access domain
    _logInfo('Setting up mirror system and access domain...');
    mirrors.MirrorSystem access = mirrors.currentMirrorSystem();
    _logInfo('Mirror system and access domain set up. ${access.isolate.rootLibrary.uri}');

    _logInfo("${refreshContext ? "Reloading" : "Scanning"} $_package application...");
    Set<File> dartFiles = {};
    List<Asset> resources = [];
    List<Package> packages = [];

    if(refreshContext) {
      dartFiles = await FileUtils.findDartFiles(directory);
      resources = await FileUtils.discoverAllResources(_package!, access);
      packages = await FileUtils.readPackageGraphDependencies(directory, access);
    } else {
      // For non-rebuilds, only process additions/removals if specified
      if(configuration.additions.isNotEmpty || configuration.removals.isNotEmpty || configuration.filesToScan.isNotEmpty) {
        dartFiles = (configuration.filesToScan + configuration.additions).where((file) => file.path.endsWith('.dart')).toSet();
      }

      if(configuration.updateAssets) {
        resources = await FileUtils.discoverAllResources(_package!, access);
      }

      if(configuration.updatePackages) {
        packages = await FileUtils.readPackageGraphDependencies(directory, access);
      }
    }

    _logInfo("Found ${dartFiles.length} dart files.");
    _logInfo("Found ${resources.length} resources.");
    _logInfo("Found ${packages.length} packages.");

    List<LibraryDeclaration> libraries = [];
    List<TypeDeclaration> specialTypes = [];

    // 5. Load dart files that are not present in the [currentMirrorSystem]
    List<mirrors.LibraryMirror> forceLoadedMirrors = [];
    if (configuration.forceLoadLibraries) {
      _logInfo('Loading dart files that are not present in the [currentMirrorSystem#${access.isolate.debugName}]...');
      final forceLoaded = <String>{};
      Map<File, Uri> urisToLoad = FileUtils.getUrisToLoad(dartFiles, _package!);

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

    // 5. Generate reflection metadata
    _logInfo('Resolving declaration metadata libraries...');
    LibraryGenerator libraryGenerator = DefaultLibraryGenerator(
      mirrorSystem: access,
      forceLoadedMirrors: forceLoadedMirrors,
      onInfo: _logInfo,
      onWarning: _logWarning,
      onError: _logError,
      configuration: configuration,
      packages: packages,
      refresh: refreshContext
    );
    final result = await libraryGenerator.generate(dartFiles.toList());
    _logInfo('Resolved ${result.length} declaration libraries.');

    libraries.addAll(result);

    if (_context != null ) {
      libraries.addAll(_context!.getAllLibraries());
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

    if(refreshContext) {
      _context = StandardRuntimeProvider();
    }
    _context?.setRuntimeResolver(await resolving.resolve());

    if(resources.isNotEmpty) {
      _context?.addAssets(resources, replace: refreshContext);
    }

    if(packages.isNotEmpty) {
      _context?.addPackages(packages, replace: refreshContext);
    }

    if(libraries.isNotEmpty) {
      _context?.addLibraries(libraries, replace: refreshContext);
    }

    // Handle removals (now configuration.removals) by removing them from the context
    if(configuration.removals.isNotEmpty) {
      final libs = _context?.getAllLibraries() ?? [];
      final urisToRemove = configuration.removals.map((f) => FileUtils.resolveToPackageUri(f.absolute.path, _package!)).whereType<String>().toSet();
      final updatedLibs = libs.where((lib) => !urisToRemove.contains(lib.getUri())).toList();
      _context?.addLibraries(updatedLibs, replace: true);
    }

    if(specialTypes.isNotEmpty) {
      _context?.addSpecialTypes(specialTypes, replace: refreshContext);
    }

    stopwatch.stop();
    _logInfo("Application ${refreshContext ? "reloading" : "scanning"} completed in ${stopwatch.elapsedMilliseconds}ms.");

    ConfigurableRuntimeScannerSummary summary = DefaultRuntimeScannerSummary();
    summary.setContext(_context!);
    summary.setBuildTime(DateTime.fromMillisecondsSinceEpoch(stopwatch.elapsedMilliseconds));
    summary.addInfos(_infoLogs);
    summary.addWarnings(_warningLogs);
    summary.addErrors(_errorLogs);

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