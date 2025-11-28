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
import '../utils/dart_type_resolver.dart';
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

  /// Cache of analyzer library elements by URI
  final Map<String, LibraryElement> libraryElementCache = {};

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
  bool isPrimitiveType(Type type) => type == int || type == double || type == bool || type == String || type == num;

  /// Check if type is List
  @protected
  bool isListType(Type type) => type.toString().startsWith('List<') || type == List;

  /// Check if type is Map
  @protected
  bool isMapType(Type type) => type.toString().startsWith('Map<') || type == Map;

  /// Check if type is Record
  @protected
  bool isRecordType(Type type) => type.toString().startsWith('(') && type.toString().endsWith(')');

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
  String buildQualifiedName(String typeName, String libraryUri) => '$libraryUri.$typeName'.replaceAll("..", '.');

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
  bool isBuiltInDartLibrary(Uri uri) => uri.scheme == 'dart';

  /// Check if name is internal (starts with _ but not __)
  @protected
  bool isInternal(String name) {
    // Find the last slash or colon
    final sepIndex = name.lastIndexOf(RegExp(r'[/\\:]'));
    final segment = sepIndex >= 0 ? name.substring(sepIndex + 1) : name;

    // Internal if segment starts with _ but not __
    return segment.startsWith('_') && !segment.startsWith('__');
  }

  /// Check if name is synthetic
  @protected
  bool isSynthetic(String name) => name.startsWith("__") || name.contains("&");

  /// Check if mirror type name is synthetic (X0, X1, etc.)
  @protected
  bool isMirrorSyntheticType(String name) {
    // Match X followed by digits (X0, X1, X2, etc.)
    return RegExp(r'^X\d+$').hasMatch(name);
  }

  /// Get variance from type parameter
  @protected
  TypeVariance getVarianceFromTypeParameter(TypeParameterElement? analyzerParam, mirrors.TypeVariableMirror? mirrorParam) {
    // Check analyzer parameter first
    if (analyzerParam != null) {
      // In current Dart, variance is not explicitly supported yet
      // This is future-proofing for when it becomes available
      final name = analyzerParam.name;
      if (name?.startsWith('in ') ?? false) return TypeVariance.contravariant;
      if (name?.startsWith('out ') ?? false) return TypeVariance.covariant;
    }
    
    // Default to invariant
    return TypeVariance.invariant;
  }

  /// Get variance from type parameter element
  @protected
  TypeVariance getVariance(TypeParameterElement? tp) {
    // Dart doesn't have explicit variance annotations yet, but we can infer
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
    // Check if it's a built-in Dart type
    if (isPrimitiveType(actualType) || 
        actualType == List || actualType == Map || actualType == Set || 
        actualType == Iterable || actualType == Future || actualType == Stream) {
      return 'dart:core';
    }
    
    // For async types
    if (actualType == Future || actualType == Stream) {
      return 'dart:async';
    }
    
    // Default fallback
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
    // if (fieldElement != null) {
    //   final DartType t = fieldElement.type;
    //   return t.nullabilitySuffix == NullabilitySuffix.question;
    // }

    // if (typeNode != null) {
    //   if (typeNode is ast.NamedType) {
    //     final DartType? resolved = typeNode.type;
    //     if (resolved != null) {
    //       return resolved.nullabilitySuffix == NullabilitySuffix.question;
    //     }
    //   }

    //   // fallback: check if the annotation text contains '?'
    //   return typeNode.toSource().contains('?');
    // }

    if (sourceCode == null) return false;
    final code = RuntimeUtils.stripComments(sourceCode);

    // Patterns WITHOUT inline (?m) flags; use multiLine: true below.
    final List<RegExp> patterns = [
      // field declarations: optional 'late/static/final/const', then a type that contains '?', then the name
      RegExp(
        r'\b(?:late\s+)?(?:static\s+)?(?:final\s+|const\s+)?[A-Za-z_$][A-Za-z0-9_$<>\?,\s]*\?\s+' +
            RegExp.escape(fieldName) +
            r'\b',
        multiLine: true,
      ),

      // constructor or parameter with explicit nullable type: 'Foo? name' (positional or named)
      RegExp(
        r'\b[A-Za-z_$][A-Za-z0-9_$<>\?,\s]*\?\s+' + RegExp.escape(fieldName) + r'\b',
        multiLine: true,
      ),

      // heuristic for 'this.name' in parameter lists where the param token includes a '?'
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
      
      if(GenericTypeParser.shouldCheckGeneric(type)) {
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
    if(annotations.where((a) => a.getLinkDeclaration().getType() == Generic).length > 1) {
      onWarning("Multiple @Generic annotations found for $name. Jetleaf will resolve to the first one it can get.");
    }

    final genericAnnotation = annotations.where((a) => a.getLinkDeclaration().getType() == Generic).firstOrNull;
    
    if (genericAnnotation != null) {
      final typeField = genericAnnotation.getField("_type");
      return typeField?.getValue() as Type?;
    }
    
    return null;
  }

  /// Get package URI from mirror
  @protected
  Future<String> getPkgUri(mirrors.TypeMirror mirror, String packageName, String libraryUri) async {
    final realClassUri = await findRealClassUriFromMirror(mirror, packageName);
    return mirror.location?.sourceUri.toString() ?? realClassUri ?? libraryUri;
  }

  /// Find the real class URI by searching through all libraries
  @protected
  Future<String?> findRealClassUri(String className, String? hintUri) async {
    // First try the hint URI if available
    if (hintUri != null) {
      final libraryElement = await getLibraryElement(Uri.parse(hintUri));
      if (libraryElement?.getClass(className) != null ||
          libraryElement?.getMixin(className) != null ||
          libraryElement?.getEnum(className) != null) {
        return hintUri;
      }
    }

    // Search through all cached libraries
    for (final entry in libraryElementCache.entries) {
      final libraryElement = entry.value;
      if (libraryElement.getClass(className) != null ||
          libraryElement.getMixin(className) != null ||
          libraryElement.getEnum(className) != null) {
        return entry.key;
      }
    }

    // Search through mirror system
    for (final libraryMirror in libraries) {
      for (final declaration in libraryMirror.declarations.values) {
        if (declaration is mirrors.ClassMirror) {
          final mirrorClassName = mirrors.MirrorSystem.getName(declaration.simpleName);
          if (mirrorClassName == className) {
            return libraryMirror.uri.toString();
          }
        }
      }
    }

    return null;
  }

  /// Find the real class URI from mirror
  @protected
  Future<String?> findRealClassUriFromMirror(mirrors.TypeMirror typeMirror, String? packageName) async {
    // 1) If this is a class mirror, the declaring library is the authoritative source.
    try {
      if (typeMirror is mirrors.ClassMirror) {
        final lib = typeMirror.owner as mirrors.LibraryMirror?;
        if (lib != null) {
          return lib.uri.toString();
        }
        // If parameterized originalDeclaration exists, prefer its owner.
        final orig = typeMirror.originalDeclaration;
        if (orig is mirrors.ClassMirror) {
          final origLib = orig.owner as mirrors.LibraryMirror?;
          if (origLib != null) {
            return origLib.uri.toString();
          }
        }
      }
    } catch (_) {
      // ignore and fall back to search
    }

    // 2) Fall back to scanning loaded libraries (mirrorSystem.libraries). Prefer root package.
    final candidates = <String>[];
    final nameToMatch = mirrors.MirrorSystem.getName(typeMirror.simpleName);

    for (final lib in libraries) {
      final decl = lib.declarations[typeMirror.simpleName];
      if (decl is mirrors.ClassMirror) {
        // quick direct declaration match
        candidates.add(lib.uri.toString());
        continue;
      }

      // If not directly declared under that symbol, try a best-effort name match:
      for (final d in lib.declarations.values) {
        if (d is mirrors.ClassMirror) {
          final dName = mirrors.MirrorSystem.getName(d.simpleName);
          if (dName == nameToMatch) {
            candidates.add(lib.uri.toString());
            break;
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    // 3) Prefer candidate in root package, then non-sdk (not dart:) libraries, else first candidate.
    if (packageName != null) {
      final pkgPrefix = 'package:$packageName/';
      final byRoot = candidates.firstWhere(
        (uri) => uri.startsWith(pkgPrefix),
        orElse: () => '',
      );
      if (byRoot.isNotEmpty) return byRoot;
    }

    // prefer non-dart: libraries (user or package libs)
    final nonSdk = candidates.firstWhere((u) => !u.startsWith('dart:'), orElse: () => '');
    if (nonSdk.isNotEmpty) return nonSdk;

    // last fallback: first candidate
    return candidates.first;
  }

  /// Find runtime type from DartType
  @protected
  Future<Type> findRuntimeTypeFromDartType(DartType dartType, String libraryUri, Package package) async {
    final cacheKey = '${dartType.element?.name}_${dartType.element?.library?.uri}_${dartType.getDisplayString()}';
    if (dartTypeToTypeCache.containsKey(cacheKey)) {
      return dartTypeToTypeCache[cacheKey]!;
    }

    // Handle built-in types first
    if (dartType.isDartCoreBool) return bool;
    if (dartType.isDartCoreDouble) return double;
    if (dartType.isDartCoreInt) return int;
    if (dartType.isDartCoreNum) return num;
    if (dartType.isDartCoreString) return String;
    if (dartType.isDartCoreList) return List;
    if (dartType.isDartCoreMap) return Map;
    if (dartType.isDartCoreSet) return Set;
    if (dartType.isDartCoreIterable) return Iterable;
    if (dartType.isDartAsyncFuture) return Future;
    if (dartType.isDartAsyncStream) return Stream;
    if (dartType is DynamicType) return dynamic;
    if (dartType is VoidType) return VoidType;

    // Try to resolve from dart type resolver
    final elementName = dartType.element?.name;
    final libraryUri = dartType.element?.library?.uri.toString();
    
    if (elementName != null && libraryUri != null) {
      final resolvedType = resolvePublicDartType(libraryUri, elementName);
      if (resolvedType != null) {
        dartTypeToTypeCache[cacheKey] = resolvedType;
        return resolvedType;
      }
    }

    // Try to find the type in our mirror system
    if (elementName != null) {
      // Look through all libraries to find a matching class
      for (final libraryMirror in libraries) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName) {
              try {
                final runtimeType = await tryAndGetOriginalType(declaration, package);
                dartTypeToTypeCache[cacheKey] = runtimeType;
                return runtimeType;
              } catch (e) {
                // Continue searching
              }
            }
          }
        }
      }
    }

    Type fallbackType = Object;
    if (dartType.element != null) {
      // Try to create a synthetic type based on the element
      try {
        fallbackType = dartType.element!.runtimeType;
      } catch (e) {
        fallbackType = Object;
      }
    }
    
    dartTypeToTypeCache[cacheKey] = fallbackType;
    return fallbackType;
  }

  /// Find base runtime type from DartType (without type parameters)
  @protected
  Future<Type> findBaseRuntimeTypeFromDartType(DartType dartType, String libraryUri, Package package) async {
    // Handle built-in types
    if (dartType.isDartCoreBool) return bool;
    if (dartType.isDartCoreDouble) return double;
    if (dartType.isDartCoreInt) return int;
    if (dartType.isDartCoreNum) return num;
    if (dartType.isDartCoreString) return String;
    if (dartType.isDartCoreList) return List;
    if (dartType.isDartCoreMap) return Map;
    if (dartType.isDartCoreSet) return Set;
    if (dartType.isDartCoreIterable) return Iterable;
    if (dartType.isDartAsyncFuture) return Future;
    if (dartType.isDartAsyncStream) return Stream;
    if (dartType is DynamicType) return dynamic;
    if (dartType is VoidType) return VoidType;

    // For parameterized types, find the base class
    final elementName = dartType.element?.name;
    if (elementName != null) {
      // Look through all libraries to find the base class
      for (final libraryMirror in libraries) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName) {
              try {
                return await tryAndGetOriginalType(declaration, package);
              } catch (e) {
                // Continue searching
              }
            }
          }
        }
      }
    }

    // Fallback to the actual runtime type
    return await findRuntimeTypeFromDartType(dartType, libraryUri, package);
  }

  /// Extract annotations - to be implemented by subclasses
  @protected
  Future<List<AnnotationDeclaration>> extractAnnotations(List<mirrors.InstanceMirror> metadata, Package package);

  /// Get library element from analyzer - to be implemented by subclasses
  @protected
  Future<LibraryElement?> getLibraryElement(Uri uri);

  /// List of library mirrors to process
  List<mirrors.LibraryMirror> get libraries;
}