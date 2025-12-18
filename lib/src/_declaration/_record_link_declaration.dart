part of '../declaration/declaration.dart';

/// {@template standard_record}
/// A standard implementation of [RecordDeclaration] used to represent Dart [Record] types,
/// including their positional and named fields, type arguments, annotations,
/// and parent library metadata.
///
/// This is useful for reflecting on Dart record types, such as:
/// ```dart
/// (int, String name)
/// ```
/// where the positional and named fields can be inspected at runtime.
///
/// ## Example
/// ```dart
/// final recordType = StandardReflectedRecord(
///   name: '(int, {String name})',
///   type: (int, {String name}).type,
///   parentLibrary: myLibrary,
///   positionalFields: [StandardReflectedRecordField(position: 0, type: intType)],
///   namedFields: {
///     'name': StandardReflectedRecordField(name: 'name', type: stringType),
///   },
/// )show DartType, InterfaceType, ParameterizedType, RecordType, RecordTypeField// print(recordType.getNamedFields().keys); // (name)
/// ```
/// {@endtemplate}
final class StandardRecordLinkDeclaration extends StandardLinkDeclaration implements RecordLinkDeclaration {
  final List<RecordFieldDeclaration> _fields;
  final bool _isNullable;

  /// {@macro standard_record}
  StandardRecordLinkDeclaration({
    required super.name,
    required super.type,
    required super.pointerType,
    super.typeArguments = const [],
    required super.qualifiedName,
    super.canonicalUri,
    required super.isPublic,
    required super.isSynthetic,
    super.referenceUri,
    bool isNullable = false,
    List<RecordFieldDeclaration> fields = const [],
  })  : _fields = fields, _isNullable = isNullable;

  @override
  List<RecordFieldDeclaration> getFields() => List.unmodifiable(_fields);

  @override
  RecordFieldDeclaration? getField(String name) => _fields.where((f) => f.getName() == name).firstOrNull;

  @override
  RecordFieldDeclaration? getPositionalField(int position) => _fields.where((f) => f.getPosition() == position).firstOrNull;

  @override
  bool getIsNullable() => _isNullable;

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {...super.toJson()};
    result['declaration'] = 'record';
    result['name'] = getName();
    result['isNullable'] = getIsNullable();
    result['type'] = getType().toString();

    final arguments = getTypeArguments().map((t) => t.toJson()).toList();
    if(arguments.isNotEmpty) {
      result['typeArguments'] = arguments;
    }

    final fields = getFields().map((f) => f.toJson()).toList();
    if(fields.isNotEmpty) {
      result['fields'] = fields;
    }
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getType(),
      getFields(),
      ...super.equalizedProperties()
    ];
  }
}

/// {@template standard_record_field}
/// Represents an individual field within a Dart record type, either positional or named.
///
/// The field contains metadata such as its position (for positional fields),
/// name (for named fields), and the reflected type.
///
/// ## Example
/// ```dart
/// final positional = StandardReflectedRecordField(
///   position: 0,
///   type: intType,
/// );
///
/// final named = StandardReflectedRecordField(
///   name: 'label',
///   type: stringType,
/// );
///
/// print(positional.getIsPositional()); // true
/// print(named.getIsNamed()); // true
/// ```
/// {@endtemplate}
final class StandardRecordFieldDeclaration extends StandardLinkDeclaration implements RecordFieldDeclaration {
  final int _position; // null for named fields
  final bool _isNullable;
  final bool _isNamed;
  final LinkDeclaration _fieldLinkDeclaration;

  /// {@macro standard_record_field}
  const StandardRecordFieldDeclaration({
    required super.name,
    required super.type,
    required super.pointerType,
    super.typeArguments = const [],
    required super.qualifiedName,
    super.canonicalUri,
    required super.isPublic,
    required super.isSynthetic,
    super.referenceUri,
    int position = -1,
    required bool isNullable,
    required bool isNamed,
    required LinkDeclaration fieldLink,
  })  : _position = position, _isNullable = isNullable, _fieldLinkDeclaration = fieldLink, _isNamed = isNamed;

  @override
  String getName() => _name;

  @override
  int getPosition() => _position;

  @override
  Type getType() => _type;

  @override
  bool getIsNullable() => _isNullable;

  @override
  bool getIsNamed() => _isNamed;

  @override
  bool getIsPositional() => !_isNamed;

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'record_field';
    result['name'] = getName();
    result['position'] = _position;
    result['isNamed'] = getIsNamed();
    result['isPositional'] = getIsPositional();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getPosition(),
      getType(),
      getIsNamed(),
      getIsPositional(),
      getLinkDeclaration(),
      ...super.equalizedProperties(),
    ];
  }
  
  @override
  LinkDeclaration getLinkDeclaration() => _fieldLinkDeclaration;
}