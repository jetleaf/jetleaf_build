part of '../declaration/declaration.dart';

/// {@template standard_annotation}
/// A standard implementation of [AnnotationDeclaration] that provides
/// reflection metadata about an annotation applied to a declaration.
///
/// This class holds the type of the annotation, the actual arguments
/// passed to the annotation constructor, and the corresponding types
/// of those arguments.
///
/// ## Example
///
/// ```dart
/// final annotation = StandardReflectedAnnotation(
///   type: reflectedTypeOf(MyAnnotation),
///   arguments: {'value': 123},
///   argumentTypes: {'value': reflectedTypeOf(int)},
/// );
///
/// final type = annotation.getType(); // ReflectedType of MyAnnotation
/// final args = annotation.getArguments(); // {'value': 123}
/// final argTypes = annotation.getArgumentTypes(); // {'value': ReflectedType of int}
/// ```
///
/// This allows tools and frameworks to inspect annotations applied to
/// classes, methods, or fields at runtime with full access to metadata.
///
/// {@endtemplate}
final class StandardAnnotationDeclaration extends StandardEntityDeclaration implements AnnotationDeclaration {
  final LinkDeclaration _linkDeclaration;
  final dynamic _instance;
  final Map<String, AnnotationFieldDeclaration> _fields;
  final Map<String, dynamic> _userProvidedValues;

  /// {@macro standard_annotation}
  const StandardAnnotationDeclaration({
    required LinkDeclaration linkDeclaration,
    required dynamic instance,
    required super.isPublic,
    required super.isSynthetic,
    required super.name,
    required super.type,
    required Map<String, AnnotationFieldDeclaration> fields,
    required Map<String, dynamic> userProvidedValues,
  })  : _linkDeclaration = linkDeclaration,
        _instance = instance,
        _fields = fields,
        _userProvidedValues = userProvidedValues;

  @override
  LinkDeclaration getLinkDeclaration() => _linkDeclaration;

  @override
  dynamic getInstance() => _instance;

  @override
  Map<String, dynamic> getUserProvidedValues() => Map.unmodifiable(_userProvidedValues);

  @override
  List<AnnotationFieldDeclaration> getFields() => List.unmodifiable(_fields.values.toList());

  @override
  Map<String, AnnotationFieldDeclaration> getMappedFields() => Map.unmodifiable(_fields);

  @override
  AnnotationFieldDeclaration? getField(String name) => _fields[name];

  @override
  List<String> getFieldNames() => _fields.keys.toList();

  @override
  Map<String, AnnotationFieldDeclaration> getFieldsWithDefaults() {
    final fieldsWithDefaults = <String, AnnotationFieldDeclaration>{};
    for (final entry in _fields.entries) {
      if (entry.value.hasDefaultValue()) {
        fieldsWithDefaults[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(fieldsWithDefaults);
  }

  @override
  Map<String, AnnotationFieldDeclaration> getFieldsWithUserValues() {
    final fieldsWithUserValues = <String, AnnotationFieldDeclaration>{};
    for (final entry in _fields.entries) {
      if (entry.value.hasUserProvidedValue()) {
        fieldsWithUserValues[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(fieldsWithUserValues);
  }

  @override
  String getDebugIdentifier() => 'annotation_${getLinkDeclaration().getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'annotation';

    final fields = getFields().map((f) => f.toJson()).toList();
    if(fields.isNotEmpty) {
      result['fields'] = fields;
    }

    final userProvidedValues = getUserProvidedValues();
    if(userProvidedValues.isNotEmpty) {
      result['userProvidedValues'] = userProvidedValues.map((key, value) => MapEntry(key, value.toString()));
    }

    final mappedFields = getMappedFields().map((key, value) => MapEntry(key, value.toJson()));
    if(mappedFields.isNotEmpty) {
      result['mappedFields'] = mappedFields;
    }

    final fieldNames = getFieldNames();
    if(fieldNames.isNotEmpty) {
      result['fieldNames'] = fieldNames;
    }

    final fieldsWithDefaults = getFieldsWithDefaults().map((key, value) => MapEntry(key, value.toJson()));
    if(fieldsWithDefaults.isNotEmpty) {
      result['fieldsWithDefaults'] = fieldsWithDefaults;
    }

    final fieldsWithUserValues = getFieldsWithUserValues().map((key, value) => MapEntry(key, value.toJson()));
    if(fieldsWithUserValues.isNotEmpty) {
      result['fieldsWithUserValues'] = fieldsWithUserValues;
    }

    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getType(),
      getFields(),
      getUserProvidedValues(),
      getMappedFields(),
      getFieldsWithDefaults(),
      getFieldsWithUserValues(),
      getLinkDeclaration()
    ];
  }
}

/// Enhanced annotation field metadata
final class StandardAnnotationFieldDeclaration extends StandardSourceDeclaration implements AnnotationFieldDeclaration {
  final LinkDeclaration _typeDeclaration;
  final dynamic _defaultValue;
  final bool _hasDefaultValue;
  final dynamic _userValue;
  final bool _hasUserValue;
  final bool _isFinal;
  final bool _isConst;
  final int _position;
  final bool _isNullable;

  const StandardAnnotationFieldDeclaration({
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
    required LinkDeclaration typeDeclaration,
    required dynamic defaultValue,
    required bool hasDefaultValue,
    required dynamic userValue,
    required bool hasUserValue,
    required bool isFinal,
    required bool isConst,
    required int position,
    required bool isNullable,
    required super.type,
    required super.libraryDeclaration,
    super.annotations,
    super.sourceLocation
  }) : _typeDeclaration = typeDeclaration,
       _defaultValue = defaultValue,
       _hasDefaultValue = hasDefaultValue,
       _userValue = userValue,
       _hasUserValue = hasUserValue,
       _isFinal = isFinal,
       _position = position,
       _isConst = isConst,
       _isNullable = isNullable;

  @override
  LinkDeclaration getLinkDeclaration() => _typeDeclaration;

  @override
  dynamic getValue() => hasUserProvidedValue() ? getUserProvidedValue() : getDefaultValue();

  @override
  dynamic getDefaultValue() => _defaultValue;

  @override
  dynamic getUserProvidedValue() => _userValue;

  @override
  bool hasDefaultValue() => _hasDefaultValue;

  @override
  bool isNullable() => _isNullable;

  @override
  int getPosition() => _position;

  @override
  bool hasUserProvidedValue() => _hasUserValue;

  @override
  bool isFinal() => _isFinal;

  @override
  bool isConst() => _isConst;

  @override
  String getDebugIdentifier() => 'annotation_field_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());

    result['declaration'] = 'annotation_field';
    result['name'] = getName();

    final type = getLinkDeclaration().toJson();
    if(type.isNotEmpty) {
      result['type'] = type;
    }

    final defaultValue = getDefaultValue();
    if(defaultValue != null) {
      result['defaultValue'] = defaultValue.toString();
    }
    
    final userValue = getUserProvidedValue();
    if(userValue != null) {
      result['userValue'] = userValue.toString();
    }
  
    result['hasUserValue'] = hasUserProvidedValue();
    result['isFinal'] = isFinal();
    result['isConst'] = isConst();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getType(),
      getValue(),
      getDefaultValue(),
      getUserProvidedValue(),
      hasDefaultValue(),
      hasUserProvidedValue(),
      isFinal(),
      isConst(),
    ];
  }
}