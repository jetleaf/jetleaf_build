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

import '../runtime/declaration/declaration.dart';
import '../utils/utils.dart';
import 'default_library_generator.dart';
import 'library_generator.dart';
import '../runtime/scanner/runtime_scanner_configuration.dart';

/// {@template mock_library_generator}
/// A mock implementation of [LibraryGenerator] that generates reflection metadata
/// using Dart's mirrors API without filesystem operations.
///
/// This generator is designed for testing and development scenarios where:
/// - Full reflection is needed but without filesystem access
/// - Only specific libraries need to be processed
/// - Simplified package resolution is acceptable
///
/// ### Key Differences from [LibraryGenerator]
/// - Operates only on in-memory mirror data
/// - Doesn't perform filesystem scanning
/// - Uses simplified package resolution
/// - Processes only current isolate and force-loaded mirrors
///
/// ### Example Usage
/// ```dart
/// final generator = MockLibraryGenerator(
///   mirrorSystem: currentMirrorSystem(),
///   forceLoadedMirrors: [reflectClass(MyClass)!.owner as LibraryMirror],
///   onInfo: (msg) => logger.info(msg),
///   onError: (err) => logger.error(err),
///   configuration: RuntimeScanLoader(
///     scanClasses: [MyClass, MyOtherClass],
///   ),
///   packages: [
///     Package(name: 'my_pkg', version: '1.0.0'),
///   ],
/// );
///
/// final libraries = await generator.generate();
/// ```
/// {@endtemplate}
base class MockLibraryGenerator extends DefaultLibraryGenerator {
  /// {@macro mock_library_generator}
  ///
  /// {@template mock_library_generator_constructor}
  /// Creates a mock library generator with direct mirror system access.
  ///
  /// Parameters:
  /// - [mirrorSystem]: The mirror system to use for reflection
  /// - [forceLoadedMirrors]: Additional libraries to process beyond current isolate
  /// - [configuration]: Configuration for the scanning process
  /// - [packages]: Known package metadata
  ///
  /// All parameters are required and non-nullable.
  /// {@endtemplate}
  MockLibraryGenerator({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });
}

/// {@template mock_library_generator_factory}
/// Signature for creating custom mock library generators.
///
/// Used to provide alternative generator implementations to [MockRuntimeScan]
/// while maintaining the same mock behavior pattern.
///
/// {@template factory_example}
/// Example:
/// ```dart
/// LibraryGenerator createGenerator(MockLibraryGeneratorParams params) {
///   return CustomMockGenerator(
///     mirrorSystem: params.mirrorSystem,
///     // ... other custom initialization
///   );
/// }
///
/// final scan = MockRuntimeScan(
///   createLibraryGenerator: createGenerator,
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
typedef MockLibraryGeneratorFactory = LibraryGenerator Function(MockLibraryGeneratorParams);

/// {@template mock_library_generator_params}
/// Configuration parameters for creating a [MockLibraryGenerator].
///
/// This bundles all required dependencies and configuration needed to
/// instantiate a mock library generator.
///
/// {@template params_example}
/// Example:
/// ```dart
/// final params = MockLibraryGeneratorParams(
///   mirrorSystem: currentMirrorSystem(),
///   forceLoadedMirrors: myLibraries,
///   onInfo: print,
///   onError: print,
///   configuration: config,
///   packages: [Package(name: 'test', version: '1.0.0')],
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
class MockLibraryGeneratorParams {
  /// The mirror system to use for reflection operations.
  final mirrors.MirrorSystem mirrorSystem;

  /// Additional libraries to include in scanning beyond current isolate.
  final List<mirrors.LibraryMirror> forceLoadedMirrors;

  /// Configuration controlling the scanning behavior.
  final RuntimeScannerConfiguration configuration;

  /// Known package metadata for resolution.
  final List<Package> packages;

  /// {@macro mock_library_generator_params}
  ///
  /// {@template params_constructor}
  /// Creates parameter bundle for mock library generator construction.
  ///
  /// All parameters are required and used to initialize the generator:
  /// - [mirrorSystem]: Typically `currentMirrorSystem()`
  /// - [forceLoadedMirrors]: Can be empty for basic cases
  /// - [onInfo/onError]: Should handle logging appropriately
  /// - [configuration]: Controls what gets scanned
  /// - [packages]: Should include at least the current package
  /// {@endtemplate}
  MockLibraryGeneratorParams({
    required this.mirrorSystem,
    required this.forceLoadedMirrors,
    required this.configuration,
    required this.packages,
  });
}

/// We create this class for the purpose of internal testing of the JetLeaf's framework.
/// This class is only visible within the framework and not to be used by external users.
/// For users who want to test their application, they can use the `MockLibraryGenerator`
/// to bootstrap their application.
base class InternalMockLibraryGenerator extends DefaultLibraryGenerator {
  /// {@macro mock_library_generator}
  ///
  /// {@template mock_library_generator_constructor}
  /// Creates a mock library generator with direct mirror system access.
  ///
  /// Parameters:
  /// - [mirrorSystem]: The mirror system to use for reflection
  /// - [forceLoadedMirrors]: Additional libraries to process beyond current isolate
  /// - [configuration]: Configuration for the scanning process
  /// - [packages]: Known package metadata
  ///
  /// All parameters are required and non-nullable.
  /// {@endtemplate}
  InternalMockLibraryGenerator({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  @override
  bool isSkippableJetLeafPackage(Uri identifier) => false;

  @override
  bool isNonLoadableJetLeafFile(Uri uri) => false;

  @override
  Future<bool> shouldNotIncludeLibrary(Uri uri, RuntimeScannerConfiguration configuration) async {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first.equalsAny(['analyzer', '_fe_analyzer_shared'])) {
      return true;
    }

    if(configuration.packagesToExclude.any((p) => p == uri.toString())) {
      return true;
    }

    return (uri.pathSegments.isNotEmpty && configuration.packagesToExclude.any((p) => uri.pathSegments.first == p));
  }

  @override
  bool isPartOf(String content) => false;

  @override
  bool isTest(String content) => false;
}