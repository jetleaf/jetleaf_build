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
import '../generators/abstract_type_support.dart';

/// Support class for generating LinkDeclaration objects.
/// 
/// Handles creation of LinkDeclarations from both analyzer DartTypes and mirrors,
/// with cycle detection and caching for performance.
abstract class AbstractLinkDeclarationSupport extends AbstractTypeSupport {
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

    // Create a unique key for this type to detect cycles
    final typeKey = '${element.library?.uri}_${element.name}_${dartType.getDisplayString()}';
    
    // Check if we're already processing this type (cycle detection)
    if (linkGenerationInProgress.contains(typeKey)) {
      return null; // Break the cycle
    }
    
    // Check cache first
    if (linkDeclarationCache.containsKey(typeKey)) {
      return linkDeclarationCache[typeKey];
    }

    // Mark as in progress
    linkGenerationInProgress.add(typeKey);
    
    try {
      // Find the real class in the runtime system to get the actual package URI
      final realClassUri = await findRealClassUri(element.name!, element.library?.uri.toString());

      // Get the actual runtime type for this DartType
      final actualRuntimeType = await findRuntimeTypeFromDartType(dartType, libraryUri, package);
      
      // Get the base type (without type parameters)
      final baseRuntimeType = await findBaseRuntimeTypeFromDartType(dartType, libraryUri, package);
      final realPackageUri = realClassUri ?? element.library?.uri.toString() ?? libraryUri;

      // Get type arguments from the implementing class (with cycle protection)
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

      // Determine variance and upper bound for type parameters (with cycle protection)
      TypeVariance variance = TypeVariance.invariant;
      LinkDeclaration? upperBound;
      
      if (dartType is TypeParameterType) {
        // Handle type parameter variance and bounds
        final bound = dartType.bound;
        if (!bound.isDartCoreObject) {
          final boundKey = '${bound.element?.library?.uri}_${bound.element?.name}_${bound.getDisplayString()}';
          if (!linkGenerationInProgress.contains(boundKey)) {
            upperBound = await generateLinkDeclarationFromDartType(bound, package, libraryUri);
          }
        }
      
        // Infer variance from usage context (simplified)
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

      // Cache the result
      linkDeclarationCache[typeKey] = result;
      return result;
    } finally {
      // Always remove from in-progress set
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

    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await extractAnnotations(typeMirror.metadata, package);
      Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, typeName);
      resolvedType ??= resolvePublicDartType(libraryUri, typeName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    // Create a unique key for this type to detect cycles
    final typeKey = 'mirror_${typeName}_${runtimeType}_${typeMirror.hashCode}';
  
    // Check if we're already processing this type (cycle detection)
    if (linkGenerationInProgress.contains(typeKey)) {
      return null; // Break the cycle
    }
  
    // Check cache first
    if (linkDeclarationCache.containsKey(typeKey)) {
      return linkDeclarationCache[typeKey];
    }

    // Mark as in progress
    linkGenerationInProgress.add(typeKey);

    final realPackageUri = typeMirror.location?.sourceUri.toString();
    if (realPackageUri == null) {
      return null;
    }
  
    try {
      // Get the actual runtime type (parameterized if applicable)
      Type actualRuntimeType;
      Type baseRuntimeType;
      
      try {
        if (typeMirror.hasReflectedType) {
          actualRuntimeType = typeMirror.reflectedType;
        } else {
          actualRuntimeType = typeMirror.runtimeType;
        }

        if(GenericTypeParser.shouldCheckGeneric(actualRuntimeType)) {
          final annotations = await extractAnnotations(typeMirror.metadata, package);
          Type? resolvedType = await resolveTypeFromGenericAnnotation(annotations, typeName);
          resolvedType ??= resolvePublicDartType(libraryUri, typeName);
          if (resolvedType != null) {
            actualRuntimeType = resolvedType;
          }
        }
        
        // For base type, get the raw type without parameters
        if (typeMirror is mirrors.ClassMirror && typeMirror.originalDeclaration != typeMirror) {
          // This is a parameterized type, get the original declaration
          baseRuntimeType = typeMirror.originalDeclaration.hasReflectedType 
              ? typeMirror.originalDeclaration.reflectedType 
              : typeMirror.originalDeclaration.runtimeType;

          // Apply @Generic annotation resolution if needed
          if(GenericTypeParser.shouldCheckGeneric(baseRuntimeType)) {
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

      // Get type arguments from the implementing class (with cycle protection)
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

      // Handle type variable bounds and variance (with cycle protection)
      TypeVariance variance = TypeVariance.invariant;
      LinkDeclaration? upperBound;
    
      if (typeMirror is mirrors.TypeVariableMirror) {
        // Extract upper bound
        if (typeMirror.upperBound != typeMirror.owner && typeMirror.upperBound.runtimeType.toString() != 'dynamic') {
          final boundName = mirrors.MirrorSystem.getName(typeMirror.upperBound.simpleName);
          final boundKey = 'mirror_${boundName}_${typeMirror.upperBound.hashCode}';
          if (!linkGenerationInProgress.contains(boundKey)) {
            upperBound = await generateLinkDeclarationFromMirror(typeMirror.upperBound, package, libraryUri);
          }
        }
      
        // Infer variance (simplified approach)
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

      // Cache the result
      linkDeclarationCache[typeKey] = result;
      return result;
    } finally {
      // Always remove from in-progress set
      linkGenerationInProgress.remove(typeKey);
    }
  }

  /// Get link declaration with fallback
  @protected
  Future<LinkDeclaration> getLinkDeclaration(mirrors.TypeMirror typeMirror, Package package, String libraryUri, [DartType? dartType]) async {
    LinkDeclaration? result;
    if(dartType != null) {
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
  Future<List<LinkDeclaration>> extractTypeArgumentsAsLinks(List<mirrors.TypeVariableMirror> mirrorTypeVars, List<TypeParameterElement>? analyzerTypeParams, Package package, String libraryUri) async {
    final typeArgs = <LinkDeclaration>[];
  
    for (int i = 0; i < mirrorTypeVars.length; i++) {
      final mirrorTypeVar = mirrorTypeVars[i];
      final analyzerTypeParam = (analyzerTypeParams != null && i < analyzerTypeParams.length)
          ? analyzerTypeParams[i]
          : null;
    
      // Create LinkDeclaration for type parameter
      String typeVarName = mirrors.MirrorSystem.getName(mirrorTypeVar.simpleName);
      if (isMirrorSyntheticType(typeVarName)) {
        typeVarName = "Object";
      }
      final typeKey = 'typevar_${typeVarName}_${libraryUri}_$i';
    
      // Skip if already processing to prevent infinite recursion
      if (linkGenerationInProgress.contains(typeKey)) {
        continue;
      }
    
      // Mark as in progress
      linkGenerationInProgress.add(typeKey);
    
      try {
        // Get upper bound (with cycle protection)
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
      
        // Determine variance
        final variance = getVarianceFromTypeParameter(analyzerTypeParam, mirrorTypeVar);
      
        final typeArgLink = StandardLinkDeclaration(
          name: typeVarName,
          type: Object, // Type parameters are represented as Object at runtime
          pointerType: Object,
          typeArguments: [], // Type parameters don't have their own type arguments
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
        // Always remove from in-progress set
        linkGenerationInProgress.remove(typeKey);
      }
    }
  
    return typeArgs;
  }

  /// Extract supertype as LinkDeclaration
  @protected
  Future<LinkDeclaration?> extractSupertypeAsLink(mirrors.ClassMirror classMirror, InterfaceElement? classElement, Package package, String libraryUri) async {
    // Use analyzer supertype if available
    if (classElement?.supertype != null) {
      return await generateLinkDeclarationFromDartType(classElement!.supertype!, package, libraryUri);
    }

    // Fallback to mirror
    if (classMirror.superclass != null) {
      return await generateLinkDeclarationFromMirror(classMirror.superclass!, package, libraryUri);
    }

    return null;
  }

  /// Extract interfaces as LinkDeclarations
  @protected
  Future<List<LinkDeclaration>> extractInterfacesAsLink(mirrors.ClassMirror classMirror, InterfaceElement? classElement, Package package, String libraryUri) async {
    final interfaces = <LinkDeclaration>[];

    // Use analyzer interfaces if available
    if (classElement != null) {
      for (final interfaceType in classElement.interfaces) {
        final linked = await generateLinkDeclarationFromDartType(interfaceType, package, libraryUri);
        if (linked != null) {
          interfaces.add(linked);
        }
      }
    } else {
      // Fallback to mirror
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

    // Use analyzer mixins if available
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

    // Use analyzer constraints if available
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
}