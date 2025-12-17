// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import 'abstract_annotation_declaration_support.dart';

/// {@template abstract_field_declaration_support}
/// Abstract support class for generating and extracting field declarations
/// within the JetLeaf framework.
///
/// `AbstractFieldDeclarationSupport` extends [AbstractAnnotationDeclarationSupport]
/// to provide advanced mechanisms for analyzing and generating **field metadata**
/// for classes and top-level variables, including type resolution, annotations,
/// and source-level details.
///
/// # Responsibilities
/// This class is responsible for:
/// 1. **Field type resolution**
///    - Resolves field types using both analyzer elements ([InterfaceElement])
///      and mirrors ([VariableMirror]) to provide accurate runtime and static types.
///    - Supports generic types via [GenericTypeParser] and resolves them when needed.
///
/// 2. **Field metadata extraction**
///    - Extracts annotations associated with fields.
///    - Captures field modifiers such as `final`, `const`, `late`, `static`, and `abstract`.
///    - Determines visibility (`isPublic`) and synthetic status (`isSynthetic`).
///    - Detects nullability using both analyzer metadata and source code heuristics.
///
/// 3. **Link generation**
///    - Produces [LinkDeclaration]s for each field type using inherited methods
///      from [AbstractLinkDeclarationSupport].
///    - Ensures cycle-safe processing and caches results for efficiency.
///
/// 4. **Top-level field support**
///    - Supports fields declared at the library scope (not within classes).
///    - Integrates analyzer and mirror-based type information and annotations.
///
/// # Usage
/// Subclasses should use [generateField] for instance or class fields and
/// [generateTopLevelField] for library-level variables. Both methods return
/// a structured [FieldDeclaration] representing the field metadata, annotations,
/// type, and runtime information.
///
/// # Notes
/// - The class is **abstract** and intended to be extended by framework or tooling
///   modules for field processing.
/// - Fully compatible with runtime reflection and analyzer-based metadata,
///   making it suitable for both JIT and AOT contexts.
/// - Exception-safe: individual field extraction errors are caught to prevent
///   total failure of processing.
///
/// # Example
/// ```dart
/// final fieldDeclaration = await myFieldSupport.generateField(
///   fieldMirror,
///   parentClassElement,
///   package,
///   libraryUri,
///   sourceUri,
///   className,
///   parentClassDeclaration,
///   sourceCode,
/// );
///
/// final topLevelField = await myFieldSupport.generateTopLevelField(
///   topLevelFieldMirror,
///   package,
///   libraryUri,
///   sourceUri,
/// );
/// ```
/// {@endtemplate}
abstract class AbstractFieldDeclarationSupport extends AbstractAnnotationDeclarationSupport {
  /// {@macro abstract_field_declaration_support}
  AbstractFieldDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  /// Generates a [FieldDeclaration] for a class or instance field.
  ///
  /// This method performs the following:
  /// - Resolves the field type using mirrors and analyzer elements.
  /// - Handles generic type resolution via [GenericTypeParser].
  /// - Extracts annotations from the field.
  /// - Determines field modifiers (`final`, `const`, `late`, `static`, `abstract`).
  /// - Detects nullability using analyzer type information or source code heuristics.
  /// - Builds a corresponding [LinkDeclaration] for type linking.
  ///
  /// # Parameters
  /// - [fieldMirror]: The mirror representing the field.
  /// - [parentElement]: Analyzer element for the class containing the field.
  /// - [package]: The package context.
  /// - [libraryUri]: URI of the library containing the field.
  /// - [sourceUri]: Source URI for locating the field in code.
  /// - [className]: Name of the containing class.
  /// - [parentClass]: Optional parent class declaration.
  /// - [sourceCode]: Optional source code for nullability and other heuristics.
  @protected
  Future<FieldDeclaration> generateField(mirrors.VariableMirror fieldMirror, InterfaceElement? parentElement, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass, String? sourceCode, bool isBuiltIn) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    final fieldClass = fieldMirror.type;
    final fieldClassName = mirrors.MirrorSystem.getName(fieldClass.simpleName);
    Type type = fieldClass.hasReflectedType ? fieldClass.reflectedType : fieldClass.runtimeType;

    final logMessage = "Extracting $fieldName field of $fieldClassName in $className";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

    final result = await RuntimeBuilder.timeExecution(() async {
      final fieldElement = parentElement?.getField(fieldName);
      final dartType = fieldElement?.type;
      type = await resolveGenericAnnotationIfNeeded(type, fieldClass, package, libraryUri, sourceUri, fieldClassName);

      return StandardFieldDeclaration(
        name: fieldName,
        type: type,
        element: fieldElement,
        dartType: dartType,
        libraryDeclaration: await getLibrary(libraryUri),
        parentClass: parentClass != null ? StandardLinkDeclaration(
          name: parentClass.getName(),
          type: parentClass.getType(),
          pointerType: parentClass.getType(),
          qualifiedName: parentClass.getQualifiedName(),
          isPublic: parentClass.getIsPublic(),
          dartType: parentClass.getDartType(),
          canonicalUri: Uri.parse(parentClass.getPackageUri()),
          referenceUri: Uri.parse(parentClass.getPackageUri()),
          isSynthetic: parentClass.getIsSynthetic(),
        ) : null,
        linkDeclaration: await getLinkDeclaration(fieldMirror.type, package, libraryUri, dartType),
        annotations: await extractAnnotations(fieldMirror.metadata, libraryUri, sourceUri, package, fieldElement?.metadata.annotations),
        sourceLocation: sourceUri,
        isFinal: fieldMirror.isFinal,
        isConst: fieldMirror.isConst,
        isLate: fieldElement?.isLate ?? isLateField(sourceCode, fieldName),
        isStatic: fieldMirror.isStatic,
        isAbstract: fieldElement?.isAbstract ?? false,
        isPublic: fieldElement?.isPublic ?? !isInternal(fieldName),
        isSynthetic: fieldElement?.isSynthetic ?? isSynthetic(fieldName),
        isNullable: isNullable(
          fieldName: fieldName,
          sourceCode: isBuiltIn ? "" : sourceCode ?? await readSourceCode(sourceUri),
          fieldElement: fieldElement
        )
      );
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
    return result.result;
  }

  /// Generates a [FieldDeclaration] for a top-level field (library-scoped).
  ///
  /// This method performs similar resolution steps as [generateField], but
  /// is tailored for top-level variables that are not part of a class.
  /// It handles:
  /// - Analyzer-based top-level variable lookup.
  /// - Mirror-based type extraction.
  /// - Generic type resolution and annotation extraction.
  /// - Modifier detection and nullability analysis.
  ///
  /// # Parameters
  /// - [fieldMirror]: Mirror representing the top-level variable.
  /// - [package]: Package context for type resolution.
  /// - [libraryUri]: URI of the library containing the variable.
  /// - [sourceUri]: Source URI for reading code if needed.
  @protected
  Future<FieldDeclaration> generateTopLevelField(mirrors.VariableMirror fieldMirror, Package package, Uri libraryUri, Uri sourceUri, bool isBuiltIn) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    final fieldClass = fieldMirror.type;
    final fieldClassName = mirrors.MirrorSystem.getName(fieldClass.simpleName);
    Type type = fieldClass.hasReflectedType ? fieldClass.reflectedType : fieldClass.runtimeType;

    final logMessage = "Extracting top-level $fieldName field of $fieldClassName";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

    final result = await RuntimeBuilder.timeExecution(() async {
      final libraryElement = await getLibraryElement(libraryUri);
      final variableElement = libraryElement?.getTopLevelVariable(fieldName) ?? libraryElement?.topLevelVariables.where((v) => v.name == fieldName).firstOrNull;
      final dartType = variableElement?.type;
      type = await resolveGenericAnnotationIfNeeded(type, fieldClass, package, libraryUri.toString(), sourceUri, fieldClassName);

      final sourceCode = isBuiltIn ? "" : await readSourceCode(sourceUri);

      return StandardFieldDeclaration(
        name: fieldName,
        type: type,
        element: variableElement,
        dartType: dartType,
        libraryDeclaration: await getLibrary(libraryUri.toString()),
        parentClass: null,
        linkDeclaration: await getLinkDeclaration(fieldMirror.type, package, libraryUri.toString(), dartType),
        annotations: await extractAnnotations(fieldMirror.metadata, libraryUri.toString(), sourceUri, package, variableElement?.metadata.annotations),
        sourceLocation: sourceUri,
        isFinal: fieldMirror.isFinal,
        isConst: fieldMirror.isConst,
        isLate: variableElement?.isLate ?? false,
        isStatic: variableElement?.isStatic ?? true,
        isAbstract: false,
        isPublic: variableElement?.isPublic ?? !isInternal(fieldName),
        isSynthetic: variableElement?.isSynthetic ?? isSynthetic(fieldName),
        isTopLevel: true,
        isNullable: variableElement != null 
          ? variableElement.type.nullabilitySuffix == NullabilitySuffix.question
          : isNullable(fieldName: fieldName, sourceCode: sourceCode)
      );
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
    return result.result;
  }
}