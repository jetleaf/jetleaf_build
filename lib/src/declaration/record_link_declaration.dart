part of 'declaration.dart';

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
abstract class RecordLinkDeclaration implements LinkDeclaration {
  /// {@macro record}
  const RecordLinkDeclaration();

  /// Returns all fields declared by this record.
  ///
  /// The returned list includes **both positional and named fields** in a
  /// unified collection, preserving the declaration order where applicable.
  ///
  /// This method is useful when performing generic iteration over record
  /// components without needing to distinguish field kinds up front.
  ///
  /// ### Returns
  /// A list of [RecordFieldDeclaration] objects representing every field
  /// contained in the record.
  List<RecordFieldDeclaration> getFields();

  /// Returns the named field with the given [name].
  ///
  /// This method performs a lookup among the record’s **named fields only**.
  /// Positional fields are ignored when resolving by name.
  ///
  /// If no named field exists with the provided identifier, this method
  /// returns `null` rather than throwing.
  ///
  /// ### Parameters
  /// - [name] — The name of the record field to retrieve.
  ///
  /// ### Returns
  /// The matching [RecordFieldDeclaration], or `null` if not found.
  RecordFieldDeclaration? getField(String name);

  /// Returns the positional field at the specified [index].
  ///
  /// Positional fields are indexed starting from `0`, in the order they are
  /// declared within the record. Named fields are not considered by this
  /// accessor.
  ///
  /// If the index is out of bounds, this method safely returns `null`.
  ///
  /// ### Parameters
  /// - [index] — The zero-based index of the positional field.
  ///
  /// ### Returns
  /// The positional [RecordFieldDeclaration], or `null` if the index is invalid.
  RecordFieldDeclaration? getPositionalField(int index);

  /// Indicates whether this record type is nullable.
  ///
  /// A nullable record corresponds to a record type declared with a trailing
  /// `?`, such as `(int, String)?`.
  ///
  /// ### Returns
  /// `true` if the record type is nullable; otherwise, `false`.
  bool getIsNullable();
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
abstract class RecordFieldDeclaration extends LinkDeclaration {
  /// {@macro record_field}
  const RecordFieldDeclaration();

  /// Returns the positional index of this field within the record.
  ///
  /// Positional fields return a zero-based index reflecting their declaration
  /// order. Named fields always return `-1`.
  ///
  /// ### Returns
  /// The positional index, or `-1` if the field is named.
  int getPosition();

  /// Returns the resolved [LinkDeclaration] describing this field’s type.
  ///
  /// This link encapsulates the fully materialized type information for the
  /// field, including generic arguments, nullability, variance, and bounds.
  ///
  /// ### Returns
  /// A [LinkDeclaration] representing the field’s type.
  LinkDeclaration getLinkDeclaration();

  /// Indicates whether this record field is a **named field**.
  ///
  /// Named fields are accessed by identifier rather than position and appear
  /// in records declared with named components.
  ///
  /// ### Returns
  /// `true` if the field is named; otherwise, `false`.
  bool getIsNamed();

  /// Indicates whether this record field’s type is nullable.
  ///
  /// This reflects the analyzer-derived nullability of the field’s declared
  /// type and is independent of whether the record itself is nullable.
  ///
  /// ### Returns
  /// `true` if the field type is nullable; otherwise, `false`.
  bool getIsNullable();

  /// Indicates whether this record field is a **positional field**.
  ///
  /// Positional fields are indexed-based and declared before any named fields
  /// in a record type.
  ///
  /// ### Returns
  /// `true` if the field is positional; otherwise, `false`.
  bool getIsPositional();

  /// Returns the underlying analyzer [RecordTypeField] for this field.
  ///
  /// This provides access to low-level analyzer metadata, such as the original
  /// field shape and declaration details, and is primarily intended for
  /// advanced tooling and diagnostics.
  ///
  /// ### Returns
  /// The associated [RecordTypeField].
  RecordTypeField getRecordFieldType();
}