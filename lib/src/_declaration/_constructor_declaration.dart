part of '../declaration/declaration.dart';

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
    required super.libraryDeclaration,
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

    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }
    
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
      getParentLibrary(),
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