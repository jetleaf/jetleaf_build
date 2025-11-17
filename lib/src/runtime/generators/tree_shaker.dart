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

import 'dart:collection';

import '../../declaration/declaration.dart';

/// {@template tree_shaker}
/// Performs tree-shaking analysis to determine which classes are actually used
/// by the user's code, either directly or indirectly through dependencies.
/// 
/// This class analyzes the dependency graph starting from user-defined classes
/// and follows all references to determine the minimal set of classes needed
/// at runtime, similar to how Dart's tree-shaking works.
/// {@endtemplate}
class TreeShaker {
  final Set<String> _visited = <String>{};
  final Set<String> _usedClasses = <String>{};
  final Map<String, TypeDeclaration> _allClasses = <String, TypeDeclaration>{};
  final Map<String, Set<String>> _dependencies = <String, Set<String>>{};

  /// {@macro tree_shaker}
  TreeShaker();

  /// Performs tree-shaking analysis on the provided libraries.
  /// 
  /// Returns a set of class qualified names that are actually used.
  /// 
  /// **Parameters:**
  /// - [libraries]: All library declarations to analyze
  /// - [userPackageNames]: Names of packages that belong to the user (not dependencies)
  /// 
  /// **Returns:** Set of qualified class names that should be included
  Set<String> shake(List<LibraryDeclaration> libraries, Set<String> userPackageNames) {
    _buildDependencyGraph(libraries);
    _findUserClasses(libraries, userPackageNames);
    _performTreeShaking();
    
    return Set.from(_usedClasses);
  }

  /// Builds a dependency graph of all classes and their relationships
  void _buildDependencyGraph(List<LibraryDeclaration> libraries) {
    // First pass: collect all classes
    for (final library in libraries) {
      for (final declaration in library.getDeclarations()) {
        if (declaration is TypeDeclaration) {
          final decl = declaration as TypeDeclaration;
          final qualifiedName = decl.getQualifiedName();
          _allClasses[qualifiedName] = decl;
          _dependencies[qualifiedName] = <String>{};
        }
      }
    }

    // Second pass: build dependency relationships
    for (final library in libraries) {
      for (final declaration in library.getDeclarations()) {
        if (declaration is ClassDeclaration) {
          final qualifiedName = declaration.getQualifiedName();
          final dependencies = _dependencies[qualifiedName]!;

          // Add superclass dependency
          final superclass = declaration.getSuperClass();
          if (superclass != null) {
            final superQualifiedName = _getQualifiedNameFromLink(superclass);
            if (superQualifiedName != null) {
              dependencies.add(superQualifiedName);
            }
          }

          // Add interface dependencies
          for (final interface in declaration.getInterfaces()) {
            final interfaceQualifiedName = _getQualifiedNameFromLink(interface);
            if (interfaceQualifiedName != null) {
              dependencies.add(interfaceQualifiedName);
            }
          }

          // Add mixin dependencies
          for (final mixin in declaration.getMixins()) {
            final mixinQualifiedName = _getQualifiedNameFromLink(mixin);
            if (mixinQualifiedName != null) {
              dependencies.add(mixinQualifiedName);
            }
          }

          // Add field type dependencies
          for (final field in declaration.getFields()) {
            final fieldTypeQualifiedName = field.getLinkDeclaration().getPointerQualifiedName();
            dependencies.add(fieldTypeQualifiedName);

            // Add generic type argument dependencies
            _addGenericTypeDependencies(field.getLinkDeclaration(), dependencies);
          }

          // Add method dependencies
          for (final method in declaration.getMethods()) {
            // Return type dependency
            final returnTypeQualifiedName = method.getReturnType().getPointerQualifiedName();
            dependencies.add(returnTypeQualifiedName);
            _addGenericTypeDependencies(method.getReturnType(), dependencies);

            // Parameter type dependencies
            for (final param in method.getParameters()) {
              final paramTypeQualifiedName = param.getLinkDeclaration().getPointerQualifiedName();
              dependencies.add(paramTypeQualifiedName);
              _addGenericTypeDependencies(param.getLinkDeclaration(), dependencies);
            }
          }

          // Add constructor dependencies
          for (final constructor in declaration.getConstructors()) {
            for (final param in constructor.getParameters()) {
              final paramTypeQualifiedName = param.getLinkDeclaration().getPointerQualifiedName();
              dependencies.add(paramTypeQualifiedName);
              _addGenericTypeDependencies(param.getLinkDeclaration(), dependencies);
            }
          }

          // Add annotation dependencies
          for (final annotation in declaration.getAnnotations()) {
            final annotationQualifiedName = annotation.getLinkDeclaration().getPointerQualifiedName();
            dependencies.add(annotationQualifiedName);
          }
        }
      }
    }
  }

  /// Adds dependencies from generic type arguments
  void _addGenericTypeDependencies(LinkDeclaration linkDecl, Set<String> dependencies) {
    if (linkDecl.getTypeArguments().isNotEmpty) {
      for (final typeArg in linkDecl.getTypeArguments()) {
        final argQualifiedName = typeArg.getPointerQualifiedName();
        dependencies.add(argQualifiedName);
      }
    }
  }

  /// Extracts qualified name from a LinkDeclaration
  String? _getQualifiedNameFromLink(LinkDeclaration link) {
    return link.getPointerQualifiedName();
  }

  /// Identifies all classes that belong to the user's code
  void _findUserClasses(List<LibraryDeclaration> libraries, Set<String> userPackageNames) {
    for (final library in libraries) {
      final packageName = library.getPackage().getName();
      
      if (userPackageNames.contains(packageName)) {
        for (final declaration in library.getDeclarations()) {
          if (declaration is TypeDeclaration && declaration.getIsPublic()) {
            _usedClasses.add((declaration as TypeDeclaration).getQualifiedName());
          }
        }
      }
    }
  }

  /// Performs the actual tree-shaking by following dependencies
  void _performTreeShaking() {
    final queue = Queue<String>.from(_usedClasses);
    
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      
      if (_visited.contains(current)) {
        continue;
      }
      
      _visited.add(current);
      
      final dependencies = _dependencies[current];
      if (dependencies != null) {
        for (final dependency in dependencies) {
          if (!_visited.contains(dependency) && _allClasses.containsKey(dependency)) {
            _usedClasses.add(dependency);
            queue.add(dependency);
          }
        }
      }
    }
  }
}