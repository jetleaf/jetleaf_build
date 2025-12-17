part of 'declaration.dart';

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
abstract class MixinDeclaration extends ClassDeclaration implements SourceDeclaration {
  /// {@macro mixin}
  const MixinDeclaration();

  /// Returns the `on` constraint types for this mixin.
  ///
  /// Mixins in Dart can declare `on` constraints to specify the
  /// classes or interfaces they can be applied to. This method
  /// returns a list of [LinkDeclaration] objects representing
  /// those types.
  ///
  /// ### Example
  /// ```dart
  /// mixin MyMixin on BaseClass, SomeInterface {}
  /// final constraints = mixinDecl.getConstraints();
  /// // constraints contains LinkDeclaration for BaseClass and SomeInterface
  /// ```
  ///
  /// Returns an empty list if the mixin has no `on` constraints.
  List<LinkDeclaration> getConstraints();

  /// Returns `true` if this mixin declares `on` type constraints.
  ///
  /// This is a convenience method equivalent to checking
  /// `getConstraints().isNotEmpty`.
  ///
  /// ### Example
  /// ```dart
  /// mixin MyMixin on BaseClass {}
  /// print(mixinDecl.getHasConstraints()); // true
  /// ```
  bool getHasConstraints();
}