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
abstract final class ConstructorDeclaration extends MemberDeclaration {
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

/// {@template standard_constructor}
/// A standard implementation of [ConstructorDeclaration] that provides
/// metadata and instantiation logic for class constructors.
///
/// This class encapsulates the constructor name, owning class and library,
/// parameter list, annotations, and information such as whether the constructor
/// is a `const` or a `factory`. It also optionally provides a factory function
/// to support reflective instantiation.
///
/// ## Example
///
/// ```dart
/// final constructor = StandardReflectedConstructor(
///   name: 'MyClass',
///   parentLibrary: myLibrary,
///   parentClass: myClass,
///   isConst: true,
///   parameters: [
///     StandardReflectedParameter(name: 'value', type: intType),
///   ],
/// );
///
/// final instance = constructor.newInstance({'value': 42});
/// ```
///
/// This creates a reflective representation of a `MyClass` constructor and
/// uses it to create a new instance.
///
/// {@endtemplate}
@internal
final class StandardConstructorDeclaration extends StandardSourceDeclaration implements ConstructorDeclaration {
  LinkDeclaration parentClass;
  List<ParameterDeclaration> parameters;
  bool isFactory;
  bool isConst;

  /// {@macro standard_constructor}
  StandardConstructorDeclaration({
    required super.name,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    required this.parentClass,
    super.annotations,
    this.parameters = const [],
    super.sourceLocation,
    this.isFactory = false,
    this.isConst = false,
  });

  @override
  LinkDeclaration getParentClass() => parentClass;

  @override
  List<ParameterDeclaration> getParameters() => List.unmodifiable(parameters);

  @override
  bool getIsFactory() => isFactory;

  @override
  bool getIsConst() => isConst;

  @override
  bool getIsStatic() => false; // Constructors are never static

  @override
  bool getIsAbstract() => false; // Constructors are never abstract

  @override
  T newInstance<T>(Map<String, dynamic> arguments) {
    if (getIsPublic()) {
      final arg = _resolveArgument(arguments, parameters, "${parentClass.getName()}$_name");
      return Runtime.getRuntimeResolver().newInstance<T>(_name, arg, this, parentClass.getType());
    }

    throw PrivateConstructorInvocationException(T, getName());
  }

  @override
  String getDebugIdentifier() => 'constructor_${getParentClass().getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'constructor';
    result['name'] = getName();
    
    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    result['parentClass'] = getParentClass().toJson();
    
    final parameters = getParameters().map((p) => p.toJson()).toList();
    if(parameters.isNotEmpty) {
      result['parameters'] = parameters;
    }
    
    result['isFactory'] = getIsFactory();
    result['isConst'] = getIsConst();
    
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
      getIsFactory(),
      getIsConst(),
    ];
  }
}