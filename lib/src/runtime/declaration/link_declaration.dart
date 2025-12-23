part of 'declaration.dart';

/// {@template link_declaration}
/// Abstract base class for type references in reflection systems.
///
/// Represents a reference to a type declaration, including:
/// - Type arguments
/// - Pointer information
/// - Source location metadata
/// - Variance information
///
/// {@template link_declaration_features}
/// ## Key Features
/// - Type parameter resolution
/// - Source location tracking
/// - Variance awareness
/// - Canonical vs reference distinction
///
/// ## Typical Implementations
/// Used by:
/// - Generic type references
/// - Type alias resolutions
/// - Cross-library type references
/// {@endtemplate}
///
/// {@template link_declaration_example}
/// ## Example Usage
/// ```dart
/// final link = getTypeReference<List<String>>();
/// print(link.getPointerQualifiedName()); // "List"
/// print(link.getTypeArguments()[0].getName()); // "String"
/// print(link.getVariance()); // TypeVariance.invariant
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract final class LinkDeclaration extends Declaration {
  /// {@macro link_declaration}
  const LinkDeclaration();

  /// Gets the type arguments for this reference.
  ///
  /// {@template get_type_arguments}
  /// Returns:
  /// - A list of [LinkDeclaration] for each type argument
  /// - Empty list for non-generic types
  /// - Preserves declaration order
  /// {@endtemplate}
  List<LinkDeclaration> getTypeArguments();

  /// Gets the base pointer type being referenced.
  ///
  /// {@template get_pointer_type}
  /// Returns:
  /// - The raw [Type] without type arguments
  /// - For `List<String>` returns `List`
  /// {@endtemplate}
  Type getPointerType();

  /// Gets the fully qualified name of the pointer type.
  ///
  /// {@template get_pointer_qualified_name}
  /// Returns:
  /// - The qualified name including library/package
  /// - Example: "package:collection/equality.dart#ListEquality"
  /// {@endtemplate}
  String getPointerQualifiedName();

  /// Gets the canonical definition location.
  ///
  /// {@template get_canonical_uri}
  /// Returns:
  /// - The [Uri] where the type is originally defined
  /// - `null` if location is unknown
  /// {@endtemplate}
  Uri? getCanonicalUri();

  /// Gets where this reference was found.
  ///
  /// {@template get_reference_uri}
  /// Returns:
  /// - The [Uri] where this reference appears
  /// - May differ from canonical location for imports/aliases
  /// {@endtemplate}
  Uri? getReferenceUri();

  /// Checks if this reference points to its canonical definition.
  ///
  /// {@template get_is_canonical}
  /// Returns:
  /// - `true` if reference location matches canonical location
  /// - `false` for imported/aliased references
  /// {@endtemplate}
  bool getIsCanonical();
}

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
@internal
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
  List<Object?> equalizedProperties() => [_pointerType, _pointerQualifiedName, _canonicalUri, _referenceUri, _typeArguments];
}