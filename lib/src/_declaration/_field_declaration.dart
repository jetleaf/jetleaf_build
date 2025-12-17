part of '../declaration/declaration.dart';

/// {@template standard_field}
/// A standard implementation of [FieldDeclaration] that provides metadata and 
/// runtime access to class fields in a reflective system.
///
/// This class encapsulates all the necessary metadata about a Dart class field, 
/// such as its name, type, annotations, modifiers (`final`, `const`, `static`, etc.), 
/// and optionally supports runtime value access through provided getter/setter functions.
///
/// ## Example
/// ```dart
/// final field = StandardReflectedField(
///   name: 'age',
///   type: IntReflectedType(),
///   parentLibrary: myLibrary,
///   parentClass: myClass,
/// );
///
/// print(field.getName()); // age
/// print(field.getType()); // ReflectedType for int
/// print(field.getValue(someInstance)); // gets age
/// field.setValue(someInstance, 25); // sets age
/// ```
/// {@endtemplate}
final class StandardFieldDeclaration extends StandardSourceDeclaration implements FieldDeclaration {
  final LinkDeclaration? _parentClass;
  final LinkDeclaration _typeDeclaration;
  final bool _isFinal;
  final bool _isConst;
  final bool _isLate;
  final bool _isStatic;
  final bool _isAbstract;
  final bool _isNullable;
  final bool isTopLevel;

  /// {@macro standard_field}
  const StandardFieldDeclaration({
    required super.name,
    required super.type,
    super.dartType,
    super.element,
    required super.libraryDeclaration,
    LinkDeclaration? parentClass,
    required LinkDeclaration linkDeclaration,
    super.annotations,
    required super.isPublic,
    required super.isSynthetic,
    super.sourceLocation,
    bool isFinal = false,
    bool isConst = false,
    bool isLate = false,
    bool isStatic = false,
    bool isAbstract = false,
    bool isNullable = false,
    this.isTopLevel = false,
  })  : _parentClass = parentClass,
        _typeDeclaration = linkDeclaration,
        _isFinal = isFinal,
        _isConst = isConst,
        _isNullable = isNullable,
        _isLate = isLate,
        _isStatic = isStatic,
        _isAbstract = isAbstract;

  @override
  LinkDeclaration? getParentClass() => _parentClass;

  @override
  LinkDeclaration getLinkDeclaration() => _typeDeclaration;

  @override
  bool getIsFinal() => _isFinal;

  @override
  bool getIsConst() => _isConst;

  @override
  bool getIsTopLevel() => isTopLevel;

  @override
  bool getIsLate() => _isLate;

  @override
  bool getIsStatic() => _isStatic;

  @override
  bool getIsAbstract() => _isAbstract;

  @override
  bool isNullable() => _isNullable;

  @override
  bool isFunction() => getLinkDeclaration() is FunctionLinkDeclaration;

  @override
  bool isRecord() => getLinkDeclaration() is RecordLinkDeclaration;

  @override
  dynamic getValue(dynamic instance) {
    if (getIsPublic()) {
      if (_isStatic) {
        return Runtime.getRuntimeResolver().getValue(instance, _name);
      } else {
        return Runtime.getRuntimeResolver().getValue(instance, _name);
      }
    }

    throw PrivateFieldAccessException(instance, getName());
  }

  @override
  void setValue(dynamic instance, dynamic value) {
    if ((_isFinal || _isConst) && !_isLate) {
      throw FieldMutationException(instance, getName());
    }
    
    if (getIsPublic()) {
      if (_isStatic) {
        return Runtime.getRuntimeResolver().setValue(instance, _name, value);
      } else {
        return Runtime.getRuntimeResolver().setValue(instance, _name, value);
      }
    } else {
      throw PrivateFieldAccessException(instance, getName());
    }
  }

  @override
  String getDebugIdentifier() => 'field_${getParentClass()?.getName()}.${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'field';
    result['name'] = getName();

    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }
    
    final parentClass = getParentClass()?.toJson();
    if(parentClass != null) {
      result['parentClass'] = parentClass;
    }
    
    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }
    
    result['isFinal'] = getIsFinal();
    result['isConst'] = getIsConst();
    result['isLate'] = getIsLate();
    result['isStatic'] = getIsStatic();
    result['isAbstract'] = getIsAbstract();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getParentClass(),
      getIsStatic(),
      getIsAbstract(),
      getType(),
      getIsFinal(),
      getIsConst(),
      getIsLate(),
    ];
  }
}