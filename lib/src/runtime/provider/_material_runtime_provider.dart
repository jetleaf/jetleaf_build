part of 'runtime_provider.dart';

/// {@template _material_runtime_provider}
/// Internal implementation of [RuntimeProvider] that extends [_MaterialLibrary].
///
/// This class manages runtime packages, assets, and the runtime resolver
/// for material libraries. It provides methods to add and retrieve packages
/// and assets, ensures deduplication by file paths, and exposes the runtime
/// executor for executing or resolving runtime-dependent operations.
///
/// It is designed to be used internally by the runtime system to maintain
/// consistent access to scanned libraries, assets, and packages.
///
/// Fields:
/// - `_packages`: List of registered packages for runtime use.
/// - `_assets`: List of registered assets, such as source files or resources.
/// - `_runtimeResolver`: Optional runtime executor that performs runtime-specific tasks.
///
/// Example:
/// ```dart
/// final provider = _MaterialRuntimeProvider._();
/// provider.addPackage(myPackage);
/// provider.addAsset(myAsset);
/// provider.setRuntimeResolver(myExecutor);
/// final packages = provider.getAllPackages();
/// final assets = provider.getAllAssets();
/// final resolver = provider.getRuntimeResolver();
/// ```
/// {@endtemplate}
final class _MaterialRuntimeProvider extends _MaterialLibrary implements RuntimeProvider {
  /// Registered runtime packages.
  List<Package> _packages = [];

  /// Registered runtime assets.
  List<Asset> _assets = [];

  /// Optional runtime executor for executing or resolving runtime tasks.
  RuntimeExecutor? _runtimeResolver;

  /// Private constructor for internal initialization.
  /// 
  /// {@macro _material_runtime_provider}
  _MaterialRuntimeProvider._();

  /// Adds a [Package] representing a scanned or resolved Dart package to the
  /// active runtime reflection context.
  ///
  /// This method is part of the **internal population phase** of the JetLeaf
  /// runtime. Packages added here become available for:
  /// - Library materialization
  /// - Dependency resolution
  /// - Runtime and reflection queries
  ///
  /// Example:
  /// ```dart
  /// provider.addPackage(myPackage);
  /// ```
  ///
  /// ⚠️ **Internal API:** Must be invoked *before* the runtime registry is frozen.
  void addPackage(Package package) => _packages.add(package);

  /// Adds an [Asset] (source file, resource, etc.) to the runtime context.
  ///
  /// These assets are later used for reflection, scanning, or materialization.
  ///
  /// Example:
  /// ```dart
  /// provider.addAsset(myAsset);
  /// ```
  void addAsset(Asset asset) => _assets.add(asset);

  /// Adds multiple [packages] to the runtime context, optionally replacing
  /// the existing packages if [replace] is `true`.
  ///
  /// Example:
  /// ```dart
  /// provider.addPackages([pkg1, pkg2], replace: true);
  /// ```
  void addPackages(List<Package> packages, {bool replace = false}) {
    if (replace) {
      _packages.clear();
    }
    _packages.addAll(packages);
  }

  /// Adds multiple [assets] to the runtime context, optionally replacing
  /// existing assets if [replace] is `true`.
  ///
  /// Example:
  /// ```dart
  /// provider.addAssets([asset1, asset2], replace: true);
  /// ```
  void addAssets(List<Asset> assets, {bool replace = false}) {
    if (replace) {
      _assets.clear();
    }
    _assets.addAll(assets);
  }

  /// Sets the [RuntimeExecutor] responsible for resolving runtime tasks.
  ///
  /// Example:
  /// ```dart
  /// provider.setRuntimeResolver(myExecutor);
  /// ```
  void setRuntimeResolver(RuntimeExecutor resolver) {
    _runtimeResolver = resolver;
  }

  /// Deduplicates items by their file path.
  ///
  /// Takes an [Iterable] of items and a function [getFilePath] to extract
  /// the file path from each item. Returns a list with duplicates removed
  /// based on file path.
  ///
  /// Example:
  /// ```dart
  /// final uniquePackages = _dedupeByFilePath(packages, (p) => p.getFilePath());
  /// ```
  List<T> _dedupeByFilePath<T>(Iterable<T> items, String? Function(T) getFilePath) {
    final seen = <String?>{};
    final result = <T>[];

    for (final item in items) {
      final path = getFilePath(item);
      if (seen.contains(path)) continue;
      seen.add(path);
      result.add(item);
    }

    return result;
  }

  @override
  void freezeLibrary() {
    super.freezeLibrary();

    _assets = _dedupeByFilePath(_assets, (asset) => asset.getFilePath());
    _packages = _dedupeByFilePath(_packages, (pkg) => pkg.getFilePath() ?? pkg.getName());
  }
  
  @override
  List<Asset> getAllAssets() => UnmodifiableListView(_assets);
  
  @override
  List<Package> getAllPackages() => UnmodifiableListView(_packages);

  @override
  Package? getPackage(String packageName) => _packages.where((p) => p.getName() == packageName).firstOrNull;

  @override
  Package? getCurrentPackage() => _packages.where((p) => p.getIsRootPackage()).firstOrNull;
  
  @override
  RuntimeExecutor getRuntimeResolver() {
    if (_runtimeResolver case final resolver?) {
      return resolver;
    }

    throw BuildException('Runtime is not yet initialized. Did you forget to run scan with `runScan` or `runTestScan`?');
  }

  @override
  String toString() {
    final parts = <String>[];

    final packageCount = _packages.length;
    if (packageCount > 0) {
      parts.add("$packageCount package${packageCount == 1 ? '' : 's'}");
    }

    final libraryCount = _sourceLibraries.length;
    if (libraryCount > 0) {
      parts.add("$libraryCount librar${libraryCount == 1 ? 'y' : 'ies'}");
    }

    final assetCount = _assets.length;
    if (assetCount > 0) {
      parts.add("$assetCount asset${assetCount == 1 ? '' : 's'}");
    }

    final resolverInfo = _runtimeResolver?.runtimeType ?? 'no';

    String description;
    if (parts.isEmpty) {
      description = "no packages, libraries, or assets";
    } else if (parts.length == 1) {
      description = parts.first;
    } else {
      // join all but the last with commas, add "and" before last
      description = parts.sublist(0, parts.length - 1).join(", ");
      description += " and ${parts.last}";
    }

    return "This runtime, tagged '$_taggedLocation' with $resolverInfo executor, currently manages $description.";
  }
}