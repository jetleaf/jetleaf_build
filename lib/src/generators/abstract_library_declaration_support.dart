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
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart' as meta;

import '../declaration/declaration.dart';
import '../utils/constant.dart';
import '../utils/generic_type_parser.dart';
import 'abstract_class_declaration_support.dart';

/// Support class for generating LibraryDeclarations.
/// 
/// This is the final support class in the hierarchy that provides
/// library-level generation capabilities.
abstract class AbstractLibraryDeclarationSupport extends AbstractClassDeclarationSupport {
  AbstractLibraryDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
  });

  /// Generate library declaration with analyzer support
  @meta.protected
  Future<LibraryDeclaration> generateLibrary(mirrors.LibraryMirror libraryMirror) async {
    clearProcessingCaches();
    
    final uri = libraryMirror.uri.toString();
    final packageName = getPackageNameFromUri(uri);
    final package = packageCache[packageName] ?? createDefaultPackage(packageName ?? "unknown");

    final libraryElement = await getLibraryElement(libraryMirror.uri);
    
    final currentLibrary = StandardLibraryDeclaration(
      uri: uri,
      element: libraryElement,
      parentPackage: package,
      declarations: [],
      isPublic: !isInternal(uri),
      isSynthetic: isSynthetic(uri),
      annotations: await extractAnnotations(libraryMirror.metadata, package),
      sourceLocation: libraryMirror.uri,
    );

    libraryCache[uri] = currentLibrary;
    final declarations = <SourceDeclaration>[];

    // Process classes and mixins
    for (final classMirror in libraryMirror.declarations.values.whereType<mirrors.ClassMirror>()) {
      final fileUri = classMirror.location?.sourceUri ?? libraryMirror.uri;
      if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
        continue;
      }

      Type typeToReflect = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;

      if (GenericTypeParser.shouldCheckGeneric(typeToReflect)) {
        final annotations = await extractAnnotations(classMirror.metadata, package);
        final resolvedType = await resolveTypeFromGenericAnnotation(annotations, mirrors.MirrorSystem.getName(classMirror.simpleName));
        if (resolvedType != null) {
          typeToReflect = resolvedType;
        }
      }

      if (configuration.scanClasses.isNotEmpty && !configuration.scanClasses.contains(typeToReflect)) {
        continue;
      }

      if (configuration.excludeClasses.contains(typeToReflect)) {
        continue;
      }

      String? fileContent;
      try {
        fileContent = await readSourceCode(fileUri);
        if ((isTest(fileContent) && configuration.skipTests) || hasMirrorImport(fileContent)) {
          continue;
        }
      } catch (e) {
        onError('Could not read file content for $fileUri: $e');
        continue;
      }

      if (classMirror.isEnum) {
        declarations.add(await generateEnum(classMirror, package, uri, fileUri));
      } else if (isMixinClass(fileContent, mirrors.MirrorSystem.getName(classMirror.simpleName))) {
        declarations.add(await generateMixin(classMirror, package, uri, fileUri));
      } else {
        declarations.add(await generateClass(classMirror, package, uri, fileUri));
      }
    }

    // Process typedefs
    for (final typedefMirror in libraryMirror.declarations.values.whereType<mirrors.TypedefMirror>()) {
      final name = mirrors.MirrorSystem.getName(typedefMirror.simpleName);
      if (isInternal(name) || isSynthetic(name)) continue;
      
      final fileUri = typedefMirror.location?.sourceUri ?? libraryMirror.uri;
      if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
        continue;
      }

      String? fileContent;
      try {
        fileContent = await readSourceCode(fileUri);
        if ((isTest(fileContent) && configuration.skipTests) || hasMirrorImport(fileContent)) {
          continue;
        }
      } catch (e) {
        onError('Could not read file content for $fileUri: $e');
        continue;
      }

      declarations.add(await generateTypedef(typedefMirror, package, uri, fileUri));
    }

    // Process top-level functions and variables
    for (final declaration in libraryMirror.declarations.values) {
      final name = mirrors.MirrorSystem.getName(declaration.simpleName);
      if (isInternal(name) || isSynthetic(name)) continue;
      
      final fileUri = declaration.location?.sourceUri ?? libraryMirror.uri;
      if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
        continue;
      }

      String? fileContent;
      try {
        fileContent = await readSourceCode(fileUri);
        if ((isTest(fileContent) && configuration.skipTests) || hasMirrorImport(fileContent)) {
          continue;
        }
      } catch (e) {
        onError('Could not read file content for $fileUri: $e');
        continue;
      }

      if (declaration is mirrors.MethodMirror && !declaration.isConstructor && !declaration.isAbstract) {
        declarations.add(await generateTopLevelMethod(declaration, package, uri, fileUri));
      } else if (declaration is mirrors.VariableMirror) {
        declarations.add(await generateTopLevelField(declaration, package, uri, fileUri));
      }
    }

    return currentLibrary.copyWith(declarations: declarations);
  }

  /// Generate built-in library declaration
  @meta.protected
  Future<LibraryDeclaration> generateBuiltInLibrary(mirrors.LibraryMirror library) async {
    clearProcessingCaches();
    
    final uri = library.uri.toString();
    final package = packageCache[Constant.DART_PACKAGE_NAME] ?? createBuiltInPackage();

    onInfo('Processing built-in library: $uri');

    final currentLibrary = StandardLibraryDeclaration(
      uri: uri,
      dartType: null,
      element: null,
      parentPackage: package,
      declarations: [],
      isPublic: !isInternal(uri),
      isSynthetic: isSynthetic(uri),
      annotations: await extractAnnotations(library.metadata, package),
      sourceLocation: library.uri,
    );

    libraryCache[uri] = currentLibrary;
    final declarations = <SourceDeclaration>[];

    // Process classes and mixins from built-in library
    for (final classMirror in library.declarations.values.whereType<mirrors.ClassMirror>()) {
      if (classMirror.isEnum) {
        declarations.add(await generateBuiltInEnum(classMirror, package, uri, library.uri));
      } else {
        declarations.add(await generateBuiltInClass(classMirror, package, uri, library.uri));
      }
    }

    // Process typedefs from built-in library
    for (final typedefMirror in library.declarations.values.whereType<mirrors.TypedefMirror>()) {
      declarations.add(await generateBuiltInTypedef(typedefMirror, package, uri, library.uri));
    }

    // Process top-level functions and variables from built-in library
    for (final declaration in library.declarations.values) {
      if (declaration is mirrors.MethodMirror && !declaration.isConstructor && !declaration.isAbstract) {
        declarations.add(await generateBuiltInTopLevelMethod(declaration, package, uri, library.uri));
      } else if (declaration is mirrors.VariableMirror) {
        declarations.add(await generateBuiltInTopLevelField(declaration, package, uri, library.uri));
      }
    }

    return currentLibrary.copyWith(declarations: declarations);
  }
}