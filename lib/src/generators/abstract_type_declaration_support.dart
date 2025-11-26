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

/// Support class for generating TypedefDeclaration, RecordDeclaration, TypeVariableDeclaration and TypeDeclarations.
abstract class AbstractTypeDeclarationSupport extends AbstractConstructorDeclarationSupport {
  AbstractTypeDeclarationSupport({
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

  /// Generate typedef declaration with analyzer support
  @protected
  Future<TypedefDeclaration> generateTypedef(mirrors.TypedefMirror typedefMirror, Package package, String libraryUri, Uri sourceUri) async {
    final typedefName = mirrors.MirrorSystem.getName(typedefMirror.simpleName);
    final typedefElement = await getTypedefElement(typedefName, sourceUri);
    final dartType = typedefElement?.aliasedType;

    Type runtimeType = typedefMirror.hasReflectedType ? typedefMirror.reflectedType : typedefMirror.runtimeType;

    if (GenericTypeParser.shouldCheckGeneric(runtimeType)) {
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

    if (GenericTypeParser.shouldCheckGeneric(runtimeType)) {
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
      element: null,
      dartType: null,
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
  Future<TypeDeclaration> generateType(mirrors.TypeMirror typeMirror, Package package, String libraryUri) async {
    if (typeMirror is mirrors.TypeVariableMirror) {
      return await generateTypeVariable(typeMirror, package, libraryUri);
    }

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

    final typeElement = await getTypeElement(typeName, Uri.parse(libraryUri));
    final dartType = typeElement != null ? (typeElement as InterfaceElement).thisType : null;

    if (isRecordType(runtimeType)) {
      return await generateRecordType(typeMirror, typeElement, package, libraryUri);
    }

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

    final typeArguments = <LinkDeclaration>[];
    if (typeMirror is mirrors.ClassMirror && typeMirror.typeArguments.isNotEmpty) {
      for (final arg in typeMirror.typeArguments) {
        final argLink = await generateLinkDeclarationFromMirror(arg, package, libraryUri);
        if (argLink != null) {
          typeArguments.add(argLink);
        }
      }
    }

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
    
    Type runtimeType = await findRuntimeTypeFromDartType(dartType, libraryUri, package);
    
    if (typeCache.containsKey(runtimeType)) {
      return typeCache[runtimeType]!;
    }

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

    final typeArguments = <LinkDeclaration>[];
    if (dartType is ParameterizedType && dartType.typeArguments.isNotEmpty) {
      for (final arg in dartType.typeArguments) {
        final argLink = await generateLinkDeclarationFromDartType(arg, package, libraryUri);
        if (argLink != null) {
          typeArguments.add(argLink);
        }
      }
    }

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

  /// Generate record type with analyzer support
  @protected
  Future<RecordDeclaration> generateRecordType(mirrors.TypeMirror typeMirror, Element? typeElement, Package package, String libraryUri) async {
    final recordName = typeMirror.hasReflectedType ? typeMirror.reflectedType.toString() : typeMirror.runtimeType.toString();
    final positionalFields = <RecordFieldDeclaration>[];
    final namedFields = <String, RecordFieldDeclaration>{};

    final recordContent = recordName.substring(1, recordName.length - 1);
    final parts = splitRecordContent(recordContent);
    
    int positionalIndex = 0;
    bool inNamedSection = false;

    Type runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;

    if (GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(typeMirror.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, recordName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final record = StandardRecordDeclaration(
      name: recordName,
      type: runtimeType,
      element: typeElement,
      dartType: (typeElement as InterfaceElement?)?.thisType,
      qualifiedName: buildQualifiedName(recordName, (typeMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      positionalFields: positionalFields,
      namedFields: namedFields,
      annotations: await extractAnnotations(typeMirror.metadata, package),
      sourceLocation: typeMirror.location?.sourceUri,
      isPublic: !isInternal(recordName),
      isSynthetic: isSynthetic(recordName),
    );
    
    for (var part in parts) {
      part = part.trim();
      if (part.startsWith('{')) {
        inNamedSection = true;
        part = part.substring(1);
      }
      if (part.endsWith('}')) {
        part = part.substring(0, part.length - 1);
      }
      if (part.isEmpty) continue;

      final typeAndName = part.split(' ');
      String fieldTypeName;
      String? fieldName;
      
      if (typeAndName.length > 1 && !inNamedSection) {
        fieldTypeName = typeAndName.sublist(0, typeAndName.length - 1).join(' ');
        fieldName = typeAndName.last;
      } else if (typeAndName.length > 1 && inNamedSection) {
        fieldTypeName = typeAndName.sublist(0, typeAndName.length - 1).join(' ');
        fieldName = typeAndName.last;
      } else {
        fieldTypeName = typeAndName.first;
      }

      Type? resolvedType = resolvePublicDartType('dart:core', fieldTypeName);
      
      final actualType = resolvedType ?? Object;
      final actualPackageUri = getPackageUriForType(fieldTypeName, actualType);

      final fieldType = StandardLinkDeclaration(
        name: fieldTypeName,
        type: actualType,
        pointerType: actualType,
        qualifiedName: buildQualifiedName(fieldTypeName, actualPackageUri),
        isPublic: !isInternal(fieldTypeName),
        isSynthetic: isSynthetic(fieldTypeName),
        canonicalUri: Uri.parse(actualPackageUri),
        referenceUri: Uri.parse(actualPackageUri)
      );

      if (inNamedSection) {
        final field = StandardRecordFieldDeclaration(
          name: fieldName!,
          typeDeclaration: fieldType,
          sourceLocation: typeMirror.location?.sourceUri ?? Uri.parse(libraryUri),
          type: actualType,
          libraryDeclaration: libraryCache[libraryUri]!,
          isPublic: !isInternal(fieldName),
          isSynthetic: isSynthetic(fieldName),
          isNullable: false
        );
        namedFields[fieldName] = field;
      } else {
        final name = fieldName ?? 'field_$positionalIndex';

        final field = StandardRecordFieldDeclaration(
          name: name,
          position: positionalIndex,
          typeDeclaration: fieldType,
          sourceLocation: typeMirror.location?.sourceUri ?? Uri.parse(libraryUri),
          type: actualType,
          libraryDeclaration: libraryCache[libraryUri]!,
          isPublic: !isInternal(name),
          isSynthetic: isSynthetic(name),
          isNullable: false
        );
        positionalFields.add(field);
        positionalIndex++;
      }
    }

    return record.copyWith(namedFields: namedFields, positionalFields: positionalFields);
  }
}