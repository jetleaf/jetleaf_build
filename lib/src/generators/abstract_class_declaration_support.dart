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
import 'abstract_enum_declaration_support.dart';

/// Support class for generating ClassDeclarations.
abstract class AbstractClassDeclarationSupport extends AbstractEnumDeclarationSupport {
  AbstractClassDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Get class element from analyzer
  @protected
  Future<ClassElement?> getClassElement(String className, Uri sourceUri) async {
    final libraryElement = await getLibraryElement(sourceUri);
    return libraryElement?.getClass(className);
  }

  /// Generate class declaration with analyzer support
  @protected
  Future<ClassDeclaration> generateClass(
    mirrors.ClassMirror classMirror, 
    Package package, 
    String libraryUri, 
    Uri sourceUri
  ) async {
    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);
    
    Type runtimeType = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;

    final classElement = await getClassElement(className, sourceUri);
    final dartType = classElement?.thisType;

    final annotations = await extractAnnotations(classMirror.metadata, package);

    if (GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, className);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final constructors = <ConstructorDeclaration>[];
    final fields = <FieldDeclaration>[];
    final methods = <MethodDeclaration>[];
    final records = <RecordDeclaration>[];

    String? sourceCode = sourceCache[sourceUri.toString()];

    final supertype = await extractSupertypeAsLink(classMirror, classElement, package, libraryUri);
    final interfaces = await extractInterfacesAsLink(classMirror, classElement, package, libraryUri);
    final mixins = await extractMixinsAsLink(classMirror, classElement, package, libraryUri);

    StandardClassDeclaration reflectedClass = StandardClassDeclaration(
      name: className,
      type: runtimeType,
      element: classElement,
      dartType: dartType,
      qualifiedName: buildQualifiedName(className, (classMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      isNullable: false,
      typeArguments: await extractTypeArgumentsAsLinks(classMirror.typeVariables, classElement?.typeParameters, package, libraryUri),
      annotations: annotations,
      sourceLocation: sourceUri,
      superClass: supertype,
      interfaces: interfaces,
      mixins: mixins,
      isAbstract: classMirror.isAbstract,
      isMixin: isMixinClass(sourceCode, className),
      isSealed: isSealedClass(sourceCode, className),
      isBase: isBaseClass(sourceCode, className),
      isInterface: isInterfaceClass(sourceCode, className),
      isFinal: isFinalClass(sourceCode, className),
      isPublic: !isInternal(className),
      isSynthetic: isSynthetic(className),
      isRecord: false,
    );

    typeCache[runtimeType] = reflectedClass;

    // Process constructors with analyzer support
    for (final constructor in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (constructor.isConstructor) {
        constructors.add(await generateConstructor(constructor, classElement, package, libraryUri, sourceUri, className, reflectedClass));
      }
    }

    // Process fields with analyzer support
    for (final field in classMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
      fields.add(await generateField(field, classElement, package, libraryUri, sourceUri, className, reflectedClass, sourceCode));
    }

    // Process methods with analyzer support
    for (final method in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (!method.isConstructor && !method.isAbstract) {
        methods.add(await generateMethod(method, classElement, package, libraryUri, sourceUri, className, reflectedClass));
      }
    }

    return reflectedClass.copyWith(constructors: constructors, fields: fields, methods: methods, records: records);
  }

  /// Generate built-in class declaration
  @protected
  Future<ClassDeclaration> generateBuiltInClass(
    mirrors.ClassMirror classMirror, 
    Package package, 
    String libraryUri, 
    Uri sourceUri
  ) async {
    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);
    
    Type runtimeType = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;

    final annotations = await extractAnnotations(classMirror.metadata, package);

    if (GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, className);
      resolvedType ??= resolvePublicDartType(libraryUri, className);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final constructors = <ConstructorDeclaration>[];
    final fields = <FieldDeclaration>[];
    final methods = <MethodDeclaration>[];
    final records = <RecordDeclaration>[];

    final supertype = await extractSupertypeAsLink(classMirror, null, package, libraryUri);
    final interfaces = await extractInterfacesAsLink(classMirror, null, package, libraryUri);
    final mixins = await extractMixinsAsLink(classMirror, null, package, libraryUri);
    final sourceCode = await readSourceCode(classMirror.location?.sourceUri ?? Uri.parse(libraryUri));

    StandardClassDeclaration reflectedClass = StandardClassDeclaration(
      name: className,
      type: runtimeType,
      element: null,
      dartType: null,
      qualifiedName: buildQualifiedName(className, (classMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      isNullable: false,
      typeArguments: await extractTypeArgumentsAsLinks(classMirror.typeVariables, null, package, libraryUri),
      annotations: annotations,
      sourceLocation: sourceUri,
      superClass: supertype,
      interfaces: interfaces,
      mixins: mixins,
      isPublic: !isInternal(className),
      isSynthetic: isSynthetic(className),
      isAbstract: classMirror.isAbstract,
      isMixin: isMixinClass(sourceCode, className),
      isSealed: isSealedClass(sourceCode, className),
      isBase: isBaseClass(sourceCode, className),
      isInterface: isInterfaceClass(sourceCode, className),
      isFinal: isFinalClass(sourceCode, className),
      isRecord: false,
    );

    typeCache[runtimeType] = reflectedClass;

    // Process constructors
    for (final constructor in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (constructor.isConstructor) {
        constructors.add(await generateBuiltInConstructor(constructor, package, libraryUri, sourceUri, className, reflectedClass));
      }
    }

    // Process fields
    for (final field in classMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
      fields.add(await generateBuiltInField(field, package, libraryUri, sourceUri, className, reflectedClass));
    }

    // Process methods
    for (final method in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (!method.isConstructor && !method.isAbstract) {
        methods.add(await generateBuiltInMethod(method, package, libraryUri, sourceUri, className, reflectedClass));
      }
    }

    return reflectedClass.copyWith(constructors: constructors, fields: fields, methods: methods, records: records);
  }
}