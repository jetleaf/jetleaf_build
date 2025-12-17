part of 'declaration.dart';

/// {@template annotation}
/// Represents an annotation that has been applied to a class, method,
/// field, parameter, or other Dart declarations at runtime.
///
/// This interface gives you access to:
/// - The [TypeDeclaration] of the annotation
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
abstract class AnnotationDeclaration extends EntityDeclaration {
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

  /// Retrieves the element annotation from analyzer. This differs from [getElement] method that
  /// provides the class element of the annotation.
  ElementAnnotation? getElementAnnotation();

  @override
  InterfaceType? getDartType();
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
abstract class AnnotationFieldDeclaration extends SourceDeclaration {
  /// {@macro annotation_field}
  const AnnotationFieldDeclaration();

  /// Returns the type of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getTypeDeclaration().getName())); // ["value"]
  /// ```
  LinkDeclaration getLinkDeclaration();

  /// Returns the value of the field.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getValue())); // ["value"]
  /// ```
  dynamic getValue();

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

  /// Returns true if the field is nullable.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isNullable())); // [true]
  /// ```
  bool isNullable();

  /// Returns true if the field is final.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isFinal())); // [true]
  /// ```
  bool isFinal();

  /// Returns true if the field is const.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.isConst())); // [true]
  /// ```
  bool isConst();

  /// Returns the position of the field in the source code.
  /// 
  /// ### Example
  /// ```dart
  /// final annotation = ...;
  /// final fields = annotation.getFields();
  /// print(fields.map((f) => f.getPosition())); // [1]
  /// ```
  int getPosition();
}