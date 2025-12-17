part of 'declaration.dart';

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

  /// Returns the zero-based positional index of this parameter within the
  /// function, method, or constructor declaration.
  ///
  /// For example, in:
  /// ```dart
  /// void example(int a, String b, {bool? flag})
  /// ```
  /// `a` → index `0`  
  /// `b` → index `1`  
  /// `flag` (named) may still receive a logical index depending on the
  /// implementation, but ordering is preserved.
  int getIndex();

  /// Returns the [LinkDeclaration] representing the declared type of this
  /// parameter.
  ///
  /// This provides semantic information about the parameter’s type, including:
  /// - resolved type references
  /// - nullability
  /// - generic type data
  ///
  /// This is useful during code generation or reflection when evaluating the
  /// parameter's type annotation.
  LinkDeclaration getLinkDeclaration();

  /// Returns `true` if this parameter is nullable.
  ///
  /// This indicates whether the parameter’s type includes a `?`, such as:
  /// ```dart
  /// String? name  // true
  /// int count     // false
  /// ```
  /// Note that this does **not** indicate whether the parameter is optional;
  /// only its type-level nullability.
  bool getIsNullable();

  /// Returns `true` if this parameter is required.
  ///
  /// This includes:
  /// - required named parameters (`required int x`)
  /// - all non-nullable positional parameters without default values
  ///
  /// It does **not** imply that the parameter is non-nullable; nullability is
  /// covered separately by [getIsNullable].
  bool getIsRequired();

  /// Returns `true` if this parameter is optional, including:
  /// - optional positional parameters (`[int x]`)
  /// - optional named parameters (`int x`)
  ///
  /// This property is the logical opposite of [getIsRequired].
  bool getIsOptional();

  /// Returns `true` if the parameter is a *named* parameter.
  ///
  /// Examples:
  /// ```dart
  /// void f({int a})   // true
  /// void f([int a])   // false
  /// void f(int a)     // false
  /// ```
  bool getIsNamed();

  /// Returns `true` if this parameter declares a default value.
  ///
  /// Applies only to optional parameters:
  /// ```dart
  /// void f([int x = 3])   // true
  /// void f({int y = 5})   // true
  /// void f(int z)         // false
  /// ```
  bool getHasDefaultValue();

  /// Returns the parameter’s default value, or `null` if no default exists.
  ///
  /// If the parameter is optional but does not explicitly declare a default,
  /// this still returns `null`.
  ///
  /// Example:
  /// ```dart
  /// void f([int x = 10, int y]) {
  ///   // x.getDefaultValue() → 10
  ///   // y.getDefaultValue() → null
  /// }
  /// ```
  dynamic getDefaultValue();
}