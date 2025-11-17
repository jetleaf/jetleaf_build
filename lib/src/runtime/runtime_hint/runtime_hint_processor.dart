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

import 'runtime_hint_descriptor.dart';

/// {@template runtime_hint_processor}
/// An abstract interface that users can implement to configure the
/// [RuntimeHintDescriptor] registry.
///
/// Implementations of this interface are discovered by the reflection scanner
/// and their `proceed` method is called to register [RuntimeHint]s.
/// This allows users to provide custom, AOT-compatible reflection logic.
///
/// ## Example
/// ```dart
/// class MyExecutableConfig implements RuntimeHintProcessor {
///   @override
///   void proceed(RuntimeHintDescriptor descriptor) {
///     descriptor.addRuntimeHint(
///       RuntimeHint(
///         type: MyService,
///         newInstance: (name, [args = const [], namedArgs = const {}]) => MyService(),
///       ),
///     );
///   }
/// }
/// ```
/// {@endtemplate}
abstract interface class RuntimeHintProcessor {
  /// {@macro runtime_hint_processor}
  const RuntimeHintProcessor();

  /// Proceeds to configure the given [RuntimeHintDescriptor] by adding
  /// [RuntimeHint]s to it.
  ///
  /// This method is called during reflection scanning. Override this to
  /// manually register any custom instantiation, method calls, or field access
  /// logic required by your application.
  void proceed(RuntimeHintDescriptor descriptor);
}