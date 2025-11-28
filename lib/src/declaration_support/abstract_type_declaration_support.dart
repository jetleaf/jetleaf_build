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
import 'abstract_record_declaration_support.dart';

/// Support class for generating TypeVariableDeclaration and TypeDeclarations.
abstract class AbstractTypeDeclarationSupport extends AbstractRecordDeclarationSupport {
  AbstractTypeDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Get type element from analyzer
  @protected
  Future<Element?> getTypeElement(String typeName, Uri sourceUri) async {
    final libraryElement = await getLibraryElement(sourceUri);
    if (libraryElement == null) return null;

    return libraryElement.getClass(typeName) ??
           libraryElement.getMixin(typeName) ??
           libraryElement.getEnum(typeName) ??
           libraryElement.getTypeAlias(typeName);
  }

  @override
  Future<TypeDeclaration> generateType(mirrors.TypeMirror typeMirror, Package package, String libraryUri) async {
    // Handle type variables
    if (typeMirror is mirrors.TypeVariableMirror) {
      return await generateTypeVariable(typeMirror, package, libraryUri);
    }

    // Handle dynamic and void
    if (typeMirror.runtimeType.toString() == 'dynamic') {
      return StandardTypeDeclaration(
        name: 'dynamic',
        type: dynamic,
        element: null,
        dartType: null,
        qualifiedName: buildQualifiedName('dynamic', 'dart:core'),
        simpleName: 'dynamic',
        packageUri: 'dart:core',
        isNullable: false,
        kind: TypeKind.dynamicType,
        isPublic: true,
        isSynthetic: false,
      );
    }

    if (typeMirror.runtimeType.toString() == 'void') {
      return StandardTypeDeclaration(
        name: 'void',
        type: VoidType,
        element: null,
        dartType: null,
        qualifiedName: buildQualifiedName('void', 'dart:core'),
        simpleName: 'void',
        packageUri: 'dart:core',
        isNullable: false,
        kind: TypeKind.voidType,
        isPublic: true,
        isSynthetic: false,
      );
    }

    Type runtimeType;
    try {
      runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;
    } catch (e) {
      runtimeType = typeMirror.runtimeType;
    }

    if (typeCache.containsKey(runtimeType)) {
      return typeCache[runtimeType]!;
    }

    final typeName = mirrors.MirrorSystem.getName(typeMirror.simpleName);

    // Get analyzer element for the type
    final typeElement = await getTypeElement(typeName, Uri.parse(libraryUri));
    final dartType = typeElement != null ? (typeElement as InterfaceElement).thisType : null;

    if (isRecordType(runtimeType)) {
      return await generateRecordType(typeMirror, typeElement, package, libraryUri);
    }

    // Handle primitive types
    if (isPrimitiveType(runtimeType)) {
      return StandardTypeDeclaration(
        name: typeName,
        type: runtimeType,
        element: typeElement,
        dartType: dartType,
        qualifiedName: buildQualifiedName(typeName, 'dart:core'),
        simpleName: typeName,
        packageUri: 'dart:core',
        isNullable: false,
        kind: TypeKind.primitiveType,
        isPublic: !isInternal(typeName),
        isSynthetic: isSynthetic(typeName),
      );
    }

    // Extract type arguments with analyzer support - now as LinkDeclarations
    final typeArguments = <LinkDeclaration>[];
    if (typeMirror is mirrors.ClassMirror && typeMirror.typeArguments.isNotEmpty) {
      for (final arg in typeMirror.typeArguments) {
        final argLink = await generateLinkDeclarationFromMirror(arg, package, libraryUri);
        if (argLink != null) {
          typeArguments.add(argLink);
        }
      }
    }

    // Determine type kind
    final kind = determineTypeKind(typeMirror, dartType);

    final declaration = StandardTypeDeclaration(
      name: typeName,
      type: runtimeType,
      element: typeElement,
      dartType: dartType,
      qualifiedName: buildQualifiedName(typeName, libraryUri),
      simpleName: typeName,
      packageUri: libraryUri,
      isNullable: false,
      kind: kind,
      typeArguments: typeArguments,
      isPublic: !isInternal(typeName),
      isSynthetic: isSynthetic(typeName),
    );

    typeCache[runtimeType] = declaration;
    return declaration;
  }

  /// Generate type variable with analyzer support
  @protected
  Future<TypeVariableDeclaration> generateTypeVariable(mirrors.TypeVariableMirror typeVarMirror, Package package, String libraryUri, {TypeParameterElement? analyzerElement}) async {
    final typeName = mirrors.MirrorSystem.getName(typeVarMirror.simpleName);
    final cacheKey = '${typeName}_${typeVarMirror.hashCode}';
    
    if (typeVariableCache.containsKey(cacheKey)) {
      return typeVariableCache[cacheKey]!;
    }

    // Get upper bound with analyzer support
    TypeDeclaration? upperBound;
    if (analyzerElement?.bound != null) {
      upperBound = await generateTypeFromDartType(analyzerElement!.bound!, package, libraryUri);
    } else if (typeVarMirror.upperBound != typeVarMirror.owner?.owner && typeVarMirror.upperBound.runtimeType.toString() != 'dynamic') {
      upperBound = await generateType(typeVarMirror.upperBound, package, libraryUri);
    }

    final typeVariable = StandardTypeVariableDeclaration(
      name: typeName,
      type: Object,
      element: analyzerElement,
      dartType: null,
      qualifiedName: buildQualifiedName(typeName, (typeVarMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      isNullable: false,
      upperBound: upperBound,
      isPublic: !isInternal(typeName),
      isSynthetic: isSynthetic(typeName),
      parentLibrary: libraryCache[libraryUri]!,
      sourceLocation: typeVarMirror.location?.sourceUri,
      variance: getVariance(analyzerElement),
    );

    typeVariableCache[cacheKey] = typeVariable;
    return typeVariable;
  }

  /// Generate type from analyzer DartType
  @protected
  Future<TypeDeclaration> generateTypeFromDartType(DartType dartType, Package package, String libraryUri) async {
    final typeName = dartType.getDisplayString();
    
    // Try to find the actual runtime type from mirrors first
    Type runtimeType = await findRuntimeTypeFromDartType(dartType, libraryUri, package);
    
    // Check cache first
    if (typeCache.containsKey(runtimeType)) {
      return typeCache[runtimeType]!;
    }

    // Handle different DartType kinds
    if (dartType is DynamicType) {
      return StandardTypeDeclaration(
        name: 'dynamic',
        type: dynamic,
        element: dartType.element,
        dartType: dartType,
        qualifiedName: buildQualifiedName('dynamic', 'dart:core'),
        simpleName: 'dynamic',
        packageUri: 'dart:core',
        isNullable: dartType.nullabilitySuffix == NullabilitySuffix.question,
        kind: TypeKind.dynamicType,
        isPublic: true,
        isSynthetic: false,
      );
    }

    if (dartType is VoidType) {
      return StandardTypeDeclaration(
        name: 'void',
        type: VoidType,
        element: dartType.element,
        dartType: dartType,
        qualifiedName: buildQualifiedName('void', 'dart:core'),
        simpleName: 'void',
        packageUri: 'dart:core',
        isNullable: false,
        kind: TypeKind.voidType,
        isPublic: true,
        isSynthetic: false,
      );
    }

    // Handle parameterized types - now using LinkDeclarations
    final typeArguments = <LinkDeclaration>[];
    if (dartType is ParameterizedType && dartType.typeArguments.isNotEmpty) {
      for (final arg in dartType.typeArguments) {
        final argLink = await generateLinkDeclarationFromDartType(arg, package, libraryUri);
        if (argLink != null) {
          typeArguments.add(argLink);
        }
      }
    }

    // Determine type kind from element
    TypeKind kind = TypeKind.unknownType;
    if (dartType.element is ClassElement) {
      final classElement = dartType.element as ClassElement;
      if (classElement.isDartCoreEnum) {
        kind = TypeKind.enumType;
      } else {
        kind = TypeKind.classType;
      }
    } else if (dartType.element is MixinElement) {
      kind = TypeKind.mixinType;
    } else if (dartType.element is TypeAliasElement) {
      kind = TypeKind.typedefType;
    } else if (dartType.element is EnumElement) {
      kind = TypeKind.enumType;
    }

    final declaration = StandardTypeDeclaration(
      name: dartType.element?.name ?? typeName,
      type: runtimeType,
      element: dartType.element,
      dartType: dartType,
      qualifiedName: buildQualifiedNameFromElement(dartType.element),
      simpleName: dartType.element?.name ?? typeName,
      packageUri: dartType.element?.library?.uri.toString() ?? libraryUri,
      isNullable: dartType.nullabilitySuffix == NullabilitySuffix.question,
      kind: kind,
      typeArguments: typeArguments,
      isPublic: !isInternal(dartType.element?.name ?? typeName),
      isSynthetic: isSynthetic(dartType.element?.name ?? typeName),
    );

    typeCache[runtimeType] = declaration;
    return declaration;
  }
}