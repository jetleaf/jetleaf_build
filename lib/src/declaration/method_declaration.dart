part of 'declaration.dart';

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

  /// Returns the return type of the method as a [LinkDeclaration].
  ///
  /// This represents the fully resolved type produced by the JetLeaf
  /// linking system and may include generic arguments, nullability,
  /// and runtime linkage metadata.
  LinkDeclaration getReturnType();

  /// Indicates whether this method’s return type is a **record type**.
  ///
  /// This is a convenience helper that checks if the resolved return
  /// [LinkDeclaration] is a [RecordLinkDeclaration], allowing callers
  /// to branch logic for record-specific handling.
  ///
  /// ### Returns
  /// `true` if the return type is a record; otherwise, `false`.
  bool isRecord() => getReturnType() is RecordLinkDeclaration;

  /// Indicates whether this method’s return type is a **function type**.
  ///
  /// This helper checks if the resolved return [LinkDeclaration] is a
  /// [FunctionLinkDeclaration], which enables inspection of callable
  /// signatures such as parameters, generics, and nullability.
  ///
  /// ### Returns
  /// `true` if the return type is a function; otherwise, `false`.
  bool isFunction() => getReturnType() is FunctionLinkDeclaration;

  /// Returns all parameters accepted by this method.
  ///
  /// The returned list preserves declaration order and includes
  /// positional, optional, and named parameters. Each parameter
  /// is represented as a [ParameterDeclaration] containing its
  /// type, name, and modifier metadata.
  List<ParameterDeclaration> getParameters();

  /// Returns `true` if this method is a Dart `getter`.
  ///
  /// Getter methods have no parameters and conceptually represent
  /// a property access rather than a traditional invocation.
  bool getIsGetter();

  /// Returns `true` if this method is a Dart `setter`.
  ///
  /// Setter methods accept exactly one parameter and conceptually
  /// represent an assignment to a property.
  bool getIsSetter();

  /// Returns `true` if this method is declared at the top level.
  ///
  /// Top-level methods are not associated with a class, mixin,
  /// or extension instance.
  bool getIsTopLevel();

  /// Returns `true` if this method is marked as an application entrypoint.
  ///
  /// Entrypoint methods may be treated specially by tooling,
  /// scanners, or runtime invocation pipelines.
  bool getIsEntryPoint();

  /// Indicates whether this method is declared as `external`.
  ///
  /// External methods have no Dart body and are typically implemented
  /// via native bindings or external tooling.
  ///
  /// **Experimental**: Behavior and guarantees may change.
  bool isExternal();

  /// Indicates whether this method’s return value may be `null`.
  ///
  /// This reflects nullability information inferred from analyzer
  /// metadata and runtime linking, and should not be used as a
  /// strict guarantee in all execution contexts.
  ///
  /// **Experimental**: Use with caution.
  bool hasNullableReturn();

  /// Returns `true` if this method is declared as a `factory`.
  ///
  /// Factory methods do not create instances directly but instead
  /// delegate object creation logic, often returning subtypes.
  bool getIsFactory();

  /// Returns `true` if this method is declared as `const`.
  ///
  /// Const methods are typically constructors and participate in
  /// compile-time constant evaluation.
  bool getIsConst();

  /// Invokes this method on the given [instance].
  ///
  /// - If the method is `static`, [instance] must be `null`.
  /// - [arguments] must be a map whose keys correspond to parameter names.
  ///
  /// The invocation is performed using the resolved runtime linkage
  /// and may throw if the method cannot be invoked, arguments are
  /// missing or invalid, or reflection is restricted.
  ///
  /// ### Example
  /// ```dart
  /// final result = method.invoke(myObject, {
  ///   'param1': 42,
  ///   'param2': 'ok',
  /// });
  /// ```
  dynamic invoke(dynamic instance, Map<String, dynamic> arguments);
}