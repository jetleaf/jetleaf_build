part of 'declaration.dart';

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
  /// {@template typedef_alias}
  /// This method resolves the underlying type that the typedef points to.
  /// It may be a class, record, or function type. This allows reflection
  /// systems to transparently follow typedef chains to the actual type.
  ///
  /// ### Example
  /// ```dart
  /// typedef StringToInt = int Function(String);
  ///
  /// final alias = typedefDeclaration.getAliasedType();
  /// print(alias.getName()); // "int Function(String)"
  /// ```
  /// {@endtemplate}
  LinkDeclaration getAliasedType();

  /// Returns the function type that this typedef refers to.
  ///
  /// {@template typedef_function_referent}
  /// Specifically for function typedefs, this method returns a [FunctionLinkDeclaration]
  /// representing the aliased function type, including return type, parameters,
  /// type parameters, and nullability.
  ///
  /// ### Example
  /// ```dart
  /// typedef StringToInt = int Function(String);
  ///
  /// final functionLink = typedefDeclaration.getReferent();
  /// print(functionLink.getReturnType().getName()); // "int"
  /// print(functionLink.getParameters()[0].getName()); // "String"
  /// print(functionLink.isNullable()); // false
  /// ```
  /// {@endtemplate}
  FunctionLinkDeclaration getReferent();

  /// Checks if the typedef represents a function type.
  ///
  /// Returns `true` if the aliased type is a [FunctionLinkDeclaration],
  /// otherwise returns `false`.
  ///
  /// ### Example
  /// ```dart
  /// typedef StringToInt = int Function(String);
  /// print(typedefDeclaration.isFunction()); // true
  /// ```
  bool isFunction() => getAliasedType() is FunctionLinkDeclaration;

  /// Checks if the typedef represents a record type.
  ///
  /// Returns `true` if the aliased type is a [RecordLinkDeclaration],
  /// otherwise returns `false`.
  ///
  /// ### Example
  /// ```dart
  /// typedef MyRecord = (int, String);
  /// print(typedefDeclaration.isRecord()); // true
  /// ```
  bool isRecord() => getAliasedType() is RecordLinkDeclaration;
}