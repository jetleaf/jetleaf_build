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

import 'package:meta/meta.dart';

import '../../../builder/runtime_builder.dart';
import '../../../utils/constant.dart';
import '../../hint/default_runtime_hint_descriptor.dart';
import '../../hint/runtime_hint.dart';
import '../../hint/runtime_hint_descriptor.dart';
import '../../hint/runtime_hint_provider.dart';
import 'runtime_executor_resolving.dart';

/// An abstract base class that provides the core logic for discovering,
/// instantiating, and managing runtime hints and descriptors used by
/// JetLeaf's runtime executors.
///
/// This class is responsible for scanning additional Dart libraries provided
/// at runtime to identify classes that implement [RuntimeHint] or
/// [RuntimeHintDescriptor], either as concrete classes or via annotations.
///
/// Subclasses typically combine these hints with primary and fallback
/// runtime executors to form a unified [RuntimeExecutor] that supports both
/// Ahead-of-Time (AOT) and Just-in-Time (JIT) execution paths.
///
/// ## Responsibilities
/// - Discover [RuntimeHintDescriptor] implementations and instantiate them.
/// - Discover [RuntimeHint] implementations and annotations and instantiate them.
/// - Provide logging hooks to track discovered hints and any instantiation errors.
/// - Serve as a foundation for hybrid runtime executor setups that combine
///   generative and mirror-based resolution strategies.
abstract class AbstractRuntimeExecutorResolving extends RuntimeExecutorResolving {
  /// Constructs an instance of [AbstractRuntimeExecutorResolving].
  ///
  /// Parameters:
  /// - [libraries]: Additional libraries to scan for runtime descriptors
  ///   and processors.
  AbstractRuntimeExecutorResolving({required super.libraries});

  /// Finds and instantiates any configured [RuntimeHintDescriptor] in the
  /// provided libraries.
  ///
  /// This method scans all class declarations in the given [libraries],
  /// excluding [DefaultRuntimeHintDescriptor]. It attempts to instantiate
  /// each non-abstract class that extends [RuntimeHintDescriptor] using
  /// a no-argument constructor.  
  ///
  /// - If multiple descriptors are found, the first one is returned.
  /// - If no descriptor is found, returns an instance of
  ///   [DefaultRuntimeHintDescriptor].
  ///
  /// Parameters:
  /// - [libraries]: The list of libraries to search.
  ///
  /// Returns:
  /// - A fully instantiated [RuntimeHintDescriptor] to configure runtime
  ///   behavior.
  @protected
  Future<RuntimeHintDescriptor> getRuntimeHintDescriptor(List<mirrors.LibraryMirror> libraries) async {
    final runtimeClassMirror = mirrors.reflectClass(RuntimeHintDescriptor);
    final defaultRuntimeMirror = mirrors.reflectClass(DefaultRuntimeHintDescriptor);

    final descriptors = <RuntimeHintDescriptor>[];
    List<mirrors.DeclarationMirror> declarations = libraries.flatMap((lib) => lib.declarations.values).toList();

    for (final declaration in declarations) {
      if (declaration case mirrors.ClassMirror classMirror) {
        if (classMirror == defaultRuntimeMirror || classMirror.qualifiedName == defaultRuntimeMirror.qualifiedName) {
          continue;
        }

        if (!classMirror.isAbstract && classMirror.isSubtypeOf(runtimeClassMirror)) {
          try {
            final instance = classMirror.newInstance(Symbol(''), []).reflectee as RuntimeHintDescriptor;
            descriptors.add(instance);
          } catch (e, st) {
            final logMessage = "Could not instantiate RuntimeHintDescriptor ${mirrors.MirrorSystem.getName(classMirror.simpleName)} (expected no-arg constructor).";
            RuntimeBuilder.logFullyVerboseError('$logMessage.\n$e\n$st', trackWith: logMessage);
          }
        }
      }
    }

    final logMessage = 'Found ${descriptors.length} runtimeHint descriptor implementations: (${descriptors.map((d) => d.runtimeType).join(", ")}).';
    RuntimeBuilder.logFullyVerboseInfo(logMessage, trackWith: logMessage);
    return descriptors.isNotEmpty ? descriptors.first : DefaultRuntimeHintDescriptor();
  }

  /// Scans the provided [libraries] and returns all discovered [RuntimeHint]
  /// instances.
  ///
  /// This method inspects each class in the libraries and collects hints from:
  /// 1. Concrete classes that extend [RuntimeHint].
  /// 2. Class-level annotations that are instances of [RuntimeHint].
  /// 3. Annotation factory methods that produce [RuntimeHint] instances.
  ///
  /// Each discovered hint is instantiated and added to the returned list. If
  /// instantiation fails, a warning is logged but the process continues.
  ///
  /// Parameters:
  /// - [libraries]: The list of libraries to scan for runtime hints.
  ///
  /// Returns:
  /// - A [Future] that resolves to a list of all instantiated [RuntimeHint]s.
  @protected
  Future<List<RuntimeHint>> getRuntimeHints(List<mirrors.LibraryMirror> libraries) async {
    final runtimeHintMirror = mirrors.reflectClass(RuntimeHint);
    final runtimeHintProviderMirror = mirrors.reflectClass(RuntimeHintProvider);
    final hints = <RuntimeHint>{};

    final declarations = libraries.expand((lib) => lib.declarations.values).toList();

    for (final decl in declarations) {
      if (decl is mirrors.ClassMirror) {
        
        // ------------------------------------------------
        // 1. Classes that *extend* RuntimeHint
        // ------------------------------------------------
        if (!decl.isAbstract) {
          if (decl.isSubtypeOf(runtimeHintMirror)) {
            try {
              final instance = decl.newInstance(Symbol(''), []).reflectee as RuntimeHint;
              hints.add(instance);
              continue;
            } catch (e, st) {
              final logMessage = 'Could not instantiate RuntimeHint ${mirrors.MirrorSystem.getName(decl.simpleName)} (expected no-arg constructor).';
              RuntimeBuilder.logFullyVerboseError('$logMessage.\n$e\n$st', trackWith: logMessage);
            }
          }

          if (decl.isSubtypeOf(runtimeHintProviderMirror)) {
            try {
              final instance = decl.newInstance(Symbol(''), []).reflectee as RuntimeHintProvider;
              hints.add(instance.createHint());
              continue;
            } catch (e, st) {
              final logMessage = 'Could not instantiate RuntimeHintProvider ${mirrors.MirrorSystem.getName(decl.simpleName)} (expected no-arg constructor).';
              RuntimeBuilder.logFullyVerboseError('$logMessage.\n$e\n$st', trackWith: logMessage);
            }
          }
        }

        // ------------------------------------------------
        // 2. Annotations on the class that are RuntimeHints
        // ------------------------------------------------
        for (final meta in decl.metadata) {
          if (meta.hasReflectee) {
            final value = meta.reflectee;

            // 2A. Annotation IS RuntimeHint
            if (value is RuntimeHint) {
              hints.add(value);
              continue;
            }

            // 2B. Annotation IS RuntimeHintProvider
            if (value is RuntimeHintProvider) {
              hints.add(value.createHint());
              continue;
            }
          }
        }
      }
    }

    final logMessage = 'Found ${hints.length} runtimeHint implementations: (${hints.map((d) => d.runtimeType).join(", ")}).';
    RuntimeBuilder.logFullyVerboseInfo(logMessage, trackWith: logMessage);
    return hints.toList();
  }
}