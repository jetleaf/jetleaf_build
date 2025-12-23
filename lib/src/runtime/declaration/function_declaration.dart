part of 'declaration.dart';

/// {@template function_link_declaration}
/// Specialized LinkDeclaration for function type references.
///
/// Represents references to function types such as:
/// - `String Function(String)`
/// - `void Function()?`
/// - `Future<T> Function(T input)`
///
/// {@template function_link_declaration_features}
/// ## Key Features
/// - Function type return type information
/// - Parameter type information
/// - Type parameter support for generic functions
/// - Nullability support for function types
/// - Full type signature representation
///
/// ## Typical Usage
/// Used by reflection systems to represent:
/// - Function type parameters
/// - Method return types
/// - Callback parameters
/// - Generic function types
/// {@endtemplate}
///
/// {@template function_link_declaration_example}
/// ## Example Usage
/// ```dart
/// final functionLink = FunctionDeclaration(
///   returnType: stringLink,
///   parameters: [stringLink],
///   typeParameters: [],
///   isNullable: false,
/// );
///
/// print(functionLink.getReturnType().getName()); // "String"
/// print(functionLink.getParameters()[0].getName()); // "String"
/// print(functionLink.isNullable()); // false
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract final class FunctionDeclaration extends ClassDeclaration implements LinkDeclaration, MemberDeclaration {
  /// {@macro function_link_declaration}
  const FunctionDeclaration();

  /// Gets the return type of the function.
  ///
  /// {@template get_return_type}
  /// Returns:
  /// - A [LinkDeclaration] representing the function's return type
  /// - For `void` functions, returns a representation of `void`
  /// - Never returns `null`
  /// {@endtemplate}
  LinkDeclaration getReturnType();

  /// Gets the parameter types of the function.
  ///
  /// {@template get_parameters}
  /// Returns:
  /// - A list of [LinkDeclaration] representing each parameter type
  /// - Empty list for functions with no parameters
  /// - Preserves parameter order
  /// - Does not include parameter names, only types
  /// {@endtemplate}
  List<LinkDeclaration> getLinkParameters();

  /// Gets the type parameters for generic function types.
  ///
  /// {@template get_type_parameters}
  /// Returns:
  /// - A list of [LinkDeclaration] for each type parameter
  /// - Empty list for non-generic function types
  /// - Preserves declaration order
  /// - Includes bounds and variance information
  /// {@endtemplate}
  List<LinkDeclaration> getTypeParameters();

  /// Checks if this function type is nullable.
  ///
  /// {@template is_function_nullable}
  /// Returns:
  /// - `true` if the function type itself is nullable (e.g., `void Function()?`)
  /// - `false` otherwise
  /// - Note: This is different from parameters or return types being nullable
  /// {@endtemplate}
  bool isNullable();

  /// Gets the function signature as a string.
  ///
  /// {@template get_signature}
  /// Returns:
  /// - Human-readable function signature
  /// - Example: "String Function(String)" or "void Function()?"
  /// - Includes type parameters if present
  /// {@endtemplate}
  String getSignature();

  /// Returns all parameters required by this functionType.
  ///
  /// This includes positional, named, and optional parameters in the order
  /// they are declared. Use this method to inspect functionType requirements
  /// before attempting instantiation.
  ///
  /// ### Example
  /// ```dart
  /// for (final param in functionType.getParameters()) {
  ///   print('${param.getName()} : ${param.getType().getName()}');
  /// }
  /// ```
  List<ParameterDeclaration> getParameters();

  /// Returns the [MethodDeclaration] representing the underlying method,
  /// if this function link was created from a concrete method reference.
  ///
  /// This is particularly useful when bridging between **function-type
  /// references** and **actual method declarations**, allowing you to
  /// inspect metadata, modifiers, parameters, and return types
  /// from the original method.
  ///
  /// Returns:
  /// - A [MethodDeclaration] if the function link corresponds to a real
  ///   method or getter/setter.
  /// - `null` if the function link represents an abstract, anonymous,
  ///   or dynamically generated function type.
  ///
  /// ### Example
  /// ```dart
  /// final methodLink = functionLink.getMethodCall();
  /// if (methodLink != null) {
  ///   print(methodLink.getName()); // e.g., "myCallback"
  ///   print(methodLink.getReturnType().getName()); // e.g., "String"
  ///   print(methodLink.Link().length); // Number of parameters
  /// }
  /// ```
  ///
  /// This allows reflection code to map function type references
  /// back to their original declarations for detailed inspection or
  /// invocation purposes.
  MethodDeclaration? getMethodCall();
}

/// {@template standard_function_link_declaration}
/// Standard implementation of [FunctionDeclaration] for representing
/// function type references with full type information.
///
/// This class provides complete metadata about function types including:
/// - Return type with nullability
/// - Parameter types with order and nullability
/// - Type parameters with bounds and variance
/// - Function-level nullability
/// - Pointer type information
///
/// {@template standard_function_link_declaration_features}
/// ## Key Features
/// - Complete function type introspection
/// - JSON serialization support
/// - Value equality comparison
/// - Debug-friendly representation
/// - Support for complex nested function types
/// {@endtemplate}
///
/// {@template standard_function_link_declaration_example}
/// ## Example Creation
/// ```dart
/// final functionLink = StandardFunctionDeclaration(
///   returnType: StandardLinkDeclaration(
///     name: 'String',
///     type: String,
///     pointerType: String,
///     qualifiedName: 'dart:core.String',
///     isPublic: true,
///     isSynthetic: false,
///   ),
///   parameters: [
///     StandardLinkDeclaration(
///       name: 'String',
///       type: String,
///       pointerType: String,
///       qualifiedName: 'dart:core.String',
///       isPublic: true,
///       isSynthetic: false,
///     ),
///   ],
///   typeParameters: [],
///   isNullable: false,
///   name: 'String Function(String)',
///   pointerType: Function,
///   qualifiedName: 'String Function(String)',
///   isPublic: true,
///   isSynthetic: false,
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
@internal
final class StandardFunctionDeclaration extends StandardClassDeclaration implements FunctionDeclaration {
  /// The return type of the function
  final LinkDeclaration _returnType;
  
  /// The parameter types of the function in order
  final List<LinkDeclaration> _parameters;
  
  /// The type parameters for generic function types
  final List<LinkDeclaration> _typeParameters;
  
  /// Whether the function type itself is nullable
  final bool _isFunctionNullable;

  /// The method call on this function
  final MethodDeclaration? _methodDeclaration;

  final Type _pointerType;
  final Uri? _canonicalUri;
  final Uri? _referenceUri;
  LinkDeclaration? parentClass;
  List<ParameterDeclaration> parameters;

  /// Creates a standard function link declaration
  ///
  /// {@template standard_function_link_constructor}
  /// Parameters:
  /// - [_returnType]: Required return type [LinkDeclaration]
  /// - [_parameters]: List of parameter type [LinkDeclaration]s (default empty)
  /// - [_typeParameters]: List of type parameter [LinkDeclaration]s (default empty)
  /// - [_isFunctionNullable]: Whether function type is nullable (default false)
  /// - [name]: Function signature name (e.g., "String Function(String)")
  /// - [type]: Runtime type (usually Function)
  /// - [pointerType]: Pointer type (usually Function)
  /// - [qualifiedName]: Fully qualified function signature
  /// - [isPublic]: Whether the type is public
  /// - [isSynthetic]: Whether the type is synthetic
  /// - [typeArguments]: Type arguments (for generic types)
  /// - [canonicalUri]: Canonical definition URI
  /// - [referenceUri]: Reference location URI
  ///
  /// All fields are immutable once created.
  /// {@endtemplate}
  StandardFunctionDeclaration({
    required LinkDeclaration returnType,
    List<LinkDeclaration> linkParameters = const [],
    List<LinkDeclaration> typeParameters = const [],
    bool isNullable = false,
    MethodDeclaration? methodDeclaration,
    required super.name,
    required super.type,
    required Type pointerType,
    Uri? canonicalUri,
    Uri? referenceUri,
    super.typeArguments = const [],
    required super.qualifiedName,
    required super.isPublic,
    required super.isSynthetic,
    required super.library,
    super.annotations,
    super.constructors,
    super.fields,
    super.interfaces,
    super.isAbstract,
    super.isBase,
    super.isFinal,
    super.isInterface,
    super.isMixin,
    super.isRecord,
    super.isSealed,
    super.kind = TypeKind.functionType,
    super.methods,
    super.mixins,
    super.packageUri,
    super.simpleName,
    super.sourceLocation,
    super.superClass,
    this.parentClass,
    this.parameters = const [],
  })  : _returnType = returnType,
        _parameters = linkParameters,
        _typeParameters = typeParameters,
        _methodDeclaration = methodDeclaration,
        _isFunctionNullable = isNullable,
        _pointerType = pointerType,
       _canonicalUri = canonicalUri, _referenceUri = referenceUri;

  @override
  LinkDeclaration getReturnType() => _returnType;

  @override
  MethodDeclaration? getMethodCall() => _methodDeclaration;

  @override
  List<LinkDeclaration> getLinkParameters() => List.unmodifiable(_parameters);

  @override
  List<LinkDeclaration> getTypeParameters() => List.unmodifiable(_typeParameters);

  @override
  Uri? getCanonicalUri() => _canonicalUri;
  
  @override
  bool getIsCanonical() => _canonicalUri != null && _referenceUri != null && _canonicalUri == _referenceUri;
  
  @override
  Type getPointerType() => _pointerType;
  
  @override
  Uri? getReferenceUri() => _referenceUri;

  @override
  bool isNullable() => _isFunctionNullable;

  @override
  bool getIsStatic() => false;

  @override
  String getSignature() {
    final typeParams = _typeParameters.isNotEmpty
        ? '<${_typeParameters.map((p) => p.getName()).join(', ')}>'
        : '';
    
    final params = _parameters.isEmpty
        ? ' Function()'
        : ' Function(${_parameters.map((p) => p.getName()).join(', ')})';
    
    final nullableSuffix = _isFunctionNullable ? '?' : '';
    
    return '${_returnType.getName()}$typeParams$params$nullableSuffix';
  }

  @override
  String getPointerQualifiedName() => getSignature();

  @override
  LinkDeclaration getParentClass() => parentClass ?? StandardLinkDeclaration(
    name: getName(),
    type: getType(),
    pointerType: getType(),
    qualifiedName: getQualifiedName(),
    isPublic: getIsPublic(),
    canonicalUri: Uri.parse(getPackageUri()),
    referenceUri: Uri.parse(getPackageUri()),
    isSynthetic: getIsSynthetic(),
  );

  @override
  List<ParameterDeclaration> getParameters() => List.unmodifiable(parameters);

  @override
  List<LinkDeclaration> getTypeArguments() {
    // For function types, we combine type parameters with parameter/return types
    final allTypeArgs = <LinkDeclaration>[];
    allTypeArgs.add(_returnType);
    allTypeArgs.addAll(_parameters);
    allTypeArgs.addAll(_typeParameters);
    allTypeArgs.addAll(_typeArguments);
    return List.unmodifiable(allTypeArgs);
  }

  @override
  Map<String, Object> toJson() {
    final result = super.toJson();
    
    // Add function-specific fields
    result['declaration'] = 'function_link';
    result['returnType'] = _returnType.toJson();
    result['parameters'] = _parameters.map((p) => p.toJson()).toList();
    result['typeParameters'] = _typeParameters.map((tp) => tp.toJson()).toList();
    result['isFunctionNullable'] = _isFunctionNullable;
    result['signature'] = getSignature();
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      ...super.equalizedProperties(),
      _returnType,
    ];
  }
}