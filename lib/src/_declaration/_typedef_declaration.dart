part of '../declaration/declaration.dart';

/// {@template standard_typedef}
/// Standard implementation of [TypedefDeclaration] used by JetLeaf's reflection system.
///
/// Represents a Dart `typedef`, capturing its name, underlying aliased type,
/// type parameters, parent library, annotations, and source location.
///
/// This class provides access to both the structural and metadata aspects of a typedef,
/// including support for resolving its aliased type and understanding whether the type is nullable.
///
/// ## Example
/// ```dart
/// typedef IntList = List<int>;
///
/// final typedef = StandardReflectedTypedef(
///   name: 'IntList',
///   type: IntList,
///   parentLibrary: myLibrary,
///   aliasedType: myListType,
/// );
///
/// print(typedef.getName()); // IntList
/// print(typedef.getAliasedType()); // List<int>
/// ```
/// {@endtemplate}
final class StandardTypedefDeclaration extends StandardTypeDeclaration implements TypedefDeclaration {
  final LibraryDeclaration _parentLibrary;
  final LinkDeclaration _aliasedType;
  final FunctionLinkDeclaration _referent;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;

  /// {@macro standard_typedef}
  StandardTypedefDeclaration({
    required super.name,
    required super.type,
    required super.element,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    String? qualifiedName,
    required LibraryDeclaration parentLibrary,
    required LinkDeclaration aliasedType,
    super.isNullable = false,
    super.typeArguments,
    required FunctionLinkDeclaration referent,
    required List<AnnotationDeclaration> annotations,
    Uri? sourceLocation,
  })  : _parentLibrary = parentLibrary,
        _aliasedType = aliasedType,
        _referent = referent,
        _sourceLocation = sourceLocation,
        _annotations = annotations,
        super(
          qualifiedName: qualifiedName ?? '${parentLibrary.getUri()}.$name',
          simpleName: name,
          packageUri: parentLibrary.getUri(),
          kind: TypeKind.typedefType,
        );

  @override
  LibraryDeclaration getParentLibrary() => _parentLibrary;

  @override
  FunctionLinkDeclaration getReferent() => _referent;

  @override
  List<AnnotationDeclaration> getAnnotations() => UnmodifiableListView(_annotations);

  @override
  bool isFunction() => getAliasedType() is FunctionLinkDeclaration;

  @override
  bool isRecord() => getAliasedType() is RecordLinkDeclaration;

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  LinkDeclaration getAliasedType() => _aliasedType;

  @override
  String getDebugIdentifier() => 'typedef_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = "typedef";
    result['name'] = getName();
    result['type'] = "${getType()}";
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();

    final arguments = getTypeArguments().map((a) => a.toJson()).toList();
    if(arguments.isNotEmpty) {
      result['typeArguments'] = arguments;
    }
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }
    
    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }
    
    final aliasedType = getAliasedType().toJson();
    if(aliasedType.isNotEmpty) {
      result['aliasedType'] = aliasedType;
    }

    final referent = getReferent().toJson();
    if(referent.isNotEmpty) {
      result['referent'] = referent;
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
      getKind(),
      getTypeArguments(),
      getAliasedType(),
      getReferent()
    ];
  }
}