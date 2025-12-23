part of 'declaration.dart';

/// {@template parameter}
/// Represents a parameter in a constructor or method, with metadata about
/// its name, type, position (named or positional), and default value.
///
/// ### Example
/// ```dart
/// final method = clazz.getMethods().first;
/// for (final param in method.getParameters()) {
///   print(param.getName()); // e.g., "value"
///   print(param.getTypeDeclaration().getName()); // e.g., "String"
/// }
/// ```
/// {@endtemplate}
abstract final class ParameterDeclaration extends SourceDeclaration {
  /// {@macro parameter}
  const ParameterDeclaration();

  /// Returns the zero-based positional index of this parameter within the
  /// function, method, or constructor declaration.
  ///
  /// For example, in:
  /// ```dart
  /// void example(int a, String b, {bool? flag})
  /// ```
  /// `a` → index `0`  
  /// `b` → index `1`  
  /// `flag` (named) may still receive a logical index depending on the
  /// implementation, but ordering is preserved.
  int getIndex();

  /// Returns the [LinkDeclaration] representing the declared type of this
  /// parameter.
  ///
  /// This provides semantic information about the parameter’s type, including:
  /// - resolved type references
  /// - nullability
  /// - generic type data
  ///
  /// This is useful during code generation or reflection when evaluating the
  /// parameter's type annotation.
  LinkDeclaration getLinkDeclaration();

  /// Indicates whether this parameter's type is a **record type**.
  ///
  /// This is a convenience helper that checks if the resolved return
  /// [LinkDeclaration] is a [RecordDeclaration], allowing callers
  /// to branch logic for record-specific handling.
  ///
  /// ### Returns
  /// `true` if the type is a record; otherwise, `false`.
  bool isRecord() => getLinkDeclaration() is RecordDeclaration;

  /// Indicates whether this parameter's type is a **function type**.
  ///
  /// This helper checks if the resolved return [LinkDeclaration] is a
  /// [FunctionDeclaration], which enables inspection of callable
  /// signatures such as parameters, generics, and nullability.
  ///
  /// ### Returns
  /// `true` if the type is a function; otherwise, `false`.
  bool isFunction() => getLinkDeclaration() is FunctionDeclaration;

  /// Returns `true` if this parameter is nullable.
  ///
  /// This indicates whether the parameter’s type includes a `?`, such as:
  /// ```dart
  /// String? name  // true
  /// int count     // false
  /// ```
  /// Note that this does **not** indicate whether the parameter is optional;
  /// only its type-level nullability.
  bool getIsNullable();

  /// Returns `true` if this parameter is required.
  ///
  /// This includes:
  /// - required named parameters (`required int x`)
  /// - all non-nullable positional parameters without default values
  ///
  /// It does **not** imply that the parameter is non-nullable; nullability is
  /// covered separately by [getIsNullable].
  bool getIsRequired();

  /// Returns `true` if this parameter is optional, including:
  /// - optional positional parameters (`[int x]`)
  /// - optional named parameters (`int x`)
  ///
  /// This property is the logical opposite of [getIsRequired].
  bool getIsOptional();

  /// Returns `true` if the parameter is a *named* parameter.
  ///
  /// Examples:
  /// ```dart
  /// void f({int a})   // true
  /// void f([int a])   // false
  /// void f(int a)     // false
  /// ```
  bool getIsNamed();

  /// Returns `true` if this parameter declares a default value.
  ///
  /// Applies only to optional parameters:
  /// ```dart
  /// void f([int x = 3])   // true
  /// void f({int y = 5})   // true
  /// void f(int z)         // false
  /// ```
  bool getHasDefaultValue();

  /// Returns the parameter’s default value, or `null` if no default exists.
  ///
  /// If the parameter is optional but does not explicitly declare a default,
  /// this still returns `null`.
  ///
  /// Example:
  /// ```dart
  /// void f([int x = 10, int y]) {
  ///   // x.getDefaultValue() → 10
  ///   // y.getDefaultValue() → null
  /// }
  /// ```
  dynamic getDefaultValue();
}

/// {@template standard_parameter}
/// A standard implementation of [ParameterDeclaration] used to represent metadata
/// about a parameter in a Dart function, method, or constructor.
///
/// This class provides information such as the parameter name, type,
/// whether it is optional or named, and whether it has a default value.
///
/// ## Example
/// ```dart
/// final param = StandardReflectedParameter(
///   name: 'count',
///   type: intType,
///   isOptional: true,
///   hasDefaultValue: true,
///   defaultValue: 5,
/// );
///
/// print(param.getName()); // "count"
/// print(param.getIsOptional()); // true
/// print(param.getDefaultValue()); // 5
/// ```
/// {@endtemplate}
@internal
final class StandardParameterDeclaration extends StandardSourceDeclaration implements ParameterDeclaration {
  final LinkDeclaration _typeDeclaration;
  final bool _isNullable;
  final bool _isRequired;
  final bool _isOptional;
  final bool _isNamed;
  final bool _hasDefaultValue;
  final dynamic _defaultValue;
  final int _index;

  /// {@macro standard_parameter}
  const StandardParameterDeclaration({
    required super.name,
    required super.type,
    required LinkDeclaration typeDeclaration,
    bool isNullable = false,
    bool isRequired = false,
    bool isOptional = false,
    bool isNamed = false,
    required super.isPublic,
    required super.isSynthetic,
    bool hasDefaultValue = false,
    dynamic defaultValue,
    required int index,
    super.sourceLocation,
    super.annotations,
  })  : _typeDeclaration = typeDeclaration,
        _isNullable = isNullable,
        _isNamed = isNamed,
        _hasDefaultValue = hasDefaultValue,
        _defaultValue = defaultValue,
        _isOptional = isOptional,
        _isRequired = isRequired,
        _index = index;

  @override
  LinkDeclaration getLinkDeclaration() => _typeDeclaration;

  @override
  bool isFunction() => getLinkDeclaration() is FunctionDeclaration;

  @override
  bool isRecord() => getLinkDeclaration() is RecordDeclaration;

  @override
  bool getIsNullable() => _isNullable;

  @override
  bool getIsOptional() => _isOptional;

  @override
  bool getIsRequired() => _isRequired;

  @override
  bool getIsNamed() => _isNamed;

  @override
  bool getHasDefaultValue() => _hasDefaultValue;

  @override
  dynamic getDefaultValue() => _defaultValue;

  @override
  int getIndex() => _index;

  @override
  String getDebugIdentifier() => 'parameter_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'parameter';
    result['name'] = getName();

    result['index'] = getIndex();
    result['isNullable'] = getIsNullable();
    result['isOptional'] = getIsOptional();
    result['isRequired'] = getIsRequired();
    result['isNamed'] = getIsNamed();
    result['hasDefaultValue'] = getHasDefaultValue();

    final defaultValue = getDefaultValue();
    if(defaultValue != null) {
      result['defaultValue'] = defaultValue.toString();
    }

    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getAnnotations(),
      getSourceLocation(),
      getType(),
      getIsNullable(),
      getIsNamed(),
      getHasDefaultValue(),
      getDefaultValue(),
      getIndex(),
    ];
  }
}