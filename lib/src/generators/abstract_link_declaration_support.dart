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
import '../utils/dart_type_resolver.dart';
import '../utils/generic_type_parser.dart';
import 'abstract_type_support.dart';

/// Support class for generating LinkDeclaration objects.
/// 
/// Handles creation of LinkDeclarations from both analyzer DartTypes and mirrors,
/// with cycle detection and caching for performance.
abstract class AbstractLinkDeclarationSupport extends AbstractTypeSupport {
  /// Cache of analyzer library elements by URI
  final Map<String, LibraryElement> libraryElementCache = {};

  /// Cache for preventing infinite recursion in LinkDeclaration generation
  final Set<String> linkGenerationInProgress = {};
  final Map<String, LinkDeclaration?> linkDeclarationCache = {};

  AbstractLinkDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Clear processing caches for a new library
  @protected
  void clearProcessingCaches() {
    linkGenerationInProgress.clear();
    linkDeclarationCache.clear();
  }

  /// Generate LinkDeclaration from DartType with cycle detection
  @protected
  Future<LinkDeclaration?> generateLinkDeclarationFromDartType(DartType dartType, Package package, String libraryUri) async {
    final element = dartType.element;
    if (element == null) return null;

    final typeKey = '${element.library?.uri}_${element.name}_${dartType.getDisplayString()}';
    
    if (linkGenerationInProgress.contains(typeKey)) {
      return null;
    }
    
    if (linkDeclarationCache.containsKey(typeKey)) {
      return linkDeclarationCache[typeKey];
    }

    linkGenerationInProgress.add(typeKey);
    
    try {
      final realClassUri = await findRealClassUri(element.name!, element.library?.uri.toString());
      final actualRuntimeType = await findRuntimeTypeFromDartType(dartType, libraryUri, package);
      final baseRuntimeType = await findBaseRuntimeTypeFromDartType(dartType, libraryUri, package);
      final realPackageUri = realClassUri ?? element.library?.uri.toString() ?? libraryUri;

      final typeArguments = <LinkDeclaration>[];
      if (dartType is ParameterizedType && dartType.typeArguments.isNotEmpty) {
        for (final arg in dartType.typeArguments) {
          final argKey = '${arg.element?.library?.uri}_${arg.element?.name}_${arg.getDisplayString()}';
          if (!linkGenerationInProgress.contains(argKey)) {
            final argLink = await generateLinkDeclarationFromDartType(arg, package, libraryUri);
            if (argLink != null) {
              typeArguments.add(argLink);
            }
          }
        }
      }

      TypeVariance variance = TypeVariance.invariant;
      LinkDeclaration? upperBound;
      
      if (dartType is TypeParameterType) {
        final bound = dartType.bound;
        if (!bound.isDartCoreObject) {
          final boundKey = '${bound.element?.library?.uri}_${bound.element?.name}_${bound.getDisplayString()}';
          if (!linkGenerationInProgress.contains(boundKey)) {
            upperBound = await generateLinkDeclarationFromDartType(bound, package, libraryUri);
          }
        }
        variance = inferVarianceFromContext(dartType);
      }

      final result = StandardLinkDeclaration(
        name: dartType.getDisplayString(),
        type: actualRuntimeType,
        pointerType: baseRuntimeType,
        typeArguments: typeArguments,
        qualifiedName: buildQualifiedName(dartType.getDisplayString(), realPackageUri),
        canonicalUri: Uri.tryParse(realPackageUri),
        referenceUri: Uri.tryParse(libraryUri),
        variance: variance,
        upperBound: upperBound,
        isPublic: !isInternal(dartType.getDisplayString()),
        isSynthetic: isSynthetic(dartType.getDisplayString()),
      );

      linkDeclarationCache[typeKey] = result;
      return result;
    } finally {
      linkGenerationInProgress.remove(typeKey);
    }
  }

  /// Generate LinkDeclaration from Mirror with cycle detection
  @protected
  Future<LinkDeclaration?> generateLinkDeclarationFromMirror(mirrors.TypeMirror typeMirror, Package package, String libraryUri) async {
    String typeName = mirrors.MirrorSystem.getName(typeMirror.simpleName);
  
    Type runtimeType;
    try {
      runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;
    } catch (e) {
      runtimeType = typeMirror.runtimeType;
    }

    if (GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(typeMirror.metadata, package);
      Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, typeName);
      resolvedType ??= resolvePublicDartType(libraryUri, typeName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final typeKey = 'mirror_${typeName}_${runtimeType}_${typeMirror.hashCode}';
  
    if (linkGenerationInProgress.contains(typeKey)) {
      return null;
    }
  
    if (linkDeclarationCache.containsKey(typeKey)) {
      return linkDeclarationCache[typeKey];
    }

    linkGenerationInProgress.add(typeKey);

    final realPackageUri = typeMirror.location?.sourceUri.toString();
    if (realPackageUri == null) {
      return null;
    }
  
    try {
      Type actualRuntimeType;
      Type baseRuntimeType;
      
      try {
        if (typeMirror.hasReflectedType) {
          actualRuntimeType = typeMirror.reflectedType;
        } else {
          actualRuntimeType = typeMirror.runtimeType;
        }

        if (GenericTypeParser.shouldCheckGeneric(actualRuntimeType)) {
          final annotations = await extractAnnotations(typeMirror.metadata, package);
          Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, typeName);
          resolvedType ??= resolvePublicDartType(libraryUri, typeName);
          if (resolvedType != null) {
            actualRuntimeType = resolvedType;
          }
        }
        
        if (typeMirror is mirrors.ClassMirror && typeMirror.originalDeclaration != typeMirror) {
          baseRuntimeType = typeMirror.originalDeclaration.hasReflectedType 
              ? typeMirror.originalDeclaration.reflectedType 
              : typeMirror.originalDeclaration.runtimeType;

          if (GenericTypeParser.shouldCheckGeneric(baseRuntimeType)) {
            final annotations = await extractAnnotations(typeMirror.originalDeclaration.metadata, package);
            Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, typeName);
            resolvedType ??= resolvePublicDartType(libraryUri, typeName);
            if (resolvedType != null) {
              baseRuntimeType = resolvedType;
            }
          }
        } else {
          baseRuntimeType = actualRuntimeType;
        }
      } catch (e) {
        actualRuntimeType = typeMirror.runtimeType;
        baseRuntimeType = typeMirror.runtimeType;
      }

      final typeArguments = <LinkDeclaration>[];
      if (typeMirror is mirrors.ClassMirror && typeMirror.typeArguments.isNotEmpty) {
        for (final arg in typeMirror.typeArguments) {
          final argName = mirrors.MirrorSystem.getName(arg.simpleName);
          final argKey = 'mirror_${argName}_${arg.hashCode}';
          if (!linkGenerationInProgress.contains(argKey)) {
            final argLink = await generateLinkDeclarationFromMirror(arg, package, libraryUri);
            if (argLink != null) {
              typeArguments.add(argLink);
            }
          }
        }
      }

      TypeVariance variance = TypeVariance.invariant;
      LinkDeclaration? upperBound;
    
      if (typeMirror is mirrors.TypeVariableMirror) {
        if (typeMirror.upperBound != typeMirror.owner && typeMirror.upperBound.runtimeType.toString() != 'dynamic') {
          final boundName = mirrors.MirrorSystem.getName(typeMirror.upperBound.simpleName);
          final boundKey = 'mirror_${boundName}_${typeMirror.upperBound.hashCode}';
          if (!linkGenerationInProgress.contains(boundKey)) {
            upperBound = await generateLinkDeclarationFromMirror(typeMirror.upperBound, package, libraryUri);
          }
        }
        variance = inferVarianceFromMirror(typeMirror);
      }

      final result = StandardLinkDeclaration(
        name: typeName,
        type: actualRuntimeType,
        pointerType: baseRuntimeType,
        typeArguments: typeArguments,
        qualifiedName: buildQualifiedName(typeName, realPackageUri),
        canonicalUri: Uri.tryParse(realPackageUri),
        referenceUri: Uri.tryParse(libraryUri),
        variance: variance,
        upperBound: upperBound,
        isPublic: !isInternal(typeName),
        isSynthetic: isSynthetic(typeName),
      );

      linkDeclarationCache[typeKey] = result;
      return result;
    } finally {
      linkGenerationInProgress.remove(typeKey);
    }
  }

  /// Get link declaration with fallback
  @protected
  Future<LinkDeclaration> getLinkDeclaration(mirrors.TypeMirror typeMirror, Package package, String libraryUri, [DartType? dartType]) async {
    LinkDeclaration? result;
    if (dartType != null) {
      result = await generateLinkDeclarationFromDartType(dartType, package, libraryUri);
    } else {
      result = await generateLinkDeclarationFromMirror(typeMirror, package, libraryUri);
    }
    
    return result ?? await generateLinkDeclarationFromMirror(typeMirror, package, libraryUri) ?? StandardLinkDeclaration(
      name: 'Object',
      type: Object,
      pointerType: Object,
      qualifiedName: buildQualifiedName('Object', 'dart:core'),
      isPublic: true,
      isSynthetic: false,
    );
  }

  /// Extract type arguments as LinkDeclarations with cycle detection
  @protected
  Future<List<LinkDeclaration>> extractTypeArgumentsAsLinks(
    List<mirrors.TypeVariableMirror> mirrorTypeVars, 
    List<TypeParameterElement>? analyzerTypeParams, 
    Package package, 
    String libraryUri
  ) async {
    final typeArgs = <LinkDeclaration>[];
  
    for (int i = 0; i < mirrorTypeVars.length; i++) {
      final mirrorTypeVar = mirrorTypeVars[i];
      final analyzerTypeParam = (analyzerTypeParams != null && i < analyzerTypeParams.length)
          ? analyzerTypeParams[i]
          : null;
    
      String typeVarName = mirrors.MirrorSystem.getName(mirrorTypeVar.simpleName);
      if (isMirrorSyntheticType(typeVarName)) {
        typeVarName = "Object";
      }
      final typeKey = 'typevar_${typeVarName}_${libraryUri}_$i';
    
      if (linkGenerationInProgress.contains(typeKey)) {
        continue;
      }
    
      linkGenerationInProgress.add(typeKey);
    
      try {
        LinkDeclaration? upperBound;
        if (mirrorTypeVar.upperBound != mirrorTypeVar.owner && mirrorTypeVar.upperBound.runtimeType.toString() != 'dynamic') {
          final boundName = mirrors.MirrorSystem.getName(mirrorTypeVar.upperBound.simpleName);
          final boundKey = 'mirror_${boundName}_${mirrorTypeVar.upperBound.runtimeType}_${mirrorTypeVar.upperBound.hashCode}';
          if (!linkGenerationInProgress.contains(boundKey)) {
            upperBound = await generateLinkDeclarationFromMirror(mirrorTypeVar.upperBound, package, libraryUri);
          }
        } else if (analyzerTypeParam?.bound != null) {
          final boundKey = '${analyzerTypeParam!.bound!.element?.library?.uri}_${analyzerTypeParam.bound!.element?.name}_${analyzerTypeParam.bound!.getDisplayString()}';
          if (!linkGenerationInProgress.contains(boundKey)) {
            upperBound = await generateLinkDeclarationFromDartType(analyzerTypeParam.bound!, package, libraryUri);
          }
        }
      
        final variance = getVarianceFromTypeParameter(analyzerTypeParam, mirrorTypeVar);
      
        final typeArgLink = StandardLinkDeclaration(
          name: typeVarName,
          type: Object,
          pointerType: Object,
          typeArguments: [],
          qualifiedName: buildQualifiedName(typeVarName, libraryUri),
          canonicalUri: Uri.tryParse(libraryUri),
          referenceUri: Uri.tryParse(libraryUri),
          variance: variance,
          upperBound: upperBound,
          isPublic: !isInternal(typeVarName),
          isSynthetic: isSynthetic(typeVarName),
        );
      
        typeArgs.add(typeArgLink);
      } finally {
        linkGenerationInProgress.remove(typeKey);
      }
    }
  
    return typeArgs;
  }

  /// Extract supertype as LinkDeclaration
  @protected
  Future<LinkDeclaration?> extractSupertypeAsLink(mirrors.ClassMirror classMirror, InterfaceElement? classElement, Package package, String libraryUri) async {
    if (classElement?.supertype != null) {
      return await generateLinkDeclarationFromDartType(classElement!.supertype!, package, libraryUri);
    }

    if (classMirror.superclass != null) {
      return await generateLinkDeclarationFromMirror(classMirror.superclass!, package, libraryUri);
    }

    return null;
  }

  /// Extract interfaces as LinkDeclarations
  @protected
  Future<List<LinkDeclaration>> extractInterfacesAsLink(mirrors.ClassMirror classMirror, InterfaceElement? classElement, Package package, String libraryUri) async {
    final interfaces = <LinkDeclaration>[];

    if (classElement != null) {
      for (final interfaceType in classElement.interfaces) {
        final linked = await generateLinkDeclarationFromDartType(interfaceType, package, libraryUri);
        if (linked != null) {
          interfaces.add(linked);
        }
      }
    } else {
      for (final interfaceMirror in classMirror.superinterfaces) {
        final linked = await generateLinkDeclarationFromMirror(interfaceMirror, package, libraryUri);
        if (linked != null) {
          interfaces.add(linked);
        }
      }
    }

    return interfaces;
  }

  /// Extract mixins as LinkDeclarations
  @protected
  Future<List<LinkDeclaration>> extractMixinsAsLink(mirrors.ClassMirror classMirror, InterfaceElement? classElement, Package package, String libraryUri) async {
    final mixins = <LinkDeclaration>[];

    if (classElement != null) {
      for (final mixinType in classElement.mixins) {
        final linked = await generateLinkDeclarationFromDartType(mixinType, package, libraryUri);
        if (linked != null) {
          mixins.add(linked);
        }
      }
    }

    return mixins;
  }

  /// Extract mixin constraints as LinkDeclarations
  @protected
  Future<List<LinkDeclaration>> extractMixinConstraintsAsLink(mirrors.ClassMirror mixinMirror, MixinElement? mixinElement, Package package, String libraryUri) async {
    final constraints = <LinkDeclaration>[];

    if (mixinElement != null) {
      for (final constraintType in mixinElement.superclassConstraints) {
        final linked = await generateLinkDeclarationFromDartType(constraintType, package, libraryUri);
        if (linked != null) {
          constraints.add(linked);
        }
      }
    }

    return constraints;
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
    if (hintUri != null) {
      final libraryElement = await getLibraryElement(Uri.parse(hintUri));
      if (libraryElement?.getClass(className) != null ||
          libraryElement?.getMixin(className) != null ||
          libraryElement?.getEnum(className) != null) {
        return hintUri;
      }
    }

    for (final entry in libraryElementCache.entries) {
      final libraryElement = entry.value;
      if (libraryElement.getClass(className) != null ||
          libraryElement.getMixin(className) != null ||
          libraryElement.getEnum(className) != null) {
        return entry.key;
      }
    }

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
    try {
      if (typeMirror is mirrors.ClassMirror) {
        final lib = typeMirror.owner as mirrors.LibraryMirror?;
        if (lib != null) {
          return lib.uri.toString();
        }
        final orig = typeMirror.originalDeclaration;
        if (orig is mirrors.ClassMirror) {
          final origLib = orig.owner as mirrors.LibraryMirror?;
          if (origLib != null) {
            return origLib.uri.toString();
          }
        }
      }
    } catch (_) {}

    final candidates = <String>[];
    final nameToMatch = mirrors.MirrorSystem.getName(typeMirror.simpleName);

    for (final lib in libraries) {
      final decl = lib.declarations[typeMirror.simpleName];
      if (decl is mirrors.ClassMirror) {
        candidates.add(lib.uri.toString());
        continue;
      }

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

    if (packageName != null) {
      final pkgPrefix = 'package:$packageName/';
      final byRoot = candidates.firstWhere(
        (uri) => uri.startsWith(pkgPrefix),
        orElse: () => '',
      );
      if (byRoot.isNotEmpty) return byRoot;
    }

    final nonSdk = candidates.firstWhere((u) => !u.startsWith('dart:'), orElse: () => '');
    if (nonSdk.isNotEmpty) return nonSdk;

    return candidates.first;
  }

  /// Find runtime type from DartType
  @protected
  Future<Type> findRuntimeTypeFromDartType(DartType dartType, String libraryUri, Package package) async {
    final cacheKey = '${dartType.element?.name}_${dartType.element?.library?.uri}_${dartType.getDisplayString()}';
    if (dartTypeToTypeCache.containsKey(cacheKey)) {
      return dartTypeToTypeCache[cacheKey]!;
    }

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

    final elementName = dartType.element?.name;
    final elementLibraryUri = dartType.element?.library?.uri.toString();
    
    if (elementName != null && elementLibraryUri != null) {
      final resolvedType = resolvePublicDartType(elementLibraryUri, elementName);
      if (resolvedType != null) {
        dartTypeToTypeCache[cacheKey] = resolvedType;
        return resolvedType;
      }
    }

    if (elementName != null) {
      for (final libraryMirror in libraries) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName) {
              try {
                final runtimeType = await tryAndGetOriginalType(declaration, package);
                dartTypeToTypeCache[cacheKey] = runtimeType;
                return runtimeType;
              } catch (_) {}
            }
          }
        }
      }
    }

    Type fallbackType = Object;
    if (dartType.element != null) {
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

    final elementName = dartType.element?.name;
    if (elementName != null) {
      for (final libraryMirror in libraries) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName) {
              try {
                return await tryAndGetOriginalType(declaration, package);
              } catch (_) {}
            }
          }
        }
      }
    }

    return await findRuntimeTypeFromDartType(dartType, libraryUri, package);
  }

  /// Get library element from analyzer - to be implemented by subclasses
  @protected
  Future<LibraryElement?> getLibraryElement(Uri uri);

  /// List of library mirrors to process
  List<mirrors.LibraryMirror> get libraries;
}