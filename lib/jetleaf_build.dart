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

/// 🏗 **JetLeaf Build**
///
/// The JetLeaf Build library provides a comprehensive set of tools and
/// runtime utilities for code generation, runtime scanning, reflection,
/// and AOT/JIT support. It is designed to facilitate modular application
/// development, automated code generation, and runtime configuration
/// within the JetLeaf ecosystem.
///
/// ## 🔑 Core Modules
///
/// ### Declarations & Generative Tools
/// - `declaration.dart`, `generative.dart` — manage code declarations
///   and generative constructs.
///
/// ### Helpers
/// - `base.dart`, `equals_and_hash_code.dart`, `to_string.dart` — utility
///   functions for object equality, string representations, and core helpers.
///
/// ### Runners
/// - `run_scan.dart`, `test_scan.dart` — scan codebases for runtime or
///   test analysis.
///
/// ### Runtime Generators
/// - `application_library_generator.dart` — generates application libraries.
/// - `declaration_file_writer.dart` — writes code declarations to files.
/// - `library_generator.dart`, `mock_library_generator.dart` — library and mock generation.
/// - `tree_shaker.dart` — removes unused declarations for optimized builds.
///
/// ### Runtime Hints
/// - `runtime_hint.dart`, `runtime_hint_descriptor.dart`, `runtime_hint_processor.dart`
///   — provide metadata and processing hooks for runtime optimizations.
///
/// ### Runtime Providers
/// - `runtime_provider.dart`, `standard_runtime_provider.dart`,
///   `configurable_runtime_provider.dart`, `meta_runtime_provider.dart`,
///   `runtime_metadata_provider.dart` — manage runtime services and
///   dependency injection.
///
/// ### Runtime Resolvers
/// - `runtime_resolver.dart`, `jit_runtime_resolver.dart`, `aot_runtime_resolver.dart`,
///   `fallback_runtime_resolver.dart` — resolve runtime dependencies for
///   JIT or AOT contexts.
///
/// ### Runtime Scanners
/// - `runtime_scanner.dart`, `application_runtime_scanner.dart`,
///   `mock_runtime_scanner.dart`, `runtime_scanner_summary.dart` — scan
///   application code and generate runtime metadata.
///
/// ### Utilities
/// - `dart_type_resolver.dart`, `file_utility.dart`, `generic_type_parser.dart`,
///   `reflection_utils.dart`, `utils.dart` — type parsing, file operations,
///   and reflection utilities.
///
/// ### Meta and Discovery
/// - `meta_table.dart`, `type_discovery.dart` — manage metadata and
///   type discovery across the application.
///
/// ### Annotations, Constants & Exceptions
/// - `annotations.dart`, `constant.dart`, `exceptions.dart` — support
///   declarative metadata, constants, and runtime exceptions.
///
///
/// ## 🌐 Global Runtime Provider
///
/// ```dart
/// /// A global reference to the active runtime provider in the JetLeaf framework.
/// RuntimeProvider? GLOBAL_RUNTIME_PROVIDER;
/// ```
///
/// `GLOBAL_RUNTIME_PROVIDER` holds the current instance of [RuntimeProvider],
/// which manages runtime services, dependency injection, and configuration
/// throughout the JetLeaf application lifecycle.
///
/// Typically initialized during application bootstrap. Provides access to
/// core services such as logging, configuration, and runtime scanning:
///
/// ```dart
/// if (GLOBAL_RUNTIME_PROVIDER != null) {
///   final logger = GLOBAL_RUNTIME_PROVIDER!.get<Logger>();
///   logger.info('Application started successfully.');
/// }
/// ```
///
/// ⚠️ Caution: This variable is nullable, so handle cases where it is
/// uninitialized to avoid null pointer exceptions.
///
/// Prefer using dependency injection or runtime service accessors in
/// production code rather than directly referencing
/// `GLOBAL_RUNTIME_PROVIDER`.
///
/// {@category Build & Runtime}
library;

import 'src/runtime_provider/runtime_provider.dart';

export 'src/declaration/declaration.dart';
export 'src/declaration/generative.dart';

export 'src/helpers/base.dart' hide equals, toString, toStringWith;
export 'src/helpers/equals_and_hash_code.dart';
export 'src/helpers/to_string.dart';

export 'src/runner/run_scan.dart';
export 'src/runner/test_scan.dart';

export 'src/generators/default_library_generator.dart';
export 'src/declaration_writer/declaration_file_writer.dart';
export 'src/generators/library_generator.dart';
export 'src/generators/mock_library_generator.dart';
export 'src/tree_shaker/tree_shaker.dart';

export 'src/runtime_hint/default_runtime_hint_descriptor.dart';
export 'src/runtime_hint/runtime_hint.dart';
export 'src/runtime_hint/runtime_hint_descriptor.dart';
export 'src/runtime_hint/runtime_hint_processor.dart';

export 'src/runtime_provider/configurable_runtime_provider.dart';
export 'src/runtime_provider/meta_runtime_provider.dart';
export 'src/runtime_provider/runtime_metadata_provider.dart';
export 'src/runtime_provider/runtime_provider.dart';
export 'src/runtime_provider/standard_runtime_provider.dart';

export 'src/runtime_resolver/aot_runtime_resolver.dart';
export 'src/runtime_resolver/fallback_runtime_resolver.dart';
export 'src/runtime_resolver/jit_runtime_resolver.dart';
export 'src/runtime_resolver/runtime_resolver.dart';
export 'src/runtime_resolver/runtime_resolving.dart';

export 'src/runtime_scanner/application_runtime_scanner.dart' hide OnLogged;
export 'src/runtime_scanner/configurable_runtime_scanner_summary.dart';
export 'src/runtime_scanner/default_runtime_scanner_summary.dart';
export 'src/runtime_scanner/mock_runtime_scanner.dart';
export 'src/runtime_scanner/runtime_scanner.dart';
export 'src/runtime_scanner/runtime_scanner_configuration.dart';
export 'src/runtime_scanner/runtime_scanner_summary.dart';

export 'src/utils/dart_type_resolver.dart';
export 'src/utils/file_utility.dart';
export 'src/utils/generic_type_parser.dart';
export 'src/utils/reflection_utils.dart';
export 'src/utils/utils.dart' hide StringX;

export 'src/utils/meta_table.dart';
export 'src/utils/type_discovery.dart';

export 'src/annotations.dart';
export 'src/utils/constant.dart' hide IterableExtension;
export 'src/exceptions.dart';
export 'src/utils/must_avoid.dart';

/// A global reference to the active runtime provider in the JetLeaf framework.
///
/// `GLOBAL_RUNTIME_PROVIDER` holds the current instance of [RuntimeProvider], which
/// is responsible for managing runtime services, dependency injection,
/// and configuration throughout the lifecycle of a JetLeaf application.
///
/// This variable is typically initialized during the application bootstrap
/// phase, before any runtime-dependent logic is executed. Once set, it allows
/// any part of the application, including dynamically loaded modules or
/// generated code, to access core services such as logging, configuration,
/// and runtime scanning.
///
/// Example usage:
/// ```dart
/// if (GLOBAL_RUNTIME_PROVIDER != null) {
///   final logger = GLOBAL_RUNTIME_PROVIDER!.get<Logger>();
///   logger.info('Application started successfully.');
/// }
/// ```
///
/// ⚠️ Caution: Since this variable is nullable (`RuntimeProvider?`), any
/// access should handle the case where it has not been initialized yet to
/// avoid null pointer exceptions.
///
/// Consider using dependency injection or the provided accessor methods
/// to safely retrieve runtime services instead of directly referencing
/// `GLOBAL_RUNTIME_PROVIDER` in production code.
RuntimeProvider? GLOBAL_RUNTIME_PROVIDER;