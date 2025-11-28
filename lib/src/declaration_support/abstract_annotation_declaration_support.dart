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
import '../utils/generic_type_parser.dart';
import 'abstract_link_declaration_support.dart';

/// Support class for extracting and generating AnnotationDeclarations.
abstract class AbstractAnnotationDeclarationSupport extends AbstractLinkDeclarationSupport {
  AbstractAnnotationDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Extract annotations with enhanced field support and proper type resolution
  @override
  @protected
  Future<List<AnnotationDeclaration>> extractAnnotations(List<mirrors.InstanceMirror> metadata, Package package) async {
    final annotations = <AnnotationDeclaration>[];
    
    for (final annotation in metadata) {
      try {
        // Create LinkDeclaration for the annotation type
        final annotationType = annotation.type;
        Type type = annotationType.hasReflectedType ? annotationType.reflectedType : annotationType.runtimeType;
        final annotationName = mirrors.MirrorSystem.getName(annotationType.simpleName);

        // Extract annotations and resolve type
        if(GenericTypeParser.shouldCheckGeneric(type)) {
          final annotations = await extractAnnotations(annotationType.metadata, package);
          final resolvedType = await resolveTypeFromGenericAnnotation(annotations, annotationName);
          if (resolvedType != null) {
            type = resolvedType;
          }
        }
        
        final annotationFields = <String, AnnotationFieldDeclaration>{};
        final userProvidedValues = <String, dynamic>{};
        final annotationInstance = annotation.hasReflectee ? annotation.reflectee : null;

        mirrors.DeclarationMirror? owner;
        Iterable<mirrors.DeclarationMirror> declarations = [];

        if (annotationType.owner is mirrors.LibraryMirror) {
          owner = annotationType.owner;
          declarations = annotationType.declarations.values;
        } else if (annotationInstance != null) {
          final im = mirrors.reflect(annotationInstance);

          if (im.type.owner is mirrors.LibraryMirror) {
            owner = im.type.owner;
            declarations = im.type.declarations.values;
          }
        }

        if (owner is mirrors.LibraryMirror) {
          for (final declaration in declarations) {
            if (declaration is mirrors.VariableMirror && !declaration.isStatic) {
              final fieldName = mirrors.MirrorSystem.getName(declaration.simpleName);
              final libraryUri = declaration.type.location?.sourceUri.toString() ?? 'dart:core';
              final fieldType = await getLinkDeclaration(declaration.type, package, libraryUri);

              // Get user-provided value with improved safety check
              dynamic userValue;
              bool hasUserValue = false;
              try {
                final fieldMirror = annotation.getField(declaration.simpleName);
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
                isFinal: declaration.isFinal,
                isConst: declaration.isConst,
                type: fieldType.getType(),
                isPublic: !isInternal(fieldName),
                isSynthetic: isSynthetic(fieldName),
                dartType: null,
                position: declarations.toList().indexOf(declaration),
                isNullable: defaultValue == null && userValue == null
              );
            }
          }
        }

        annotations.add(StandardAnnotationDeclaration(
          name: annotationName,
          typeDeclaration: StandardLinkDeclaration(
            name: annotationName,
            type: type,
            pointerType: type,
            typeArguments: [],
            qualifiedName: buildQualifiedName(annotationName, await getPkgUri(annotationType, package.getName(), 'dart:core')),
            isPublic: !isInternal(annotationName),
            isSynthetic: isSynthetic(annotationName),
          ),
          instance: annotationInstance,
          fields: annotationFields,
          userProvidedValues: userProvidedValues,
          type: type,
          dartType: null,
          isPublic: !isInternal(annotationName),
          isSynthetic: isSynthetic(annotationName),
        ));
      } catch (e) {
        // onWarning('Failed to extract annotation: $e');
      }
    }
    
    return annotations;
  }
}