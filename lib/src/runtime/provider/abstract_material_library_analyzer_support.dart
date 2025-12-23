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

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

/// {@template abstract_element_support}
/// An abstract base class that enhances [MaterialLibrary] with high-level
/// support for Dart analyzer *elements* (classes, enums, typedefs, mixins).
///
/// Whereas [MaterialLibrary] focuses on loading metadata through mirrors and
/// high-level library analysis, **AbstractMaterialLibraryAnalyzerSupport** adds the ability to
/// cache, resolve, and reuse static analyzer elements obtained from
/// `package:analyzer`.
///
/// This class does not perform resolution itself—subclasses are responsible for
/// populating these caches—but it provides the structure necessary for:
///
/// ### Why This Exists
/// - Avoiding expensive repeated analyzer lookups.
/// - Offering a unified element-layer to JetLeaf generators.
/// - Supporting mixed reflection (mirrors + analyzer) without duplicated work.
/// - Providing a bridge that allows declaration generators to use fully
///   resolved semantic information rather than only Mirror metadata.
///
/// ### Element Caches
/// Each cache maps a canonical or fully qualified Dart name to its corresponding
/// analyzer element:
///
/// | Cache Field | Element Type            | Description |
/// |-------------|-------------------------|-------------|
/// | `_classes`  | [ClassElement]          | Stores analyzer representations of all resolved classes. Useful for semantic type inspection, constructors, mixins, interfaces, generic parameters, etc. |
/// | `_enums`    | [EnumElement]           | Stores analyzer metadata for discovered enums, including values, documentation, and annotations. |
/// | `_typedefs` | [TypeAliasElement]      | Stores typedef / alias declarations, supporting generic typedef resolution and function alias discovery. |
/// | `_mixins`   | [MixinElement]          | Stores discovered mixins and their constrained type requirements. |
///
/// These caches enable rapid lookups when generating declarations, resolving
/// types, or building metadata trees across multiple libraries.
///
/// ### Typical Usage in Subclasses
/// Subclasses may:
/// - Populate caches when scanning resolved library elements.
/// - Query caches before calling analyzer APIs again.
/// - Use caches to resolve a type string → analyzer element.
/// - Build custom declaration objects from these element models.
///
/// This design ensures the JetLeaf build/runtime-generator pipeline remains
/// performant even as the complexity of type resolution increases.
/// {@endtemplate}
abstract class AbstractMaterialLibraryAnalyzerSupport {
  /// Creates the base element-support layer used by JetLeaf library and
  /// declaration generators.
  /// 
  /// {@macro abstract_element_support}
  AbstractMaterialLibraryAnalyzerSupport();
  
  /// Parses and returns the analyzer [CompilationUnit] for the Dart source
  /// identified by the given [uri].
  ///
  /// This method acts as a lightweight bridge between raw source loading
  /// ([readSourceCode]) and analyzer-based semantic resolution. It converts
  /// Dart source code into an abstract syntax tree (AST) representation that
  /// can later be used to obtain a [LibraryElement].
  ///
  /// ### Behavior
  /// - Reads the source code associated with [uri] using [readSourceCode].
  /// - Invokes `parseString` from `package:analyzer` to produce a
  ///   [CompilationUnit].
  /// - Returns the parsed unit if successful.
  /// - Silently returns `null` if parsing fails for any reason.
  ///
  /// ### Parameters
  /// - `uri`: The URI identifying the Dart source to parse. This value is
  ///   forwarded to both the source reader and analyzer parser.
  ///
  /// ### Returns
  /// - A [Future] that completes with a [CompilationUnit] when parsing
  ///   succeeds.
  /// - `null` if the source cannot be read or contains syntax errors that
  ///   prevent parsing.
  ///
  /// ### Notes
  /// - This method intentionally suppresses parsing errors to keep JetLeaf’s
  ///   generator pipeline resilient when encountering partially invalid or
  ///   unsupported source files.
  ///
  /// This method does **not** perform full semantic resolution; it only builds
  /// the syntactic AST needed to access declared fragments.
  @protected
  CompilationUnit? getUnit(Object uri) {
    try {
      final result = parseString(content: readSourceCode(uri), path: uri.toString());
      return result.unit;
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the analyzer [ClassDeclaration] AST node for the class named
  /// [name] within the Dart source identified by [sourceUri].
  ///
  /// This method operates purely at the **syntax
  /// (AST) level** and returns the raw parsed declaration as it appears in
  /// source code, without requiring full semantic resolution.
  ///
  /// ### Behavior
  /// - Parses the source file using [getUnit].
  /// - Searches top-level declarations for a matching [ClassDeclaration].
  /// - Returns the first matching declaration if found.
  /// - Returns `null` if the source cannot be parsed or the class is absent.
  ///
  /// ### Parameters
  /// - `name`: The simple name of the class to locate.
  /// - `sourceUri`: The URI of the Dart source file to analyze.
  ///
  /// ### Returns
  /// - A [ClassDeclaration] representing the class syntax node.
  /// - `null` if no matching class declaration exists.
  ///
  /// ### Use Cases
  /// - Inspecting constructors, fields, methods, and modifiers directly.
  /// - Reading documentation comments or annotations from source.
  /// - Performing source-level transformations or validations.
  ///
  /// ### Notes
  /// - This method does **not** require analyzer element resolution.
  /// - It is marked `@protected` for internal JetLeaf generator usage only.
  @protected
  AnalyzedClassDeclaration? getAnalyzedClassDeclaration(String name, Uri sourceUri) {
    if (getUnit(sourceUri) case final unit?) {
      if (unit.declarations.whereType<ClassDeclaration>().where((c) => c.name.toString() == name).firstOrNull case final type?) {
        return type;
      }
    }

    return null;
  }

  /// Returns a specific **field declaration** from a list of analyzed class members.
  ///
  /// Searches [members] for a [AnalyzedFieldDeclaration] whose first variable
  /// name matches [fieldName] or whose full string representation matches.
  ///
  /// Returns `null` if no matching field is found.
  ///
  /// Example:
  /// ```dart
  /// final field = getAnalyzedField(classMembers, 'myField');
  /// ```
  AnalyzedFieldDeclaration? getAnalyzedField(AnalyzedMemberList? members, String fieldName) {
    if (members case final members?) {
      if (members.whereType<FieldDeclaration>().where((f) => f.fields.variables.firstOrNull?.name.toString() == fieldName || f.fields.toString() == fieldName).firstOrNull case final field?) {
        return field;
      }
    }

    return null;
  }

  /// Returns a specific **method declaration** from a list of analyzed class members.
  ///
  /// Searches [members] for a [AnalyzedMethodDeclaration] whose name matches
  /// [methodName] or whose full string representation matches.
  ///
  /// Returns `null` if no matching method is found.
  ///
  /// Example:
  /// ```dart
  /// final method = getAnalyzedMethod(classMembers, 'myMethod');
  /// ```
  AnalyzedMethodDeclaration? getAnalyzedMethod(AnalyzedMemberList? members, String methodName) {
    if (members case final members?) {
      if (members.whereType<MethodDeclaration>().where((f) => f.name.toString() == methodName || f.toString() == methodName).firstOrNull case final method?) {
        return method;
      }
    }

    return null;
  }

  /// Returns a specific **top-level variable declaration** from a library.
  ///
  /// Searches the analyzed unit obtained via [getUnit(libraryUri)] for a
  /// [AnalyzedTopLevelVariableDeclaration] whose variable name matches
  /// [variableName] or whose string representation matches.
  ///
  /// Returns `null` if no matching variable is found.
  ///
  /// Example:
  /// ```dart
  /// final variable = getAnalyzedTopLevelVariable('package:my_app/main.dart', 'myVar');
  /// ```
  AnalyzedTopLevelVariableDeclaration? getAnalyzedTopLevelVariable(Object libraryUri, String variableName) {
    if (getUnit(libraryUri) case final unit?) {
      if (unit.declarations.whereType<TopLevelVariableDeclaration>().where((f) => f.toString() == variableName || f.variables.variables.firstOrNull?.name.toString() == variableName).firstOrNull case final variable?) {
        return variable;
      }
    }

    return null;
  }

  /// Returns a specific **top-level function declaration** from a library.
  ///
  /// Searches the analyzed unit obtained via [getUnit(libraryUri)] for a
  /// [AnalyzedTopLevelFunctionDeclaration] whose name matches [functionName]
  /// or whose string representation matches.
  ///
  /// Returns `null` if no matching function is found.
  ///
  /// Example:
  /// ```dart
  /// final function = getAnalyzedTopLevelMethod('package:my_app/main.dart', 'myFunction');
  /// ```
  AnalyzedTopLevelFunctionDeclaration? getAnalyzedTopLevelMethod(Object libraryUri, String functionName) {
    if (getUnit(libraryUri) case final unit?) {
      if (unit.declarations.whereType<FunctionDeclaration>().where((f) => f.toString() == functionName || f.name.toString() == functionName).firstOrNull case final function?) {
        return function;
      }
    }

    return null;
  }

  /// Retrieves the analyzer [MixinDeclaration] AST node for the mixin named
  /// [name] within the Dart source identified by [sourceUri].
  ///
  /// This method provides direct access to the **syntactic representation**
  /// of a mixin declaration without relying on analyzer element resolution.
  ///
  /// ### Behavior
  /// - Parses the source file via [getUnit].
  /// - Searches for a top-level [MixinDeclaration] matching [name].
  /// - Returns the declaration if found; otherwise returns `null`.
  ///
  /// ### Parameters
  /// - `name`: The simple name of the mixin.
  /// - `sourceUri`: The URI of the source file containing the mixin.
  ///
  /// ### Returns
  /// - A [MixinDeclaration] AST node if present.
  /// - `null` if the mixin is not declared in the source.
  ///
  /// ### Use Cases
  /// - Inspecting `on` constraints and implemented interfaces.
  /// - Reading mixin-level annotations or documentation.
  /// - Source-driven metadata generation.
  ///
  /// ### Notes
  /// - This method works even when semantic resolution is unavailable.
  /// - Intended exclusively for internal JetLeaf generator logic.
  @protected
  AnalyzedMixinDeclaration? getAnalyzedMixinDeclaration(String name, Uri sourceUri) {
    if (getUnit(sourceUri) case final unit?) {
      if (unit.declarations.whereType<MixinDeclaration>().where((c) => c.name.toString() == name).firstOrNull case final type?) {
        return type;
      }
    }

    return null;
  }

  /// Retrieves the analyzer [EnumDeclaration] AST node for the enum named
  /// [name] within the Dart source identified by [sourceUri].
  ///
  /// This method exposes the enum’s **raw syntax tree**, including values,
  /// annotations, and documentation, without requiring analyzer element
  /// resolution.
  ///
  /// ### Behavior
  /// - Parses the source file using [getUnit].
  /// - Searches top-level declarations for an [EnumDeclaration] matching [name].
  /// - Returns the declaration if found.
  ///
  /// ### Parameters
  /// - `name`: The simple name of the enum.
  /// - `sourceUri`: The URI of the Dart source file to analyze.
  ///
  /// ### Returns
  /// - An [EnumDeclaration] representing the enum syntax.
  /// - `null` if the enum does not exist in the source.
  ///
  /// ### Use Cases
  /// - Extracting enum values and documentation comments.
  /// - Source-based code generation or validation.
  /// - Analyzing annotations applied to enum values.
  ///
  /// ### Notes
  /// - This method is AST-only and does not imply semantic correctness.
  /// - Intended for internal use by JetLeaf’s generator pipeline.
  @protected
  AnalyzedEnumDeclaration? getAnalyzedEnumDeclaration(String name, Uri sourceUri) {
    if (getUnit(sourceUri) case final unit?) {
      if (unit.declarations.whereType<EnumDeclaration>().where((c) => c.name.toString() == name).firstOrNull case final type?) {
        return type;
      }
    }

    return null;
  }

  /// Retrieves the analyzer [FunctionTypeAlias] AST node for the typedef named
  /// [name] within the Dart source identified by [sourceUri].
  ///
  /// This method returns the **syntactic typedef declaration** exactly as it
  /// appears in source code, without resolving it to a [TypeAliasElement].
  ///
  /// ### Behavior
  /// - Parses the source file using [getUnit].
  /// - Searches for a matching [FunctionTypeAlias] declaration.
  /// - Returns the declaration if found; otherwise returns `null`.
  ///
  /// ### Parameters
  /// - `name`: The simple name of the typedef.
  /// - `sourceUri`: The URI of the Dart file where the typedef is declared.
  ///
  /// ### Returns
  /// - A [FunctionTypeAlias] AST node.
  /// - `null` if the typedef is not present.
  ///
  /// ### Use Cases
  /// - Reading typedef signatures directly from source.
  /// - Inspecting generic parameters and function shapes.
  /// - Supporting source-driven reflection features.
  ///
  /// ### Notes
  /// - Only supports legacy `typedef` declarations represented by
  ///   [FunctionTypeAlias].
  /// - Modern alias syntax is handled via analyzer elements instead.
  @protected
  AnalyzedTypedefDeclaration? getAnalyzedTypeAliasDeclaration(String name, Uri sourceUri) {
    if (getUnit(sourceUri) case final unit?) {
      if (unit.declarations.whereType<FunctionTypeAlias>().where((c) => c.name.toString() == name).firstOrNull case final type?) {
        return type;
      }
    }

    return null;
  }

  /// Determines whether the given analyzer [TypeAnnotation] represents a
  /// **nullable type**.
  ///
  /// This method performs a **hybrid nullability check**, combining:
  /// - **Syntactic analysis** (AST-level `?` markers and string forms), and
  /// - **Semantic analysis** (resolved [DartType] nullability information).
  ///
  /// It exists because nullability information may be partially available
  /// depending on whether analyzer resolution has been performed.
  ///
  /// ### How Nullability Is Detected
  /// The method evaluates nullability using the following strategy:
  ///
  /// 1. **Explicit syntax (`?`)**
  ///    - If `type?.question` is present.
  ///    - If the string representation ends with `?`.
  ///
  /// 2. **Named types**
  ///    - Checks the resolved [DartType] via [_checkDartType].
  ///    - Recursively inspects generic type arguments
  ///      (e.g. `List<String?>`).
  ///
  /// 3. **Generic function types**
  ///    - Evaluates the function’s return type for nullability.
  ///
  /// 4. **Fallback semantic check**
  ///    - Uses analyzer nullability metadata when available.
  ///
  /// ### Parameters
  /// - `type`: The analyzer [TypeAnnotation] to inspect. May be `null`.
  ///
  /// ### Returns
  /// - `true` if the type is nullable.
  /// - `false` if the type is definitively non-nullable.
  ///
  /// ### Use Cases
  /// - Determining optional parameters or fields during code generation.
  /// - Enforcing null-safety rules in JetLeaf metadata models.
  /// - Supporting mixed-resolution analysis where full type information
  ///   may not yet be available.
  ///
  /// ### Notes
  /// - This method is resilient to partially-resolved analyzer states.
  /// - It intentionally favors correctness over minimal checks.
  /// - Record types are currently ignored and treated as non-nullable
  ///   unless semantic information is present.
  bool checkTypeAnnotationNullable(TypeAnnotation? type) {
    if (type?.question != null) return true;
    if (type.toString().endsWith("?")) return true;

    if (type is NamedType) {
      if (type.name.lexeme.endsWith("?")) return true;
    }

    // if (type is NamedType) {
    //   if (_checkDartType(type.type)) return true;

    //   if (type.typeArguments != null) {
    //     for (final arg in type.typeArguments!.arguments) {
    //       if (arg is NamedType && checkTypeAnnotationNullable(arg)) return true;
    //     }
    //   }

    //   return false;
    // }

    // if (type is GenericFunctionType) {
    //   return checkTypeAnnotationNullable(type.returnType);
    // }

    return _checkDartType(type?.type);
  }

  /// Returns the **name of an analyzed type annotation**.
  ///
  /// If [annotation] is a [AnalyzedNamedType], this returns the
  /// identifier’s lexeme. Otherwise, it returns the string representation
  /// of the annotation.
  ///
  /// Example:
  /// ```dart
  /// final name = getNameFromAnalyzedTypeAnnotation(namedType); // "MyClass"
  /// ```
  String getNameFromAnalyzedTypeAnnotation(AnalyzedTypeAnnotation annotation) {
    return annotation is AnalyzedNamedType ? annotation.name.lexeme : annotation.toString();
  }

  /// Checks whether the given analyzer [DartType] is marked as **nullable**
  /// according to its resolved nullability suffix.
  ///
  /// This method performs a **semantic-level nullability check** and is used
  /// as a fallback when syntactic nullability (`?`) cannot be reliably
  /// determined from the AST alone.
  ///
  /// ### Behavior
  /// - Returns `true` if the type’s [NullabilitySuffix] is
  ///   [NullabilitySuffix.question].
  /// - Returns `false` if the type is non-nullable or unresolved.
  ///
  /// ### Parameters
  /// - `dartType`: A resolved analyzer [DartType], or `null`.
  ///
  /// ### Returns
  /// - `true` if the type is nullable.
  /// - `false` otherwise.
  ///
  /// ### Notes
  /// - This method assumes analyzer resolution has occurred.
  /// - When resolution is incomplete, callers should rely on
  ///   syntactic checks first.
  bool _checkDartType(DartType? dartType) => dartType?.nullabilitySuffix == NullabilitySuffix.question;

  /// Retrieves the Dart type of a parameter from its AST node.
  ///
  /// Supports all parameter types including simple, field, function-typed,
  /// default, and super formal parameters.
  ///
  /// # Parameters
  /// - [param]: The AST parameter node.
  ///
  /// # Returns
  /// The [AnalyzedTypeAnnotation] of the parameter, or `null` if it cannot be determined.
  AnalyzedTypeAnnotation? getAnalyzedTypeAnnotationFromParameter(FormalParameter? param) {
    if (param is SimpleFormalParameter) return param.type;
    if (param is FieldFormalParameter) return param.type;
    if (param is FunctionTypedFormalParameter) return param.returnType;
    if (param is DefaultFormalParameter) return getAnalyzedTypeAnnotationFromParameter(param.parameter);
    if (param is SuperFormalParameter) return param.type;
    return null;
  }

  /// Reads and returns the **raw Dart source code** associated with the given
  /// [uri] reference.
  ///
  /// This method provides low-level access to the textual contents of a Dart
  /// source file and serves as a bridge between JetLeaf’s generator pipeline
  /// and the underlying source system (file system, package resolver, or
  /// in-memory assets).
  ///
  /// ### Responsibilities
  /// Implementations are expected to:
  /// - Resolve the provided [uri] into a readable Dart source location.
  /// - Load and return the complete source code as a UTF-8 string.
  /// - Support common URI types such as:
  ///   - `file://` URIs
  ///   - `package:` URIs
  ///   - Analyzer-provided source references
  ///
  /// ### Parameters
  /// - `uri`: A reference to the Dart source. This may be a [Uri], a string,
  ///   or an analyzer-specific object depending on the implementation.
  ///
  /// ### Returns
  /// - A [Future] that completes with the raw source code as a [String].
  ///
  /// ### Use Cases
  /// - Parsing documentation comments directly from source.
  /// - Performing source-level analysis not exposed by analyzer elements.
  /// - Supporting hybrid reflection (mirrors + source inspection).
  ///
  /// ### Notes
  /// - This method is marked `@protected` because it is intended solely for
  ///   internal use by JetLeaf generators.
  /// - Implementations should throw meaningful exceptions if the source
  ///   cannot be resolved or read.
  ///
  /// Subclasses **must** provide an implementation appropriate to their
  /// execution environment (build-time, runtime, or analyzer-driven).
  @protected
  String readSourceCode(Object uri);
}

/// {@template analyzed_class_declaration}
/// An internal alias representing a fully **analyzed class declaration**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [ClassDeclaration] but is used internally to
/// distinguish declarations that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedClassDeclaration = ClassDeclaration;

/// {@template analyzed_enum_declaration}
/// An internal alias representing a fully **analyzed enum declaration**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [EnumDeclaration] but is used internally to
/// distinguish declarations that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedEnumDeclaration = EnumDeclaration;

/// {@template analyzed_mixin_declaration}
/// An internal alias representing a fully **analyzed mixin declaration**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [MixinDeclaration] but is used internally to
/// distinguish declarations that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedMixinDeclaration = MixinDeclaration;

/// {@template analyzed_typedef_declaration}
/// An internal alias representing a fully **analyzed typedef declaration**
/// (function type alias) in JetLeaf’s reflection system.
///
/// This is equivalent to [FunctionTypeAlias] but is used internally to
/// distinguish declarations that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedTypedefDeclaration = FunctionTypeAlias;

/// {@template analyzed_parameter_declaration}
/// An internal alias representing a fully **analyzed parameter declaration**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [FormalParameter] but is used internally to
/// distinguish parameters that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedParameterDeclaration = FormalParameter;

/// {@template analyzed_constructor_declaration}
/// An internal alias representing a fully **analyzed constructor declaration**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [ConstructorDeclaration] but is used internally to
/// distinguish constructors that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedConstructorDeclaration = ConstructorDeclaration;

/// {@template analyzed_method_declaration}
/// An internal alias representing a fully **analyzed method declaration**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [MethodDeclaration] but is used internally to
/// distinguish methods that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedMethodDeclaration = MethodDeclaration;

/// {@template analyzed_top_level_variable_declaration}
/// An internal alias representing a fully **analyzed top-level variable**
/// declaration in JetLeaf’s reflection system.
///
/// This is equivalent to [TopLevelVariableDeclaration] but is used internally
/// to distinguish variables that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedTopLevelVariableDeclaration = TopLevelVariableDeclaration;

/// {@template analyzed_top_level_function_declaration}
/// An internal alias representing a fully **analyzed top-level function**
/// declaration in JetLeaf’s reflection system.
///
/// This is equivalent to [FunctionDeclaration] but is used internally
/// to distinguish functions that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedTopLevelFunctionDeclaration = FunctionDeclaration;

/// {@template analyzed_field_declaration}
/// An internal alias representing a fully **analyzed field declaration**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [FieldDeclaration] but is used internally
/// to distinguish fields that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedFieldDeclaration = FieldDeclaration;

/// {@template analyzed_type_annotation}
/// An internal alias representing a fully **analyzed type annotation**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [TypeAnnotation] but is used internally
/// to distinguish type annotations that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedTypeAnnotation = TypeAnnotation;

/// {@template analyzed_record_type_annotation}
/// An internal alias representing a fully **analyzed record type annotation**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [RecordTypeAnnotation] but is used internally
/// to distinguish record type annotations that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedRecordTypeAnnotation = RecordTypeAnnotation;

/// {@template analyzed_record_type_annotation_field}
/// An internal alias representing a fully **analyzed field** within a
/// record type annotation in JetLeaf’s reflection system.
///
/// This is equivalent to [RecordTypeAnnotationField] but is used internally
/// to distinguish record fields that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedRecordTypeAnnotationField = RecordTypeAnnotationField;

/// {@template analyzed_record_type_annotation_named_field}
/// An internal alias representing a fully **analyzed named field** within a
/// record type annotation in JetLeaf’s reflection system.
///
/// This is equivalent to [RecordTypeAnnotationNamedField] but is used internally
/// to distinguish named record fields that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedRecordTypeAnnotationNamedField = RecordTypeAnnotationNamedField;

/// {@template analyzed_generic_function_type_annotation}
/// An internal alias representing a fully **analyzed generic function type**
/// annotation in JetLeaf’s reflection system.
///
/// This is equivalent to [GenericFunctionType] but is used internally
/// to distinguish generic function type annotations that have been fully
/// processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedGenericFunctionTypeAnnotation = GenericFunctionType;

/// {@template analyzed_type_parameter_list}
/// An internal alias representing a fully **analyzed list of type parameters**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [TypeParameterList] but is used internally
/// to distinguish type parameter lists that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedTypeParameterList = TypeParameterList;

/// {@template analyzed_type_parameter}
/// An internal alias representing a fully **analyzed type parameter**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [TypeParameter] but is used internally
/// to distinguish type parameters that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedTypeParameter = TypeParameter;

/// {@template analyzed_formal_parameter_list}
/// An internal alias representing a fully **analyzed formal parameter list**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [FormalParameterList] but is used internally
/// to distinguish parameter lists that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedFormalParameterList = FormalParameterList;

/// {@template analyzed_annotation}
/// An internal alias representing a fully **analyzed annotation** in
/// JetLeaf’s reflection system.
///
/// This is equivalent to [Annotation] but is used internally to distinguish
/// annotations that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedAnnotation = Annotation;

/// {@template analyzed_named_type}
/// An internal alias representing a fully **analyzed named type** in
/// JetLeaf’s reflection system.
///
/// This is equivalent to [NamedType] but is used internally to distinguish
/// named types that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedNamedType = NamedType;

/// {@template analyzed_mixin_clause}
/// An internal alias representing a fully **analyzed mixin clause** in
/// JetLeaf’s reflection system.
///
/// This is equivalent to [WithClause] but is used internally to distinguish
/// mixin clauses that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedMixinClause = WithClause;

/// {@template analyzed_interface_clause}
/// An internal alias representing a fully **analyzed implements clause** in
/// JetLeaf’s reflection system.
///
/// This is equivalent to [ImplementsClause] but is used internally to
/// distinguish interface clauses that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedInterfaceClause = ImplementsClause;

/// {@template analyzed_super_class_clause}
/// An internal alias representing a fully **analyzed extends clause** in
/// JetLeaf’s reflection system.
///
/// This is equivalent to [ExtendsClause] but is used internally to distinguish
/// super class clauses that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedSuperClassClause = ExtendsClause;

/// {@template analyzed_mixin_on_clause}
/// An internal alias representing a fully **analyzed mixin `on` clause** in
/// JetLeaf’s reflection system.
///
/// This is equivalent to [MixinOnClause] but is used internally to distinguish
/// mixin `on` clauses that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedMixinOnClause = MixinOnClause;

/// {@template analyzed_member_list}
/// An internal alias representing a fully **analyzed list of class members**
/// in JetLeaf’s reflection system.
///
/// This is equivalent to [NodeList<ClassMember>] but is used internally to
/// distinguish member lists that have been fully processed and resolved.
/// {@endtemplate}
@internal
typedef AnalyzedMemberList = NodeList<ClassMember>;