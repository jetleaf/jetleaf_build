// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../declaration/declaration.dart';
import '../utils/dart_type_resolver.dart';
import '../utils/generic_type_parser.dart';
import 'abstract_type_declaration_support.dart';

/// Support class for generating MixinDeclarations.
abstract class AbstractMixinDeclarationSupport extends AbstractTypeDeclarationSupport {
  AbstractMixinDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Get mixin element from analyzer
  @protected
  Future<MixinElement?> getMixinElement(String mixinName, Uri sourceUri) async {
    final libraryElement = await getLibraryElement(sourceUri);
    return libraryElement?.getMixin(mixinName);
  }

  /// Generate mixin declaration with analyzer support
  @protected
  Future<MixinDeclaration> generateMixin(mirrors.ClassMirror mixinMirror, Package package, String libraryUri, Uri sourceUri) async {
     final mixinName = mirrors.MirrorSystem.getName(mixinMirror.simpleName);
    
    Type runtimeType = mixinMirror.hasReflectedType ? mixinMirror.reflectedType : mixinMirror.runtimeType;

    // Get analyzer element
    final mixinElement = await getMixinElement(mixinName, sourceUri);
    final dartType = mixinElement?.thisType;

    final annotations = await extractAnnotations(mixinMirror.metadata, package);
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, mixinName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final fields = <FieldDeclaration>[];
    final methods = <MethodDeclaration>[];

    // Extract constraints and interfaces using LinkDeclarations
    final constraints = await extractMixinConstraintsAsLink(mixinMirror, mixinElement, package, libraryUri);
    final interfaces = await extractInterfacesAsLink(mixinMirror, mixinElement, package, libraryUri);

    StandardMixinDeclaration reflectedMixin = StandardMixinDeclaration(
      name: mixinName,
      type: runtimeType,
      element: mixinElement,
      dartType: dartType,
      qualifiedName: buildQualifiedName(mixinName, (mixinMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      isNullable: false,
      typeArguments: await extractTypeArgumentsAsLinks(mixinMirror.typeVariables, mixinElement?.typeParameters, package, libraryUri),
      annotations: annotations,
      sourceLocation: sourceUri,
      fields: fields,
      methods: methods,
      constraints: constraints,
      interfaces: interfaces,
      isPublic: !isInternal(mixinName),
      isSynthetic: isSynthetic(mixinName),
    );

    // Process fields
    for (final field in mixinMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
      fields.add(await generateField(field, mixinElement, package, libraryUri, sourceUri, mixinName, null, null));
    }

    // Process methods
    for (final method in mixinMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (!method.isConstructor && !method.isAbstract) {
        methods.add(await generateMethod(method, mixinElement, package, libraryUri, sourceUri, mixinName, null));
      }
    }

    reflectedMixin = reflectedMixin.copyWith(fields: fields, methods: methods);

    typeCache[runtimeType] = reflectedMixin;
    return reflectedMixin;
  }
}