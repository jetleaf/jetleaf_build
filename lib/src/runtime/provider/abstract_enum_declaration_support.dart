// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import 'abstract_mixin_declaration_support.dart';

/// {@template abstract_enum_declaration_support}
/// A specialized reflection and analyzer-based support class responsible for
/// generating [`EnumDeclaration`] objects for JetLeaf's type-introspection
/// system.
///
/// This class sits on top of [`AbstractMixinDeclarationSupport`], inheriting
/// all mixin/constraint/interface extraction logic, and extends it with
/// complete enum-specific generation behavior.
///
/// ### Purpose
/// JetLeaf uses a hybrid reflection model (combining `dart:mirrors` and the
/// Dart Analyzer) to produce strongly-typed declaration objects that describe
/// every construct in a Dart library.  
/// `AbstractEnumDeclarationSupport` contributes the logic required to:
///
/// - Inspect enum types using `ClassMirror`.
/// - Match those enum types with corresponding Analyzer `EnumElement`s.
/// - Extract enum values, members, annotations, type arguments, and metadata.
/// - Resolve generic types and support JetLeaf's generic-annotation override
///   mechanism.
/// - Produce a fully-formed [`EnumDeclaration`] that integrates cleanly with
///   the JetLeaf declaration graph.
///
/// ### Why both Mirrors *and* Analyzer?
/// Enums require runtime value access (`value.reflectee`) to retrieve the
/// actual enum constant instances, but also require static information from
/// the Analyzer, such as:
///
/// - syntactic metadata,
/// - static types,
/// - public/synthetic flags,
/// - raw source code for nullability heuristics.
///
/// This class unifies both representations into one consistent JetLeaf
/// declaration model.
///
/// ### Responsibilities
/// - Resolve and validate enum names.
/// - Resolve underlying Dart types (including generic annotation overrides).
/// - Extract:
///   - enum values (`EnumFieldDeclaration`)
///   - methods
///   - instance fields
///   - annotations
///   - type parameters / type arguments
/// - Evaluate visibility (`isPublic`) and synthetic status (`isSynthetic`).
/// - Provide correct `qualifiedName` linking to the enum's library.
/// - Cache resolved declarations through JetLeaf’s type cache.
///
/// ### Not intended for direct use
/// This is an **internal support class** used by higher-level JetLeaf
/// declaration builders. Concrete subclasses typically bundle multiple
/// declaration-support behaviors into a complete library-introspection
/// pipeline.
///
/// {@endtemplate}
abstract class AbstractEnumDeclarationSupport extends AbstractMixinDeclarationSupport {
  /// {@macro abstract_enum_declaration_support}
  AbstractEnumDeclarationSupport();

  /// Generates a complete [`EnumDeclaration`] for the enum represented by the
  /// given [enumMirror], combining reflection (`dart:mirrors`) and static
  /// semantic information from the Dart Analyzer.
  ///
  /// This method forms the core of JetLeaf’s enum-introspection workflow. It
  /// constructs a [`StandardEnumDeclaration`] by progressively collecting and
  /// merging information from:
  ///
  /// - the runtime mirror (`ClassMirror`),
  /// - the corresponding Analyzer [`EnumElement`] (if found),
  /// - resolved generic-type overrides (via annotation-based generic resolver),
  /// - extracted enum values,
  /// - extracted methods & fields,
  /// - resolved annotations,
  /// - visibility/synthetic heuristics,
  /// - source-code analysis for nullability.
  ///
  /// ### Parameter Details
  /// - **[enumMirror]**  
  ///   The runtime mirror representing the enum. Provides access to reflected
  ///   values, declarations, and runtime type metadata.
  ///
  /// - **[libraryUri]**  
  ///   String URI of the library declaring this enum. Used to bind the enum to
  ///   JetLeaf’s library cache.
  ///
  /// - **[sourceUri]**  
  ///   URI pointing to the actual source file. Required for reading source code
  ///   when evaluating value-nullability heuristics.
  ///
  /// - **[isBuiltIn]**  
  ///   Whether the enum originates from a built-in library. Affects which fields
  ///   and methods may be generated or omitted.
  ///
  /// ### Workflow
  /// 1. **Resolve analyzer element**
  ///    Attempts to locate the corresponding [`EnumElement`] from the Analyzer.
  ///
  /// 2. **Resolve type**
  ///    Detects generic annotations and performs override resolution when
  ///    necessary (`GenericTypeParser.shouldCheckGeneric`).
  ///
  /// 3. **Initialize base declaration**
  ///    Creates a `StandardEnumDeclaration` pre-populated with:
  ///    - name and qualified name
  ///    - runtime type & analyzer type
  ///    - annotations
  ///    - type arguments (mapped to Links)
  ///    - synthetic/public determination
  ///    - placeholders for values & members
  ///
  /// 4. **Extract enum values**
  ///    Iterates static variables whose type matches the enum’s runtime type and
  ///    uses reflection to obtain the actual enum instance. Produces
  ///    [`EnumFieldDeclaration`] entries that include:
  ///    - actual enum value
  ///    - position
  ///    - visibility/synthetic status
  ///    - inferred nullability (via source-code inspection)
  ///
  /// 5. **Extract methods and instance fields**
  ///    Non-constructor methods and non-static fields are converted into
  ///    [`MemberDeclaration`] instances using JetLeaf’s method/field generators.
  ///
  /// 6. **Finalize and cache**
  ///    Mutates the base declaration to include values and members, then stores
  ///    the resulting declaration in the global type cache.
  ///
  /// ### Returns
  /// A fully populated [`EnumDeclaration`] describing all values, members,
  /// annotations, type parameters, and metadata of the enum.
  ///
  /// ### Throws
  /// - Errors from underlying worker functions such as:
  ///   - annotation extraction,
  ///   - type-argument extraction,
  ///   - source-code reading,
  ///   - analyzer lookup.
  ///
  /// ### Notes
  /// - Mirrors are required to obtain the runtime enum instances.
  /// - Analyzer is required for static type reflection and source-based metadata.
  /// - JetLeaf’s hybrid inspection strategy guarantees correctness even in
  ///   non-reflected generic or macro-generated contexts.
  @protected
  EnumDeclaration generateEnum(mirrors.ClassMirror enumMirror, String libraryUri, Uri sourceUri, bool isBuiltIn) {
    final enumName = mirrors.MirrorSystem.getName(enumMirror.simpleName);
    Type type = enumMirror.hasReflectedType ? enumMirror.reflectedType : enumMirror.runtimeType;

    final logMessage = "Extracting $enumName enum with $type";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 1);

    final result = RuntimeBuilder.timeExecution(() {
      final sourceCode = readSourceCode(sourceUri);
      final analyzedEnum = getAnalyzedEnumDeclaration(enumName, sourceUri);
      // final dartType = analyzedEnum?.thisType;
      type = resolveGenericAnnotationIfNeeded(type, enumMirror, libraryUri, sourceUri, enumName);

      StandardEnumDeclaration reflectedEnum = StandardEnumDeclaration(
        name: enumName,
        type: type,
        isPublic: !isInternal(enumName),
        isSynthetic: analyzedEnum?.isSynthetic ?? isSynthetic(enumName),
        qualifiedName: buildQualifiedName(enumName, (findRealClassUriFromMirror(enumMirror) ?? Uri.parse(libraryUri)).toString()),
        library: getLibrary(libraryUri),
        values: [],
        typeArguments: extractTypeVariableAsLinks(enumMirror.typeVariables, analyzedEnum?.typeParameters, libraryUri),
        annotations: extractAnnotations(enumMirror.metadata, libraryUri, sourceUri, analyzedEnum?.metadata),
        sourceLocation: sourceUri,
        interfaces: extractInterfacesAsLink(enumMirror, analyzedEnum?.implementsClause, libraryUri),
        superClass: extractSupertypeAsLink(enumMirror, null, libraryUri),
        mixins: extractMixinsAsLink(enumMirror, analyzedEnum?.withClause, libraryUri)
      );

      final values = <EnumFieldDeclaration>[];

      // Extract enum values with safety checks
      for (final declaration in enumMirror.declarations.values) {
        if (declaration is mirrors.VariableMirror && declaration.isStatic && declaration.type.hasReflectedType && declaration.type.reflectedType == type) {
          final fieldMirror = enumMirror.getField(declaration.simpleName);
          if (fieldMirror.hasReflectee) {
            final enumValue = fieldMirror.reflectee;
            final enumFieldName = mirrors.MirrorSystem.getName(declaration.simpleName);

            values.add(StandardEnumFieldDeclaration(
              name: enumFieldName,
              type: type,
              linkDeclaration: StandardLinkDeclaration(
                name: enumName,
                type: type,
                pointerType: type,
                qualifiedName: reflectedEnum.getQualifiedName(),
                isPublic: reflectedEnum.getIsPublic(),
                isSynthetic: reflectedEnum.getIsSynthetic(),
                canonicalUri: reflectedEnum.getSourceLocation(),
                referenceUri: reflectedEnum.getSourceLocation(),
                typeArguments: reflectedEnum.getTypeArguments()
              ),
              value: enumValue,
              isPublic: !isInternal(enumFieldName),
              isSynthetic: isSynthetic(enumFieldName),
              annotations: extractAnnotations(declaration.metadata, libraryUri, sourceUri),
              position: enumMirror.declarations.values.toList().indexOf(declaration),
              isNullable: isNullable(fieldName: enumFieldName, sourceCode: readSourceCode(sourceUri))
            ));
          }
        }
      }

      final constructors = <ConstructorDeclaration>[];
      final fields = <FieldDeclaration>[];
      final methods = <MethodDeclaration>[];
      // final records = <RecordDeclaration>[];

      // Process constructors with analyzer support
      for (final constructor in enumMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
        if (constructor.isConstructor) {
          constructors.add(generateConstructor(constructor, analyzedEnum?.members, libraryUri, sourceUri, enumName, reflectedEnum));
        }
      }

      // Process fields with analyzer support
      for (final field in enumMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
        if (field.isStatic && field.type.hasReflectedType && field.type.reflectedType == type) {
          continue; // Enum fields
        }

        fields.add(generateField(field, analyzedEnum?.members, libraryUri, sourceUri, enumName, reflectedEnum, sourceCode, isBuiltIn));
      }

      // Process methods with analyzer support
      for (final method in enumMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
        if (!method.isConstructor) {
          methods.add(generateMethod(method, analyzedEnum?.members, libraryUri, sourceUri, enumName, StandardLinkDeclaration(
            name: reflectedEnum.getName(),
            type: reflectedEnum.getType(),
            pointerType: reflectedEnum.getType(),
            qualifiedName: reflectedEnum.getQualifiedName(),
            isPublic: reflectedEnum.getIsPublic(),
            canonicalUri: Uri.parse(reflectedEnum.getPackageUri()),
            referenceUri: Uri.parse(reflectedEnum.getPackageUri()),
            isSynthetic: reflectedEnum.getIsSynthetic(),
          )));
        }
      }

      return reflectedEnum.updateWith(fields: fields, methods: methods, constructors: constructors, enumFields: values);
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 1);
    return result.result;
  }
}