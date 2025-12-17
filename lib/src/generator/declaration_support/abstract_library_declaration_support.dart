// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:io';
import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart' as meta;

import '../../builder/runtime_builder.dart';
import '../../declaration/declaration.dart';
import '../../utils/constant.dart';
import '../../utils/generic_type_parser.dart';
import 'abstract_class_declaration_support.dart';

/// {@template abstract_library_declaration_support}
/// Provides the high-level orchestration, integration, and transformation logic
/// required to generate full [LibraryDeclaration] objects for JetLeaf.
///
/// This class forms the **final and highest layer** of the reflection + analyzer
/// interoperability pipeline. It extends [AbstractClassDeclarationSupport] by
/// adding capabilities that operate at the *library* level—coordinating class
/// discovery, typedef extraction, top-level function parsing, Dart analyzer
/// integration, package resolution, source-file filtering, annotation
/// extraction, and declaration construction.
///
/// ### 🔍 Primary Responsibilities
///
/// **1. Library Reflection & Analyzer Fusion**  
/// JetLeaf uses both `dart:mirrors` (runtime metadata) and the Dart Analyzer
/// (static AST metadata). This class merges the two worlds into a single,
/// consistent representation:
/// - Mirrors provide runtime types, generic information, enum metadata, and
///   library structure.
/// - The Analyzer provides AST-level elements, source locations, fully resolved
///   types, nullability info, and annotations in static form.
///
/// This support class ensures both perspectives stay synchronized during
/// generation.
///
/// **2. Library-Level Declaration Generation**  
/// The `generateLibrary()` method produces a complete and self-contained
/// [LibraryDeclaration] by:
/// - Identifying classes, mixins, enums, typedefs, and top-level members  
/// - Filtering internal, synthetic, excluded, or package-skippable declarations  
/// - Reading source files (with test-skipping and mirror-import detection)  
/// - Resolving the owning package of each library  
/// - Attaching metadata, annotations, and visibility flags  
/// - Delegating class-level construction to inherited functionality  
///
/// **3. Package Resolution**  
/// The internal `_getPackage()` method determines which JetLeaf package a
/// library belongs to, handling:
/// - Built-in core and SDK libraries  
/// - External packages  
/// - Fallback handling for unknown URIs or edge-case schemes  
///
/// **4. Source-Code Analysis & Filtering**  
/// The helper `_readSourceCode()` applies JetLeaf’s file-level inclusion logic:
/// - Skips tests when configured  
/// - Detects illegal or undesired mirror imports  
/// - Gracefully handles missing or unreadable files  
///
/// **5. Accurate Annotation Extraction**  
/// All annotation metadata from runtime mirrors and static Analyzer metadata is
/// merged and resolved through `extractAnnotations()`, enabling JetLeaf to
/// produce consistent annotation models across reflection modes.
///
/// ### 🧩 The JetLeaf Declaration Pipeline
/// In the complete hierarchy of reflection support classes:
///
/// ```
/// — AbstractDeclarationSupport
///    └─ AbstractClassDeclarationSupport
///          └─ AbstractLibraryDeclarationSupport  ← (this class)
/// ```
///
/// This class is responsible for **final assembly**, delegating class-level work
/// to inherited methods such as `generateClass()`, `generateMixin()`,
/// `generateEnum()`, and their typedef/function/field counterparts.
///
/// ### ⚙️ Extensibility
///
/// This is an `abstract` class intended to be subclassed by concrete JetLeaf
/// reflection backends. Subclasses may:
/// - Override package resolution behavior  
/// - Extend annotation handling  
/// - Inject custom filtering or configuration hooks  
/// - Add support for new declaration types or structure  
///
/// ### 🛡️ Reliability and Fail-Safe Behavior
///
/// JetLeaf reflection must operate across diverse runtime environments.
/// Therefore this class:
/// - Never throws during declaration collection (errors become warnings)  
/// - Uses safe null-aware lookups and analyzer fallback patterns  
/// - Maintains internal caches to prevent duplicate work  
/// - Ensures minimal reflection cost by reading source only when required  
///
/// ### Summary
///
/// `AbstractLibraryDeclarationSupport` is the central coordination layer for
/// JetLeaf’s library-level reflection system. It unifies runtime mirrors,
/// static analyzer metadata, package resolution, source parsing, annotation
/// extraction, filtering rules, and declaration assembly into a single coherent
/// generation pipeline.
///
/// Subclasses use it as the authoritative foundation for building full
/// library-level models in the JetLeaf framework.
/// {@endtemplate}
abstract class AbstractLibraryDeclarationSupport extends AbstractClassDeclarationSupport {
  /// {@macro abstract_library_declaration_support}
  AbstractLibraryDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

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
    if (isBuiltInDartLibrary(uri)) {
      return packageCache[Constant.DART_PACKAGE_NAME] ?? createBuiltInPackage();
    } else {
      final packageName = getPackageNameFromUri(uri.toString());
      return packageCache[packageName] ?? createDefaultPackage(packageName ?? "unknown");
    }
  }

  @override
  Future<LibraryDeclaration> generateLibrary(mirrors.LibraryMirror library) async {
    // Clear processing caches for this library
    clearProcessingCaches();

    final uri = library.uri;
    final uriString = uri.toString();
    final package = _getPackage(uri);

    final logMessage = "Processing $uriString in (${package.getName()})";
    RuntimeBuilder.logLibraryVerboseInfo(logMessage);

    final result = await RuntimeBuilder.timeExecution(() async {
      final libraryElement = await getLibraryElement(uri);
      final isNotBuiltIn = !isBuiltInDartLibrary(uri);
      final isBuiltIn = isBuiltInDartLibrary(uri);

      final currentLibrary = StandardLibraryDeclaration(
        uri: uriString,
        element: libraryElement,
        parentPackage: package,
        declarations: [],
        recordLinkDeclarations: [],
        isPublic: !isInternal(uriString),
        isSynthetic: isSynthetic(uriString),
        annotations: await extractAnnotations(library.metadata, uriString, uri, package, libraryElement?.metadata.annotations),
        sourceLocation: uri,
      );

      libraryCache[uriString] = currentLibrary;
      final declarations = <SourceDeclaration>[];
      final recordLinkDeclarations = <RecordLinkDeclaration>[];

      // Process classes and mixins
      for (final classMirror in library.declarations.values.whereType<mirrors.ClassMirror>()) {
        final fileUri = classMirror.location?.sourceUri ?? uri;
        final className = mirrors.MirrorSystem.getName(classMirror.simpleName);
        
        if (isNotBuiltIn && (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri))) {
          continue;
        }

        Type type = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;
        type = await resolveGenericAnnotationIfNeeded(type, classMirror, package, uriString, uri, className);

        if (isNotBuiltIn && configuration.scanClasses.isNotEmpty && !configuration.scanClasses.contains(type)) {
          continue;
        }

        if (isNotBuiltIn && configuration.excludeClasses.contains(type)) {
          continue;
        }
        
        final content = await _readSourceCode(fileUri, isNotBuiltIn);
        if (isNotBuiltIn && content.value) {
          continue;
        }

        try {
          if (classMirror.isEnum) {
            declarations.add(await generateEnum(classMirror, package, uriString, fileUri, isBuiltIn));
          } else if (isMixinClass(content.key, className)) {
            declarations.add(await generateMixin(classMirror, package, uriString, fileUri, isBuiltIn));
          } else {
            declarations.add(await generateClass(classMirror, package, uriString, fileUri, isBuiltIn));
          }
        } catch (_) { }
      }

      // Process typedefs
      for (final typedefMirror in library.declarations.values.whereType<mirrors.TypedefMirror>()) {
        final name = mirrors.MirrorSystem.getName(typedefMirror.simpleName);
        if (isNotBuiltIn && (isInternal(name) || isSynthetic(name))) continue;
        
        final fileUri = typedefMirror.location?.sourceUri ?? uri;
        if (isNotBuiltIn && (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri))) {
          continue;
        }

        final content = await _readSourceCode(fileUri, isNotBuiltIn);
        if (isNotBuiltIn && content.value) {
          continue;
        }

        try {
          declarations.add(await generateTypedef(typedefMirror, package, uriString, fileUri));
        } catch (_) { }
      }

      // Process top-level functions and variables
      for (final declaration in library.declarations.values) {
        final name = mirrors.MirrorSystem.getName(declaration.simpleName);
        if (isNotBuiltIn && (isInternal(name) || isSynthetic(name))) continue;
        
        final fileUri = declaration.location?.sourceUri ?? uri;
        if (isNotBuiltIn && (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri))) {
          continue;
        }

        final content = await _readSourceCode(fileUri, isNotBuiltIn);
        if (isNotBuiltIn && content.value) {
          continue;
        }

        try {
          if (declaration is mirrors.MethodMirror && !declaration.isConstructor && !declaration.isAbstract) {
            declarations.add(await generateTopLevelMethod(declaration, package, uri, fileUri));
          } else if (declaration is mirrors.VariableMirror) {
            declarations.add(await generateTopLevelField(declaration, package, uri, fileUri, isBuiltIn));
          } else if (declaration is mirrors.TypeMirror) {
            final libraryElement = await getLibraryElement(uri);
            final element = libraryElement?.getTopLevelFunction(name);
            if (isReallyARecordType(declaration, element?.type)) {
              if (await generateRecordLinkDeclaration(declaration, package, uriString, element!.type) case final record?) {
                recordLinkDeclarations.add(record);
              }
            }
          }
        } catch (_) {}
      }

      return currentLibrary.copyWith(declarations: declarations, records: recordLinkDeclarations);
    });

    RuntimeBuilder.logLibraryVerboseInfo('Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}', trackWith: logMessage);
    return result.result;
  }

  /// Reads the source code for the file identified by [fileUri] and applies
  /// JetLeaf filtering rules to determine whether the file should be excluded
  /// from reflection.
  ///
  /// This method centralizes all logic related to source-file eligibility.
  /// It ensures that only valid, reflectable, non-skipped code units are passed
  /// to the deeper declaration-generation pipeline.
  ///
  /// ---
  /// ## 🧩 Behavior Overview
  ///
  /// ### 1. Built-In Library Optimization
  /// If the file does **not** belong to a built-in Dart library (`isNotBuiltIn == false`),
  /// the file is **not read from disk** since built-in libraries do not have
  /// accessible source code.  
  ///
  /// In this case, a successful response with `fileContent = null` is returned.
  ///
  /// ---
  /// ## 2. Attempt to Read the Source File
  /// If the file belongs to a user or third-party library (`isNotBuiltIn == true`):
  ///
  /// - The method reads the file's content via `readSourceCode(fileUri)`.
  /// - Any read failure (permissions, missing file, IO issues) is caught.
  /// - When reading fails, the method:
  ///   - logs the error through `onError`,
  ///   - returns a flag instructing JetLeaf to **skip processing the file**.
  ///
  /// This prevents filesystem errors from halting the reflection process.
  ///
  /// ---
  /// ## 3. File-Level Filtering Rules
  ///
  /// After reading the source code, the method applies several JetLeaf rules:
  ///
  /// ### 🔹 **Skip Tests**
  /// If the file appears to be a test file (determined by `isTest(content)`)
  /// **and** test scanning is disabled (`configuration.skipTests`),
  /// the file is excluded from reflection.
  ///
  /// ### 🔹 **Skip Mirror-Based Files**
  /// Any file that contains `dart:mirrors` imports is automatically excluded.
  /// This ensures JetLeaf does not attempt to reflect files that already rely on
  /// mirrors internally, which could cause conflicting behavior.
  ///
  /// ---
  /// ## 🧪 Return Value
  ///
  /// The method returns a [MapEntry] where:
  ///
  /// - **key** → `String?`  
  ///   - The raw source code string  
  ///   - `null` when the file is built-in or unreadable  
  ///
  /// - **value** → `bool`  
  ///   - `false` → The file is valid and safe to reflect  
  ///   - `true` → The file should be skipped entirely  
  ///
  /// This dual result allows callers to both:
  /// - use the source code (for modifier detection, mixin detection, etc.),
  /// - skip files early without attempting deeper reflection steps.
  ///
  /// ---
  /// ## 🧾 Summary
  ///
  /// `_readSourceCode` acts as the **gatekeeper** for reflection:
  ///
  /// - It reads source files safely.  
  /// - It guards against invalid, unreadable, or intentionally skipped files.  
  /// - It enforces global JetLeaf configuration.  
  ///
  /// By ensuring only valid inputs reach the declaration generator, it protects
  /// JetLeaf from reflection time errors and improves overall performance.
  Future<MapEntry<String?, bool>> _readSourceCode(Uri fileUri, bool isNotBuiltIn) async {
    String? fileContent;
    if (isNotBuiltIn) {
      try {
        fileContent = await readSourceCode(fileUri);
        if ((isTest(fileContent) && configuration.skipTests) || hasMirrorImport(fileContent)) {
          return MapEntry(null, true);
        }
      } catch (e) {
        RuntimeBuilder.logFullyVerboseError('Could not read file content for $fileUri: $e');
        return MapEntry(null, true);
      }

    }

    return MapEntry(fileContent, false);
  }
}