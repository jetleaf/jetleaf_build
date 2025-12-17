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

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../declaration/declaration.dart';

/// {@template declaration_file_writer}
/// Writes generated declarations to separate files organized by packages.
/// 
/// Creates a structured file system where each package gets its own folder
/// and runtime declaration classes are written to individual files. Also generates 
/// a main runtime provider that imports everything for easy access.
/// 
/// File structure:
/// ```
/// runtime_declarations/
/// ├── dart_core_runtime_declaration.dart
/// ├── dart_async_runtime_declaration.dart
/// ├── my_package_runtime_declaration.dart
/// └── generated_runtime_provider.dart  // Main provider file
/// ```
/// {@endtemplate}
class DeclarationFileWriter {
  final String _outputPath;
  final Map<String, Set<String>> _packageImports = {};
  final Map<String, String> _classToPackage = {};
  final bool _refresh;

  /// {@macro declaration_file_writer}
  DeclarationFileWriter(this._outputPath, this._refresh);

  /// Writes all declarations to organized runtime declaration files
  /// 
  /// **Parameters:**
  /// - [libraries]: All library declarations to write
  /// - [usedClasses]: Set of class qualified names that should be included (for tree-shaking)
  /// - [enableTreeShaking]: Whether to apply tree-shaking filtering
  Future<void> writeDeclarations(List<LibraryDeclaration> libraries, Set<String> usedClasses, bool enableTreeShaking) async {
    final runtimeDir = Directory(_outputPath);
    if (await runtimeDir.exists() && _refresh) {
      await runtimeDir.delete(recursive: true);
    }

    await runtimeDir.create(recursive: true);

    // Group declarations by package
    final packageDeclarations = <String, List<LibraryDeclaration>>{};
    
    for (final library in libraries) {
      final packageName = library.getPackage().getName();
      packageDeclarations.putIfAbsent(packageName, () => []).add(library);
      
      // Track classes for tree-shaking
      for (final declaration in library.getDeclarations()) {
        if (declaration is TypeDeclaration) {
          final qualifiedName = (declaration as TypeDeclaration).getQualifiedName();
          
          // Apply tree-shaking filter if enabled
          if (enableTreeShaking && !usedClasses.contains(qualifiedName)) {
            continue;
          }
          
          _classToPackage[(declaration as TypeDeclaration).getSimpleName()] = packageName;
        }
      }
    }

    // Write each package's runtime declaration
    for (final entry in packageDeclarations.entries) {
      await _writePackageRuntimeDeclaration(entry.key, entry.value, runtimeDir, usedClasses, enableTreeShaking);
    }

    // Write main generated runtime provider file
    await _writeGeneratedRuntimeProvider(runtimeDir);
  }

  /// Writes runtime declaration for a specific package
  Future<void> _writePackageRuntimeDeclaration(String packageName, List<LibraryDeclaration> libraries, Directory runtimeDir, Set<String> usedClasses, bool enableTreeShaking) async {
    final sanitizedPackageName = _sanitizePackageName(packageName);
    final fileName = '${sanitizedPackageName}_runtime_declaration.dart';
    final file = File(p.join(runtimeDir.path, fileName));

    final buffer = StringBuffer();
    
    // File header
    buffer.writeln('// Generated runtime declaration for $packageName package');
    buffer.writeln('// This file is auto-generated. Do not edit manually.');
    buffer.writeln();

    final imports = _generateImportsForPackage(packageName, libraries);
    for (final import in imports) {
      buffer.writeln(import);
    }
    if (imports.isNotEmpty) {
      buffer.writeln();
    }

    // Import the base RuntimeDeclaration
    buffer.writeln("import 'package:jetleaf_lang/lang.dart';");
    buffer.writeln();

    buffer.writeln('/// Runtime declaration class for $packageName package');
    buffer.writeln('class ${_toPascalCase(sanitizedPackageName)}RuntimeDeclaration extends RuntimeDeclaration {');
    buffer.writeln('  @override');
    buffer.writeln('  List<LibraryDeclaration> getLibraryDeclarations() => [');
    
    // Generate library declarations with proper type resolution
    for (final library in libraries) {
      buffer.writeln('    ${_generateLibraryDeclarationCode(library, usedClasses, enableTreeShaking)},');
    }
    
    buffer.writeln('  ];');
    buffer.writeln('}');

    await file.writeAsString(buffer.toString());
    _packageImports[packageName] = {fileName};
  }

  /// Generates import statements for a package
  List<String> _generateImportsForPackage(String packageName, List<LibraryDeclaration> libraries) {
    final imports = <String>[];
    final processedUris = <String>{};

    final dartLibraries = [
      'dart:async', 'dart:collection', 'dart:convert', 'dart:ffi', 'dart:io', 
      'dart:isolate', 'dart:math', 'dart:mirrors', 'dart:typed_data'
    ];
    
    for (final dartLib in dartLibraries) {
      final alias = dartLib.replaceAll(':', '_');
      imports.add("import '$dartLib' as $alias;");
    }

    // Add package imports based on dependencies found in libraries
    for (final library in libraries) {
      for (final declaration in library.getDeclarations()) {
        if (declaration is ClassDeclaration) {
          _addImportsForClassDeclaration(declaration, imports, processedUris);
        }
      }
    }

    return imports.toSet().toList()..sort();
  }

  /// Adds imports needed for a class declaration
  void _addImportsForClassDeclaration(ClassDeclaration classDecl, List<String> imports, Set<String> processedUris) {
    // Add imports for superclass, interfaces, mixins
    final superclass = classDecl.getSuperClass();
    if (superclass != null) {
      _addImportForLinkDeclaration(superclass, imports, processedUris);
    }

    for (final interface in classDecl.getInterfaces()) {
      _addImportForLinkDeclaration(interface, imports, processedUris);
    }

    for (final mixin in classDecl.getMixins()) {
      _addImportForLinkDeclaration(mixin, imports, processedUris);
    }

    // Add imports for field types
    for (final field in classDecl.getFields()) {
      _addImportForLinkDeclaration(field.getLinkDeclaration(), imports, processedUris);
    }

    // Add imports for method types
    for (final method in classDecl.getMethods()) {
      _addImportForLinkDeclaration(method.getReturnType(), imports, processedUris);
      for (final param in method.getParameters()) {
        _addImportForLinkDeclaration(param.getLinkDeclaration(), imports, processedUris);
      }
    }
  }

  /// Adds import for a LinkDeclaration
  void _addImportForLinkDeclaration(LinkDeclaration linkDecl, List<String> imports, Set<String> processedUris) {
    final canonicalUri = linkDecl.getCanonicalUri();
    if (canonicalUri != null && !processedUris.contains(canonicalUri.toString())) {
      processedUris.add(canonicalUri.toString());
      final alias = _uriToAlias(canonicalUri.toString());
      imports.add("import '${canonicalUri.toString()}' as $alias;");
    }

    // Add imports for type arguments
    for (final typeArg in linkDecl.getTypeArguments()) {
      _addImportForLinkDeclaration(typeArg, imports, processedUris);
    }
  }

  /// Generates the library declaration code
  String _generateLibraryDeclarationCode(LibraryDeclaration library, Set<String> usedClasses, bool enableTreeShaking) {
    final buffer = StringBuffer();
    
    buffer.writeln('StandardLibraryDeclaration(');
    buffer.writeln('      name: \'${library.getName()}\',');
    buffer.writeln('      uri: \'${library.getUri()}\',');
    buffer.writeln('      package: ${_generatePackageCode(library.getPackage())},');
    buffer.writeln('      declarations: [');
    
    // Generate declarations with proper type resolution
    for (final declaration in library.getDeclarations()) {
      if (declaration is TypeDeclaration) {
        final qualifiedName = (declaration as TypeDeclaration).getQualifiedName();
        
        // Apply tree-shaking filter if enabled
        if (enableTreeShaking && !usedClasses.contains(qualifiedName)) {
          continue;
        }
        
        buffer.writeln('        ${_generateTypeDeclarationCode(declaration as TypeDeclaration)},');
      }
    }
    
    buffer.writeln('      ],');
    buffer.writeln('    )');
    
    return buffer.toString();
  }

  /// Generates package code
  String _generatePackageCode(Package package) {
    return 'StandardPackage(name: \'${package.getName()}\', version: \'${package.getVersion()}\', isRootPackage: ${package.getIsRootPackage()})';
  }

  /// Generates type declaration code with proper type references
  String _generateTypeDeclarationCode(TypeDeclaration typeDecl) {
    if (typeDecl is ClassDeclaration) {
      return _generateClassDeclarationCode(typeDecl);
    }
    // Handle other type declarations as needed
    return 'null /* Unsupported type declaration */';
  }

  /// Generates class declaration code
  String _generateClassDeclarationCode(ClassDeclaration classDecl) {
    final buffer = StringBuffer();
    final qualifiedName = classDecl.getQualifiedName();
    final typeReference = _resolveTypeReference(qualifiedName);
    
    buffer.writeln('StandardClassDeclaration(');
    buffer.writeln('        name: \'${classDecl.getName()}\',');
    buffer.writeln('        type: $typeReference,');
    buffer.writeln('        qualifiedName: \'$qualifiedName\',');
    buffer.writeln('        simpleName: \'${classDecl.getSimpleName()}\',');
    buffer.writeln('        packageUri: \'${classDecl.getPackageUri()}\',');
    buffer.writeln('        isPublic: ${classDecl.getIsPublic()},');
    buffer.writeln('        isSynthetic: ${classDecl.getIsSynthetic()},');
    
    // Add superclass, interfaces, mixins with LinkDeclarations
    final superclass = classDecl.getSuperClass();
    if (superclass != null) {
      buffer.writeln('        superClass: ${_generateLinkDeclarationCode(superclass)},');
    }
    
    buffer.writeln('        interfaces: [${classDecl.getInterfaces().map(_generateLinkDeclarationCode).join(', ')}],');
    buffer.writeln('        mixins: [${classDecl.getMixins().map(_generateLinkDeclarationCode).join(', ')}],');
    
    // Add fields, methods, constructors
    buffer.writeln('        fields: [${classDecl.getFields().map(_generateFieldDeclarationCode).join(', ')}],');
    buffer.writeln('        methods: [${classDecl.getMethods().map(_generateMethodDeclarationCode).join(', ')}],');
    buffer.writeln('        constructors: [${classDecl.getConstructors().map(_generateConstructorDeclarationCode).join(', ')}],');
    
    buffer.writeln('      )');
    
    return buffer.toString();
  }

  /// Generates LinkDeclaration code
  String _generateLinkDeclarationCode(LinkDeclaration linkDecl) {
    final typeReference = _resolveTypeReference(linkDecl.getPointerQualifiedName());
    return 'StandardLinkDeclaration(name: \'${linkDecl.getName()}\', type: $typeReference, pointerType: $typeReference, qualifiedName: \'${linkDecl.getPointerQualifiedName()}\', isPublic: ${linkDecl.getIsPublic()}, isSynthetic: ${linkDecl.getIsSynthetic()})';
  }

  /// Generates field declaration code
  String _generateFieldDeclarationCode(FieldDeclaration fieldDecl) {
    final typeReference = _resolveTypeReference(fieldDecl.getLinkDeclaration().getPointerQualifiedName());
    return 'StandardFieldDeclaration(name: \'${fieldDecl.getName()}\', type: $typeReference, typeDeclaration: ${_generateLinkDeclarationCode(fieldDecl.getLinkDeclaration())}, isPublic: ${fieldDecl.getIsPublic()}, isSynthetic: ${fieldDecl.getIsSynthetic()}, isFinal: ${fieldDecl.getIsFinal()}, isConst: ${fieldDecl.getIsConst()}, isStatic: ${fieldDecl.getIsStatic()})';
  }

  /// Generates method declaration code
  String _generateMethodDeclarationCode(MethodDeclaration methodDecl) {
    return 'StandardMethodDeclaration(name: \'${methodDecl.getName()}\', returnType: ${_generateLinkDeclarationCode(methodDecl.getReturnType())}, isPublic: ${methodDecl.getIsPublic()}, isSynthetic: ${methodDecl.getIsSynthetic()}, isStatic: ${methodDecl.getIsStatic()}, isAbstract: ${methodDecl.getIsAbstract()})';
  }

  /// Generates constructor declaration code
  String _generateConstructorDeclarationCode(ConstructorDeclaration constructorDecl) {
    return 'StandardConstructorDeclaration(name: \'${constructorDecl.getName()}\', isPublic: ${constructorDecl.getIsPublic()}, isSynthetic: ${constructorDecl.getIsSynthetic()})';
  }

  /// Resolves type reference with proper package prefixes
  String _resolveTypeReference(String qualifiedName) {
    final parts = qualifiedName.split('.');
    if (parts.length >= 2) {
      final packageUri = parts.first;
      final typeName = parts.last;
      final alias = _uriToAlias(packageUri);
      return '$alias.$typeName';
    }
    return qualifiedName;
  }

  /// Converts URI to alias
  String _uriToAlias(String uri) {
    return uri.replaceAll(':', '_').replaceAll('/', '_').replaceAll('.', '_');
  }

  /// Writes the main generated runtime provider file
  Future<void> _writeGeneratedRuntimeProvider(Directory runtimeDir) async {
    final file = File(p.join(runtimeDir.path, 'generated_runtime_provider.dart'));
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// Generated runtime provider');
    buffer.writeln('// This file is auto-generated. Do not edit manually.');
    buffer.writeln();

    // Import base classes
    buffer.writeln("import 'package:jetleaf_lang/lang.dart';");
    buffer.writeln();

    // Import all runtime declaration files
    for (final entry in _packageImports.entries) {
      final packageName = entry.key;
      final sanitizedPackageName = _sanitizePackageName(packageName);
      buffer.writeln("import '${sanitizedPackageName}_runtime_declaration.dart';");
    }
    buffer.writeln();

    // Generate the main runtime provider class
    buffer.writeln('/// Generated runtime provider that extends ConfigurableRuntimeProvider');
    buffer.writeln('class GeneratedRuntimeProvider extends ConfigurableRuntimeProvider {');
    buffer.writeln('  GeneratedRuntimeProvider() {');
    buffer.writeln('    _loadAllDeclarations();');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  void _loadAllDeclarations() {');
    
    // Add all runtime declarations
    for (final entry in _packageImports.entries) {
      final packageName = entry.key;
      final sanitizedPackageName = _sanitizePackageName(packageName);
      final className = _toPascalCase(sanitizedPackageName);
      buffer.writeln('    final ${sanitizedPackageName}Runtime = ${className}RuntimeDeclaration();');
      buffer.writeln('    addLibraries(${sanitizedPackageName}Runtime.getLibraryDeclarations());');
    }
    
    buffer.writeln('  }');
    buffer.writeln('}');

    await file.writeAsString(buffer.toString());
  }

  /// Sanitizes package name for use as Dart identifier
  String _sanitizePackageName(String packageName) {
    return packageName
        .replaceAll('-', '_')
        .replaceAll('.', '_')
        .replaceAll(':', '_');
  }

  /// Converts snake_case to PascalCase
  String _toPascalCase(String input) {
    return input
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join('');
  }
}