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

import '../../../builder/runtime_builder.dart';
import 'abstract_runtime_executor_resolving.dart';
import '../aot/aot_runtime_executor.dart';
import '../default_runtime_executor.dart';
import '../jit/jit_runtime_executor.dart';
import '../runtime_executor.dart';

/// {@template default_runtime_executor_resolving}
/// A concrete implementation of [AbstractRuntimeExecutorResolving] that
/// resolves a fully configured [RuntimeExecutor] using a two-stage approach:
///
/// 1. **AOT-based resolver**: Generates executables using ahead-of-time
///    configured runtime hints from [RuntimeHintDescriptor] and
///    [RuntimeHint] instances.
/// 2. **JIT-based fallback resolver**: Provides mirror-based
///    just-in-time resolution for any operations not supported by the
///    AOT resolver.
///
/// This class orchestrates the discovery, instantiation, and execution of
/// runtime hint descriptors and hints across all specified [libraries].
/// It ensures that any exceptions thrown by individual hints are logged
/// as warnings without interrupting the resolution process.
///
/// ## Behavior
/// - Discovers and instantiates the first available [RuntimeHintDescriptor]
///   in the provided libraries, or defaults to [DefaultRuntimeHintDescriptor].
/// - Scans libraries for [RuntimeHint] implementations and applies
///   them to the descriptor.
/// - Constructs a [DefaultRuntimeExecutor] that delegates to an
///   [AotRuntimeExecutor] first and falls back to a [JitRuntimeExecutor].
///
/// ## Use case
/// Suitable for environments where a combination of pre-generated
/// executables (AOT) and dynamic reflection (JIT) is required, providing
/// robust hybrid runtime execution.
///
/// Example:
/// ```dart
/// final resolver = DefaultRuntimeExecutorResolving(
///   libraries: [myLibrary],
///   logInfo: print,
///   logWarning: print,
/// );
///
/// final executor = await resolver.resolve();
/// final instance = executor.newInstance<MyClass>('default');
/// final result = executor.invokeMethod(instance, 'run');
/// ```
///
/// This ensures that any missing or unimplemented AOT operations are
/// automatically handled by the JIT fallback, maintaining runtime safety.
/// {@endtemplate}
final class DefaultRuntimeExecutorResolving extends AbstractRuntimeExecutorResolving {
  /// {@macro default_runtime_executor_resolving}
  /// 
  /// Constructs a [DefaultRuntimeExecutorResolving] with the provided
  /// [libraries] and logging callbacks.
  ///
  /// Parameters:
  /// - [libraries]: Libraries to scan for runtime descriptors and hints.
  DefaultRuntimeExecutorResolving({required super.libraries});

  @override
  Future<RuntimeExecutor> resolve() async {
    final descriptor = await getRuntimeHintDescriptor(libraries);
    final hints = await getRuntimeHints(libraries);

    // Proceed all found RuntimeHint instances
    for (final hint in hints) {
      try {
        descriptor.addHint(hint);
      } catch (e, stack) {
        final logMessage = 'Error adding RuntimeHint ${hint.runtimeType}';
        RuntimeBuilder.logFullyVerboseError('$logMessage.\n$e\n$stack', trackWith: logMessage);
      }
    }

    return DefaultRuntimeExecutor(AotRuntimeExecutor(descriptor), JitRuntimeExecutor());
  }
}