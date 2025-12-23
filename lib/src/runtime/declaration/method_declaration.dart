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
abstract final class MethodDeclaration extends MemberDeclaration {
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
  /// [LinkDeclaration] is a [RecordDeclaration], allowing callers
  /// to branch logic for record-specific handling.
  ///
  /// ### Returns
  /// `true` if the return type is a record; otherwise, `false`.
  bool isRecord() => getReturnType() is RecordDeclaration;

  /// Indicates whether this method’s return type is a **function type**.
  ///
  /// This helper checks if the resolved return [LinkDeclaration] is a
  /// [FunctionDeclaration], which enables inspection of callable
  /// signatures such as parameters, generics, and nullability.
  ///
  /// ### Returns
  /// `true` if the return type is a function; otherwise, `false`.
  bool isFunction() => getReturnType() is FunctionDeclaration;

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

  /// Returns `true` if this method is declared as an asynchronous method.
  ///
  /// Async methods are typically methods that have `Future` or `FutureOr`.
  bool isAsynchronous();

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

/// {@template standard_method}
/// A standard implementation of [MethodDeclaration] representing a method,
/// constructor, getter, or setter in a Dart class or library.
///
/// It exposes metadata such as the method name, return type, parameters,
/// modifiers (e.g., `static`, `abstract`, `getter`, `setter`, `const`, `factory`),
/// and annotations. It can optionally support dynamic invocation using the
/// [invoke] function.
///
/// ## Example
/// ```dart
/// final method = StandardReflectedMethod(
///   name: 'greet',
///   parentLibrary: myLibrary,
///   returnType: stringType,
///   parameters: [
///     StandardReflectedParameter(name: 'name', type: stringType),
///   ],
/// );
///
/// final result = method.invoke(null, {'name': 'Eve'});
/// print(result); // "Hello, Eve"
/// ```
///
/// This class is commonly used in reflective systems to invoke methods
/// dynamically and to analyze method structures.
///
/// > Note: [invoke] throws if no `_invoker` function is supplied or if the
///   method's static/non-static requirements are not met.
/// {@endtemplate}
@internal
final class StandardMethodDeclaration extends StandardSourceDeclaration implements MethodDeclaration {
  LinkDeclaration returnType;
  List<ParameterDeclaration> parameters;
  bool isStatic;
  bool isAbstract;
  bool isGetter;
  bool isSetter;
  LinkDeclaration? parentClass;
  bool isConst;
  bool isFactory;
  bool isEntrypoint;
  bool isTopLevel;
  bool isAsync;
  final bool _hasNullableReturn;
  final bool _isExternal;

  /// {@macro standard_method}
  StandardMethodDeclaration({
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
    required super.type,
    required this.returnType,
    this.parameters = const [],
    super.sourceLocation,
    super.annotations,
    this.isStatic = false,
    this.isAbstract = false,
    this.isGetter = false,
    this.isSetter = false,
    this.parentClass,
    this.isConst = false,
    this.isFactory = false,
    this.isEntrypoint = false,
    this.isTopLevel = false,
    bool hasNullableReturn = false,
    bool isExternal = false,
    this.isAsync = false,
  }) : _hasNullableReturn = hasNullableReturn, _isExternal = isExternal;

  @override
  LinkDeclaration getReturnType() => returnType;

  @override
  List<ParameterDeclaration> getParameters() => List.unmodifiable(parameters);

  @override
  bool getIsStatic() => isStatic;

  @override
  bool getIsAbstract() => isAbstract;

  @override
  bool getIsGetter() => isGetter;

  @override
  bool getIsSetter() => isSetter;

  @override
  bool isExternal() => _isExternal;

  @override
  bool getIsTopLevel() => isTopLevel;

  @override
  bool getIsEntryPoint() => isEntrypoint;

  @override
  bool hasNullableReturn() => _hasNullableReturn;

  @override
  bool isFunction() => getReturnType() is FunctionDeclaration;

  @override
  bool isRecord() => getReturnType() is RecordDeclaration;

  @override
  dynamic invoke(dynamic instance, Map<String, dynamic> arguments) {
    if (getIsPublic()) {
      final arg = _resolveArgument(arguments, parameters, "${parentClass?.getName() ?? "#"}$_name");

      if (isStatic) {
        return Runtime.getRuntimeResolver().invokeMethod(instance, _name, arg);
      } else {
        return Runtime.getRuntimeResolver().invokeMethod(instance, _name, arg);
      }
    } else {
      throw PrivateMethodInvocationException(instance, getName());
    }
  }
  
  @override
  bool getIsConst() => isConst;
  
  @override
  bool getIsFactory() => isFactory;
  
  @override
  LinkDeclaration? getParentClass() => parentClass;

  @override
  bool isAsynchronous() => isAsync;

  @override
  String getDebugIdentifier() => 'method_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'method';
    result['name'] = getName();

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if (annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }

    final sourceLocation = getSourceLocation();
    if (sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    final returnType = getReturnType().toJson();
    if (returnType.isNotEmpty) {
      result['returnType'] = returnType;
    }

    final parameters = getParameters().map((p) => p.toJson()).toList();
    if (parameters.isNotEmpty) {
      result['parameters'] = parameters;
    }

    result['isGetter'] = getIsGetter();
    result['isSetter'] = getIsSetter();
    result['isFactory'] = getIsFactory();
    result['isConst'] = getIsConst();
    result['isStatic'] = getIsStatic();
    result['isAbstract'] = getIsAbstract();

    final parentClass = getParentClass()?.toJson();
    if (parentClass != null) {
      result['parentClass'] = parentClass;
    }
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getAnnotations(),
      getSourceLocation(),
      getParentClass(),
      getIsStatic(),
      getIsAbstract(),
      getReturnType(),
      getParameters(),
      getIsGetter(),
      getIsSetter(),
      getIsFactory(),
      getIsConst(),
    ];
  }
}