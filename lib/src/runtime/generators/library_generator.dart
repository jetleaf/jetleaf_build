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

import 'dart:io';
import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../declaration/declaration.dart';
import '../runtime_scanner/runtime_scanner_configuration.dart';
import '../utils/utils.dart';

/// {@template library_generator}
/// Enhanced reflection generator that creates both metadata and reflector classes.
/// 
/// This abstract class provides functionality to generate reflection metadata
/// for Dart libraries, including classes, mixins, enums, typedefs, and top-level
/// declarations. It handles complex type relationships, inheritance hierarchies,
/// and source code analysis to provide accurate reflection information.
/// 
/// **Usage Example:**
/// ```dart
/// final generator = ConcreteLibraryGenerator(
///   mirrorSystem: currentMirrorSystem(),
///   forceLoadedMirrors: [],
///   onInfo: print,
///   onError: print,
///   loader: RuntimeScanLoader(),
///   packages: [currentPackage],
/// );
/// 
/// final libraries = await generator.generate();
/// ```
/// 
/// **Key Features:**
/// - Generates reflection metadata for entire libraries
/// - Handles complex type relationships and generics
/// - Supports source code analysis for accurate modifier detection
/// - Caches results for performance
/// - Provides detailed error reporting
/// {@endtemplate}
abstract class LibraryGenerator {
  /// The mirror system used for reflection
  final mirrors.MirrorSystem mirrorSystem;

  /// Callback for informational messages
  final void Function(String) onInfo;

  /// Callback for error messages
  final void Function(String) onError;

  /// Callback for warning messages
  final void Function(String) onWarning;

  /// The runtime scan loader configuration
  final RuntimeScannerConfiguration configuration;

  /// List of packages to process
  final List<Package> packages;

  /// List of mirrors that should be force-loaded
  final List<mirrors.LibraryMirror> forceLoadedMirrors;

  /// {@macro library_generator}
  @protected
  LibraryGenerator({
    required this.mirrorSystem,
    required this.forceLoadedMirrors,
    required this.onInfo,
    required this.onWarning,
    required this.onError,
    required this.configuration,
    required this.packages,
  });

  /// Generates both reflection metadata and concrete reflector classes.
  /// 
  /// This is the main entry point that processes all libraries in the mirror system
  /// (plus any force-loaded mirrors) and generates complete reflection metadata.
  /// 
  /// **Parameters:**
  /// - [dartFiles]: A list of Dart files to process via analyzer
  /// 
  /// **Returns:** A list of [LibraryDeclaration] objects representing the reflected libraries
  /// 
  /// **Example:**
  /// ```dart
  /// final libraries = await generator.generate(dartFiles);
  /// for (final library in libraries) {
  ///   print('Library: ${library.uri}');
  ///   for (final declaration in library.declarations) {
  ///     print(' - ${declaration.name}');
  ///   }
  /// }
  /// ```
  Future<List<LibraryDeclaration>> generate(List<File> dartFiles);

  /// {@macro non_loadable_check}
  @protected
  bool isNonLoadableJetLeafFile(Uri uri) => RuntimeUtils.isNonLoadableJetLeafFile(uri);

  /// {@macro non_loadable_check}
  @protected
  bool isSkippableJetLeafPackage(Uri identifier) => RuntimeUtils.isSkippableJetLeafPackage(identifier);

  /// {@macro package_name_extraction}
  @protected
  String? getPackageNameFromUri(dynamic uri) => RuntimeUtils.getPackageNameFromUri(uri);

  /// {@macro is_part_of}
  @protected
  bool isPartOf(String content) => RuntimeUtils.isPartOf(content);

  /// {@macro has_mirror_import}
  @protected
  bool hasMirrorImport(String content) => RuntimeUtils.hasMirrorImport(content);

  /// {@macro is_test}
  @protected
  bool isTest(String content) => RuntimeUtils.isTest(content);

  /// {@macro uri_resolution}
  @protected
  Future<Uri?> resolveUri(Uri uri) => RuntimeUtils.resolveUri(uri);

  /// {@macro library_exclusion}
  @protected
  Future<bool> shouldNotIncludeLibrary(Uri uri, RuntimeScannerConfiguration configuration) => RuntimeUtils.shouldNotIncludeLibrary(uri, configuration);
}