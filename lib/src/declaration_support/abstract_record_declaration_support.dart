// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:ffi';
import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../declaration/declaration.dart';
import '../utils/dart_type_resolver.dart';
import '../utils/generic_type_parser.dart';
import 'abstract_typedef_declaration_support.dart';

/// Support class for generating RecordDeclaration.
abstract class AbstractRecordDeclarationSupport extends AbstractTypedefDeclarationSupport {
  AbstractRecordDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Generate record type with analyzer support
  @protected
  Future<RecordDeclaration> generateRecordType(mirrors.TypeMirror typeMirror, Element? typeElement, Package package, String libraryUri) async {
    final recordName = typeMirror.hasReflectedType ? typeMirror.reflectedType.toString() : typeMirror.runtimeType.toString();
    final positionalFields = <RecordFieldDeclaration>[];
    final namedFields = <String, RecordFieldDeclaration>{};

    // Parse record structure from string representation
    final recordContent = recordName.substring(1, recordName.length - 1);
    final parts = splitRecordContent(recordContent);
    
    int positionalIndex = 0;
    bool inNamedSection = false;

    Type runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(typeMirror.metadata, package);
      final resolvedType = await resolveTypeFromGenericAnnotation(annotations, recordName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final record = StandardRecordDeclaration(
      name: recordName,
      type: runtimeType,
      element: typeElement,
      dartType: (typeElement as InterfaceElement?)?.thisType,
      qualifiedName: buildQualifiedName(recordName, (typeMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: libraryCache[libraryUri]!,
      positionalFields: positionalFields,
      namedFields: namedFields,
      annotations: await extractAnnotations(typeMirror.metadata, package),
      sourceLocation: typeMirror.location?.sourceUri,
      isPublic: !isInternal(recordName),
      isSynthetic: isSynthetic(recordName),
    );
    
    for (var part in parts) {
      part = part.trim();
      if (part.startsWith('{')) {
        inNamedSection = true;
        part = part.substring(1);
      }
      if (part.endsWith('}')) {
        part = part.substring(0, part.length - 1);
      }
      if (part.isEmpty) continue;

      final typeAndName = part.split(' ');
      String fieldTypeName;
      String? fieldName;
      
      if (typeAndName.length > 1 && !inNamedSection) {
        fieldTypeName = typeAndName.sublist(0, typeAndName.length - 1).join(' ');
        fieldName = typeAndName.last;
      } else if (typeAndName.length > 1 && inNamedSection) {
        fieldTypeName = typeAndName.sublist(0, typeAndName.length - 1).join(' ');
        fieldName = typeAndName.last;
      } else {
        fieldTypeName = typeAndName.first;
      }

      // Create field type
      // Resolve the actual type and URI for the field
      Type? resolvedType = resolvePublicDartType('dart:core', fieldTypeName);
      // resolvedType ??= resolveTypeFromName(fieldTypeName);
      
      final actualType = resolvedType ?? Object;
      final actualPackageUri = getPackageUriForType(fieldTypeName, actualType);

      // Create field type with proper resolution
      final fieldType = StandardLinkDeclaration(
        name: fieldTypeName,
        type: actualType,
        pointerType: actualType,
        qualifiedName: buildQualifiedName(fieldTypeName, actualPackageUri),
        isPublic: !isInternal(fieldTypeName),
        isSynthetic: isSynthetic(fieldTypeName),
        canonicalUri: Uri.parse(actualPackageUri),
        referenceUri: Uri.parse(actualPackageUri)
      );

      if (inNamedSection) {
        final field = StandardRecordFieldDeclaration(
          name: fieldName!,
          typeDeclaration: fieldType,
          sourceLocation: typeMirror.location?.sourceUri ?? Uri.parse(libraryUri),
          type: actualType,
          libraryDeclaration: libraryCache[libraryUri]!,
          isPublic: !isInternal(fieldName),
          isSynthetic: isSynthetic(fieldName),
          isNullable: false
        );
        namedFields[fieldName] = field;
      } else {
        final name = fieldName ?? 'field_$positionalIndex';

        final field = StandardRecordFieldDeclaration(
          name: name,
          position: positionalIndex,
          typeDeclaration: fieldType,
          sourceLocation: typeMirror.location?.sourceUri ?? Uri.parse(libraryUri),
          type: actualType,
          libraryDeclaration: libraryCache[libraryUri]!,
          isPublic: !isInternal(name),
          isSynthetic: isSynthetic(name),
          isNullable: false
        );
        positionalFields.add(field);
        positionalIndex++;
      }
    }

    return record.copyWith(namedFields: namedFields, positionalFields: positionalFields);
  }
}