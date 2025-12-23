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

import '../../argument/executable_argument.dart';
import '../../exceptions.dart';
import '../../helpers/equals_and_hash_code.dart';
import '../../helpers/qualified_name.dart';
import '../../helpers/to_string.dart';
import '../../utils/generic_type_parser.dart';
import '../provider/runtime_provider.dart';

part '_declaration.dart';
part 'annotation_declaration.dart';
part 'class_declaration.dart';
part 'constructor_declaration.dart';
part 'enum_declaration.dart';
part 'field_declaration.dart';
part 'function_declaration.dart';
part 'library_declaration.dart';
part 'link_declaration.dart';
part 'method_declaration.dart';
part 'mixin_declaration.dart';
part 'parameter_declaration.dart';
part 'record_declaration.dart';
part 'asset.dart';
part 'package.dart';
part 'closure_declaration.dart';

/// {@template type_kind}
/// Enumerates the different **kinds of Dart types** recognized by JetLeaf’s
/// reflection and type resolution system.
///
/// [TypeKind] provides a standardized classification for all materialized
/// types, including classes, enums, typedefs, collections, primitives,
/// functions, and unresolved types.
///
/// This enum is used to:
/// - Distinguish type categories at runtime and during code generation
/// - Drive type-specific logic in reflection, serialization, and generation
/// - Enable deterministic type resolution across packages and libraries
///
/// Each value corresponds to a **semantic category** of Dart type, not
/// necessarily to its runtime representation.
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
  /// Represents a typedef type such as `(int, String)`.
  typedef,

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
  /// Represents Dart’s `dynamic` type.
  dynamicType,

  /// {@macro type_kind}
  ///
  /// Represents Dart’s `void` type.
  voidType,

  /// {@macro type_kind}
  ///
  /// Represents a closure.
  closureType,

  /// {@macro type_kind}
  ///
  /// Represents a Dart mixin.
  mixinType,

  /// {@macro type_kind}
  ///
  /// Represents a type that could not be resolved or identified.
  unknownType,
}

/// {@template base_declaration}
/// Base abstraction for all JetLeaf declaration models.
///
/// [BaseDeclaration] represents the **lowest-level declaration contract**
/// shared by every declaration type in the JetLeaf metadata system.
///
/// ---
///
/// #### Responsibilities
///
/// - Provide a stable JSON serialization surface
/// - Define structural equality via [EqualsAndHashCode]
/// - Offer a consistent string representation for diagnostics
///
/// ---
///
/// #### Design Notes
///
/// - This class is intentionally minimal
/// - Subclasses are expected to enrich the metadata model
/// - Equality semantics are delegated to [EqualsAndHashCode]
///
/// All JetLeaf declarations ultimately derive from this type.
/// {@endtemplate}
abstract class BaseDeclaration with EqualsAndHashCode {
  /// Creates a new declaration base instance.
  ///
  /// Subclasses are expected to be immutable.
  /// 
  /// {@macro base_declaration}
  const BaseDeclaration();

  /// Serializes this declaration into a JSON-compatible map.
  ///
  /// The returned map must:
  /// - Contain only JSON-encodable values
  /// - Fully describe the declaration’s identity and structure
  ///
  /// This method is used for:
  /// - Debugging
  /// - Tooling output
  /// - Snapshot comparisons
  Map<String, Object> toJson();

  @override
  String toString() => toJson().toString();
}

/// {@template declaration}
/// A named, typed declaration representing a concrete program element.
///
/// [Declaration] extends [BaseDeclaration] with **language-level identity**
/// such as name, type, visibility, and synthetic status.
///
/// ---
///
/// #### What This Represents
///
/// This abstraction is used for:
/// - Classes
/// - Methods
/// - Fields
/// - Constructors
/// - Parameters
///
/// Any declaration that has:
/// - A name
/// - A Dart type
/// - Visibility semantics
///
/// ---
///
/// #### Visibility & Origin
///
/// JetLeaf distinguishes between:
/// - **Public vs private** declarations
/// - **User-authored vs synthetic** declarations
///
/// These distinctions are critical for:
/// - Reflection safety
/// - Code generation
/// - API surface control
///
/// ---
///
/// #### Immutability
///
/// Implementations must be immutable and thread-safe.
/// {@endtemplate}
abstract final class Declaration extends BaseDeclaration {
  /// {@macro declaration}
  const Declaration();

  /// Returns the simple (unqualified) name of this declaration.
  ///
  /// Examples:
  /// - Class name
  /// - Method name
  /// - Field identifier
  String getName();

  /// Returns the Dart [Type] represented by this declaration.
  ///
  /// This is the runtime type used for reflection and invocation.
  Type getType();

  /// Indicates whether this declaration is **publicly visible**.
  ///
  /// Returns `true` for public declarations and `false` for private ones.
  bool getIsPublic();

  /// Indicates whether this declaration is **synthetic**.
  ///
  /// Synthetic declarations are generated by the compiler or tooling
  /// rather than authored directly by the user.
  ///
  /// Examples:
  /// - Implicit constructors
  /// - Generated backing fields
  bool getIsSynthetic();

  @override
  String toString() => toJson().toString();
}

/// {@template entity_declaration}
/// A uniquely identifiable declaration representing a **runtime entity**.
///
/// [EntityDeclaration] introduces a **stable debug identity** used for:
/// - Equality comparison
/// - Hash-based collections
/// - Cross-runtime correlation
///
/// ---
///
/// #### What Is an Entity?
///
/// An entity declaration represents something that:
/// - Exists as a distinct runtime symbol
/// - Must be uniquely identifiable within the reflection scope
///
/// Common examples include:
/// - Classes
/// - Enums
/// - Mixins
/// - Top-level functions
///
/// ---
///
/// #### Identity & Equality
///
/// Equality for [EntityDeclaration] is **not structural**.
///
/// Two entity declarations are considered equal if and only if:
/// - They have the same runtime type
/// - They expose the same [getDebugIdentifier]
///
/// This ensures:
/// - Stable identity across generator runs
/// - Correct behavior in caches and registries
///
/// ---
///
/// #### Debug Identifier
///
/// The debug identifier must:
/// - Be globally unique within the runtime
/// - Remain stable across reflection lifecycles
/// - Not depend on object identity
/// {@endtemplate}
abstract final class EntityDeclaration extends Declaration {
  /// {@macro entity_declaration}
  const EntityDeclaration();

  /// Returns the **stable debug identifier** for this entity.
  ///
  /// This value is used as the authoritative identity for:
  /// - Equality checks
  /// - Hash code computation
  /// - Runtime and build-time correlation
  String getDebugIdentifier();

  @override
  String toString() => toJson().toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is EntityDeclaration &&
        getDebugIdentifier() == other.getDebugIdentifier();
  }

  @override
  int get hashCode => getDebugIdentifier().hashCode;
}

/// {@template source_declaration}
/// A declaration that originates directly from **source-level Dart code**.
///
/// [SourceDeclaration] represents declarations that can be traced back to
/// a concrete location in source code, such as:
/// - Classes
/// - Members (methods, fields, constructors)
/// - Top-level declarations
///
/// Unlike purely synthetic or runtime-only declarations, source declarations
/// may expose:
/// - Annotations applied in code
/// - A source URI pointing to their definition
///
/// ---
///
/// #### Identity
///
/// The debug identity for a [SourceDeclaration] is derived from:
/// - The declaration’s runtime type
/// - Its simple name
///
/// This ensures stability across reflection and generation phases while
/// remaining human-readable.
///
/// ---
///
/// #### Serialization
///
/// [SourceDeclaration] provides a standardized [toJson] implementation
/// containing:
/// - Declaration kind
/// - Name
/// - Annotations (if any)
/// - Source location (if available)
/// - Runtime type information
///
/// This structure is used extensively by:
/// - Diagnostic tooling
/// - Debug output
/// - Metadata inspection
/// {@endtemplate}
abstract final class SourceDeclaration extends EntityDeclaration {
  /// {@macro source_declaration}
  const SourceDeclaration();

  /// Returns all annotations applied to this declaration in source code.
  ///
  /// The returned list:
  /// - Preserves declaration order
  /// - Contains fully materialized [AnnotationDeclaration] instances
  ///
  /// Returns an empty list if no annotations are present.
  List<AnnotationDeclaration> getAnnotations();

  /// Returns the URI pointing to the source location where this declaration
  /// is defined.
  ///
  /// This may be:
  /// - A `package:` URI
  /// - A `dart:` URI
  /// - `null` if the declaration is synthetic or source information
  ///   is unavailable
  Uri? getSourceLocation();

  @override
  String getDebugIdentifier() => '$runtimeType:::${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'source';
    result['name'] = getName();

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

/// {@template member_declaration}
/// A source-level declaration that is **owned by a class**.
///
/// [MemberDeclaration] represents class members such as:
/// - Methods
/// - Fields
/// - Getters and setters
/// - Constructors
///
/// It augments [SourceDeclaration] with class-specific metadata
/// including ownership, staticness, and abstraction state.
///
/// ---
///
/// #### Ownership
///
/// Each member declaration may be associated with a parent class.
/// If the member is top-level or synthetic, the parent may be `null`.
///
/// ---
///
/// #### Identity
///
/// The debug identifier for a member declaration is derived from:
/// - The parent class name (if available)
/// - The member name
///
/// Format:
/// ```text
/// Member: <ClassName>.<memberName>
/// ```
///
/// This ensures:
/// - Human-readable diagnostics
/// - Stable identity across runtime scans
///
/// ---
///
/// #### Use Cases
///
/// Member declarations are commonly used for:
/// - Method invocation
/// - Field access
/// - Code generation
/// - Annotation-driven behavior
/// {@endtemplate}
abstract final class MemberDeclaration extends SourceDeclaration {
  /// {@macro member_declaration}
  const MemberDeclaration();

  /// Returns a link to the class that declares this member.
  ///
  /// Returns:
  /// - A [LinkDeclaration] pointing to the owning class
  /// - `null` if the member is not associated with a class
  LinkDeclaration? getParentClass();

  /// Indicates whether this member is declared as `static`.
  ///
  /// Static members belong to the class itself rather than
  /// to instances of the class.
  bool getIsStatic();

  /// Indicates whether this member is declared as `abstract`.
  ///
  /// Abstract members:
  /// - Have no implementation
  /// - Must be implemented by concrete subclasses
  bool getIsAbstract();

  @override
  String getDebugIdentifier() => 'Member: ${getParentClass()?.getName()}.${getName()}';

  @override
  String toString() => '''
$runtimeType(
  name: ${getName()},
  annotations: ${getAnnotations().map((a) => a.getDebugIdentifier()).join(', ')},
  sourceLocation: ${getSourceLocation()},
  isStatic: ${getIsStatic()},
  isAbstract: ${getIsAbstract()},
  parentClass: ${getParentClass()?.toJson()},
)
''';
}