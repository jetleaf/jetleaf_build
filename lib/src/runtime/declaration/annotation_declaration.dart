part of 'declaration.dart';

/// {@template annotation}
/// Represents an annotation that has been applied to a class, method,
/// field, parameter, or other Dart declarations at runtime.
///
/// This interface gives you access to:
/// - The [EntityDeclaration] of the annotation
/// - The arguments used when the annotation was constructed
///
/// ### Example
/// ```dart
/// for (final annotation in reflectedClass.getAnnotations()) {
///   print(annotation.getTypeDeclaration().getName());
///   print(annotation.getArguments());
/// }
/// ```
/// {@endtemplate}
abstract final class AnnotationDeclaration extends EntityDeclaration {
  /// {@macro annotation}
  const AnnotationDeclaration();

  /// Returns the type of the annotation.
  ///
  /// This allows inspection of the annotation's class, including whether it
  /// is a custom annotation or a built-in one.
  LinkDeclaration getLinkDeclaration();

  /// Returns the instance of the annotation.
  /// 
  /// This allows inspection of the annotation's instance, including its fields and methods.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final instance = annotation.getInstance();
  /// print(instance.toString());
  /// ```
  dynamic getInstance();

  /// Returns the fields of the annotation.
  /// 
  /// This list contains the fields of the annotation in the order they were declared.
  /// If no fields were declared, the list will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getName())); // ["value"]
  /// ```
  List<AnnotationFieldDeclaration> getFields();

  /// Returns the user provided values of the annotation.
  /// 
  /// This map contains the values that were provided by the user when the annotation was applied.
  /// If no values were provided, the map will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final values = annotation.getUserProvidedValues();
  /// print(values['value']); // "Hello"
  /// ```
  Map<String, dynamic> getUserProvidedValues();

  /// Returns a map of the annotation's fields, keyed by their name.
  /// 
  /// This map contains the fields of the annotation in the order they were declared.
  /// If no fields were declared, the map will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final mappedFields = annotation.getMappedFields();
  /// print(mappedFields['value']); // ReflectedAnnotationField(...)
  /// ```
  Map<String, AnnotationFieldDeclaration> getMappedFields();

  /// Returns a specific field by name.
  /// 
  /// If no field with the given name was declared, returns `null`.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final field = annotation.getField('value');
  /// print(field.getName()); // "value"
  /// ```
  AnnotationFieldDeclaration? getField(String name);

  /// Returns a list of the annotation's field names.
  /// 
  /// This list contains the names of the fields of the annotation in the order they were declared.
  /// If no fields were declared, the list will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fieldNames = annotation.getFieldNames();
  /// print(fieldNames); // ["value"]
  /// ```
  List<String> getFieldNames();

  /// Returns a map of the annotation's fields that have default values, keyed by their name.
  /// 
  /// This map contains the fields of the annotation that have default values in the order they were declared.
  /// If no fields have default values, the map will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fieldsWithDefaults = annotation.getFieldsWithDefaults();
  /// print(fieldsWithDefaults['value']); // ReflectedAnnotationField(...)
  /// ```
  Map<String, AnnotationFieldDeclaration> getFieldsWithDefaults();

  /// Returns a map of the annotation's fields that have user-provided values, keyed by their name.
  /// 
  /// This map contains the fields of the annotation that have user-provided values in the order they were declared.
  /// If no fields have user-provided values, the map will be empty.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fieldsWithUserValues = annotation.getFieldsWithUserValues();
  /// print(fieldsWithUserValues['value']); // ReflectedAnnotationField(...)
  /// ```
  Map<String, AnnotationFieldDeclaration> getFieldsWithUserValues();
}

/// {@template annotation_field}
/// Represents a field of an annotation.
/// 
/// This interface provides access to:
/// - The field's name
/// - The field's type
/// - The value of the field
/// 
/// ### Example
/// ```dart
/// final annotation = ...;
/// final fields = annotation.getFields();
/// print(fields.map((f) => f.getName())); // ["value"]
/// ```
/// {@endtemplate}
abstract final class AnnotationFieldDeclaration extends FieldDeclaration {
  /// {@macro annotation_field}
  const AnnotationFieldDeclaration();

  /// Returns the default value of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getDefaultValue())); // ["value"]
  /// ```
  dynamic getDefaultValue();

  /// Returns the user provided value of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getUserProvidedValue())); // ["value"]
  /// ```
  dynamic getUserProvidedValue();

  /// Returns true if the field has a default value.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.hasDefaultValue())); // [true]
  /// ```
  bool hasDefaultValue();

  /// Returns true if the field has a user provided value.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.hasUserProvidedValue())); // [true]
  /// ```
  bool hasUserProvidedValue();

  /// Returns the position of the field in the source code.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getPosition())); // [1]
  /// ```
  int getPosition();

  /// Returns the value of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getAnnotationValue())); // ["value"]
  /// ```
  dynamic getAnnotationValue();
}

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
@internal
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
@internal
final class StandardAnnotationFieldDeclaration extends StandardFieldDeclaration implements AnnotationFieldDeclaration {
  final dynamic _defaultValue;
  final bool _hasDefaultValue;
  final dynamic _userValue;
  final bool _hasUserValue;
  final int _position;

  const StandardAnnotationFieldDeclaration({
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
    required dynamic defaultValue,
    required bool hasDefaultValue,
    required dynamic userValue,
    required bool hasUserValue,
    required int position,
    required super.type,
    super.annotations,
    super.sourceLocation,
    required super.linkDeclaration,
    super.isAbstract,
    super.isLate,
    super.isStatic,
    super.isTopLevel,
    super.parentClass,
    super.isConst,
    super.isFinal,
    super.isNullable
  }) : _defaultValue = defaultValue,
       _hasDefaultValue = hasDefaultValue,
       _userValue = userValue,
       _hasUserValue = hasUserValue,
       _position = position;

  @override
  dynamic getValue(dynamic instance) => hasUserProvidedValue() ? getUserProvidedValue() : getDefaultValue();

  @override
  dynamic getAnnotationValue() => getValue(Object());

  @override
  void setValue(instance, value) {}

  @override
  dynamic getDefaultValue() => _defaultValue;

  @override
  dynamic getUserProvidedValue() => _userValue;

  @override
  bool hasDefaultValue() => _hasDefaultValue;

  @override
  int getPosition() => _position;

  @override
  bool hasUserProvidedValue() => _hasUserValue;

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
    result['isFinal'] = getIsFinal();
    result['isConst'] = getIsConst();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getType(),
      getValue(Object()),
      getDefaultValue(),
      getUserProvidedValue(),
      hasDefaultValue(),
      hasUserProvidedValue(),
      getIsFinal(),
      getIsConst(),
    ];
  }
}