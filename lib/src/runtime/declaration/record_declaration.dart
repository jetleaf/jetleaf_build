part of 'declaration.dart';

/// {@template record}
/// Represents a reflected Dart record type.
///
/// A Dart record consists of zero or more positional fields and optionally
/// named fields. This interface provides access to both positional and named
/// components of the record in a structured and introspectable form.
///
/// ## Example
/// ```dart
/// (int, String, {bool active}) record = (1, "hello", active: true);
///
/// ReflectedRecord reflected = ...;
/// reflected.getPositionalFields(); // returns field for int and String
/// reflected.getNamedFields();      // returns map with 'active': bool
/// ```
/// {@endtemplate}
abstract final class RecordDeclaration extends ClassDeclaration implements LinkDeclaration {
  /// {@macro record}
  const RecordDeclaration();

  /// Returns all fields declared by this record.
  ///
  /// The returned list includes **both positional and named fields** in a
  /// unified collection, preserving the declaration order where applicable.
  ///
  /// This method is useful when performing generic iteration over record
  /// components without needing to distinguish field kinds up front.
  ///
  /// ### Returns
  /// A list of [RecordFieldDeclaration] objects representing every field
  /// contained in the record.
  List<RecordFieldDeclaration> getRecordFields();

  /// Returns the named field with the given [name].
  ///
  /// This method performs a lookup among the record’s **named fields only**.
  /// Positional fields are ignored when resolving by name.
  ///
  /// If no named field exists with the provided identifier, this method
  /// returns `null` rather than throwing.
  ///
  /// ### Parameters
  /// - [name] — The name of the record field to retrieve.
  ///
  /// ### Returns
  /// The matching [RecordFieldDeclaration], or `null` if not found.
  RecordFieldDeclaration? getRecordField(String name);

  /// Returns the positional field at the specified [index].
  ///
  /// Positional fields are indexed starting from `0`, in the order they are
  /// declared within the record. Named fields are not considered by this
  /// accessor.
  ///
  /// If the index is out of bounds, this method safely returns `null`.
  ///
  /// ### Parameters
  /// - [index] — The zero-based index of the positional field.
  ///
  /// ### Returns
  /// The positional [RecordFieldDeclaration], or `null` if the index is invalid.
  RecordFieldDeclaration? getPositionalField(int index);

  /// Indicates whether this record type is nullable.
  ///
  /// A nullable record corresponds to a record type declared with a trailing
  /// `?`, such as `(int, String)?`.
  ///
  /// ### Returns
  /// `true` if the record type is nullable; otherwise, `false`.
  bool getIsNullable();
}

/// {@template record_field}
/// A representation of an individual field within a Dart record type in the
/// JetLeaf reflection system.
///
/// This abstraction allows inspecting both named and positional fields of a
/// record. Provides metadata such as name, position, type, and whether it's named.
///
/// ## Example
/// ```dart
/// final field = MyReflectedRecordField(...);
/// print(field.getIsNamed()); // true
/// ```
/// {@endtemplate}
abstract final class RecordFieldDeclaration extends FieldDeclaration {
  /// {@macro record_field}
  const RecordFieldDeclaration();

  /// Returns the positional index of this field within the record.
  ///
  /// Positional fields return a zero-based index reflecting their declaration
  /// order. Named fields always return `-1`.
  ///
  /// ### Returns
  /// The positional index, or `-1` if the field is named.
  int getPosition();

  /// Indicates whether this record field is a **named field**.
  ///
  /// Named fields are accessed by identifier rather than position and appear
  /// in records declared with named components.
  ///
  /// ### Returns
  /// `true` if the field is named; otherwise, `false`.
  bool getIsNamed();

  /// Indicates whether this record field is a **positional field**.
  ///
  /// Positional fields are indexed-based and declared before any named fields
  /// in a record type.
  ///
  /// ### Returns
  /// `true` if the field is positional; otherwise, `false`.
  bool getIsPositional();
}

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
@internal
final class StandardRecordDeclaration extends StandardClassDeclaration implements RecordDeclaration {
  final List<RecordFieldDeclaration> _recordFields;
  final bool _isNullable;

  final Type _pointerType;
  final Uri? _canonicalUri;
  final Uri? _referenceUri;

  /// {@macro standard_record}
  StandardRecordDeclaration({
    required super.name,
    required super.type,
    super.typeArguments = const [],
    required super.qualifiedName,
    required super.isPublic,
    required super.isSynthetic,
    bool isNullable = false,
    required Type pointerType,
    Uri? canonicalUri,
    Uri? referenceUri,
    List<RecordFieldDeclaration> recordFields = const [],
    required super.library,
  })  : _recordFields = recordFields, _isNullable = isNullable, _pointerType = pointerType,
       _canonicalUri = canonicalUri, _referenceUri = referenceUri, super(kind: TypeKind.recordType);

  @override
  bool getIsNullable() => _isNullable;

  @override
  Uri? getCanonicalUri() => _canonicalUri;
  
  @override
  bool getIsCanonical() => _canonicalUri != null && _referenceUri != null && _canonicalUri == _referenceUri;
  
  @override
  Type getPointerType() => _pointerType;
  
  @override
  Uri? getReferenceUri() => _referenceUri;

  @override
  String getPointerQualifiedName() => getQualifiedName();

  @override
  List<RecordFieldDeclaration> getRecordFields() => List.unmodifiable(_recordFields);

  @override
  RecordFieldDeclaration? getRecordField(String name) => _recordFields.where((f) => f.getName() == name).firstOrNull;

  @override
  RecordFieldDeclaration? getPositionalField(int position) => _recordFields.where((f) => f.getPosition() == position).firstOrNull;

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

    final fields = getRecordFields().map((f) => f.toJson()).toList();
    if(fields.isNotEmpty) {
      result['fields'] = fields;
    }
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
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
@internal
final class StandardRecordFieldDeclaration extends StandardFieldDeclaration implements RecordFieldDeclaration {
  final int _position;
  final bool _isNamed;

  /// {@macro standard_record_field}
  const StandardRecordFieldDeclaration({
    required super.name,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    super.isNullable,
    required super.linkDeclaration,
    super.sourceLocation,
    int position = -1,
    required bool isNamed,
  })  : _position = position, _isNamed = isNamed;

  @override
  int getPosition() => _position;

  @override
  bool getIsNamed() => _isNamed;

  @override
  bool getIsPositional() => !_isNamed;

  @override
  dynamic getValue(dynamic instance) => Object();

  @override
  void setValue(instance, value) {}

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {...super.toJson()};
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
}