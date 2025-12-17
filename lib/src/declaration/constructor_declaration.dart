part of 'declaration.dart';

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
  /// This includes positional, named, and optional parameters in the order
  /// they are declared. Use this method to inspect constructor requirements
  /// before attempting instantiation.
  ///
  /// ### Example
  /// ```dart
  /// for (final param in constructor.getParameters()) {
  ///   print('${param.getName()} : ${param.getType().getName()}');
  /// }
  /// ```
  List<ParameterDeclaration> getParameters();

  /// Returns `true` if this constructor is a `factory`.
  ///
  /// Factory constructors do not necessarily create a new instance of the
  /// class; they may return cached instances or redirect to other constructors.
  ///
  /// ### Example
  /// ```dart
  /// class Singleton {
  ///   factory Singleton() => _instance ??= Singleton._internal();
  ///   Singleton._internal();
  /// }
  /// print(constructor.getIsFactory()); // true
  /// ```
  bool getIsFactory();

  /// Returns `true` if this constructor is declared `const`.
  ///
  /// Const constructors allow compile-time instantiation and can be used
  /// to create canonicalized constant objects.
  ///
  /// ### Example
  /// ```dart
  /// class Point {
  ///   final int x, y;
  ///   const Point(this.x, this.y);
  /// }
  /// print(constructor.getIsConst()); // true
  /// ```
  bool getIsConst();

  /// Creates a new instance of the class using this constructor.
  ///
  /// [arguments] is a map where keys are parameter names and values are
  /// the corresponding values to pass to the constructor.
  ///
  /// Throws if required parameters are missing or if types do not match.
  ///
  /// ### Example
  /// ```dart
  /// final person = constructor.newInstance({
  ///   'name': 'Alice',
  ///   'age': 30,
  /// });
  /// print(person.name); // Alice
  /// ```
  T newInstance<T>(Map<String, dynamic> arguments);
}