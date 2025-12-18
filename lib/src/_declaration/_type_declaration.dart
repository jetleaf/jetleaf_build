part of '../declaration/declaration.dart';

/// {@template standard_type}
/// A standard implementation of [TypeDeclaration] for representing common Dart types,
/// such as primitive types, classes, enums, typedefs, and records.
///
/// This class holds metadata such as the type's name, runtime representation,
/// nullability, kind (e.g., class, enum), generic type arguments, and optionally
/// a reference to a [SourceDeclaration].
///
/// ## Example
/// ```dart
/// final type = StandardReflectedType(
///   name: 'String',
///   type: String,
///   isNullable: false,
///   kind: TypeKind.classType,
///   declaration: MyReflectedClassDeclaration(),
/// );
///
/// print(type.getName()); // "String"
/// print(type.getKind()); // TypeKind.classType
/// ```
/// {@endtemplate}
final class StandardTypeDeclaration extends TypeDeclaration with EqualsAndHashCode {
  final String _name;
  final bool _isNullable;
  final TypeKind _kind;
  final Type _type;
  final String _qualifiedName;
  final String _simpleName;
  final String _packageUri;
  final List<LinkDeclaration> _mixins;
  final List<LinkDeclaration> _interfaces;
  final LinkDeclaration? _superClass;
  final List<LinkDeclaration> _typeArguments;
  final bool _isPublic;
  final bool _isSynthetic;

  /// {@macro standard_type}
  const StandardTypeDeclaration({
    required String name,
    required bool isNullable,
    required TypeKind kind,
    required Type type,
    required String qualifiedName,
    required String simpleName,
    required String packageUri,
    List<LinkDeclaration> mixins = const [],
    List<LinkDeclaration> interfaces = const [],
    LinkDeclaration? superClass,
    required bool isPublic,
    required bool isSynthetic,
    List<LinkDeclaration> typeArguments = const [],
  })  : _name = name,
        _isNullable = isNullable,
        _isPublic = isPublic, _isSynthetic = isSynthetic,
        _typeArguments = typeArguments,
        _type = type,
        _kind = kind,
        _qualifiedName = qualifiedName,
        _simpleName = simpleName,
        _packageUri = packageUri,
        _mixins = mixins,
        _interfaces = interfaces,
        _superClass = superClass;

  @override
  String getName() => _name;

  @override
  bool getIsNullable() => _isNullable;

  @override
  bool getIsPublic() => _isPublic;

  @override
  bool getIsSynthetic() => _isSynthetic;

  @override
  TypeKind getKind() => _kind;

  @override
  bool isAssignableFrom(TypeDeclaration other)  {
    return other.isAssignableTo(this);
  }

  @override
  bool isAssignableTo(TypeDeclaration target) {
    // // Use analyzer's type system if available
    // if (hasAnalyzerSupport() && target.hasAnalyzerSupport()) {
    //   return _isAssignableToWithAnalyzer(target);
    // }
    
    // // Fallback to basic checking
    // return _isAssignableToBasic(target);
    return false;
  }

  // Private helper methods
  // bool _isAssignableToWithAnalyzer(TypeDeclaration target) {
  //   final from = getDartType();
  //   final to = target.getDartType();
    
  //   if (from == null || to == null) {
  //     return _isAssignableToBasic(target);
  //   }
    
  //   final typeSystem = from.element?.library?.typeSystem;
  //   if (typeSystem == null) {
  //     return _isAssignableToBasic(target);
  //   }
    
  //   return typeSystem.isAssignableTo(from, to);
  // }

  // bool _isAssignableToBasic(TypeDeclaration target) {
  //   // Basic assignability logic as fallback
  //   if (getName() == target.getName()) return true;
  //   if (getKind() == TypeKind.dynamicType && target.getKind() == TypeKind.dynamicType) return true;
  //   return false;
  // }

  @override
  bool isGeneric() => getTypeArguments().isNotEmpty || (getType().toString().contains("<") && getType().toString().endsWith(">"));

  @override
  List<LinkDeclaration> getTypeArguments() => List.unmodifiable(_typeArguments);
  
  @override
  String getPackageUri() => _packageUri;
  
  @override
  String getQualifiedName() => _qualifiedName;
  
  @override
  String getSimpleName() => _simpleName;
  
  @override
  LinkDeclaration? getSuperClass() => _superClass;

  @override
  List<LinkDeclaration> getMixins() => List.unmodifiable(_mixins);

  @override
  List<LinkDeclaration> getInterfaces() => List.unmodifiable(_interfaces);
  
  @override
  Type getType() => _type;

  @override
  String getDebugIdentifier() => "type_${getSimpleName().toLowerCase()}";

  @override
  List<Object?> equalizedProperties() {
    return [
      _name,
      _isNullable,
      _kind,
      _type,
      _qualifiedName,
      _simpleName,
      _packageUri,
      _mixins,
      _interfaces,
      _superClass,
      _typeArguments,
      _isPublic,
      _isSynthetic,
    ];
  }
}