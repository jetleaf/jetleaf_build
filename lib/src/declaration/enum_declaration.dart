part of 'declaration.dart';

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
abstract class EnumDeclaration extends ClassDeclaration implements SourceDeclaration {
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