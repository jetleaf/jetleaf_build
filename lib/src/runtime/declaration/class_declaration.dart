part of 'declaration.dart';

/// {@template class_declaration}
/// Represents a reflected Dart class and all of its metadata, including
/// fields, methods, constructors, superclasses, mixins, interfaces, and
/// declaration-level modifiers (abstract, sealed, etc.).
///
/// Use this class to introspect:
/// - Class members: fields, methods, constructors
/// - Generic type parameters
/// - Supertype, mixins, and implemented interfaces
/// - Modifiers like `abstract`, `sealed`, `base`, etc.
/// - Runtime instantiation via `newInstance()`
///
/// ### Example
/// ```dart
/// final type = reflector.reflectType(MyService).asClassType();
/// print('Class: ${type?.getName()}');
///
/// for (final method in type!.getMethods()) {
///   print('Method: ${method.getName()}');
/// }
///
/// final instance = type.newInstance({'message': 'Hello'});
/// ```
/// {@endtemplate}
abstract final class ClassDeclaration extends SourceDeclaration with EqualsAndHashCode implements QualifiedName {
  /// {@macro class_declaration}
  const ClassDeclaration();

  /// Returns all members declared in this class, including fields, methods, and constructors.
  ///
  /// This method provides a comprehensive view of the class structure
  /// without including inherited members. Useful for code analysis,
  /// generation, or runtime introspection.
  ///
  /// Members include:
  /// - [FieldDeclaration] objects for each field
  /// - [MethodDeclaration] objects for each method
  /// - [ConstructorDeclaration] objects for each constructor
  ///
  /// ### Example
  /// ```dart
  /// for (final member in clazz.getMembers()) {
  ///   print('${member.getName()} (${member.runtimeType})');
  /// }
  /// ```
  ///
  /// Returns an empty list if the class has no declared members.
  List<MemberDeclaration> getMembers();

  /// Returns all constructors declared in this class.
  ///
  /// Each constructor can be inspected for:
  /// - Name (unnamed or named)
  /// - Parameters ([ParameterDeclaration])
  /// - Modifiers like `const`, `factory`, or `external`
  ///
  /// ### Example
  /// ```dart
  /// for (final ctor in clazz.getConstructors()) {
  ///   print(ctor.getName());
  /// }
  /// ```
  ///
  /// Returns an empty list if the class has no constructors.
  List<ConstructorDeclaration> getConstructors();

  /// Returns all fields declared in this class, excluding inherited fields.
  ///
  /// Fields include both instance and static fields.
  /// Each field can be inspected via [FieldDeclaration] to check
  /// its type, nullability, and modifiers (`final`, `const`, `late`, `static`).
  ///
  /// ### Example
  /// ```dart
  /// for (final field in clazz.getFields()) {
  ///   print('${field.getName()} : ${field.getLinkDeclaration().getName()}');
  /// }
  /// ```
  List<FieldDeclaration> getFields();

  /// Returns all static fields declared in this class or mixin.
  ///
  /// Static fields are those declared with the `static` keyword.
  /// Each returned [FieldDeclaration] provides access to type, value,
  /// and metadata.
  ///
  /// ### Example
  /// ```dart
  /// for (final field in clazz.getStaticFields()) {
  ///   print('${field.getName()} : ${field.getLinkDeclaration().getName()}');
  /// }
  /// ```
  List<FieldDeclaration> getStaticFields();

  /// Returns all instance fields declared in this class or mixin.
  ///
  /// Excludes static fields and inherited fields.
  /// Useful for runtime introspection or code generation targeting
  /// instance-specific properties.
  ///
  /// ### Example
  /// ```dart
  /// for (final field in clazz.getInstanceFields()) {
  ///   print('${field.getName()} : ${field.getLinkDeclaration().getName()}');
  /// }
  /// ```
  List<FieldDeclaration> getInstanceFields();

  /// Returns a field by its [fieldName], or `null` if no field with that name exists.
  ///
  /// Can be used to access the field type, value, or metadata dynamically.
  ///
  /// ### Example
  /// ```dart
  /// final nameField = clazz.getField('name');
  /// if (nameField != null) {
  ///   print(nameField.getLinkDeclaration().getName()); // String
  /// }
  /// ```
  FieldDeclaration? getField(String fieldName);

  /// Checks if this class or mixin declares a field with the given [fieldName].
  ///
  /// Returns `true` if a field exists, `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// if (clazz.hasField('id')) {
  ///   print('Field "id" exists');
  /// }
  /// ```
  bool hasField(String fieldName);

  /// Returns all methods declared in this class, excluding inherited methods.
  ///
  /// Methods include instance and static methods, as well as getters and setters.
  /// Each method can be inspected via [MethodDeclaration] for return type,
  /// parameters, and invocation.
  ///
  /// ### Example
  /// ```dart
  /// for (final method in clazz.getMethods()) {
  ///   print('${method.getName()} returns ${method.getReturnType().getName()}');
  /// }
  /// ```
  ///
  /// Returns an empty list if the class has no declared methods.
  List<MethodDeclaration> getMethods();

  /// Returns all static methods declared in this class or mixin.
  ///
  /// Static methods are declared with the `static` keyword and do not
  /// require an instance to invoke. Each [MethodDeclaration] provides
  /// metadata about parameters, return type, and modifiers.
  ///
  /// ### Example
  /// ```dart
  /// for (final method in clazz.getStaticMethods()) {
  ///   print('${method.getName()} : ${method.getReturnType().getName()}');
  /// }
  /// ```
  List<MethodDeclaration> getStaticMethods();

  /// Returns all instance methods declared in this class or mixin.
  ///
  /// Excludes static methods and inherited methods. Useful for runtime
  /// inspection or code generation targeting instance behavior.
  ///
  /// ### Example
  /// ```dart
  /// for (final method in clazz.getInstanceMethods()) {
  ///   print('${method.getName()} : ${method.getReturnType().getName()}');
  /// }
  /// ```
  List<MethodDeclaration> getInstanceMethods();

  /// Returns a method by its [methodName], or `null` if no method with that name exists.
  ///
  /// Useful for dynamic invocation or analyzing a specific method’s
  /// parameters, return type, and metadata.
  ///
  /// ### Example
  /// ```dart
  /// final addMethod = clazz.getMethod('add');
  /// if (addMethod != null) {
  ///   print(addMethod.getReturnType().getName()); // int
  /// }
  /// ```
  MethodDeclaration? getMethod(String methodName);

  /// Checks if this class or mixin declares a method with the given [methodName].
  ///
  /// Returns `true` if the method exists, `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// if (clazz.hasMethod('toString')) {
  ///   print('Method "toString" exists');
  /// }
  /// ```
  bool hasMethod(String methodName);

  /// Returns `true` if this class is marked `abstract`.
  ///
  /// Abstract classes cannot be instantiated directly and are intended
  /// to be subclassed. They may contain abstract methods that must be
  /// implemented by subclasses.
  ///
  /// ### Example
  /// ```dart
  /// abstract class Shape {}
  /// print(shapeClass.getIsAbstract()); // true
  /// ```
  bool getIsAbstract();

  /// Returns `true` if this declaration is a `mixin` or a mixin application.
  ///
  /// Mixins are reusable sets of methods and fields that can be applied
  /// to classes without using inheritance.
  ///
  /// ### Example
  /// ```dart
  /// mixin Logging {}
  /// print(loggingMixin.getIsMixin()); // true
  /// ```
  bool getIsMixin();

  /// Returns `true` if this class is declared as **sealed**.
  ///
  /// A sealed class restricts which other classes may extend or implement it.
  /// Only classes declared in the same library are permitted as subtypes,
  /// enabling the compiler and tooling to reason exhaustively about
  /// all possible subclasses.
  ///
  /// ### Use cases
  /// - Exhaustive `switch` / pattern matching
  /// - Closed class hierarchies
  /// - Safer domain modeling
  bool getIsSealed();

  /// Returns `true` if this class is declared as **base**.
  ///
  /// A base class may be extended or implemented **only within the same
  /// library** unless explicitly permitted. This prevents external
  /// implementations while still allowing controlled inheritance.
  ///
  /// ### Use cases
  /// - Framework extension points
  /// - Preventing uncontrolled third-party implementations
  bool getIsBase();

  /// Returns the [LibraryDeclaration] in which this class is declared.
  ///
  /// The library represents the physical Dart source unit that owns
  /// this class and defines its visibility, privacy boundaries,
  /// and sealing constraints.
  LibraryDeclaration getLibrary();

  /// Returns `true` if this class is declared as an **interface**.
  ///
  /// Interface classes define a contract that other classes may implement
  /// but do not provide concrete implementation guarantees.
  ///
  /// ### Notes
  /// - Interface classes cannot be instantiated directly
  /// - They are commonly used to define APIs or capabilities
  bool getIsInterface();

  /// Returns `true` if this class is declared as **final**.
  ///
  /// Final classes cannot be extended, mixed in, or subclassed.
  /// This guarantees a closed inheritance hierarchy for the type.
  ///
  /// ### Use cases
  /// - Security-sensitive types
  /// - Performance-critical or invariant-dependent implementations
  bool getIsFinal();

  /// Returns `true` if this class represents a **record class**.
  ///
  /// Record classes typically act as wrappers around Dart record types,
  /// providing named access, metadata, or reflection support while
  /// preserving record semantics.
  bool getIsRecord();

  /// Returns `true` if this class implements one or more interfaces.
  ///
  /// This is useful for:
  /// - Reflection-based interface discovery
  /// - Code generation
  /// - Behavioral analysis
  bool getHasInterfaces();

  /// Returns the **simple (unqualified) name** of this class.
  ///
  /// This excludes:
  /// - Package URI
  /// - Library path
  ///
  /// ### Example
  /// ```dart
  /// "BaseInterface"
  /// ```
  String getSimpleName();

  /// Returns the **package URI** in which this class is declared.
  ///
  /// The URI typically follows the `package:` scheme and identifies
  /// the logical package owner of the class.
  ///
  /// ### Example
  /// ```dart
  /// "package:myapp/models.dart"
  /// ```
  String getPackageUri();

  /// Returns the [TypeKind] describing what kind of type this declaration represents.
  ///
  /// This allows callers to distinguish between:
  /// - Classes
  /// - Enums
  /// - Mixins
  /// - Records
  /// - Other Dart type forms
  ///
  /// ### Example
  /// ```dart
  /// if (declaration.getKind() == TypeKind.classType) {
  ///   print('This is a class.');
  /// }
  /// ```
  TypeKind getKind();

  /// Returns `true` if this class declares **generic type parameters**.
  ///
  /// Generic classes introduce one or more type variables that must
  /// be resolved at instantiation or use-site.
  ///
  /// ### Example
  /// ```dart
  /// class Box<T> {}
  /// ```
  ///
  /// In this case, `isGeneric()` would return `true`.
  bool isGeneric();

  /// Returns the list of mixin identities that are applied to this type.
  ///
  /// This includes all mixins directly used in class declarations:
  ///
  /// ```dart
  /// class MyService with LoggingMixin {}
  /// ```
  /// In this case, `LoggingMixin` would appear in the result.
  List<LinkDeclaration> getMixins() => [];

  /// Returns the list of interfaces this type implements.
  ///
  /// This includes all interfaces declared in the `implements` clause.
  ///
  /// ```dart
  /// class MyService implements Disposable, Serializable {}
  /// ```
  /// Would return both `Disposable` and `Serializable`.
  List<LinkDeclaration> getInterfaces() => [];

  /// Returns the list of type arguments for generic types.
  ///
  /// If the type is not generic, this returns an empty list.
  /// For example, `List<String>` will return a list with one [LinkDeclaration] for `String`.
  List<LinkDeclaration> getTypeArguments() => [];

  /// Returns the direct superclass of this type.
  ///
  /// Returns `null` if this type has no superclass or extends `Object`.
  ///
  /// ```dart
  /// final superClass = identity.getSuperClass();
  /// print(superClass?.getQualifiedName()); // e.g., "package:core/BaseService"
  /// ```
  LinkDeclaration? getSuperClass();

  /// Instantiates this class using the default (unnamed) constructor.
  ///
  /// [arguments] is a map of parameter names to their corresponding values.
  /// The runtime system resolves the constructor and passes the arguments.
  ///
  /// ### Example
  /// ```dart
  /// final instance = clazz.newInstance({'name': 'Alice', 'age': 25});
  /// print(instance); // Instance of MyClass
  /// ```
  dynamic newInstance(Map<String, dynamic> arguments);

  @override
  Map<String,Object> toJson() {
    Map<String, Object> result = {};

    result['declaration'] = 'type';
    result['name'] = getName();
    result['runtimeType'] = getType().toString();
    result['kind'] = getKind().toString();

    final arguments = getTypeArguments().map((t) => t.toJson()).toList();
    if(arguments.isNotEmpty) {
      result['typeArguments'] = arguments;
    }

    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassDeclaration &&
          runtimeType == other.runtimeType && // Crucial for distinguishing concrete types
          getName() == other.getName() &&
          getType() == other.getType() &&
          getKind() == other.getKind();

  @override
  int get hashCode =>
      getName().hashCode ^
      getType().hashCode ^
      getKind().hashCode;

  @override
  String getDebugIdentifier() => '$runtimeType(${getName()})';
}

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
///   library: myLibrary,
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
@internal
final class StandardClassDeclaration extends StandardSourceDeclaration implements ClassDeclaration {
  final LibraryDeclaration _parentLibrary;
  final List<ConstructorDeclaration> _constructors;
  final List<FieldDeclaration> _fields;
  final List<MethodDeclaration> _methods;
  final bool _isAbstract;
  final bool _isMixin;
  final bool _isSealed;
  final bool _isBase;
  final bool _isInterface;
  final bool _isFinal;
  final bool _isRecord;
  final TypeKind _kind;
  final String _qualifiedName;
  final String _simpleName;
  final String _packageUri;
  final List<LinkDeclaration> _mixins;
  final List<LinkDeclaration> _interfaces;
  final LinkDeclaration? _superClass;
  final List<LinkDeclaration> _typeArguments;

  /// {@macro standard_class}
  StandardClassDeclaration({
    required super.name,
    required super.type,
    required LibraryDeclaration library,
    String? qualifiedName,
    List<ConstructorDeclaration> constructors = const [],
    List<FieldDeclaration> fields = const [],
    List<MethodDeclaration> methods = const [],
    super.annotations,
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
    TypeKind kind = TypeKind.classType,
    String? simpleName,
    String? packageUri,
    List<LinkDeclaration> mixins = const [],
    List<LinkDeclaration> interfaces = const [],
    LinkDeclaration? superClass,
    List<LinkDeclaration> typeArguments = const [],
  })  : _parentLibrary = library,
        _constructors = constructors,
        _fields = fields,
        _methods = methods,
        _isAbstract = isAbstract,
        _isMixin = isMixin,
        _isSealed = isSealed,
        _isBase = isBase,
        _isInterface = isInterface,
        _isFinal = isFinal,
        _isRecord = isRecord,
        _interfaces = interfaces,
        _kind = kind,
        _mixins = mixins,
        _superClass = superClass,
        _typeArguments = typeArguments,
        _qualifiedName = qualifiedName ?? '${library.getUri()}.$name',
        _simpleName = simpleName ?? name,
        _packageUri = packageUri ?? library.getUri();

  @override
  LibraryDeclaration getLibrary() => _parentLibrary;

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

  @override
  List<LinkDeclaration> getInterfaces() => UnmodifiableListView(_interfaces);
  
  @override
  TypeKind getKind() => _kind;
  
  @override
  List<LinkDeclaration> getMixins() => UnmodifiableListView(_mixins);
  
  @override
  String getPackageUri() => _packageUri;
  
  @override
  String getQualifiedName() => _qualifiedName;
  
  @override
  String getSimpleName() => _simpleName;
  
  @override
  LinkDeclaration? getSuperClass() => _superClass;
  
  @override
  List<LinkDeclaration> getTypeArguments() => UnmodifiableListView(_typeArguments);

  @override
  List<MemberDeclaration> getMembers() => [..._constructors, ..._fields, ..._methods];

  @override
  String getDebugIdentifier() => "class_${getSimpleName().toLowerCase()}";
  
  @override
  bool isGeneric() => getTypeArguments().isNotEmpty || (getType().toString().contains("<") && getType().toString().endsWith(">"));

  /// Creates a copy of this class with the specified properties changed.
  StandardClassDeclaration copyWith({
    String? name,
    Type? type,
    LibraryDeclaration? library,
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
    String? qualifiedName,
    bool? isPublic,
    bool? isSynthetic
  }) {
    return StandardClassDeclaration(
      name: name ?? getName(),
      type: type ?? getType(),
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      library: library ?? _parentLibrary,
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
      qualifiedName: qualifiedName ?? getQualifiedName(),
      isFinal: isFinal ?? _isFinal,
      isRecord: isRecord ?? _isRecord,
      packageUri: getPackageUri(),
      simpleName: getSimpleName(),
      kind: getKind(),
    );
  }

  @override
  dynamic newInstance(Map<String, dynamic> arguments) {
    if (GenericTypeParser.isMirrored(getType().toString())) {
      throw UnresolvedTypeInstantiationException(getType());
    }

    // Try to find a suitable constructor
    ConstructorDeclaration? constructor;
    if (arguments.isEmpty) {
      // Look for default constructor
      constructor = _constructors.firstWhere(
        (c) => c.getName().isEmpty && c.getParameters().isEmpty,
        orElse: () => _constructors.firstWhere(
          (c) => c.getParameters().every((p) => p.getIsNullable()),
          orElse: () => throw ConstructorNotFoundException(getType(), getName()),
        ),
      );
    } else {
      // Look for constructor that matches the provided arguments
      constructor = _constructors.firstWhere(
        (c) => _constructorMatches(c, arguments),
        orElse: () => throw ConstructorNotFoundException(getType(), getName()),
      );
    }
    return constructor.newInstance(arguments);
  }

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'class';
    result['name'] = getName();
    
    final library = getLibrary().toJson();
    if(library.isNotEmpty) {
      result['library'] = library;
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
      getSourceLocation(),
      getType(),
      getKind(),
      getQualifiedName(),
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