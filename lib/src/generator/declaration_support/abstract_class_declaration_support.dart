// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../../declaration/declaration.dart';
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
  AbstractClassDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  /// Generates a JetLeaf [`ClassDeclaration`] by combining mirrors-based
  /// reflection, static analyzer metadata, source parsing, and JetLeaf’s
  /// declaration synthesis rules.
  ///
  /// This method is the primary workhorse for class modeling: it takes a
  /// runtime [`ClassMirror`] and a linked analyzer [`ClassElement`] (when
  /// available), merges their information, and produces a complete normalized
  /// representation suitable for further processing throughout the JetLeaf
  /// pipeline.
  ///
  /// ### What This Method Resolves
  ///
  /// **1. Type Metadata**
  /// - Determines the runtime type (reflected or inferred).
  /// - Applies JetLeaf's generic-type resolution (`@Generic(...)`).
  /// - Extracts analyzer type metadata (`InterfaceType`).
  ///
  /// **2. Class Annotations**
  /// - Merges mirror metadata with static analyzer metadata.
  /// - Expands annotations into canonical JetLeaf annotation declarations.
  ///
  /// **3. Inheritance Structure**
  /// Uses JetLeaf’s link-resolution helpers to map:
  /// - `extends` → `superClass`
  /// - `implements` → `interfaces`
  /// - `with` → `mixins`
  ///
  /// All members are returned as `LinkDeclaration` objects ensuring stability
  /// across mirrors, analyzer types, and different compilation environments.
  ///
  /// **4. Member Extraction**
  /// The method iterates over the mirror's declarations:
  /// - Constructors → via [`generateConstructor`]
  /// - Fields → via [`generateField`]
  /// - Methods → via [`generateMethod`]
  ///
  /// Each member is resolved using both reflection and analyzer metadata where
  /// possible, guaranteeing accurate type information, nullability, synthetic
  /// status, and access modifiers.
  ///
  /// **5. Class Modifiers**
  /// Uses analyzer metadata when present, but falls back to JetLeaf’s
  /// source-parsing utilities for environments where reflection does not expose
  /// modifier flags:
  /// - `abstract`
  /// - `base`
  /// - `interface`
  /// - `sealed`
  /// - `final`
  /// - `mixin class` detection
  ///
  /// **6. Synthetic & Public Flags**
  /// Determined through analyzer API when available, otherwise inferred via
  /// JetLeaf's naming conventions (`_internal` / leading underscores).
  ///
  /// ### Parameters
  /// - **[classMirror]**  
  ///   The runtime reflection descriptor for the class.
  ///
  /// - **[package]**  
  ///   The JetLeaf package context used to resolve declarations and imports.
  ///
  /// - **[libraryUri]**  
  ///   The canonical URI of the parent library in string form.
  ///
  /// - **[sourceUri]**  
  ///   The URI of the original source file, used for source-based modifier
  ///   detection and accurate error reporting.
  ///
  /// - **[isBuiltIn]**  
  ///   Signals whether the class originates from SDK/Built-in libraries,
  ///   affecting how members are extracted and how synthetic status is
  ///   determined.
  ///
  /// ### Returns
  /// A fully synthesized, analyzer-integrated [`ClassDeclaration`] containing:
  /// - Full inheritance graph
  /// - Constructors
  /// - Fields
  /// - Methods
  /// - Annotations
  /// - Type arguments
  /// - Modifier flags
  /// - Source location metadata
  ///
  /// ### Notes
  /// - This method updates the global [`typeCache`] so future lookups for the
  ///   same type reuse the declaration instead of re-reflecting.
  /// - Any missing analyzer information is gracefully handled; JetLeaf
  ///   prioritizes analyzer metadata but falls back to mirrors and source
  ///   parsing.
  /// - This method does **not** process record types embedded in classes; record
  ///   extraction is delegated elsewhere in the pipeline.
  @protected
  Future<ClassDeclaration> generateClass(mirrors.ClassMirror classMirror, Package package, String libraryUri, Uri sourceUri, bool isBuiltIn) async {
    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);
    Type type = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;

    final logMessage = "Extracting $className class with $type";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 1);
    
    final result = await RuntimeBuilder.timeExecution(() async {
      final analyzedClass = await getAnalyzedClassDeclaration(className, sourceUri);
      // final dartType = analyzedClass?.thisType;
      final annotations = await extractAnnotations(
        classMirror.metadata,
        libraryUri,
        sourceUri,
        package,
        analyzedClass?.metadata
      );
      type = await resolveGenericAnnotationIfNeeded(type, classMirror, package, libraryUri, sourceUri, className);

      // Get source code for modifier detection
      final sourceCode = await readSourceCode(sourceUri);

      // Create class declaration with full analyzer integration
      StandardClassDeclaration reflectedClass = StandardClassDeclaration(
        name: className,
        type: type,
        qualifiedName: buildQualifiedName(className, (classMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
        parentLibrary: await getLibrary(libraryUri),
        isNullable: false,
        typeArguments: await extractTypeVariableAsLinks(classMirror.typeVariables, analyzedClass?.typeParameters, package, libraryUri),
        annotations: annotations,
        sourceLocation: sourceUri,
        superClass: await extractSupertypeAsLink(classMirror, analyzedClass?.extendsClause, package, libraryUri),
        interfaces: await extractInterfacesAsLink(classMirror, analyzedClass?.implementsClause, package, libraryUri),
        mixins: await extractMixinsAsLink(classMirror, analyzedClass?.withClause, package, libraryUri),
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
          constructors.add(await generateConstructor(constructor, analyzedClass?.members, package, libraryUri, sourceUri, className, reflectedClass));
        }
      }

      // Process fields with analyzer support
      for (final field in classMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
        fields.add(await generateField(field, analyzedClass?.members, package, libraryUri, sourceUri, className, reflectedClass, sourceCode, isBuiltIn));
      }

      // Process methods with analyzer support
      for (final method in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
        if (!method.isConstructor) {
          methods.add(await generateMethod(method, analyzedClass?.members, package, libraryUri, sourceUri, className, reflectedClass));
        }
      }

      return reflectedClass.copyWith(constructors: constructors, fields: fields, methods: methods);
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 1);
    return result.result;
  }
}