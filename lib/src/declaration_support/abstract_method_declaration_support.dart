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
import 'abstract_field_declaration_support.dart';

/// Support class for generating MethodDeclarations.
abstract class AbstractMethodDeclarationSupport extends AbstractFieldDeclarationSupport {
  AbstractMethodDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Extract parameters with analyzer support
  @protected
  Future<List<ParameterDeclaration>> extractParameters(List<mirrors.ParameterMirror> mirrorParams, List<TypeParameterElement>? analyzerParams, Package package, String libraryUri, MemberDeclaration parentMember) async {
    final parameters = <ParameterDeclaration>[];
    
    for (int i = 0; i < mirrorParams.length; i++) {
      final mirrorParam = mirrorParams[i];
      final analyzerParam = (analyzerParams != null && i < analyzerParams.length)
          ? analyzerParams[i]
          : null;
      
      final paramName = mirrors.MirrorSystem.getName(mirrorParam.simpleName);
      final dartType = analyzerParam?.bound;
      final paramType = await getLinkDeclaration(mirrorParam.type, package, libraryUri, dartType);
      
      // Safe access to default value
      dynamic defaultValue;
      if (mirrorParam.hasDefaultValue && mirrorParam.defaultValue != null && mirrorParam.defaultValue!.hasReflectee) {
        defaultValue = mirrorParam.defaultValue!.reflectee;
      }

      final mirrorType = mirrorParam.type;
      Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

      // Extract annotations and resolve type
      if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
        final annotations = await extractAnnotations(mirrorType.metadata, package);
        final resolvedType = await resolveTypeFromGenericAnnotation(annotations, paramName);
        if (resolvedType != null) {
          runtimeType = resolvedType;
        }
      }
      final annotations = await extractAnnotations(mirrorParam.metadata, package);
      
      parameters.add(StandardParameterDeclaration(
        name: paramName,
        element: analyzerParam,
        dartType: dartType,
        type: runtimeType,
        libraryDeclaration: libraryCache[libraryUri]!,
        typeDeclaration: paramType,
        isOptional: mirrorParam.isOptional,
        isNamed: mirrorParam.isNamed,
        hasDefaultValue: mirrorParam.hasDefaultValue,
        defaultValue: defaultValue,
        index: i,
        memberDeclaration: parentMember,
        isPublic: !isInternal(paramName),
        isSynthetic: isSynthetic(paramName),
        sourceLocation: Uri.parse(libraryUri),
        annotations: annotations,
      ));
    }
    
    return parameters;
  }

  /// Generate method declaration with analyzer support
  @protected
  Future<MethodDeclaration> generateMethod(mirrors.MethodMirror methodMirror, Element? parentElement, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);
    
    // Get appropriate analyzer element
    Element? methodElement;
    if (parentElement is InterfaceElement) {
      if (methodMirror.isGetter) {
        methodElement = parentElement.getGetter(methodName);
      } else if (methodMirror.isSetter) {
        methodElement = parentElement.getSetter(methodName);
      } else {
        methodElement = parentElement.getMethod(methodName);
      }
    }

    final dartType = (methodElement as ExecutableElement?)?.type;
    final mirrorType = methodMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, methodName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardMethodDeclaration(
      name: methodName,
      element: methodElement,
      dartType: dartType,
      type: runtimeType,
      libraryDeclaration: libraryCache[libraryUri]!,
      returnType: await getLinkDeclaration(methodMirror.returnType, package, libraryUri, dartType),
      annotations: await extractAnnotations(methodMirror.metadata, package),
      isPublic: !isInternal(methodName),
      isSynthetic: isSynthetic(methodName),
      sourceLocation: sourceUri,
      isStatic: methodMirror.isStatic,
      isAbstract: methodMirror.isAbstract,
      isGetter: methodMirror.isGetter,
      isSetter: methodMirror.isSetter,
      parentClass: parentClass != null ? StandardLinkDeclaration(
        name: parentClass.getName(),
        type: parentClass.getType(),
        pointerType: parentClass.getType(),
        qualifiedName: parentClass.getQualifiedName(),
        isPublic: parentClass.getIsPublic(),
        canonicalUri: Uri.parse(parentClass.getPackageUri()),
        referenceUri: Uri.parse(parentClass.getPackageUri()),
        isSynthetic: parentClass.getIsSynthetic(),
      ) : null,
      isFactory: methodMirror.isFactoryConstructor,
      isConst: methodMirror.isConstConstructor,
    );

    result.parameters = await extractParameters(methodMirror.parameters, methodElement?.typeParameters, package, libraryUri, result);

    return result;
  }

  /// Generate built-in method
  @protected
  Future<MethodDeclaration> generateBuiltInMethod(mirrors.MethodMirror methodMirror, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);

    final mirrorType = methodMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, methodName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardMethodDeclaration(
      name: methodName,
      element: null, // Built-in methods don't have analyzer elements
      dartType: null, // Built-in methods don't have analyzer DartType
      type: runtimeType,
      libraryDeclaration: libraryCache[libraryUri]!,
      returnType: await getLinkDeclaration(methodMirror.returnType, package, libraryUri),
      annotations: await extractAnnotations(methodMirror.metadata, package),
      sourceLocation: sourceUri,
      isStatic: methodMirror.isStatic,
      isAbstract: methodMirror.isAbstract,
      isGetter: methodMirror.isGetter,
      isSetter: methodMirror.isSetter,
      parentClass: parentClass != null ? StandardLinkDeclaration(
        name: parentClass.getName(),
        type: parentClass.getType(),
        pointerType: parentClass.getType(),
        qualifiedName: parentClass.getQualifiedName(),
        isPublic: parentClass.getIsPublic(),
        canonicalUri: Uri.parse(parentClass.getPackageUri()),
        referenceUri: Uri.parse(parentClass.getPackageUri()),
        isSynthetic: parentClass.getIsSynthetic(),
      ) : null,
      isFactory: methodMirror.isFactoryConstructor,
      isConst: methodMirror.isConstConstructor,
      isPublic: !isInternal(methodName),
      isSynthetic: isSynthetic(methodName),
    );

    result.parameters = await extractParameters(methodMirror.parameters, null, package, libraryUri, result);

    return result;
  }

  /// Generate built-in top-level method
  @protected
  Future<MethodDeclaration> generateBuiltInTopLevelMethod(mirrors.MethodMirror methodMirror, Package package, String libraryUri, Uri sourceUri) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);

    final mirrorType = methodMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, methodName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardMethodDeclaration(
      name: methodName,
      element: null, // Built-in methods don't have analyzer elements
      dartType: null, // Built-in methods don't have analyzer DartType
      type: runtimeType,
      libraryDeclaration: libraryCache[libraryUri]!,
      returnType: await getLinkDeclaration(methodMirror.returnType, package, libraryUri),
      annotations: await extractAnnotations(methodMirror.metadata, package),
      sourceLocation: sourceUri,
      isStatic: true,
      isAbstract: false,
      isPublic: !isInternal(methodName),
      isSynthetic: isSynthetic(methodName),
      isGetter: methodMirror.isGetter,
      isSetter: methodMirror.isSetter,
      isFactory: false,
      isConst: false,
    );

    result.parameters = await extractParameters(methodMirror.parameters, null, package, libraryUri, result);

    return result;
  }

  /// Generate top-level method with analyzer support
  @protected
  Future<MethodDeclaration> generateTopLevelMethod(mirrors.MethodMirror methodMirror, Package package, String libraryUri, Uri sourceUri) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);
    
    final libraryElement = await getLibraryElement(Uri.parse(libraryUri));
    
    // Get top-level function element
    ExecutableElement? functionElement;
    if (libraryElement != null) {
      functionElement = libraryElement.topLevelFunctions.where((f) => f.name == methodName).firstOrNull;
    }

    final dartType = functionElement?.type;
    final mirrorType = methodMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, methodName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardMethodDeclaration(
      name: methodName,
      element: functionElement,
      dartType: dartType,
      type: runtimeType,
      libraryDeclaration: libraryCache[libraryUri]!,
      returnType: await getLinkDeclaration(methodMirror.returnType, package, libraryUri, dartType),
      annotations: await extractAnnotations(methodMirror.metadata, package),
      sourceLocation: sourceUri,
      isStatic: true,
      isAbstract: false,
      isGetter: methodMirror.isGetter,
      isSetter: methodMirror.isSetter,
      isFactory: false,
      isPublic: !isInternal(methodName),
      isSynthetic: isSynthetic(methodName),
      isConst: false,
    );

    result.parameters = await extractParameters(methodMirror.parameters, functionElement?.typeParameters, package, libraryUri, result);

    return result;
  }
}