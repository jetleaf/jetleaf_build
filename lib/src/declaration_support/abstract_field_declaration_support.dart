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
import 'abstract_annotation_declaration_support.dart';

/// Support class for generating FieldDeclarations.
abstract class AbstractFieldDeclarationSupport extends AbstractAnnotationDeclarationSupport {
  AbstractFieldDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Generate field declaration with analyzer support
  @protected
  Future<FieldDeclaration> generateField(mirrors.VariableMirror fieldMirror, Element? parentElement, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass, String? sourceCode) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    
    // Get analyzer field element
    FieldElement? fieldElement;
    if (parentElement is InterfaceElement) {
      fieldElement = parentElement.getField(fieldName);
    }

    final dartType = fieldElement?.type;
    final mirrorType = fieldMirror.type;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, fieldName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    return StandardFieldDeclaration(
      name: fieldName,
      type: runtimeType,
      element: fieldElement,
      dartType: dartType,
      libraryDeclaration: libraryCache[libraryUri]!,
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
      linkDeclaration: await getLinkDeclaration(fieldMirror.type, package, libraryUri, dartType),
      annotations: await extractAnnotations(fieldMirror.metadata, package),
      sourceLocation: sourceUri,
      isFinal: fieldMirror.isFinal,
      isConst: fieldMirror.isConst,
      isLate: isLateField(sourceCode, fieldName),
      isStatic: fieldMirror.isStatic,
      isAbstract: false,
      isPublic: !isInternal(fieldName),
      isSynthetic: isSynthetic(fieldName),
      isNullable: isNullable(
        fieldName: fieldName, 
        sourceCode: sourceCode ?? await readSourceCode(sourceUri),
        fieldElement: fieldElement
      )
    );
  }

  /// Generate built-in field
  @protected
  Future<FieldDeclaration> generateBuiltInField(mirrors.VariableMirror fieldMirror, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);

    final mirrorType = fieldMirror.type;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, fieldName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    return StandardFieldDeclaration(
      name: fieldName,
      type: runtimeType,
      element: null, // Built-in fields don't have analyzer elements
      dartType: null, // Built-in fields don't have analyzer DartType
      libraryDeclaration: libraryCache[libraryUri]!,
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
      linkDeclaration: await getLinkDeclaration(fieldMirror.type, package, libraryUri),
      annotations: await extractAnnotations(fieldMirror.metadata, package),
      sourceLocation: sourceUri,
      isFinal: fieldMirror.isFinal,
      isConst: fieldMirror.isConst,
      isLate: false,
      isStatic: fieldMirror.isStatic,
      isAbstract: false,
      isPublic: !isInternal(fieldName),
      isSynthetic: isSynthetic(fieldName),
      isNullable: isNullable(fieldName: fieldName, sourceCode: await readSourceCode(sourceUri))
    );
  }

  /// Generate built-in top-level field
  @protected
  Future<FieldDeclaration> generateBuiltInTopLevelField(mirrors.VariableMirror fieldMirror, Package package, String libraryUri, Uri sourceUri) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);

    final mirrorType = fieldMirror.type;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, fieldName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    return StandardFieldDeclaration(
      name: fieldName,
      type: runtimeType,
      element: null, // Built-in fields don't have analyzer elements
      dartType: null, // Built-in fields don't have analyzer DartType
      libraryDeclaration: libraryCache[libraryUri]!,
      parentClass: null,
      linkDeclaration: await getLinkDeclaration(fieldMirror.type, package, libraryUri),
      annotations: await extractAnnotations(fieldMirror.metadata, package),
      sourceLocation: sourceUri,
      isFinal: fieldMirror.isFinal,
      isConst: fieldMirror.isConst,
      isLate: false,
      isStatic: true,
      isAbstract: false,
      isPublic: !isInternal(fieldName),
      isSynthetic: isSynthetic(fieldName),
      isNullable: isNullable(fieldName: fieldName, sourceCode: await readSourceCode(sourceUri))
    );
  }

  /// Generate top-level field with analyzer support
  @protected
  Future<FieldDeclaration> generateTopLevelField(mirrors.VariableMirror fieldMirror, Package package, String libraryUri, Uri sourceUri) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    final libraryElement = await getLibraryElement(Uri.parse(libraryUri));
    
    // Get top-level variable element
    TopLevelVariableElement? variableElement;
    if (libraryElement != null) {
      variableElement = libraryElement.topLevelVariables.where((v) => v.name == fieldName).firstOrNull;
    }

    final dartType = variableElement?.type;
    final mirrorType = fieldMirror.type;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, fieldName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final sourceCode = await readSourceCode(sourceUri);

    return StandardFieldDeclaration(
      name: fieldName,
      type: runtimeType,
      element: variableElement,
      dartType: dartType,
      libraryDeclaration: libraryCache[libraryUri]!,
      parentClass: null,
      linkDeclaration: await getLinkDeclaration(fieldMirror.type, package, libraryUri, dartType),
      annotations: await extractAnnotations(fieldMirror.metadata, package),
      sourceLocation: sourceUri,
      isFinal: fieldMirror.isFinal,
      isConst: fieldMirror.isConst,
      isLate: false,
      isStatic: true,
      isAbstract: false,
      isPublic: !isInternal(fieldName),
      isSynthetic: isSynthetic(fieldName),
      isNullable: isNullable(fieldName: fieldName, sourceCode: sourceCode)
    );
  }
}