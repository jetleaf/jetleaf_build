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

import '../runtime_executor.dart';

/// {@template runtime_executor_resolving}
/// An abstract base class responsible for orchestrating the **runtime resolution**
/// of types, methods, and fields across multiple libraries.
///
/// `RuntimeExecutorResolving` provides a structured way to prepare a fully
/// configured [RuntimeExecutor] instance by combining multiple sources of
/// runtime information, such as:
/// 
/// - Force-loaded libraries containing types that may not be referenced
///   directly in the program but should be resolvable at runtime.
/// - Runtime hints or configuration directives guiding type resolution
///   and instance creation.
/// - Fallback mechanisms to ensure operations succeed even when
///   primary resolvers cannot handle certain types.
///
/// This class is **abstract** because the specific resolution strategy
/// (how to generate AOT resolvers, how to combine mirrors, etc.) is left
/// to concrete implementations. It defines the **contract** for any
/// runtime resolving process in the JetLeaf framework.
///
/// Typical usage involves:
/// 1. Specifying additional libraries that need to be loaded.
/// 2. Providing logging callbacks for informational and warning messages.
/// 3. Calling [resolve] to obtain a fully operational [RuntimeExecutor].
///
/// This setup enables hybrid AOT/JIT scenarios, supports code generation
/// workflows, and allows progressive migration from reflective
/// resolution to fully code-generated runtime support.
/// {@endtemplate}
abstract class RuntimeExecutorResolving {
  /// A list of libraries that should be force-loaded during resolution.
  ///
  /// This is useful for ensuring that all relevant types and members are
  /// visible to the runtime executor, even if they are not statically
  /// referenced elsewhere in the program.
  final List<mirrors.LibraryMirror> libraries;

  /// Constructs a new `RuntimeExecutorResolving` instance.
  ///
  /// Parameters:
  /// - [libraries]: Additional libraries to load and include in the resolution.
  ///
  /// {@macro runtime_executor_resolving}
  RuntimeExecutorResolving({required this.libraries});

  /// Executes the complete runtime resolution process.
  ///
  /// This method must be implemented by subclasses. It is responsible for:
  /// 1. Generating AOT (Ahead-of-Time) resolvers for all discovered types.
  /// 2. Processing runtime hints and configuration that guide dynamic
  ///    resolution.
  /// 3. Creating a [RuntimeExecutor] instance that uses a primary resolver
  ///    with optional fallback strategies.
  ///
  /// Returns:
  /// - A fully configured [RuntimeExecutor] ready to create instances,
  ///   invoke methods, and get/set fields at runtime.
  ///
  /// Example:
  /// ```dart
  /// final resolver = await MyRuntimeResolver(libraries: myLibs, logInfo: print, logWarning: print).resolve();
  /// final instance = resolver.newInstance<MyClass>('');
  /// ```
  Future<RuntimeExecutor> resolve();
}