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

import 'dart:typed_data';

import 'declaration.dart';

/// {@template jetleaf_generative_asset}
/// Base class representing a **resource asset with a no-args constructor**.
///
/// Designed primarily for **code generation scenarios**, where subclasses
/// are instantiated reflectively (e.g., via mirrors or generated code).
///
/// Subclasses are expected to override the core getters to provide asset
/// metadata and content:
/// - [_filePath] — the asset's relative or absolute path  
/// - [_fileName] — the asset's file name  
/// - [_packageName] — the package the asset belongs to  
/// - [_contentBytes] — the raw byte content of the asset  
///
/// Generated subclasses typically provide these as `final` fields for
/// immutable, compile-time-safe assets.
///
/// ### Usage Example
/// ```dart
/// class GeneratedAssetExample extends GenerativeAsset {
///   @override
///   String getFilePath() => "assets/config.json";
///
///   @override
///   String getFileName() => "config.json";
///
///   @override
///   String? getPackageName() => "my_package";
///
///   @override
///   Uint8List getContentBytes() => Uint8List.fromList([1, 2, 3]);
/// }
///
/// final asset = GeneratedAssetExample();
/// print(asset.getFilePath()); // "assets/config.json"
/// ```
///
/// ### Design Notes
/// - Must have a **no-args constructor** to support reflective instantiation.  
/// - Serves as a base for code-generated asset classes, ensuring a uniform
///   API across all assets.  
/// - Provides default dummy values in the constructor to satisfy the base
///   [Asset] class; actual values must be supplied by overriding getters.
///
/// ### See Also
/// - [Asset]
/// - [Uint8List]
/// {@endtemplate}
abstract class GenerativeAsset extends Asset {
  /// Default no-args constructor.
  ///
  /// Subclasses should override the getters to provide actual asset data.
  /// 
  /// {@macro jetleaf_generative_asset}
  GenerativeAsset() : super(
    filePath: '',
    fileName: '',
    packageName: '',
    contentBytes: Uint8List(0),
  );

  @override
  String getFilePath();

  @override
  String getFileName();

  @override
  String? getPackageName();

  @override
  Uint8List getContentBytes();
}

/// {@template jetleaf_generative_package}
/// Base class representing a **package resource with a no-args constructor**.
///
/// Designed primarily for **code generation scenarios**, where subclasses
/// are instantiated reflectively (e.g., via mirrors or generated code).
///
/// Subclasses are expected to override the core getters to provide package
/// metadata:
/// - [_name] — the package name  
/// - [_version] — the package version  
/// - [_languageVersion] — the Dart language version  
/// - [_isRootPackage] — whether this package is the root package  
/// - [_filePath] — the path to the package descriptor or source  
/// - [_rootUri] — the root URI of the package  
///
/// Generated subclasses typically provide these as `final` fields for
/// immutable, compile-time-safe package representations.
///
/// ### Usage Example
/// ```dart
/// class GeneratedPackageExample extends GenerativePackage {
///   @override
///   String getName() => "my_package";
///
///   @override
///   String getVersion() => "1.0.0";
///
///   @override
///   String? getLanguageVersion() => "2.20";
///
///   @override
///   bool getIsRootPackage() => true;
///
///   @override
///   String? getFilePath() => "/path/to/package";
///
///   @override
///   String? getRootUri() => "file:///path/to/package";
/// }
///
/// final pkg = GeneratedPackageExample();
/// print(pkg.getName()); // "my_package"
/// ```
///
/// ### Design Notes
/// - Must have a **no-args constructor** to support reflective instantiation.  
/// - Serves as a base for code-generated package classes, ensuring a uniform
///   API across all packages.  
/// - Provides default dummy values in the constructor to satisfy the base
///   [Package] class; actual values must be supplied by overriding getters.
///
/// ### See Also
/// - [Package]
/// {@endtemplate}
abstract class GenerativePackage extends Package {
  /// Default no-args constructor.
  ///
  /// Subclasses should override the getters to provide actual package data.
  /// 
  /// {@macro jetleaf_generative_package}
  const GenerativePackage() : super(
    name: '',
    version: '',
    languageVersion: null,
    isRootPackage: false,
    filePath: null,
    rootUri: null,
  );

  @override
  String getName();

  @override
  String getVersion();

  @override
  String? getLanguageVersion();

  @override
  bool getIsRootPackage();

  @override
  String? getFilePath();

  @override
  String? getRootUri();
}