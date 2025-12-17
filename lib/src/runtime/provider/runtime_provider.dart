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

import '../executor/runtime_executor.dart';
import 'runtime_metadata_provider.dart';

/// {@template runtime_provider}
/// Represents a runtime reflection context for a Dart application,
/// providing access to libraries, packages, assets, and metadata.
///
/// This context can be implemented using `dart:mirrors` for JIT,
/// or a custom metadata loader for AOT.
///
/// Common use cases include:
/// - Loading all classes, enums, typedefs, and extensions
/// - Discovering framework-specific types or annotations
/// - Building reflection-based systems like DI, serialization, or codegen
///
/// ### Example
/// ```dart
/// RuntimeProvider context = obtainContext();
///
/// final libraries = context.getLibraries();
/// final packages = context.getPackages();
///
/// for (final lib in libraries) {
///   print('Library: ${lib.getName()}');
/// }
/// ```
///
/// {@endtemplate}
abstract class RuntimeProvider implements RuntimeMetadataProvider {
  /// {@macro runtime_provider}
  RuntimeProvider();

  /// {@macro runtime_provider}
  ///
  /// Returns the runtime resolver used to resolve descriptors entities.
  RuntimeExecutor getRuntimeResolver();

  @override
  String toString() => 'ReflectionContext(\n${getAllLibraries().length} libraries,\n${getAllPackages().length} packages)';
} 