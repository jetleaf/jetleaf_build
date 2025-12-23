part of 'runtime_provider.dart';

/// Adds a [Package] representing a scanned or resolved Dart package to the
/// active runtime reflection context.
///
/// This method is part of the **internal population phase** of the JetLeaf
/// runtime. Packages added here become available for:
/// - Library materialization
/// - Dependency resolution
/// - Runtime and reflection queries
///
/// ```dart
/// addRuntimePackage(myPackage);
/// ```
///
/// This API is **internal-only** and must be invoked *before* the runtime
/// registry is frozen.
@internal
void addRuntimePackage(Package package) => _InternalRuntime.addPackage(package);

/// Adds an [Asset] representing a non-Dart resource to the runtime context.
///
/// Assets typically include configuration files, text resources, JSON metadata,
/// or other bundled, non-code artifacts that participate in reflection or
/// generation workflows.
///
/// ```dart
/// addRuntimeAsset(Asset('config.json', contents));
/// ```
///
/// Assets added here are exposed via [RuntimeProvider.getAllAssets].
/// This API is **internal-only** and must be invoked before freezing.
@internal
void addRuntimeAsset(Asset asset) => _InternalRuntime.addAsset(asset);

/// Adds multiple [Package] instances to the runtime context.
///
/// This is a bulk variant of [addRuntimePackage] intended for efficient
/// initialization during scanning or bootstrap phases.
///
/// If [replace] is `true`:
/// - All previously registered packages are cleared
/// - The provided list becomes the complete package set
///
/// This API is **internal-only** and must be invoked before freezing.
@internal
void addRuntimePackages(List<Package> packages, {bool replace = false}) => _InternalRuntime.addPackages(packages, replace: replace);

/// Adds multiple [Asset] instances to the runtime context.
///
/// This is a bulk variant of [addRuntimeAsset] intended for efficient runtime
/// initialization.
///
/// If [replace] is `true`:
/// - All previously registered assets are cleared
/// - The provided list becomes the complete asset set
///
/// Assets added here are exposed via [RuntimeProvider.getAllAssets].
/// This API is **internal-only** and must be invoked before freezing.
@internal
void addRuntimeAssets(List<Asset> assets, {bool replace = false}) => _InternalRuntime.addAssets(assets, replace: replace);

/// Sets the [RuntimeExecutor] used to resolve and execute descriptor-backed
/// entities at runtime.
///
/// The provided resolver becomes the **authoritative execution engine**
/// for all reflection-driven runtime behavior, including:
/// - Descriptor resolution
/// - Reflected invocation and construction
/// - Runtime binding of materialized declarations
///
/// This must be configured exactly once during initialization and
/// before the runtime is frozen.
@internal
void setRuntimeResolver(RuntimeExecutor resolver) => _InternalRuntime.setRuntimeResolver(resolver);

/// Adds and materializes a source-level Dart library into the runtime registry.
///
/// This function bridges raw runtime discovery with the underlying
/// [MaterialLibrary] implementation, enabling:
/// - Source-to-runtime identity binding
/// - Class and declaration discovery
/// - Cross-package type resolution
///
/// This API participates in the **library population phase** and must be
/// invoked before [freezeRuntimeLibrary] is called.
@internal
void addRuntimeSourceLibrary(
  Package package,
  String sourceCode,
  bool isSdkLibrary,
  mirrors.LibraryMirror library,
) => _InternalRuntime.addLibrary(package, sourceCode, isSdkLibrary, library);

/// Freezes the runtime materialized library registry.
///
/// After this call:
/// - No additional packages, assets, or libraries may be added
/// - All lookup and resolution results become deterministic
/// - Read-only, thread-safe access is guaranteed
///
/// This marks the transition from **population** to **query** phase.
@internal
void freezeRuntimeLibrary() => _InternalRuntime.freezeLibrary();

/// Tags the runtime materialized library with a diagnostic or origin label.
///
/// This is typically used to associate the registry with a specific
/// build, environment, or execution context for debugging and tracing
/// purposes.
///
/// This API is **internal-only** and should be called before freezing.
@internal
void setRuntimeLibraryTag(String taggedLocation) => _InternalRuntime.setTag(taggedLocation);

/// Creates a built-in Dart SDK [Package] instance.
///
/// - Uses the root package version and language version from the cached packages
///   if available, defaults to Dart 3.0.
/// - Sets `rootUri` to `dart:core`.
///
/// - Returns: A [MaterialPackage] representing the Dart SDK.
@internal
Package createBuiltInPackage(Map<String, Package> cache) => MaterialPackage(
  name: Constant.DART_PACKAGE_NAME,
  version: cache.values
    .where((v) => v.getIsRootPackage())
    .firstOrNull?.getLanguageVersion() ?? '3.0',
  languageVersion: cache.values
    .where((v) => v.getIsRootPackage())
    .firstOrNull?.getLanguageVersion() ?? '3.0',
  isRootPackage: false,
  rootUri: 'dart:core',
  filePath: null,
  jetleafDependencies: [],
  dependencies: [],
  devDependencies: []
);

/// Creates a default [Package] instance with placeholder values.
///
/// - [name]: The name of the package.
/// - Returns: A new [MaterialPackage] with default metadata.
@internal
Package createDefaultPackage(String name) {
  return MaterialPackage(
    name: name,
    version: '0.0.0',
    languageVersion: null,
    isRootPackage: false,
    rootUri: null,
    filePath: null,
    jetleafDependencies: [],
    dependencies: [],
    devDependencies: []
  );
}

/// The internal, concrete runtime-backed implementation of [RuntimeProvider]
/// and [MaterialLibrary].
///
/// This instance serves as the **single authoritative runtime registry**
/// for the current execution context and is not exposed directly to
/// application or package code.
final _MaterialRuntimeProvider _InternalRuntime = _MaterialRuntimeProvider._();

@internal
extension StringExte on String {
  /// Case-insensitive in-equality check.
  bool notEqualsIgnoreCase(String value) => toLowerCase() != value.toLowerCase();
}