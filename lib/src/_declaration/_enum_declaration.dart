part of '../declaration/declaration.dart';

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
final class StandardEnumDeclaration extends StandardClassDeclaration implements EnumDeclaration {
  final List<EnumFieldDeclaration> _values;

  /// {@macro standard_enum}
  StandardEnumDeclaration({
    required super.name,
    required super.type,
    required super.element,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    super.qualifiedName,
    required super.parentLibrary,
    super.isNullable = false,
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
    result['declaration'] = 'enum';
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

    final declaration = getDeclaration();
    if (declaration != null) {
      result['declaration'] = declaration.toJson();
    }

    result['type'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();
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
      getValues(),
      getMembers(),
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
      element: getElement(),
      dartType: getDartType(),
      isPublic: getIsPublic(),
      isSynthetic: getIsSynthetic(),
      parentLibrary: getParentLibrary(),
      values: enumFields ?? getValues(),
      constructors: constructors ?? getConstructors(),
      fields: fields ?? getFields(),
      methods: methods ?? getMethods(),
      isNullable: getIsNullable(),
      typeArguments: getTypeArguments(),
      annotations: getAnnotations(),
      sourceLocation: getSourceLocation(),
      qualifiedName: getQualifiedName(),
      mixins: getMixins(),
      interfaces: getInterfaces(),
      superClass: getSuperClass()
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
final class StandardEnumFieldDeclaration extends StandardSourceDeclaration implements EnumFieldDeclaration {
  /// The runtime value of the enum field
  final dynamic _value;

  /// The enum field position
  final int _position;

  /// Whether this enum field is nullable
  final bool _isNullable;

  /// Creates a standard enum field declaration
  ///
  /// {@template standard_enum_field_constructor}
  /// Parameters:
  /// - [_name]: The declared name of the enum value
  /// - [_value]: The actual enum value instance  
  /// - [_enum]: The parent enum declaration
  ///
  /// All parameters are required and immutable.
  /// {@endtemplate}
  const StandardEnumFieldDeclaration({
    required super.name,
    super.element,
    super.dartType,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    required dynamic value,
    required int position,
    required super.libraryDeclaration,
    super.annotations,
    required bool isNullable,
  }) : _value = value, _position = position, _isNullable = isNullable;

  @override
  dynamic getValue() => _value;

  @override
  int getPosition() => _position;

  @override
  bool isNullable() => _isNullable;

  @override
  String getDebugIdentifier() => 'enum_field_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'enum_field';
    result['name'] = getName();
    result['value'] = getValue();
    result['type'] = getType().toString();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getValue(),
      getType(),
    ];
  }
}