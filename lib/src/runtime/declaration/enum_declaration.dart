part of 'declaration.dart';

/// {@template enum}
/// Represents a reflected Dart `enum` type, providing access to its
/// enum entry names, metadata, and declared members (fields, methods).
///
/// ### Example
/// ```dart
/// final type = reflector.reflectType(MyEnum).asEnumType();
///
/// print(type?.getName()); // MyEnum
/// print(type?.getValues()); // [active, inactive, unknown]
///
/// for (final member in type!.getMembers()) {
///   print(member.getName());
/// }
/// ```
/// {@endtemplate}
abstract final class EnumDeclaration extends ClassDeclaration implements SourceDeclaration {
  /// {@macro enum}
  const EnumDeclaration();

  /// Returns the list of enum value names declared in this enum.
  ///
  /// ### Example
  /// ```dart
  /// final values = enumType.getValues();
  /// print(values); // ['small', 'medium', 'large']
  /// ```
  List<EnumFieldDeclaration> getValues();
}

/// {@template enum_field_declaration}
/// Abstract base class representing a field (value) within an enum declaration.
///
/// Provides reflective access to enum value metadata including:
/// - Name and value of the enum field
/// - Type information
/// - Parent enum declaration
///
/// {@template enum_field_declaration_features}
/// ## Key Features
/// - Enum value name access
/// - Raw value inspection
/// - Type-safe enum value handling
/// - Parent enum resolution
///
/// ## Implementations
/// Typically implemented by code generators or runtime reflection systems.
/// {@endtemplate}
///
/// {@template enum_field_declaration_example}
/// ## Example Usage
/// ```dart
/// enum Status { active, paused }
///
/// final enumDecl = reflector.getEnumDeclaration(Status);
/// final activeField = enumDecl.getField('active');
///
/// print(activeField.getName()); // 'active'
/// print(activeField.getValue()); // Status.active
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract final class EnumFieldDeclaration extends FieldDeclaration {
  /// Creates a new enum field declaration.
  const EnumFieldDeclaration();

  /// This is the position of the enum field, as-is on the enum class.
  /// 
  /// Example:
  /// ```dart
  /// final position = field.getPosition(); // Returns 1
  /// ```
  int getPosition();

  /// Gets the runtime value of this enum field.
  ///
  /// {@template enum_field_get_value}
  /// Returns:
  /// - The actual enum value instance
  ///
  /// Example:
  /// ```dart
  /// final value = field.getEnumValue(); // Returns Status.active
  /// ```
  /// {@endtemplate}
  dynamic getEnumValue();
}

/// {@template standard_enum}
/// A standard implementation of [EnumDeclaration] that provides reflection
/// metadata about an enum declaration in a Dart program.
///
/// This class exposes the name, runtime type, nullability, type arguments,
/// parent library, annotations, enum values, source location, and declared members.
///
/// ## Example
///
/// ```dart
/// final enumType = StandardReflectedEnum(
///   name: 'Color',
///   type: Color,
///   parentLibrary: myLibrary,
///   values: ['red', 'green', 'blue'],
/// );
///
/// print(enumType.getName()); // Color
/// print(enumType.getValues()); // [red, green, blue]
/// print(enumType.getKind()); // TypeKind.enumType
/// ```
///
/// Useful for tools and frameworks that need to inspect or work with enums
/// at runtime or during analysis, especially in reflection-based systems.
///
/// {@endtemplate}
@internal
final class StandardEnumDeclaration extends StandardClassDeclaration implements EnumDeclaration {
  final List<EnumFieldDeclaration> _values;

  /// {@macro standard_enum}
  StandardEnumDeclaration({
    required super.name,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    super.qualifiedName,
    required super.library,
    super.typeArguments,
    super.annotations,
    super.constructors,
    super.fields,
    super.interfaces,
    super.isAbstract = false,
    super.isBase = false,
    super.isFinal = false,
    super.isInterface = false,
    super.isMixin = false,
    super.isRecord = false,
    super.isSealed = false,
    super.methods,
    super.mixins,
    super.sourceLocation,
    super.superClass,
    required List<EnumFieldDeclaration> values,
  })  : _values = values, super(kind: TypeKind.enumType);

  @override
  List<EnumFieldDeclaration> getValues() => List.unmodifiable(_values);

  @override
  String getDebugIdentifier() => 'enum_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'enum';
    result['name'] = getName();
    
    final parentLibrary = getLibrary().toJson();
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

    final values = getValues();
    if (values.isNotEmpty) {
      result['values'] = values;
    }

    final members = getMembers();
    if (members.isNotEmpty) {
      result['members'] = members.map((m) => m.toJson()).toList();
    }

    final typeArguments = getTypeArguments();
    if (typeArguments.isNotEmpty) {
      result['typeArguments'] = typeArguments.map((t) => t.toJson()).toList();
    }

    result['type'] = getType().toString();
    result['kind'] = getKind().toString();

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

  StandardEnumDeclaration updateWith({
    List<ConstructorDeclaration>? constructors,
    List<FieldDeclaration>? fields,
    List<MethodDeclaration>? methods,
    List<EnumFieldDeclaration>? enumFields
  }) {
    return StandardEnumDeclaration(
      name: getName(),
      type: getType(),
      isPublic: getIsPublic(),
      isSynthetic: getIsSynthetic(),
      library: getLibrary(),
      values: enumFields ?? getValues(),
      constructors: constructors ?? getConstructors(),
      fields: fields ?? getFields(),
      methods: methods ?? getMethods(),
      typeArguments: getTypeArguments(),
      annotations: getAnnotations(),
      sourceLocation: getSourceLocation(),
      qualifiedName: getQualifiedName(),
      mixins: getMixins(),
      interfaces: getInterfaces(),
      superClass: getSuperClass(),
      isRecord: false,
      isAbstract: getIsAbstract(),
      isBase: getIsBase(),
      isFinal: getIsFinal(),
      isInterface: getIsInterface(),
      isMixin: getIsMixin(),
      isSealed: getIsSealed(),
    );
  }
}

/// {@template standard_enum_field_declaration}
/// Concrete implementation of [EnumFieldDeclaration] representing an enum value.
///
/// Provides standard reflective access to enum values with efficient storage
/// of the name, value, and parent enum reference.
///
/// {@template standard_enum_field_declaration_features}
/// ## Key Features
/// - Lightweight immutable implementation
/// - Efficient value storage
/// - JSON serialization support
/// - Value equality comparison
/// - Debug identifiers
///
/// ## Typical Usage
/// Used by code generators and runtime systems to represent enum values
/// in reflection contexts.
/// {@endtemplate}
///
/// {@template standard_enum_field_declaration_example}
/// ## Example Creation
/// ```dart
/// enum Status { active, paused }
///
/// final enumDecl = StandardEnumDeclaration(
///   'Status', 
///   Status.values,
///   Status.type
/// );
///
/// final field = StandardEnumFieldDeclaration(
///   'active',
///   Status.active,
///   enumDecl
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
@internal
final class StandardEnumFieldDeclaration extends StandardFieldDeclaration implements EnumFieldDeclaration {
  /// The runtime value of the enum field
  final dynamic _value;

  /// The enum field position
  final int _position;

  /// Creates a standard enum field declaration
  ///
  /// {@template standard_enum_field_constructor}
  /// Parameters:
  /// - [_name]: The declared name of the enum value
  /// - [_value]: The actual enum value instance  
  ///
  /// All parameters are required and immutable.
  /// {@endtemplate}
  const StandardEnumFieldDeclaration({
    required super.name,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    required dynamic value,
    required int position,
    super.annotations,
    required bool isNullable,
    required super.linkDeclaration,
  }) : _value = value, _position = position;

  @override
  dynamic getValue(dynamic instance) => _value;

  @override
  dynamic getEnumValue() => getValue(Object());

  @override
  void setValue(instance, value) { }

  @override
  int getPosition() => _position;

  @override
  bool isNullable() => _isNullable;

  @override
  String getDebugIdentifier() => 'enum_field_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'enum_field';
    result['name'] = getName();
    result['value'] = getValue(Object());
    result['type'] = getType().toString();

    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getValue(Object()),
      getType(),
    ];
  }
}