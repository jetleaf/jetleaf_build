part of '../declaration/declaration.dart';

/// {@template standard_function_link_declaration}
/// Standard implementation of [FunctionLinkDeclaration] for representing
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
/// final functionLink = StandardFunctionLinkDeclaration(
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
final class StandardFunctionLinkDeclaration extends StandardLinkDeclaration implements FunctionLinkDeclaration {
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
  /// - [variance]: Type variance
  /// - [upperBound]: Upper bound for type variables
  ///
  /// All fields are immutable once created.
  /// {@endtemplate}
  const StandardFunctionLinkDeclaration({
    required LinkDeclaration returnType,
    List<LinkDeclaration> parameters = const [],
    List<LinkDeclaration> typeParameters = const [],
    bool isNullable = false,
    MethodDeclaration? methodDeclaration,
    required super.dartType,
    required super.name,
    required super.type,
    required super.pointerType,
    super.typeArguments = const [],
    required super.qualifiedName,
    super.canonicalUri,
    required super.isPublic,
    required super.isSynthetic,
    super.referenceUri,
    super.variance,
    super.upperBound,
  })  : _returnType = returnType,
        _parameters = parameters,
        _typeParameters = typeParameters,
        _methodDeclaration = methodDeclaration,
        _isFunctionNullable = isNullable;

  @override
  LinkDeclaration getReturnType() => _returnType;

  @override
  MethodDeclaration? getMethodCall() => _methodDeclaration;

  @override
  List<LinkDeclaration> getParameters() => List.unmodifiable(_parameters);

  @override
  List<LinkDeclaration> getTypeParameters() => List.unmodifiable(_typeParameters);

  @override
  bool isNullable() => _isFunctionNullable;

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
      _parameters,
      _typeParameters,
      _isFunctionNullable,
    ];
  }
}