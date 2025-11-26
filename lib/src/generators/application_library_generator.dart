// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

// ignore_for_file: depend_on_referenced_packages, unused_import, unnecessary_import

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:core';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:mirrors' as mirrors;
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

import '../annotations.dart';
import '../utils/constant.dart';
import '../declaration/declaration.dart';
import '../utils/must_avoid.dart';
import '../utils/dart_type_resolver.dart';
import '../utils/generic_type_parser.dart';
import '../utils/utils.dart';
import 'library_generator.dart';
import 'tree_shaker.dart';
import 'declaration_file_writer.dart';

/// Enhanced reflection generator that integrates analyzer capabilities directly
/// into declaration classes for perfect generic type handling and accurate
/// assignability checking.
class ApplicationLibraryGenerator extends LibraryGenerator {
  /// Analysis context collection for static analysis
  AnalysisContextCollection? _analysisContextCollection;
  
  /// Cache of library declarations
  final Map<String, LibraryDeclaration> _libraryCache = {};
  
  /// Cache of type declarations
  final Map<Type, TypeDeclaration> _typeCache = {};
  
  /// Cache of package declarations
  final Map<String, Package> _packageCache = {};
  
  /// Cache of source code
  final Map<String, String> _sourceCache = {};
  
  /// Cache of analyzer elements by URI
  final Map<String, LibraryElement> _libraryElementCache = {};

  /// Type variable cache
  final Map<String, TypeVariableDeclaration> _typeVariableCache = {};

  /// Cache for DartType to Type mapping
  final Map<String, Type> _dartTypeToTypeCache = {};

  /// Cache for preventing infinite recursion in LinkDeclaration generation
  final Set<String> _linkGenerationInProgress = {};
  final Map<String, LinkDeclaration?> _linkDeclarationCache = {};

  /// Tree shaker instance for dependency analysis
  TreeShaker? _treeShaker;
  
  /// Declaration file writer for organized output
  DeclarationFileWriter? _fileWriter;

  final bool refresh;

  ApplicationLibraryGenerator({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
    this.refresh = true
  });

  List<mirrors.LibraryMirror> get loader => refresh ? [...mirrorSystem.libraries.values, ...forceLoadedMirrors] : [...forceLoadedMirrors];

  @override
  Future<List<LibraryDeclaration>> generate(List<File> dartFiles) async {
    // Initialize analyzer
    await _initializeAnalyzer(dartFiles);
    
    // Initialize tree shaker if needed
    if (configuration.enableTreeShaking) {
      _treeShaker = TreeShaker();
    }
    
    // Create package lookup
    for (final package in packages) {
      _packageCache[package.getName()] = package;
    }

    final libraries = <LibraryDeclaration>[];
    final processedLibraries = <String>{};

    onInfo('Generating declaration metadata with analyzer integration...');
    final nonNecessaryPackages = getNonNecessaryPackages();
    
    for (final libraryMirror in loader) {
      final fileUri = libraryMirror.uri;
      final filePath = libraryMirror.uri.toString();

      try {
        final mustSkip = "jetleaf_build/src/runtime/";
        if(filePath == "dart:mirrors" || filePath.startsWith("package:$mustSkip") || filePath.contains(mustSkip)) {
          continue;
        }

        if (!processedLibraries.add(filePath) || forgetPackage(filePath)) {
          continue;
        }

        if (nonNecessaryPackages.any((pkg) => filePath.startsWith('package:$pkg/') && !configuration.packagesToScan.contains(pkg))) {
          // Skip this file
          continue;
        }

        onInfo('Processing library: $filePath');
        LibraryDeclaration libDecl;
        
        if (_isBuiltInDartLibrary(fileUri)) {
          // Handle built-in Dart libraries (dart:core, dart:io, etc.)
          libDecl = await _generateBuiltInLibraryDeclaration(libraryMirror);
        } else {
          // Handle user libraries and package libraries
          if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
            continue;
          }

          String? fileContent;
          try {
            fileContent = await _readSourceCode(fileUri);
            if ((isTest(fileContent) && configuration.skipTests) || hasMirrorImport(fileContent) || forgetPackage(fileContent)) {
              continue;
            }
          } catch (e) {
            onError('Could not read file content for $fileUri: $e');
            continue;
          }
          
          libDecl = await generateLibrary(libraryMirror);
        }

        libraries.add(libDecl);
        _libraryCache[fileUri.toString()] = libDecl;
      } catch (e, stackTrace) {
        onError('Error processing library ${fileUri.toString()}: $e\n$stackTrace');
      }
    }

    // Apply tree-shaking if enabled
    Set<String> usedClasses = {};
    if (configuration.enableTreeShaking && _treeShaker != null) {
      final userPackageNames = packages
          .where((p) => p.getIsRootPackage())
          .map((p) => p.getName())
          .toSet();
      
      usedClasses = _treeShaker!.shake(libraries, userPackageNames);
      onInfo('Tree-shaking enabled: ${usedClasses.length} classes marked as used');
    }

    // Write declarations to files if configured
    if (configuration.writeDeclarationsToFiles) {
      _fileWriter = DeclarationFileWriter(configuration.outputPath, refresh);
      await _fileWriter!.writeDeclarations(libraries, usedClasses, configuration.enableTreeShaking);
      onInfo('Declarations written to ${configuration.outputPath}/classes/');
    }

    // Check for unresolved generic classes
    final unresolvedClasses = libraries
      .where((l) => l.getIsPublic() && !l.getIsSynthetic() && l.getPackage().getIsRootPackage())
      .flatMap((l) => l.getDeclarations())
      .whereType<TypeDeclaration>()
      .where((d) => GenericTypeParser.shouldCheckGeneric(d.getType()) && d.getIsPublic() && !d.getIsSynthetic());

    if (unresolvedClasses.isNotEmpty) {
      final warningMessage = '''
⚠️ Generic Class Discovery Issue ⚠️
Found ${unresolvedClasses.length} classes with unresolved runtime types:
${unresolvedClasses.map((d) => "• ${d.getSimpleName()} (${d.getQualifiedName()})").join("\n")}

These classes may need manual type resolution or have complex generic constraints.
      ''';
      onWarning(warningMessage);
    }

    return libraries;
  }

  /// Initialize the analyzer context collection
  Future<void> _initializeAnalyzer(List<File> dartFiles) async {
    try {
      final resourceProvider = PhysicalResourceProvider.INSTANCE;
      if (dartFiles.isNotEmpty) {
        _analysisContextCollection = AnalysisContextCollection(
          includedPaths: dartFiles.map((f) => f.path).toList(),
          resourceProvider: resourceProvider,
        );
        onInfo('Analyzer initialized with ${dartFiles.length} dart files');
      } else {
        onWarning('No dart files found');
      }
    } catch (e) {
      onWarning('Failed to initialize analyzer: $e');
    }
  }

  /// Clear caches for processing a new library
  void _clearProcessingCaches() {
    _linkGenerationInProgress.clear();
    _linkDeclarationCache.clear();
  }

  // ========================================== DART GENERATION ==============================================

  /// Generates a library declaration for built-in Dart libraries
  Future<LibraryDeclaration> _generateBuiltInLibraryDeclaration(mirrors.LibraryMirror library) async {
    // Clear processing caches for this library
    _clearProcessingCaches();
    
    final uri = library.uri.toString();
    final package = _packageCache[Constant.DART_PACKAGE_NAME] ?? _createBuiltInPackage();

    onInfo('Processing built-in library: $uri');

    // Create library declaration for built-in library
    final currentLibrary = StandardLibraryDeclaration(
      uri: uri,
      dartType: null, // Built-in libraries don't have analyzer DartType
      element: null,  // Built-in libraries don't have analyzer Element
      parentPackage: package,
      declarations: [],
      isPublic: !_isInternal(uri),
      isSynthetic: _isSynthetic(uri),
      annotations: await _extractAnnotations(library.metadata, package),
      sourceLocation: library.uri,
    );

    _libraryCache[uri] = currentLibrary;
    final declarations = <SourceDeclaration>[];

    // Process classes and mixins from built-in library
    for (final classMirror in library.declarations.values.whereType<mirrors.ClassMirror>()) {
      if (classMirror.isEnum) {
        declarations.add(await _generateBuiltInEnum(classMirror, package, uri, library.uri));
      } else {
        declarations.add(await _generateBuiltInClass(classMirror, package, uri, library.uri));
      }
    }

    // Process typedefs from built-in library
    for (final typedefMirror in library.declarations.values.whereType<mirrors.TypedefMirror>()) {
      declarations.add(await _generateBuiltInTypedef(typedefMirror, package, uri, library.uri));
    }

    // Process top-level functions and variables from built-in library
    for (final declaration in library.declarations.values) {
      if (declaration is mirrors.MethodMirror && !declaration.isConstructor && !declaration.isAbstract) {
        declarations.add(await _generateBuiltInTopLevelMethod(declaration, package, uri, library.uri));
      } else if (declaration is mirrors.VariableMirror) {
        declarations.add(await _generateBuiltInTopLevelField(declaration, package, uri, library.uri));
      }
    }

    return currentLibrary.copyWith(declarations: declarations);
  }

  /// Generate built-in class declaration
  Future<ClassDeclaration> _generateBuiltInClass(mirrors.ClassMirror classMirror, Package package, String libraryUri, Uri sourceUri) async {
    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);
    
    // Get runtime type with fallback and safety check
    Type runtimeType = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;

    final annotations = await _extractAnnotations(classMirror.metadata, package);

    // Resolve type from @Generic annotation if needed
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      Type? resolvedType = await _resolveTypeFromGenericAnnotation(annotations, className);
      resolvedType ??= resolvePublicDartType(libraryUri, className);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final constructors = <ConstructorDeclaration>[];
    final fields = <FieldDeclaration>[];
    final methods = <MethodDeclaration>[];
    final records = <RecordDeclaration>[];

    // Extract inheritance relationships using LinkDeclarations
    final supertype = await _extractSupertypeAsLink(classMirror, null, package, libraryUri);
    final interfaces = await _extractInterfacesAsLink(classMirror, null, package, libraryUri);
    final mixins = await _extractMixinsAsLink(classMirror, null, package, libraryUri);
    final sourceCode = await _readSourceCode(classMirror.location?.sourceUri ?? Uri.parse(libraryUri));

    // Create class declaration for built-in class
    StandardClassDeclaration reflectedClass = StandardClassDeclaration(
      name: className,
      type: runtimeType,
      element: null, // Built-in classes don't have analyzer elements
      dartType: null, // Built-in classes don't have analyzer DartType
      qualifiedName: _buildQualifiedName(className, (classMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: _libraryCache[libraryUri]!,
      isNullable: false,
      typeArguments: await _extractTypeArgumentsAsLinks(classMirror.typeVariables, null, package, libraryUri),
      annotations: annotations,
      sourceLocation: sourceUri,
      superClass: supertype,
      interfaces: interfaces,
      mixins: mixins,
      isPublic: !_isInternal(className),
      isSynthetic: _isSynthetic(className),
      isAbstract: classMirror.isAbstract,
      isMixin: _isMixinClass(sourceCode, className),
      isSealed: _isSealedClass(sourceCode, className),
      isBase: _isBaseClass(sourceCode, className),
      isInterface: _isInterfaceClass(sourceCode, className),
      isFinal: _isFinalClass(sourceCode, className),
      isRecord: false,
    );

    _typeCache[runtimeType] = reflectedClass;

    // Process constructors
    for (final constructor in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (constructor.isConstructor) {
        constructors.add(await _generateBuiltInConstructor(constructor, package, libraryUri, sourceUri, className, reflectedClass));
      }
    }

    // Process fields
    for (final field in classMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
      fields.add(await _generateBuiltInField(field, package, libraryUri, sourceUri, className, reflectedClass));
    }

    // Process methods
    for (final method in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (!method.isConstructor && !method.isAbstract) {
        methods.add(await _generateBuiltInMethod(method, package, libraryUri, sourceUri, className, reflectedClass));
      }
    }

    return reflectedClass.copyWith(constructors: constructors, fields: fields, methods: methods, records: records);
  }

  /// Generate built-in enum declaration
  Future<EnumDeclaration> _generateBuiltInEnum(mirrors.ClassMirror enumMirror, Package package, String libraryUri, Uri sourceUri) async {
    final enumName = mirrors.MirrorSystem.getName(enumMirror.simpleName);

    final values = <EnumFieldDeclaration>[];
    final members = <MemberDeclaration>[];

    Type runtimeType = enumMirror.hasReflectedType ? enumMirror.reflectedType : enumMirror.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(enumMirror.metadata, package);
      Type? resolvedType = await _resolveTypeFromGenericAnnotation(annotations, enumName);
      resolvedType ??= resolvePublicDartType(libraryUri, enumName);

      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    StandardEnumDeclaration reflectedEnum = StandardEnumDeclaration(
      name: enumName,
      type: runtimeType,
      element: null, // Built-in enums don't have analyzer elements
      dartType: null, // Built-in enums don't have analyzer DartType
      qualifiedName: _buildQualifiedName(enumName, (enumMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: _libraryCache[libraryUri]!,
      values: values,
      isNullable: false,
      isPublic: !_isInternal(enumName),
      isSynthetic: _isSynthetic(enumName),
      typeArguments: await _extractTypeArgumentsAsLinks(enumMirror.typeVariables, null, package, libraryUri),
      annotations: await _extractAnnotations(enumMirror.metadata, package),
      sourceLocation: sourceUri,
      members: members,
    );

    // Extract enum values with safety checks
    for (final declaration in enumMirror.declarations.values) {
      if (declaration is mirrors.VariableMirror && declaration.isStatic && declaration.type.hasReflectedType && declaration.type.reflectedType == runtimeType) {
        final fieldMirror = enumMirror.getField(declaration.simpleName);
        if (fieldMirror.hasReflectee) {
          final enumFieldName = mirrors.MirrorSystem.getName(declaration.simpleName);

          values.add(StandardEnumFieldDeclaration(
            name: enumFieldName,
            type: runtimeType,
            libraryDeclaration: _libraryCache[libraryUri]!,
            annotations: await _extractAnnotations(declaration.metadata, package),
            value: fieldMirror.reflectee,
            isPublic: !_isInternal(enumFieldName),
            isSynthetic: _isSynthetic(enumFieldName),
            position: enumMirror.declarations.values.toList().indexOf(declaration),
            isNullable: _isNullable(fieldName: enumFieldName, sourceCode: await _readSourceCode(sourceUri))
          ));
        }
      }
    }

    // Extract enum methods and fields
    for (final declaration in enumMirror.declarations.values) {
      if (declaration is mirrors.MethodMirror && !declaration.isConstructor) {
        members.add(await _generateBuiltInMethod(declaration, package, libraryUri, sourceUri, enumName, null));
      } else if (declaration is mirrors.VariableMirror && !declaration.isStatic) {
        members.add(await _generateBuiltInField(declaration, package, libraryUri, sourceUri, enumName, null));
      }
    }

    reflectedEnum = reflectedEnum.copyWith(values: values, members: members);
    
    _typeCache[runtimeType] = reflectedEnum;
    return reflectedEnum;
  }

  /// Generate built-in typedef declaration
  Future<TypedefDeclaration> _generateBuiltInTypedef(mirrors.TypedefMirror typedefMirror, Package package, String libraryUri, Uri sourceUri) async {
    final typedefName = mirrors.MirrorSystem.getName(typedefMirror.simpleName);

    Type runtimeType = typedefMirror.hasReflectedType ? typedefMirror.reflectedType : typedefMirror.runtimeType;

    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(typedefMirror.metadata, package);
      Type? resolvedType = await _resolveTypeFromGenericAnnotation(annotations, typedefName);
      resolvedType ??= resolvePublicDartType(libraryUri, typedefName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    StandardTypedefDeclaration reflectedTypedef = StandardTypedefDeclaration(
      name: typedefName,
      type: runtimeType,
      element: null, // Built-in typedefs don't have analyzer elements
      dartType: null, // Built-in typedefs don't have analyzer DartType
      qualifiedName: _buildQualifiedName(typedefName, (typedefMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: _libraryCache[libraryUri]!,
      aliasedType: await generateType(typedefMirror.referent, package, libraryUri),
      isNullable: false,
      isPublic: !_isInternal(typedefName),
      isSynthetic: _isSynthetic(typedefName),
      typeArguments: await _extractTypeArgumentsAsLinks(typedefMirror.typeVariables, null, package, libraryUri),
      annotations: await _extractAnnotations(typedefMirror.metadata, package),
      sourceLocation: sourceUri,
    );

    _typeCache[runtimeType] = reflectedTypedef;
    return reflectedTypedef;
  }

  /// Generate built-in top-level method
  Future<MethodDeclaration> _generateBuiltInTopLevelMethod(mirrors.MethodMirror methodMirror, Package package, String libraryUri, Uri sourceUri) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);

    final mirrorType = methodMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, methodName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardMethodDeclaration(
      name: methodName,
      element: null, // Built-in methods don't have analyzer elements
      dartType: null, // Built-in methods don't have analyzer DartType
      type: runtimeType,
      libraryDeclaration: _libraryCache[libraryUri]!,
      returnType: await _getLinkDeclaration(methodMirror.returnType, package, libraryUri),
      annotations: await _extractAnnotations(methodMirror.metadata, package),
      sourceLocation: sourceUri,
      isStatic: true,
      isAbstract: false,
      isPublic: !_isInternal(methodName),
      isSynthetic: _isSynthetic(methodName),
      isGetter: methodMirror.isGetter,
      isSetter: methodMirror.isSetter,
      isFactory: false,
      isConst: false,
    );

    result.parameters = await _extractParameters(methodMirror.parameters, null, package, libraryUri, result);

    return result;
  }

  /// Generate built-in top-level field
  Future<FieldDeclaration> _generateBuiltInTopLevelField(mirrors.VariableMirror fieldMirror, Package package, String libraryUri, Uri sourceUri) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);

    final mirrorType = fieldMirror.type;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, fieldName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    return StandardFieldDeclaration(
      name: fieldName,
      type: runtimeType,
      element: null, // Built-in fields don't have analyzer elements
      dartType: null, // Built-in fields don't have analyzer DartType
      libraryDeclaration: _libraryCache[libraryUri]!,
      parentClass: null,
      linkDeclaration: await _getLinkDeclaration(fieldMirror.type, package, libraryUri),
      annotations: await _extractAnnotations(fieldMirror.metadata, package),
      sourceLocation: sourceUri,
      isFinal: fieldMirror.isFinal,
      isConst: fieldMirror.isConst,
      isLate: false,
      isStatic: true,
      isAbstract: false,
      isPublic: !_isInternal(fieldName),
      isSynthetic: _isSynthetic(fieldName),
      isNullable: _isNullable(fieldName: fieldName, sourceCode: await _readSourceCode(sourceUri))
    );
  }

  /// Generate built-in constructor
  Future<ConstructorDeclaration> _generateBuiltInConstructor(mirrors.MethodMirror constructorMirror, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration parentClass) async {
    final constructorName = mirrors.MirrorSystem.getName(constructorMirror.constructorName);

    final mirrorType = constructorMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, constructorName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardConstructorDeclaration(
      name: constructorName.isEmpty ? '' : constructorName,
      type: runtimeType,
      element: null, // Built-in constructors don't have analyzer elements
      dartType: null, // Built-in constructors don't have analyzer DartType
      libraryDeclaration: _libraryCache[libraryUri]!,
      parentClass: StandardLinkDeclaration(
        name: parentClass.getName(),
        type: parentClass.getType(),
        pointerType: parentClass.getType(),
        qualifiedName: parentClass.getQualifiedName(),
        isPublic: parentClass.getIsPublic(),
        canonicalUri: Uri.parse(parentClass.getPackageUri()),
        referenceUri: Uri.parse(parentClass.getPackageUri()),
        isSynthetic: parentClass.getIsSynthetic(),
      ),
      annotations: await _extractAnnotations(constructorMirror.metadata, package),
      sourceLocation: sourceUri,
      isFactory: constructorMirror.isFactoryConstructor,
      isConst: constructorMirror.isConstConstructor,
      isPublic: !_isInternal(constructorName),
      isSynthetic: _isSynthetic(constructorName),
    );

    result.parameters = await _extractParameters(constructorMirror.parameters, null, package, libraryUri, result);

    return result;
  }

  /// Generate built-in method
  Future<MethodDeclaration> _generateBuiltInMethod(mirrors.MethodMirror methodMirror, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);

    final mirrorType = methodMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, methodName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardMethodDeclaration(
      name: methodName,
      element: null, // Built-in methods don't have analyzer elements
      dartType: null, // Built-in methods don't have analyzer DartType
      type: runtimeType,
      libraryDeclaration: _libraryCache[libraryUri]!,
      returnType: await _getLinkDeclaration(methodMirror.returnType, package, libraryUri),
      annotations: await _extractAnnotations(methodMirror.metadata, package),
      sourceLocation: sourceUri,
      isStatic: methodMirror.isStatic,
      isAbstract: methodMirror.isAbstract,
      isGetter: methodMirror.isGetter,
      isSetter: methodMirror.isSetter,
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
      isFactory: methodMirror.isFactoryConstructor,
      isConst: methodMirror.isConstConstructor,
      isPublic: !_isInternal(methodName),
      isSynthetic: _isSynthetic(methodName),
    );

    result.parameters = await _extractParameters(methodMirror.parameters, null, package, libraryUri, result);

    return result;
  }

  /// Generate built-in field
  Future<FieldDeclaration> _generateBuiltInField(mirrors.VariableMirror fieldMirror, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);

    final mirrorType = fieldMirror.type;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, fieldName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    return StandardFieldDeclaration(
      name: fieldName,
      type: runtimeType,
      element: null, // Built-in fields don't have analyzer elements
      dartType: null, // Built-in fields don't have analyzer DartType
      libraryDeclaration: _libraryCache[libraryUri]!,
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
      linkDeclaration: await _getLinkDeclaration(fieldMirror.type, package, libraryUri),
      annotations: await _extractAnnotations(fieldMirror.metadata, package),
      sourceLocation: sourceUri,
      isFinal: fieldMirror.isFinal,
      isConst: fieldMirror.isConst,
      isLate: false,
      isStatic: fieldMirror.isStatic,
      isAbstract: false,
      isPublic: !_isInternal(fieldName),
      isSynthetic: _isSynthetic(fieldName),
      isNullable: _isNullable(fieldName: fieldName, sourceCode: await _readSourceCode(sourceUri))
    );
  }

  // ========================================== USER GENERATIOn ==============================================

  /// Generate library declaration with integrated analyzer support
  Future<LibraryDeclaration> generateLibrary(mirrors.LibraryMirror libraryMirror) async {
    // Clear processing caches for this library
    _clearProcessingCaches();
    
    final uri = libraryMirror.uri.toString();
    final packageName = getPackageNameFromUri(uri);
    final package = _packageCache[packageName] ?? _createDefaultPackage(packageName ?? "unknown");

    // Get analyzer library element
    final libraryElement = await _getLibraryElement(libraryMirror.uri);
    
    // Create library declaration with analyzer support
    final currentLibrary = StandardLibraryDeclaration(
      uri: uri,
      element: libraryElement,
      parentPackage: package,
      declarations: [],
      isPublic: !_isInternal(uri),
      isSynthetic: _isSynthetic(uri),
      annotations: await _extractAnnotations(libraryMirror.metadata, package),
      sourceLocation: libraryMirror.uri,
    );

    _libraryCache[uri] = currentLibrary;
    final declarations = <SourceDeclaration>[];

    // Process classes and mixins
    for (final classMirror in libraryMirror.declarations.values.whereType<mirrors.ClassMirror>()) {
      final fileUri = classMirror.location?.sourceUri ?? libraryMirror.uri;
      if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
        continue;
      }

      Type typeToReflect = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;

      if(GenericTypeParser.shouldCheckGeneric(typeToReflect)) {
        final annotations = await _extractAnnotations(classMirror.metadata, package);
        final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, mirrors.MirrorSystem.getName(classMirror.simpleName));
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
        fileContent = await _readSourceCode(fileUri);
        if ((isTest(fileContent) && configuration.skipTests) || hasMirrorImport(fileContent)) {
          continue;
        }
      } catch (e) {
        onError('Could not read file content for $fileUri: $e');
        continue;
      }

      if (classMirror.isEnum) {
        declarations.add(await generateEnum(classMirror, package, uri, fileUri));
      } else if (_isMixinClass(fileContent, mirrors.MirrorSystem.getName(classMirror.simpleName))) {
        declarations.add(await generateMixin(classMirror, package, uri, fileUri));
      } else {
        declarations.add(await generateClass(classMirror, package, uri, fileUri));
      }
    }

    // Process typedefs
    for (final typedefMirror in libraryMirror.declarations.values.whereType<mirrors.TypedefMirror>()) {
      final name = mirrors.MirrorSystem.getName(typedefMirror.simpleName);
      if (_isInternal(name) || _isSynthetic(name)) continue;
      
      final fileUri = typedefMirror.location?.sourceUri ?? libraryMirror.uri;
      if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
        continue;
      }

      String? fileContent;
      try {
        fileContent = await _readSourceCode(fileUri);
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
      if (_isInternal(name) || _isSynthetic(name)) continue;
      
      final fileUri = declaration.location?.sourceUri ?? libraryMirror.uri;
      if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
        continue;
      }

      String? fileContent;
      try {
        fileContent = await _readSourceCode(fileUri);
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

  /// Generate class declaration with integrated analyzer support
  Future<ClassDeclaration> generateClass(mirrors.ClassMirror classMirror, Package package, String libraryUri, Uri sourceUri) async {
    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);
    
    // Get runtime type with fallback and safety check
    Type runtimeType = classMirror.hasReflectedType ? classMirror.reflectedType : classMirror.runtimeType;

    // Get analyzer element and type
    final classElement = await _getClassElement(className, sourceUri);
    final dartType = classElement?.thisType;

    final annotations = await _extractAnnotations(classMirror.metadata, package);

    // Resolve type from @Generic annotation if needed
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, className);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final constructors = <ConstructorDeclaration>[];
    final fields = <FieldDeclaration>[];
    final methods = <MethodDeclaration>[];
    final records = <RecordDeclaration>[];

    // Get source code for modifier detection
    String? sourceCode = _sourceCache[sourceUri.toString()];

    // Extract inheritance relationships using LinkDeclarations
    final supertype = await _extractSupertypeAsLink(classMirror, classElement, package, libraryUri);
    final interfaces = await _extractInterfacesAsLink(classMirror, classElement, package, libraryUri);
    final mixins = await _extractMixinsAsLink(classMirror, classElement, package, libraryUri);

    // Create class declaration with full analyzer integration
    StandardClassDeclaration reflectedClass = StandardClassDeclaration(
      name: className,
      type: runtimeType,
      element: classElement,
      dartType: dartType,
      qualifiedName: _buildQualifiedName(className, (classMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: _libraryCache[libraryUri]!,
      isNullable: false,
      typeArguments: await _extractTypeArgumentsAsLinks(classMirror.typeVariables, classElement?.typeParameters, package, libraryUri),
      annotations: annotations,
      sourceLocation: sourceUri,
      superClass: supertype,
      interfaces: interfaces,
      mixins: mixins,
      isAbstract: classMirror.isAbstract,
      isMixin: _isMixinClass(sourceCode, className),
      isSealed: _isSealedClass(sourceCode, className),
      isBase: _isBaseClass(sourceCode, className),
      isInterface: _isInterfaceClass(sourceCode, className),
      isFinal: _isFinalClass(sourceCode, className),
      isPublic: !_isInternal(className),
      isSynthetic: _isSynthetic(className),
      isRecord: false,
    );

    _typeCache[runtimeType] = reflectedClass;

    // Process constructors with analyzer support
    for (final constructor in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (constructor.isConstructor) {
        constructors.add(await generateConstructor(constructor, classElement, package, libraryUri, sourceUri, className, reflectedClass));
      }
    }

    // Process fields with analyzer support
    for (final field in classMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
      fields.add(await generateField(field, classElement, package, libraryUri, sourceUri, className, reflectedClass, sourceCode));
    }

    // Process methods with analyzer support
    for (final method in classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (!method.isConstructor && !method.isAbstract) {
        methods.add(await generateMethod(method, classElement, package, libraryUri, sourceUri, className, reflectedClass));
      }
    }

    return reflectedClass.copyWith(constructors: constructors, fields: fields, methods: methods, records: records);
  }

  /// Generate mixin declaration with analyzer support
  Future<MixinDeclaration> generateMixin(mirrors.ClassMirror mixinMirror, Package package, String libraryUri, Uri sourceUri) async {
    final mixinName = mirrors.MirrorSystem.getName(mixinMirror.simpleName);
    
    Type runtimeType = mixinMirror.hasReflectedType ? mixinMirror.reflectedType : mixinMirror.runtimeType;

    // Get analyzer element
    final mixinElement = await _getMixinElement(mixinName, sourceUri);
    final dartType = mixinElement?.thisType;

    final annotations = await _extractAnnotations(mixinMirror.metadata, package);
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, mixinName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final fields = <FieldDeclaration>[];
    final methods = <MethodDeclaration>[];

    // Extract constraints and interfaces using LinkDeclarations
    final constraints = await _extractMixinConstraintsAsLink(mixinMirror, mixinElement, package, libraryUri);
    final interfaces = await _extractInterfacesAsLink(mixinMirror, mixinElement, package, libraryUri);

    StandardMixinDeclaration reflectedMixin = StandardMixinDeclaration(
      name: mixinName,
      type: runtimeType,
      element: mixinElement,
      dartType: dartType,
      qualifiedName: _buildQualifiedName(mixinName, (mixinMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: _libraryCache[libraryUri]!,
      isNullable: false,
      typeArguments: await _extractTypeArgumentsAsLinks(mixinMirror.typeVariables, mixinElement?.typeParameters, package, libraryUri),
      annotations: annotations,
      sourceLocation: sourceUri,
      fields: fields,
      methods: methods,
      constraints: constraints,
      interfaces: interfaces,
      isPublic: !_isInternal(mixinName),
      isSynthetic: _isSynthetic(mixinName),
    );

    // Process fields
    for (final field in mixinMirror.declarations.values.whereType<mirrors.VariableMirror>()) {
      fields.add(await generateField(field, mixinElement, package, libraryUri, sourceUri, mixinName, null, null));
    }

    // Process methods
    for (final method in mixinMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
      if (!method.isConstructor && !method.isAbstract) {
        methods.add(await generateMethod(method, mixinElement, package, libraryUri, sourceUri, mixinName, null));
      }
    }

    reflectedMixin = reflectedMixin.copyWith(fields: fields, methods: methods);

    _typeCache[runtimeType] = reflectedMixin;
    return reflectedMixin;
  }

  /// Generate enum declaration with analyzer support
  Future<EnumDeclaration> generateEnum(mirrors.ClassMirror enumMirror, Package package, String libraryUri, Uri sourceUri) async {
    final enumName = mirrors.MirrorSystem.getName(enumMirror.simpleName);
    final enumElement = await _getEnumElement(enumName, sourceUri);
    final dartType = enumElement?.thisType;

    final values = <EnumFieldDeclaration>[];
    final members = <MemberDeclaration>[];

    Type runtimeType = enumMirror.hasReflectedType ? enumMirror.reflectedType : enumMirror.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(enumMirror.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, enumName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    StandardEnumDeclaration reflectedEnum = StandardEnumDeclaration(
      name: enumName,
      type: runtimeType,
      element: enumElement,
      dartType: dartType,
      isPublic: !_isInternal(enumName),
      isSynthetic: _isSynthetic(enumName),
      qualifiedName: _buildQualifiedName(enumName, (enumMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: _libraryCache[libraryUri]!,
      values: values,
      isNullable: false,
      typeArguments: await _extractTypeArgumentsAsLinks(enumMirror.typeVariables, enumElement?.typeParameters, package, libraryUri),
      annotations: await _extractAnnotations(enumMirror.metadata, package),
      sourceLocation: sourceUri,
      members: members,
    );

    // Extract enum values with safety checks
    for (final declaration in enumMirror.declarations.values) {
      if (declaration is mirrors.VariableMirror && declaration.isStatic && declaration.type.hasReflectedType && declaration.type.reflectedType == runtimeType) {
        final fieldMirror = enumMirror.getField(declaration.simpleName);
        if (fieldMirror.hasReflectee) {
          final enumFieldName = mirrors.MirrorSystem.getName(declaration.simpleName);

          values.add(StandardEnumFieldDeclaration(
            name: enumFieldName,
            type: runtimeType,
            libraryDeclaration: _libraryCache[libraryUri]!,
            value: fieldMirror.reflectee,
            isPublic: !_isInternal(enumFieldName),
            isSynthetic: _isSynthetic(enumFieldName),
            position: enumMirror.declarations.values.toList().indexOf(declaration),
            isNullable: _isNullable(fieldName: enumFieldName, sourceCode: await _readSourceCode(sourceUri))
          ));
        }
      }
    }

    // Extract enum methods and fields
    for (final declaration in enumMirror.declarations.values) {
      if (declaration is mirrors.MethodMirror && !declaration.isConstructor) {
        members.add(await generateMethod(declaration, enumElement, package, libraryUri, sourceUri, enumName, null));
      } else if (declaration is mirrors.VariableMirror && !declaration.isStatic) {
        members.add(await generateField(declaration, enumElement, package, libraryUri, sourceUri, enumName, null, null));
      }
    }

    reflectedEnum = reflectedEnum.copyWith(values: values, members: members);
    
    _typeCache[runtimeType] = reflectedEnum;
    return reflectedEnum;
  }

  /// Generate typedef declaration with analyzer support
  Future<TypedefDeclaration> generateTypedef(mirrors.TypedefMirror typedefMirror, Package package, String libraryUri, Uri sourceUri) async {
    final typedefName = mirrors.MirrorSystem.getName(typedefMirror.simpleName);
    final typedefElement = await _getTypedefElement(typedefName, sourceUri);
    final dartType = typedefElement?.aliasedType;

    Type runtimeType = typedefMirror.hasReflectedType ? typedefMirror.reflectedType : typedefMirror.runtimeType;

    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(typedefMirror.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, typedefName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    StandardTypedefDeclaration reflectedTypedef = StandardTypedefDeclaration(
      name: typedefName,
      type: runtimeType,
      element: typedefElement,
      dartType: dartType,
      qualifiedName: _buildQualifiedName(typedefName, (typedefMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: _libraryCache[libraryUri]!,
      aliasedType: await generateType(typedefMirror.referent, package, libraryUri),
      isNullable: false,
      isPublic: !_isInternal(typedefName),
      isSynthetic: _isSynthetic(typedefName),
      typeArguments: await _extractTypeArgumentsAsLinks(typedefMirror.typeVariables, typedefElement?.typeParameters, package, libraryUri),
      annotations: await _extractAnnotations(typedefMirror.metadata, package),
      sourceLocation: sourceUri,
    );

    _typeCache[runtimeType] = reflectedTypedef;
    return reflectedTypedef;
  }

  /// Extract supertype as LinkDeclaration
  Future<LinkDeclaration?> _extractSupertypeAsLink(mirrors.ClassMirror classMirror, InterfaceElement? classElement, Package package, String libraryUri) async {
    // Use analyzer supertype if available
    if (classElement?.supertype != null) {
      return await _generateLinkDeclarationFromDartType(classElement!.supertype!, package, libraryUri);
    }

    // Fallback to mirror
    if (classMirror.superclass != null) {
      return await _generateLinkDeclarationFromMirror(classMirror.superclass!, package, libraryUri);
    }

    return null;
  }

  /// Extract interfaces as LinkDeclarations
  Future<List<LinkDeclaration>> _extractInterfacesAsLink(mirrors.ClassMirror classMirror, InterfaceElement? classElement, Package package, String libraryUri) async {
    final interfaces = <LinkDeclaration>[];

    // Use analyzer interfaces if available
    if (classElement != null) {
      for (final interfaceType in classElement.interfaces) {
        final linked = await _generateLinkDeclarationFromDartType(interfaceType, package, libraryUri);
        if (linked != null) {
          interfaces.add(linked);
        }
      }
    } else {
      // Fallback to mirror
      for (final interfaceMirror in classMirror.superinterfaces) {
        final linked = await _generateLinkDeclarationFromMirror(interfaceMirror, package, libraryUri);
        if (linked != null) {
          interfaces.add(linked);
        }
      }
    }

    return interfaces;
  }

  /// Extract mixins as LinkDeclarations
  Future<List<LinkDeclaration>> _extractMixinsAsLink(mirrors.ClassMirror classMirror, InterfaceElement? classElement, Package package, String libraryUri) async {
    final mixins = <LinkDeclaration>[];

    // Use analyzer mixins if available
    if (classElement != null) {
      for (final mixinType in classElement.mixins) {
        final linked = await _generateLinkDeclarationFromDartType(mixinType, package, libraryUri);
        if (linked != null) {
          mixins.add(linked);
        }
      }
    }

    return mixins;
  }

  /// Extract mixin constraints as LinkDeclarations
  Future<List<LinkDeclaration>> _extractMixinConstraintsAsLink(mirrors.ClassMirror mixinMirror, MixinElement? mixinElement, Package package, String libraryUri) async {
    final constraints = <LinkDeclaration>[];

    // Use analyzer constraints if available
    if (mixinElement != null) {
      for (final constraintType in mixinElement.superclassConstraints) {
        final linked = await _generateLinkDeclarationFromDartType(constraintType, package, libraryUri);
        if (linked != null) {
          constraints.add(linked);
        }
      }
    }

    return constraints;
  }

  /// Generate LinkDeclaration from DartType with cycle detection
  Future<LinkDeclaration?> _generateLinkDeclarationFromDartType(DartType dartType, Package package, String libraryUri) async {
    final element = dartType.element;
    if (element == null) return null;

    // Create a unique key for this type to detect cycles
    final typeKey = '${element.library?.uri}_${element.name}_${dartType.getDisplayString()}';
    
    // Check if we're already processing this type (cycle detection)
    if (_linkGenerationInProgress.contains(typeKey)) {
      return null; // Break the cycle
    }
    
    // Check cache first
    if (_linkDeclarationCache.containsKey(typeKey)) {
      return _linkDeclarationCache[typeKey];
    }

    // Mark as in progress
    _linkGenerationInProgress.add(typeKey);
    
    try {
      // Find the real class in the runtime system to get the actual package URI
      final realClassUri = await _findRealClassUri(element.name!, element.library?.uri.toString());

      // Get the actual runtime type for this DartType
      final actualRuntimeType = await _findRuntimeTypeFromDartType(dartType, libraryUri, package);
      
      // Get the base type (without type parameters)
      final baseRuntimeType = await _findBaseRuntimeTypeFromDartType(dartType, libraryUri, package);
      final realPackageUri = realClassUri ?? element.library?.uri.toString() ?? libraryUri;

      // Get type arguments from the implementing class (with cycle protection)
      final typeArguments = <LinkDeclaration>[];
      if (dartType is ParameterizedType && dartType.typeArguments.isNotEmpty) {
        for (final arg in dartType.typeArguments) {
          final argKey = '${arg.element?.library?.uri}_${arg.element?.name}_${arg.getDisplayString()}';
          if (!_linkGenerationInProgress.contains(argKey)) {
            final argLink = await _generateLinkDeclarationFromDartType(arg, package, libraryUri);
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
          if (!_linkGenerationInProgress.contains(boundKey)) {
            upperBound = await _generateLinkDeclarationFromDartType(bound, package, libraryUri);
          }
        }
      
        // Infer variance from usage context (simplified)
        variance = _inferVarianceFromContext(dartType);
      }

      final result = StandardLinkDeclaration(
        name: dartType.getDisplayString(),
        type: actualRuntimeType,
        pointerType: baseRuntimeType,
        typeArguments: typeArguments,
        qualifiedName: _buildQualifiedName(dartType.getDisplayString(), realPackageUri),
        canonicalUri: Uri.tryParse(realPackageUri),
        referenceUri: Uri.tryParse(libraryUri),
        variance: variance,
        upperBound: upperBound,
        isPublic: !_isInternal(dartType.getDisplayString()),
        isSynthetic: _isSynthetic(dartType.getDisplayString()),
      );

      // Cache the result
      _linkDeclarationCache[typeKey] = result;
      return result;
    } finally {
      // Always remove from in-progress set
      _linkGenerationInProgress.remove(typeKey);
    }
  }

  /// Generate LinkDeclaration from Mirror with cycle detection
  Future<LinkDeclaration?> _generateLinkDeclarationFromMirror(mirrors.TypeMirror typeMirror, Package package, String libraryUri) async {
    String typeName = mirrors.MirrorSystem.getName(typeMirror.simpleName);
  
    Type runtimeType;
    try {
      runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;
    } catch (e) {
      runtimeType = typeMirror.runtimeType;
    }

    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(typeMirror.metadata, package);
      Type? resolvedType = await _resolveTypeFromGenericAnnotation(annotations, typeName);
      resolvedType ??= resolvePublicDartType(libraryUri, typeName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    // Create a unique key for this type to detect cycles
    final typeKey = 'mirror_${typeName}_${runtimeType}_${typeMirror.hashCode}';
  
    // Check if we're already processing this type (cycle detection)
    if (_linkGenerationInProgress.contains(typeKey)) {
      return null; // Break the cycle
    }
  
    // Check cache first
    if (_linkDeclarationCache.containsKey(typeKey)) {
      return _linkDeclarationCache[typeKey];
    }

    // Mark as in progress
    _linkGenerationInProgress.add(typeKey);

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
          final annotations = await _extractAnnotations(typeMirror.metadata, package);
          Type? resolvedType = await _resolveTypeFromGenericAnnotation(annotations, typeName);
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
            final annotations = await _extractAnnotations(typeMirror.originalDeclaration.metadata, package);
            Type? resolvedType = await _resolveTypeFromGenericAnnotation(annotations, typeName);
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
          if (!_linkGenerationInProgress.contains(argKey)) {
            final argLink = await _generateLinkDeclarationFromMirror(arg, package, libraryUri);
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
          if (!_linkGenerationInProgress.contains(boundKey)) {
            upperBound = await _generateLinkDeclarationFromMirror(typeMirror.upperBound, package, libraryUri);
          }
        }
      
        // Infer variance (simplified approach)
        variance = _inferVarianceFromMirror(typeMirror);
      }

      final result = StandardLinkDeclaration(
        name: typeName,
        type: actualRuntimeType,
        pointerType: baseRuntimeType,
        typeArguments: typeArguments,
        qualifiedName: _buildQualifiedName(typeName, realPackageUri),
        canonicalUri: Uri.tryParse(realPackageUri),
        referenceUri: Uri.tryParse(libraryUri),
        variance: variance,
        upperBound: upperBound,
        isPublic: !_isInternal(typeName),
        isSynthetic: _isSynthetic(typeName),
      );

      // Cache the result
      _linkDeclarationCache[typeKey] = result;
      return result;
    } finally {
      // Always remove from in-progress set
      _linkGenerationInProgress.remove(typeKey);
    }
  }

  Future<LinkDeclaration> _getLinkDeclaration(mirrors.TypeMirror typeMirror, Package package, String libraryUri, [DartType? dartType]) async {
    LinkDeclaration? result;
    if(dartType != null) {
      result = await _generateLinkDeclarationFromDartType(dartType, package, libraryUri);
    } else {
      result = await _generateLinkDeclarationFromMirror(typeMirror, package, libraryUri);
    }
    
    return result ?? await _generateLinkDeclarationFromMirror(typeMirror, package, libraryUri) ?? StandardLinkDeclaration(
      name: 'Object',
      type: Object,
      pointerType: Object,
      qualifiedName: _buildQualifiedName('Object', 'dart:core'),
      isPublic: true,
      isSynthetic: false,
    );
  }

  /// Extract type arguments as LinkDeclarations with cycle detection
  Future<List<LinkDeclaration>> _extractTypeArgumentsAsLinks(
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
    
      // Create LinkDeclaration for type parameter
      String typeVarName = mirrors.MirrorSystem.getName(mirrorTypeVar.simpleName);
      if (_isMirrorSyntheticType(typeVarName)) {
        typeVarName = "Object";
      }
      final typeKey = 'typevar_${typeVarName}_${libraryUri}_$i';
    
      // Skip if already processing to prevent infinite recursion
      if (_linkGenerationInProgress.contains(typeKey)) {
        continue;
      }
    
      // Mark as in progress
      _linkGenerationInProgress.add(typeKey);
    
      try {
        // Get upper bound (with cycle protection)
        LinkDeclaration? upperBound;
        if (mirrorTypeVar.upperBound != mirrorTypeVar.owner && mirrorTypeVar.upperBound.runtimeType.toString() != 'dynamic') {
          final boundName = mirrors.MirrorSystem.getName(mirrorTypeVar.upperBound.simpleName);
          final boundKey = 'mirror_${boundName}_${mirrorTypeVar.upperBound.runtimeType}_${mirrorTypeVar.upperBound.hashCode}';
          if (!_linkGenerationInProgress.contains(boundKey)) {
            upperBound = await _generateLinkDeclarationFromMirror(mirrorTypeVar.upperBound, package, libraryUri);
          }
        } else if (analyzerTypeParam?.bound != null) {
          final boundKey = '${analyzerTypeParam!.bound!.element?.library?.uri}_${analyzerTypeParam.bound!.element?.name}_${analyzerTypeParam.bound!.getDisplayString()}';
          if (!_linkGenerationInProgress.contains(boundKey)) {
            upperBound = await _generateLinkDeclarationFromDartType(analyzerTypeParam.bound!, package, libraryUri);
          }
        }
      
        // Determine variance
        final variance = _getVarianceFromTypeParameter(analyzerTypeParam, mirrorTypeVar);
      
        final typeArgLink = StandardLinkDeclaration(
          name: typeVarName,
          type: Object, // Type parameters are represented as Object at runtime
          pointerType: Object,
          typeArguments: [], // Type parameters don't have their own type arguments
          qualifiedName: _buildQualifiedName(typeVarName, libraryUri),
          canonicalUri: Uri.tryParse(libraryUri),
          referenceUri: Uri.tryParse(libraryUri),
          variance: variance,
          upperBound: upperBound,
          isPublic: !_isInternal(typeVarName),
          isSynthetic: _isSynthetic(typeVarName),
        );
      
        typeArgs.add(typeArgLink);
      } finally {
        // Always remove from in-progress set
        _linkGenerationInProgress.remove(typeKey);
      }
    }
  
    return typeArgs;
  }

  Future<String> _getPkgUri(mirrors.TypeMirror mirror, String packageName, String libraryUri) async {
    final realClassUri = await _findRealClassUriFromMirror(mirror, packageName);
    return mirror.location?.sourceUri.toString() ?? realClassUri ?? libraryUri;
  }

  /// Infer variance from DartType context
  TypeVariance _inferVarianceFromContext(TypeParameterType dartType) {
    // This is a simplified approach - in a real implementation you'd analyze
    // the usage context to determine variance
    return TypeVariance.invariant;
  }

  /// Infer variance from Mirror context
  TypeVariance _inferVarianceFromMirror(mirrors.TypeVariableMirror typeMirror) {
    // This is a simplified approach - in a real implementation you'd analyze
    // the usage context to determine variance
    return TypeVariance.invariant;
  }

  /// Get variance from type parameter
  TypeVariance _getVarianceFromTypeParameter(TypeParameterElement? analyzerParam, mirrors.TypeVariableMirror? mirrorParam) {
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

  /// Find the real class URI by searching through all libraries
  Future<String?> _findRealClassUri(String className, String? hintUri) async {
    // First try the hint URI if available
    if (hintUri != null) {
      final libraryElement = await _getLibraryElement(Uri.parse(hintUri));
      if (libraryElement?.getClass(className) != null ||
          libraryElement?.getMixin(className) != null ||
          libraryElement?.getEnum(className) != null) {
        return hintUri;
      }
    }

    // Search through all cached libraries
    for (final entry in _libraryElementCache.entries) {
      final libraryElement = entry.value;
      if (libraryElement.getClass(className) != null ||
          libraryElement.getMixin(className) != null ||
          libraryElement.getEnum(className) != null) {
        return entry.key;
      }
    }

    // Search through mirror system
    for (final libraryMirror in loader) {
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
  Future<String?> _findRealClassUriFromMirror(mirrors.TypeMirror typeMirror, String? packageName) async {
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

    for (final lib in loader) {
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

  /// Generate method declaration with analyzer support
  Future<MethodDeclaration> generateMethod(
    mirrors.MethodMirror methodMirror,
    Element? parentElement,
    Package package,
    String libraryUri,
    Uri sourceUri,
    String className,
    ClassDeclaration? parentClass,
  ) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);
    
    // Get appropriate analyzer element
    Element? methodElement;
    if (parentElement is InterfaceElement) {
      if (methodMirror.isGetter) {
        methodElement = parentElement.getGetter(methodName);
      } else if (methodMirror.isSetter) {
        methodElement = parentElement.getSetter(methodName);
      } else {
        methodElement = parentElement.getMethod(methodName);
      }
    }

    final dartType = (methodElement as ExecutableElement?)?.type;
    final mirrorType = methodMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, methodName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardMethodDeclaration(
      name: methodName,
      element: methodElement,
      dartType: dartType,
      type: runtimeType,
      libraryDeclaration: _libraryCache[libraryUri]!,
      returnType: await _getLinkDeclaration(methodMirror.returnType, package, libraryUri, dartType),
      annotations: await _extractAnnotations(methodMirror.metadata, package),
      isPublic: !_isInternal(methodName),
      isSynthetic: _isSynthetic(methodName),
      sourceLocation: sourceUri,
      isStatic: methodMirror.isStatic,
      isAbstract: methodMirror.isAbstract,
      isGetter: methodMirror.isGetter,
      isSetter: methodMirror.isSetter,
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
      isFactory: methodMirror.isFactoryConstructor,
      isConst: methodMirror.isConstConstructor,
    );

    result.parameters = await _extractParameters(methodMirror.parameters, methodElement?.typeParameters, package, libraryUri, result);

    return result;
  }

  /// Generate field declaration with analyzer support
  Future<FieldDeclaration> generateField(
    mirrors.VariableMirror fieldMirror,
    Element? parentElement,
    Package package,
    String libraryUri,
    Uri sourceUri,
    String className,
    ClassDeclaration? parentClass,
    String? sourceCode,
  ) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    
    // Get analyzer field element
    FieldElement? fieldElement;
    if (parentElement is InterfaceElement) {
      fieldElement = parentElement.getField(fieldName);
    }

    final dartType = fieldElement?.type;
    final mirrorType = fieldMirror.type;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, fieldName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    return StandardFieldDeclaration(
      name: fieldName,
      type: runtimeType,
      element: fieldElement,
      dartType: dartType,
      libraryDeclaration: _libraryCache[libraryUri]!,
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
      linkDeclaration: await _getLinkDeclaration(fieldMirror.type, package, libraryUri, dartType),
      annotations: await _extractAnnotations(fieldMirror.metadata, package),
      sourceLocation: sourceUri,
      isFinal: fieldMirror.isFinal,
      isConst: fieldMirror.isConst,
      isLate: _isLateField(sourceCode, fieldName),
      isStatic: fieldMirror.isStatic,
      isAbstract: false,
      isPublic: !_isInternal(fieldName),
      isSynthetic: _isSynthetic(fieldName),
      isNullable: _isNullable(
        fieldName: fieldName, 
        sourceCode: sourceCode ?? await _readSourceCode(sourceUri),
        fieldElement: fieldElement
      )
    );
  }

  /// Generate constructor declaration with analyzer support
  Future<ConstructorDeclaration> generateConstructor(
    mirrors.MethodMirror constructorMirror,
    Element? parentElement,
    Package package,
    String libraryUri,
    Uri sourceUri,
    String className,
    ClassDeclaration parentClass,
  ) async {
    final constructorName = mirrors.MirrorSystem.getName(constructorMirror.constructorName);
    
    // Get analyzer constructor element
    ConstructorElement? constructorElement;
    if (parentElement is InterfaceElement) {
      if (constructorName.isEmpty) {
        constructorElement = parentElement.unnamedConstructor;
      } else {
        constructorElement = parentElement.getNamedConstructor(constructorName);
      }
    }

    final mirrorType = constructorMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, constructorName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardConstructorDeclaration(
      name: constructorName.isEmpty ? '' : constructorName,
      type: runtimeType,
      element: constructorElement,
      dartType: constructorElement?.type,
      libraryDeclaration: _libraryCache[libraryUri]!,
      parentClass: StandardLinkDeclaration(
        name: parentClass.getName(),
        type: parentClass.getType(),
        pointerType: parentClass.getType(),
        qualifiedName: parentClass.getQualifiedName(),
        isPublic: parentClass.getIsPublic(),
        canonicalUri: Uri.parse(parentClass.getPackageUri()),
        referenceUri: Uri.parse(parentClass.getPackageUri()),
        isSynthetic: parentClass.getIsSynthetic(),
      ),
      annotations: await _extractAnnotations(constructorMirror.metadata, package),
      sourceLocation: sourceUri,
      isFactory: constructorMirror.isFactoryConstructor,
      isConst: constructorMirror.isConstConstructor,
      isPublic: !_isInternal(constructorName),
      isSynthetic: _isSynthetic(constructorName),
    );

    result.parameters = await _extractParameters(constructorMirror.parameters, constructorElement?.typeParameters, package, libraryUri, result);

    return result;
  }

  /// Generate top-level method with analyzer support
  Future<MethodDeclaration> generateTopLevelMethod(
    mirrors.MethodMirror methodMirror,
    Package package,
    String libraryUri,
    Uri sourceUri,
  ) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);
    
    final libraryElement = await _getLibraryElement(Uri.parse(libraryUri));
    
    // Get top-level function element
    ExecutableElement? functionElement;
    if (libraryElement != null) {
      functionElement = libraryElement.topLevelFunctions.where((f) => f.name == methodName).firstOrNull;
    }

    final dartType = functionElement?.type;
    final mirrorType = methodMirror.returnType;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, methodName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final result = StandardMethodDeclaration(
      name: methodName,
      element: functionElement,
      dartType: dartType,
      type: runtimeType,
      libraryDeclaration: _libraryCache[libraryUri]!,
      returnType: await _getLinkDeclaration(methodMirror.returnType, package, libraryUri, dartType),
      annotations: await _extractAnnotations(methodMirror.metadata, package),
      sourceLocation: sourceUri,
      isStatic: true,
      isAbstract: false,
      isGetter: methodMirror.isGetter,
      isSetter: methodMirror.isSetter,
      isFactory: false,
      isPublic: !_isInternal(methodName),
      isSynthetic: _isSynthetic(methodName),
      isConst: false,
    );

    result.parameters = await _extractParameters(methodMirror.parameters, functionElement?.typeParameters, package, libraryUri, result);

    return result;
  }

  /// Generate top-level field with analyzer support
  Future<FieldDeclaration> generateTopLevelField(
    mirrors.VariableMirror fieldMirror,
    Package package,
    String libraryUri,
    Uri sourceUri,
  ) async {
    final fieldName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    final libraryElement = await _getLibraryElement(Uri.parse(libraryUri));
    
    // Get top-level variable element
    TopLevelVariableElement? variableElement;
    if (libraryElement != null) {
      variableElement = libraryElement.topLevelVariables.where((v) => v.name == fieldName).firstOrNull;
    }

    final dartType = variableElement?.type;
    final mirrorType = fieldMirror.type;
    Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(mirrorType.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, fieldName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final sourceCode = await _readSourceCode(sourceUri);

    return StandardFieldDeclaration(
      name: fieldName,
      type: runtimeType,
      element: variableElement,
      dartType: dartType,
      libraryDeclaration: _libraryCache[libraryUri]!,
      parentClass: null,
      linkDeclaration: await _getLinkDeclaration(fieldMirror.type, package, libraryUri, dartType),
      annotations: await _extractAnnotations(fieldMirror.metadata, package),
      sourceLocation: sourceUri,
      isFinal: fieldMirror.isFinal,
      isConst: fieldMirror.isConst,
      isLate: false,
      isStatic: true,
      isAbstract: false,
      isPublic: !_isInternal(fieldName),
      isSynthetic: _isSynthetic(fieldName),
      isNullable: _isNullable(fieldName: fieldName, sourceCode: sourceCode)
    );
  }

  /// Generate type declaration with analyzer support
  Future<TypeDeclaration> generateType(mirrors.TypeMirror typeMirror, Package package, String libraryUri) async {
    // Handle type variables
    if (typeMirror is mirrors.TypeVariableMirror) {
      return await _generateTypeVariable(typeMirror, package, libraryUri);
    }

    // Handle dynamic and void
    if (typeMirror.runtimeType.toString() == 'dynamic') {
      return StandardTypeDeclaration(
        name: 'dynamic',
        type: dynamic,
        element: null,
        dartType: null,
        qualifiedName: _buildQualifiedName('dynamic', 'dart:core'),
        simpleName: 'dynamic',
        packageUri: 'dart:core',
        isNullable: false,
        kind: TypeKind.dynamicType,
        isPublic: true,
        isSynthetic: false,
      );
    }

    if (typeMirror.runtimeType.toString() == 'void') {
      return StandardTypeDeclaration(
        name: 'void',
        type: VoidType,
        element: null,
        dartType: null,
        qualifiedName: _buildQualifiedName('void', 'dart:core'),
        simpleName: 'void',
        packageUri: 'dart:core',
        isNullable: false,
        kind: TypeKind.voidType,
        isPublic: true,
        isSynthetic: false,
      );
    }

    Type runtimeType;
    try {
      runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;
    } catch (e) {
      runtimeType = typeMirror.runtimeType;
    }

    if (_typeCache.containsKey(runtimeType)) {
      return _typeCache[runtimeType]!;
    }

    final typeName = mirrors.MirrorSystem.getName(typeMirror.simpleName);

    // Get analyzer element for the type
    final typeElement = await _getTypeElement(typeName, Uri.parse(libraryUri));
    final dartType = typeElement != null ? (typeElement as InterfaceElement).thisType : null;

    if (_isRecordType(runtimeType)) {
      return await _generateRecordType(typeMirror, typeElement, package, libraryUri);
    }

    // Handle primitive types
    if (_isPrimitiveType(runtimeType)) {
      return StandardTypeDeclaration(
        name: typeName,
        type: runtimeType,
        element: typeElement,
        dartType: dartType,
        qualifiedName: _buildQualifiedName(typeName, 'dart:core'),
        simpleName: typeName,
        packageUri: 'dart:core',
        isNullable: false,
        kind: TypeKind.primitiveType,
        isPublic: !_isInternal(typeName),
        isSynthetic: _isSynthetic(typeName),
      );
    }

    // Extract type arguments with analyzer support - now as LinkDeclarations
    final typeArguments = <LinkDeclaration>[];
    if (typeMirror is mirrors.ClassMirror && typeMirror.typeArguments.isNotEmpty) {
      for (final arg in typeMirror.typeArguments) {
        final argLink = await _generateLinkDeclarationFromMirror(arg, package, libraryUri);
        if (argLink != null) {
          typeArguments.add(argLink);
        }
      }
    }

    // Determine type kind
    final kind = _determineTypeKind(typeMirror, dartType);

    final declaration = StandardTypeDeclaration(
      name: typeName,
      type: runtimeType,
      element: typeElement,
      dartType: dartType,
      qualifiedName: _buildQualifiedName(typeName, libraryUri),
      simpleName: typeName,
      packageUri: libraryUri,
      isNullable: false,
      kind: kind,
      typeArguments: typeArguments,
      isPublic: !_isInternal(typeName),
      isSynthetic: _isSynthetic(typeName),
    );

    _typeCache[runtimeType] = declaration;
    return declaration;
  }

  // ============================================= ANALYZER HELPERS ===========================================

  /// Get library element from analyzer
  Future<LibraryElement?> _getLibraryElement(Uri uri) async {
    final uriString = uri.toString();
    if (_libraryElementCache.containsKey(uriString)) {
      return _libraryElementCache[uriString];
    }

    if (_analysisContextCollection == null) {
      return null;
    }

    try {
      final filePath = uri.toFilePath();
      final context = _analysisContextCollection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedLibrary(filePath);
      
      if (result is ResolvedLibraryResult) {
        final libraryElement = result.element;
        _libraryElementCache[uriString] = libraryElement;
        return libraryElement;
      }
    } catch (e) {
      // Analyzer not available or file not found
    }

    return null;
  }

  /// Get class element from analyzer
  Future<ClassElement?> _getClassElement(String className, Uri sourceUri) async {
    final libraryElement = await _getLibraryElement(sourceUri);
    return libraryElement?.getClass(className);
  }

  /// Get mixin element from analyzer
  Future<MixinElement?> _getMixinElement(String mixinName, Uri sourceUri) async {
    final libraryElement = await _getLibraryElement(sourceUri);
    return libraryElement?.getMixin(mixinName);
  }

  /// Get enum element from analyzer
  Future<EnumElement?> _getEnumElement(String enumName, Uri sourceUri) async {
    final libraryElement = await _getLibraryElement(sourceUri);
    return libraryElement?.getEnum(enumName);
  }

  /// Get typedef element from analyzer
  Future<TypeAliasElement?> _getTypedefElement(String typedefName, Uri sourceUri) async {
    final libraryElement = await _getLibraryElement(sourceUri);
    return libraryElement?.getTypeAlias(typedefName);
  }

  /// Get type element from analyzer
  Future<Element?> _getTypeElement(String typeName, Uri sourceUri) async {
    final libraryElement = await _getLibraryElement(sourceUri);
    if (libraryElement == null) return null;

    // Try different element types
    return libraryElement.getClass(typeName) ??
           libraryElement.getMixin(typeName) ??
           libraryElement.getEnum(typeName) ??
           libraryElement.getTypeAlias(typeName);
  }

  // ============================================= TYPE EXTRACTION HELPERS =================================

  /// Extract parameters with analyzer support
  Future<List<ParameterDeclaration>> _extractParameters(List<mirrors.ParameterMirror> mirrorParams, List<TypeParameterElement>? analyzerParams, Package package, String libraryUri, MemberDeclaration parentMember) async {
    final parameters = <ParameterDeclaration>[];
    
    for (int i = 0; i < mirrorParams.length; i++) {
      final mirrorParam = mirrorParams[i];
      final analyzerParam = (analyzerParams != null && i < analyzerParams.length)
          ? analyzerParams[i]
          : null;
      
      final paramName = mirrors.MirrorSystem.getName(mirrorParam.simpleName);
      final dartType = analyzerParam?.bound;
      final paramType = await _getLinkDeclaration(mirrorParam.type, package, libraryUri, dartType);
      
      // Safe access to default value
      dynamic defaultValue;
      if (mirrorParam.hasDefaultValue && mirrorParam.defaultValue != null && mirrorParam.defaultValue!.hasReflectee) {
        defaultValue = mirrorParam.defaultValue!.reflectee;
      }

      final mirrorType = mirrorParam.type;
      Type runtimeType = mirrorType.hasReflectedType ? mirrorType.reflectedType : mirrorType.runtimeType;

      // Extract annotations and resolve type
      if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
        final annotations = await _extractAnnotations(mirrorType.metadata, package);
        final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, paramName);
        if (resolvedType != null) {
          runtimeType = resolvedType;
        }
      }
      final annotations = await _extractAnnotations(mirrorParam.metadata, package);
      
      parameters.add(StandardParameterDeclaration(
        name: paramName,
        element: analyzerParam,
        dartType: dartType,
        type: runtimeType,
        libraryDeclaration: _libraryCache[libraryUri]!,
        typeDeclaration: paramType,
        isOptional: mirrorParam.isOptional,
        isNamed: mirrorParam.isNamed,
        hasDefaultValue: mirrorParam.hasDefaultValue,
        defaultValue: defaultValue,
        index: i,
        memberDeclaration: parentMember,
        isPublic: !_isInternal(paramName),
        isSynthetic: _isSynthetic(paramName),
        sourceLocation: Uri.parse(libraryUri),
        annotations: annotations,
      ));
    }
    
    return parameters;
  }

  // ============================================= TYPE GENERATION HELPERS =================================

  /// Generate type variable with analyzer support
  Future<TypeVariableDeclaration> _generateTypeVariable(mirrors.TypeVariableMirror typeVarMirror, Package package, String libraryUri, {TypeParameterElement? analyzerElement}) async {
    final typeName = mirrors.MirrorSystem.getName(typeVarMirror.simpleName);
    final cacheKey = '${typeName}_${typeVarMirror.hashCode}';
    
    if (_typeVariableCache.containsKey(cacheKey)) {
      return _typeVariableCache[cacheKey]!;
    }

    // Get upper bound with analyzer support
    TypeDeclaration? upperBound;
    if (analyzerElement?.bound != null) {
      upperBound = await _generateTypeFromDartType(analyzerElement!.bound!, package, libraryUri);
    } else if (typeVarMirror.upperBound != typeVarMirror.owner?.owner && typeVarMirror.upperBound.runtimeType.toString() != 'dynamic') {
      upperBound = await generateType(typeVarMirror.upperBound, package, libraryUri);
    }

    final typeVariable = StandardTypeVariableDeclaration(
      name: typeName,
      type: Object,
      element: analyzerElement,
      dartType: null,
      qualifiedName: _buildQualifiedName(typeName, (typeVarMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      isNullable: false,
      upperBound: upperBound,
      isPublic: !_isInternal(typeName),
      isSynthetic: _isSynthetic(typeName),
      parentLibrary: _libraryCache[libraryUri]!,
      sourceLocation: typeVarMirror.location?.sourceUri,
      variance: _getVariance(analyzerElement),
    );

    _typeVariableCache[cacheKey] = typeVariable;
    return typeVariable;
  }

  TypeVariance _getVariance(TypeParameterElement? tp) {
    // Dart doesn't have explicit variance annotations yet, but we can infer
    if (tp?.name?.startsWith('in ') ?? false) return TypeVariance.contravariant;
    if (tp?.name?.startsWith('out ') ?? false) return TypeVariance.covariant;
    return TypeVariance.invariant;
  }

  /// Generate type from analyzer DartType
  Future<TypeDeclaration> _generateTypeFromDartType(DartType dartType, Package package, String libraryUri) async {
    final typeName = dartType.getDisplayString();
    
    // Try to find the actual runtime type from mirrors first
    Type runtimeType = await _findRuntimeTypeFromDartType(dartType, libraryUri, package);
    
    // Check cache first
    if (_typeCache.containsKey(runtimeType)) {
      return _typeCache[runtimeType]!;
    }

    // Handle different DartType kinds
    if (dartType is DynamicType) {
      return StandardTypeDeclaration(
        name: 'dynamic',
        type: dynamic,
        element: dartType.element,
        dartType: dartType,
        qualifiedName: _buildQualifiedName('dynamic', 'dart:core'),
        simpleName: 'dynamic',
        packageUri: 'dart:core',
        isNullable: dartType.nullabilitySuffix == NullabilitySuffix.question,
        kind: TypeKind.dynamicType,
        isPublic: true,
        isSynthetic: false,
      );
    }

    if (dartType is VoidType) {
      return StandardTypeDeclaration(
        name: 'void',
        type: VoidType,
        element: dartType.element,
        dartType: dartType,
        qualifiedName: _buildQualifiedName('void', 'dart:core'),
        simpleName: 'void',
        packageUri: 'dart:core',
        isNullable: false,
        kind: TypeKind.voidType,
        isPublic: true,
        isSynthetic: false,
      );
    }

    // Handle parameterized types - now using LinkDeclarations
    final typeArguments = <LinkDeclaration>[];
    if (dartType is ParameterizedType && dartType.typeArguments.isNotEmpty) {
      for (final arg in dartType.typeArguments) {
        final argLink = await _generateLinkDeclarationFromDartType(arg, package, libraryUri);
        if (argLink != null) {
          typeArguments.add(argLink);
        }
      }
    }

    // Determine type kind from element
    TypeKind kind = TypeKind.unknownType;
    if (dartType.element is ClassElement) {
      final classElement = dartType.element as ClassElement;
      if (classElement.isDartCoreEnum) {
        kind = TypeKind.enumType;
      } else {
        kind = TypeKind.classType;
      }
    } else if (dartType.element is MixinElement) {
      kind = TypeKind.mixinType;
    } else if (dartType.element is TypeAliasElement) {
      kind = TypeKind.typedefType;
    } else if (dartType.element is EnumElement) {
      kind = TypeKind.enumType;
    }

    final declaration = StandardTypeDeclaration(
      name: dartType.element?.name ?? typeName,
      type: runtimeType,
      element: dartType.element,
      dartType: dartType,
      qualifiedName: _buildQualifiedNameFromElement(dartType.element),
      simpleName: dartType.element?.name ?? typeName,
      packageUri: dartType.element?.library?.uri.toString() ?? libraryUri,
      isNullable: dartType.nullabilitySuffix == NullabilitySuffix.question,
      kind: kind,
      typeArguments: typeArguments,
      isPublic: !_isInternal(dartType.element?.name ?? typeName),
      isSynthetic: _isSynthetic(dartType.element?.name ?? typeName),
    );

    _typeCache[runtimeType] = declaration;
    return declaration;
  }

  /// Generate record type with analyzer support
  Future<RecordDeclaration> _generateRecordType(mirrors.TypeMirror typeMirror, Element? typeElement, Package package, String libraryUri) async {
    final recordName = typeMirror.hasReflectedType ? typeMirror.reflectedType.toString() : typeMirror.runtimeType.toString();
    final positionalFields = <RecordFieldDeclaration>[];
    final namedFields = <String, RecordFieldDeclaration>{};

    // Parse record structure from string representation
    final recordContent = recordName.substring(1, recordName.length - 1);
    final parts = _splitRecordContent(recordContent);
    
    int positionalIndex = 0;
    bool inNamedSection = false;

    Type runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;

    // Extract annotations and resolve type
    if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
      final annotations = await _extractAnnotations(typeMirror.metadata, package);
      final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, recordName);
      if (resolvedType != null) {
        runtimeType = resolvedType;
      }
    }

    final record = StandardRecordDeclaration(
      name: recordName,
      type: runtimeType,
      element: typeElement,
      dartType: (typeElement as InterfaceElement?)?.thisType,
      qualifiedName: _buildQualifiedName(recordName, (typeMirror.location?.sourceUri ?? Uri.parse(libraryUri)).toString()),
      parentLibrary: _libraryCache[libraryUri]!,
      positionalFields: positionalFields,
      namedFields: namedFields,
      annotations: await _extractAnnotations(typeMirror.metadata, package),
      sourceLocation: typeMirror.location?.sourceUri,
      isPublic: !_isInternal(recordName),
      isSynthetic: _isSynthetic(recordName),
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
      // resolvedType ??= _resolveTypeFromName(fieldTypeName);
      
      final actualType = resolvedType ?? Object;
      final actualPackageUri = _getPackageUriForType(fieldTypeName, actualType);

      // Create field type with proper resolution
      final fieldType = StandardLinkDeclaration(
        name: fieldTypeName,
        type: actualType,
        pointerType: actualType,
        qualifiedName: _buildQualifiedName(fieldTypeName, actualPackageUri),
        isPublic: !_isInternal(fieldTypeName),
        isSynthetic: _isSynthetic(fieldTypeName),
        canonicalUri: Uri.parse(actualPackageUri),
        referenceUri: Uri.parse(actualPackageUri)
      );

      if (inNamedSection) {
        final field = StandardRecordFieldDeclaration(
          name: fieldName!,
          typeDeclaration: fieldType,
          sourceLocation: typeMirror.location?.sourceUri ?? Uri.parse(libraryUri),
          type: actualType,
          libraryDeclaration: _libraryCache[libraryUri]!,
          isPublic: !_isInternal(fieldName),
          isSynthetic: _isSynthetic(fieldName),
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
          libraryDeclaration: _libraryCache[libraryUri]!,
          isPublic: !_isInternal(name),
          isSynthetic: _isSynthetic(name),
          isNullable: false
        );
        positionalFields.add(field);
        positionalIndex++;
      }
    }

    return record.copyWith(namedFields: namedFields, positionalFields: positionalFields);
  }

  // ============================================= UTILITY HELPERS =========================================

  String _getPackageUriForType(String typeName, Type actualType) {
    // Check if it's a built-in Dart type
    if (_isPrimitiveType(actualType) || 
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

  /// Read source code with caching
  Future<String> _readSourceCode(Uri uri) async {
    try {
      if (_sourceCache.containsKey(uri.toString())) {
        return _sourceCache[uri.toString()]!;
      }

      final filePath = (await resolveUri(uri) ?? uri).toFilePath();
      String fileContent = await File(filePath).readAsString();
      _sourceCache[uri.toString()] = fileContent;
      return RuntimeUtils.stripComments(fileContent);
    } catch (_) {
      return "";
    }
  }

  /// Extract annotations with enhanced field support and proper type resolution
  Future<List<AnnotationDeclaration>> _extractAnnotations(List<mirrors.InstanceMirror> metadata, Package package) async {
    final annotations = <AnnotationDeclaration>[];
    
    for (final annotation in metadata) {
      try {
        // Create LinkDeclaration for the annotation type
        final annotationType = annotation.type;
        Type type = annotationType.hasReflectedType ? annotationType.reflectedType : annotationType.runtimeType;
        final annotationName = mirrors.MirrorSystem.getName(annotationType.simpleName);

        // Extract annotations and resolve type
        if(GenericTypeParser.shouldCheckGeneric(runtimeType)) {
          final annotations = await _extractAnnotations(annotationType.metadata, package);
          final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, annotationName);
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
              final fieldType = await _getLinkDeclaration(declaration.type, package, libraryUri);

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
                isPublic: !_isInternal(fieldName),
                isSynthetic: _isSynthetic(fieldName),
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
            qualifiedName: _buildQualifiedName(annotationName, await _getPkgUri(annotationType, package.getName(), 'dart:core')),
            isPublic: !_isInternal(annotationName),
            isSynthetic: _isSynthetic(annotationName),
          ),
          instance: annotationInstance,
          fields: annotationFields,
          userProvidedValues: userProvidedValues,
          type: type,
          dartType: null,
          isPublic: !_isInternal(annotationName),
          isSynthetic: _isSynthetic(annotationName),
        ));
      } catch (e) {
        // onWarning('Failed to extract annotation: $e');
      }
    }
    
    return annotations;
  }

  /// Resolve type from @Generic annotation
  Future<Type?> _resolveTypeFromGenericAnnotation(List<AnnotationDeclaration> annotations, String name) async {
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

  Future<Type> _tryAndGetOriginalType(mirrors.ClassMirror mirror, Package package) async {
    if (mirror.isOriginalDeclaration) {
      Type type = mirror.hasReflectedType ? mirror.reflectedType : mirror.runtimeType;
      String name = mirrors.MirrorSystem.getName(mirror.simpleName);
      
      if(GenericTypeParser.shouldCheckGeneric(type)) {
        final annotations = await _extractAnnotations(mirror.metadata, package);
        final resolvedType = await _resolveTypeFromGenericAnnotation(annotations, name);
        if (resolvedType != null) {
          type = resolvedType;
        }
      }
      
      return type;
    }
    
    return mirror.hasReflectedType ? mirror.reflectedType : mirror.runtimeType;
  }

  Future<Type> _findRuntimeTypeFromDartType(DartType dartType, String libraryUri, Package package) async {
    final cacheKey = '${dartType.element?.name}_${dartType.element?.library?.uri}_${dartType.getDisplayString()}';
    if (_dartTypeToTypeCache.containsKey(cacheKey)) {
      return _dartTypeToTypeCache[cacheKey]!;
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
        _dartTypeToTypeCache[cacheKey] = resolvedType;
        return resolvedType;
      }
    }

    // Try to find the type in our mirror system
    if (elementName != null) {
      // Look through all libraries to find a matching class
      for (final libraryMirror in loader) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName) {
              try {
                final runtimeType = await _tryAndGetOriginalType(declaration, package);
                _dartTypeToTypeCache[cacheKey] = runtimeType;
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
    
    _dartTypeToTypeCache[cacheKey] = fallbackType;
    return fallbackType;
  }

  /// Find base runtime type from DartType (without type parameters)
  Future<Type> _findBaseRuntimeTypeFromDartType(DartType dartType, String libraryUri, Package package) async {
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
      for (final libraryMirror in loader) {
        for (final declaration in libraryMirror.declarations.values) {
          if (declaration is mirrors.ClassMirror) {
            final className = mirrors.MirrorSystem.getName(declaration.simpleName);
            if (className == elementName) {
              try {
                return await _tryAndGetOriginalType(declaration, package);
              } catch (e) {
                // Continue searching
              }
            }
          }
        }
      }
    }

    // Fallback to the actual runtime type
    return await _findRuntimeTypeFromDartType(dartType, libraryUri, package);
  }

  /// Build qualified name from library URI and type name
  String _buildQualifiedName(String typeName, String libraryUri) {
    return '$libraryUri.$typeName'.replaceAll("..", '.');
  }

  /// Checks if a URI represents a built-in Dart library
  bool _isBuiltInDartLibrary(Uri uri) {
    return uri.scheme == 'dart';
  }

  /// Build qualified name from analyzer element
  String _buildQualifiedNameFromElement(Element? element) {
    if (element == null) return 'unknown';
    
    final library = element.library;
    if (library == null) {
      return _buildQualifiedName(element.name ?? 'unknown', 'unknown');
    }
    
    return _buildQualifiedName(element.name ?? 'unknown', library.uri.toString());
  }

  /// Create default package
  Package _createDefaultPackage(String name) {
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
  Package _createBuiltInPackage() {
    return PackageImplementation(
      name: Constant.DART_PACKAGE_NAME,
      version: _packageCache.values.where((v) => v.getIsRootPackage()).firstOrNull?.getLanguageVersion() ?? '3.0',
      languageVersion: _packageCache.values.where((v) => v.getIsRootPackage()).firstOrNull?.getLanguageVersion() ?? '3.0',
      isRootPackage: false,
      rootUri: 'dart:core',
      filePath: null,
    );
  }

  /// Determine type kind from mirror
  TypeKind _determineTypeKind(mirrors.TypeMirror typeMirror, DartType? dartType) {
    if (typeMirror.runtimeType.toString() == 'dynamic') return TypeKind.dynamicType;
    if (typeMirror.runtimeType.toString() == 'void') return TypeKind.voidType;
    
    if (typeMirror is mirrors.ClassMirror) {
      if (typeMirror.isEnum) return TypeKind.enumType;
      final runtimeType = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;
      if (_isPrimitiveType(runtimeType)) return TypeKind.primitiveType;
      if (_isListType(runtimeType)) return TypeKind.listType;
      if (_isMapType(runtimeType)) return TypeKind.mapType;
      if (_isRecordType(runtimeType)) return TypeKind.recordType;
      return TypeKind.classType;
    }
    
    if (typeMirror is mirrors.TypedefMirror) return TypeKind.typedefType;
    if (typeMirror is mirrors.FunctionTypeMirror) return TypeKind.functionType;
    
    return TypeKind.unknownType;
  }

  /// Check if type is primitive
  bool _isPrimitiveType(Type type) {
    return type == int || type == double || type == bool || type == String || type == num;
  }

  /// Check if type is List
  bool _isListType(Type type) {
    return type.toString().startsWith('List<') || type == List;
  }

  /// Check if type is Map
  bool _isMapType(Type type) {
    return type.toString().startsWith('Map<') || type == Map;
  }

  /// Check if type is Record
  bool _isRecordType(Type type) {
    return type.toString().startsWith('(') && type.toString().endsWith(')');
  }

  /// Check class modifiers from source code
  bool _isSealedClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bsealed\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  bool _isBaseClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bbase\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  bool _isFinalClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bfinal\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  bool _isInterfaceClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\binterface\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  bool _isMixinClass(String? sourceCode, String className) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\bmixin\s+class\s+' + RegExp.escape(className) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  bool _isLateField(String? sourceCode, String fieldName) {
    if (sourceCode == null) return false;
    final pattern = RegExp(r'\blate\s+[^;]*\b' + RegExp.escape(fieldName) + r'\b');
    return pattern.hasMatch(sourceCode);
  }

  bool _isMirrorSyntheticType(String name) {
    // Match X followed by digits (X0, X1, X2, etc.)
    return RegExp(r'^X\d+$').hasMatch(name);
  }

  bool _isInternal(String name) {
    // Find the last slash or colon
    final sepIndex = name.lastIndexOf(RegExp(r'[/\\:]'));
    final segment = sepIndex >= 0 ? name.substring(sepIndex + 1) : name;

    // Internal if segment starts with _ but not __
    return segment.startsWith('_') && !segment.startsWith('__');
  }

  bool _isSynthetic(String name) => name.startsWith("__") || name.contains("&");

  bool _isNullable({FieldElement? fieldElement, String? sourceCode, required String fieldName}) {
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

  /// Split record content string into components
  List<String> _splitRecordContent(String content) {
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
}