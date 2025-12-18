part of '../declaration/declaration.dart';

/// {@template standard_link_declaration}
/// A standard implementation of [LinkDeclaration] for representing links to
/// other types.
///
/// This class holds metadata such as the type's name, runtime representation,
/// nullability, kind (e.g., class, enum), generic type arguments, and optionally
/// a reference to a [SourceDeclaration].
///
/// ## Example
/// ```dart
/// final link = StandardReflectedLink(
///   name: 'List',
///   type: List,
///   pointerType: List,
///   pointerQualifiedName: 'List',
///   canonicalUri: Uri.parse('dart:core#List'),
///   referenceUri: Uri.parse('dart:core#List'),
///   variance: TypeVariance.invariant,
/// );
///
/// print(link.getName()); // "List"
/// print(link.getKind()); // TypeKind.classType
/// ```
/// {@endtemplate}
final class StandardLinkDeclaration extends StandardDeclaration implements LinkDeclaration {
  final Type _pointerType;
  final String _pointerQualifiedName;
  final Uri? _canonicalUri;
  final Uri? _referenceUri;
  final List<LinkDeclaration> _typeArguments;

  /// {@macro standard_link_declaration}
  const StandardLinkDeclaration({
    required super.name,
    required super.type,
    required Type pointerType,
    List<LinkDeclaration> typeArguments = const [],
    required String qualifiedName,
    Uri? canonicalUri,
    required super.isPublic,
    required super.isSynthetic,
    Uri? referenceUri,
  }) : _pointerType = pointerType, _pointerQualifiedName = qualifiedName, _typeArguments = typeArguments,
       _canonicalUri = canonicalUri, _referenceUri = referenceUri;

  @override
  Type getPointerType() => _pointerType;

  @override
  String getPointerQualifiedName() => _pointerQualifiedName;

  @override
  List<LinkDeclaration> getTypeArguments() => List.unmodifiable(_typeArguments);

  @override
  Uri? getCanonicalUri() => _canonicalUri;

  @override
  Uri? getReferenceUri() => _referenceUri;

  @override
  bool getIsCanonical() => _canonicalUri != null && _referenceUri != null && _canonicalUri == _referenceUri;

  @override
  Map<String, Object> toJson() => {
    "type": _type,
    "pointer": _pointerType,
    "qualified_name": _pointerQualifiedName,
    if(_canonicalUri != null) "canonical_uri": _canonicalUri.toString(),
    if(_referenceUri != null) "reference_uri": _referenceUri.toString(),
    if(_typeArguments.isNotEmpty) "type_arguments": _typeArguments.map((t) => t.toJson()).toList(),
  };

  @override
  List<Object?> equalizedProperties() {
    return [
      _pointerType,
      _pointerQualifiedName,
      _canonicalUri,
      _referenceUri,
      _typeArguments,
    ];
  }
}