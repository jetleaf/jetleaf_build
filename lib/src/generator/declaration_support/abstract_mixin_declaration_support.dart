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
import 'abstract_typedef_declaration_support.dart';

/// {@template abstract_mixin_declaration_support}
/// Support class for generating [MixinDeclaration] instances within the JetLeaf
/// reflection and static-analysis pipeline.
///
/// This abstract class extends [AbstractTypedefDeclarationSupport] to provide a
/// unified mechanism for interpreting Dart mixins from both the runtime mirror
/// system and the static analyzer. It acts as the central mixin-declaration
/// generator used by higher-level JetLeaf components that need fully resolved
/// metadata for mixin structures, generic type parameters, annotations,
/// constraints, interfaces, and members.
///
///
/// ## Purpose
/// `AbstractMixinDeclarationSupport` translates a runtime [ClassMirror] that
/// represents a Dart mixin into a complete [MixinDeclaration], combining:
///
/// - **Runtime reflection (dart:mirrors)** — to inspect fields, methods, type
///   variables, constraints, modifiers, and source locations.
/// - **Static analysis (package:analyzer)** — to attach precise type metadata,
///   nullability information, type parameter elements, declared interfaces,
///   constraints, and canonical library URIs.
/// - **JetLeaf declaration models** — to produce immutable, canonical IR objects
///   (e.g., [StandardMixinDeclaration], [FieldDeclaration], [MethodDeclaration],
///   [LinkDeclaration]) used throughout code generation and documentation
///   systems.
///
///
/// ## Responsibilities
/// This class:
///
/// - Locates the analyzer [ClassElement] for the mixin using the fully resolved
///   URI and name.
/// - Merges analyzer metadata (e.g., variance, type parameters, interface
///   elements) with mirror metadata (e.g., reflected type, declarations).
/// - Resolves annotations from both the mirror system and analyzer element
///   metadata.
/// - Resolves all mixin constraints and implemented interfaces as JetLeaf
///   [LinkDeclaration] objects.
/// - Generates declarations for all fields and methods, applying JetLeaf’s
///   accessibility, synthetic, and public visibility rules.
/// - Creates type-argument link declarations for generic mixins.
/// - Applies JetLeaf’s naming, qualified naming, synthetic detection, and
///   internal-symbol logic (`isInternal`, `isSynthetic`).
/// - Stores generated mixins in the shared `typeCache`, ensuring stable identity
///   across the system.
///
///
/// ## When JetLeaf Uses This Class
/// JetLeaf calls into this support class when:
///
/// - Parsing a library that contains mixins.
/// - Converting mixins referenced as constraints or interfaces.
/// - Resolving generic type instantiations involving mixins.
/// - Building package-level or library-level declaration graphs.
///
///
/// ## Constructor
/// The constructor forwards all configuration to [AbstractTypedefDeclarationSupport]
/// and its superclass hierarchy. All parameters are required and represent the
/// reflection environment, analyzer configuration, package system, and error
/// reporting interfaces that JetLeaf uses during declaration extraction.
///
/// - `mirrorSystem`: The active `dart:mirrors` system.
/// - `forceLoadedMirrors`: Whether JetLeaf should force eager loading of mirrors.
/// - `configuration`: JetLeaf’s declaration-generation configuration.
/// - `packages`: The package resolution registry for linking declarations.
///
/// These values flow down through all generator layers involved in type,
/// constructor, typedef, record, and variable generation.
/// {@endtemplate}
abstract class AbstractMixinDeclarationSupport extends AbstractTypedefDeclarationSupport {
  /// {@macro abstract_mixin_declaration_support}
  AbstractMixinDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  /// Generate mixin declaration with analyzer support.
  ///
  /// This method produces a complete [MixinDeclaration] for a mixin represented
  /// by a [ClassMirror], combining static analyzer information with runtime
  /// reflection.
  ///
  ///
  /// ## Parameters
  /// - `mixinMirror`: The mirror representing the mixin.
  /// - `package`: The JetLeaf package context that owns the mixin.
  /// - `libraryUri`: The URI string of the parent library where the mixin resides.
  /// - `sourceUri`: The resolved canonical URI of the source file.
  /// - `isBuiltIn`: Indicates whether the mixin is part of Dart’s built-in
  ///   libraries, affecting metadata extraction and visibility behavior.
  ///
  ///
  /// ## Processing Steps
  ///
  /// ### 1. **Extract Naming and Runtime Type**
  /// Retrieves the mixin name, resolves the runtime [Type], and loads the
  /// corresponding analyzer [ClassElement], if available.
  ///
  /// ### 2. **Annotation Resolution**
  /// Extracts metadata from:
  /// - Mirror metadata (`mixinMirror.metadata`)
  /// - Analyzer metadata (`analyedMixin?.metadata.annotations`)
  ///
  /// Generic-aware annotations are processed through [GenericTypeParser] to
  /// resolve substituted or aliased types.
  ///
  ///
  /// ### 3. **Resolve Constraints and Interfaces**
  /// Both are extracted using JetLeaf link-resolution utilities:
  /// - `extractMixinConstraintsAsLink`
  /// - `extractInterfacesAsLink`
  ///
  /// These return lists of [LinkDeclaration] objects that point to other types
  /// via canonical URIs and fully qualified names.
  ///
  ///
  /// ### 4. **Create the Initial [StandardMixinDeclaration]**
  /// Initializes the declaration with:
  /// - Type arguments (converted to [LinkDeclaration]s)
  /// - Parent library linkage
  /// - Synthetic/public detection from analyzer or JetLeaf fallback
  /// - Analyzer’s `thisType`
  /// - Annotations
  /// - Constraints & interfaces
  ///
  ///
  /// ### 5. **Generate Fields**
  /// Every [VariableMirror] in the mixin declarations is converted using
  /// `generateField`, with full support for:
  /// - Static & instance fields  
  /// - Accessors  
  /// - Types & nullability  
  /// - Synthetic handling  
  /// - Built-in overrides  
  ///
  ///
  /// ### 6. **Generate Methods**
  /// All non-constructor, non-abstract [MethodMirror] instances are converted
  /// using `generateMethod`.  
  /// This includes getters, setters, normal methods, and operator overloads.
  ///
  ///
  /// ### 7. **Finalize Declaration**
  /// A final immutable copy is produced by `.copyWith`, ensuring the declaration
  /// instance matches JetLeaf’s canonical data flow.  
  /// The declaration is added to the `typeCache` using the runtime type as the
  /// identity key.
  ///
  ///
  /// ## Returns
  /// A fully constructed [MixinDeclaration] populated with:
  /// - Name, simple name, and qualified name  
  /// - Analyzer and mirror type information  
  /// - Fields & methods  
  /// - Generic type arguments  
  /// - Constraints & interfaces  
  /// - Visibility and synthetic metadata  
  /// - Linked parent library and source location  
  ///
  ///
  /// ## Example
  /// ```dart
  /// final mixinDecl = await generateMixin(
  ///   myMixinMirror,
  ///   myPackage,
  ///   'package:example/src/example.dart',
  ///   Uri.parse('package:example/src/example.dart'),
  ///   false,
  /// );
  ///
  /// print(mixinDecl.name);        // "MyMixin"
  /// print(mixinDecl.fields.length);
  /// print(mixinDecl.interfaces);  // LinkDeclarations representing interfaces
  /// ```
  @protected
  Future<MixinDeclaration> generateMixin(mirrors.ClassMirror mixinMirror, Package package, String libraryUri, Uri sourceUri, bool isBuiltIn) async {
    final mixinName = mirrors.MirrorSystem.getName(mixinMirror.simpleName);
    Type type = mixinMirror.hasReflectedType ? mixinMirror.reflectedType : mixinMirror.runtimeType;

    final logMessage = "Extracting $mixinName mixin with $type";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 1);
    
    final result = await RuntimeBuilder.timeExecution(() async {
      final analyedMixin = await getAnalyzedMixinDeclaration(mixinName, sourceUri);
      // final dartType = analyedMixin?.thisType;
      final annotations = await extractAnnotations(mixinMirror.metadata, libraryUri, sourceUri, package, analyedMixin?.metadata);
      type = await resolveGenericAnnotationIfNeeded(type, mixinMirror, package, libraryUri, sourceUri, mixinName);

      // Get source code for modifier detection
      final sourceCode = await readSourceCode(sourceUri);

      StandardMixinDeclaration reflectedMixin = StandardMixinDeclaration(
        name: mixinName,
        type: type,
        qualifiedName: buildQualifiedName(mixinName, (mixinMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
        parentLibrary: await getLibrary(libraryUri),
        isNullable: false,
        typeArguments: await extractTypeVariableAsLinks(mixinMirror.typeVariables, analyedMixin?.typeParameters, package, libraryUri),
        annotations: annotations,
        sourceLocation: sourceUri,
        constraints: await extractMixinConstraintsAsLink(mixinMirror, analyedMixin?.onClause, package, libraryUri),
        superClass: await extractSupertypeAsLink(mixinMirror, null, package, libraryUri),
        interfaces: await extractInterfacesAsLink(mixinMirror, analyedMixin?.implementsClause, package, libraryUri),
        mixins: await extractMixinsAsLink(mixinMirror, null, package, libraryUri),
        isBase: isBaseClass(sourceCode, mixinName),
        isPublic: !isInternal(mixinName),
        isSynthetic: analyedMixin?.isSynthetic ?? isSynthetic(mixinName),
      );

      final fields = <FieldDeclaration>[];
      final methods = <MethodDeclaration>[];

      // Process fields
      for (final field in mixinMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
        fields.add(await generateField(field, analyedMixin?.members, package, libraryUri, sourceUri, mixinName, null, null, isBuiltIn));
      }

      // Process methods
      for (final method in mixinMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
        if (!method.isConstructor) {
          methods.add(await generateMethod(method, analyedMixin?.members, package, libraryUri, sourceUri, mixinName, null));
        }
      }

      return reflectedMixin.updateWith(fields: fields, methods: methods);
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 1);
    return result.result;
  }
}