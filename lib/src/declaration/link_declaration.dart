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
abstract class LinkDeclaration extends Declaration {
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