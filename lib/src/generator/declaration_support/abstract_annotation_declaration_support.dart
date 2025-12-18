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
import '../abstract_element_support.dart';
import 'abstract_record_link_declaration_support.dart';

/// {@template abstract_annotation_declaration_support}
/// Abstract support class for extracting and generating annotation declarations
/// within the JetLeaf framework.
///
/// `AbstractAnnotationDeclarationSupport` extends [AbstractRecordLinkDeclarationSupport]
/// to provide specialized mechanisms for handling **Dart annotations** at both
/// compile-time (via analyzer types) and runtime (via mirrors). This class
/// is designed to be the base for tools that need structured information about
/// annotations, their fields, and associated type metadata.
///
/// # Responsibilities
/// This class is responsible for:
/// 1. **Annotation type resolution**
///    - Resolves the Dart type of an annotation instance.
///    - Handles generic annotations using [GenericTypeParser] and runtime metadata.
///    - Integrates both analyzer types ([DartType]) and mirrors ([TypeMirror])
///      for full reflection support.
///
/// 2. **Annotation field extraction**
///    - Detects non-static fields defined in annotation classes.
///    - Resolves each field’s type to a [LinkDeclaration].
///    - Captures user-provided values present in the annotation instance.
///    - Retrieves default values from annotation constructors when available.
///    - Tracks immutability and const modifiers (`isFinal`, `isConst`).
///    - Determines nullability of fields based on default and user-provided values.
///
/// 3. **Structured representation**
///    - Constructs [StandardAnnotationDeclaration] objects containing:
///      - Name and fully resolved type of the annotation.
///      - Runtime instance reference.
///      - Map of extracted fields, including values, types, and metadata.
///      - Visibility (`isPublic`) and synthetic status (`isSynthetic`).
///
/// 4. **Cycle detection and caching**
///    - Inherited from [AbstractRecordLinkDeclarationSupport].
///    - Prevents infinite recursion in nested annotations or generic types.
///    - Caches generated link declarations for efficiency.
///
/// # Usage
/// Subclasses should override or extend [extractAnnotations] to:
/// - Apply custom logic for annotation filtering.
/// - Integrate additional metadata extraction (e.g., for code generation).
/// - Support framework-specific annotation conventions.
///
/// # Notes
/// - The class is **abstract** and cannot be instantiated directly.
/// - Designed for **internal JetLeaf use**, but can be extended by tooling plugins.
/// - Supports both **runtime reflection** and **analyzer-based metadata**, making
///   it compatible with both ahead-of-time and just-in-time contexts.
/// - Exception-safe: field extraction and default value resolution errors are caught
///   and do not interrupt processing.
///
/// # Example
/// ```dart
/// class MyAnnotation {
///   final String name;
///   final int count;
///   const MyAnnotation({this.name = 'default', this.count = 0});
/// }
///
/// // Usage in subclass:
/// final annotations = await myAnnotationSupport.extractAnnotations(metadata, package);
/// ```
/// {@endtemplate}
abstract class AbstractAnnotationDeclarationSupport extends AbstractRecordLinkDeclarationSupport {
  /// Constructs an [AbstractAnnotationDeclarationSupport] instance.
  ///
  /// All parameters are required and forwarded to [AbstractRecordLinkDeclarationSupport].
  /// {@macro abstract_annotation_declaration_support}
  AbstractAnnotationDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  /// Retrieves an [ElementAnnotation] by index or by name from a list of analyzer
  /// metadata annotations.
  ///
  /// This helper provides a unified way to extract an annotation from the static
  /// analyzer metadata associated with an element. It supports two lookup
  /// strategies:
  ///
  /// ### 1. Index-based Lookup
  /// If the caller provides an `index` that falls within the bounds of the
  /// annotation list, that annotation is returned immediately.  
  ///  
  /// This is the fastest and most predictable path and is typically used when
  /// the mirror and analyzer annotations are expected to be aligned in order.
  ///
  /// ### 2. Name-based Lookup (Fallback)
  /// If the index is out of bounds, the method attempts a **secondary lookup**
  /// using the `annotationName`.  
  ///
  /// It searches the list for the first annotation where:
  ///
  /// ```dart
  /// a.element?.displayName == annotationName
  /// ```
  ///
  /// This is useful when the analyzer produces annotations in a different order
  /// than mirrors, or when index consistency cannot be guaranteed.
  ///
  /// ### Parameters
  /// - **annotationName**  
  ///   The display name of the annotation type to search for when index-based
  ///   lookup is not possible.
  ///
  /// - **index**  
  ///   The preferred position of the annotation in the list. If valid, this
  ///   position is used directly.
  ///
  /// - **annotations**  
  ///   The list of analyzer [ElementAnnotation] objects to search.  
  ///   May be `null`, in which case lookup always returns `null`.
  ///
  /// ### Returns
  /// - The resolved [ElementAnnotation] if found.
  /// - `null` if no annotation matches or the list itself is `null`.
  ///
  /// ### Notes
  /// - This method provides safe, null-aware access and does not throw for
  ///   out-of-range indices.
  /// - It is intentionally tolerant because analyzer metadata ordering can vary
  ///   between Dart versions and compilation strategies.
  /// - The use of `firstOrNull` assumes an extension method (e.g., from
  ///   `collection` or custom extensions) is available in the project.
  // ElementAnnotation? _getAnnotation(String annotationName, int index, List<ElementAnnotation>? annotations) {
  //   if (annotations != null && index < annotations.length) {
  //     return annotations[index];
  //   }

  //   return annotations?.where((a) => a.element?.displayName == annotationName).firstOrNull;
  // }

  /// Extracts a list of [AnnotationDeclaration] objects from a list of runtime metadata mirrors.
  ///
  /// This method performs the following tasks:
  /// 1. Iterates over each annotation in the provided [metadata] list.
  /// 2. Resolves the annotation type, considering generic annotations if present.
  /// 3. Extracts **fields** of the annotation:
  ///    - Non-static instance variables are considered as annotation fields.
  ///    - Resolves the type of each field using [getLinkDeclaration].
  ///    - Captures **user-provided values** from the annotation instance, if available.
  ///    - Captures **default values** from the constructor parameters, if available.
  ///    - Detects `final` and `const` modifiers.
  ///    - Computes `isNullable` based on presence of default or user value.
  /// 4. Builds [StandardAnnotationDeclaration] for each annotation.
  ///
  /// Parameters:
  /// - [metadata]: A list of [mirrors.InstanceMirror] objects representing annotation instances.
  /// - [package]: The current [Package] context used to resolve type references.
  ///
  /// Returns:
  /// A [Future] completing with a list of [AnnotationDeclaration] objects, each containing:
  /// - Annotation name.
  /// - Fully resolved type declaration ([LinkDeclaration]).
  /// - Extracted fields with default and user-provided values.
  /// - The runtime instance of the annotation.
  /// - Flags for visibility (`isPublic`) and synthetic status (`isSynthetic`).
  @override
  @protected
  Future<List<AnnotationDeclaration>> extractAnnotations(List<mirrors.InstanceMirror> metadata, String libraryUri, Uri sourceUri, Package package, [List<AnalyzedAnnotation>? analyzerAnnotations]) async {
    final annotations = <AnnotationDeclaration>[];
    
    for (int i = 0; i < metadata.length; i++) {
      final annotation = metadata[i];
      final annotationClass = annotation.type;
      Type type = annotationClass.hasReflectedType ? annotationClass.reflectedType : annotationClass.runtimeType;
      final annotationName = mirrors.MirrorSystem.getName(annotationClass.simpleName);

      final logMessage = "Extracting $annotationName annotation with $type";
      RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 1);

      final result = await RuntimeBuilder.timeExecution(() async {
        final uriToUse = annotationClass.location?.sourceUri ?? sourceUri;
        final analyzedAnnotation = await getAnalyzedClassDeclaration(annotationName, sourceUri);

        try {
          type = await resolveGenericAnnotationIfNeeded(type, annotationClass, package, libraryUri, sourceUri, annotationName);
          
          final annotationFields = <String, AnnotationFieldDeclaration>{};
          final userProvidedValues = <String, dynamic>{};
          final annotationInstance = annotation.hasReflectee ? annotation.reflectee : null;

          mirrors.DeclarationMirror? owner;
          Iterable<mirrors.DeclarationMirror> declarations = [];

          if (annotationClass.owner is mirrors.LibraryMirror) {
            owner = annotationClass.owner;
            declarations = annotationClass.declarations.values;
          } else if (annotationInstance != null) {
            final im = mirrors.reflect(annotationInstance);

            if (im.type.owner is mirrors.LibraryMirror) {
              owner = im.type.owner;
              declarations = im.type.declarations.values;
            }
          }

          if (owner is mirrors.LibraryMirror) {
            for (final declaration in declarations) {
              try {
                if (declaration is mirrors.VariableMirror && !declaration.isStatic) {
                  final symbol = declaration.simpleName;
                  final fieldName = mirrors.MirrorSystem.getName(symbol);
                  final analyzedField = getAnalyzedField(analyzedAnnotation?.members, fieldName);
                  final resolvedLibraryUri = declaration.type.location?.sourceUri.toString() ?? declaration.location?.sourceUri.toString() ?? libraryUri;
                  final fieldType = await getLinkDeclaration(declaration.type, package, resolvedLibraryUri);
                  final sourceCode = await readSourceCode(uriToUse);

                  // Get user-provided value with improved safety check
                  dynamic userValue;
                  bool hasUserValue = false;
                  try {
                    final fieldMirror = annotation.getField(symbol);
                    if (fieldMirror.hasReflectee) {
                      userValue = fieldMirror.reflectee;
                      hasUserValue = true;
                      userProvidedValues[fieldName] = userValue;
                    }
                  } catch (e) {
                    // Field access failed, continue without user value
                  }

                  // Get default value from constructor with improved handling
                  dynamic defaultValue;
                  bool hasDefaultValue = false;
                  try {
                    for (final constructor in declarations.whereType<mirrors.MethodMirror>()) {
                      if (constructor.isConstructor) {
                        for (final param in constructor.parameters) {
                          final paramName = mirrors.MirrorSystem.getName(param.simpleName);
                          if (paramName == fieldName && param.hasDefaultValue && param.defaultValue?.hasReflectee == true) {
                            defaultValue = param.defaultValue!.reflectee;
                            hasDefaultValue = true;
                            break;
                          }
                        }
                        if (hasDefaultValue) break;
                      }
                    }
                  } catch (e) {
                    // Default value extraction failed, continue without default
                  }
                  
                  annotationFields[fieldName] = StandardAnnotationFieldDeclaration(
                    name: fieldName,
                    typeDeclaration: fieldType,
                    defaultValue: defaultValue,
                    hasDefaultValue: hasDefaultValue,
                    userValue: userValue,
                    hasUserValue: hasUserValue,
                    isFinal: analyzedField?.fields.isFinal ?? declaration.isFinal,
                    isConst: analyzedField?.fields.isConst ?? declaration.isConst,
                    type: fieldType.getType(),
                    isPublic: !isInternal(fieldName),
                    isSynthetic: analyzedField?.isSynthetic ?? isSynthetic(fieldName),
                    position: declarations.toList().indexOf(declaration),
                    annotations: await extractAnnotations(declaration.metadata, resolvedLibraryUri, sourceUri, package),
                    libraryDeclaration: await getLibrary(resolvedLibraryUri),
                    sourceLocation: sourceUri,
                    isNullable: isNullable(fieldName: fieldName, field: analyzedField, sourceCode: sourceCode) || defaultValue == null && userValue == null
                  );
                }
              } catch (_) { }
            }
          }

          annotations.add(StandardAnnotationDeclaration(
            name: annotationName,
            linkDeclaration: StandardLinkDeclaration(
              name: annotationName,
              type: type,
              pointerType: type,
              typeArguments: await extractTypeVariableAsLinks(
                annotationClass.typeVariables,
                analyzedAnnotation?.typeParameters,
                package,
                libraryUri
              ),
              qualifiedName: buildQualifiedName(annotationName, await getPkgUri(annotationClass, package.getName(), 'dart:core')),
              isPublic: !isInternal(annotationName),
              isSynthetic: analyzedAnnotation?.isSynthetic ?? isSynthetic(annotationName),
            ),
            instance: annotationInstance,
            fields: annotationFields,
            userProvidedValues: userProvidedValues,
            type: type,
            isPublic: !isInternal(annotationName),
            isSynthetic: analyzedAnnotation?.isSynthetic ?? isSynthetic(annotationName),
          ));
        } catch (e) {
          // print('Failed to extract annotation: $e');
        }
      });

      RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 1);
    }
    
    return annotations;
  }
}