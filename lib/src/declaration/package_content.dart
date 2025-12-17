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

import 'declaration.dart';

/// {@template package_content}
/// Represents the complete content and metadata of a Dart package.
/// 
/// Provides access to package hierarchy information, contained libraries,
/// and non-code assets. Serves as a container for all package-level declarations.
///
/// {@template package_content_features}
/// ## Key Features
/// - Package hierarchy navigation
/// - Library metadata access
/// - Asset management
/// - Package identity information
/// {@endtemplate}
///
/// {@template package_content_example}
/// ## Example Usage
/// ```dart
/// final content = PackageContent.forPackage(myPackage);
/// 
/// // Access package hierarchy
/// final hierarchyLevel = content.getHierarchy();
///
/// // Get all libraries
/// final libraries = content.getAllLibraries();
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract class PackageContent {
  /// {@template package_content_get_hierarchy}
  /// Retrieves the package's position in the dependency hierarchy.
  ///
  /// Returns:
  /// - [int] representing the depth in the dependency tree
  /// - Lower numbers indicate more foundational packages
  ///
  /// Example:
  /// ```dart
  /// final hierarchy = content.getHierarchy();
  /// if (hierarchy.value == 0) {
  ///   print('This is a root package');
  /// }
  /// ```
  /// {@endtemplate}
  int getHierarchy();

  /// {@template package_content_get_package}
  /// Retrieves the package instance this content belongs to.
  ///
  /// Returns:
  /// - The containing [Package] object
  /// - Never returns null
  ///
  /// Example:
  /// ```dart
  /// final package = content.getPackage();
  /// print('Package name: ${package.name}');
  /// ```
  /// {@endtemplate}
  Package getPackage();

  /// {@template package_content_get_all_assets}
  /// Retrieves all non-code assets contained in this package.
  ///
  /// Returns:
  /// - List of [Asset] objects
  /// - Includes images, fonts, configuration files
  /// - Empty list if package contains no assets
  ///
  /// Example:
  /// ```dart
  /// final assets = content.getAllAssets();
  /// final images = assets.where((a) => a.isImage);
  /// ```
  /// {@endtemplate}
  List<Asset> getAllAssets();

  /// {@template package_content_get_all_libraries}
  /// Retrieves all library declarations within this package.
  ///
  /// Returns:
  /// - List of [LibraryDeclaration] objects
  /// - Includes all Dart library declarations
  /// - Empty list if package contains no libraries
  ///
  /// Example:
  /// ```dart
  /// final libraries = content.getAllLibraries();
  /// final publicLibraries = libraries.where((l) => l.isPublic);
  /// ```
  /// {@endtemplate}
  List<LibraryDeclaration> getAllLibraries();
}

/// {@template package_content_impl}
/// Concrete implementation of [PackageContent] with mutable state.
///
/// {@template package_content_impl_features}
/// ## Implementation Details
/// - Mutable collections and hierarchy
/// - Internal state management
/// - Direct field access for setters
/// {@endtemplate}
///
/// {@template package_content_impl_example}
/// ## Example Usage
/// ```dart
/// final content = PackageContentImpl(
///   myPackage,
///   assets,
///   libraries,
///   1
/// );
///
/// // Update hierarchy later
/// content.setHierarchy(2);
/// ```
/// {@endtemplate}
/// {@endtemplate}
class PackageContentImpl extends PackageContent {
  final Package _package;
  List<Asset> _assets;
  List<LibraryDeclaration> _libraries;
  int _hierarchy;

  /// Creates a new package content container.
  ///
  /// {@template package_content_impl_constructor}
  /// Parameters:
  /// - [_package]: The owning package instance
  /// - [_assets]: Initial list of package assets
  /// - [_libraries]: Initial list of library declarations
  /// - [_hierarchy]: Initial hierarchy level
  ///
  /// All parameters are required and cannot be null.
  /// {@endtemplate}
  PackageContentImpl(this._package, this._assets, this._libraries, this._hierarchy);

  @override
  List<Asset> getAllAssets() => _assets;

  @override
  List<LibraryDeclaration> getAllLibraries() => _libraries;

  @override
  int getHierarchy() => _hierarchy;

  @override
  Package getPackage() => _package;

  /// {@template package_content_impl_set_hierarchy}
  /// Updates the package's hierarchy level.
  ///
  /// Parameters:
  /// - [hierarchy]: New hierarchy level as [int]
  ///
  /// Example:
  /// ```dart
  /// content.setHierarchy(int(2));
  /// ```
  /// {@endtemplate}
  void setHierarchy(int hierarchy) => _hierarchy = hierarchy;

  /// {@template package_content_impl_set_assets}
  /// Replaces the current asset collection.
  ///
  /// Parameters:
  /// - [assets]: New list of [Asset] objects
  ///
  /// Example:
  /// ```dart
  /// content.setAssets(newAssets);
  /// ```
  /// {@endtemplate}
  void setAssets(List<Asset> assets) => _assets = assets;

  /// {@template package_content_impl_set_libraries}
  /// Replaces the current library collection.
  ///
  /// Parameters:
  /// - [libraries]: New list of [LibraryDeclaration] objects
  ///
  /// Example:
  /// ```dart
  /// content.setLibraries(newLibraries);
  /// ```
  /// {@endtemplate}
  void setLibraries(List<LibraryDeclaration> libraries) => _libraries = libraries;
}