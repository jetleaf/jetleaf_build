part of 'declaration.dart';

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

  /// Returns the [LinkDeclaration] describing this field’s declared type.
  ///
  /// This represents the **fully resolved type metadata** for the field,
  /// including nullability, generic arguments, variance, and bounds.
  ///
  /// For example, a field declared as `List<String>?` will return a
  /// [LinkDeclaration] describing `List<String>` with nullable semantics.
  ///
  /// This is the primary entry point for type-level inspection of a field.
  LinkDeclaration getLinkDeclaration();

  /// Indicates whether this field’s type is a Dart **record type**.
  ///
  /// This is a convenience helper that checks whether the resolved
  /// [LinkDeclaration] is a [RecordLinkDeclaration].
  ///
  /// Record fields can be further introspected to access positional and
  /// named components of the record structure.
  ///
  /// ### Returns
  /// `true` if the field type is a record; otherwise, `false`.
  bool isRecord() => getLinkDeclaration() is RecordLinkDeclaration;

  /// Indicates whether this field’s declared type is a **function type**.
  ///
  /// This is a convenience helper that checks whether the resolved
  /// [LinkDeclaration] is a [FunctionLinkDeclaration].
  ///
  /// Function-typed fields can be invoked, inspected for parameters,
  /// return types, and generic signatures through the function
  /// declaration metadata.
  ///
  /// ### Returns
  /// `true` if the field type represents a function; otherwise, `false`.
  bool isFunction() => getLinkDeclaration() is FunctionLinkDeclaration;

  /// Indicates whether this field is declared with the `final` modifier.
  ///
  /// Final fields may be assigned only once, either at declaration time
  /// or during construction, and cannot be reassigned afterward.
  ///
  /// This flag is independent of whether the field is `static` or
  /// instance-based.
  ///
  /// ### Returns
  /// `true` if the field is `final`; otherwise, `false`.
  bool getIsFinal();

  /// Indicates whether this field is declared with the `const` modifier.
  ///
  /// Const fields are implicitly `static` and must be compile-time
  /// constants. Their values are fully resolved at build time.
  ///
  /// Attempting to modify a const field at runtime will always fail.
  ///
  /// ### Returns
  /// `true` if the field is `const`; otherwise, `false`.
  bool getIsConst();

  /// Indicates whether this field is declared with the `late` modifier.
  ///
  /// Late fields defer initialization until first access or explicit
  /// assignment, allowing non-nullable fields to be initialized outside
  /// of the constructor.
  ///
  /// This flag does not imply mutability.
  ///
  /// ### Returns
  /// `true` if the field is `late`; otherwise, `false`.
  bool getIsLate();

  /// Indicates whether this field is declared at the **top level**.
  ///
  /// Top-level fields are declared outside of any class, mixin, enum,
  /// or extension and are implicitly static within their library scope.
  ///
  /// ### Returns
  /// `true` if the field is top-level; otherwise, `false`.
  bool getIsTopLevel();

  /// Indicates whether this field’s declared type is nullable.
  ///
  /// This reflects the analyzer-derived nullability of the field’s type,
  /// not whether the field currently holds a `null` value at runtime.
  ///
  /// ### Example
  /// ```dart
  /// final fields = declaration.getFields();
  /// print(fields.map((f) => f.isNullable())); // [true, false]
  /// ```
  ///
  /// ### Returns
  /// `true` if the field type is nullable; otherwise, `false`.
  bool isNullable();

  /// Indicates whether this field is declared as `static`.
  ///
  /// Static fields belong to the enclosing type itself rather than to
  /// individual instances. As a result, they must be accessed without
  /// an instance reference.
  ///
  /// This overrides [MemberDeclaration.getIsStatic] to enforce
  /// field-specific semantics.
  ///
  /// ### Returns
  /// `true` if the field is static; otherwise, `false`.
  @override
  bool getIsStatic();

  /// Returns the runtime value of this field from the given [instance].
  ///
  /// - For **static fields**, [instance] must be `null`.
  /// - For **instance fields**, [instance] must be a valid object of the
  ///   declaring type.
  ///
  /// This method performs reflective access and may throw if the field
  /// is inaccessible or unreadable.
  ///
  /// ### Returns
  /// The current value stored in the field.
  dynamic getValue(dynamic instance);

  /// Sets the runtime value of this field on the given [instance].
  ///
  /// - For **static fields**, [instance] must be `null`.
  /// - For **instance fields**, [instance] must be a valid object of the
  ///   declaring type.
  ///
  /// This operation will throw if the field is `final`, `const`, or
  /// otherwise not writable, or if the value violates type constraints.
  ///
  /// ### Parameters
  /// - [instance] — The target object, or `null` for static fields.
  /// - [value] — The new value to assign to the field.
  void setValue(dynamic instance, dynamic value);
}