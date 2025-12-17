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

import 'package:meta/meta_meta.dart';

/// {@template annotation}
/// Base class for all annotations.
/// 
/// This class serves as the base for all annotations that can be discovered
/// and processed through the reflection system. It provides the basic
/// contract that all annotations must implement.
/// 
/// Unlike Dart's built-in Annotation class, this class is designed specifically
/// for use with the JetLeaf framework and provides additional metadata
/// and processing capabilities.
/// 
/// {@endtemplate}
@Author("Evaristus Adimonyemma")
abstract class ReflectableAnnotation {
  /// {@macro annotation}
  const ReflectableAnnotation();
  
  /// Returns the annotation _type of this annotation.
  /// 
  /// This method returns the runtime _type of the annotation, which can be
  /// used for _type checking and filtering operations.
  /// 
  /// **Returns:** The Class object representing the annotation _type
  Type get annotationType;
  
  /// Checks if this annotation is equal to another object.
  /// 
  /// Two annotations are considered equal if they are of the same _type
  /// and all their properties have equal values.
  /// 
  /// **Parameters:**
  /// - [other]: The object to compare with this annotation
  /// 
  /// **Returns:** true if the objects are equal, false otherwise
  @override
  bool operator ==(Object other);
  
  /// Checks whether the given object is logically equivalent to this annotation.
  ///
  /// Logical equivalence means:
  /// - Same runtime _type (implements same annotation interface)
  /// - All fields/members of both annotations are equal
  ///
  /// Value comparison rules:
  /// - Primitive types: compared via `==`
  /// - `double`/`float`: compared via `.equals`, treating `NaN == NaN`, and `0.0 != -0.0`
  /// - Strings, Classes, Enums, and other annotations: compared via `.equals`
  /// - Arrays: compared via deep equality (like `ListEquality`) for respective element types
  ///
  /// Returns `true` if equivalent, `false` otherwise.
  bool equals(Object other) {
    return this == other;
  }

  /// Returns a hash code consistent with equality definition.
  ///
  /// Hash is calculated as the sum of hash codes of all members (including default values).
  /// For each member, hash is:
  /// `(127 * memberName.hashCode) ^ memberValue.hashCode`
  ///
  /// The value hash code rules:
  /// - Primitives: use wrapper hash codes (e.g., `int.hashCode`)
  /// - Enums, Strings, Classes, Annotations: `.hashCode`
  /// - Arrays/lists: use deep hash from list contents
  @override
  int get hashCode;
  
  /// Returns a string representation of this annotation.
  /// 
  /// The string representation includes the annotation _type and all
  /// property values in a readable format.
  /// 
  /// **Returns:** A string representation of this annotation
  @override
  String toString();
}

/// {@template generic_annotation}
/// A reflectable annotation that marks generic classes for type reflection.
///
/// This annotation must be used exclusively on generic class declarations
/// to enable type lookup in the reflection system. It captures the generic
/// type information that would otherwise be erased at runtime.
///
/// ### Usage Requirements:
/// - Only valid on generic class declarations (`TargetKind.classType`)
/// - Must specify at least the base type parameter
/// - Should include URI for better debugging when possible
///
/// {@template generic_annotation_example}
/// Example usage with various generic class patterns:
/// ```dart
/// @Generic(Box, 'dart:core')
/// class Box<T> {}  // Basic generic class
///
/// @Generic(SortedCollection, 'dart:core')
/// class SortedCollection<T extends Comparable> {}  // Bounded generic
///
/// @Generic(Map, 'dart:core')
/// class Registry<K, V> with Logging implements Storage {}  // With mixins/implements
/// ```
/// {@endtemplate}
///
/// See also:
/// - [ReflectableAnnotation] for base annotation capabilities
/// {@endtemplate}
@Target({TargetKind.classType, TargetKind.mixinType})
@Author("Evaristus Adimonyemma")
class Generic extends ReflectableAnnotation {
  static final String FIELD_NAME = "type";

  /// The runtime type representation of the generic parameter.
  ///
  /// Stores the actual type that will be used for reflection lookups,
  /// preserving the generic type information that would normally be erased.
  ///
  /// {@macro generic_annotation_example}
  final Type type;

  /// The source location URI where the generic type is defined.
  ///
  /// While optional, providing this enables better:
  /// - Debugging information
  /// - Documentation generation
  /// - Dependency tracking
  ///
  /// Format examples:
  /// - SDK types: `'dart:core'`
  /// - Package types: `'package:collection/collection.dart'`
  /// - Local types: `'lib/src/models.dart'`
  ///
  /// {@macro generic_annotation_example}
  final String? _uri;

  /// Creates a [Generic] annotation instance.
  ///
  /// {@template generic_constructor}
  /// Parameters:
  /// - [type]: The base generic type (e.g., `List` for `List<T>`)
  /// - [_uri]: Optional source URI for better debugging
  ///
  /// Throws:
  /// - [InvalidArgumentException] if [type] represents a non-generic type
  ///
  /// Example:
  /// ```dart
  /// @Generic(DataPipe, 'dart:async')
  /// class DataPipe<T> {
  ///   Stream<T> get stream => _controller.stream;
  /// }
  /// ```
  /// {@endtemplate}
  const Generic(this.type, [this._uri]);

  /// Gets the preserved generic type information.
  ///
  /// This is the type that will be used for reflection system lookups,
  /// maintaining the generic type parameter that would otherwise be erased.
  ///
  /// {@template generic_getter_example}
  /// Example:
  /// ```dart
  /// final annotation = const Generic(Set, 'dart:core');
  /// print(annotation.getType()); // Set
  /// ```
  /// {@endtemplate}
  ///
  /// Returns:
  /// The preserved generic [Type] for reflection lookups
  Type getType() => type;

  /// Gets the source location URI if provided.
  ///
  /// While not required for functionality, this enables better tooling support
  /// when debugging reflected generic types.
  ///
  /// {@macro generic_getter_example}
  ///
  /// Returns:
  /// The source [String] URI if available, otherwise `null`
  String? getUri() => _uri;

  @override
  Type get annotationType => Generic;
}

/// An annotation used to mark classes for which AOT-compatible runtime
/// resolvers should be generated.
///
/// When a class is annotated with `@Resolved`, the `RuntimeResolverGenerator`
/// will create a `RuntimeHint` for it, enabling dynamic operations like
/// instance creation, method invocation, and field access in AOT environments.
///
/// This annotation can also be applied to other annotations. If a class is
/// annotated with an annotation that itself has `@Resolved`, the class will
/// also be processed for resolver generation.
///
/// Example:
/// ```dart
/// @Resolved()
/// class MyService {
///   MyService();
///   String greet(String name) => 'Hello, $name!';
/// }
///
/// @Resolved()
/// @Component() // If @Component itself has @Resolved, MyComponent will be resolved
/// class MyComponent {
///   MyComponent();
/// }
/// ```
@Target({TargetKind.classType})
@Author("Evaristus Adimonyemma")
class Resolved extends ReflectableAnnotation {
  const Resolved();

  @override
  Type get annotationType => Resolved;
}

/// {@template author_annotation}
/// Annotation to describe the author of a declaration.
///
/// This annotation can be applied to classes, methods, or any other declarations
/// to provide metadata about the author, including the name, email address, organization,
/// website, and additional comments.
///
/// This can be especially useful for documentation generation or reflection-based
/// tooling provided by the JetLeaf framework.
///
/// Example usage:
/// ```dart
/// @Author(
///   name: 'Alice Smith',
///   emailAddress: 'alice@example.com',
///   organization: 'Acme Corp',
///   website: 'https://acme.example.com',
///   comment: 'Created during Hackathon 2025',
/// )
/// class MyAnnotatedClass {}
/// ```
/// {@endtemplate}
@Target({})
@Author("Evaristus Adimonyemma")
class Author extends ReflectableAnnotation {
  /// The full name of the author.
  final String name;

  /// The email address of the author.
  final String? emailAddress;

  /// The organization with which the author is affiliated (if any).
  final String? organization;

  /// The website of the author or their organization (if available).
  final String? website;

  /// Additional comments about the author or the context of the declaration.
  final String? comment;

  /// {@macro author_annotation}
  ///
  /// Creates an [Author] annotation with the given author metadata.
  ///
  /// - [name]: The full name of the author.
  /// - [emailAddress]: The email address of the author.
  /// - [organization]: (Optional) The organization the author belongs to.
  /// - [website]: (Optional) The author's or organization's website.
  /// - [comment]: (Optional) Any additional comments.
  const Author(this.name, {this.emailAddress, this.organization, this.website, this.comment});

  @override
  String toString() {
    final fields = <String>['name: $name'];

    void addIfPresent(String label, String? value) {
      if (value != null && value.isNotEmpty) {
        fields.add('$label: $value');
      }
    }

    addIfPresent('emailAddress', emailAddress);
    addIfPresent('organization', organization);
    addIfPresent('website', website);
    addIfPresent('comment', comment);

    return 'Author(${fields.join(', ')})';
  }

  @override
  Type get annotationType => Author;
}