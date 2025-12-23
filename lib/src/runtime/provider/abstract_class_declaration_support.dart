// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../../classes.dart';
import '../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import 'abstract_enum_declaration_support.dart';

/// {@template abstract_class_declaration_support}
/// A foundational support class responsible for generating fully–analyzed
/// [`ClassDeclaration`] instances within the JetLeaf reflection pipeline.
///
/// This class bridges Dart's runtime reflection system (`dart:mirrors`) with the
/// static analysis framework provided by the Dart Analyzer. It provides the
/// logic that interprets a runtime `ClassMirror`, merges it with static type and
/// element information, resolves generics, extracts annotations, and constructs
/// a canonical [`ClassDeclaration`] that JetLeaf uses for code generation,
/// documentation extraction, and API modeling.
///
/// ### Responsibilities
/// - Integrates **runtime reflection** (via `ClassMirror`) with **static type
///   metadata** (via `ClassElement` and `InterfaceType`).
/// - Normalizes class structure into JetLeaf’s declarative format:
///   constructors, fields, methods, type arguments, inheritance hierarchy, and
///   modifier flags (abstract, base, interface, etc.).
/// - Resolves annotations from both runtime mirrors and analyzer elements,
///   including full support for JetLeaf’s generic-type resolution pipeline.
/// - Extracts and links:
///   - Superclasses
///   - Implemented interfaces
///   - Mixed-in mixins
///   - Constructor declarations
///   - Field declarations
///   - Method declarations
/// - Applies JetLeaf's IntelliCache mechanisms (`typeCache`, `libraryCache`,
///   `sourceCache`) to avoid redundant reflection or re-analysis.
/// - Detects class modifiers (`abstract`, `sealed`, `base`, `interface`,
///   `final`) using a combination of analyzer flags and source scanning.
///
/// ### When This Class Is Used
/// Every time JetLeaf needs to materialize a model of a Dart class—whether for
/// introspection, documentation export, runtime type linking, or external
/// language bindings—this class provides the core logic behind that process.
///
/// It is extended by more specific declaration support classes in the JetLeaf
/// pipeline and should not be instantiated directly.
/// {@endtemplate}
abstract class AbstractClassDeclarationSupport extends AbstractEnumDeclarationSupport {
  /// {@macro abstract_class_declaration_support}
  AbstractClassDeclarationSupport();

  @override
  ClassDeclaration generateClass(mirrors.ClassMirror classMirror, String libraryUri, Uri sourceUri, bool isBuiltIn, [bool treatFunctionAsItsOwnClass = true]) {
    if (classMirror.isEnum) {
      return generateEnum(classMirror, libraryUri, sourceUri, isBuiltIn);
    }

    if (classMirror case mirrors.FunctionTypeMirror classMirror) {
      if (treatFunctionAsItsOwnClass) {
        return generateFunctionDeclarationFromMirror(classMirror, null, libraryUri);
      }
    }

    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);

    if (isMixinClass(readSourceCode(libraryUri), className)) {
      return generateMixin(classMirror, libraryUri, sourceUri, isBuiltIn);
    }

    //
    Type type = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;

    final logMessage = "Extracting $className class with $type";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 1);
    
    final result = RuntimeBuilder.timeExecution(() {
      final analyzedClass = getAnalyzedClassDeclaration(className, sourceUri);
      // final dartType = analyzedClass?.thisType;
      final annotations = extractAnnotations(
        classMirror.metadata,
        libraryUri,
        sourceUri,
        analyzedClass?.metadata
      );
      type = resolveGenericAnnotationIfNeeded(type, classMirror, libraryUri, sourceUri, className);

      // Get source code for modifier detection
      final sourceCode = readSourceCode(sourceUri);

      // Create class declaration with full analyzer integration
      StandardClassDeclaration reflectedClass = StandardClassDeclaration(
        name: className,
        type: type,
        qualifiedName: buildQualifiedName(className, (findRealClassUriFromMirror(classMirror) ?? Uri.parse(libraryUri)).toString()),
        library: getLibrary(libraryUri),
        typeArguments: extractTypeVariableAsLinks(classMirror.typeVariables, analyzedClass?.typeParameters, libraryUri),
        annotations: annotations,
        sourceLocation: sourceUri,
        superClass: extractSupertypeAsLink(classMirror, analyzedClass?.extendsClause, libraryUri),
        interfaces: extractInterfacesAsLink(classMirror, analyzedClass?.implementsClause, libraryUri),
        mixins: extractMixinsAsLink(classMirror, analyzedClass?.withClause, libraryUri),
        isAbstract: analyzedClass?.abstractKeyword != null || classMirror.isAbstract,
        isMixin: analyzedClass?.mixinKeyword != null || isMixinClass(sourceCode, className),
        isSealed: analyzedClass?.sealedKeyword != null || isSealedClass(sourceCode, className),
        isBase: analyzedClass?.baseKeyword != null || isBaseClass(sourceCode, className),
        isInterface: analyzedClass?.interfaceKeyword != null || isInterfaceClass(sourceCode, className),
        isFinal: analyzedClass?.finalKeyword != null || isFinalClass(sourceCode, className),
        isPublic: !isInternal(className),
        isSynthetic: analyzedClass?.isSynthetic ?? isSynthetic(className),
        isRecord: false,
      );

      final constructors = <ConstructorDeclaration>[];
      final fields = <FieldDeclaration>[];
      final methods = <MethodDeclaration>[];

      // Process constructors with analyzer support
      for (final constructor in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
        if (constructor.isConstructor) {
          constructors.add(generateConstructor(constructor, analyzedClass?.members, libraryUri, sourceUri, className, reflectedClass));
        }
      }

      // Process fields with analyzer support
      for (final field in classMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
        fields.add(generateField(field, analyzedClass?.members, libraryUri, sourceUri, className, reflectedClass, sourceCode, isBuiltIn));
      }

      // Process methods with analyzer support
      for (final method in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
        if (!method.isConstructor) {
          methods.add(generateMethod(method, analyzedClass?.members, libraryUri, sourceUri, className, StandardLinkDeclaration(
            name: reflectedClass.getName(),
            type: reflectedClass.getType(),
            pointerType: reflectedClass.getType(),
            qualifiedName: reflectedClass.getQualifiedName(),
            isPublic: reflectedClass.getIsPublic(),
            canonicalUri: Uri.parse(reflectedClass.getPackageUri()),
            referenceUri: Uri.parse(reflectedClass.getPackageUri()),
            isSynthetic: reflectedClass.getIsSynthetic(),
          )));
        }
      }

      return reflectedClass.copyWith(constructors: constructors, fields: fields, methods: methods);
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 1);
    return result.result;
  }
}