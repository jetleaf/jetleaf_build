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

import '../../declaration/declaration.dart';

/// {@template reflection_metadata_provider}
/// A contract for providing access to reflection metadata in JetLeaf.
///
/// This interface defines common methods for accessing reflected types,
/// libraries, packages, and assets. It serves as a base for both runtime
/// registry and provider implementations.
///
/// Implementations can be used for:
/// - Serialization
/// - Dependency injection
/// - Dynamic routing
/// - Code generation
/// 
/// {@template reflection_metadata_provider_example}
/// Example usage:
/// ```dart
/// final provider = SomeReflectionMetadataProvider();
/// 
/// // Get all reflected classes
/// final classes = provider.getAllClasses();
/// 
/// // Get metadata for specific type
/// final stringType = provider.getReflectedType(String);
/// 
/// // Get library information
/// final dartCore = provider.getReflectedLibrary('dart:core');
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract interface class RuntimeMetadataProvider {
  /// {@macro reflection_metadata_provider}
  const RuntimeMetadataProvider();

  /// Returns all reflected libraries available in the reflection context.
  ///
  /// This includes all libraries that have been processed by the reflection system,
  /// including those from dependencies and generated code.
  ///
  /// {@macro reflection_metadata_provider_example}
  ///
  /// Returns a list of [LibraryDeclaration] objects containing metadata about each library.
  List<LibraryDeclaration> getAllLibraries();

  /// Returns all assets available in the reflection context.
  ///
  /// Assets typically include non-code resources like images, configuration files,
  /// or other bundled files that are part of the application.
  ///
  /// {@macro reflection_metadata_provider_example}
  ///
  /// Returns a list of [Asset] objects containing metadata about each asset.
  List<Asset> getAllAssets();

  /// Returns all packages available in the reflection context.
  ///
  /// This includes all Dart packages that have been processed by the reflection system,
  /// including their libraries and dependencies.
  ///
  /// {@macro reflection_metadata_provider_example}
  ///
  /// Returns a list of [Package] objects containing metadata about each package.
  List<Package> getAllPackages();
}