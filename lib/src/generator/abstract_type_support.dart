// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:io';
import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../annotations.dart';
import '../builder/runtime_builder.dart';
import '../classes.dart';
import '../declaration/declaration.dart';
import '../utils/constant.dart';
import '../utils/dart_type_resolver.dart';
import '../utils/generic_type_parser.dart';
import '../utils/reflection_utils.dart';
import '../utils/utils.dart';
import 'abstract_element_support.dart';
import 'library_generator.dart';

/// {@template abstract_type_support}
/// Base support class providing shared **type-resolution**, **caching**, and
/// **lookup utilities** for JetLeaf's declaration-generation pipeline.
/// 
/// `AbstractTypeSupport` builds on [AbstractElementSupport] by adding several
/// layers of caching and high-level type utilities used across JetLeaf's 
/// analyzer-integrated reflection system. It centralizes all reusable type-
/// related logic so subclasses—such as library generators, declaration 
/// processors, and metadata builders—can rely on consistent, efficient 
/// behavior.
///
/// ### Responsibilities
/// - Maintain caches for libraries, types, packages, type variables, analyzer
///   elements, and raw Dart types.
/// - Provide fast lookup during code generation to reduce analyzer overhead.
/// - Coordinate source-code access through caching layers.
/// - Serve as the foundational support class for all reflection-driven
///   type-resolution components.
///
/// ### Design Notes
/// - All caches are intentionally exposed as `final` fields to allow subclasses
///   direct read/write access.
/// - This class is not meant for general use. It is a JetLeaf internal
///   abstraction and therefore not part of the public API.
/// - All functionality in this class is reusable by subclasses via protected
///   methods inherited from [AbstractElementSupport].
/// {@endtemplate}
abstract class AbstractTypeSupport extends AbstractElementSupport {
  /// A cache mapping **library URI strings** to their resolved
  /// [LibraryDeclaration] instances.
  ///
  /// JetLeaf uses this cache to avoid regenerating declarations for libraries
  /// that have already been processed during the current build run.
  ///
  /// Keys are always the `.toString()` representation of the library URI.
  final Map<String, LibraryDeclaration> libraryCache = {};
  
  /// Cache storing resolved [Package] metadata keyed by package name.
  ///
  /// This allows JetLeaf to quickly determine package boundaries, dependencies,
  /// skip logic, and root-package behavior without repeatedly parsing
  /// configuration or scanning the filesystem.
  final Map<String, Package> packageCache = {};
  
  /// A string-keyed cache storing **source code text** for files that have been
  /// accessed during analysis.
  ///
  /// Keys are full URI strings.
  ///
  /// This cache prevents repeated disk reads when performing operations such as:
  /// - modifier detection (`sealed`, `base`, `final`, etc.)
  /// - annotation extraction
  /// - scanning for forbidden imports
  /// - test file detection
  final Map<String, String> _sourceCache = {};

  /// Creates a new instance of [AbstractTypeSupport].
  ///
  /// Subclasses must provide:
  /// - a [mirrors.MirrorSystem] used for mirror-based reflection,
  /// - any preloaded mirrors via [forceLoadedMirrors],
  /// - logging callbacks (`onInfo`, `onWarning`, `onError`),
  /// - the global JetLeaf [Configuration],
  /// - the list of recognized [packages].
  ///
  /// All caches are initialized empty and populated dynamically during
  /// declaration generation.
  /// 
  /// {@macro abstract_type_support}
  AbstractTypeSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  // ========================================== TYPE UTILITIES ==============================================

  /// Checks if the given [type] is a primitive Dart type.
  ///
  /// Recognized primitive types are:
  /// - `int`
  /// - `double`
  /// - `bool`
  /// - `String`
  /// - `num`
  ///
  /// - [type]: The `Type` object to check.
  /// - Returns: `true` if [type] is a primitive type, otherwise `false`.
  @protected
  bool isPrimitiveType(Type type) => type == int || type == double || type == bool || type == String || type == num;

  /// Checks if the given [type] is a `List` or a generic `List<T>`.
  ///
  /// This method inspects the string representation of [type] to detect both
  /// raw and generic `List` types.
  ///
  /// - [type]: The `Type` object to check.
  /// - Returns: `true` if [type] is `List` or `List<T>`, otherwise `false`.
  @protected
  bool isListType(Type type) => type.toString().startsWith('List<') || type == List;

  /// Checks if the given [type] is a `Map` or a generic `Map<K, V>`.
  ///
  /// This method inspects the string representation of [type] to detect both
  /// raw and generic `Map` types.
  ///
  /// - [type]: The `Type` object to check.
  /// - Returns: `true` if [type] is `Map` or `Map<K, V>`, otherwise `false`.
  @protected
  bool isMapType(Type type) => type.toString().startsWith('Map<') || type == Map;

  /// Checks if the given [type] represents a Dart record.
  ///
  /// A type is considered a record if its string representation starts with
  /// `'('` and ends with `')'`, e.g., `(int, String)`.
  ///
  /// - [type]: The `Type` object to check.
  /// - Returns: `true` if [type] is a record type, otherwise `false`.
  @protected
  bool isRecordType(Type type) => type.toString().startsWith('(') && type.toString().endsWith(')');

  /// Determines whether a given type truly represents a **Dart record type**.
  ///
  /// This helper performs a strict validation to distinguish real record types
  /// from similarly named or synthetic constructs. It combines runtime mirror
  /// inspection with analyzer metadata to ensure accurate detection.
  ///
  /// A type is considered a real record when:
  /// - The mirror’s simple name resolves to `"Record"`
  /// - The mirror has a reflected runtime type
  /// - The reflected type is exactly `Record`
  /// - An analyzer [AnalyzedTypeAnnotation] is available to confirm static type information
  ///
  /// ### Parameters
  /// - [mirror] — The runtime type mirror to inspect.
  /// - [package] — The package context for resolution (unused here, but kept
  ///   for signature consistency).
  /// - [libraryUri] — The declaring library URI (unused here, but kept for
  ///   signature consistency).
  /// - [dartType] — The analyzer type used to confirm record semantics.
  ///
  /// ### Returns
  /// `true` if the type is conclusively identified as a Dart record type;
  /// otherwise, `false`.
  @protected
  bool isReallyARecordType(mirrors.TypeMirror mirror, AnalyzedTypeAnnotation? dartType) 
    => ReflectionUtils.isThisARecord(mirror) && dartType != null;

  /// Determines the kind of a type based on its `dart:mirrors` [TypeMirror] 
  /// and optional analyzer [AnalyzedTypeAnnotation].
  ///
  /// This method classifies types into the following [TypeKind] categories:
  /// - `dynamicType`
  /// - `voidType`
  /// - `primitiveType`
  /// - `listType`
  /// - `mapType`
  /// - `recordType`
  /// - `classType`
  /// - `enumType`
  /// - `typedefType`
  /// - `functionType`
  /// - `unknownType`
  ///
  /// - [typeMirror]: The mirror representing the type at runtime.
  /// - [dartType]: Optional analyzer type information (can be `null`).
  /// - Returns: The corresponding [TypeKind] of the provided type.
  @protected
  TypeKind determineTypeKind(mirrors.TypeMirror typeMirror, AnalyzedTypeAnnotation? dartType) {
    if (typeMirror.runtimeType.toString() == 'dynamic') return TypeKind.dynamicType;
    if (typeMirror.runtimeType.toString() == 'void') return TypeKind.voidType;
    
    if (typeMirror is mirrors.ClassMirror) {
      if (typeMirror.isEnum) return TypeKind.enumType;
      final runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;
      if (isPrimitiveType(runtimeType)) return TypeKind.primitiveType;
      if (isListType(runtimeType)) return TypeKind.listType;
      if (isMapType(runtimeType)) return TypeKind.mapType;
      return TypeKind.classType;
    }
    
    if (typeMirror is mirrors.TypedefMirror) return TypeKind.typedefType;
    if (typeMirror is mirrors.FunctionTypeMirror) return TypeKind.functionType;
    
    return TypeKind.unknownType;
  }

  /// Builds a fully qualified name from a library URI and a type name.
  ///
  /// This method concatenates the [libraryUri] and [typeName] with a dot,
  /// ensuring that accidental double dots are replaced with a single dot.
  ///
  /// - [typeName]: The simple name of the type.
  /// - [libraryUri]: The URI of the library containing the type.
  /// - Returns: A canonical string representing the fully qualified type name.
  @protected
  String buildQualifiedName(String typeName, String libraryUri) {
    if (typeName == "void") {
      return Void.getQualifiedName();
    }

    if (typeName == "dynamic") {
      return Dynamic.getQualifiedName();
    }

    return ReflectionUtils.buildQualifiedName(typeName, libraryUri);
  }

  /// Checks if a [uri] points to a built-in Dart library.
  ///
  /// Built-in libraries have the `dart:` scheme, e.g., `dart:core`, `dart:io`.
  ///
  /// - [uri]: The URI to check.
  /// - Returns: `true` if the URI represents a built-in Dart library.
  @protected
  bool isBuiltInDartLibrary(Uri uri) => uri.scheme == 'dart';

  /// Determines if a given [name] is considered internal.
  ///
  /// A name is internal if the final segment (after the last slash, backslash,
  /// or colon) starts with a single underscore `_` but not a double underscore `__`.
  ///
  /// - [name]: The symbol or identifier to check.
  /// - Returns: `true` if the name is internal, otherwise `false`.
  @protected
  bool isInternal(String name) {
    // Find the last slash or colon
    final sepIndex = name.lastIndexOf(RegExp(r'[/\\:]'));
    final segment = sepIndex >= 0 ? name.substring(sepIndex + 1) : name;

    // Internal if segment starts with _ but not __
    return segment.startsWith('_') && !segment.startsWith('__');
  }

  /// Determines if a [name] is synthetic.
  ///
  /// Synthetic names are typically compiler-generated or framework-internal,
  /// such as names starting with double underscores `__` or containing `&`.
  ///
  /// - [name]: The name to check.
  /// - Returns: `true` if the name is synthetic, otherwise `false`.
  @protected
  bool isSynthetic(String name) => name.startsWith("__") || name.contains("&");

  /// Checks if a mirror type [name] represents a synthetic type.
  ///
  /// Common synthetic mirror types are compiler-generated placeholders
  /// like `X0`, `X1`, `X2`, etc.
  ///
  /// - [name]: The type name to inspect.
  /// - Returns: `true` if the name matches the synthetic pattern.
  @protected
  bool isMirrorSyntheticType(String name) {
    // Match X followed by digits (X0, X1, X2, etc.)
    return RegExp(r'^X\d+$').hasMatch(name);
  }

  /// Infers the variance of a type parameter from a mirrors [TypeVariableMirror] context.
  ///
  /// Currently always returns [TypeVariance.invariant] as Dart mirrors do not
  /// provide variance information.
  ///
  /// - [typeMirror]: The mirrors type variable to inspect.
  /// - Returns: The inferred [TypeVariance], defaults to invariant.
  @protected
  TypeVariance inferVarianceFromMirror(mirrors.TypeVariableMirror typeMirror) {
    return TypeVariance.invariant;
  }

  /// Resolves or creates a [LibraryDeclaration] for the given library [uri].
  ///
  /// This method serves as the **central library resolution entry point** for
  /// the JetLeaf build and reflection pipeline. It attempts to locate an existing
  /// library declaration first and falls back to **synthetic library generation**
  /// when no source-backed declaration is available.
  ///
  /// ## Resolution Strategy
  /// The method resolves libraries in the following order:
  ///
  /// ### 1. Cached lookup
  /// If a library for the given [uri] already exists in the internal cache,
  /// the cached [LibraryDeclaration] is returned immediately.
  ///
  /// ### 2. Known library generation
  /// If the URI corresponds to a discovered library element (for example,
  /// from the analyzer or build system), the method delegates to
  /// [generateLibrary] to produce a fully populated declaration.
  ///
  /// ### 3. Synthetic fallback
  /// If no matching library can be found, a **synthetic**
  /// [StandardLibraryDeclaration] is created with:
  /// - No backing analyzer element
  /// - An inferred or default package
  /// - Empty declarations and record links
  /// - Visibility and synthetic flags derived from the URI
  ///
  /// This ensures that **all referenced URIs resolve to a library**, even if
  /// they are external, missing, or dynamically introduced.
  ///
  /// ## Caching Behavior
  /// - Newly generated or synthetic libraries are stored in the internal cache
  ///   keyed by their URI string.
  /// - Subsequent calls with the same [uri] will return the cached instance.
  ///
  /// ## Parameters
  /// - `uri`: The library URI string (e.g. `dart:core`, `package:my_app/foo.dart`)
  ///
  /// ## Returns
  /// A [Future] that completes with a resolved [LibraryDeclaration].
  ///
  /// ## Guarantees
  /// - This method never returns `null`.
  /// - A library declaration is always produced, even if it is synthetic.
  /// - Returned libraries are safe to use in downstream reflection,
  ///   linking, and code-generation pipelines.
  ///
  /// ## Typical Usage
  /// ```dart
  /// final lib = await libraryResolver.getLibrary('package:my_app/models.dart');
  ///
  /// print(lib.uri);        // → package:my_app/models.dart
  /// print(lib.isSynthetic); // → false (if source-backed)
  /// ```
  ///
  /// ## Notes
  /// - Synthetic libraries are commonly used for:
  ///   - External dependencies
  ///   - Generated code
  ///   - Unresolved or late-bound references
  /// - Public/internal visibility is inferred from the URI structure.
  Future<LibraryDeclaration> getLibrary(String uri) async {
    if (libraryCache[uri] case final cache?) {
      return cache;
    }

    if (getLibraries().where((lib) => lib.uri == Uri.parse(uri)).firstOrNull case final library?) {
      return await generateLibrary(library);
    }

    final library = StandardLibraryDeclaration(
      uri: uri.toString(),
      parentPackage: createDefaultPackage(getPackageNameFromUri(uri) ?? "Unknown"),
      declarations: [],
      recordLinkDeclarations: [],
      isPublic: !isInternal(uri.toString()),
      isSynthetic: isSynthetic(uri.toString()),
      annotations: [],
      sourceLocation: Uri.parse(uri),
    );

    libraryCache[uri] = library;
    return library;
  }

  @override
  Future<String> readSourceCode(Object uri) async {
    if (uri case Uri uri) {
      try {
        if (_sourceCache.containsKey(uri.toString())) {
          return _sourceCache[uri.toString()]!;
        }

        final filePath = (await resolveUri(uri) ?? uri).toFilePath();
        String fileContent = await File(filePath).readAsString();
        _sourceCache[uri.toString()] = fileContent;
        return RuntimeUtils.stripComments(fileContent);
      } catch (_) { }
    } else if(uri case String uri) {
      return await readSourceCode(Uri.parse(uri));
    }

    return "";
  }

  /// Returns the package URI for a given [typeName] and [actualType].
  ///
  /// - Recognizes built-in Dart types such as `int`, `List`, `Map`, `Future`, etc.
  /// - Defaults to `dart:core` for unknown types.
  /// - For async types like [Future] and [Stream], returns `dart:async`.
  ///
  /// - [typeName]: The name of the type (not currently used in logic).
  /// - [actualType]: The runtime type to inspect.
  /// - Returns: A string representing the package URI.
  @protected
  String getPackageUriForType(String typeName, Type actualType) {
    // Check if it's a built-in Dart type
    if (isPrimitiveType(actualType) || 
        actualType == List || actualType == Map || actualType == Set || 
        actualType == Iterable || actualType == Future || actualType == Stream) {
      return 'dart:core';
    }
    
    // For async types
    if (actualType == Future || actualType == Stream) {
      return 'dart:async';
    }
    
    // Default fallback
    return 'dart:core';
  }

  /// Creates a default [Package] instance with placeholder values.
  ///
  /// - [name]: The name of the package.
  /// - Returns: A new [PackageImplementation] with default metadata.
  @protected
  Package createDefaultPackage(String name) {
    return PackageImplementation(
      name: name,
      version: '0.0.0',
      languageVersion: null,
      isRootPackage: false,
      rootUri: null,
      filePath: null,
    );
  }

  /// Creates a built-in Dart SDK [Package] instance.
  ///
  /// - Uses the root package version and language version from the cached packages
  ///   if available, defaults to Dart 3.0.
  /// - Sets `rootUri` to `dart:core`.
  ///
  /// - Returns: A [PackageImplementation] representing the Dart SDK.
  @protected
  Package createBuiltInPackage() {
    return PackageImplementation(
      name: Constant.DART_PACKAGE_NAME,
      version: packageCache.values.where((v) => v.getIsRootPackage()).firstOrNull?.getLanguageVersion() ?? '3.0',
      languageVersion: packageCache.values.where((v) => v.getIsRootPackage()).firstOrNull?.getLanguageVersion() ?? '3.0',
      isRootPackage: false,
      rootUri: 'dart:core',
      filePath: null,
    );
  }

  /// Splits a record type content string into individual components.
  ///
  /// - Handles nested generics, tuples, and record types by keeping track of
  ///   bracket depth to avoid splitting inside nested structures.
  /// - For example: `(int, List<String>, Map<String, int>)` → [`int`, `List<String>`, `Map<String, int>`]
  ///
  /// - [content]: The string representation of a record's content.
  /// - Returns: A list of component strings.
  @protected
  List<String> splitRecordContent(String content) {
    final parts = <String>[];
    int balance = 0;
    int start = 0;
    
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '<' || char == '(' || char == '{') {
        balance++;
      } else if (char == '>' || char == ')' || char == '}') {
        balance--;
      } else if (char == ',' && balance == 0) {
        parts.add(content.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(content.substring(start));
    return parts;
  }

  /// Returns `true` if the given [className] is declared as a `sealed class`
  /// in the provided [sourceCode].
  ///
  /// Example:
  /// ```dart
  /// isSealedClass('sealed class MyClass {}', 'MyClass'); // true
  /// ```
  @protected
  bool isSealedClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bsealed\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  /// Returns `true` if the given [className] is declared as a `base class`
  /// in the provided [sourceCode].
  ///
  /// Example:
  /// ```dart
  /// isBaseClass('base class MyBase {}', 'MyBase'); // true
  /// ```
  @protected
  bool isBaseClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bbase\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  /// Returns `true` if the given [className] is declared as a `final class`
  /// in the provided [sourceCode].
  ///
  /// Example:
  /// ```dart
  /// isFinalClass('final class MyFinal {}', 'MyFinal'); // true
  /// ```
  @protected
  bool isFinalClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bfinal\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  /// Returns `true` if the given [className] is declared as an `interface class`
  /// in the provided [sourceCode].
  ///
  /// Example:
  /// ```dart
  /// isInterfaceClass('interface class MyInterface {}', 'MyInterface'); // true
  /// ```
  @protected
  bool isInterfaceClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\binterface\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  /// Checks whether the given [className] is declared as a `mixin` or `mixin class`
  /// in the provided Dart [sourceCode].
  ///
  /// This method supports both:
  /// - The `mixin class MyMixin {}` syntax (Dart 3+)
  /// - The classic `mixin MyMixin {}` syntax
  ///
  /// Returns `true` if either pattern is found; otherwise, `false`.
  ///
  /// Example:
  /// ```dart
  /// isMixinClass('mixin class MyMixin {}', 'MyMixin'); // true
  /// isMixinClass('mixin MyMixin {}', 'MyMixin');       // true
  /// isMixinClass('class MyMixin {}', 'MyMixin');       // false
  /// ```
  @protected
  bool isMixinClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern1 = RegExp(r'\bmixin\s+class\s+' + RegExp.escape(className) + r'\b');
    final pattern2 = RegExp(r'\bmixin\s+' + RegExp.escape(className) + r'\b');

    return pattern1.hasMatch(sourceCode) || pattern2.hasMatch(sourceCode);
  }

  /// Returns `true` if the field named [fieldName] is declared with `late`
  /// in the provided [sourceCode].
  ///
  /// This detects both instance and static fields.
  ///
  /// Example:
  /// ```dart
  /// isLateField('late final String user', 'user'); // true
  /// ```
  @protected
  bool isLateField(String? sourceCode, String fieldName) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\blate\s+[^;]*\b' + RegExp.escape(fieldName) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  /// Determines if a field is nullable either from analyzer [FieldElement] or source code.
  ///
  /// Checks nullability in multiple ways:
  /// - If [field] is provided, checks the Dart analyzer type's nullability suffix.
  /// - If [sourceCode] is provided, uses regular expressions to detect `?` in type declarations.
  /// 
  /// Supports:
  /// - Optional `late`, `static`, `final`, or `const` modifiers
  /// - Nullable parameters in constructors
  /// - `this.fieldName` syntax in parameter lists
  ///
  /// - [field]: Optional analyzer field element to inspect nullability directly.
  /// - [sourceCode]: Optional Dart source code as string.
  /// - [fieldName]: The field name to check.
  /// - Returns: `true` if the field is nullable, `false` otherwise.
  @protected
  bool isNullable({AnalyzedFieldDeclaration? field, String? sourceCode, required String fieldName}) {
    if (field != null) {
      final t = field.fields.type;
      return checkTypeAnnotationNullable(t);
    }

    if (sourceCode == null) return false;
    final code = RuntimeUtils.stripComments(sourceCode);

    // Patterns WITHOUT inline (?m) flags; use multiLine: true below.
    final List<RegExp> patterns = [
      // field declarations: optional 'late/static/final/const', then a type that contains '?', then the name
      RegExp(
        r'\b(?:late\s+)?(?:static\s+)?(?:final\s+|const\s+)?[A-Za-z_$][A-Za-z0-9_$<>\?,\s]*\?\s+' +
            RegExp.escape(fieldName) +
            r'\b',
        multiLine: true,
      ),

      // constructor or parameter with explicit nullable type: 'Foo? name' (positional or named)
      RegExp(
        r'\b[A-Za-z_$][A-Za-z0-9_$<>\?,\s]*\?\s+' + RegExp.escape(fieldName) + r'\b',
        multiLine: true,
      ),

      // heuristic for 'this.name' in parameter lists where the param token includes a '?'
      RegExp(
        r'[(,][^)]{0,120}\b[A-Za-z_$][A-Za-z0-9_$<>\?,\s]*\?\s*(?:this\.)?' +
            RegExp.escape(fieldName) +
            r'\b',
        multiLine: true,
      ),
    ];

    return patterns.any((p) => p.hasMatch(code));
  }

  /// Attempts to obtain the original runtime [Type] of a class from a mirrors [ClassMirror].
  ///
  /// - If the mirror represents the original declaration, retrieves the reflected type.
  /// - Checks for `@Generic` annotations and resolves the type accordingly.
  /// - Otherwise, falls back to the reflected or runtime type.
  ///
  /// - [mirror]: The class mirror to inspect.
  /// - [package]: The package context for resolving annotations.
  /// - Returns: The resolved [Type] of the class.
  @protected
  Future<Type> tryAndGetOriginalType(mirrors.ClassMirror mirror, String libraryUri, Uri sourceUri, Package package) async {
    if (mirror.isOriginalDeclaration) {
      Type type = mirror.hasReflectedType ? mirror.reflectedType : mirror.runtimeType;
      String name = mirrors.MirrorSystem.getName(mirror.simpleName);
      
      if(GenericTypeParser.shouldCheckGeneric(type)) {
        final annotations = await extractAnnotations(mirror.metadata, libraryUri, sourceUri, package, []);
        final resolvedType = await resolveTypeFromGenericAnnotation(annotations, name) ?? resolvePublicDartType(libraryUri, name, mirror);
        if (resolvedType != null) {
          type = resolvedType;
        }
      }
      
      return type;
    }
    
    return mirror.hasReflectedType ? mirror.reflectedType : mirror.runtimeType;
  }

  /// Resolves a Dart [Type] from `@Generic` annotations on a class or field.
  ///
  /// - Warns if multiple `@Generic` annotations are present, selecting the first resolvable one.
  /// - Extracts the `_type` field from the annotation to determine the actual type.
  ///
  /// - [annotations]: List of annotation declarations to inspect.
  /// - [name]: The name of the class or field being resolved.
  /// - Returns: The resolved [Type] if found, otherwise `null`.
  @protected
  Future<Type?> resolveTypeFromGenericAnnotation(List<AnnotationDeclaration> annotations, String name) async {
    if(annotations.where((a) => a.getLinkDeclaration().getType() == Generic).length > 1) {
      RuntimeBuilder.logFullyVerboseWarning("Multiple @Generic annotations found for $name. Jetleaf will resolve to the first one it can get.");
    }

    Type? type;
    final generic = annotations.where((a) => a.getLinkDeclaration().getType() == Generic || a.getType() == Generic).firstOrNull;
    
    if (generic != null) {
      final typeField = generic.getField(Generic.FIELD_NAME);
      type = typeField?.getValue() as Type?;
    }

    if (generic?.getInstance() case Generic generic?) {
      type ??= generic.getType();
    }
    
    return type;
  }

  /// Resolves **@Generic annotations** on a runtime type if present.
  ///
  /// JetLeaf uses @Generic annotations to materialize runtime types for
  /// parameterized classes. This method ensures that the resolved runtime type
  /// reflects any explicitly declared generic binding.
  ///
  /// Resolution steps:
  /// 1. Check if the runtime type should be inspected for generics using
  ///    [GenericTypeParser.shouldCheckGeneric].
  /// 2. Extract annotations from the mirror metadata.
  /// 3. Attempt to resolve a concrete type from any @Generic annotation.
  /// 4. Fallback to public Dart type resolution if annotation resolution fails.
  ///
  /// ### Parameters
  /// - [runtimeType] — The original runtime type obtained from the mirror.
  /// - [mirror] — The mirror used to extract annotations.
  /// - [package] — Package context for annotation resolution.
  /// - [libraryUri] — Library URI of the type.
  /// - [sourceUri] — Source file URI for reference.
  /// - [typeName] — Name of the type being resolved.
  ///
  /// ### Returns
  /// The resolved runtime type, or the original [runtimeType] if resolution
  /// fails.
  Future<Type> resolveGenericAnnotationIfNeeded(Type runtimeType, mirrors.TypeMirror mirror, Package package, String libraryUri, Uri sourceUri, String typeName) async {
    if (runtimeType.toString() == "_TypeVariableMirror") {
      return Object;
    }
    
    if (!GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      return runtimeType;
    }

    try {
      // Try mirror annotations first
      final annotations = await extractAnnotations(mirror.metadata, libraryUri, sourceUri, package);
      Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, typeName);
      
      // Fallback to AnalyzedTypeAnnotation resolution
      resolvedType ??= resolvePublicDartType(libraryUri, typeName, mirror);
      
      return resolvedType ?? (typeName == "void" ? Void : runtimeType);
    } catch (e) {
      return typeName == "void" ? Void : runtimeType;
    }
  }

  /// Retrieves the package URI for a given [mirror].
  ///
  /// - Uses [findRealClassUriFromMirror] to attempt locating the original class URI.
  /// - Falls back to [mirror.location?.sourceUri] if available.
  /// - Defaults to the provided [libraryUri] if no other URI is found.
  ///
  /// - [mirror]: The class mirror to inspect.
  /// - [packageName]: The name of the package containing the class.
  /// - [libraryUri]: The library URI to use as fallback.
  /// - Returns: A string representing the resolved package URI.
  @protected
  Future<String> getPkgUri(mirrors.TypeMirror mirror, String packageName, String libraryUri) async {
    final realClassUri = await findRealClassUriFromMirror(mirror, packageName);
    return mirror.location?.sourceUri.toString() ?? realClassUri ?? libraryUri;
  }

  /// Finds the real URI of a class by searching through known libraries.
  ///
  /// This method attempts to locate the library URI where the class is defined,
  /// using multiple strategies:
  /// 1. If a `hintUri` is provided, it checks that library first.
  /// 2. Falls back to scanning all loaded libraries in the mirror system.
  ///
  /// - [className]: The name of the class, mixin, or enum to locate.
  /// - [hintUri]: Optional URI hint where the class may be declared.
  /// - Returns: The URI string of the library containing the class, or `null` if not found.
  @protected
  Future<String?> findRealClassUri(String className, String? hintUri) async {
    // Search through mirror system
    for (final libraryMirror in getLibraries()) {
      for (final declaration in libraryMirror.declarations.values) {
        final mirrorClassName = mirrors.MirrorSystem.getName(declaration.simpleName);
        if (mirrorClassName == className && Symbol(className) == declaration.simpleName) {
          return await findRealClassUriFromMirror(declaration, null) ?? libraryMirror.uri.toString();
        }
      }
    }

    return null;
  }

  /// Finds the real URI of a class from a [mirrors.TypeMirror], optionally scoped by package.
  ///
  /// This method attempts several strategies to determine the authoritative library URI:
  /// 1. If the mirror is a [mirrors.ClassMirror], returns its owner library URI or the
  ///    URI of its original declaration.
  /// 2. Falls back to scanning all loaded mirrors for matching class names.
  /// 3. Prioritizes libraries in the specified root package, then non-SDK libraries,
  ///    then the first candidate.
  ///
  /// - [typeMirror]: The class or type mirror to locate.
  /// - [packageName]: Optional package name to prioritize matches.
  /// - Returns: The URI string of the library containing the type, or `null` if not found.
  @protected
  Future<String?> findRealClassUriFromMirror(mirrors.DeclarationMirror typeMirror, String? packageName) async {
    // 1) If this is a class mirror, the declaring library is the authoritative source. dart:core/function.dart.Function
    try {
      if (typeMirror.location?.sourceUri.toString() case final uri?) {
        return uri;
      }

      if (typeMirror.owner?.location?.sourceUri.toString() case final uri?) {
        return uri;
      }

      if (typeMirror.owner?.location?.sourceUri.toString() case final uri?) {
        return uri;
      }

      if (typeMirror is mirrors.TypeMirror) {
        return await findRealClassUriFromMirror(typeMirror.originalDeclaration, packageName);
      }
    } catch (_) {
      // ignore and fall back to search
    }

    // 2) Fall back to scanning loaded libraries (mirrorSystem.libraries). Prefer root package.
    final nameToMatch = mirrors.MirrorSystem.getName(typeMirror.simpleName);

    for (final lib in getLibraries()) {
      if (lib.declarations[typeMirror.simpleName] case final declaration?) {
        return await findRealClassUriFromMirror(declaration, packageName) ?? lib.uri.toString();
      }

      // If not directly declared under that symbol, try a best-effort name match:
      try {
        for (final d in lib.declarations.values) {
          final dName = mirrors.MirrorSystem.getName(d.simpleName);
          if (dName == nameToMatch && d.simpleName == typeMirror.simpleName) {
            return await findRealClassUriFromMirror(d, packageName) ?? lib.uri.toString();
          }
        }
      } catch (_) {}
    }
    
    // last fallback: first candidate
    return null;
  }

  /// Resolves a runtime [mirrors.TypeMirror] from an analyzer [AnalyzedTypeAnnotation].
  ///
  /// This helper bridges the analyzer and reflection worlds by:
  /// - Resolving the concrete runtime [Type] associated with [dartType]
  /// - Reflecting that runtime type into a [mirrors.TypeMirror]
  ///
  /// It is primarily used during record-field processing to enable
  /// reflection-based extraction of type metadata that is not available
  /// directly from analyzer structures.
  ///
  /// ### Parameters
  /// - [dartType] — The analyzer type to resolve.
  /// - [package] — The package context used for lookup.
  /// - [libraryUri] — The URI of the declaring library.
  ///
  /// ### Returns
  /// A [Future] that completes with the corresponding [mirrors.TypeMirror].
  Future<mirrors.TypeMirror> getMirroredTypeAnnotation(AnalyzedTypeAnnotation dartType, Package package, String libraryUri) async {
    final type = await findRuntimeTypeFromDartType(dartType, libraryUri, package);
    return mirrors.reflectType(type);
  }

  /// Resolves the runtime [Type] corresponding to a given [AnalyzedTypeAnnotation].
  ///
  /// This method attempts multiple strategies to determine the actual runtime
  /// type of a Dart element:
  /// 1. Checks for built-in core and async types (e.g., `int`, `List`, `Future`).
  /// 2. Uses a cached mapping (`dartTypeToTypeCache`) to avoid repeated resolution.
  /// 3. Attempts to resolve the type using the analyzer element and library URI.
  /// 4. Searches through all loaded libraries in the mirror system to find a matching class.
  /// 5. Falls back to `Object` or the element's runtime type if no match is found.
  ///
  /// - [dartType]: The analyzer [AnalyzedTypeAnnotation] to resolve.
  /// - [defaultLibraryUri]: The URI of the library where the type is defined (used for resolution).
  /// - [package]: The package context for type resolution.
  /// - Returns: The resolved runtime [Type].
  @protected
  Future<Type> findRuntimeTypeFromDartType(AnalyzedTypeAnnotation dartType, String defaultLibraryUri, Package package) async {
    // Try to resolve from dart type resolver
    final elementName = getNameFromAnalyzedTypeAnnotation(dartType);

    // Try to find the type in our mirror system
    // Look through all libraries to find a matching class
    for (final libraryMirror in getLibraries()) {
      if (libraryMirror.location?.sourceUri.toString() == defaultLibraryUri) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName && declaration.simpleName == Symbol(elementName)) {
              try {
                return await tryAndGetOriginalType(declaration, defaultLibraryUri, Uri.parse(defaultLibraryUri), package);
              } catch (e) {
                // Continue searching
              }
            }
          }
        }
      }
    }
    
    return Object;
  }

  /// Resolves the base runtime [Type] from a [AnalyzedTypeAnnotation], ignoring type parameters.
  ///
  /// This method is similar to [findRuntimeTypeFromDartType] but focuses on
  /// retrieving the non-parameterized, “raw” type of the element.  
  /// It is useful when generics or type arguments should be ignored.
  ///
  /// Resolution steps:
  /// 1. Checks for built-in types (core and async).
  /// 2. Searches the mirror system for the base class corresponding to the [AnalyzedTypeAnnotation].
  /// 3. Falls back to [findRuntimeTypeFromDartType] if no base class is found.
  ///
  /// - [dartType]: The analyzer [AnalyzedTypeAnnotation] to resolve.
  /// - [libraryUri]: The URI of the library where the type is defined.
  /// - [package]: The package context for type resolution.
  /// - Returns: The base runtime [Type].
  @protected
  Future<Type> findBaseRuntimeTypeFromDartType(AnalyzedTypeAnnotation dartType, String libraryUri, Package package) async {
    // For parameterized types, find the base class
    final elementName = getNameFromAnalyzedTypeAnnotation(dartType);
    // Look through all libraries to find the base class
    for (final libraryMirror in getLibraries()) {
      if (libraryMirror.location?.sourceUri.toString() == libraryUri) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName && declaration.simpleName == Symbol(elementName)) {
              try {
                return await tryAndGetOriginalType(declaration, libraryUri, Uri.parse(libraryUri), package);
              } catch (e) {
                // Continue searching
              }
            }
          }
        }
      }
      }

    // Fallback to the actual runtime type
    return await findRuntimeTypeFromDartType(dartType, libraryUri, package);
  }

  /// Attempts to resolve the **class name** associated with a given [AnalyzedTypeAnnotation]
  /// within a specific Dart library.
  ///
  /// This utility bridges static analyzer types ([AnalyzedTypeAnnotation]) with runtime
  /// reflection metadata ([mirrors.ClassMirror]). It searches for a class
  /// declaration in the loaded mirror system whose name matches the element
  /// associated with the provided [dartType], but **only within the library
  /// identified by** [libraryUri].
  ///
  /// ### Behavior
  /// - Extracts the element name from the analyzer’s [AnalyzedTypeAnnotation].
  /// - Scans all libraries known to the mirror system.
  /// - Identifies the library whose `sourceUri` matches [libraryUri].
  /// - Searches that library’s declarations for a matching class name.
  ///
  /// ### Returns
  /// - The resolved class name as a `String` if found.
  /// - `null` if the class does not exist in the specified library or if the
  ///   [dartType] has no associated element.
  ///
  /// ### Typical Use Cases
  /// - Mapping analyzer types to runtime mirror classes
  /// - Cross-referencing compile-time and runtime type systems
  /// - Supporting reflection-driven code generation or dynamic loading
  ///
  /// ### Example
  /// ```dart
  /// final name = await getClassNameFromDartType(type, 'package:my_pkg/src/file.dart');
  /// if (name != null) {
  ///   print('Resolved class: $name');
  /// }
  /// ```
  ///
  /// ### Parameters
  /// - [dartType]: The static analyzer type whose class name is being resolved.
  /// - [libraryUri]: The URI of the library where the class is expected to exist.
  ///
  /// ### Notes
  /// - This function only checks the **specified** library.  
  /// - Resolution may fail for synthetic, anonymous, or inferred types.
  Future<String?> getClassNameFromDartType(AnalyzedTypeAnnotation dartType, String libraryUri) async {
    final elementName = getNameFromAnalyzedTypeAnnotation(dartType);
    // Look through all libraries to find the base class
    for (final libraryMirror in getLibraries()) {
      if (libraryMirror.location?.sourceUri.toString() == libraryUri) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName && declaration.simpleName == Symbol(elementName)) {
              return className;
            }
          }
        }
      }
    }

    return null;
  }

  /// Extracts annotations from a list of [mirrors.InstanceMirror] metadata.
  ///
  /// Subclasses must implement this method to convert Dart mirrors metadata
  /// into JetLeaf [AnnotationDeclaration]s, taking package context into account.
  ///
  /// - [metadata]: The list of mirrors metadata for a class, field, or type.
  /// - [package]: The package context for resolving annotation types.
  /// - Returns: A list of [AnnotationDeclaration] representing the extracted annotations.
  @protected
  Future<List<AnnotationDeclaration>> extractAnnotations(List<mirrors.InstanceMirror> metadata, String libraryUri, Uri sourceUri, Package package, [List<AnalyzedAnnotation>? analyzerAnnotations]);

  /// Generates a full [LibraryDeclaration] for a runtime-reflected
  /// [mirrors.LibraryMirror], integrating both runtime reflection and static
  /// analyzer metadata, and applying all JetLeaf configuration rules.
  ///
  /// This is the **top-level entry point** for library-level generation and
  /// represents the final orchestration step in the JetLeaf reflection pipeline.
  ///
  /// ---
  /// ## 🧩 Responsibilities
  ///
  /// ### 1. Cache Reset & Initialization
  /// Clears all processing caches so each library is generated in isolation,
  /// ensuring consistency and preventing cross-library contamination.
  ///
  /// ### 2. Analyzer Integration
  /// Loads the corresponding `LibraryElement` for the library's URI, enabling:
  /// - resolved types,
  /// - static annotations,
  /// - visibility modifiers,
  /// - full AST metadata.
  ///
  /// ### 3. Package Resolution
  /// Determines the parent [Package] via `_getPackage()`, allowing the library
  /// to be grouped under the correct JetLeaf package context.
  ///
  /// ### 4. Creation of the Initial Library Declaration
  /// Builds a `StandardLibraryDeclaration` with:
  /// - URI  
  /// - analyzer element  
  /// - parent package  
  /// - initial empty declaration list  
  /// - source location  
  /// - visibility, synthetic, and annotation metadata  
  ///
  /// The declaration is added to `libraryCache` for immediate lookup and
  /// cross-link support.
  ///
  /// ---
  /// ## 📦 5. Discovery & Generation of Declarations
  ///
  /// The method iterates over `library.declarations.values` and classifies each
  /// member into one of the following:
  ///
  /// ### 🔧 A. Classes, Mixins, Enums
  /// For each `ClassMirror`:
  /// - Resolves the class element  
  /// - Applies filtering rules (internal/synthetic/skip-package/test skipping)  
  /// - Reads source code to detect mixins, mirror imports, test files, etc.  
  /// - Handles @Generic-resolution via `GenericTypeParser`  
  ///
  /// Depending on the classification, one of the following is invoked:
  /// - `generateClass()`  
  /// - `generateMixin()`  
  /// - `generateEnum()`  
  ///
  /// Each returns a fully assembled `SourceDeclaration` which is appended to
  /// the library’s declaration list.
  ///
  /// ### 🔧 B. Typedefs
  /// Extracts typedef declarations via:
  /// - `generateTypedef()`
  ///
  /// ### 🔧 C. Top-Level Functions & Variables
  /// Using:
  /// - `generateTopLevelMethod()`  
  /// - `generateTopLevelField()`  
  ///
  /// Only non-internal, non-synthetic, non-abstract members are included.
  ///
  /// ---
  /// ## 🛡️ Filtering & Safety Mechanisms
  ///
  /// Several layers of filtering prevent generating invalid or undesirable
  /// declarations:
  ///
  /// - **skipTests**: excludes any file considered a test when enabled  
  /// - **skip mirror imports**: avoids reflecting mirror-dependent files  
  /// - **excludeClasses** & **scanClasses** configurations  
  /// - **package guardrails** through `isSkippableJetLeafPackage()`  
  /// - **internal/synthetic rules** for names and URIs  
  ///
  /// All transformation steps are wrapped in defensive try/catch blocks to
  /// ensure that reflection cannot crash the application.
  ///
  /// ---
  /// ## 🔁 Finalization
  ///
  /// Returns an updated `LibraryDeclaration` containing:
  /// - all discovered classes, mixins, enums  
  /// - typedefs  
  /// - top-level functions and fields  
  /// - merged analyzer + runtime annotations  
  ///
  /// This object represents the authoritative, complete model of the library
  /// within the JetLeaf reflection environment.
  ///
  /// ---
  /// ## Returns
  /// A fully assembled and validated [LibraryDeclaration] representing all
  /// public, non-skipped, non-internal declarations found in the provided
  /// [mirrors.LibraryMirror].
  @protected
  Future<LibraryDeclaration> generateLibrary(mirrors.LibraryMirror library);

  @override
  Future<void> cleanup() async {
    await super.cleanup();
    
    libraryCache.clear();
    packageCache.clear();
    _sourceCache.clear();
  }
}