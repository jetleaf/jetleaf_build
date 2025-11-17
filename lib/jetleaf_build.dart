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

library;

import 'src/runtime/runtime_provider/runtime_provider.dart';

export 'src/declaration/declaration.dart';
export 'src/declaration/generative.dart';

export 'src/helpers/base.dart' hide equals, toString, toStringWith;
export 'src/helpers/equals_and_hash_code.dart';
export 'src/helpers/to_string.dart';

export 'src/runner/run_scan.dart';
export 'src/runner/test_scan.dart';

export 'src/runtime/generators/application_library_generator.dart';
export 'src/runtime/generators/declaration_file_writer.dart';
export 'src/runtime/generators/library_generator.dart';
export 'src/runtime/generators/mock_library_generator.dart';
export 'src/runtime/generators/res.dart';
export 'src/runtime/generators/tree_shaker.dart';

export 'src/runtime/runtime_hint/default_runtime_hint_descriptor.dart';
export 'src/runtime/runtime_hint/runtime_hint.dart';
export 'src/runtime/runtime_hint/runtime_hint_descriptor.dart';
export 'src/runtime/runtime_hint/runtime_hint_processor.dart';

export 'src/runtime/runtime_provider/configurable_runtime_provider.dart';
export 'src/runtime/runtime_provider/meta_runtime_provider.dart';
export 'src/runtime/runtime_provider/runtime_metadata_provider.dart';
export 'src/runtime/runtime_provider/runtime_provider.dart';
export 'src/runtime/runtime_provider/standard_runtime_provider.dart';

export 'src/runtime/runtime_resolver/aot_runtime_resolver.dart';
export 'src/runtime/runtime_resolver/fallback_runtime_resolver.dart';
export 'src/runtime/runtime_resolver/jit_runtime_resolver.dart';
export 'src/runtime/runtime_resolver/runtime_resolver.dart';
export 'src/runtime/runtime_resolver/runtime_resolving.dart';

export 'src/runtime/runtime_scanner/application_runtime_scanner.dart' hide OnLogged;
export 'src/runtime/runtime_scanner/configurable_runtime_scanner_summary.dart';
export 'src/runtime/runtime_scanner/default_runtime_scanner_summary.dart';
export 'src/runtime/runtime_scanner/mock_runtime_scanner.dart' hide OnLogged;
export 'src/runtime/runtime_scanner/runtime_scanner.dart';
export 'src/runtime/runtime_scanner/runtime_scanner_configuration.dart';
export 'src/runtime/runtime_scanner/runtime_scanner_summary.dart';

export 'src/runtime/utils/dart_type_resolver.dart';
export 'src/runtime/utils/file_utility.dart';
export 'src/runtime/utils/generic_type_parser.dart';
export 'src/runtime/utils/reflection_utils.dart';
export 'src/runtime/utils/utils.dart' hide StringX;

export 'src/runtime/meta_table.dart';
export 'src/runtime/type_discovery.dart';

export 'src/annotations.dart';
export 'src/constant.dart' hide IterableExtension;
export 'src/exceptions.dart';

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