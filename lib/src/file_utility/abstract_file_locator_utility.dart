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

import 'package:path/path.dart' as p;

import 'abstract_file_utility.dart';
import '../utils/constant.dart';
import '../utils/must_avoid.dart';
import 'located_files.dart';

/// {@template abstract_file_locator_utility}
/// A high-level file discovery utility that extends [AbstractFileUtility] with
/// capabilities for locating **both Dart and non-Dart source files** across the
/// user’s project and all dependency packages.
///
/// This class forms the foundation of JetLeaf’s project-scanning layer.  
/// It provides a consistent, configurable mechanism for assembling the complete
/// set of files relevant to runtime reflection, analysis, or code generation.
///
/// ### Core Responsibilities
/// - Recursively scan the user project for Dart or non-Dart files  
/// - Optionally scan all dependency packages, respecting JetLeaf-specific rules  
/// - Apply user-defined inclusion and exclusion rules  
/// - Honor test-file skip behavior and part-file detection  
/// - Participate in JetLeaf’s “package relevance” filtering (e.g., skipping
///   non-JetLeaf packages unless required)  
/// - Route logging through the parent utility for insight into scanning behavior
///
/// ### Behavioral Highlights
/// - **User-Included Files:** If any files are explicitly listed in  
///   `configuration.filesToScan`, scanning becomes opt-in and only those files  
///   are considered.  
///
/// - **User-Excluded Files:** Paths listed in `configuration.filesToExclude`  
///   take precedence and are always ignored.  
///
/// - **Package Filtering:** Dependency packages may be included, excluded, or  
///   auto-filtered based on JetLeaf’s dependency graph.  
///
/// - **Project-wide Scanning:** Provides high-level conveniences such as  
///   `findDartFiles()` and `findNonDartFiles()`, which orchestrate scanning  
///   across the project and its dependencies.  
///
/// ### Intended Use
/// Concrete subclasses typically provide:
/// - custom traversal logic  
/// - caching/persistence for repeated scans  
/// - post-processing of discovered files  
/// - integration with build steps or runtime injection systems  
///
/// This class itself focuses on *file discovery semantics*, leaving higher-level
/// interpretation to the implementing framework.
/// {@endtemplate}
abstract class AbstractFileLocatorUtility extends AbstractFileUtility {
  /// Keeps track of logged "Skipping package" message to reduce message logs.
  final Set<String> _loggedSkippedPackageMessages = {};

  /// {@macro abstract_file_locator_utility}
  AbstractFileLocatorUtility(super.configuration, super.onError, super.onInfo, super.onWarning, super.tryOutsideIsolate);

  /// Scans the current project **and all dependency packages** for Dart source
  /// files, applying user-defined inclusion and exclusion rules.
  ///
  /// This is the primary method for assembling the complete set of Dart files
  /// relevant to JetLeaf’s analysis or code generation systems.
  ///
  /// ### Features
  /// - Honors explicit user-included files via `configuration.filesToScan`
  /// - Honors explicit user-excluded files via `configuration.filesToExclude`
  /// - Skips test files if `skipTests = true`
  /// - Skips packages that do not depend on JetLeaf (unless disabled)
  /// - Scans both the user’s project and all dependencies
  ///
  /// ### Parameters
  /// - [projectDir] — The root directory of the user's project.
  ///
  /// ### Returns
  /// A set of all discovered `.dart` files.
  Future<LocatedFiles> findDartFiles(Directory projectDir) async {
    final LocatedFiles files = LocatedFiles();

    final allFilesToScan = (configuration.filesToScan).map((f) => p.normalize(f.absolute.path)).toSet();
    final allFilesToExclude = (configuration.filesToExclude).map((f) => p.normalize(f.absolute.path)).toSet();

    // Scan user project
    onInfo('Scanning user project for Dart files...', true);
    await _scanDirectoryForDartFiles(Directory.current, files, allFilesToScan, allFilesToExclude);

    // Scan ALL dependencies unless user explicitly excludes them
    onInfo('Scanning ALL dependencies for Dart files...', true);
    await scanAllDependenciesForDartFiles(files, allFilesToScan, allFilesToExclude);

    return files;
  }

  /// Scans a directory tree for `.dart` files, respecting user-specified
  /// inclusion rules, exclusion rules, test-file behavior, and internal
  /// JetLeaf filtering logic.
  ///
  /// This function is intentionally low-level and used by both project scanning
  /// and dependency scanning routines.
  ///
  /// ### Filtering Rules
  /// - Files explicitly excluded → **skipped**
  /// - If inclusion list is non-empty → only included if explicitly listed
  /// - Test files → skipped only when configured and not force-included
  /// - "Forgotten" files via `forgetPackage()` checks → skipped
  ///
  /// ### Parameters
  /// - [dir] — Directory to scan.
  /// - [located] — The mutable [LocatedFiles] used to collect results.
  /// - [filesToScan] — Normalized user-included file paths.
  /// - [filesToExclude] — Normalized user-excluded file paths.
  /// - [packageName] — Optional package name used for advanced internal filters.
  Future<void> _scanDirectoryForDartFiles(Directory dir, LocatedFiles located, Set<String> filesToScan, Set<String> filesToExclude, [String packageName = "", Directory? pkgRoot]) async {
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
        if (configuration.skipTests && isTestFile(normalizedPath) && !filesToScan.contains(normalizedPath)) {
          continue;
        }

        if (forgetPackage(normalizedPath) || forgetPackage(await entity.readAsString())) {
          continue;
        }

        // final build = "jetleaf_build";
        // final allowed = ['annotations.dart', 'constant.dart', 'exceptions.dart'];

        // if (packageName == build && !(allowed.contains(normalizedPath) || normalizedPath.contains("runtime_hint"))) {
        //   continue;
        // }

        // Include everything else
        if (pkgRoot case final packageRoot?) {
          if ((await getJetleafDependencies(packageRoot)).isEmpty) {
            final message = 'Skipping non-Jetleaf package: $packageName';

            if (_loggedSkippedPackageMessages.add(message)) {
              onInfo(message, true);
            }

            located.addToAnalyzer(entity);
          } else {
            located.add(entity);
          }
        } else {
          located.add(entity);
        }
      }
    }
  }

  /// Scans **all dependency packages** for Dart files using the same filtering
  /// logic as project scanning, extended with package-level inclusion/exclusion
  /// configuration and JetLeaf dependency detection.
  ///
  /// ### Package-Level Logic
  /// - Packages listed in `packagesToExclude` → **skipped**
  /// - If `packagesToScan` is non-empty → scan only listed packages
  /// - A dependency is considered a “JetLeaf package” if any of its dependencies
  ///   match `jetleafPackages` or begin with `PackageNames.MAIN`
  ///
  /// ### Parameters
  /// - [located] — The [LocatedFiles] where discovered `.dart` files are added.
  /// - [filesToScan] — User-specified inclusion list.
  /// - [filesToExclude] — User-specified exclusion list.
  Future<void> scanAllDependenciesForDartFiles(LocatedFiles located, Set<String> filesToScan, Set<String> filesToExclude) async {
    if (packageConfigCache == null) {
      await loadPackageConfig();
    }

    if (packageConfigCache == null) {
      return;
    }

    for (final pkg in packageConfigCache!) {
      final packageName = pkg.name;
      final packageRoot = Directory(pkg.absoluteRootPath);

      if (!await packageRoot.exists()) continue;

      // Skip if user excluded the package
      if (configuration.packagesToExclude.contains(packageName)) {
        onInfo('Skipping excluded package: $packageName', true);
        continue;
      }
      
      // If user specified packages to scan, only include those. Otherwise include all.
      final bool includePackage = configuration.packagesToScan.isEmpty || configuration.packagesToScan.contains(packageName);

      if (includePackage) {
        onInfo('Scanning package: $packageName', true);
        await _scanDirectoryForDartFiles(packageRoot, located, filesToScan, filesToExclude, packageName, packageRoot);
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

  /// Returns the set of **JetLeaf-related dependencies** declared in a package.
  ///
  /// This method inspects the `pubspec.yaml` located at [packageRoot] and
  /// extracts all declared dependency names. From that set, it filters and
  /// returns only dependencies that are considered part of the JetLeaf
  /// ecosystem.
  ///
  /// A dependency is classified as a *JetLeaf dependency* if:
  /// - Its name exists in [jetleafPackages], **or**
  /// - Its name starts with [PackageNames.MAIN] (the JetLeaf main package prefix)
  ///
  /// Parameters:
  /// - [packageRoot]: The root directory of the Dart package containing
  ///   a `pubspec.yaml` file.
  ///
  /// Returns:
  /// - A [Set] of dependency names that belong to the JetLeaf framework
  ///   or its core modules.
  Future<Set<String>> getJetleafDependencies(Directory packageRoot) async {
    final keys = await extractPubspecDependencyKeys(packageRoot);
    return extractJetleafDependencies(keys).toSet();
  }

  /// Returns the set of **JetLeaf-related dependencies** declared in a package.
  ///
  /// This method inspects the given iterable [dependencies] to filter and
  /// returns only dependencies that are considered part of the JetLeaf
  /// ecosystem.
  ///
  /// A dependency is classified as a *JetLeaf dependency* if:
  /// - Its name exists in [jetleafPackages], **or**
  /// - Its name starts with [PackageNames.MAIN] (the JetLeaf main package prefix)
  Iterable<String> extractJetleafDependencies(Iterable<String> dependencies) => dependencies.where((key) => jetleafPackages.contains(key) || key.startsWith(PackageNames.MAIN));

  /// Returns the set of **non-JetLeaf dependencies** declared in a package.
  ///
  /// This method complements [getJetleafDependencies] by identifying
  /// dependencies that do **not** belong to the JetLeaf ecosystem.
  ///
  /// A dependency is classified as *non-JetLeaf* if:
  /// - Its name is not listed in [jetleafPackages], **or**
  /// - Its name does not start with [PackageNames.MAIN]
  /// 
  /// Parameters:
  /// - [packageRoot]: The root directory of the Dart package containing
  ///   a `pubspec.yaml` file.
  ///
  /// Returns:
  /// - A [Set] of dependency names that are external to the JetLeaf framework.
  Future<Set<String>> getNonJetleafDependencies(Directory packageRoot) async {
    final keys = await extractPubspecDependencyKeys(packageRoot);
    return keys.where((key) => !jetleafPackages.contains(key) || !key.startsWith(PackageNames.MAIN)).toSet();
  }

  /// Finds all **non-Dart files** within the current project and optionally
  /// selected dependency packages, respecting the user's inclusion and exclusion
  /// rules from the runtime scanner configuration.
  ///
  /// ### Behavior
  /// - Any file ending **not** with `.dart` is eligible.
  /// - Files listed in `filesToExclude` are always skipped.
  /// - If `filesToScan` is non-empty, only explicitly listed files are included.
  /// - Dependencies are scanned **only** when the user explicitly lists them in
  ///   `packagesToScan`, and not present in `packagesToExclude`.
  ///
  /// ### Parameters
  /// - [projectDir] — The root directory of the user project.
  ///
  /// ### Returns
  /// A `Set<File>` containing all discovered non-Dart files.
  Future<Set<File>> findNonDartFiles(Directory projectDir) async {
    final Set<File> nonDartFiles = {};
    
    final allFilesToScan = (configuration.filesToScan).map((f) => p.normalize(f.absolute.path)).toSet();
    final allFilesToExclude = (configuration.filesToExclude).map((f) => p.normalize(f.absolute.path)).toSet();

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
    if (configuration.packagesToScan.isNotEmpty && packageConfigCache != null) {
      for (final pkg in packageConfigCache!) {
        final packageName = pkg.name;
        final packageRoot = Directory(pkg.absoluteRootPath);

        final bool includePackage = configuration.packagesToScan.contains(packageName);
        final bool excludePackage = configuration.packagesToExclude.contains(packageName);

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

  @override
  Future<void> cleanup() async {
    await super.cleanup();
    _loggedSkippedPackageMessages.clear();
  }
}