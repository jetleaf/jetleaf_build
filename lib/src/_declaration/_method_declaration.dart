part of '../declaration/declaration.dart';

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
  final bool _hasNullableReturn;
  final bool _isExternal;

  /// {@macro standard_method}
  StandardMethodDeclaration({
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
    required super.type,
    required super.libraryDeclaration,
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
    bool isExternal = false
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
  bool isFunction() => getReturnType() is FunctionLinkDeclaration;

  @override
  bool isRecord() => getReturnType() is RecordLinkDeclaration;

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
  String getDebugIdentifier() => 'method_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'method';
    result['name'] = getName();
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

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
      getParentLibrary(),
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