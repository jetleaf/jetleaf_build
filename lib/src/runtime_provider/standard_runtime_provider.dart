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

import '../declaration/declaration.dart';
import '../exceptions.dart';
import '../runtime_resolver/runtime_resolver.dart';
import 'configurable_runtime_provider.dart';

/// {@template standard_runtime_provider}
/// Default mutable implementation of [ConfigurableRuntimeProvider].
///
/// This class collects runtime metadata during the context construction
/// phase. Internally, it stores discovered libraries, packages, assets,
/// environment entries, and special types. Once all metadata is added,
/// it can be finalized into an immutable [ReflectedContext] via [build].
///
/// This class is used by the runtime engine, compilers, and
/// custom context processors that extend the metadata model.
///
/// ## Example
/// ```dart
/// final context = StandardRuntimeProvider();
/// // Assuming you have a way to create ReflectedLibrary instances
/// // context.addLibrary(myReflectedLibrary);
/// context.addEnvironment('env', 'dev');
///
/// final runtime = context.build();
/// print(runtime.getMetadata().getAllClasses().length);
/// ```
/// {@endtemplate}
final class StandardRuntimeProvider extends ConfigurableRuntimeProvider {
  final List<LibraryDeclaration> _libraries = [];
  final List<Package> _packages = [];
  final List<Asset> _assets = [];
  final List<TypeDeclaration> _specialTypes = [];
  RuntimeResolver? _runtimeResolver;

  /// {@macro standard_runtime_provider}
  StandardRuntimeProvider() : super();

  @override
  void addLibrary(LibraryDeclaration library) => _libraries.add(library);

  @override
  void addPackage(Package package) => _packages.add(package);

  @override
  void addAsset(Asset asset) => _assets.add(asset);
  
  @override
  void addSpecialType(TypeDeclaration type) => _specialTypes.add(type);

  @override
  void addLibraries(List<LibraryDeclaration> libraries, {bool replace = false}) {
    if (replace) {
      _libraries.clear();
    }
    _libraries.addAll(libraries);
  }

  @override
  void addPackages(List<Package> packages, {bool replace = false}) {
    if (replace) {
      _packages.clear();
    }
    _packages.addAll(packages);
  }

  @override
  void addAssets(List<Asset> assets, {bool replace = false}) {
    if (replace) {
      _assets.clear();
    }
    _assets.addAll(assets);
  }

  @override
  void addSpecialTypes(List<TypeDeclaration> types, {bool replace = false}) {
    if (replace) {
      _specialTypes.clear();
    }
    _specialTypes.addAll(types);
  }

  @override
  void setRuntimeResolver(RuntimeResolver resolver) {
    _runtimeResolver = resolver;
  }

  @override
  List<LibraryDeclaration> getAllLibraries() => _libraries;

  @override
  List<TypeDeclaration> getSpecialTypes() => _specialTypes;

  @override
  RuntimeResolver getRuntimeResolver() => _runtimeResolver ?? (throw BuildException('Runtime resolver not set'));
  
  @override
  List<Asset> getAllAssets() => _assets;
  
  @override
  List<Package> getAllPackages() => _packages;
}