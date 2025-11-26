// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:io';
import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../annotations.dart';
import '../declaration/declaration.dart';
import '../utils/constant.dart';
import '../utils/generic_type_parser.dart';
import '../utils/utils.dart';
import 'library_generator.dart';

/// Base support class providing type-related utilities for declaration generation.
/// 
/// This class contains all @protected type methods that inheriting classes can reuse
/// for type resolution, caching, and manipulation.
abstract class AbstractTypeSupport extends LibraryGenerator {
  /// Cache of library declarations
  final Map<String, LibraryDeclaration> libraryCache = {};
  
  /// Cache of type declarations
  final Map<Type, TypeDeclaration> typeCache = {};
  
  /// Cache of package declarations
  final Map<String, Package> packageCache = {};
  
  /// Cache of source code
  final Map<String, String> sourceCache = {};

  /// Type variable cache
  final Map<String, TypeVariableDeclaration> typeVariableCache = {};

  /// Cache for DartType to Type mapping
  final Map<String, Type> dartTypeToTypeCache = {};

  AbstractTypeSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  // ========================================== TYPE UTILITIES ==============================================

  /// Check if type is primitive
  @protected
  bool isPrimitiveType(Type type) {
    return type == int || type == double || type == bool || type == String || type == num;
  }

  /// Check if type is List
  @protected
  bool isListType(Type type) {
    return type.toString().startsWith('List<') || type == List;
  }

  /// Check if type is Map
  @protected
  bool isMapType(Type type) {
    return type.toString().startsWith('Map<') || type == Map;
  }

  /// Check if type is Record
  @protected
  bool isRecordType(Type type) {
    return type.toString().startsWith('(') && type.toString().endsWith(')');
  }

  /// Determine type kind from mirror
  @protected
  TypeKind determineTypeKind(mirrors.TypeMirror typeMirror, DartType? dartType) {
    if (typeMirror.runtimeType.toString() == 'dynamic') return TypeKind.dynamicType;
    if (typeMirror.runtimeType.toString() == 'void') return TypeKind.voidType;
    
    if (typeMirror is mirrors.ClassMirror) {
      if (typeMirror.isEnum) return TypeKind.enumType;
      final runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;
      if (isPrimitiveType(runtimeType)) return TypeKind.primitiveType;
      if (isListType(runtimeType)) return TypeKind.listType;
      if (isMapType(runtimeType)) return TypeKind.mapType;
      if (isRecordType(runtimeType)) return TypeKind.recordType;
      return TypeKind.classType;
    }
    
    if (typeMirror is mirrors.TypedefMirror) return TypeKind.typedefType;
    if (typeMirror is mirrors.FunctionTypeMirror) return TypeKind.functionType;
    
    return TypeKind.unknownType;
  }

  /// Build qualified name from library URI and type name
  @protected
  String buildQualifiedName(String typeName, String libraryUri) {
    return '$libraryUri.$typeName'.replaceAll("..", '.');
  }

  /// Build qualified name from analyzer element
  @protected
  String buildQualifiedNameFromElement(Element? element) {
    if (element == null) return 'unknown';
    
    final library = element.library;
    if (library == null) {
      return buildQualifiedName(element.name ?? 'unknown', 'unknown');
    }
    
    return buildQualifiedName(element.name ?? 'unknown', library.uri.toString());
  }

  /// Checks if a URI represents a built-in Dart library
  @protected
  bool isBuiltInDartLibrary(Uri uri) {
    return uri.scheme == 'dart';
  }

  /// Check if name is internal (starts with _ but not __)
  @protected
  bool isInternal(String name) {
    final sepIndex = name.lastIndexOf(RegExp(r'[/\\:]'));
    final segment = sepIndex >= 0 ? name.substring(sepIndex + 1) : name;
    return segment.startsWith('_') && !segment.startsWith('__');
  }

  /// Check if name is synthetic
  @protected
  bool isSynthetic(String name) => name.startsWith("__") || name.contains("&");

  /// Check if mirror type name is synthetic (X0, X1, etc.)
  @protected
  bool isMirrorSyntheticType(String name) {
    return RegExp(r'^X\d+$').hasMatch(name);
  }

  /// Get variance from type parameter
  @protected
  TypeVariance getVarianceFromTypeParameter(TypeParameterElement? analyzerParam, mirrors.TypeVariableMirror? mirrorParam) {
    if (analyzerParam != null) {
      final name = analyzerParam.name;
      if (name?.startsWith('in ') ?? false) return TypeVariance.contravariant;
      if (name?.startsWith('out ') ?? false) return TypeVariance.covariant;
    }
    return TypeVariance.invariant;
  }

  /// Get variance from type parameter element
  @protected
  TypeVariance getVariance(TypeParameterElement? tp) {
    if (tp?.name?.startsWith('in ') ?? false) return TypeVariance.contravariant;
    if (tp?.name?.startsWith('out ') ?? false) return TypeVariance.covariant;
    return TypeVariance.invariant;
  }

  /// Infer variance from DartType context
  @protected
  TypeVariance inferVarianceFromContext(TypeParameterType dartType) {
    return TypeVariance.invariant;
  }

  /// Infer variance from Mirror context
  @protected
  TypeVariance inferVarianceFromMirror(mirrors.TypeVariableMirror typeMirror) {
    return TypeVariance.invariant;
  }

  /// Read source code with caching
  @protected
  Future<String> readSourceCode(Uri uri) async {
    try {
      if (sourceCache.containsKey(uri.toString())) {
        return sourceCache[uri.toString()]!;
      }

      final filePath = (await resolveUri(uri) ?? uri).toFilePath();
      String fileContent = await File(filePath).readAsString();
      sourceCache[uri.toString()] = fileContent;
      return RuntimeUtils.stripComments(fileContent);
    } catch (_) {
      return "";
    }
  }

  /// Get package URI for a type
  @protected
  String getPackageUriForType(String typeName, Type actualType) {
    if (isPrimitiveType(actualType) || 
        actualType == List || actualType == Map || actualType == Set || 
        actualType == Iterable || actualType == Future || actualType == Stream) {
      return 'dart:core';
    }
    
    if (actualType == Future || actualType == Stream) {
      return 'dart:async';
    }
    
    return 'dart:core';
  }

  /// Create default package
  @protected
  Package createDefaultPackage(String name) {
    return PackageImplementation(
      name: name,
      version: '0.0.0',
      languageVersion: null,
      isRootPackage: false,
      rootUri: null,
      filePath: null,
    );
  }

  /// Create built-in package for Dart SDK
  @protected
  Package createBuiltInPackage() {
    return PackageImplementation(
      name: Constant.DART_PACKAGE_NAME,
      version: packageCache.values.where((v) => v.getIsRootPackage()).firstOrNull?.getLanguageVersion() ?? '3.0',
      languageVersion: packageCache.values.where((v) => v.getIsRootPackage()).firstOrNull?.getLanguageVersion() ?? '3.0',
      isRootPackage: false,
      rootUri: 'dart:core',
      filePath: null,
    );
  }

  /// Split record content string into components
  @protected
  List<String> splitRecordContent(String content) {
    final parts = <String>[];
    int balance = 0;
    int start = 0;
    
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '<' || char == '(' || char == '{') {
        balance++;
      } else if (char == '>' || char == ')' || char == '}') {
        balance--;
      } else if (char == ',' && balance == 0) {
        parts.add(content.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(content.substring(start));
    return parts;
  }

  /// Check class modifiers from source code
  @protected
  bool isSealedClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bsealed\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  @protected
  bool isBaseClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bbase\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  @protected
  bool isFinalClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bfinal\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  @protected
  bool isInterfaceClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\binterface\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  @protected
  bool isMixinClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bmixin\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  @protected
  bool isLateField(String? sourceCode, String fieldName) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\blate\s+[^;]*\b' + RegExp.escape(fieldName) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  @protected
  bool isNullable({FieldElement? fieldElement, String? sourceCode, required String fieldName}) {
    if (sourceCode == null) return false;
    final code = RuntimeUtils.stripComments(sourceCode);

    final List<RegExp> patterns = [
      RegExp(
        r'\b(?:late\s+)?(?:static\s+)?(?:final\s+|const\s+)?[A-Za-z_$][A-Za-z0-9_$<>\?,\s]*\?\s+' +
            RegExp.escape(fieldName) +
            r'\b',
        multiLine: true,
      ),
      RegExp(
        r'\b[A-Za-z_$][A-Za-z0-9_$<>\?,\s]*\?\s+' + RegExp.escape(fieldName) + r'\b',
        multiLine: true,
      ),
      RegExp(
        r'[(,][^)]{0,120}\b[A-Za-z_$][A-Za-z0-9_$<>\?,\s]*\?\s*(?:this\.)?' +
            RegExp.escape(fieldName) +
            r'\b',
        multiLine: true,
      ),
    ];

    return patterns.any((p) => p.hasMatch(code));
  }

  /// Try to get original type from class mirror
  @protected
  Future<Type> tryAndGetOriginalType(mirrors.ClassMirror mirror, Package package) async {
    if (mirror.isOriginalDeclaration) {
      Type type = mirror.hasReflectedType ? mirror.reflectedType : mirror.runtimeType;
      String name = mirrors.MirrorSystem.getName(mirror.simpleName);
      
      if (GenericTypeParser.shouldCheckGeneric(type)) {
        final annotations = await extractAnnotations(mirror.metadata, package);
        final resolvedType = await resolveTypeFromGenericAnnotation(annotations, name);
        if (resolvedType != null) {
          type = resolvedType;
        }
      }
      
      return type;
    }
    
    return mirror.hasReflectedType ? mirror.reflectedType : mirror.runtimeType;
  }

  /// Resolve type from @Generic annotation
  @protected
  Future<Type?> resolveTypeFromGenericAnnotation(List<AnnotationDeclaration> annotations, String name) async {
    if (annotations.where((a) => a.getLinkDeclaration().getType() == Generic).length > 1) {
      onWarning("Multiple @Generic annotations found for $name. Jetleaf will resolve to the first one it can get.");
    }

    final genericAnnotation = annotations.where((a) => a.getLinkDeclaration().getType() == Generic).firstOrNull;
    
    if (genericAnnotation != null) {
      final typeField = genericAnnotation.getField("_type");
      return typeField?.getValue() as Type?;
    }
    
    return null;
  }

  /// Extract annotations - to be implemented by subclasses
  @protected
  Future<List<AnnotationDeclaration>> extractAnnotations(List<mirrors.InstanceMirror> metadata, Package package);
}