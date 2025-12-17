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

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../builder/runtime_builder.dart';
import '../runtime/scanner/runtime_scanner_configuration.dart';

/// {@template abstract_file_utility}
/// A foundational utility class providing shared logic, configuration access,  
/// and resolution helpers for file-system driven runtime analysis.
///
/// This abstraction centralizes concerns common to tools that:
///
/// - traverse project directories  
/// - resolve `package:` URIs  
/// - apply user-defined include/exclude rules  
/// - identify Dart test files and part files  
/// - coordinate scanning strategies across isolates  
/// - emit structured logging through user-provided callbacks  
///
/// The utility does **not** prescribe how files are discovered or consumed;  
/// instead, it serves as a reusable base for higher-level scanners, analyzers,  
/// or runtime-mirroring systems that must interpret project structure while  
/// respecting configuration and performance constraints.
///
/// ### Responsibilities
/// - Provide access to the parsed `package_config.json` entries and the name of  
///   the active root package.  
/// - Offer standard skip/exclusion logic for determining whether a file is  
///   safe and meaningful to load during runtime scanning.  
/// - Supply lightweight classification helpers such as test-file and part-file  
///   detection.  
/// - Expose callbacks for structured informational, warning, and error logging  
///   without coupling callers to any specific logging framework.  
/// - Integrate with isolate-execution strategies to decide when a file must be  
///   processed by the main isolate versus a background isolate.  
///
/// Subclasses typically compose this utility into more specialized tooling  
/// such as full project scanners, incremental resolvers, or runtime hook  
/// generators.  
///
/// The class is designed for extensibility rather than direct use; concrete  
/// implementations should supply file traversal, actual scanning routines, or  
/// caching policies as needed by the encompassing framework.
/// {@endtemplate}
abstract class AbstractFileUtility {
  /// Cached list of parsed package configuration entries loaded from the
  /// active `package_config.json`.
  ///
  /// This value is populated on-demand and reused for subsequent lookups to
  /// avoid repeated parsing of the configuration file.  
  ///  
  /// `null` indicates that the configuration has not yet been loaded.
  List<PackageConfigEntry>? packageConfigCache;

  /// Name of the root package as determined from the loaded package
  /// configuration.
  ///
  /// This value is resolved once the configuration is parsed and cached
  /// alongside it.  
  ///
  /// Used by utilities that need to differentiate between files inside the
  /// current package versus those coming from dependencies.
  String? currentPackageName;

  /// Logging callback for informational output.
  ///
  /// Typical usage includes reporting discovered files, resolved paths,
  /// or general progress updates during scanning.
  final OnLogged onInfo;

  /// Logging callback for non-fatal warnings.
  ///
  /// This is used to report unexpected but recoverable situations such as:
  /// - Missing package entries  
  /// - Skipped files  
  /// - Deprecated paths found during scanning  
  final OnLogged onWarning;

  /// Logging callback for critical or unrecoverable file-system errors.
  ///
  /// This may be used when a required file is inaccessible, a configuration
  /// is malformed, or a resolution step fails in a way that prevents
  /// continued scanning.
  final OnLogged onError;

  /// Strategy function that determines whether a specific file should be
  /// accessed outside an isolate.
  ///
  /// This is particularly relevant during runtime scanning, where some file
  /// reads may not be safe or efficient within spawned isolates.
  ///
  /// A return value of `true` indicates the main isolate must handle the file
  /// read; otherwise it can be delegated to a background isolate.
  final TryOutsideIsolate tryOutsideIsolate;

  /// Configuration options controlling runtime scanning behavior.
  ///
  /// This object defines limits, file-type filters, traversal rules,
  /// performance tuning options, and other parameters that influence how
  /// the file system is scanned and interpreted.
  final RuntimeScannerConfiguration configuration;

  /// {@macro abstract_file_utility}
  AbstractFileUtility(this.onInfo, this.onWarning, this.onError, this.configuration, this.tryOutsideIsolate);

  /// List of all packages in the project - including dev dependencies
  List<PackageConfigEntry> get packageConfig => packageConfigCache ?? [];

  /// List of all Jetleaf packages you care about
  final Set<String> jetleafPackages = {'jetleaf', 'jetson', 'jtl'};

  /// Determines whether a file should be skipped based *only* on user
  /// configuration and intrinsic unloadability rules.
  ///
  /// This method centralizes all exclusion logic used when collecting URIs
  /// for runtime analysis.
  ///
  /// **Skip Rules:**
  /// 1. **Explicit file removals**  
  ///    Files listed in `removals` or `filesToExclude` are skipped unconditionally.
  ///
  /// 2. **Excluded packages**  
  ///    If the file resolves to a `package:` URI whose package name appears in
  ///    `packagesToExclude`, it is skipped.
  ///
  /// 3. **Test files**  
  ///    If `skipTests` is enabled and the file matches test-path patterns, it is
  ///    skipped *unless* explicitly included in `filesToScan`.
  ///
  /// 4. **Part files**  
  ///    Files containing a `part of` directive are skipped because they cannot be
  ///    loaded independently into the mirror system.
  ///
  /// Returns `true` if the file must be skipped, otherwise `false`.
  bool shouldSkipFile(File file, Uri uri) {
    final filePath = file.absolute.path;
    final normalizedPath = p.normalize(filePath);

    // Only skip files explicitly excluded by user
    final excludedFilePaths = (configuration.removals + configuration.filesToExclude)
        .map((f) => p.normalize(f.absolute.path))
        .toSet();
    
    if (excludedFilePaths.contains(normalizedPath)) {
      return true;
    }

    // Skip files from packages explicitly excluded by user
    final packageName = _getPackageNameFromUri(uri);
    if (packageName != null && configuration.packagesToExclude.contains(packageName)) {
      return true;
    }

    // Skip test files only if user configured skipTests and it's not explicitly included
    if (configuration.skipTests && isTestFile(normalizedPath)) {
      final explicitlyIncluded = configuration.filesToScan.any((f) => p.normalize(f.absolute.path) == normalizedPath);
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

  /// Determines whether a file path refers to a test file.
  ///
  /// A file is considered a test file if its path contains a `test/` or
  /// `tests/` directory segment (case-insensitive).  
  ///
  /// This check is used when applying the `skipTests` configuration to avoid
  /// scanning or processing test files unless explicitly included by the user.
  ///
  /// ### Example Matches
  /// - `lib/foo/test/example.dart`
  /// - `project/tests/util/helpers.dart`
  ///
  /// ### Example Non-Matches
  /// - `lib/contest/util.dart`
  /// - `integration/example.dart`
  bool isTestFile(String filePath) {
    // Matches paths containing `/test/` or `/tests/` (case-insensitive)
    // return RegExp(r'(^|/|\\)(test|tests)(/|\\|$)|_test\.dart$', caseSensitive: false).hasMatch(filePath);
    return RegExp(r'(^|/|\\)(test|tests)(/|\\|$)', caseSensitive: false).hasMatch(filePath);
  }

  /// Extracts the package name from a `package:` URI.
  ///
  /// Returns:
  /// - the first path segment (the package name) for URIs of the form
  ///   `package:<name>/path.dart`
  /// - `null` for non-package URIs.
  String? _getPackageNameFromUri(Uri uri) {
    if (uri.scheme == 'package') {
      final segments = uri.pathSegments;
      return segments.isNotEmpty ? segments.first : null;
    }
    return null;
  }

  /// Loads the package configuration from `.dart_tool/package_config.json`.
  ///
  /// This method populates `packageConfigCache` with a parsed list of
  /// `PackageConfigEntry` objects representing every package known to the
  /// current Dart toolchain.
  ///
  /// **Behavior:**
  /// - If `packageConfigCache` is already loaded, the method returns immediately
  ///   without re-reading the configuration.
  /// - If the configuration file does not exist, a warning is emitted and
  ///   `packageConfigCache` is set to an empty list.
  /// - If the file exists but cannot be parsed, an error is logged and the
  ///   configuration is treated as empty.
  ///
  /// - [source] may override the root directory from which the `.dart_tool`
  ///   folder is resolved; by default, `Directory.current` is used.
  @protected
  Future<void> loadPackageConfig([Directory? source]) async {
    if (packageConfigCache != null) return;

    final packageConfigFile = File(p.join(source?.path ?? Directory.current.path, '.dart_tool', 'package_config.json'));
    final packageConfigDir = packageConfigFile.parent.path;

    if (!await packageConfigFile.exists()) {
      onWarning('Warning: .dart_tool/package_config.json not found. Cannot resolve package URIs for dependencies.', true);
      packageConfigCache = [];
      return;
    }

    try {
      final content = await packageConfigFile.readAsString();
      final json = jsonDecode(content);
      final packagesJson = json['packages'] as List<dynamic>;
      packageConfigCache = packagesJson.map((e) => PackageConfigEntry.fromJson(e as Map<String, dynamic>, packageConfigDir)).toList();
    } catch (e) {
      onError('Error reading or parsing package_config.json: $e', true);
      packageConfigCache = [];
    }
  }

  @mustCallSuper
  Future<void> cleanup() async {
    packageConfigCache = null;
  }

  /// Returns `true` if the given file contains a `part of` directive, meaning
  /// it is a *part file* and cannot be loaded as a standalone library.
  ///
  /// Mirrors cannot load part files directly; they must be loaded indirectly via
  /// their parent library.
  ///
  /// This uses a lightweight regex to avoid full parsing and may return `false`
  /// on unreadable files.
  bool isPartFile(File file);
}

/// Signature for a callback used to determine whether a file should be
/// processed *outside* an isolate.
///
/// This function is typically used by runtime scanners or build systems
/// that need to decide whether certain files (e.g., package config files,
/// generated sources, or non-Dart assets) must be accessed directly from
/// the main isolate rather than delegated to a background isolate.
///
/// Parameters:
/// - [file]: The resolved `File` instance being considered.
/// - [uri]: The original URI representing the file.
///
/// Returns:
/// - `true` if the file must be handled outside the isolate;
/// - `false` if it is safe to process inside an isolate.
typedef TryOutsideIsolate = bool Function(File file, Uri uri);

/// {@template package_config_entry}
/// Represents a single entry in a parsed `package_config.json` file.
///
/// A `PackageConfigEntry` provides the essential metadata needed to resolve
/// package-relative file paths during scanning and runtime analysis.
/// It captures both the declared URIs from the configuration file and a fully
/// resolved absolute filesystem path for the package’s root.
///
/// JetLeaf uses this model to:
/// - Locate source files belonging to a specific package
/// - Resolve `package:` URIs into physical paths
/// - Distinguish between the root package and its dependencies
/// - Support runtime scanning and reflection operations
/// {@endtemplate}
class PackageConfigEntry {
  /// The package name as declared in `package_config.json`.
  ///
  /// This is the canonical package identifier used in `import 'package:...'`
  /// statements and for resolving package dependencies.
  final String name;

  /// The root URI of the package as specified in the configuration.
  ///
  /// This URI may be:
  /// - A `file:` URI pointing directly to a filesystem location.
  /// - A relative URI resolved against the directory containing the
  ///   `package_config.json`.
  ///
  /// This value is preserved exactly as written in the config file.
  final Uri rootUri;

  /// The base URI used when resolving `package:` imports for this package.
  ///
  /// For example, a package with:
  /// ```json
  /// "packageUri": "lib/"
  /// ```
  /// means that `package:foo/foo.dart` maps to the folder:
  /// `<rootUri>/lib/`.
  final Uri packageUri;

  /// The fully resolved absolute filesystem path of the package’s root.
  ///
  /// Unlike [rootUri], this value is:
  /// - Normalized
  /// - Always absolute
  /// - Guaranteed to reference an on-disk directory
  ///
  /// JetLeaf uses this path for any operations requiring direct file access.
  final String absoluteRootPath;

  /// Creates a new [PackageConfigEntry] with fully initialized metadata.
  ///
  /// All fields must be provided and represent one complete package entry.
  /// 
  /// {@macro package_config_entry}
  PackageConfigEntry({
    required this.name,
    required this.rootUri,
    required this.packageUri,
    required this.absoluteRootPath,
  });

  /// Builds a [PackageConfigEntry] directly from a JSON object read from
  /// `package_config.json`.
  ///
  /// This factory handles both absolute and relative `rootUri` values and
  /// resolves them into a normalized absolute filesystem path.
  ///
  /// Parameters:
  /// - [json]: The raw JSON map describing the package entry.
  /// - [packageConfigDir]: The directory in which the `package_config.json`
  ///   file resides; used to resolve relative URIs.
  ///
  /// Returns:
  /// - A fully constructed, filesystem-safe [PackageConfigEntry].
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