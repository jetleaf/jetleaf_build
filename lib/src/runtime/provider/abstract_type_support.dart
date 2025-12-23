// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:io';
import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../annotations.dart';
import '../../builder/runtime_builder.dart';
import '../../classes.dart';
import '../declaration/declaration.dart';
import '../../utils/constant.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import '../../utils/reflection_utils.dart';
import '../../utils/utils.dart';
import 'abstract_material_library_analyzer_support.dart';

/// {@template abstract_type_support}
/// Base support class providing shared **type-resolution**, **caching**, and
/// **lookup utilities** for JetLeaf's declaration-generation pipeline.
/// 
/// `AbstractTypeSupport` builds on [AbstractMaterialLibraryAnalyzerSupport] by adding several
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
///   methods inherited from [AbstractMaterialLibraryAnalyzerSupport].
/// {@endtemplate}
abstract class AbstractTypeSupport extends AbstractMaterialLibraryAnalyzerSupport {
  /// {@macro abstract_type_support}
  AbstractTypeSupport();

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

  /// Returns the package URI for a given [typeName] and [actualType].
  ///
  /// - Recognizes built-in Dart types such as `int`, `List`, `Map`, `Future`, etc.
  /// - Defaults to `dart:core` for unknown types.
  /// - For types like [Future] and [Stream], returns `dart`.
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
    
    // For types
    if (actualType == Future || actualType == Stream) {
      return 'dart';
    }
    
    // Default fallback
    return 'dart:core';
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
  Type tryAndGetOriginalType(mirrors.ClassMirror mirror, String libraryUri, Uri sourceUri) {
    if (mirror.isOriginalDeclaration) {
      Type type = mirror.hasReflectedType ? mirror.reflectedType : mirror.runtimeType;
      String name = mirrors.MirrorSystem.getName(mirror.simpleName);
      
      if(GenericTypeParser.shouldCheckGeneric(type)) {
        final annotations = extractAnnotations(mirror.metadata, libraryUri, sourceUri, []);
        final resolvedType = resolveTypeFromGenericAnnotation(annotations, name) ?? resolvePublicDartType(libraryUri, name, mirror);
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
  Type? resolveTypeFromGenericAnnotation(List<AnnotationDeclaration> annotations, String name) {
    if(annotations.where((a) => a.getLinkDeclaration().getType() == Generic).length > 1) {
      RuntimeBuilder.logFullyVerboseWarning("Multiple @Generic annotations found for $name. Jetleaf will resolve to the first one it can get.");
    }

    Type? type;
    final generic = annotations.where((a) => a.getLinkDeclaration().getType() == Generic || a.getType() == Generic).firstOrNull;
    
    if (generic != null) {
      final typeField = generic.getField(Generic.FIELD_NAME);
      type = typeField?.getValue(Object()) as Type?;
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
  /// - [type] — The original runtime type obtained from the mirror.
  /// - [mirror] — The mirror used to extract annotations.
  /// - [package] — Package context for annotation resolution.
  /// - [libraryUri] — Library URI of the type.
  /// - [sourceUri] — Source file URI for reference.
  /// - [typeName] — Name of the type being resolved.
  ///
  /// ### Returns
  /// The resolved runtime type, or the original [type] if resolution
  /// fails.
  Type resolveGenericAnnotationIfNeeded(Type type, mirrors.TypeMirror mirror, String libraryUri, Uri sourceUri, String typeName) {
    if (type.toString() == "_TypeVariableMirror") {
      return Object;
    }
    
    if (!GenericTypeParser.shouldCheckGeneric(type)) {
      return type;
    }

    try {
      // Try mirror annotations first
      final annotations = extractAnnotations(mirror.metadata, libraryUri, sourceUri);
      Type? resolvedType = resolveTypeFromGenericAnnotation(annotations, typeName);
      
      // Fallback to AnalyzedTypeAnnotation resolution
      resolvedType ??= resolvePublicDartType(libraryUri, typeName, mirror);
      
      return resolvedType ?? (typeName == "void" ? Void : type);
    } catch (e) {
      return typeName == "void" ? Void : type;
    }
  }

  /// Retrieves the package URI for a given [mirror].
  ///
  /// - Uses [findRealClassUriFromMirror] to attempt locating the original class URI.
  /// - Falls back to [mirror.location?.sourceUri] if available.
  /// - Defaults to the provided [libraryUri] if no other URI is found.
  ///
  /// - [mirror]: The class mirror to inspect.
  /// - [libraryUri]: The library URI to use as fallback.
  /// - Returns: A string representing the resolved package URI.
  @protected
  String getPkgUri(mirrors.TypeMirror mirror, String libraryUri) {
    final realClassUri = findRealClassUriFromMirror(mirror)?.toString();
    return realClassUri ?? libraryUri;
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
  /// - Returns: The URI of the library containing the class, or `null` if not found.
  @protected
  Uri? findRealClassUri(String className, String? hintUri) {
    // Search through mirror system
    for (final libraryMirror in getLibraries()) {
      for (final declaration in libraryMirror.declarations.values) {
        final mirrorClassName = mirrors.MirrorSystem.getName(declaration.simpleName);
        if (mirrorClassName == className && Symbol(className) == declaration.simpleName) {
          return findRealClassUriFromMirror(declaration) ?? libraryMirror.uri;
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
  /// - Returns: The URI of the library containing the type, or `null` if not found.
  @protected
  Uri? findRealClassUriFromMirror(mirrors.DeclarationMirror typeMirror) {
    // 1) If this is a class mirror, the declaring library is the authoritative source. dart:core/function.dart.Function
    try {
      if (typeMirror.location?.sourceUri case final uri?) {
        return uri;
      }

      if (typeMirror.owner?.location?.sourceUri case final uri?) {
        return uri;
      }

      if (typeMirror.owner?.location?.sourceUri case final uri?) {
        return uri;
      }

      if (typeMirror is mirrors.TypeMirror) {
        return findRealClassUriFromMirror(typeMirror.originalDeclaration);
      }
    } catch (_) {
      // ignore and fall back to search
    }

    // 2) Fall back to scanning loaded libraries (mirrorSystem.libraries). Prefer root package.
    final nameToMatch = mirrors.MirrorSystem.getName(typeMirror.simpleName);

    for (final lib in getLibraries()) {
      if (lib.declarations[typeMirror.simpleName] case final declaration?) {
        return findRealClassUriFromMirror(declaration) ?? lib.uri;
      }

      // If not directly declared under that symbol, try a best-effort name match:
      try {
        for (final d in lib.declarations.values) {
          final dName = mirrors.MirrorSystem.getName(d.simpleName);
          if (dName == nameToMatch && d.simpleName == typeMirror.simpleName) {
            return findRealClassUriFromMirror(d) ?? lib.uri;
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
  mirrors.TypeMirror getMirroredTypeAnnotation(AnalyzedTypeAnnotation dartType, String libraryUri) {
    final type = findRuntimeTypeFromDartType(dartType, libraryUri);
    return mirrors.reflectType(type);
  }

  /// Resolves the runtime [Type] corresponding to a given [AnalyzedTypeAnnotation].
  ///
  /// This method attempts multiple strategies to determine the actual runtime
  /// type of a Dart element:
  /// 1. Checks for built-in core and types (e.g., `int`, `List`, `Future`).
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
  Type findRuntimeTypeFromDartType(AnalyzedTypeAnnotation dartType, String defaultLibraryUri) {
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
                return tryAndGetOriginalType(declaration, defaultLibraryUri, Uri.parse(defaultLibraryUri));
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
  /// 1. Checks for built-in types (core and).
  /// 2. Searches the mirror system for the base class corresponding to the [AnalyzedTypeAnnotation].
  /// 3. Falls back to [findRuntimeTypeFromDartType] if no base class is found.
  ///
  /// - [dartType]: The analyzer [AnalyzedTypeAnnotation] to resolve.
  /// - [libraryUri]: The URI of the library where the type is defined.
  /// - Returns: The base runtime [Type].
  @protected
  Type findBaseRuntimeTypeFromDartType(AnalyzedTypeAnnotation dartType, String libraryUri) {
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
                return tryAndGetOriginalType(declaration, libraryUri, Uri.parse(libraryUri));
              } catch (e) {
                // Continue searching
              }
            }
          }
        }
      }
      }

    // Fallback to the actual runtime type
    return findRuntimeTypeFromDartType(dartType, libraryUri);
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
  /// final name = getClassNameFromDartType(type, 'package:my_pkg/src/file.dart');
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
  String? getClassNameFromDartType(AnalyzedTypeAnnotation dartType, String libraryUri) {
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
  /// - Returns: A list of [AnnotationDeclaration] representing the extracted annotations.
  @protected
  List<AnnotationDeclaration> extractAnnotations(List<mirrors.InstanceMirror> metadata, String libraryUri, Uri sourceUri, [List<AnalyzedAnnotation>? analyzerAnnotations]);

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
  /// ### 2. Synthetic fallback
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
  /// final lib = libraryResolver.getLibrary('package:my_app/models.dart');
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
  @protected
  LibraryDeclaration getLibrary(String uri);

  /// List of library mirrors to process
  List<mirrors.LibraryMirror> getLibraries();
}