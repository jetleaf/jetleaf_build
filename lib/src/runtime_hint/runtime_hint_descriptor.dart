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

import 'runtime_hint.dart';

/// {@template runtime_hint_descriptors}
/// Abstract interface which provides all the [RuntimeHint]s that
/// are registered with JetLeaf's reflection system.
///
/// This interface is implemented by a concrete registry that collects
/// [RuntimeHint]s, typically populated by generated code or
/// user-defined [RuntimeHintProcessor] implementations.
///
/// ## Example
/// ```dart
/// class MyRegistry extends RuntimeHintDescriptor {
///   final _descriptors = <Type, RuntimeHint>{};
///
///   @override
///   void addRuntimeHintDescriptors(List<RuntimeHint> descriptors) {
///     for (var d in descriptors) {
///       _descriptors[d.type] = d;
///     }
///   }
///
///   @override
///   void addRuntimeHintDescriptor(RuntimeHint descriptor) {
///     _descriptors[descriptor.type] = descriptor;
///   }
/// }
/// ```
/// {@endtemplate}
abstract interface class RuntimeHintDescriptor {
  /// {@macro runtime_hint_descriptors}
  const RuntimeHintDescriptor();

  /// Returns a map of `Type` to [RuntimeHint] for all registered descriptors.
  ///
  /// The returned map can be used by other parts of the reflection system to
  /// dynamically construct or invoke types without `dart:mirrors`.
  Map<Type, RuntimeHint> getRuntimeHints();

  /// Adds multiple [RuntimeHint] values to the system.
  ///
  /// This is used when the reflection system or user code wants to register
  /// a batch of descriptors at once.
  ///
  /// ## Example
  /// ```dart
  /// descriptors.addRuntimeHints([
  ///   RuntimeHint(type: MyClass, newInstance: ...),
  ///   RuntimeHint(type: AnotherClass, invokeMethod: ...),
  /// ]);
  /// ```
  void addRuntimeHints(List<RuntimeHint> hints);

  /// Adds a single [RuntimeHint] value to the system.
  ///
  /// This is useful for registering one descriptor at a time,
  /// such as when scanning annotations or running user logic.
  ///
  /// ## Example
  /// ```dart
  /// descriptors.addRuntimeHint(
  ///   RuntimeHint(type: MyClass, newInstance: ...),
  /// );
  /// ```
  void addRuntimeHint(RuntimeHint hint);
}