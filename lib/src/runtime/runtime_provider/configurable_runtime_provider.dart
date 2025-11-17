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

import 'dart:io' show File;

import '../../declaration/declaration.dart';
import '../runtime_resolver/runtime_resolver.dart';
import 'runtime_provider.dart';

/// {@template configurable_runtime_provider}
/// A mutable context used to collect and assemble metadata during the
/// framework’s initialization or AOT compilation phase.
///
/// This interface is used internally to register discovered libraries, packages,
/// assets, environment variables, and special types before
/// the context is finalized via [build].
///
/// The finalized output will be an immutable [RuntimeProvider] that provides
/// a stable view of all application metadata.
///
/// ## Example
/// ```dart
/// final context = StandardRuntimeProvider();
/// // Assuming you have a way to create ReflectedLibrary instances
/// context.addLibrary(myReflectedLibrary);
/// context.addPackage(myPackage);
/// context.addAsset(myAsset);
/// context.addSpecialType(mySpecialType);
/// context.addLibraries([lib1, lib2], replace: true);
/// context.addPackages([pkg1, pkg2], replace: true);
/// context.addAssets([asset1, asset2], replace: true);
/// context.addSpecialTypes([type1, type2], replace: true);
/// ```
/// {@endtemplate}
abstract class ConfigurableRuntimeProvider extends RuntimeProvider {
  /// {@macro configurable_runtime_provider}
  ///
  /// Adds a [LibraryDeclaration] representing a discovered Dart library.
  ///
  /// The library must include metadata for its classes, enums, methods,
  /// fields, and associated annotations.
  ///
  /// ```dart
  /// context.addLibrary(myLibrary);
  /// ```
  void addLibrary(LibraryDeclaration library);

  /// {@macro configurable_runtime_provider}
  ///
  /// Adds a [Package] representing a scanned or resolved Dart package.
  ///
  /// ```dart
  /// context.addPackage(myPackage);
  /// ```
  void addPackage(Package package);

  /// {@macro configurable_runtime_provider}
  ///
  /// Adds an [Asset] representing a non-Dart file, such as config,
  /// text, or JSON metadata.
  ///
  /// ```dart
  /// context.addAsset(Asset('config.json', contents));
  /// ```
  void addAsset(Asset asset);

  /// {@macro configurable_runtime_provider}
  ///
  /// Registers a [TypeDeclaration] as a special or framework-level type.
  ///
  /// These are typically types used by the framework to mark components,
  /// such as `@Controller`, `@Service`, etc.
  ///
  /// ```dart
  /// context.addSpecialType(reflectedControllerType);
  /// ```
  void addSpecialType(TypeDeclaration type);

  /// {@macro configurable_runtime_provider}
  ///
  /// Registers a [File] as a non-dart file.
  ///
  /// These are typically files that does not end with `.dart`.
  ///
  /// ```dart
  /// context.addNonDartFile(file);
  /// ```
  void addNonDartFile(File file);

  /// {@macro configurable_runtime_provider}
  ///
  /// Adds a list of [LibraryDeclaration]s to the context.
  ///
  /// If [replace] is `true`, the existing library list will be cleared first.
  ///
  /// ```dart
  /// context.addLibraries([lib1, lib2], replace: true);
  /// ```
  void addLibraries(List<LibraryDeclaration> libraries, {bool replace = false});

  /// {@macro configurable_runtime_provider}
  ///
  /// Adds a list of [Package]s to the context.
  ///
  /// If [replace] is `true`, existing packages will be cleared first.
  void addPackages(List<Package> packages, {bool replace = false});

  /// {@macro configurable_runtime_provider}
  ///
  /// Adds a list of [Asset]s to the context.
  ///
  /// If [replace] is `true`, existing assets will be replaced.
  void addAssets(List<Asset> assets, {bool replace = false});

  /// {@macro configurable_runtime_provider}
  ///
  /// Adds a list of [TypeDeclaration]s as special types to the context.
  ///
  /// If [replace] is `true`, all previous special types will be cleared first.
  void addSpecialTypes(List<TypeDeclaration> types, {bool replace = false});

  /// {@macro configurable_runtime_provider}
  ///
  /// Adds a list of [File]s as non-dart files to the context.
  ///
  /// If [replace] is `true`, all previous non-dart files will be cleared first.
  void addNonDartFiles(List<File> files, {bool replace = false});

  /// {@macro configurable_runtime_provider}
  ///
  /// Sets the runtime resolver used to resolve descriptors entities.
  void setRuntimeResolver(RuntimeResolver resolver);
}