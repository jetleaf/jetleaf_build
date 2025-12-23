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

import 'dart:mirrors';
import 'dart:mirrors' as mirrors;

import '../builder/runtime_builder.dart';
import '../runtime/declaration/declaration.dart';
import '../runtime/provider/runtime_provider.dart';
import '../utils/must_avoid.dart';
import '../utils/constant.dart';
import '../utils/utils.dart';
import 'library_generator.dart';

/// {@template default_library_generator}
/// Default implementation of [LibraryGenerator] responsible for producing
/// **runtime declaration metadata** from Dart libraries using the VM
/// mirror system and source-code analysis.
///
/// `DefaultLibraryGenerator` is the core generator used during application
/// runtime scanning. It coordinates library discovery, package resolution,
/// filtering, and metadata extraction, ultimately registering libraries
/// with the JetLeaf runtime.
///
/// ## Key Responsibilities
/// - Enumerate Dart libraries from the mirror system and forced-loaded mirrors
/// - Resolve each library to its owning [Package]
/// - Apply configuration-based filtering (packages, tests, exclusions)
/// - Read and normalize source code for analysis
/// - Generate runtime metadata via `addRuntimeSourceLibrary`
/// - Detect and warn about unresolved generic runtime types
///
/// ## Refresh Behavior
/// The [refresh] flag controls how aggressively libraries are discovered:
/// - `true` (default): Uses **all** libraries from the mirror system
///   plus any `forceLoadedMirrors`
/// - `false`: Operates only on explicitly forced-loaded mirrors,
///   enabling faster incremental or partial builds
///
/// ## Package Resolution
/// A local [packageCache] is maintained during generation to:
/// - Avoid repeated package construction
/// - Ensure consistent package identity
/// - Support built-in Dart SDK packages, user packages, and fallbacks
///
/// ## Error Handling
/// - Individual library failures are isolated and logged
/// - Source read failures do not abort the generation process
/// - Package cache is always cleared after generation completes
///
/// ## Typical Usage
/// This generator is instantiated internally by runtime scanners such as
/// [ApplicationRuntimeScanner] and is not usually constructed directly
/// by application code.
///
/// It forms a critical part of the JetLeaf reflection pipeline, bridging
/// the Dart VM mirror system with runtime-resolvable metadata.
/// {@endtemplate}
base class DefaultLibraryGenerator extends LibraryGenerator {
  /// Whether the library list should be refreshed using the full set of mirrors
  /// provided by the VM.
  ///
  /// - When `true` (default), libraries are gathered from both the mirror
  ///   system and any explicitly loaded runtime mirrors (`forceLoadedMirrors`).
  /// - When `false`, only the forced-loaded mirrors are used, which may be
  ///   desirable in incremental or performance-sensitive build scenarios.
  final bool refresh;

  /// Cache storing resolved [Package] metadata keyed by package name.
  ///
  /// This allows JetLeaf to quickly determine package boundaries, dependencies,
  /// skip logic, and root-package behavior without repeatedly parsing
  /// configuration or scanning the filesystem.
  final Map<String, Package> packageCache = {};

  /// Creates a new [DefaultLibraryGenerator] with the required reflection
  /// environment, logging callbacks, and build configuration.
  ///
  /// The [refresh] flag controls whether the generator should enumerate all
  /// libraries available via the mirror system or operate exclusively on the
  /// supplied forced-loaded mirror set.
  /// 
  /// {@macro default_library_generator}
  DefaultLibraryGenerator({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
    this.refresh = true
  });

  @override
  Future<void> generate(List<File> dartFiles) async {
    try {
      final result = await RuntimeBuilder.timeAsyncExecution(() async {
        // Create package lookup
        for (final package in packages) {
          packageCache[package.getName()] = package;
        }

        final processedLibraries = <String>{};

        RuntimeBuilder.logVerboseInfo('Generating declaration metadata with analyzer integration...');
        final nonNecessaryPackages = getNonNecessaryPackages();
        
        for (final libraryMirror in getLibraries()) {
          final fileUri = libraryMirror.uri;
          final filePath = libraryMirror.uri.toString();

          try {
            if(filePath == "dart:mirrors" || !processedLibraries.add(filePath) || forgetPackage(filePath)) {
              continue;
            }

            final pkg = nonNecessaryPackages.where((pkg) => filePath.startsWith('package:$pkg/')).firstOrNull;
            if (pkg != null && !configuration.packagesToScan.contains(pkg)) {
              // Skip this file
              continue;
            }
            
            if (RuntimeUtils.isBuiltInDartLibrary(fileUri)) {
              // Handle built-in Dart libraries (dart:core, dart:io, etc.)
              await generateLibrary(libraryMirror);
            } else {
              // Handle user libraries and package libraries
              if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
                continue;
              }

              String? fileContent;
              try {
                fileContent = await readSourceCode(fileUri);
                if ((isTest(fileContent) && configuration.skipTests) || hasMirrorImport(fileContent) || forgetPackage(fileContent)) {
                  continue;
                }
              } catch (e) {
                RuntimeBuilder.logLibraryVerboseError('Could not read file content for $fileUri: $e');
                continue;
              }
              
              await generateLibrary(libraryMirror);
            }
          } catch (e, stackTrace) {
            RuntimeBuilder.logLibraryVerboseError('Error processing library ${fileUri.toString()}: $e\n$stackTrace');
          }
        }
      });
      RuntimeBuilder.logVerboseInfo("Library generation took ${result.getFormatted()}");

      // Check for unresolved generic classes
      final unresolvedClasses = Runtime.getUnresolvedClasses();

      if (unresolvedClasses.isNotEmpty) {
        RuntimeBuilder.logVerboseWarning(unresolvedClasses.getWarningMessage());
      }
    } finally {
      packageCache.clear();
    }
  }

  @override
  List<LibraryMirror> getLibraries() => [...forceLoadedMirrors, ...mirrorSystem.libraries.values];

  /// Resolves and returns the [Package] instance associated with the given
  /// library [uri].
  ///
  /// This method determines which JetLeaf package a library belongs to by
  /// examining the URI scheme and path. It supports:
  ///
  /// ### 🔹 1. Built-In Dart & SDK Libraries
  /// If the URI represents a built-in Dart SDK library (e.g. `dart:core`,
  /// `dart:async`, `dart:io`), JetLeaf assigns it to the shared built-in
  /// package (`Constant.DART_PACKAGE_NAME`). The method returns:
  ///
  /// - an existing cached built-in [Package], **or**
  /// - a newly constructed built-in package via `createBuiltInPackage()`.
  ///
  /// ### 🔹 2. User or Third-Party Packages
  /// If the URI corresponds to a package external to the Dart SDK:
  /// - The package name is extracted using `getPackageNameFromUri()`.
  /// - If a matching package exists in `packageCache`, that instance is reused.
  /// - Otherwise, a default package is created via `createDefaultPackage()`.
  ///
  /// ### 🔹 3. Graceful Fallbacks
  /// If the URI cannot be associated with any recognizable package:
  /// - The method falls back to creating a package named `"unknown"`.
  ///
  /// ### 🧩 Role in the JetLeaf Reflection Pipeline
  /// Package resolution is essential for:
  /// - grouping declarations under their correct package,
  /// - enforcing filtering and scoping rules,
  /// - tracking local vs. external declarations,
  /// - enabling correct relative URI computations,
  /// - preventing cross-package reflection when disabled.
  ///
  /// ### Returns
  /// The resolved or newly created [Package] instance that should own the
  /// provided library [uri].
  Package _getPackage(Uri uri) {
    if (RuntimeUtils.isBuiltInDartLibrary(uri)) {
      return packageCache[Constant.DART_PACKAGE_NAME] ?? createBuiltInPackage(packageCache);
    } else {
      final packageName = getPackageNameFromUri(uri.toString());
      return packageCache[packageName] ?? createDefaultPackage(packageName ?? uri.toString());
    }
  }

  /// Generates runtime metadata for a single Dart library.
  ///
  /// This method is responsible for converting a [LibraryMirror] obtained
  /// from the Dart VM mirror system into a **runtime source library**
  /// registered with the JetLeaf runtime.
  ///
  /// Processing steps:
  /// 1. Resolve the library’s [Uri]
  /// 2. Determine the owning [Package] via [_getPackage]
  /// 3. Detect whether the library is a built-in Dart SDK library
  /// 4. Load and normalize the library’s source code
  /// 5. Register the library using `addRuntimeSourceLibrary`
  ///
  /// Built-in Dart libraries (`dart:*`) and user/package libraries are both
  /// supported, with built-in libraries flagged appropriately to ensure
  /// correct runtime behavior.
  ///
  /// Errors during source loading are handled gracefully by returning
  /// an empty source string, allowing metadata generation to continue.
  Future<void> generateLibrary(mirrors.LibraryMirror library) async {
    final uri = library.uri;
    final package = _getPackage(uri);
    final isBuiltIn = RuntimeUtils.isBuiltInDartLibrary(uri);
    final sourceCode = await readSourceCode(uri);
    return addRuntimeSourceLibrary(package, sourceCode, isBuiltIn, library);
  }

  /// Reads and returns the normalized source code for a Dart library.
  ///
  /// This helper resolves a library [uri] to a file path, loads the file
  /// contents, and strips comments to produce a clean source representation
  /// suitable for analysis and metadata generation.
  ///
  /// Supported inputs:
  /// - [Uri]: Resolved directly or via `resolveUri`
  /// - [String]: Parsed into a [Uri] and resolved recursively
  ///
  /// Behavior:
  /// - Returns the source code with comments removed
  /// - Silently ignores I/O or resolution errors
  /// - Returns an empty string if the source cannot be read
  ///
  /// This design ensures that missing or unreadable files do not
  /// interrupt the overall library generation process.
  Future<String> readSourceCode(Object uri) async {
    if (uri case Uri uri) {
      try {
        final filePath = (await resolveUri(uri) ?? uri).toFilePath();
        String fileContent = await File(filePath).readAsString();
        
        return RuntimeUtils.stripComments(fileContent);
      } catch (_) { }
    } else if(uri case String uri) {
      return await readSourceCode(Uri.parse(uri));
    }

    return "";
  }
}