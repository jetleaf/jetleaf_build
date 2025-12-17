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
import 'dart:mirrors' as mirrors;

import 'package:path/path.dart' as p;

import 'abstract_file_utility.dart';
import 'abstract_part_file_utility.dart';
import '../utils/constant.dart';
import '../declaration/declaration.dart';
import '../generative/generative.dart';
import '../runtime/scanner/runtime_scanner_configuration.dart';

/// {@template file_utility}
/// A utility class providing file-system and package-resolution helpers
/// for Dart and JetLeaf runtime environments.
///
/// `FileUtility` centralizes logic for interacting with:
/// - `package_config.json` parsing and caching
/// - Resolution of package-local and project-local file paths
/// - Determining safe file access contexts (e.g., inside vs. outside isolates)
/// - Logging of file-related operations
///
/// This class is used internally by JetLeaf runtime scanners,
/// reflection systems, and AOT tooling to robustly locate, load,
/// and classify project files.
///
/// The utility caches package configuration entries for performance and
/// exposes controlled logging hooks that allow the host application or
/// framework to capture scanner output without depending on any logging
/// package.
///
/// Fields:
/// - [packageConfigCache]: Cached list of parsed package configuration entries.
/// - [currentPackageName]: Name of the root package resolved from the
///   active package configuration.
/// - [onInfo]: Callback for informational logging messages.
/// - [onWarning]: Callback for warnings that do not halt execution.
/// - [onError]: Callback for critical errors encountered during file
///   operations.
/// - [tryOutsideIsolate]: Strategy function to determine whether specific
///   files must be read in the main isolate.
/// - [configuration]: Runtime scanner configuration options controlling
///   scanning behavior and file-system traversal rules.
/// {@endtemplate}
final class FileUtility extends AbstractPartFileUtility {
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

  /// {@macro file_utility}
  FileUtility(super.onInfo, super.onWarning, super.onError, super.configuration, super.tryOutsideIsolate) {
    loadPackageConfig();
  }

  /// Reads dependency information for the current Dart project by combining
  /// data from:
  ///
  /// - **`.dart_tool/package_graph.json`** – Provides dependency names,
  ///   versions, and root markers.
  /// - **`.dart_tool/package_config.json`** – Provides resolved URIs,
  ///   language versions, and filesystem paths.
  ///
  /// The resulting dependency list includes:
  ///
  /// - All packages explicitly listed in `package_config.json`
  /// - Their versions from the package graph
  /// - Flags indicating whether each package is a **root package**
  /// - Resolved absolute file paths when available
  ///
  /// If `package_config.json` is missing, unreadable, or incomplete,
  /// this method gracefully **falls back** to using only the package graph.
  ///
  /// ### Runtime Reflection
  /// If the optional [mirrorSystem] is provided, the method also scans the
  /// runtime environment for classes extending [GenerativePackage] and having
  /// a zero-argument constructor. These “generative" packages behave like
  /// dynamically declared package metadata at runtime and are added to the
  /// final list.
  ///
  /// ### Parameters
  /// - [projectRoot]: Root directory of the Dart project whose dependencies
  ///   should be resolved.
  /// - [mirrorSystem]: Optional runtime reflection system.  
  /// - [libraries]: A filtered list of library mirrors, if reflection
  ///   should be restricted.
  ///
  /// ### Returns
  /// A list of concrete [Package] implementations describing all detected
  /// project dependencies.
  Future<List<Package>> readPackageGraphDependencies(Directory projectRoot, [mirrors.MirrorSystem? mirrorSystem, List<mirrors.LibraryMirror>? libraries]) async {
    final graphFile = File(p.join(projectRoot.path, '.dart_tool', 'package_graph.json'));
    final configFile = File(p.join(projectRoot.path, '.dart_tool', 'package_config.json'));

    if (!graphFile.existsSync()) return [];

    Map<String, dynamic> graph = {};
    Map<String, dynamic> config = {};

    try {
      graph = jsonDecode(await graphFile.readAsString());
    } catch (e) {
      onError('Error reading package_graph.json: $e', true);
      return [];
    }

    if (configFile.existsSync()) {
      try {
        config = jsonDecode(await configFile.readAsString());
      } catch (e) {
        onError('Error reading package_config.json: $e', true);
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
      result.addAll(await _readMirrorGenerativePackages(mirrorSystem, libraries));
    }

    return result;
  }

  /// Scans all reflected libraries for classes that extend [GenerativePackage].
  ///
  /// A class is considered a *generative package descriptor* if:
  ///
  /// - It extends or implements [GenerativePackage] (directly or indirectly)
  /// - It defines a zero-argument constructor, enabling reflective instantiation
  ///
  /// Each valid class is instantiated and added to the returned list.  
  /// Errors during instantiation are intentionally swallowed to avoid
  /// interrupting discovery of other valid classes.
  ///
  /// ### Parameters
  /// - [mirrorSystem]: The reflection system providing access to all reachable
  ///   libraries.
  /// - [libraries]: Optional filtered subset of libraries.
  ///
  /// ### Returns
  /// List of runtime-discovered [GenerativePackage] instances.
  Future<List<GenerativePackage>> _readMirrorGenerativePackages(mirrors.MirrorSystem mirrorSystem, List<mirrors.LibraryMirror>? libraries) async {
    final packages = <GenerativePackage>[];
    final gaClass = mirrors.reflectClass(GenerativePackage);

    for (final lib in libraries ?? mirrorSystem.libraries.values) {
      for (final decl in lib.declarations.values) {
        // We only care about classes
        if (decl is! mirrors.ClassMirror) continue;

        final classMirror = decl;

        // Must be a subclass of GenerativePackage
        if (!_isSubclassOf(classMirror, gaClass)) {
          continue;
        }

        // Must have zero-arg constructor symbol
        final symbol = _findZeroArgsConstructorSymbol(classMirror);
        if (symbol == null) {
          continue;
        }

        // Try to instantiate
        try {
          final instanceMirror = classMirror.newInstance(symbol, const []);
          final instance = instanceMirror.reflectee;

          if (instance is GenerativePackage) {
            packages.add(instance);
          }
        } catch (_) { }
      }
    }

    return packages;
  }

  /// Discovers all resource files available in the current project as well as
  /// across all resolved package dependencies.
  ///
  /// This method performs a full resource scan following JetLeaf’s asset
  /// discovery conventions. It searches several known directories inside both
  /// the root project and each dependency:
  ///
  /// - `<package>/resources/`
  /// - `<package>/lib/resources/`
  /// - `<package>/assets/`
  /// - `<package>/lib/assets/`
  /// - The package root itself
  ///
  /// **Behavior overview:**
  ///
  /// 1. Ensures the package configuration is loaded before scanning.
  /// 2. Scans the current (user) project for assets.
  /// 3. Scans every dependency package unless explicitly excluded via
  ///    [RuntimeScannerConfiguration.packagesToExclude].
  /// 4. Optionally enriches results using mirrors when Dart VM reflection is
  ///    available.
  ///
  /// **Filtering logic:**
  /// - A dependency is included only if:
  ///   - It is not explicitly excluded, AND
  ///   - Either the scan list is empty, or the package is included in
  ///     `packagesToScan`.
  ///
  /// **Parameters:**
  /// - [currentPackageName]: The name of the root package.
  /// - [mirrorSystem]: (Optional) A mirror system to scan for generative assets.
  /// - [libraries]: (Optional) Specific libraries to include when scanning with
  ///   VM mirrors.
  ///
  /// **Returns:**
  /// A complete list of discovered [Asset] objects from both the current project
  /// and all included dependencies.
  Future<List<Asset>> discoverAllResources(String currentPackageName, [mirrors.MirrorSystem? mirrorSystem, List<mirrors.LibraryMirror>? libraries]) async {
    if (packageConfigCache == null) {
      await loadPackageConfig();
    }

    final List<Asset> allResources = [];
    final currentProjectRoot = Directory.current.path;

    List<Directory> searchDirectories(String root) => [
      Directory(p.join(root, Constant.RESOURCES_DIR_NAME)),
      Directory(p.join(root, 'lib', Constant.RESOURCES_DIR_NAME)),
      Directory(p.join(root, Constant.PACKAGE_ASSET_DIR)),
      Directory(p.join(root, 'lib', Constant.PACKAGE_ASSET_DIR)),
      Directory(root),
    ];

    // 1. User's project resources
    onInfo('🔍 Scanning user project for resources...', true);
    for (final dir in searchDirectories(currentProjectRoot)) {
      if (dir.existsSync()) {
        allResources.addAll(await _scanDirectoryForResources(dir, currentPackageName, currentProjectRoot));
      }
    }

    // 2. ALL dependency resources unless explicitly excluded
    onInfo('🔍 Scanning all dependencies for resources...', true);
    for (final dep in (packageConfigCache ?? <PackageConfigEntry>[])) {
      final depPackagePath = dep.absoluteRootPath;
      final packageName = dep.name;

      // Only exclude if user explicitly excludes this package
      final bool excludePackage = configuration.packagesToExclude.contains(packageName);
      final bool includePackage = configuration.packagesToScan.isEmpty || configuration.packagesToScan.contains(packageName);

      if (Directory(depPackagePath).existsSync() && includePackage && !excludePackage) {
        for (final dir in searchDirectories(depPackagePath)) {
          if (dir.existsSync()) {
            allResources.addAll(await _scanDirectoryForResources(dir, dep.name, depPackagePath));
          }
        }
      }
    }

    if (mirrorSystem != null) {
      allResources.addAll(await _scanMirrorForGenerativeAssets(mirrorSystem, libraries));
    }
    
    return allResources;
  }

  /// Scans a single directory for resource files and converts them into
  /// [Asset] instances.
  ///
  /// This method performs a deep, recursive scan of the given [dir] and
  /// collects all non-Dart files. Each recognized file is read and wrapped into
  /// an [AssetImplementation], which contains:
  ///
  /// - The file path  
  /// - The filename  
  /// - The package that owns the asset  
  /// - Raw file bytes  
  ///
  /// Files ending with `.dart` are intentionally ignored since they are source
  /// files, not end-user assets.
  ///
  /// **Parameters:**
  /// - [dir]: The directory to scan.
  /// - [packageName]: The owning package’s name.
  /// - [packageRootPath]: The absolute path to the package root.
  ///
  /// **Returns:**
  /// A list of successfully parsed resource files.
  ///
  /// Any unreadable files result in a logged warning rather than an exception,
  /// ensuring the scan process remains fault-tolerant.
  Future<List<Asset>> _scanDirectoryForResources(Directory dir, String packageName, String packageRootPath) async {
    final List<Asset> resources = [];
    await for (final entity in dir.list(recursive: true, followLinks: true)) {
      if (entity is File && !entity.path.endsWith(".dart")) {
        try {
          resources.add(AssetImplementation(
            filePath: entity.path,
            fileName: p.basename(entity.path),
            packageName: packageName,
            contentBytes: await entity.readAsBytes(),
          ));
        } catch (e) {
          onWarning('Could not read resource file ${entity.path}: $e', true);
        }
      }
    }
    return resources;
  }

  /// Scans loaded Dart libraries (via `dart:mirrors`) for classes that define
  /// **generative assets** — i.e., classes that extend [GenerativeAsset] and
  /// expose a zero-argument constructor.
  ///
  /// This reflective scan supplements file-based resource discovery by allowing
  /// assets to be defined programmatically. Any class that:
  ///
  /// 1. Extends or implements [GenerativeAsset] (directly or indirectly),
  /// 2. Has a callable zero-argument constructor,
  ///
  /// will be instantiated and collected.
  ///
  /// **How discovery works:**
  /// - Iterate over all libraries in the provided [mirrorSystem] or a filtered
  ///   list of [libraries].
  /// - Inspect each class declaration.
  /// - Determine whether the class is a subtype of [GenerativeAsset] using
  ///   [_isSubclassOf].
  /// - Look for a zero-argument constructor via `_findZeroArgsConstructorSymbol`
  ///   (defined elsewhere in this class).
  /// - Attempt instantiation via `ClassMirror.newInstance`.
  ///
  /// If instantiation succeeds and the reflected instance is a
  /// [GenerativeAsset], it is added to the returned list.
  ///
  /// **Fault tolerance:**
  /// - Constructor invocation errors are silently ignored to prevent a single
  ///   broken class from interrupting the entire discovery pipeline.
  ///
  /// **Parameters:**
  /// - [mirrorSystem]: The active reflective view of the Dart program.
  /// - [libraries]: Optional subset of libraries to restrict the scan.
  ///
  /// **Returns:**
  /// A list of instantiated generative assets discovered through reflection.
  Future<List<GenerativeAsset>> _scanMirrorForGenerativeAssets(mirrors.MirrorSystem mirrorSystem, List<mirrors.LibraryMirror>? libraries) async {
    final assets = <GenerativeAsset>[];
    final gaClass = mirrors.reflectClass(GenerativeAsset);

    for (final lib in libraries ?? mirrorSystem.libraries.values) {
      for (final decl in lib.declarations.values) {
        // We only care about classes
        if (decl is! mirrors.ClassMirror) continue;

        final classMirror = decl;

        // Must be a subclass of GenerativeAsset
        if (!_isSubclassOf(classMirror, gaClass)) {
          continue;
        }

        // Must have zero-arg constructor symbol
        final symbol = _findZeroArgsConstructorSymbol(classMirror);
        if (symbol == null) {
          continue;
        }

        // Try to instantiate
        try {
          final instanceMirror = classMirror.newInstance(symbol, const []);
          final instance = instanceMirror.reflectee;

          if (instance is GenerativeAsset) {
            assets.add(instance);
          }
        } catch (_) {}
      }
    }

    return assets;
  }

  /// Determines whether [classMirror] is the same type as [target] or a
  /// transitive subtype of it.
  ///
  /// The check is performed using a recursive traversal of:
  ///
  /// 1. The class itself  
  /// 2. All implemented interfaces  
  /// 3. The superclass chain  
  ///
  /// This ensures accurate subtype detection even for deep or mixed inheritance
  /// hierarchies, including classes that implement [GenerativeAsset] through
  /// multiple interfaces rather than direct extension.
  ///
  /// **Parameters:**
  /// - [classMirror]: The class being examined.
  /// - [target]: The type to compare against.
  ///
  /// **Returns:**
  /// `true` if [classMirror] is the same as or a subtype of [target],
  /// otherwise `false`.
  bool _isSubclassOf(mirrors.ClassMirror classMirror, mirrors.ClassMirror target) {
    // 1. Check the class itself
    if (classMirror == target) return true;

    // 2. Check all interfaces implemented by this class
    for (final interface in classMirror.superinterfaces) {
      if (interface == target) return true;
      if (_isSubclassOf(interface, target)) return true;
    }

    // 3. Recurse into superclass (if exists)
    final superClass = classMirror.superclass;
    if (superClass == null) return false;

    return _isSubclassOf(superClass, target);
  }

  /// Attempts to locate a **zero-argument constructor** for the given class.
  ///
  /// A class is considered eligible for reflective instantiation only if it
  /// exposes a constructor whose parameter list is empty. This method scans
  /// all declarations of the provided [mirror] and checks:
  ///
  /// - The declaration is a [mirrors.MethodMirror]
  /// - It represents a constructor (`isConstructor == true`)
  /// - It defines **no parameters**
  ///
  /// When such a constructor is found, this method returns the canonical
  /// invocation symbol `Symbol('')`, which corresponds to the unnamed
  /// (default) constructor in Dart’s reflective invocation model.
  ///
  /// ### Why return `Symbol("")`?
  /// Dart’s reflection system treats all unnamed constructors—no matter
  /// how they appear in source—as `Symbol('')`.  
  /// This aligns with how `ClassMirror.newInstance` expects the constructor
  /// symbol for default constructors.
  ///
  /// ### Parameters:
  /// - [mirror]: The class mirror to inspect for a zero-argument constructor.
  ///
  /// ### Returns:
  /// - The constructor symbol (`Symbol('')`) if such a constructor exists.
  /// - `null` if the class does not define any zero-argument constructor.
  Symbol? _findZeroArgsConstructorSymbol(mirrors.ClassMirror mirror) {
    for (final entry in mirror.declarations.entries) {
      final decl = entry.value;

      if (decl is mirrors.MethodMirror && decl.isConstructor && decl.parameters.isEmpty) {
        return Symbol(""); // constructor symbol
      }
    }

    return null;
  }
}