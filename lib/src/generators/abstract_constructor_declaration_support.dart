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
import '../utils/generic_type_parser.dart';
import 'abstract_method_declaration_support.dart';

/// Support class for generating ConstructorDeclarations.
abstract class AbstractConstructorDeclarationSupport extends AbstractMethodDeclarationSupport {
  AbstractConstructorDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Generate constructor declaration with analyzer support
  @protected
  Future<ConstructorDeclaration> generateConstructor(
    mirrors.MethodMirror constructorMirror,
    Element? parentElement,
    Package package,
    String libraryUri,
    Uri sourceUri,
    String className,
    ClassDeclaration parentClass,
  ) async {
    final constructorName = mirrors.MirrorSystem.getName(constructorMirror.constructorName);
    
    ConstructorElement? constructorElement;
    if (parentElement is InterfaceElement) {
      if (constructorName.isEmpty) {
        constructorElement = parentElement.unnamedConstructor;
      } else {
        constructorElement = parentElement.getNamedConstructor(constructorName);
      }
    }

    final mirrorType = constructorMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    if (GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, constructorName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardConstructorDeclaration(
      name: constructorName.isEmpty ? '' : constructorName,
      type: runtimeType,
      element: constructorElement,
      dartType: constructorElement?.type,
      libraryDeclaration: libraryCache[libraryUri]!,
      parentClass: StandardLinkDeclaration(
        name: parentClass.getName(),
        type: parentClass.getType(),
        pointerType: parentClass.getType(),
        qualifiedName: parentClass.getQualifiedName(),
        isPublic: parentClass.getIsPublic(),
        canonicalUri: Uri.parse(parentClass.getPackageUri()),
        referenceUri: Uri.parse(parentClass.getPackageUri()),
        isSynthetic: parentClass.getIsSynthetic(),
      ),
      annotations: await extractAnnotations(constructorMirror.metadata, package),
      sourceLocation: sourceUri,
      isFactory: constructorMirror.isFactoryConstructor,
      isConst: constructorMirror.isConstConstructor,
      isPublic: !isInternal(constructorName),
      isSynthetic: isSynthetic(constructorName),
    );

    result.parameters = await extractParameters(constructorMirror.parameters, constructorElement?.typeParameters, package, libraryUri, result);

    return result;
  }

  /// Generate built-in constructor
  @protected
  Future<ConstructorDeclaration> generateBuiltInConstructor(
    mirrors.MethodMirror constructorMirror, 
    Package package, 
    String libraryUri, 
    Uri sourceUri, 
    String className, 
    ClassDeclaration parentClass
  ) async {
    final constructorName = mirrors.MirrorSystem.getName(constructorMirror.constructorName);

    final mirrorType = constructorMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    if (GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, constructorName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardConstructorDeclaration(
      name: constructorName.isEmpty ? '' : constructorName,
      type: runtimeType,
      element: null,
      dartType: null,
      libraryDeclaration: libraryCache[libraryUri]!,
      parentClass: StandardLinkDeclaration(
        name: parentClass.getName(),
        type: parentClass.getType(),
        pointerType: parentClass.getType(),
        qualifiedName: parentClass.getQualifiedName(),
        isPublic: parentClass.getIsPublic(),
        canonicalUri: Uri.parse(parentClass.getPackageUri()),
        referenceUri: Uri.parse(parentClass.getPackageUri()),
        isSynthetic: parentClass.getIsSynthetic(),
      ),
      annotations: await extractAnnotations(constructorMirror.metadata, package),
      sourceLocation: sourceUri,
      isFactory: constructorMirror.isFactoryConstructor,
      isConst: constructorMirror.isConstConstructor,
      isPublic: !isInternal(constructorName),
      isSynthetic: isSynthetic(constructorName),
    );

    result.parameters = await extractParameters(constructorMirror.parameters, null, package, libraryUri, result);

    return result;
  }
}