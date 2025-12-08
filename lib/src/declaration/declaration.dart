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
import 'dart:typed_data';

import 'package:analyzer/dart/element/element.dart' show Element;
import 'package:analyzer/dart/element/type.dart' show DartType, ParameterizedType;
import 'package:meta/meta.dart';

import '../exceptions.dart';
import '../helpers/equals_and_hash_code.dart';
import '../runtime_provider/meta_runtime_provider.dart';

part '_declaration.dart';

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

  /// The analyzer DartType of the entity for enhanced type operations.
  /// 
  /// This provides access to the analyzer's type system for:
  /// - Accurate generic type information
  /// - Precise assignability checking
  /// - Complete inheritance relationships
  /// - Proper type parameter handling
  DartType? getDartType();

  /// The analyzer element associated with this declaration.
  /// 
  /// Provides access to the analyzer's element model for:
  /// - Source code information
  /// - Detailed metadata
  /// - Type parameter bounds
  /// - Member information
  Element? getElement();

  /// Returns true if this declaration has analyzer information available.
  bool hasAnalyzerSupport() => getDartType() != null || getElement() != null;

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

/// {@template type}
/// Represents metadata information about any Dart type — including classes,
/// enums, typedefs, generic types like `List<int>`, and even nullable types.
///
/// You can use this class to:
/// - Introspect type names and type arguments
/// - Determine type kind (list, map, class, enum, etc.)
/// - Resolve the declaration (e.g., to [ClassDeclaration] or [EnumDeclaration])
/// - Perform runtime type comparisons or assignability checks
///
/// ### Example
/// ```dart
/// final type = reflector.reflectType(MyClass);
/// print(type.getName()); // MyClass
///
/// if (type.asClassType() != null) {
///   final reflectedClass = type.asClassType()!;
///   print(reflectedClass.getConstructors());
/// }
/// ```
/// {@endtemplate}
abstract class TypeDeclaration extends EntityDeclaration {
  /// {@macro type}
  const TypeDeclaration();

  /// Returns the fully qualified name of this type.
  ///
  /// For example:
  /// ```
  /// "package:myapp/models.dart.BaseInterface"
  /// ```
  String getQualifiedName();

  /// Returns the simple name of the type without the package or library URI.
  ///
  /// Example:
  /// ```
  /// "BaseInterface"
  /// ```
  String getSimpleName();

  /// Returns the package URI where this type is declared.
  ///
  /// This is typically a `package:` URI such as:
  /// ```
  /// "package:myapp/models.dart"
  /// ```
  String getPackageUri();

  /// Returns the [TypeKind] of this type, indicating whether it is a class, enum, mixin, etc.
  ///
  /// This is useful when performing conditional logic based on what kind of type it is.
  ///
  /// ```dart
  /// if (identity.getKind() == TypeKind.classType) {
  ///   print("This is a class.");
  /// }
  /// ```
  TypeKind getKind();

  /// Returns `true` if the type is nullable, such as `'String?'` or `'int?'`.
  bool getIsNullable();

  /// #### Type Assignability Table:
  /// ```sql
  /// DART TYPE ASSIGNABILITY TABLE
  /// ────────────────────────────────────────────────────────────────────────────
  /// From (B) → To (A)                     A.isAssignableFrom(B)   Valid?   Notes
  /// ────────────────────────────────────────────────────────────────────────────
  /// Object    ← String                   ✅ true                  ✅      String extends Object
  /// String    ← Object                   ❌ false                 ❌      Super not assignable from subclass
  /// num       ← int                      ✅ true                  ✅      int is a subclass of num
  /// int       ← num                      ❌ false                 ❌      num is broader than int
  /// List<int> ← List<int>                ✅ true                  ✅      Same type
  /// List<T>   ← List<S>                  ❌ false                 ❌      Dart generics are invariant
  /// List<dynamic> ← List<int>            ❌ false                 ❌      Still invariant
  /// A         ← B (B extends A)          ✅ true                  ✅      Subclass to superclass is OK
  /// A         ← C (unrelated)            ❌ false                 ❌      No inheritance/interface link
  /// Interface ← Class implements Itf     ✅ true                  ✅      Implements is assignable to interface
  /// Mixin     ← Class with Mixin         ✅ true                  ✅      Mixed-in type present
  /// dynamic   ← anything                 ✅ true                  ✅      dynamic accepts all types
  /// anything  ← dynamic                  ✅ true (unsafe)         ✅      Allowed but unchecked
  /// Never     ← anything                 ❌ false                 ❌      Never can’t accept anything
  /// anything  ← Never                    ✅ true                  ✅      Never fits anywhere (bottom type)
  /// ────────────────────────────────────────────────────────────────────────────
  ///
  /// RULE OF THUMB:
  /// A.isAssignableFrom(B) → Can you do: A a = B();
  /// ✓ Subclass → Superclass: OK
  /// ✗ Superclass → Subclass: Not OK
  /// ✓ Class implements Interface → Interface: OK
  /// ✗ Interface → Class: Not OK
  /// ✓ Identical types: OK
  /// ✗ Unrelated types: Not OK
  /// ```
  ///
  /// Checks if this type is assignable from the given [other] type.
  /// 
  /// Returns `true` if a value of type [other] can be assigned to a variable of this type.
  /// This follows Dart's assignability rules including inheritance, interfaces, and mixins.
  bool isAssignableFrom(TypeDeclaration other);
  
  /// #### Type Assignability Table:
  /// ```sql
  /// DART TYPE ASSIGNABILITY TABLE
  /// ────────────────────────────────────────────────────────────────────────────
  /// From (A) → To (B)                   A.isAssignableTo(B)   Valid?   Notes
  /// ────────────────────────────────────────────────────────────────────────────
  /// String    → Object                 ✅ true               ✅      String extends Object
  /// Object    → String                 ❌ false              ❌      Superclass to subclass not allowed
  /// int       → num                    ✅ true               ✅      int is a subtype of num
  /// num       → int                    ❌ false              ❌      Can't assign broader to narrower
  /// List<int> → List<int>              ✅ true               ✅      Identical type
  /// List<S>   → List<T>                ❌ false              ❌      Dart generics are invariant
  /// List<int> → List<dynamic>          ❌ false              ❌      Invariant generics
  /// B         → A (B extends A)        ✅ true               ✅      Subclass to superclass: OK
  /// C         → A (no relation)        ❌ false              ❌      Unrelated types
  /// Class     → Interface (implements) ✅ true               ✅      Implements interface
  /// Class     → Mixin (with mixin)     ✅ true               ✅      Class includes mixin
  /// anything  → dynamic                ✅ true               ✅      Everything is assignable to dynamic
  /// dynamic   → anything               ✅ true (unchecked)   ✅      Allowed but unsafe
  /// anything  → Never                  ❌ false              ❌      Can't assign anything to Never
  /// Never     → anything               ✅ true               ✅      Never fits anywhere
  /// ────────────────────────────────────────────────────────────────────────────
  ///
  /// RULE OF THUMB:
  /// A.isAssignableTo(B) → Can you do: B b = A();
  /// ✓ Subclass → Superclass: OK
  /// ✗ Superclass → Subclass: Not OK
  /// ✓ Class → Interface it implements: OK
  /// ✗ Interface → Class: Not OK
  /// ✓ Identical types: OK
  /// ✗ Unrelated types: Not OK
  /// ```
  ///
  /// Checks if this type is assignable to the given [target] type.
  /// 
  /// Returns `true` if a value of this type can be assigned to a variable of type [target].
  /// This is the inverse of [isAssignableFrom].
  bool isAssignableTo(TypeDeclaration target);

  /// Check if this is a generic type.
  bool isGeneric();

  /// Returns the list of mixin identities that are applied to this type.
  ///
  /// This includes all mixins directly used in class declarations:
  ///
  /// ```dart
  /// class MyService with LoggingMixin {}
  /// ```
  /// In this case, `LoggingMixin` would appear in the result.
  List<LinkDeclaration> getMixins() => [];

  /// Returns the list of interfaces this type implements.
  ///
  /// This includes all interfaces declared in the `implements` clause.
  ///
  /// ```dart
  /// class MyService implements Disposable, Serializable {}
  /// ```
  /// Would return both `Disposable` and `Serializable`.
  List<LinkDeclaration> getInterfaces() => [];

  /// Returns the list of type arguments for generic types.
  ///
  /// If the type is not generic, this returns an empty list.
  /// For example, `List<String>` will return a list with one [LinkDeclaration] for `String`.
  List<LinkDeclaration> getTypeArguments() => [];

  /// Returns the direct superclass of this type.
  ///
  /// Returns `null` if this type has no superclass or extends `Object`.
  ///
  /// ```dart
  /// final superClass = identity.getSuperClass();
  /// print(superClass?.getQualifiedName()); // e.g., "package:core/BaseService"
  /// ```
  LinkDeclaration? getSuperClass();

  @override
  Map<String,Object> toJson() {
    Map<String, Object> result = {};

    result['declaration'] = 'type';
    result['name'] = getName();
    result['runtimeType'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();

    final arguments = getTypeArguments().map((t) => t.toJson()).toList();
    if(arguments.isNotEmpty) {
      result['typeArguments'] = arguments;
    }

    final declaration = getDeclaration()?.toJson();
    if(declaration != null) {
      result['declaration'] = declaration;
    }
    
    final classType = asClass()?.toJson();
    if(classType != null) {
      result['asClassType'] = classType;
    }
    
    final enumType = asEnum()?.toJson();
    if(enumType != null) {
      result['asEnumType'] = enumType;
    }
    
    final typedefType = asTypedef()?.toJson();
    if(typedefType != null) {
      result['asTypedefType'] = typedefType;
    }
    
    final recordType = asRecord()?.toJson();
    if(recordType != null) {
      result['asRecordType'] = recordType;
    }
    
    final mixinType = asMixin()?.toJson();
    if(mixinType != null) {
      result['asMixinType'] = mixinType;
    }
    
    final typeVariable = asTypeVariable()?.toJson();
    if(typeVariable != null) {
      result['asTypeVariable'] = typeVariable;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeDeclaration &&
          runtimeType == other.runtimeType && // Crucial for distinguishing concrete types
          getName() == other.getName() &&
          getType() == other.getType() &&
          getIsNullable() == other.getIsNullable() &&
          getKind() == other.getKind();

  @override
  int get hashCode =>
      getName().hashCode ^
      getType().hashCode ^
      getIsNullable().hashCode ^
      getKind().hashCode;

  @override
  String getDebugIdentifier() => 'ReflectedType(${getName()})';
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
  SourceDeclaration? getDeclaration() => asClass() ?? asEnum() ?? asTypedef() ?? asRecord() ?? asMixin() ?? asTypeVariable();

  /// Safely casts to [ClassDeclaration] if possible.
  ClassDeclaration? asClass() => this is ClassDeclaration ? this as ClassDeclaration? : null;

  /// Safely casts to [EnumDeclaration] if possible.
  EnumDeclaration? asEnum() => this is EnumDeclaration ? this as EnumDeclaration? : null;

  /// Safely casts to [TypedefDeclaration] if possible.
  TypedefDeclaration? asTypedef() => this is TypedefDeclaration ? this as TypedefDeclaration? : null;

  /// Safely casts to [RecordDeclaration] if possible.
  RecordDeclaration? asRecord() => this is RecordDeclaration ? this as RecordDeclaration? : null;

  /// Safely casts to [MixinDeclaration] if possible.
  MixinDeclaration? asMixin() => this is MixinDeclaration ? this as MixinDeclaration? : null;
  
  /// Safely casts to [TypeVariableDeclaration] if possible.
  TypeVariableDeclaration? asTypeVariable() => this is TypeVariableDeclaration ? this as TypeVariableDeclaration? : null;
}

/// {@template link_declaration}
/// Abstract base class for type references in reflection systems.
///
/// Represents a reference to a type declaration, including:
/// - Type arguments
/// - Pointer information
/// - Source location metadata
/// - Variance information
///
/// {@template link_declaration_features}
/// ## Key Features
/// - Type parameter resolution
/// - Source location tracking
/// - Variance awareness
/// - Canonical vs reference distinction
///
/// ## Typical Implementations
/// Used by:
/// - Generic type references
/// - Type alias resolutions
/// - Cross-library type references
/// {@endtemplate}
///
/// {@template link_declaration_example}
/// ## Example Usage
/// ```dart
/// final link = getTypeReference<List<String>>();
/// print(link.getPointerQualifiedName()); // "List"
/// print(link.getTypeArguments()[0].getName()); // "String"
/// print(link.getVariance()); // TypeVariance.invariant
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract class LinkDeclaration extends Declaration {
  const LinkDeclaration();

  /// Gets the type arguments for this reference.
  ///
  /// {@template get_type_arguments}
  /// Returns:
  /// - A list of [LinkDeclaration] for each type argument
  /// - Empty list for non-generic types
  /// - Preserves declaration order
  /// {@endtemplate}
  List<LinkDeclaration> getTypeArguments();

  /// Gets the base pointer type being referenced.
  ///
  /// {@template get_pointer_type}
  /// Returns:
  /// - The raw [Type] without type arguments
  /// - For `List<String>` returns `List`
  /// {@endtemplate}
  Type getPointerType();

  /// Gets the fully qualified name of the pointer type.
  ///
  /// {@template get_pointer_qualified_name}
  /// Returns:
  /// - The qualified name including library/package
  /// - Example: "package:collection/equality.dart#ListEquality"
  /// {@endtemplate}
  String getPointerQualifiedName();

  /// Gets the canonical definition location.
  ///
  /// {@template get_canonical_uri}
  /// Returns:
  /// - The [Uri] where the type is originally defined
  /// - `null` if location is unknown
  /// {@endtemplate}
  Uri? getCanonicalUri();

  /// Gets where this reference was found.
  ///
  /// {@template get_reference_uri}
  /// Returns:
  /// - The [Uri] where this reference appears
  /// - May differ from canonical location for imports/aliases
  /// {@endtemplate}
  Uri? getReferenceUri();

  /// Gets the upper bound for type variables.
  ///
  /// {@template get_upper_bound}
  /// Returns:
  /// - The [LinkDeclaration] representing the upper bound
  /// - `null` if no bound exists or not a type variable
  /// {@endtemplate}
  LinkDeclaration? getUpperBound();

  /// Gets the variance annotation for this reference.
  ///
  /// {@template get_variance}
  /// Returns:
  /// - The [TypeVariance] (covariant, contravariant, invariant)
  /// - Defaults to invariant for non-generic types
  /// {@endtemplate}
  TypeVariance getVariance();

  /// Checks if this reference points to its canonical definition.
  ///
  /// {@template get_is_canonical}
  /// Returns:
  /// - `true` if reference location matches canonical location
  /// - `false` for imported/aliased references
  /// {@endtemplate}
  bool getIsCanonical();
}

/// {@template record_field}
/// A representation of an individual field within a Dart record type in the
/// JetLeaf reflection system.
///
/// This abstraction allows inspecting both named and positional fields of a
/// record. Provides metadata such as name, position, type, and whether it's named.
///
/// ## Example
/// ```dart
/// final field = MyReflectedRecordField(...);
/// print(field.getIsNamed()); // true
/// ```
/// {@endtemplate}
abstract class RecordFieldDeclaration extends SourceDeclaration {
  /// {@macro record_field}
  const RecordFieldDeclaration();

  /// Returns the positional index of the field (starting at 0), or `null` if named.
  int? getPosition();

  /// Returns the [LinkDeclaration] of the record field.
  LinkDeclaration getLinkDeclaration();

  /// Returns true if the field is named.
  bool getIsNamed();

  /// Returns true if the field is nullable.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isNullable())); // [true]
  /// ```
  bool isNullable();

  /// Returns true if the field is positional.
  bool getIsPositional();
}

/// {@template record}
/// Represents a reflected Dart record type.
///
/// A Dart record consists of zero or more positional fields and optionally
/// named fields. This interface provides access to both positional and named
/// components of the record in a structured and introspectable form.
///
/// ## Example
/// ```dart
/// (int, String, {bool active}) record = (1, "hello", active: true);
///
/// ReflectedRecord reflected = ...;
/// reflected.getPositionalFields(); // returns field for int and String
/// reflected.getNamedFields();      // returns map with 'active': bool
/// ```
///
/// This type also implements [TypeDeclaration], so it can be treated like any
/// other reflected type (e.g., for kind, name, annotations, etc.).
/// {@endtemplate}
abstract class RecordDeclaration extends TypeDeclaration implements SourceDeclaration {
  /// {@macro record}
  const RecordDeclaration();

  /// Returns the list of positional fields in the record, in order of position.
  List<RecordFieldDeclaration> getPositionalFields();

  /// Returns a map of named fields in the record, keyed by their name.
  Map<String, RecordFieldDeclaration> getNamedFields();

  /// Returns the named field with the given [name], or `null` if not found.
  RecordFieldDeclaration? getField(String name);

  /// Returns the positional field at the given [index], or `null` if out of bounds.
  RecordFieldDeclaration? getPositionalField(int index);
}

/// {@template annotation}
/// Represents an annotation that has been applied to a class, method,
/// field, parameter, or other Dart declarations at runtime.
///
/// This interface gives you access to:
/// - The [TypeDeclaration] of the annotation
/// - The arguments used when the annotation was constructed
///
/// ### Example
/// ```dart
/// for (final annotation in reflectedClass.getAnnotations()) {
///   print(annotation.getTypeDeclaration().getName());
///   print(annotation.getArguments());
/// }
/// ```
/// {@endtemplate}
abstract class AnnotationDeclaration extends EntityDeclaration {
  /// {@macro annotation}
  const AnnotationDeclaration();

  /// Returns the type of the annotation.
  ///
  /// This allows inspection of the annotation's class, including whether it
  /// is a custom annotation or a built-in one.
  LinkDeclaration getLinkDeclaration();

  /// Returns the instance of the annotation.
  /// 
  /// This allows inspection of the annotation's instance, including its fields and methods.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final instance = annotation.getInstance();
  /// print(instance.toString());
  /// ```
  dynamic getInstance();

  /// Returns the fields of the annotation.
  /// 
  /// This list contains the fields of the annotation in the order they were declared.
  /// If no fields were declared, the list will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getName())); // ["value"]
  /// ```
  List<AnnotationFieldDeclaration> getFields();

  /// Returns the user provided values of the annotation.
  /// 
  /// This map contains the values that were provided by the user when the annotation was applied.
  /// If no values were provided, the map will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final values = annotation.getUserProvidedValues();
  /// print(values['value']); // "Hello"
  /// ```
  Map<String, dynamic> getUserProvidedValues();

  /// Returns a map of the annotation's fields, keyed by their name.
  /// 
  /// This map contains the fields of the annotation in the order they were declared.
  /// If no fields were declared, the map will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final mappedFields = annotation.getMappedFields();
  /// print(mappedFields['value']); // ReflectedAnnotationField(...)
  /// ```
  Map<String, AnnotationFieldDeclaration> getMappedFields();

  /// Returns a specific field by name.
  /// 
  /// If no field with the given name was declared, returns `null`.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final field = annotation.getField('value');
  /// print(field.getName()); // "value"
  /// ```
  AnnotationFieldDeclaration? getField(String name);

  /// Returns a list of the annotation's field names.
  /// 
  /// This list contains the names of the fields of the annotation in the order they were declared.
  /// If no fields were declared, the list will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fieldNames = annotation.getFieldNames();
  /// print(fieldNames); // ["value"]
  /// ```
  List<String> getFieldNames();

  /// Returns a map of the annotation's fields that have default values, keyed by their name.
  /// 
  /// This map contains the fields of the annotation that have default values in the order they were declared.
  /// If no fields have default values, the map will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fieldsWithDefaults = annotation.getFieldsWithDefaults();
  /// print(fieldsWithDefaults['value']); // ReflectedAnnotationField(...)
  /// ```
  Map<String, AnnotationFieldDeclaration> getFieldsWithDefaults();

  /// Returns a map of the annotation's fields that have user-provided values, keyed by their name.
  /// 
  /// This map contains the fields of the annotation that have user-provided values in the order they were declared.
  /// If no fields have user-provided values, the map will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fieldsWithUserValues = annotation.getFieldsWithUserValues();
  /// print(fieldsWithUserValues['value']); // ReflectedAnnotationField(...)
  /// ```
  Map<String, AnnotationFieldDeclaration> getFieldsWithUserValues();
}

/// {@template annotation_field}
/// Represents a field of an annotation.
/// 
/// This interface provides access to:
/// - The field's name
/// - The field's type
/// - The value of the field
/// 
/// ### Example
/// ```dart
/// final annotation = ...;
/// final fields = annotation.getFields();
/// print(fields.map((f) => f.getName())); // ["value"]
/// ```
/// {@endtemplate}
abstract class AnnotationFieldDeclaration extends EntityDeclaration {
  /// {@macro annotation_field}
  const AnnotationFieldDeclaration();

  /// Returns the type of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getTypeDeclaration().getName())); // ["value"]
  /// ```
  LinkDeclaration getLinkDeclaration();

  /// Returns the value of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getValue())); // ["value"]
  /// ```
  dynamic getValue();

  /// Returns the default value of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getDefaultValue())); // ["value"]
  /// ```
  dynamic getDefaultValue();

  /// Returns the user provided value of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getUserProvidedValue())); // ["value"]
  /// ```
  dynamic getUserProvidedValue();

  /// Returns true if the field has a default value.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.hasDefaultValue())); // [true]
  /// ```
  bool hasDefaultValue();

  /// Returns true if the field has a user provided value.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.hasUserProvidedValue())); // [true]
  /// ```
  bool hasUserProvidedValue();

  /// Returns true if the field is nullable.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isNullable())); // [true]
  /// ```
  bool isNullable();

  /// Returns true if the field is final.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isFinal())); // [true]
  /// ```
  bool isFinal();

  /// Returns true if the field is const.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isConst())); // [true]
  /// ```
  bool isConst();

  /// Returns the position of the field in the source code.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getPosition())); // [1]
  /// ```
  int getPosition();
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

/// {@template parameter}
/// Represents a parameter in a constructor or method, with metadata about
/// its name, type, position (named or positional), and default value.
///
/// ### Example
/// ```dart
/// final method = clazz.getMethods().first;
/// for (final param in method.getParameters()) {
///   print(param.getName()); // e.g., "value"
///   print(param.getTypeDeclaration().getName()); // e.g., "String"
/// }
/// ```
/// {@endtemplate}
abstract class ParameterDeclaration extends SourceDeclaration {
  /// {@macro parameter}
  const ParameterDeclaration();

  /// The index of the parameter
  int getIndex();

  /// Returns the [LinkDeclaration] of the parameter.
  LinkDeclaration getLinkDeclaration();

  /// Returns the [MemberDeclaration] that this parameter belongs to.
  MemberDeclaration getMemberDeclaration();

  /// Returns `true` if the parameter is optional (either named or positional).
  bool getIsNullable();

  /// Returns `true` if the parameter is a named parameter.
  bool getIsNamed();

  /// Returns `true` if the parameter has a default value.
  bool getHasDefaultValue();

  /// Returns the default value of the parameter, or `null` if none.
  ///
  /// If the parameter doesn't have a default or it is not applicable,
  /// this returns `null`.
  dynamic getDefaultValue();
}

/// {@template library}
/// Represents a Dart library, providing access to its URI, the
/// containing package, and all top-level declarations inside it.
///
/// Libraries in Dart map directly to `.dart` files and can expose
/// multiple classes, functions, and constants.
///
/// ### Example
/// ```dart
/// final library = reflector.getLibraries().firstWhere(
///   (lib) => lib.getUri().contains('my_library.dart'),
/// );
/// print(library.getParentPackage().getName());
/// for (final decl in library.getDeclarations()) {
///   print(decl.getName());
/// }
/// ```
/// {@endtemplate}
abstract class LibraryDeclaration extends SourceDeclaration {
  /// {@macro library}
  const LibraryDeclaration();

  /// Returns the URI of the library (e.g., `'package:my_app/main.dart'`).
  String getUri();

  /// Returns the [Package] that this library is part of.
  Package getPackage();

  /// Returns all top-level [SourceDeclaration]s in the library.
  ///
  /// This may include:
  /// - Classes
  /// - Typedefs
  /// - Enums
  /// - Top-level functions and fields
  List<SourceDeclaration> getDeclarations();

  /// Returns all [ClassDeclaration] instances declared directly in this library.
  List<ClassDeclaration> getClasses();

  /// Returns all [EnumDeclaration] instances declared directly in this library.
  List<EnumDeclaration> getEnums();

  /// Returns all [TypedefDeclaration] instances declared directly in this library.
  List<TypedefDeclaration> getTypedefs();

  /// Returns all [ExtensionDeclaration] instances declared directly in this library.
  List<ExtensionDeclaration> getExtensions();

  /// Returns all top-level [MethodDeclaration] instances declared directly in this library.
  List<MethodDeclaration> getTopLevelMethods();

  /// Returns all top-level [FieldDeclaration] instances declared directly in this library.
  List<FieldDeclaration> getTopLevelFields();

  /// Returns all top-level [RecordDeclaration] instances declared directly in this library.
  List<RecordDeclaration> getTopLevelRecords();

  /// Returns all top-level [RecordFieldDeclaration] instances declared directly in this library.
  List<RecordFieldDeclaration> getTopLevelRecordFields();

  @override
  String getName() => getUri(); // Libraries typically use their URI as their identifier.
}

/// {@template mixin}
/// Represents a reflected Dart `mixin` declaration, providing access to its
/// members, type constraints, and metadata.
///
/// Mixins in Dart allow code reuse across multiple class hierarchies. This
/// interface provides runtime introspection of mixin declarations, including
/// their fields, methods, type constraints, and annotations.
///
/// ### Example
/// ```dart
/// mixin TimestampMixin on BaseModel {
///   DateTime? createdAt;
///   DateTime? updatedAt;
///   
///   void updateTimestamp() {
///     updatedAt = DateTime.now();
///   }
/// }
///
/// final mixinType = reflector.reflectType(TimestampMixin).asMixinType();
/// print(mixinType?.getName()); // TimestampMixin
/// print(mixinType?.getFields().length); // 2
/// print(mixinType?.getMethods().length); // 1
/// ```
///
/// This interface combines both [SourceDeclaration] and [TypeDeclaration],
/// allowing it to be used both as a type descriptor and a declaration node.
/// {@endtemplate}
abstract class MixinDeclaration extends TypeDeclaration implements SourceDeclaration {
  /// {@macro mixin}
  const MixinDeclaration();

  /// Returns all members declared in this mixin, including fields and methods.
  ///
  /// ### Example
  /// ```dart
  /// for (final member in mixin.getMembers()) {
  ///   print(member.getName());
  /// }
  /// ```
  List<MemberDeclaration> getMembers();

  /// Returns all fields declared in this mixin (excluding inherited fields).
  ///
  /// ### Example
  /// ```dart
  /// for (final field in mixin.getFields()) {
  ///   print('${field.getName()}: ${field.getTypeDeclaration().getName()}');
  /// }
  /// ```
  List<FieldDeclaration> getFields();

  /// Returns all methods declared in this mixin (excluding inherited methods).
  ///
  /// ### Example
  /// ```dart
  /// for (final method in mixin.getMethods()) {
  ///   print('${method.getName()}() -> ${method.getReturnType().getName()}');
  /// }
  /// ```
  List<MethodDeclaration> getMethods();

  /// Returns the `on` constraint types for this mixin.
  ///
  /// For example, in `mixin MyMixin on BaseClass, SomeInterface`,
  /// this returns a list with [TypeDeclaration]s for `BaseClass` and `SomeInterface`.
  ///
  /// Returns an empty list if the mixin has no `on` constraints.
  List<LinkDeclaration> getConstraints();

  /// Returns `true` if this mixin has `on` type constraints.
  bool getHasConstraints();

  /// Returns `true` if this mixin implements any interfaces.
  bool getHasInterfaces();

  /// Returns all instance fields declared in this mixin.
  List<FieldDeclaration> getInstanceFields();

  /// Returns all static fields declared in this mixin.
  List<FieldDeclaration> getStaticFields();

  /// Returns all instance methods declared in this mixin.
  List<MethodDeclaration> getInstanceMethods();

  /// Returns all static methods declared in this mixin.
  List<MethodDeclaration> getStaticMethods();

  /// Returns a field by name, or null if not found.
  FieldDeclaration? getField(String fieldName);

  /// Returns a method by name, or null if not found.
  MethodDeclaration? getMethod(String methodName);

  /// Checks if this mixin has a field with the given name.
  bool hasField(String fieldName);

  /// Checks if this mixin has a method with the given name.
  bool hasMethod(String methodName);
}

/// {@template class}
/// Represents a reflected Dart class and all of its metadata, including
/// fields, methods, constructors, superclasses, mixins, interfaces, and
/// declaration-level modifiers (abstract, sealed, etc.).
///
/// This interface combines both [SourceDeclaration] and [TypeDeclaration],
/// allowing it to be used both as a type descriptor and a declaration node.
///
/// Use this class to introspect:
/// - Class members: fields, methods, constructors
/// - Generic type parameters
/// - Supertype, mixins, and implemented interfaces
/// - Modifiers like `abstract`, `sealed`, `base`, etc.
/// - Runtime instantiation via `newInstance()`
///
/// ### Example
/// ```dart
/// final type = reflector.reflectType(MyService).asClassType();
/// print('Class: ${type?.getName()}');
///
/// for (final method in type!.getMethods()) {
///   print('Method: ${method.getName()}');
/// }
///
/// final instance = type.newInstance({'message': 'Hello'});
/// ```
/// {@endtemplate}
abstract class ClassDeclaration extends TypeDeclaration implements SourceDeclaration {
  /// {@macro class}
  const ClassDeclaration();

  /// Returns all members declared in this class, including fields, methods, and constructors.
  ///
  /// ### Example
  /// ```dart
  /// for (final member in clazz.getMembers()) {
  ///   print(member.getName());
  /// }
  /// ```
  List<MemberDeclaration> getMembers();

  /// Returns all constructors declared in this class.
  ///
  /// This allows you to introspect constructor names, parameters, and metadata.
  List<ConstructorDeclaration> getConstructors();

  /// Returns all fields declared in this class (excluding inherited fields).
  ///
  /// ### Example
  /// ```dart
  /// for (final field in clazz.getFields()) {
  ///   print(field.getName());
  /// }
  /// ```
  List<FieldDeclaration> getFields();

  /// Returns all methods declared in this class (excluding inherited methods).
  ///
  /// ### Example
  /// ```dart
  /// for (final method in clazz.getMethods()) {
  ///   print(method.getName());
  /// }
  /// ```
  List<MethodDeclaration> getMethods();

  /// Returns all records declared in this class (excluding inherited records).
  List<RecordDeclaration> getRecords();

  /// Returns `true` if this class is marked `abstract`.
  bool getIsAbstract();

  /// Returns `true` if this is a `mixin` declaration or a mixin application.
  bool getIsMixin();

  /// Returns `true` if this class is marked `sealed`.
  bool getIsSealed();

  /// Returns `true` if this class is marked `base`.
  bool getIsBase();

  /// Returns `true` if this class is declared as an `interface`.
  bool getIsInterface();

  /// Returns `true` if this class is marked `final`.
  bool getIsFinal();

  /// Returns `true` if this class is a `record class` (e.g., a class wrapping a record).
  bool getIsRecord();

  /// Instantiates this class using the default (unnamed) constructor.
  ///
  /// [arguments] is a map where keys are parameter names and values are passed to the constructor.
  ///
  /// ### Example
  /// ```dart
  /// final instance = clazz.newInstance({'name': 'John', 'age': 30});
  /// print(instance); // Instance of MyClass
  /// ```
  ///
  /// > **Note:** In a real reflection system, this would delegate to generated code
  /// or a dynamic factory registry.
  dynamic newInstance(Map<String, dynamic> arguments);
}

/// {@template enum}
/// Represents a reflected Dart `enum` type, providing access to its
/// enum entry names, metadata, and declared members (fields, methods).
///
/// This interface combines both [SourceDeclaration] and [TypeDeclaration],
/// and allows you to inspect enums dynamically at runtime.
///
/// ### Example
/// ```dart
/// final type = reflector.reflectType(MyEnum).asEnumType();
///
/// print(type?.getName()); // MyEnum
/// print(type?.getValues()); // [active, inactive, unknown]
///
/// for (final member in type!.getMembers()) {
///   print(member.getName());
/// }
/// ```
/// {@endtemplate}
abstract class EnumDeclaration extends TypeDeclaration implements SourceDeclaration {
  /// {@macro enum}
  const EnumDeclaration();

  /// Returns the list of enum value names declared in this enum.
  ///
  /// ### Example
  /// ```dart
  /// final values = enumType.getValues();
  /// print(values); // ['small', 'medium', 'large']
  /// ```
  List<EnumFieldDeclaration> getValues();

  /// Returns all members (fields and methods) declared in this enum.
  ///
  /// These may include custom getters, fields, or methods declared inside
  /// the enum body.
  ///
  /// ### Example
  /// ```dart
  /// for (final member in enumType.getMembers()) {
  ///   print(member.getName());
  /// }
  /// ```
  List<MemberDeclaration> getMembers();
}

/// {@template enum_field_declaration}
/// Abstract base class representing a field (value) within an enum declaration.
///
/// Provides reflective access to enum value metadata including:
/// - Name and value of the enum field
/// - Type information
/// - Parent enum declaration
///
/// {@template enum_field_declaration_features}
/// ## Key Features
/// - Enum value name access
/// - Raw value inspection
/// - Type-safe enum value handling
/// - Parent enum resolution
///
/// ## Implementations
/// Typically implemented by code generators or runtime reflection systems.
/// {@endtemplate}
///
/// {@template enum_field_declaration_example}
/// ## Example Usage
/// ```dart
/// enum Status { active, paused }
///
/// final enumDecl = reflector.getEnumDeclaration(Status);
/// final activeField = enumDecl.getField('active');
///
/// print(activeField.getName()); // 'active'
/// print(activeField.getValue()); // Status.active
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract class EnumFieldDeclaration extends SourceDeclaration {
  /// Creates a new enum field declaration.
  const EnumFieldDeclaration();

  /// Gets the runtime value of this enum field.
  ///
  /// {@template enum_field_get_value}
  /// Returns:
  /// - The actual enum value instance
  ///
  /// Example:
  /// ```dart
  /// final value = field.getValue(); // Returns Status.active
  /// ```
  /// {@endtemplate}
  dynamic getValue();

  /// This is the position of the enum field, as-is on the enum class.
  /// 
  /// Example:
  /// ```dart
  /// final position = field.getPosition(); // Returns 1
  /// ```
  int getPosition();

  /// Returns true if the field is nullable.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isNullable())); // [true]
  /// ```
  bool isNullable();
}

/// {@template typedef}
/// Represents a reflected Dart `typedef`, which is a type alias for a
/// function type, class type, or any other complex type.
///
/// Provides access to the aliased type, type parameters, and runtime metadata.
///
/// ### Example
/// ```dart
/// typedef Mapper<T> = T Function(String);
///
/// final typedefType = reflector.reflectType(Mapper).asTypedef();
/// print(typedefType?.getName()); // Mapper
/// print(typedefType?.getAliasedType().getName()); // Function
/// ```
/// {@endtemplate}
abstract class TypedefDeclaration extends TypeDeclaration implements SourceDeclaration {
  /// {@macro typedef}
  const TypedefDeclaration();

  /// Returns the type that this typedef aliases.
  ///
  /// ### Example
  /// ```dart
  /// final alias = typedefType.getAliasedType();
  /// print(alias.getName()); // Function
  /// ```
  TypeDeclaration getAliasedType();
}

/// {@template extension}
/// Represents a Dart `extension` declaration at runtime.
///
/// Provides access to the type being extended and the members defined in
/// the extension (methods, getters, setters, etc.).
///
/// ### Example
/// ```dart
/// extension MyStringExtension on String {
///   String reversed() => split('').reversed.join();
/// }
///
/// final extension = reflector.reflectExtension('MyStringExtension');
/// print(extension.getExtendedType().getName()); // String
/// for (final member in extension.getMembers()) {
///   print(member.getName()); // reversed
/// }
/// ```
/// {@endtemplate}
abstract class ExtensionDeclaration extends SourceDeclaration {
  /// {@macro extension}
  const ExtensionDeclaration();

  /// Returns the [TypeDeclaration] that this extension is declared on.
  ///
  /// For example, in:
  /// ```dart
  /// extension MyListUtils on List<int> {
  ///   int get firstOrZero => isEmpty ? 0 : first;
  /// }
  /// ```
  /// `getExtendedType()` returns the reflected type for `List<int>`.
  TypeDeclaration getExtendedType();

  /// Returns the list of members (methods, fields, etc.) defined in this extension.
  ///
  /// This includes:
  /// - Instance methods
  /// - Getters/setters
  /// - Fields (if supported)
  List<MemberDeclaration> getMembers();
}

/// {@template field}
/// Represents a field (variable) declared within a Dart class, extension, enum, or mixin.
///
/// Provides access to its type, modifiers (`final`, `late`, `const`, `static`),
/// and the ability to read or write its value at runtime.
///
/// ### Example
/// ```dart
/// class Person {
///   final String name;
///   static int count = 0;
/// }
///
/// final field = reflector.reflectField(Person, 'name');
/// print(field.getIsFinal()); // true
/// print(field.getTypeDeclaration().getName()); // String
///
/// final p = Person('Jet');
/// print(field.getValue(p)); // Jet
/// ```
/// {@endtemplate}
abstract class FieldDeclaration extends MemberDeclaration {
  /// {@macro field}
  const FieldDeclaration();

  /// Returns the [LinkDeclaration] of this field.
  ///
  /// For example, in `int age = 10;`, this returns the reflected type for `int`.
  LinkDeclaration getLinkDeclaration();

  /// Whether this field is declared `final`.
  bool getIsFinal();

  /// Whether this field is declared `const`.
  bool getIsConst();

  /// Whether this field is declared `late`.
  bool getIsLate();

  /// Returns true if the field is nullable.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isNullable())); // [true]
  /// ```
  bool isNullable();

  /// Whether this field is `static`.
  ///
  /// Overrides [MemberDeclaration.getIsStatic] to ensure field-specific behavior.
  @override
  bool getIsStatic();

  /// Returns the value of this field on the given [instance].
  ///
  /// - If the field is static, [instance] must be `null`.
  /// - If the field is instance-based, [instance] must be a valid object.
  ///
  /// Throws if the field cannot be read.
  dynamic getValue(dynamic instance);

  /// Sets the value of this field on the given [instance].
  ///
  /// - If the field is static, [instance] must be `null`.
  /// - If the field is instance-based, [instance] must be a valid object.
  ///
  /// Throws if the field is `final`, `const`, or cannot be written to.
  void setValue(dynamic instance, dynamic value);
}

/// {@template method}
/// Represents a method declaration in a Dart class, extension, mixin, or top-level scope.
///
/// Provides full metadata about the method's return type, parameters, type parameters,
/// and modifiers (`static`, `abstract`, `getter`, `setter`). Also allows invoking the method
/// at runtime with named arguments.
///
/// ### Example
/// ```dart
/// class Calculator {
///   int add(int a, int b) => a + b;
/// }
///
/// final method = reflector.reflectMethod(Calculator, 'add');
/// print(method.getReturnType().getName()); // int
///
/// final result = method.invoke(Calculator(), {'a': 3, 'b': 4});
/// print(result); // 7
/// ```
///
/// This class is also used for getters and setters:
/// ```dart
/// class Example {
///   String get title => 'Jet';
///   set title(String value) {}
/// }
///
/// final getter = reflector.reflectMethod(Example, 'title');
/// print(getter.getIsGetter()); // true
/// ```
/// {@endtemplate}
abstract class MethodDeclaration extends MemberDeclaration {
  /// {@macro method}
  const MethodDeclaration();

  /// Returns the return type of the method.
  LinkDeclaration getReturnType();

  /// Returns all parameters accepted by this method.
  ///
  /// Includes positional, named, and optional parameters in declaration order.
  List<ParameterDeclaration> getParameters();

  /// Whether this method is a `getter`.
  bool getIsGetter();

  /// Whether this method is a `setter`.
  bool getIsSetter();

  /// Whether this method is a `factory`.
  bool getIsFactory();

  /// Whether this method is a `const`.
  bool getIsConst();

  /// Invokes this method on the given [instance].
  ///
  /// - If the method is static, [instance] must be `null`.
  /// - [arguments] must be a map where the keys match parameter names.
  ///
  /// Throws if the invocation fails or the arguments are invalid.
  ///
  /// ### Example
  /// ```dart
  /// final result = method.invoke(myObject, {'param1': 42, 'param2': 'ok'});
  /// ```
  dynamic invoke(dynamic instance, Map<String, dynamic> arguments);
}

/// {@template constructor}
/// Represents a constructor of a Dart class, including its parameters,
/// modifiers (`const`, `factory`), and the ability to create new instances.
///
/// This abstraction allows runtime instantiation of classes using metadata.
///
/// ### Example
/// ```dart
/// class Person {
///   final String name;
///   final int age;
///
///   Person(this.name, this.age);
/// }
///
/// final constructor = reflector.reflectConstructor(Person);
/// final person = constructor.newInstance({'name': 'Alice', 'age': 30});
/// print(person.name); // Alice
/// ```
///
/// This is especially useful in frameworks like dependency injection,
/// serialization, and code generation where runtime construction is needed.
/// {@endtemplate}
abstract class ConstructorDeclaration extends MemberDeclaration {
  /// {@macro constructor}
  const ConstructorDeclaration();

  /// Returns all parameters required by this constructor.
  ///
  /// Includes positional, named, and optional parameters in declaration order.
  List<ParameterDeclaration> getParameters();

  /// Whether this constructor is a `factory`.
  bool getIsFactory();

  /// Whether this constructor is declared `const`.
  bool getIsConst();

  /// Creates a new instance of the declaring class using this constructor.
  ///
  /// [arguments] is a map of parameter names to their values.
  ///
  /// ### Example
  /// ```dart
  /// final instance = constructor.newInstance({
  ///   'name': 'JetLeaf',
  ///   'version': 1,
  /// });
  /// ```
  ///
  /// Throws if the arguments do not match the constructor's requirements.
  T newInstance<T>(Map<String, dynamic> arguments);
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