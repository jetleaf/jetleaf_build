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

import '../runtime/declaration/declaration.dart';
import 'abstract_asset_support.dart';

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
final class FileUtility extends AbstractAssetSupport {
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
    Map<String, _GraphPackage> graphPackages = {};

    if (graph["packages"] case List graph) {
      graphPackages = Map.fromEntries(graph.whereType<Map>().map((pkg) => MapEntry(pkg["name"], _GraphPackage(
        "${pkg['version']}",
        pkg["dependencies"] is List ? List<String>.from(pkg["dependencies"]) : [],
        pkg["devDependencies"] is List ? List<String>.from(pkg["devDependencies"]) : []
      ))));
    }

    final configPackages = config['packages'] as List<dynamic>? ?? [];
    final result = <Package>[];

    for (final entry in configPackages) {
      if (entry is Map<String, dynamic>) {
        final name = entry['name'] as String?;
        final rootUri = entry['rootUri'] as String?;
        final langVersion = entry['languageVersion'] as String?;
        final graphPackage = graphPackages[name];
        final resolvedFilePath = rootUri != null ? Uri.parse(rootUri).isAbsolute
          ? Uri.parse(rootUri).toFilePath()
          : Directory.current.uri.resolveUri(Uri.parse(rootUri)).toFilePath() : null;

        if (name != null && graphPackage != null) {
          final isRoot = rootUri == '../' || roots.contains(name);
          result.add(MaterialPackage(
            name: name,
            version: graphPackage._version,
            languageVersion: langVersion,
            isRootPackage: isRoot,
            rootUri: rootUri,
            jetleafDependencies: extractJetleafDependencies([...graphPackage._dependencies, ...graphPackage._devDependencies]),
            dependencies: graphPackage._dependencies,
            filePath: resolvedFilePath,
            devDependencies: graphPackage._devDependencies
          ));
        }
      }
    }

    // Fallback to graph only if config is missing
    if (result.isEmpty) {
      for (final pkg in graphPackages.entries) {
        final package = pkg.value;

        result.add(MaterialPackage(
          name: pkg.key,
          version: package._version,
          languageVersion: null,
          isRootPackage: roots.contains(pkg.key),
          rootUri: null,
          filePath: null,
          jetleafDependencies: extractJetleafDependencies([...package._dependencies, ...package._devDependencies]),
          dependencies: package._dependencies,
          devDependencies: package._devDependencies
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
        if (!isSubclassOf(classMirror, gaClass)) {
          continue;
        }

        // Must have zero-arg constructor symbol
        final symbol = findZeroArgsConstructorSymbol(classMirror);
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
}

/// {@template _graph_package}
/// Internal representation of a package entry parsed from `package_graph.json`.
///
/// `_GraphPackage` captures the **resolved dependency state** of a Dart package
/// as produced by JetLeaf’s package graph analysis. It stores the package
/// version along with its direct runtime and development dependencies.
///
/// This class is **internal-only** and is not intended for public API exposure.
/// It exists to support dependency resolution, graph traversal, and package
/// filtering during materialization and analysis.
///
/// ---
///
/// ## Fields
/// - `_version`
///   The resolved semantic version string of the package.
///
/// - `_dependencies`
///   A list of package names that this package depends on at runtime.
///
/// - `_devDependencies`
///   A list of package names required only for development, testing,
///   or build-time tooling.
///
/// ---
///
/// ## Notes
/// - Dependency names are stored as raw strings and are assumed to be
///   normalized by the graph loader.
/// - This class does not perform validation or resolution logic itself;
///   it is a passive data container.
/// {@endtemplate}
final class _GraphPackage {
  /// The resolved version of the package.
  final String _version;

  /// Runtime dependencies declared by this package.
  final List<String> _dependencies;

  /// Development-only dependencies declared by this package.
  final List<String> _devDependencies;

  /// {@macro _graph_package}
  _GraphPackage(this._version, this._dependencies, this._devDependencies);
}