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

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../argument/executable_argument.dart';
import '../exceptions.dart';
import '../helpers/equals_and_hash_code.dart';
import '../runtime/provider/meta_runtime_provider.dart';

part '../_declaration/_annotation_declaration.dart';
part '../_declaration/_class_declaration.dart';
part '../_declaration/_constructor_declaration.dart';
part '../_declaration/_declaration.dart';
part '../_declaration/_enum_declaration.dart';
part '../_declaration/_field_declaration.dart';
part '../_declaration/_function_link_declaration.dart';
part '../_declaration/_library_declaration.dart';
part '../_declaration/_link_declaration.dart';
part '../_declaration/_method_declaration.dart';
part '../_declaration/_mixin_declaration.dart';
part '../_declaration/_parameter_declaration.dart';
part '../_declaration/_record_link_declaration.dart';
part '../_declaration/_type_declaration.dart';
part '../_declaration/_typedef_declaration.dart';
part 'annotation_declaration.dart';
part 'class_declaration.dart';
part 'constructor_declaration.dart';
part 'enum_declaration.dart';
part 'field_declaration.dart';
part 'function_link_declaration.dart';
part 'library_declaration.dart';
part 'link_declaration.dart';
part 'method_declaration.dart';
part 'mixin_declaration.dart';
part 'parameter_declaration.dart';
part 'record_link_declaration.dart';
part 'type_declaration.dart';
part 'typedef_declaration.dart';

/// The default character encoding used for JSON serialization and deserialization.
///
/// Jetson uses UTF-8 as the standard encoding for all JSON input and output
/// operations to ensure full compatibility with the JSON specification
/// (RFC 8259) and cross-platform interoperability.
///
/// ### Details
/// - All string data written by Jetson components is encoded using UTF-8.
/// - Input streams are decoded using UTF-8 unless another encoding is
///   explicitly configured.
/// - This constant provides a single reference point for encoding decisions
///   throughout the Jetson pipeline.
///
/// ### Example
/// ```dart
/// final encoded = DEFAULT_ENCODING.encode('{"name":"JetLeaf"}');
/// final decoded = DEFAULT_ENCODING.decode(encoded);
/// print(decoded); // {"name":"JetLeaf"}
/// ```
@internal
const Utf8Codec DEFAULT_ENCODING = utf8;

/// {@template type_kind}
/// Defines the kind of a reflected type within the JetLeaf reflection system.
///
/// This enum is used by [TypeDeclaration] and related APIs to describe
/// what kind of Dart type a given type represents. It enables consistent
/// introspection and classification of Dart types during reflection.
///
/// {@endtemplate}
enum TypeKind {
  /// {@macro type_kind}
  ///
  /// Represents a standard Dart class or interface type.
  classType,

  /// {@macro type_kind}
  ///
  /// Represents an `enum` declaration in Dart.
  enumType,

  /// {@macro type_kind}
  ///
  /// Represents a `typedef`, either for functions or types.
  typedefType,

  /// {@macro type_kind}
  ///
  /// Represents a `List<T>` or any subtype of `List`.
  listType,

  /// {@macro type_kind}
  ///
  /// Represents a `Map<K, V>` or any subtype of `Map`.
  mapType,

  /// {@macro type_kind}
  ///
  /// Represents a function type such as `void Function(int)`.
  functionType,

  /// {@macro type_kind}
  ///
  /// Represents a record type such as `(int, String)`.
  recordType,

  /// {@macro type_kind}
  ///
  /// Represents primitive Dart types such as `int`, `double`, `bool`, or `String`.
  primitiveType,

  /// {@macro type_kind}
  ///
  /// Represents a `Collection` or any subtype of `Collection`.
  collectionType,

  /// {@macro type_kind}
  ///
  /// Represents a `Async` or any subtype of `Async`.
  asyncType,

  /// {@macro type_kind}
  ///
  /// Represents a `Meta` or any subtype of `Meta`.
  metaType,

  /// {@macro type_kind}
  ///
  /// Represents Dart’s `dynamic` type.
  dynamicType,

  /// {@macro type_kind}
  ///
  /// Represents Dart’s `void` type.
  voidType,

  /// {@macro type_kind}
  ///
  /// Represents a type variable, such as `T` in a generic class declaration.
  typeVariable,

  /// {@macro type_kind}
  ///
  /// Represents a Dart mixin.
  mixinType,

  /// {@macro type_kind}
  ///
  /// Represents a type that could not be resolved or identified.
  unknownType,
  
  /// {@macro type_kind}
  ///
  /// Represents a type that is a subtype of `TypedData`.
  typedData,

  /// {@macro type_kind}
  ///
  /// Represents a type that is an extension.
  extensionType,
}

/// {@template type_variance}
/// Represents the variance annotations for generic type parameters in Dart.
///
/// Variance defines how generic type parameters behave with respect to subtyping:
/// - Covariant (out): Preserves subtyping direction
/// - Contravariant (in): Reverses subtyping direction  
/// - Invariant: Neither covariant nor contravariant
///
/// {@template type_variance_features}
/// ## Values
/// - `covariant`: Marked with `covariant` keyword or `out` in some languages
/// - `contravariant`: Marked with `in` keyword in some languages  
/// - `invariant`: Default variance with no keyword
///
/// ## Dart Usage
/// In Dart, variance is primarily expressed through:
/// - `covariant` keyword for parameters
/// - Method parameter positions (contravariant)
/// - Default invariant behavior
/// {@endtemplate}
///
/// {@template type_variance_example}
/// ## Examples
/// ```dart
/// // Covariant type parameter
/// class Box<out T> {
///   T get value => ...;
/// }
///
/// // Contravariant type parameter  
/// class Consumer<in T> {
///   void accept(T value) {...}
/// }
///
/// // Invariant type parameter
/// class Holder<T> {
///   T value;
/// }
/// ```
/// {@endtemplate}
/// {@endtemplate}
enum TypeVariance {
  /// {@template covariant}
  /// Covariant type parameter (preserves subtyping).
  ///
  /// A covariant type parameter preserves the subtyping relationship:
  /// If `A` is a subtype of `B`, then `Container<A>` is a subtype of `Container<B>`.
  ///
  /// Used for:
  /// - Return types (output positions)
  /// - Read-only fields
  ///
  /// In Dart, marked with the `covariant` keyword.
  /// {@endtemplate}
  covariant,

  /// {@template contravariant}
  /// Contravariant type parameter (reverses subtyping).
  ///
  /// A contravariant type parameter reverses the subtyping relationship:
  /// If `A` is a subtype of `B`, then `Processor<B>` is a subtype of `Processor<A>`.
  ///
  /// Used for:
  /// - Parameter types (input positions)  
  /// - Write-only fields
  ///
  /// In some languages marked with `in` keyword.
  /// {@endtemplate}
  contravariant,

  /// {@template invariant}  
  /// Invariant type parameter (no subtyping relationship).
  ///
  /// An invariant type parameter allows no subtyping relationship between
  /// different instantiations of the generic type.
  ///
  /// Used when:
  /// - Type appears in both input and output positions
  /// - No subtyping should be allowed between instantiations
  ///
  /// This is the default variance in Dart.
  /// {@endtemplate}
  invariant,
}

/// {@template declaration}
/// Abstract base class representing a declared program element in reflection systems.
///
/// Provides fundamental metadata about declarations including:
/// - Name of the declared element
/// - Runtime type information
///
/// {@template declaration_features}
/// ## Key Features
/// - Uniform interface for all declaration types
/// - Name and type access
/// - Base for specialized declarations (classes, functions, etc.)
///
/// ## Implementations
/// Typically extended by:
/// - `ClassDeclaration` for class types
/// - `FunctionDeclaration` for functions/methods
/// - `VariableDeclaration` for variables/fields
/// - `ParameterDeclaration` for parameters
/// {@endtemplate}
///
/// {@template declaration_example}
/// ## Example Usage
/// ```dart
/// Declaration getDeclaration(dynamic element) {
///   return ClassDeclaration(element.runtimeType, element.runtimeType.toString());
/// }
///
/// final classDecl = getDeclaration(MyClass());
/// print(classDecl.getName()); // "MyClass"
/// print(classDecl.getType()); // MyClass
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract class Declaration {
  /// {@macro declaration}
  const Declaration();

  /// Gets the name of the declared element.
  ///
  /// {@template declaration_get_name}
  /// Returns:
  /// - The identifier name as it appears in source code
  /// - For classes: the class name ("MyClass")
  /// - For functions: the function name ("calculate")
  /// - For variables: the variable name ("count")
  ///
  /// Note:
  /// The exact format may vary by implementation but should always
  /// match the source declaration.
  /// {@endtemplate}
  String getName();

  /// Gets the runtime type of the declared element.
  ///
  /// {@template declaration_get_type}
  /// Returns:
  /// - The Dart [Type] object representing the declaration's type
  /// - For classes: the class type (MyClass)
  /// - For functions: the function type (Function)
  /// - For variables: the variable's declared type
  /// {@endtemplate}
  Type getType();

  /// Checks if this declaration is a public declaration.
  /// 
  /// Public vlues in dart is often just the name without any prefix.
  /// While private values are often prefixed with `_`.
  /// 
  /// ### Example
  /// ```dart
  /// class _PrivateClass {
  ///   final String publicField;
  /// 
  ///   void _privateMethod() {}
  /// }
  /// 
  /// class PublicClass {
  ///   final String _privateField;
  ///   
  ///   void publicMethod() {}
  /// }
  /// ```
  bool getIsPublic();

  /// Checks if a declaration is a synthetic declaration.
  /// 
  /// Synthetic declarations are normally generated by the compiler, for classes with generic values.
  bool getIsSynthetic();

  /// Returns a JSON representation of this entity.
  Map<String, Object> toJson();

  @override
  String toString() => toJson().toString();
}

/// {@template entity}
/// An abstract base class that defines a reflective entity in the system,
/// providing a common identifier useful for debugging, logging, or inspection.
///
/// This class is intended to be extended by other reflection-related
/// types such as [FieldDeclaration], [MethodDeclaration], [TypeDeclaration], etc.
///
/// ### Example
/// ```dart
/// class ReflectedField extends ReflectedEntity {
///   @override
///   final String debugIdentifier;
///
///   ReflectedField(this.getDebugIdentifier());
/// }
///
/// final field = ReflectedField('User.name');
/// print(field.getDebugIdentifier()); // User.name
/// ```
/// {@endtemplate}
abstract class EntityDeclaration extends Declaration {
  /// {@macro entity}
  const EntityDeclaration();

  /// The debug identifier for the entity.
  String getDebugIdentifier();

  @override
  String toString() => toJson().toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Use runtimeType for strict equality, as different concrete implementations
    // might have the same debugIdentifier but represent different concepts.
    if (other.runtimeType != runtimeType) return false;
    return other is EntityDeclaration && getDebugIdentifier() == other.getDebugIdentifier();
  }

  @override
  int get hashCode => getDebugIdentifier().hashCode;
}

/// {@template type_variable}
/// Represents a reflected type variable, such as `T` in a generic class
/// declaration like `class MyClass<T extends num>`.
///
/// This abstraction provides access to the upper bound of the type variable,
/// if any. This is useful in scenarios involving reflection, serialization,
/// or code generation where generic type constraints must be analyzed.
///
/// ## Example
/// Suppose you reflect on a class like:
///
/// ```dart
/// class Box<T extends num> {}
/// ```
///
/// A [TypeVariableDeclaration] for `T` would return an upper bound
/// representing `num`.
///
/// {@endtemplate}
abstract class TypeVariableDeclaration extends TypeDeclaration implements SourceDeclaration {
  /// The upper bound of the type variable, or `null` if unbounded.
  ///
  /// For example, in:
  /// ```dart
  /// class MyClass<T extends num> {}
  /// ``` 
  /// this would return a [TypeDeclaration] representing `num`.
  TypeDeclaration? getUpperBound();

  /// Returns the variance of the type parameter.
  TypeVariance getVariance();
}

/// {@template type_declaration_extension}
/// Extension providing type casting and declaration resolution for [TypeDeclaration].
///
/// Adds convenience methods for safely casting to specific declaration types
/// and finding the most specific declaration type.
///
/// {@template type_declaration_extension_features}
/// ## Key Features
/// - Safe type casting methods
/// - Declaration type resolution
/// - Null-safe operations
/// - Covers all TypeDeclaration variants
/// {@endtemplate}
///
/// {@template type_declaration_extension_example}
/// ## Example Usage
/// ```dart
/// TypeDeclaration decl = getSomeDeclaration();
///
/// // Safe casting
/// final classDecl = decl.asClass();
/// if (classDecl != null) {
///   print('Found class: ${classDecl.getName()}');
/// }
///
/// // Declaration resolution
/// final sourceDecl = decl.getDeclaration();
/// ```
/// {@endtemplate}
/// {@endtemplate}
extension TypeDeclarationExtension on TypeDeclaration {
  /// Resolves the most specific declaration type.
  ///
  /// {@template get_declaration}
  /// Returns:
  /// - The declaration as its most specific type (Class, Enum, etc.)
  /// - `null` if the type doesn't match any known declaration variant
  ///
  /// Checks types in this order:
  /// 1. ClassDeclaration
  /// 2. EnumDeclaration
  /// 3. TypedefDeclaration
  /// 4. RecordDeclaration
  /// 5. MixinDeclaration
  /// 6. TypeVariableDeclaration
  /// {@endtemplate}
  ClassDeclaration? getDeclaration() => asClass() ?? asEnum() ?? asMixin();

  /// Safely casts to [ClassDeclaration] if possible.
  ClassDeclaration? asClass() => this is ClassDeclaration ? this as ClassDeclaration? : null;

  /// Safely casts to [EnumDeclaration] if possible.
  EnumDeclaration? asEnum() => this is EnumDeclaration ? this as EnumDeclaration? : null;

  /// Safely casts to [MixinDeclaration] if possible.
  MixinDeclaration? asMixin() => this is MixinDeclaration ? this as MixinDeclaration? : null;
}

/// {@template declaration}
/// Represents any top-level or member declaration in Dart code,
/// such as a class, method, field, enum, typedef, etc., and exposes
/// its metadata for reflection.
///
/// This interface provides access to:
/// - The declaration's name
/// - The library it belongs to
/// - Attached annotations
/// - Optional source location (e.g., filename or URI)
///
/// It forms the base interface for all reflectable declarations like
/// [ClassDeclaration], [MethodDeclaration], and [FieldDeclaration].
///
/// ### Example
/// ```dart
/// final clazz = reflector.reflectType(MyClass).asClassType();
/// final methods = clazz?.getMethods();
///
/// for (final method in methods!) {
///   print(method.getName());
///   print(method.getSourceLocation());
/// }
/// ```
/// {@endtemplate}
abstract interface class SourceDeclaration extends EntityDeclaration {
  /// {@macro declaration}
  const SourceDeclaration();

  /// Returns the [LibraryDeclaration] in which this declaration is defined.
  ///
  /// Useful for tracking the origin of the declaration across packages and files.
  LibraryDeclaration getParentLibrary();

  /// Returns all annotations applied to this declaration.
  ///
  /// You can inspect custom or built-in annotations and their arguments:
  ///
  /// ### Example
  /// ```dart
  /// for (final annotation in declaration.getAnnotations()) {
  ///   print(annotation.getTypeDeclaration().getName());
  ///   print(annotation.getArguments());
  /// }
  /// ```
  List<AnnotationDeclaration> getAnnotations();

  /// Returns the source code location (e.g., file path or URI) where this declaration is defined,
  /// or `null` if not available in the current reflection context.
  ///
  /// This is optional and implementation-dependent.
  Uri? getSourceLocation();

  @override
  String getDebugIdentifier() => 'ReflectedDeclaration: ${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'source';
    result['name'] = getName();
    result['parentLibrary'] = getParentLibrary().toJson();

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if (annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }

    final sourceLocation = getSourceLocation();
    if (sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    result['runtimeType'] = runtimeType.toString();

    return result;
  }
}

/// {@template member}
/// Represents a member (method, field, or constructor) declared within a class,
/// exposing information about the owning class, whether it is static or abstract,
/// and any inherited metadata from [SourceDeclaration].
///
/// This is the base abstraction for:
/// - [MethodDeclaration]
/// - [FieldDeclaration]
/// - [ConstructorDeclaration]
///
/// ### Example
/// ```dart
/// final clazz = reflector.reflectType(MyClass).asClassType();
/// final members = clazz?.getDeclaredMembers();
///
/// for (final member in members!) {
///   print(member.getName()); // e.g., "toString"
///   print(member.getIsStatic()); // false
/// }
/// ```
/// {@endtemplate}
abstract class MemberDeclaration extends SourceDeclaration {
  /// {@macro member}
  const MemberDeclaration();

  /// Returns the [LinkDeclaration] that owns this member.
  ///
  /// ### Example
  /// ```dart
  /// final owner = member.getParentClass();
  /// print(owner.getName()); // e.g., "MyClass"
  /// ```
  LinkDeclaration? getParentClass();

  /// Returns `true` if this member is marked `static`.
  bool getIsStatic();

  /// Returns `true` if this member is declared `abstract`.
  bool getIsAbstract();

  @override
  String getDebugIdentifier() => 'Member: ${getParentClass()?.getName()}.${getName()}';

  @override
  String toString() => '''
Member(
  name: ${getName()},
  parentLibrary: ${getParentLibrary().getDebugIdentifier()},
  annotations: ${getAnnotations().map((a) => a.getDebugIdentifier()).join(', ')},
  sourceLocation: ${getSourceLocation()},
  isStatic: ${getIsStatic()},
  isAbstract: ${getIsAbstract()},
  parentClass: ${getParentClass()?.toJson()},
)
''';
}

/// {@template sort_by_public_extension}
/// Extension providing sorting capabilities for collections of [Declaration] objects.
/// 
/// Enables declarative sorting of reflection metadata by visibility and origin.
/// Particularly useful when presenting API documentation or generating code.
///
/// {@template sort_by_public_extension_features}
/// ## Sorting Features
/// - Public-first ordering
/// - Synthetic-last ordering
/// - Combined visibility/origin sorting
/// - Stable sorting (preserves original order for equal elements)
/// {@endtemplate}
///
/// {@template sort_by_public_extension_example}
/// ## Example Usage
/// ```dart
/// final declarations = library.getAllDeclarations();
///
/// // Simple public-first sort
/// final publicFirst = declarations.sortedByPublicFirst();
///
/// // Combined sort
/// final organized = declarations.sortedByPublicFirstThenSyntheticLast();
/// ```
/// {@endtemplate}
/// {@endtemplate}
extension SortByPublic<T extends Declaration> on Iterable<T> {
  /// {@template sorted_by_public_first}
  /// Sorts declarations with public visibility before private ones.
  ///
  /// Returns:
  /// - New [List] with public declarations first
  /// - Original order preserved among declarations with same visibility
  ///
  /// Example:
  /// ```dart
  /// final methods = classDecl.getMethods().sortedByPublicFirst();
  /// // [publicMethod1, publicMethod2, _privateMethod1, _privateMethod2]
  /// ```
  ///
  /// Sorting Logic:
  /// ```plaintext
  /// Public   -> -1 (comes first)
  /// Private  ->  1 (comes after)
  /// Equal    ->  0 (original order preserved)
  /// ```
  /// {@endtemplate}
  List<T> sortedByPublicFirst() {
    return toList()
      ..sort((a, b) {
        if (a.getIsPublic() == b.getIsPublic()) return 0;
        return a.getIsPublic() ? -1 : 1;
      });
  }

  /// {@template sorted_by_public_first_then_synthetic_last}
  /// Sorts declarations with public visibility first and synthetic declarations last.
  ///
  /// Returns:
  /// - New [List] with ordering: public > private > synthetic
  /// - Original order preserved among declarations with same characteristics
  ///
  /// Example:
  /// ```dart
  /// final fields = classDecl.getFields()
  ///   .sortedByPublicFirstThenSyntheticLast();
  /// // [publicField1, publicField2, _privateField1, @syntheticField]
  /// ```
  ///
  /// Sorting Logic:
  /// ```plaintext
  /// 1. Synthetic declarations always last
  /// 2. Among non-synthetic:
  ///    - Public   -> -1 (first)
  ///    - Private  ->  1 (after public)
  ///    - Equal    ->  0 (original order)
  /// ```
  /// {@endtemplate}
  List<T> sortedByPublicFirstThenSyntheticLast() {
    return toList()
      ..sort((a, b) {
        // Step 1: Synthetic comes last
        final syntheticA = a.getIsSynthetic();
        final syntheticB = b.getIsSynthetic();
        if (syntheticA != syntheticB) {
          return syntheticA ? 1 : -1;
        }

        // Step 2: Public comes before private
        final publicA = a.getIsPublic();
        final publicB = b.getIsPublic();
        if (publicA == publicB) return 0;
        return publicA ? -1 : 1;
      });
  }
}

/// {@template resource_declaration}
/// Abstract base class for declarations of external resources in reflection systems.
///
/// Represents metadata about external resources like:
/// - Asset files (images, translations, etc.)
/// - Native platform libraries
/// - Web resources
/// - Database schemas
///
/// {@template resource_declaration_features}
/// ## Key Features
/// - JSON serialization support
/// - Standardized toString() representation
/// - Base for resource-specific declarations
///
/// ## Implementations
/// Typically extended by:
/// - `AssetDeclaration` for bundled files
/// - `NativeLibraryDeclaration` for platform libraries
/// - `WebResourceDeclaration` for network assets
/// {@endtemplate}
///
/// {@template resource_declaration_example}
/// ## Example Implementation
/// ```dart
/// class ImageDeclaration extends ResourceDeclaration {
///   final String path;
///   final int width;
///   final int height;
///
///   const ImageDeclaration(this.path, this.width, this.height);
///
///   @override
///   Map<String, Object> toJson() => {
///     'type': 'image',
///     'path': path,
///     'dimensions': {'width': width, 'height': height}
///   };
/// }
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract class ResourceDeclaration {
  /// Creates a new resource declaration instance.
  ///
  /// {@template resource_declaration_constructor}
  /// All subclasses should provide a const constructor to enable
  /// usage in const contexts and metadata annotations.
  /// {@endtemplate}
  const ResourceDeclaration();

  /// Serializes this resource to a JSON-encodable map.
  ///
  /// {@template resource_to_json}
  /// Returns:
  /// - A map containing all relevant resource metadata
  /// - Should include at minimum a 'type' field identifying the resource kind
  /// - Must contain only JSON-encodable values
  ///
  /// Implementation Requirements:
  /// - Must be overridden by subclasses
  /// - Should include all identifying metadata
  /// - Should maintain backward compatibility
  ///
  /// Example Output:
  /// ```json
  /// {
  ///   "type": "font",
  ///   "family": "Roboto",
  ///   "files": ["Roboto-Regular.ttf", "Roboto-Bold.ttf"]
  /// }
  /// ```
  /// {@endtemplate}
  Map<String, Object> toJson();

  /// Standard string representation of this resource.
  ///
  /// {@template resource_to_string}
  /// Returns:
  /// - The JSON representation as a string
  /// - Provides consistent formatting for all resources
  ///
  /// Note:
  /// Uses the [toJson] implementation for serialization.
  /// {@endtemplate}
  @override
  String toString() => toJson().toString();
}

/// {@template package}
/// 🍃 JetLeaf Framework - Represents a Dart package within the runtime context.
///
/// This metadata is usually generated at compile time (JIT or AOT) to describe:
/// - The root application package
/// - Any dependent packages (e.g., `args`, `collection`)
///
/// This class allows tools, scanners, and the reflection system to access
/// package-specific information like name, version, and file location.
///
/// Example:
/// ```dart
/// Package pkg = ...;
/// print(pkg.getName()); // => "jetleaf"
/// print(pkg.getIsRootPackage()); // => true
/// ```
/// {@endtemplate}
abstract class Package extends ResourceDeclaration {
  /// Returns the name of the package (e.g., `'jetleaf'`, `'args'`).
  final String _name;

  /// Returns the version of the package (e.g., `'2.7.0'`).
  final String _version;

  /// Returns the Dart language version constraint (e.g., `'3.3'`), or `null` if unspecified.
  final String? _languageVersion;

  /// Returns `true` if this is the root application package.
  final bool _isRootPackage;

  /// Returns the absolute file system path of the package root (or `null` if unavailable).
  final String? _filePath;

  /// Returns the root URI of the package (or `null` if unavailable).
  final String? _rootUri;

  /// {@macro package}
  const Package({
    required String name,
    required String version,
    String? languageVersion,
    required bool isRootPackage,
    String? filePath,
    String? rootUri,
  }) : _filePath = filePath, _languageVersion = languageVersion, _version = version, _name = name, _isRootPackage = isRootPackage, _rootUri = rootUri;

  /// Returns the name of the package.
  String getName() => _name;

  /// Returns the version of the package.
  String getVersion() => _version;

  /// Returns the language version of the package.
  String? getLanguageVersion() => _languageVersion;

  /// Returns whether the package is the root package.
  bool getIsRootPackage() => _isRootPackage;

  /// Returns the file path of the package.
  String? getFilePath() => _filePath;

  /// Returns the root URI of the package.
  String? getRootUri() => _rootUri;

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['name'] = getName();
    result['version'] = getVersion();

    if (getLanguageVersion() != null) {
      result['languageVersion'] = getLanguageVersion()!;
    }
    result['isRootPackage'] = getIsRootPackage();

    if (getFilePath() != null) {
      result['filePath'] = getFilePath()!;
    }
    if (getRootUri() != null) {
      result['rootUri'] = getRootUri()!;
    }

    return result;
  }
}

/// {@template asset}
/// 🍃 JetLeaf Framework - Represents a non-Dart static resource (e.g., HTML, CSS, images).
///
/// The compiler generates implementations of this class to expose metadata
/// and raw content for embedded or served assets during runtime.
///
/// Represents a static asset (e.g., HTML, CSS, JS, images, or any binary file)
/// that is bundled with the project but not written in Dart code.
///
/// This is typically used in frameworks like JetLeaf for handling:
/// - Static web resources (HTML templates, stylesheets)
/// - Server-rendered views
/// - Embedded images or configuration files
///
/// These assets are typically provided via compiler-generated implementations
/// and may be embedded in memory or referenced via file paths.
///
/// ### Example
/// ```dart
/// final asset = MyGeneratedAsset(); // implements Asset
/// print(asset.getFilePath()); // "resources/index.html"
/// print(Closeable.DEFAULT_ENCODING.decode(asset.getContentBytes())); // "<html>...</html>"
/// ```
/// {@endtemplate}
abstract class Asset extends ResourceDeclaration {
  /// The relative file path of the asset (e.g., `'resources/index.html'`).
  final String _filePath;

  /// The name of the asset file (e.g., `'index.html'`).
  final String _fileName;

  /// The name of the package this asset belongs to (e.g., `'jetleaf'`).
  final String _packageName;

  /// The raw binary contents of this asset.
  final Uint8List _contentBytes;

  /// {@macro asset}
  const Asset({
    required String filePath,
    required String fileName,
    required String packageName,
    required Uint8List contentBytes,
  }) : _filePath = filePath, _fileName = fileName, _packageName = packageName, _contentBytes = contentBytes;

  /// Returns a unique name for the asset, combining the package name and file name.
  String getUniqueName() => "${_packageName}_${_fileName.split(".").first}";

  /// Returns the name of the file (same as [_fileName]).
  String getFileName() => _fileName;

  /// Returns the full path to the file (same as [_filePath]).
  String getFilePath() => _filePath;

  /// Returns the name of the originating package (same as [_packageName]).
  String? getPackageName() => _packageName;

  /// Returns the binary content of the asset (same as [_contentBytes]).
  Uint8List getContentBytes() => _contentBytes;

  @override
  Map<String, Object> toJson() {
    return {
      'filePath': getFilePath(),
      'fileName': getFileName(),
      'packageName': getPackageName() ?? "Unknown",
      'contentBytes': getContentBytes()
    };
  }
}

/// {@template asset_extension}
/// Extension methods for [Asset] objects.
/// 
/// Provides additional functionality for [Asset] objects, such as
/// retrieving the content as a string.
/// 
/// {@endtemplate}
extension AssetExtension on Asset {
  /// {@macro asset_extension}
  /// 
  /// ## Example
  /// ```dart
  /// final asset = Asset.fromFile('index.html');
  /// final content = asset.getContentAsString();
  /// print(content);
  /// ```
  String getContentAsString() {
    try {
      final file = File(getFilePath());
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        return content;
      }

      return DEFAULT_ENCODING.decode(getContentBytes());
    } catch (e) {
      try {
        return DEFAULT_ENCODING.decode(getContentBytes());
      } catch (e) {
        try {
          return String.fromCharCodes(getContentBytes());
        } catch (e) {
          throw BuildException('Failed to parse asset ${getFileName()}: $e');
        }
      }
    }
  }
}