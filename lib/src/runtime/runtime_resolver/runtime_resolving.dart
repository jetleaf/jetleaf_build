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

import 'dart:mirrors' as mirrors;

import '../../constant.dart';
import '../../declaration/declaration.dart';
import '../utils/file_utility.dart';
import '../runtime_hint/default_runtime_hint_descriptor.dart';
import '../runtime_hint/runtime_hint_descriptor.dart';
import '../runtime_hint/runtime_hint_processor.dart';
import 'aot_runtime_resolver.dart';
import 'fallback_runtime_resolver.dart';
import 'jit_runtime_resolver.dart';
import 'runtime_resolver.dart';

/// {@template generative_executable}
/// Global runtime hint descriptor used for AOT resolution.
/// 
/// Initialized with default values and can be modified by [RuntimeHintProcessor]s.
/// {@endtemplate}
RuntimeHintDescriptor _executable = DefaultRuntimeHintDescriptors();

/// {@template runtime_resolving}
/// Orchestrates the runtime resolution process for JetLeaf reflection.
///
/// Handles the complete pipeline from code generation to resolver instantiation,
/// including:
/// - AOT resolver generation
/// - Runtime hint processing
/// - Resolver selection strategy
///
/// {@template runtime_resolving_features}
/// ## Key Responsibilities
/// - Generates AOT resolvers for discovered types
/// - Processes runtime hint configurations
/// - Selects appropriate resolution strategy (AOT/JIT)
/// - Manages resolver fallback behavior
/// {@endtemplate}
///
/// {@template runtime_resolving_flow}
/// ## Resolution Process
/// 1. Generates AOT resolvers for discovered types
/// 2. Processes runtime hint configurations
/// 3. Creates primary AOT resolver with generated code
/// 4. Sets up fallback to JIT resolution when needed
/// {@endtemplate}
/// {@endtemplate}
class RuntimeResolving {
  /// The mirror system providing reflection capabilities
  final mirrors.MirrorSystem access;

  /// List of library declarations to process
  final List<LibraryDeclaration> libraries;

  /// Additional libraries that should be force-loaded
  final List<mirrors.LibraryMirror> forceLoadedMirrors;

  /// Output directory for generated resolvers
  final String outputFolder;

  /// File utility operations
  final FileUtility fileUtils;

  /// Current package name
  final String package;

  /// Info logging callback
  final void Function(String message) logInfo;

  /// Warning logging callback
  final void Function(String message) logWarning;

  /// Error logging callback
  final void Function(String message) logError;

  /// Creates a new RuntimeResolving instance
  ///
  /// {@template runtime_resolving_constructor}
  /// Parameters:
  /// - [access]: Mirror system for reflection
  /// - [libraries]: Libraries to process
  /// - [forceLoadedMirrors]: Additional libraries to load
  /// - [outputFolder]: Where to generate resolver files
  /// - [fileUtils]: File operations handler
  /// - [package]: Current package name
  /// - [logInfo]: Info logging callback
  /// - [logWarning]: Warning logging callback
  /// - [logError]: Error logging callback
  /// {@endtemplate}
  RuntimeResolving({
    required this.access,
    required this.libraries,
    required this.forceLoadedMirrors,
    required this.outputFolder,
    required this.fileUtils,
    required this.package,
    required this.logInfo,
    required this.logWarning,
    required this.logError,
  });

  /// Executes the complete resolution process
  ///
  /// {@template resolve_method}
  /// Returns:
  /// - A configured [RuntimeResolver] instance
  ///
  /// Process:
  /// 1. Generates AOT resolvers for discovered types
  /// 2. Processes runtime hint configurations
  /// 3. Creates resolver with fallback strategy
  ///
  /// Example:
  /// ```dart
  /// final resolver = await RuntimeResolving(...).resolve();
  /// ```
  /// {@endtemplate}
  Future<RuntimeResolver> resolve() async {
    // Determine Compiler and ExecutableResolver
    return await _prepareResolver([...access.libraries.values, ...forceLoadedMirrors]);
  }

  /// Prepares the appropriate resolver strategy
  ///
  /// {@template prepare_resolver}
  /// Parameters:
  /// - [libraries]: Libraries to include in resolution
  ///
  /// Returns:
  /// - A [RuntimeResolver] with AOT primary and JIT fallback
  ///
  /// Internal method that:
  /// 1. Processes runtime hints
  /// 2. Creates AOT resolver
  /// 3. Wraps with fallback to JIT
  /// {@endtemplate}
  Future<RuntimeResolver> _prepareResolver(List<mirrors.LibraryMirror> libraries) async {
    await _analyzeAndProcessGenerativeExecutables(libraries);
    final primaryResolver = AotRuntimeResolver(_executable);

    return FallbackRuntimeResolver(primaryResolver, JitRuntimeResolver());
  }

  /// Processes RuntimeHintProcessor implementations and annotations
  ///
  /// {@template analyze_executables}
  /// Parameters:
  /// - [libraries]: Libraries to scan for processors
  ///
  /// Scans for and executes all [RuntimeHintProcessor] implementations,
  /// allowing them to modify the global [_executable] configuration.
  /// {@endtemplate}
  Future<void> _analyzeAndProcessGenerativeExecutables(List<mirrors.LibraryMirror> libraries) async {
    final runtimeClassMirror = mirrors.reflectClass(RuntimeHintProcessor);

    final foundConfigurableExecutables = <RuntimeHintProcessor>[];
    List<mirrors.DeclarationMirror> declarations = libraries.flatMap((lib) => lib.declarations.values).toList();

    for (final declaration in declarations) {
      // Process RuntimeHintProcessor implementations
      if (declaration is mirrors.ClassMirror && !declaration.isAbstract && declaration.isSubtypeOf(runtimeClassMirror)) {
        try {
          logInfo('Found RuntimeHintProcessor implementation: ${mirrors.MirrorSystem.getName(declaration.simpleName)} from ${declaration.location?.sourceUri}');
          final instance = declaration.newInstance(Symbol(''), []).reflectee as RuntimeHintProcessor;
          foundConfigurableExecutables.add(instance);
        } catch (e, stack) {
          logWarning('Could not instantiate RuntimeHintProcessor ${mirrors.MirrorSystem.getName(declaration.simpleName)} (expected no-arg constructor): $e\n$stack');
        }
      }
    }

    // Proceed all found RuntimeHintProcessor instances
    for (final executable in foundConfigurableExecutables) {
      try {
        executable.proceed(_executable);
      } catch (e, stack) {
        logWarning('Error proceeding RuntimeHintProcessor ${executable.runtimeType}: $e\n$stack');
      }
    }
  }
}