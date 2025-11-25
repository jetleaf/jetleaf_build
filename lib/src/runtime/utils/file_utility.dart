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

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:mirrors' as mirrors;

import 'package:path/path.dart' as p;

import '../../constant.dart';
import '../../declaration/declaration.dart';
import '../../declaration/generative.dart';
import '../../must_avoid.dart';
import '../runtime_scanner/runtime_scanner_configuration.dart';

typedef OnLogged = void Function(String message);

/// Utility class for file system operations related to Dart projects.
class FileUtility {
  List<PackageConfigEntry>? _packageConfig;
  String? _currentPackageName;

  final OnLogged _onInfo;
  final OnLogged _onWarning;
  final OnLogged _onError;
  final bool _tryOutsideIsolate;
  final RuntimeScannerConfiguration _configuration;

  /// File patterns that should be skipped
  // static const List<String> _skipPatterns = [
  //   r'.*/(test|tests)/.*',
  //   r'.*_test\.dart$',
  //   r'.*/tool/.*',
  //   r'.*/example/.*',
  //   r'.*/benchmark/.*',
  //   r'.*/\.dart_tool/.*',
  //   r'.*/build/.*',
  // ];

  FileUtility(this._onInfo, this._onWarning, this._onError, this._configuration, this._tryOutsideIsolate) {
    _loadPackageConfig();
  }

  /// List of all packages in the project - including dev dependencies
  List<PackageConfigEntry> get packageConfig => _packageConfig ?? [];

  /// List of all Jetleaf packages you care about
  final Set<String> jetleafPackages = {'jetleaf', 'jetson', 'jtl'};

  /// Loads the package configuration from .dart_tool/package_config.json.
  Future<void> _loadPackageConfig([Directory? source]) async {
    if (_packageConfig != null) return;

    final packageConfigFile = File(p.join(source?.path ?? Directory.current.path, '.dart_tool', 'package_config.json'));
    final packageConfigDir = packageConfigFile.parent.path;

    if (!await packageConfigFile.exists()) {
      _onWarning('Warning: .dart_tool/package_config.json not found. Cannot resolve package URIs for dependencies.');
      _packageConfig = [];
      return;
    }

    try {
      final content = await packageConfigFile.readAsString();
      final json = jsonDecode(content);
      final packagesJson = json['packages'] as List<dynamic>;
      _packageConfig = packagesJson
          .map((e) => PackageConfigEntry.fromJson(e as Map<String, dynamic>, packageConfigDir))
          .toList();
    } catch (e) {
      _onError('Error reading or parsing package_config.json: $e');
      _packageConfig = [];
    }
  }

  /// Checks if a file should be skipped based only on user configuration
  bool shouldSkipFile(File file, Uri uri) {
    final filePath = file.absolute.path;
    final normalizedPath = p.normalize(filePath);

    // Only skip files explicitly excluded by user
    final excludedFilePaths = (_configuration.removals + _configuration.filesToExclude)
        .map((f) => p.normalize(f.absolute.path))
        .toSet();
    
    if (excludedFilePaths.contains(normalizedPath)) {
      return true;
    }

    // Skip files from packages explicitly excluded by user
    final packageName = _getPackageNameFromUri(uri);
    if (packageName != null && _configuration.packagesToExclude.contains(packageName)) {
      return true;
    }

    // Skip test files only if user configured skipTests and it's not explicitly included
    if (_configuration.skipTests && _isTestFile(normalizedPath)) {
      final explicitlyIncluded = _configuration.filesToScan
          .any((f) => p.normalize(f.absolute.path) == normalizedPath);
      if (!explicitlyIncluded) {
        return true;
      }
    }

    // Skip files that are part of other files (part of directive) - these are genuinely unloadable
    if (isPartFile(file)) {
      return true;
    }

    return false;
  }

  /// Extracts package name from a URI
  String? _getPackageNameFromUri(Uri uri) {
    if (uri.scheme == 'package') {
      final segments = uri.pathSegments;
      return segments.isNotEmpty ? segments.first : null;
    }
    return null;
  }

  /// Checks if a file contains a 'part of' directive
  bool isPartFile(File file) {
    try {
      final content = file.readAsStringSync();
      return content.contains(RegExp(r'^\s*part\s+of\s+', multiLine: true));
    } catch (e) {
      return false;
    }
  }


  /// Resolves a list of files to their package URIs, being as inclusive as possible.
  Map<File, Uri> getUrisToLoad(Set<File> files, String package) {
    Map<File, Uri> uris = {};
    int skippedCount = 0;

    for (final file in files) {
      final normalizedFilePath = p.normalize(file.absolute.path);
      
      // Try to resolve to package URI first
      final packageUriString = resolveToPackageUri(normalizedFilePath, package);
      Uri uri;
      
      if (packageUriString != null) {
        uri = Uri.parse(packageUriString);
      } else {
        // Use file URI as fallback - don't skip files just because they can't be resolved to package URIs
        uri = file.uri;
        _onInfo('Using file URI for $normalizedFilePath (could not resolve to package URI)');
      }

      // Only skip if user explicitly wants to exclude or if genuinely unloadable
      if (!shouldSkipFile(file, uri)) {
        uris[file] = uri;
      } else {
        skippedCount++;
      }
    }

    if (skippedCount > 0) {
      _onInfo('Skipped $skippedCount files due to user configuration or unloadable files');
    }

    return uris;
  }

  /// Checks if a file is part of the user's project (not a dependency)
  bool _isUserProjectFile(String filePath) {
    final currentProjectPath = p.normalize(Directory.current.path);
    return p.isWithin(currentProjectPath, filePath);
  }

  /// Forces a Dart library at [uri] to be loaded into the [mirrorSystem].
  Future<mirrors.LibraryMirror?> forceLoadLibrary(Uri uri, File file, mirrors.MirrorSystem mirrorSystem) async {
    final mustSkip = "jetleaf_build/src/runtime/";

    if(uri.toString().startsWith("package:$mustSkip") || uri.toString().contains(mustSkip)) {
      return null;
    }

    if(mirrorSystem.libraries.containsKey(uri)) {
      return null;
    }

    if (isPartFile(file)) {
      return null;
    }

    try {
      // Run the heavy loading in an isolate
      return await Isolate.run<mirrors.LibraryMirror?>(() => _loadLibrary(uri, file, mirrorSystem), debugName: 'lib_$uri');
    } catch (e) {
      try {
        if(_tryOutsideIsolate) {
          return await _loadLibrary(uri, file, mirrorSystem);
        }
      } catch (e) {
        // Only log as warning for dependency files, error for user files
        if (_isUserProjectFile(file.absolute.path)) {
          _onError('Error loading user library $uri: $e');
        }
      }
    }

    return null;
  }

  Future<mirrors.LibraryMirror?> _loadLibrary(Uri uri, File file, mirrors.MirrorSystem mirrorSystem) async {
    _onInfo('Force loading library $uri...');
    try {
      return await mirrorSystem.isolate.loadUri(uri);
    } catch (e) {
      // Try alternative approaches for problematic files
      if (uri.scheme == 'file') {
        final packageUri = resolveToPackageUri(file.absolute.path, await readPackageName());

        if (packageUri != null && packageUri != uri.toString()) {
          try {
            final alternativeUri = Uri.parse(packageUri);
            _onInfo('Retrying with package URI: $alternativeUri for file: ${file.path}');
            return await mirrorSystem.isolate.loadUri(alternativeUri);
          } catch (e2) {
            _onWarning('Failed to load with both file and package URI for ${file.path}: $e2');
          }
        }
      }

      return null;
    }
  }

  /// Reads the package name from the pubspec.yaml file in the current directory.
  Future<String> readPackageName() async {
    if (_currentPackageName != null) return _currentPackageName!;

    final pubspecFile = File(p.join(Directory.current.path, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw Exception('pubspec.yaml not found in current directory.');
    }
    
    final content = await pubspecFile.readAsString();
    final nameMatch = RegExp(r'name:\s*(\S+)').firstMatch(content);
    if (nameMatch != null && nameMatch.group(1) != null) {
      _currentPackageName = nameMatch.group(1)!;
      return _currentPackageName!;
    }
    throw Exception('Could not find package name in pubspec.yaml');
  }

  /// Finds all Dart files within the current project and ALL its dependencies, respecting only user exclusions.
  Future<Set<File>> findDartFiles(Directory projectDir) async {
    final Set<File> dartFiles = {};

    final allFilesToScan = (_configuration.filesToScan).map((f) => p.normalize(f.absolute.path)).toSet();
    final allFilesToExclude = (_configuration.filesToExclude).map((f) => p.normalize(f.absolute.path)).toSet();

    // Scan user project
    _onInfo('Scanning user project for Dart files...');
    await _scanDirectoryForDartFiles(Directory.current, dartFiles, allFilesToScan, allFilesToExclude);

    // Scan ALL dependencies unless user explicitly excludes them
    _onInfo('Scanning ALL dependencies for Dart files...');
    await scanAllDependenciesForDartFiles(dartFiles, allFilesToScan, allFilesToExclude);

    return dartFiles;
  }

  /// Scans a directory for Dart files with minimal filtering
  Future<void> _scanDirectoryForDartFiles(Directory dir, Set<File> dartFiles, Set<String> filesToScan, Set<String> filesToExclude, [String packageName = ""]) async {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final normalizedPath = p.normalize(entity.absolute.path);
        
        // Skip only explicitly excluded files
        if (filesToExclude.contains(normalizedPath)) {
          continue;
        }

        // If specific files are listed, only include those
        if (filesToScan.isNotEmpty && !filesToScan.contains(normalizedPath)) {
          continue;
        }

        // Skip test files only if user configured skipTests
        if (_configuration.skipTests && _isTestFile(normalizedPath) && !filesToScan.contains(normalizedPath)) {
          continue;
        }

        if (forgetPackage(normalizedPath) || forgetPackage(await entity.readAsString())) {
          continue;
        }

        final build = "jetleaf_build";
        final allowed = ['annotations.dart', 'constant.dart', 'exceptions.dart'];

        if (packageName == build && !(allowed.contains(normalizedPath) || normalizedPath.contains("runtime_hint"))) {
          continue;
        }

        // Include everything else
        dartFiles.add(entity);
      }
    }
  }

  /// Scans ALL dependencies for Dart files unless explicitly excluded by user
  Future<void> scanAllDependenciesForDartFiles(Set<File> dartFiles, Set<String> filesToScan, Set<String> filesToExclude) async {
    if (_packageConfig == null) {
      await _loadPackageConfig();
    }

    if (_packageConfig == null) {
      return;
    }

    for (final pkg in _packageConfig!) {
      final packageName = pkg.name;
      final packageRoot = Directory(pkg.absoluteRootPath);

      if (!await packageRoot.exists()) continue;

      // Skip if user excluded the package
      if (_configuration.packagesToExclude.contains(packageName)) {
        _onInfo('Skipping excluded package: $packageName');
        continue;
      }

      final keys = await extractPubspecDependencyKeys(packageRoot);
      final hasJetleaf = keys.any(jetleafPackages.contains) || keys.any((key) => key.startsWith(PackageNames.MAIN));

      if (!hasJetleaf) {
        _onInfo('Skipping non-Jetleaf package: $packageName');
        continue;
      }
      
      // If user specified packages to scan, only include those. Otherwise include all.
      final bool includePackage = _configuration.packagesToScan.isEmpty || _configuration.packagesToScan.contains(packageName);

      if (includePackage) {
        _onInfo('Scanning package: $packageName');
        await _scanDirectoryForDartFiles(packageRoot, dartFiles, filesToScan, filesToExclude, packageName);
      }
    }
  }

  /// {@template extract_pubspec_dependency_keys}
  /// Extracts all dependency keys declared in a `pubspec.yaml` located at the
  /// given [packageRoot].
  ///
  /// This function:
  /// - locates `pubspec.yaml` inside the directory
  /// - returns an empty set if the file does not exist
  /// - scans only `dependencies:` and `dev_dependencies:` sections
  /// - stops reading when another top-level YAML key is reached
  /// - ignores comments and empty lines
  /// - extracts only the package names, not version constraints
  ///
  /// ### Example
  /// ```dart
  /// final deps = await extractPubspecDependencyKeys(Directory('/my/pkg'));
  /// print(deps); // {http, shelf, path, ...}
  /// ```
  ///
  /// Returns a `Set<String>` containing only dependency identifiers.
  /// {@endtemplate}
  Future<Set<String>> extractPubspecDependencyKeys(Directory packageRoot) async {
    final pubspecFile = File('${packageRoot.path}/pubspec.yaml');

    if (!await pubspecFile.exists()) return {};

    final lines = await pubspecFile.readAsLines();

    final Set<String> keys = {};
    bool inDeps = false;

    for (final rawLine in lines) {
      final line = rawLine.trimRight();

      // Enter dependency sections
      if (line == 'dependencies:' || line == 'dev_dependencies:') {
        inDeps = true;
        continue;
      }

      // Leave section when hitting next top-level key
      if (inDeps && !rawLine.startsWith(' ') && line.isNotEmpty) {
        inDeps = false;
        continue;
      }

      if (!inDeps) continue;

      // Ignore comments or empty lines
      if (line.isEmpty || line.trimLeft().startsWith('#')) continue;

      // Extract the package key only
      final match = RegExp(r'^\s*([\w\-]+)\s*:').firstMatch(rawLine);
      if (match != null) {
        keys.add(match.group(1)!);
      }
    }

    return keys;
  }

  /// Checks if a file should be included based on path patterns
  // bool _shouldIncludeFile(String filePath) {
  //   // Only include files from lib directories in dependencies
  //   return filePath.contains('/lib/') && !_isTestFile(filePath);
  // }

  /// Checks if a file is a test file
  bool _isTestFile(String filePath) {
    // Matches paths containing `/test/` or `/tests/` (case-insensitive)
    // return RegExp(r'(^|/|\\)(test|tests)(/|\\|$)|_test\.dart$', caseSensitive: false).hasMatch(filePath);
    return RegExp(r'(^|/|\\)(test|tests)(/|\\|$)', caseSensitive: false).hasMatch(filePath);
  }

  /// Finds all non-Dart files within the current project directory, respecting inclusion/exclusion lists.
  Future<Set<File>> findNonDartFiles(Directory projectDir) async {
    final Set<File> nonDartFiles = {};
    
    final allFilesToScan = (_configuration.filesToScan).map((f) => p.normalize(f.absolute.path)).toSet();
    final allFilesToExclude = (_configuration.filesToExclude).map((f) => p.normalize(f.absolute.path)).toSet();

    // Helper to check if a file should be included
    bool shouldIncludeFile(String filePath) {
      final normalizedPath = p.normalize(filePath);
      if (allFilesToExclude.contains(normalizedPath)) {
        return false;
      }
      if (allFilesToScan.isEmpty) {
        return true;
      }
      return allFilesToScan.contains(normalizedPath);
    }

    // 1. Find non-Dart files in the current project directory
    await for (final entity in projectDir.list(recursive: true, followLinks: false)) {
      if (entity is File && !entity.path.endsWith('.dart')) {
        if (shouldIncludeFile(entity.absolute.path)) {
          nonDartFiles.add(entity);
        }
      }
    }

    // 2. Find non-Dart files in dependencies (only if explicitly requested)
    if (_configuration.packagesToScan.isNotEmpty && _packageConfig != null) {
      for (final pkg in _packageConfig!) {
        final packageName = pkg.name;
        final packageRoot = Directory(pkg.absoluteRootPath);

        final bool includePackage = _configuration.packagesToScan.contains(packageName);
        final bool excludePackage = _configuration.packagesToExclude.contains(packageName);

        if (includePackage && !excludePackage && await packageRoot.exists()) {
          await for (final entity in packageRoot.list(recursive: true, followLinks: false)) {
            if (entity is File && !entity.path.endsWith('.dart')) {
              if (shouldIncludeFile(entity.absolute.path)) {
                nonDartFiles.add(entity);
              }
            }
          }
        }
      }
    }

    return nonDartFiles;
  }

  /// Resolves a file system path to a package URI.
  String? resolveToPackageUri(String absoluteFilePath, String currentPackageName, [Directory? project]) {
    if (packageConfig.isEmpty) {
      return null;
    }

    final normalizedAbsoluteFilePath = p.normalize(absoluteFilePath);

    // Try to resolve against known packages
    for (final pkg in packageConfig) {
      final absoluteLibPath = p.normalize(p.join(pkg.absoluteRootPath, p.fromUri(pkg.packageUri)));
      if (p.isWithin(absoluteLibPath, normalizedAbsoluteFilePath)) {
        final relativePath = p.relative(normalizedAbsoluteFilePath, from: absoluteLibPath);
        final cleanedRelativePath = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
        return 'package:${pkg.name}/$cleanedRelativePath';
      }
    }

    // Check if it's in the current project's lib directory
    final current = project ?? Directory.current;
    final currentProjectLibPath = p.normalize(p.join(current.path, 'lib'));
    
    if (p.isWithin(currentProjectLibPath, normalizedAbsoluteFilePath)) {
      final relativePath = p.relative(normalizedAbsoluteFilePath, from: currentProjectLibPath);
      final cleanedRelativePath = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
      return 'package:$currentPackageName/$cleanedRelativePath';
    }

    return null;
  }

  /// Reads dependencies from .dart_tool/package_graph.json.
  Future<List<Package>> readPackageGraphDependencies(Directory projectRoot, [mirrors.MirrorSystem? mirrorSystem]) async {
    final graphFile = File(p.join(projectRoot.path, '.dart_tool', 'package_graph.json'));
    final configFile = File(p.join(projectRoot.path, '.dart_tool', 'package_config.json'));

    if (!graphFile.existsSync()) return [];

    Map<String, dynamic> graph = {};
    Map<String, dynamic> config = {};

    try {
      graph = jsonDecode(await graphFile.readAsString());
    } catch (e) {
      _onError('Error reading package_graph.json: $e');
      return [];
    }

    if (configFile.existsSync()) {
      try {
        config = jsonDecode(await configFile.readAsString());
      } catch (e) {
        _onError('Error reading package_config.json: $e');
      }
    }

    final roots = Set<String>.from(graph['roots'] ?? []);
    final graphPackages = Map.fromEntries(
      (graph['packages'] as List)
          .whereType<Map>()
          .map((pkg) => MapEntry(pkg['name'], pkg['version'])),
    );

    final configPackages = config['packages'] as List<dynamic>? ?? [];
    final result = <Package>[];

    for (final entry in configPackages) {
      if (entry is Map<String, dynamic>) {
        final name = entry['name'] as String?;
        final rootUri = entry['rootUri'] as String?;
        final langVersion = entry['languageVersion'] as String?;
        final version = graphPackages[name];

        if (name != null && version != null) {
          final isRoot = rootUri == '../' || roots.contains(name);
          result.add(PackageImplementation(
            name: name,
            version: version,
            languageVersion: langVersion,
            isRootPackage: isRoot,
            rootUri: rootUri,
            filePath: rootUri != null ? Uri.parse(rootUri).isAbsolute
                ? Uri.parse(rootUri).toFilePath()
                : Directory.current.uri.resolveUri(Uri.parse(rootUri)).toFilePath() : null,
          ));
        }
      }
    }

    // Fallback to graph only if config is missing
    if (result.isEmpty) {
      for (final pkg in graphPackages.entries) {
        result.add(PackageImplementation(
          name: pkg.key,
          version: pkg.value,
          languageVersion: null,
          isRootPackage: roots.contains(pkg.key),
          rootUri: null,
          filePath: null,
        ));
      }
    }

    if (mirrorSystem != null) {
      result.addAll(await _readMirrorGenerativePackages(mirrorSystem));
    }

    return result;
  }

  /// Scans the mirror system for classes that extend [GenerativePackage],
  /// have a zero-argument constructor, and can be instantiated.
  ///
  /// This is used to discover auto-generated `GenerativePackage` classes
  /// that JetLeaf’s code generator emits to describe package metadata.
  ///
  /// A class is considered a valid *generative package* if:
  /// - it is a subclass of [GenerativePackage] (directly or indirectly)
  /// - it provides a zero-argument constructor
  /// - instantiating it does not throw
  ///
  /// Returns a list of instantiated [GenerativePackage] objects.
  Future<List<GenerativePackage>> _readMirrorGenerativePackages(mirrors.MirrorSystem mirrorSystem) async {
    final packages = <GenerativePackage>[];
    final gaClass = mirrors.reflectClass(GenerativePackage);

    for (final lib in mirrorSystem.libraries.values) {
      for (final decl in lib.declarations.values) {
        // We only care about classes
        if (decl is! mirrors.ClassMirror) continue;

        final classMirror = decl;

        // Must be a subclass of GenerativePackage
        if (!_isSubclassOf(classMirror, gaClass)) {
          continue;
        }

        // Must have zero-arg constructor
        final ctor = _findZeroArgsConstructor(classMirror);
        if (ctor == null) {
          continue;
        }

        // Try to instantiate
        try {
          final instanceMirror = classMirror.newInstance(ctor, const []);
          final instance = instanceMirror.reflectee;

          if (instance is GenerativePackage) {
            packages.add(instance);
          }
        } catch (_) { }
      }
    }

    return packages;
  }

  /// Discovers all resource files in the current project and ALL dependencies.
  Future<List<Asset>> discoverAllResources(String currentPackageName, [mirrors.MirrorSystem? mirrorSystem]) async {
    if (_packageConfig == null) {
      await _loadPackageConfig();
    }

    final List<Asset> allResources = [];
    final currentProjectRoot = Directory.current.path;

    List<Directory> searchDirectories(String root) => [
      Directory(p.join(root, Constant.RESOURCES_DIR_NAME)),
      Directory(p.join(root, 'lib', Constant.RESOURCES_DIR_NAME)),
      Directory(p.join(root, Constant.PACKAGE_ASSET_DIR)),
      Directory(p.join(root, 'lib', Constant.PACKAGE_ASSET_DIR)),
    ];

    // 1. User's project resources
    _onInfo('🔍 Scanning user project for resources...');
    for (final dir in searchDirectories(currentProjectRoot)) {
      if (dir.existsSync()) {
        allResources.addAll(await _scanDirectoryForResources(dir, currentPackageName, currentProjectRoot));
      }
    }

    // 2. ALL dependency resources unless explicitly excluded
    _onInfo('🔍 Scanning all dependencies for resources...');
    for (final dep in (_packageConfig ?? <PackageConfigEntry>[])) {
      final depPackagePath = dep.absoluteRootPath;
      final packageName = dep.name;

      // Only exclude if user explicitly excludes this package
      final bool excludePackage = _configuration.packagesToExclude.contains(packageName);
      final bool includePackage = _configuration.packagesToScan.isEmpty || _configuration.packagesToScan.contains(packageName);

      if (Directory(depPackagePath).existsSync() && includePackage && !excludePackage) {
        for (final dir in searchDirectories(depPackagePath)) {
          if (dir.existsSync()) {
            allResources.addAll(await _scanDirectoryForResources(dir, dep.name, depPackagePath));
          }
        }
      }
    }

    if (mirrorSystem != null) {
      allResources.addAll(await _scanMirrorForGenerativeAssets(mirrorSystem));
    }
    
    return allResources;
  }

  /// Scans a directory for resource files.
  Future<List<Asset>> _scanDirectoryForResources(Directory dir, String packageName, String packageRootPath) async {
    final List<Asset> resources = [];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          resources.add(AssetImplementation(
            filePath: entity.path,
            fileName: p.basename(entity.path),
            packageName: packageName,
            contentBytes: await entity.readAsBytes(),
          ));
        } catch (e) {
          _onWarning('Could not read resource file ${entity.path}: $e');
        }
      }
    }
    return resources;
  }

  /// Scans the running isolate's mirror system for classes that extend
  /// [GenerativeAsset], have a zero-argument constructor, and can be
  /// successfully instantiated.
  ///
  /// This is used to discover auto-generated asset classes produced by
  /// JetLeaf’s code generation (`GenerativeAsset` subclasses).
  ///
  /// Returns a list of instantiated [GenerativeAsset] objects.
  Future<List<GenerativeAsset>> _scanMirrorForGenerativeAssets(mirrors.MirrorSystem mirrorSystem) async {
    final assets = <GenerativeAsset>[];
    final gaClass = mirrors.reflectClass(GenerativeAsset);

    for (final lib in mirrorSystem.libraries.values) {
      for (final decl in lib.declarations.values) {
        // We only care about classes
        if (decl is! mirrors.ClassMirror) continue;

        final classMirror = decl;

        // Must be a subclass of GenerativeAsset
        if (!_isSubclassOf(classMirror, gaClass)) {
          continue;
        }

        // Must have zero-arg constructor
        final ctor = _findZeroArgsConstructor(classMirror);
        if (ctor == null) {
          continue;
        }

        // Try to instantiate
        try {
          final instanceMirror = classMirror.newInstance(ctor, const []);
          final instance = instanceMirror.reflectee;

          if (instance is GenerativeAsset) {
            assets.add(instance);
          }
        } catch (_) { }
      }
    }

    return assets;
  }

  /// Returns `true` if [classMirror] is the same as, or extends, [target].
  ///
  /// This walks up the superclass chain (excluding mixins), returning
  /// `false` once the root `Object` is reached.
  bool _isSubclassOf(mirrors.ClassMirror classMirror, mirrors.ClassMirror target) {
    var current = classMirror;
    while (true) {
      if (current == target) return true;
      if (current.superclass == null) return false;
      current = current.superclass!;
    }
  }

  /// Returns the symbol of a zero-argument constructor for [mirror],
  /// or `null` if the class defines none.
  ///
  /// A valid generative asset/package must define:
  ///   ClassName();
  Symbol? _findZeroArgsConstructor(mirrors.ClassMirror mirror) {
    for (final entry in mirror.declarations.entries) {
      final decl = entry.value;

      if (decl is mirrors.MethodMirror && decl.isConstructor && decl.parameters.isEmpty) {
        return entry.key; // constructor symbol
      }
    }

    return null;
  }
}

/// {@template package_config_entry}
/// Represents an entry from the `.dart_tool/package_config.json` file.
/// {@endtemplate}
class PackageConfigEntry {
  final String name;
  final Uri rootUri;
  final Uri packageUri;
  final String absoluteRootPath;

  PackageConfigEntry({
    required this.name,
    required this.rootUri,
    required this.packageUri,
    required this.absoluteRootPath,
  });

  factory PackageConfigEntry.fromJson(Map<String, dynamic> json, String packageConfigDir) {
    final name = json['name'] as String;
    final rootUri = Uri.parse(json['rootUri'] as String);
    final packageUri = Uri.parse(json['packageUri'] as String);

    String resolvedRootPath;
    if (rootUri.scheme == 'file') {
      resolvedRootPath = p.fromUri(rootUri);
    } else {
      resolvedRootPath = p.normalize(p.join(packageConfigDir, p.fromUri(rootUri)));
    }

    return PackageConfigEntry(
      name: name,
      rootUri: rootUri,
      packageUri: packageUri,
      absoluteRootPath: resolvedRootPath,
    );
  }
}