// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:ffi';
import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../declaration/declaration.dart';
import '../utils/dart_type_resolver.dart';
import '../utils/generic_type_parser.dart';
import 'abstract_constructor_declaration_support.dart';

/// Support class for generating TypedefDeclaration.
abstract class AbstractTypedefDeclarationSupport extends AbstractConstructorDeclarationSupport {
  AbstractTypedefDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Get typedef element from analyzer
  @protected
  Future<TypeAliasElement?> getTypedefElement(String typedefName, Uri sourceUri) async {
    final libraryElement = await getLibraryElement(sourceUri);
    return libraryElement?.getTypeAlias(typedefName);
  }

  /// Generate typedef declaration with analyzer support
  @protected
  Future<TypedefDeclaration> generateTypedef(mirrors.TypedefMirror typedefMirror, Package package, String libraryUri, Uri sourceUri) async {
    final typedefName = mirrors.MirrorSystem.getName(typedefMirror.simpleName);
    final typedefElement = await getTypedefElement(typedefName, sourceUri);
    final dartType = typedefElement?.aliasedType;

    Type runtimeType = typedefMirror.hasReflectedType ? typedefMirror.reflectedType : typedefMirror.runtimeType;

    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(typedefMirror.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, typedefName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    StandardTypedefDeclaration reflectedTypedef = StandardTypedefDeclaration(
      name: typedefName,
      type: runtimeType,
      element: typedefElement,
      dartType: dartType,
      qualifiedName: buildQualifiedName(typedefName, (typedefMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      aliasedType: await generateType(typedefMirror.referent, package, libraryUri),
      isNullable: false,
      isPublic: !isInternal(typedefName),
      isSynthetic: isSynthetic(typedefName),
      typeArguments: await extractTypeArgumentsAsLinks(typedefMirror.typeVariables, typedefElement?.typeParameters, package, libraryUri),
      annotations: await extractAnnotations(typedefMirror.metadata, package),
      sourceLocation: sourceUri,
    );

    typeCache[runtimeType] = reflectedTypedef;
    return reflectedTypedef;
  }

  /// Generate built-in typedef declaration
  @protected
  Future<TypedefDeclaration> generateBuiltInTypedef(mirrors.TypedefMirror typedefMirror, Package package, String libraryUri, Uri sourceUri) async {
    final typedefName = mirrors.MirrorSystem.getName(typedefMirror.simpleName);

    Type runtimeType = typedefMirror.hasReflectedType ? typedefMirror.reflectedType : typedefMirror.runtimeType;

    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(typedefMirror.metadata, package);
      Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, typedefName);
      resolvedType ??= resolvePublicDartType(libraryUri, typedefName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    StandardTypedefDeclaration reflectedTypedef = StandardTypedefDeclaration(
      name: typedefName,
      type: runtimeType,
      element: null, // Built-in typedefs don't have analyzer elements
      dartType: null, // Built-in typedefs don't have analyzer DartType
      qualifiedName: buildQualifiedName(typedefName, (typedefMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      aliasedType: await generateType(typedefMirror.referent, package, libraryUri),
      isNullable: false,
      isPublic: !isInternal(typedefName),
      isSynthetic: isSynthetic(typedefName),
      typeArguments: await extractTypeArgumentsAsLinks(typedefMirror.typeVariables, null, package, libraryUri),
      annotations: await extractAnnotations(typedefMirror.metadata, package),
      sourceLocation: sourceUri,
    );

    typeCache[runtimeType] = reflectedTypedef;
    return reflectedTypedef;
  }

  /// Generate type declaration with analyzer support
  @protected
  Future<TypeDeclaration> generateType(mirrors.TypeMirror typeMirror, Package package, String libraryUri);
}