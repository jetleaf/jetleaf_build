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
import 'abstract_mixin_declaration_support.dart';

/// Support class for generating EnumDeclarations.
abstract class AbstractEnumDeclarationSupport extends AbstractMixinDeclarationSupport {
  AbstractEnumDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Get enum element from analyzer
  @protected
  Future<EnumElement?> getEnumElement(String enumName, Uri sourceUri) async {
    final libraryElement = await getLibraryElement(sourceUri);
    return libraryElement?.getEnum(enumName);
  }

  /// Generate enum declaration with analyzer support
  @protected
  Future<EnumDeclaration> generateEnum(mirrors.ClassMirror enumMirror, Package package, String libraryUri, Uri sourceUri) async {
    final enumName = mirrors.MirrorSystem.getName(enumMirror.simpleName);
    final enumElement = await getEnumElement(enumName, sourceUri);
    final dartType = enumElement?.thisType;

    final values = <EnumFieldDeclaration>[];
    final members = <MemberDeclaration>[];

    Type runtimeType = enumMirror.hasReflectedType ? enumMirror.reflectedType : enumMirror.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(enumMirror.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, enumName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    StandardEnumDeclaration reflectedEnum = StandardEnumDeclaration(
      name: enumName,
      type: runtimeType,
      element: enumElement,
      dartType: dartType,
      isPublic: !isInternal(enumName),
      isSynthetic: isSynthetic(enumName),
      qualifiedName: buildQualifiedName(enumName, (enumMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      values: values,
      isNullable: false,
      typeArguments: await extractTypeArgumentsAsLinks(enumMirror.typeVariables, enumElement?.typeParameters, package, libraryUri),
      annotations: await extractAnnotations(enumMirror.metadata, package),
      sourceLocation: sourceUri,
      members: members,
    );

    // Extract enum values with safety checks
    for (final declaration in enumMirror.declarations.values) {
      if (declaration is mirrors.VariableMirror && declaration.isStatic && declaration.type.hasReflectedType && declaration.type.reflectedType == runtimeType) {
        final fieldMirror = enumMirror.getField(declaration.simpleName);
        if (fieldMirror.hasReflectee) {
          final enumFieldName = mirrors.MirrorSystem.getName(declaration.simpleName);

          values.add(StandardEnumFieldDeclaration(
            name: enumFieldName,
            type: runtimeType,
            libraryDeclaration: libraryCache[libraryUri]!,
            value: fieldMirror.reflectee,
            isPublic: !isInternal(enumFieldName),
            isSynthetic: isSynthetic(enumFieldName),
            position: enumMirror.declarations.values.toList().indexOf(declaration),
            isNullable: isNullable(fieldName: enumFieldName, sourceCode: await readSourceCode(sourceUri))
          ));
        }
      }
    }

    // Extract enum methods and fields
    for (final declaration in enumMirror.declarations.values) {
      if (declaration is mirrors.MethodMirror && !declaration.isConstructor) {
        members.add(await generateMethod(declaration, enumElement, package, libraryUri, sourceUri, enumName, null));
      } else if (declaration is mirrors.VariableMirror && !declaration.isStatic) {
        members.add(await generateField(declaration, enumElement, package, libraryUri, sourceUri, enumName, null, null));
      }
    }

    reflectedEnum = reflectedEnum.copyWith(values: values, members: members);
    
    typeCache[runtimeType] = reflectedEnum;
    return reflectedEnum;
  }

  /// Generate built-in enum declaration
  @protected
  Future<EnumDeclaration> generateBuiltInEnum(mirrors.ClassMirror enumMirror, Package package, String libraryUri, Uri sourceUri) async {
    final enumName = mirrors.MirrorSystem.getName(enumMirror.simpleName);

    final values = <EnumFieldDeclaration>[];
    final members = <MemberDeclaration>[];

    Type runtimeType = enumMirror.hasReflectedType ? enumMirror.reflectedType : enumMirror.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(enumMirror.metadata, package);
      Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, enumName);
      resolvedType ??= resolvePublicDartType(libraryUri, enumName);

      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    StandardEnumDeclaration reflectedEnum = StandardEnumDeclaration(
      name: enumName,
      type: runtimeType,
      element: null, // Built-in enums don't have analyzer elements
      dartType: null, // Built-in enums don't have analyzer DartType
      qualifiedName: buildQualifiedName(enumName, (enumMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      values: values,
      isNullable: false,
      isPublic: !isInternal(enumName),
      isSynthetic: isSynthetic(enumName),
      typeArguments: await extractTypeArgumentsAsLinks(enumMirror.typeVariables, null, package, libraryUri),
      annotations: await extractAnnotations(enumMirror.metadata, package),
      sourceLocation: sourceUri,
      members: members,
    );

    // Extract enum values with safety checks
    for (final declaration in enumMirror.declarations.values) {
      if (declaration is mirrors.VariableMirror && declaration.isStatic && declaration.type.hasReflectedType && declaration.type.reflectedType == runtimeType) {
        final fieldMirror = enumMirror.getField(declaration.simpleName);
        if (fieldMirror.hasReflectee) {
          final enumFieldName = mirrors.MirrorSystem.getName(declaration.simpleName);

          values.add(StandardEnumFieldDeclaration(
            name: enumFieldName,
            type: runtimeType,
            libraryDeclaration: libraryCache[libraryUri]!,
            annotations: await extractAnnotations(declaration.metadata, package),
            value: fieldMirror.reflectee,
            isPublic: !isInternal(enumFieldName),
            isSynthetic: isSynthetic(enumFieldName),
            position: enumMirror.declarations.values.toList().indexOf(declaration),
            isNullable: isNullable(fieldName: enumFieldName, sourceCode: await readSourceCode(sourceUri))
          ));
        }
      }
    }

    // Extract enum methods and fields
    for (final declaration in enumMirror.declarations.values) {
      if (declaration is mirrors.MethodMirror && !declaration.isConstructor) {
        members.add(await generateBuiltInMethod(declaration, package, libraryUri, sourceUri, enumName, null));
      } else if (declaration is mirrors.VariableMirror && !declaration.isStatic) {
        members.add(await generateBuiltInField(declaration, package, libraryUri, sourceUri, enumName, null));
      }
    }

    reflectedEnum = reflectedEnum.copyWith(values: values, members: members);
    
    typeCache[runtimeType] = reflectedEnum;
    return reflectedEnum;
  }
}