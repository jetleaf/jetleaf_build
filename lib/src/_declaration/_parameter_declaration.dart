part of '../declaration/declaration.dart';

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
    super.element,
    super.dartType,
    required super.type,
    required super.libraryDeclaration,
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

    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
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
      getParentLibrary(),
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