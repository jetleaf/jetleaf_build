// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:ffi';
import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import 'abstract_constructor_declaration_support.dart';

/// {@template abstract_typedef_declaration_support}
/// Abstract support class for generating [TypedefDeclaration]s and
/// handling type-related reflections within the JetLeaf framework.
///
/// [AbstractTypedefDeclarationSupport] extends
/// [AbstractConstructorDeclarationSupport] to provide specialized
/// functionality for creating rich, metadata-aware representations
/// of Dart typedefs and type declarations. It integrates both mirrors
/// and analyzer-based approaches to extract detailed type information,
/// including aliased types, type arguments, annotations, and nullability.
///
/// This class is primarily intended for internal use within the
/// framework to facilitate reflection, code generation, and
/// type-safe analysis. Key responsibilities include:
///
/// - Resolving typedef elements from analyzer [TypedefElement]s and
///   mirror information ([mirrors.TypedefMirror]).
/// - Extracting the aliased type represented by a typedef.
/// - Generating fully linked type declarations, including nested and
///   generic types.
/// - Handling annotations, including generic type annotations that
///   require resolution.
/// - Determining visibility (public/private) and synthetic status
///   for typedefs and type declarations.
/// - Caching generated type representations to optimize repeated
///   type resolution.
///
/// Typical usage:
/// ```dart
/// final typedefSupport = MyTypedefSupport(...);
/// final typedefDeclaration = await typedefSupport.generateTypedef(
///   typedefMirror,
///   package,
///   libraryUri,
///   sourceUri,
/// );
/// ```
///
/// **Notes:**
/// - This class does not instantiate types; it generates metadata
///   representations suitable for reflection or code generation.
/// - Type declarations generated may include type arguments, aliased
///   types, and annotations to fully describe complex type structures.
/// - Nullability and generic type resolution are handled automatically
///   using a combination of mirrors, analyzer elements, and
///   annotation-based inference.
/// {@endtemplate}
abstract class AbstractTypedefDeclarationSupport extends AbstractConstructorDeclarationSupport {
  /// Initializes an instance of [AbstractTypedefDeclarationSupport].
  ///
  /// The constructor requires the same configuration parameters as
  /// [AbstractConstructorDeclarationSupport], including access to
  /// the mirror system, package context, and logging callbacks.
  /// 
  /// {@macro abstract_typedef_declaration_support}
  AbstractTypedefDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  /// Generates a [TypedefDeclaration] for a given [TypedefMirror] using
  /// both reflection and analyzer support.
  ///
  /// This method extracts all available metadata about the typedef,
  /// including its aliased type, type arguments, annotations, and
  /// nullability. It resolves the runtime type using mirrors, and if
  /// the type involves generics, it attempts to resolve them using
  /// annotations and [GenericTypeParser].
  ///
  /// The generated [StandardTypedefDeclaration] includes:
  /// - Name and qualified name of the typedef
  /// - Aliased type representation
  /// - Type arguments as linked declarations
  /// - Annotations
  /// - Visibility (public/private) and synthetic status
  /// - Source location URI
  ///
  /// Additionally, the resolved type is cached in [typeCache] to avoid
  /// repeated computation for the same runtime type.
  ///
  /// Example usage:
  /// ```dart
  /// final typedefDeclaration = await typedefSupport.generateTypedef(
  ///   typedefMirror,
  ///   package,
  ///   libraryUri,
  ///   sourceUri,
  /// );
  /// ```
  ///
  /// Parameters:
  /// - [typedefMirror]: The mirror representing the typedef to generate.
  /// - [package]: The current package context for resolution of types
  ///   and annotations.
  /// - [libraryUri]: URI of the library containing the typedef.
  /// - [sourceUri]: Source URI for locating the typedef in the project.
  ///
  /// Returns:
  /// A [Future] resolving to a fully populated [TypedefDeclaration].
  @protected
  Future<TypedefDeclaration> generateTypedef(mirrors.TypedefMirror typedefMirror, Package package, String libraryUri, Uri sourceUri) async {
    final typedefName = mirrors.MirrorSystem.getName(typedefMirror.simpleName);
    final typedefElement = await getAnalyzedTypeAliasDeclaration(typedefName, sourceUri);
    final dartType = typedefElement?.returnType;

    Type type = typedefMirror.hasReflectedType ? typedefMirror.reflectedType : typedefMirror.runtimeType;
    final annotations = await extractAnnotations(typedefMirror.metadata, libraryUri, sourceUri, package, typedefElement?.metadata);
    type = await resolveGenericAnnotationIfNeeded(type, typedefMirror, package, libraryUri, sourceUri, typedefName);

    return StandardTypedefDeclaration(
      name: typedefName,
      type: type,
      qualifiedName: buildQualifiedName(typedefName, (typedefMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: await getLibrary(libraryUri),
      aliasedType: await getLinkDeclaration(typedefMirror.referent, package, libraryUri, dartType),
      isNullable: false,
      isPublic: !isInternal(typedefName),
      isSynthetic: typedefElement?.isSynthetic ?? isSynthetic(typedefName),
      typeArguments: await extractTypeVariableAsLinks(typedefMirror.typeVariables, typedefElement?.typeParameters, package, libraryUri),
      annotations: annotations,
      sourceLocation: sourceUri,
      referent: await generateFunctionLinkDeclarationFromMirror(typedefMirror.referent, null, package, libraryUri)
    );
  }
}