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
import 'abstract_annotation_declaration_support.dart';
import 'abstract_material_library_analyzer_support.dart';

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
/// final fieldDeclaration = myFieldSupport.generateField(
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
/// final topLevelField = myFieldSupport.generateTopLevelField(
///   topLevelFieldMirror,
///   package,
///   libraryUri,
///   sourceUri,
/// );
/// ```
/// {@endtemplate}
abstract class AbstractFieldDeclarationSupport extends AbstractAnnotationDeclarationSupport {
  /// {@macro abstract_field_declaration_support}
  AbstractFieldDeclarationSupport();

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
  /// - [members]: Analyzer element for the class containing the field.
  /// - [libraryUri]: URI of the library containing the field.
  /// - [sourceUri]: Source URI for locating the field in code.
  /// - [className]: Name of the containing class.
  /// - [parentClass]: Optional parent class declaration.
  /// - [sourceCode]: Optional source code for nullability and other heuristics.
  @protected
  FieldDeclaration generateField(mirrors.VariableMirror fieldMirror, AnalyzedMemberList? members, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass, String? sourceCode, bool isBuiltIn) {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    final fieldClass = fieldMirror.type;
    final fieldClassName = mirrors.MirrorSystem.getName(fieldClass.simpleName);
    Type type = fieldClass.hasReflectedType ? fieldClass.reflectedType : fieldClass.runtimeType;

    final logMessage = "Extracting $fieldName field of $fieldClassName in $className";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

    final result = RuntimeBuilder.timeExecution(() {
      final analyzedField = getAnalyzedField(members, fieldName);
      final dartType = analyzedField?.fields.type;
      type = resolveGenericAnnotationIfNeeded(type, fieldClass, libraryUri, sourceUri, fieldClassName);

      return StandardFieldDeclaration(
        name: fieldName,
        type: type,
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
        linkDeclaration: getLinkDeclaration(fieldMirror.type, libraryUri, dartType),
        annotations: extractAnnotations(fieldMirror.metadata, libraryUri, sourceUri, analyzedField?.metadata),
        sourceLocation: sourceUri,
        isFinal: fieldMirror.isFinal,
        isConst: fieldMirror.isConst,
        isLate: analyzedField?.fields.lateKeyword != null || isLateField(sourceCode, fieldName),
        isStatic: fieldMirror.isStatic,
        isPublic: !isInternal(fieldName),
        isSynthetic: analyzedField?.isSynthetic ?? isSynthetic(fieldName),
        isNullable: isNullable(
          fieldName: fieldName,
          sourceCode: isBuiltIn ? "" : sourceCode ?? readSourceCode(sourceUri),
          field: analyzedField
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
  /// - [libraryUri]: URI of the library containing the variable.
  /// - [sourceUri]: Source URI for reading code if needed.
  @protected
  FieldDeclaration generateTopLevelField(mirrors.VariableMirror fieldMirror, Uri libraryUri, Uri sourceUri, bool isBuiltIn) {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    final fieldClass = fieldMirror.type;
    final fieldClassName = mirrors.MirrorSystem.getName(fieldClass.simpleName);
    Type type = fieldClass.hasReflectedType ? fieldClass.reflectedType : fieldClass.runtimeType;

    final logMessage = "Extracting top-level $fieldName field of $fieldClassName";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

    final result = RuntimeBuilder.timeExecution(() {
      final analyzedVariable = getAnalyzedTopLevelVariable(libraryUri, fieldName);
      final dartType = analyzedVariable?.variables.type;
      type = resolveGenericAnnotationIfNeeded(type, fieldClass, libraryUri.toString(), sourceUri, fieldClassName);

      final sourceCode = isBuiltIn ? "" : readSourceCode(sourceUri);

      return StandardFieldDeclaration(
        name: fieldName,
        type: type,
        parentClass: null,
        linkDeclaration: getLinkDeclaration(fieldMirror.type, libraryUri.toString(), dartType),
        annotations: extractAnnotations(fieldMirror.metadata, libraryUri.toString(), sourceUri, analyzedVariable?.metadata),
        sourceLocation: sourceUri,
        isFinal: fieldMirror.isFinal,
        isConst: fieldMirror.isConst,
        isLate: analyzedVariable?.variables.lateKeyword != null || false,
        isAbstract: false,
        isPublic: !isInternal(fieldName),
        isSynthetic: analyzedVariable?.isSynthetic ?? isSynthetic(fieldName),
        isTopLevel: true,
        isNullable: checkTypeAnnotationNullable(dartType) || isNullable(fieldName: fieldName, sourceCode: sourceCode)
      );
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
    return result.result;
  }
}