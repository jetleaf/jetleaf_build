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

import '../builder/runtime_builder.dart';
import '../declaration/declaration.dart';
import '../utils/generic_type_parser.dart';
import '../utils/must_avoid.dart';
import '../utils/constant.dart';
import 'declaration_support/abstract_library_declaration_support.dart';

/// {@template default_library_generator}
/// A build-time library generator that integrates both `dart:mirrors`
/// reflection and the Dart Analyzer to produce rich, static- and runtime-aware
/// `LibraryDeclaration` metadata for JetLeaf.
///
/// This generator collects and analyzes libraries discovered through the
/// mirror system as well as additional Dart files provided by the build
/// configuration. It performs tasks such as:
///
/// - Reading and parsing library source code
/// - Creating analyzer contexts for full semantic resolution
/// - Discovering declarations, types, generics, and metadata
/// - Filtering out unnecessary or unsupported packages
/// - Providing detailed diagnostics during the generation process
///
/// The class extends [AbstractLibraryDeclarationSupport], inheriting utility
/// methods for handling library mirrors, declaration extraction, package
/// resolution, and cross-runtime reflection support.
///
/// ### Key Features
/// - Hybrid reflection + analyzer metadata generation  
/// - Automatic skipping of non-relevant libraries (tests, internal JetLeaf runtime files, etc.)
/// - Detection of unresolved generic types and user-friendly warnings  
/// - Configurable refresh behavior for incremental or repeated builds
///
/// This class is used internally by JetLeaf's code generation system and is
/// not typically used directly by application developers.
/// {@endtemplate}
base class DefaultLibraryGenerator extends AbstractLibraryDeclarationSupport {
  /// Whether the library list should be refreshed using the full set of mirrors
  /// provided by the VM.
  ///
  /// - When `true` (default), libraries are gathered from both the mirror
  ///   system and any explicitly loaded runtime mirrors (`forceLoadedMirrors`).
  /// - When `false`, only the forced-loaded mirrors are used, which may be
  ///   desirable in incremental or performance-sensitive build scenarios.
  final bool refresh;

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
  Future<List<LibraryDeclaration>> generate(List<File> dartFiles) async {
    try {
      final libraries = <LibraryDeclaration>[];
      
      final result = await RuntimeBuilder.timeExecution(() async {
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
            final mustSkip = "jetleaf_build/src/runtime/";
            if(filePath == "dart:mirrors" || filePath.startsWith("package:$mustSkip") || filePath.contains(mustSkip)) {
              continue;
            }

            if (!processedLibraries.add(filePath) || forgetPackage(filePath)) {
              continue;
            }

            final pkg = nonNecessaryPackages.where((pkg) => filePath.startsWith('package:$pkg/')).firstOrNull;
            if (pkg != null && !configuration.packagesToScan.contains(pkg)) {
              // Skip this file
              continue;
            }

            LibraryDeclaration libDecl;
            
            if (isBuiltInDartLibrary(fileUri)) {
              // Handle built-in Dart libraries (dart:core, dart:io, etc.)
              libDecl = await generateLibrary(libraryMirror);
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
              
              libDecl = await generateLibrary(libraryMirror);
            }

            libraries.add(libDecl);
            libraryCache[fileUri.toString()] = libDecl;
          } catch (e, stackTrace) {
            RuntimeBuilder.logLibraryVerboseError('Error processing library ${fileUri.toString()}: $e\n$stackTrace');
          }
        }
      });
      RuntimeBuilder.logVerboseInfo("Library generation took ${result.getFormatted()}");

      // Check for unresolved generic classes
      final unresolvedClasses = libraries
        .where((l) => l.getIsPublic() && !l.getIsSynthetic() && l.getPackage().getIsRootPackage())
        .flatMap((l) => l.getDeclarations())
        .whereType<TypeDeclaration>()
        .where((d) => GenericTypeParser.shouldCheckGeneric(d.getType()) && d.getIsPublic() && !d.getIsSynthetic());

      if (unresolvedClasses.isNotEmpty) {
        final warningMessage = '''
  ⚠️ Generic Class Discovery Issue ⚠️
  Found ${unresolvedClasses.length} classes with unresolved runtime types:
  ${unresolvedClasses.map((d) => "• ${d.getSimpleName()} (${d.getQualifiedName()})").join("\n")}

  These classes may need manual type resolution or have complex generic constraints.
  Use @Generic() annotation on these classes to avoid exceptions when invoking such classes
        ''';
        RuntimeBuilder.logVerboseWarning(warningMessage);
      }

      return libraries;
    } finally {
      await cleanup();
    }
  }

  @override
  List<LibraryMirror> getLibraries() => refresh ? [...mirrorSystem.libraries.values, ...forceLoadedMirrors] : [...forceLoadedMirrors];

  @override
  Future<void> cleanup() async {
    await super.cleanup();
  }
}