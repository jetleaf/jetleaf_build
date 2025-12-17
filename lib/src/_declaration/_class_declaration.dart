part of '../declaration/declaration.dart';

/// {@template standard_class}
/// A standard implementation of [ClassDeclaration] that provides runtime
/// metadata and reflection capabilities for Dart classes.
///
/// This class supports inspection of class properties such as fields,
/// methods, constructors, supertypes, and metadata annotations. It can
/// also instantiate class objects reflectively using a provided factory
/// or by matching a suitable constructor.
///
/// ## Example
///
/// ```dart
/// final reflectedClass = StandardReflectedClass(
///   name: 'MyClass',
///   type: MyClass,
///   parentLibrary: myLibrary,
///   constructors: [myConstructor],
///   fields: [myField],
///   methods: [myMethod],
/// );
///
/// final instance = reflectedClass.newInstance({'value': 42});
/// ```
///
/// In this example, `StandardReflectedClass` provides access to the metadata
/// and creation mechanism of `MyClass`, which can be instantiated via
/// `newInstance()` with a map of named arguments.
///
/// {@endtemplate}
final class StandardClassDeclaration extends StandardTypeDeclaration implements ClassDeclaration {
  final LibraryDeclaration _parentLibrary;
  final List<ConstructorDeclaration> _constructors;
  final List<FieldDeclaration> _fields;
  final List<MethodDeclaration> _methods;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;
  final bool _isAbstract;
  final bool _isMixin;
  final bool _isSealed;
  final bool _isBase;
  final bool _isInterface;
  final bool _isFinal;
  final bool _isRecord;

  /// {@macro standard_class}
  StandardClassDeclaration({
    required super.name,
    required super.type,
    required LibraryDeclaration parentLibrary,
    super.isNullable = false,
    super.typeArguments,
    required super.element,
    required super.dartType,
    String? qualifiedName,
    List<ConstructorDeclaration> constructors = const [],
    List<FieldDeclaration> fields = const [],
    List<MethodDeclaration> methods = const [],
    super.superClass,
    super.interfaces,
    super.mixins,
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation,
    bool isAbstract = false,
    required super.isPublic,
    required super.isSynthetic,
    bool isMixin = false,
    bool isSealed = false,
    bool isBase = false,
    bool isInterface = false,
    bool isFinal = false,
    bool isRecord = false,
    super.kind = TypeKind.classType,
  })  : _parentLibrary = parentLibrary,
        _constructors = constructors,
        _fields = fields,
        _methods = methods,
        _annotations = annotations,
        _sourceLocation = sourceLocation,
        _isAbstract = isAbstract,
        _isMixin = isMixin,
        _isSealed = isSealed,
        _isBase = isBase,
        _isInterface = isInterface,
        _isFinal = isFinal,
        _isRecord = isRecord,
        super(
          qualifiedName: qualifiedName ?? '${parentLibrary.getUri()}.$name',
          simpleName: name,
          packageUri: parentLibrary.getUri(),
        );

  @override
  LibraryDeclaration getParentLibrary() => _parentLibrary;

  @override
  List<AnnotationDeclaration> getAnnotations() => List.unmodifiable(_annotations);

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  List<ConstructorDeclaration> getConstructors() => List.unmodifiable(_constructors);

  @override
  bool hasField(String fieldName) => getField(fieldName) != null;

  @override
  FieldDeclaration? getField(String fieldName) => _fields.where((field) => field.getName() == fieldName).firstOrNull;

  @override
  List<FieldDeclaration> getFields() => List.unmodifiable(_fields);

  @override
  List<FieldDeclaration> getStaticFields() => getFields().where((field) => field.getIsStatic()).toList();

  @override
  List<FieldDeclaration> getInstanceFields() => getFields().where((field) => !field.getIsStatic()).toList();

  @override
  bool hasMethod(String methodName) => getMethod(methodName) != null;

  @override
  MethodDeclaration? getMethod(String methodName) => _methods.where((method) => method.getName() == methodName).firstOrNull;

  @override
  List<MethodDeclaration> getMethods() => List.unmodifiable(_methods);

  @override
  List<MethodDeclaration> getStaticMethods() => getMethods().where((method) => method.getIsStatic()).toList();

  @override
  List<MethodDeclaration> getInstanceMethods() => getMethods().where((method) => !method.getIsStatic()).toList();

  @override
  bool getIsAbstract() => _isAbstract;

  @override
  bool getIsMixin() => _isMixin;

  @override
  bool getIsSealed() => _isSealed;

  @override
  bool getIsBase() => _isBase;

  @override
  bool getIsInterface() => _isInterface;

  @override
  bool getIsFinal() => _isFinal;

  @override
  bool getIsRecord() => _isRecord;

  @override
  bool getHasInterfaces() => getInterfaces().isNotEmpty;

  /// Creates a copy of this class with the specified properties changed.
  StandardClassDeclaration copyWith({
    String? name,
    Type? type,
    LibraryDeclaration? parentLibrary,
    bool? isNullable,
    List<LinkDeclaration>? typeArguments,
    List<ConstructorDeclaration>? constructors,
    List<FieldDeclaration>? fields,
    List<MethodDeclaration>? methods,
    LinkDeclaration? superClass,
    List<LinkDeclaration>? interfaces,
    List<LinkDeclaration>? mixins,
    List<AnnotationDeclaration>? annotations,
    Uri? sourceLocation,
    bool? isAbstract,
    bool? isMixin,
    bool? isSealed,
    bool? isBase,
    bool? isInterface,
    bool? isFinal,
    bool? isRecord,
    Element? element,
    DartType? dartType,
    String? qualifiedName,
    bool? isPublic,
    bool? isSynthetic
  }) {
    return StandardClassDeclaration(
      name: name ?? getName(),
      type: type ?? getType(),
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      parentLibrary: parentLibrary ?? _parentLibrary,
      isNullable: isNullable ?? getIsNullable(),
      typeArguments: typeArguments ?? getTypeArguments(),
      constructors: constructors ?? _constructors,
      fields: fields ?? _fields,
      methods: methods ?? _methods,
      superClass: superClass ?? _superClass,
      interfaces: interfaces ?? _interfaces,
      mixins: mixins ?? _mixins,
      annotations: annotations ?? _annotations,
      sourceLocation: sourceLocation ?? _sourceLocation,
      isAbstract: isAbstract ?? _isAbstract,
      isMixin: isMixin ?? _isMixin,
      isSealed: isSealed ?? _isSealed,
      isBase: isBase ?? _isBase,
      isInterface: isInterface ?? _isInterface,
      element: element ?? getElement(),
      dartType: dartType ?? getDartType(),
      qualifiedName: qualifiedName ?? getQualifiedName(),
      isFinal: isFinal ?? _isFinal,
      isRecord: isRecord ?? _isRecord,
    );
  }

  @override
  List<MemberDeclaration> getMembers() {
    return [
      ..._constructors,
      ..._fields,
      ..._methods,
    ];
  }

  @override
  dynamic newInstance(Map<String, dynamic> arguments) {
    // Try to find a suitable constructor
    ConstructorDeclaration? constructor;
    if (arguments.isEmpty) {
      // Look for default constructor
      constructor = _constructors.firstWhere(
        (c) => c.getName().isEmpty && c.getParameters().isEmpty,
        orElse: () => _constructors.firstWhere(
          (c) => c.getParameters().every((p) => p.getIsNullable()),
          orElse: () => throw BuildException('No suitable constructor found for $_name with no arguments'),
        ),
      );
    } else {
      // Look for constructor that matches the provided arguments
      constructor = _constructors.firstWhere(
        (c) => _constructorMatches(c, arguments),
        orElse: () => throw BuildException('No suitable constructor found for $_name with arguments: ${arguments.keys}'),
      );
    }
    return constructor.newInstance(arguments);
  }

  @override
  String getDebugIdentifier() => 'class_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'class';
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

    result['type'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();

    final superClass = getSuperClass()?.toJson();
    if (superClass != null) {
      result['superClass'] = superClass;
    }

    final interfaces = getInterfaces();
    if (interfaces.isNotEmpty) {
      result['interfaces'] = interfaces.map((i) => i.toJson()).toList();
    }

    final mixins = getMixins();
    if (mixins.isNotEmpty) {
      result['mixins'] = mixins.map((m) => m.toJson()).toList();
    }

    final typeArguments = getTypeArguments();
    if (typeArguments.isNotEmpty) {
      result['typeArguments'] = typeArguments.map((t) => t.toJson()).toList();
    }

    final constructors = getConstructors();
    if (constructors.isNotEmpty) {
      result['constructors'] = constructors.map((t) => t.toJson()).toList();
    }

    result['isAbstract'] = getIsAbstract();
    result['isMixin'] = getIsMixin();
    result['isSealed'] = getIsSealed();
    result['isBase'] = getIsBase();
    result['isInterface'] = getIsInterface();
    result['isFinal'] = getIsFinal();
    result['isRecord'] = getIsRecord();

    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getType(),
      getIsNullable(),
      getKind(),
      getTypeArguments(),
      getSuperClass(),
      getInterfaces(),
      getMixins(),
      getConstructors(),
      getIsAbstract(),
      getIsMixin(),
      getIsSealed(),
      getIsBase(),
      getIsInterface(),
      getIsFinal(),
      getIsRecord(),
    ];
  }
}

bool _constructorMatches(ConstructorDeclaration constructor, Map<String, dynamic> arguments) {
  final params = constructor.getParameters();
  // Check if all required parameters are provided
  for (final param in params) {
    if (!param.getIsNullable() && !arguments.containsKey(param.getName())) {
      return false;
    }
  }
  // Check if all provided arguments have corresponding parameters
  for (final argName in arguments.keys) {
    if (!params.any((p) => p.getName() == argName)) {
      return false;
    }
  }
  return true;
}