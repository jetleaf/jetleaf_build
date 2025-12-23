part of 'declaration.dart';

/// {@template package}
/// Represents a **Dart package** within the JetLeaf reflection and
/// code generation system.
///
/// A [Package] is a **pure metadata model** describing a Dart package
/// and its relationship to the JetLeaf ecosystem. It is used by the
/// runtime provider, class loader, and code generator to understand
/// where types originate and how they should be resolved.
///
/// A [Package] encapsulates:
/// - Package name and semantic version
/// - Dart language version constraints
/// - Package root location (file system path or URI)
/// - Dependency metadata (runtime, dev, and JetLeaf-specific)
/// - Whether the package is the root application package
///
/// ---
///
/// ## Design Notes
///
/// - This class performs **no I/O or resolution**
/// - All instances are **immutable**
/// - It acts as a declarative description only
/// - Package resolution and graph construction occur elsewhere
///
/// ---
///
/// ## Usage
///
/// [Package] instances are typically constructed from:
/// - `package_graph.json`
/// - `pubspec.yaml`
/// - Runtime package discovery
///
/// and then consumed by:
/// - Class loaders
/// - Reflection utilities
/// - Code generators
///
/// {@endtemplate}
abstract class Package extends BaseDeclaration with ToString {
  /// The **name of the package** (e.g. `'jetleaf'`, `'http'`).
  final String _name;

  /// The **semantic version** of the package (e.g. `'2.7.0'`).
  final String _version;

  /// The Dart language version constraint for this package,
  /// or `null` if unspecified.
  final String? _languageVersion;

  /// Whether this package represents the **root application package**.
  final bool _isRootPackage;

  /// Absolute file system path to the package root, if available.
  final String? _filePath;

  /// Root URI of the package, if available.
  final String? _rootUri;

  /// Dependencies that belong to the **JetLeaf ecosystem**.
  ///
  /// These are used by the runtime to:
  /// - Enable JetLeaf-specific behaviors
  /// - Activate reflection or code generation features
  /// - Detect framework-level integration
  final Iterable<String> _jetleafDependencies;

  /// Regular (runtime) dependencies of this package.
  final Iterable<String> _dependencies;

  /// Development-only dependencies of this package.
  final Iterable<String> _devDependencies;

  /// {@macro package}
  const Package({
    required String name,
    required String version,
    String? languageVersion,
    required bool isRootPackage,
    String? filePath,
    String? rootUri,
    Iterable<String> jetleafDependencies = const [],
    Iterable<String> dependencies = const [],
    Iterable<String> devDependencies = const [],
  })  : _filePath = filePath,
        _languageVersion = languageVersion,
        _version = version,
        _name = name,
        _isRootPackage = isRootPackage,
        _jetleafDependencies = jetleafDependencies,
        _dependencies = dependencies,
        _devDependencies = devDependencies,
        _rootUri = rootUri;

  /// Returns the **name of the package**.
  ///
  /// Example:
  /// ```dart
  /// final packageName = myPackage.getName(); // 'jetleaf'
  /// ```
  String getName() => _name;

  /// Returns the **version of the package**.
  ///
  /// Example:
  /// ```dart
  /// final version = myPackage.getVersion(); // '2.7.0'
  /// ```
  String getVersion() => _version;

  /// Returns the **Dart language version constraint** of the package,
  /// or `null` if it was not specified.
  ///
  /// Example:
  /// ```dart
  /// final languageVersion = myPackage.getLanguageVersion(); // '3.3'
  /// ```
  String? getLanguageVersion() => _languageVersion;

  /// Returns `true` if this package is the **root application package**.
  ///
  /// Example:
  /// ```dart
  /// final isRoot = myPackage.getIsRootPackage(); // true
  /// ```
  bool getIsRootPackage() => _isRootPackage;

  /// Returns the **absolute file system path** to the package root,
  /// or `null` if unavailable.
  ///
  /// Example:
  /// ```dart
  /// final path = myPackage.getFilePath(); // '/Users/me/projects/my_package'
  /// ```
  String? getFilePath() => _filePath;

  /// Returns the **root URI** of the package, or `null` if unavailable.
  ///
  /// Example:
  /// ```dart
  /// final uri = myPackage.getRootUri(); // 'file:///Users/me/projects/my_package/'
  /// ```
  String? getRootUri() => _rootUri;

  /// Returns the **JetLeaf-specific dependencies** of this package.
  ///
  /// This includes only the dependencies that are considered part of the
  /// JetLeaf framework or ecosystem. It provides a convenient way to
  /// retrieve the subset of dependencies that are relevant for
  /// JetLeaf runtime or reflection purposes.
  ///
  /// Example:
  /// ```dart
  /// final jetleafDeps = myPackage.getJetleafDependencies();
  /// print(jetleafDeps); // {'jetleaf_core', 'jetleaf_utils'}
  /// ```
  Iterable<String> getJetleafDependencies() => _jetleafDependencies;

  /// Returns all dependencies of this package (including jetleaf dependencies too - if any).
  ///
  /// This includes only the dependencies that are considered part of the
  /// JetLeaf framework or ecosystem. It provides a convenient way to
  /// retrieve the subset of dependencies that are relevant for
  /// JetLeaf runtime or reflection purposes.
  ///
  /// Example:
  /// ```dart
  /// final jetleafDeps = myPackage.getJetleafDependencies();
  /// print(jetleafDeps); // {'jetleaf_core', 'jetleaf_utils', 'http'}
  /// ```
  Iterable<String> getDependencies() => _dependencies;

  /// Returns all dev dependencies of this package (including jetleaf dependencies too - if any).
  ///
  /// This includes only the dependencies that are considered part of the
  /// JetLeaf framework or ecosystem. It provides a convenient way to
  /// retrieve the subset of dependencies that are relevant for
  /// JetLeaf runtime or reflection purposes.
  ///
  /// Example:
  /// ```dart
  /// final jetleafDeps = myPackage.getJetleafDependencies();
  /// print(jetleafDeps); // {'jetleaf_core', 'jetleaf_utils', 'http'}
  /// ```
  Iterable<String> getDevDependencies() => _devDependencies;

  /// Returns `true` if this package is **JetLeaf-enabled**.
  ///
  /// A package is considered JetLeaf-packaged if it declares at least
  /// one dependency that belongs to the JetLeaf ecosystem.
  ///
  /// This flag is used by the runtime to:
  /// - Enable JetLeaf-specific reflection
  /// - Allow class materialization
  /// - Apply framework conventions and tooling
  ///
  /// ---
  ///
  /// ## Example
  /// ```dart
  /// if (package.isJetleafPackaged()) {
  ///   enableJetLeafReflection(package);
  /// }
  /// ```
  bool isJetleafPackaged() => getJetleafDependencies().isNotEmpty;

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['name'] = getName();
    result['version'] = getVersion();

    if (getLanguageVersion() != null) {
      result['languageVersion'] = getLanguageVersion()!;
    }

    result['isRootPackage'] = getIsRootPackage();

    if (getFilePath() != null) {
      result['filePath'] = getFilePath()!;
    }

    if (getRootUri() != null) {
      result['rootUri'] = getRootUri()!;
    }

    if (getJetleafDependencies().isNotEmpty) {
      result["jetleaf_dependencies"] = getJetleafDependencies();
    }

    if (getDependencies().isNotEmpty) {
      result["dependencies"] = getDependencies();
    }

    if (getDevDependencies().isNotEmpty) {
      result["devDependencies"] = getDevDependencies();
    }

    return result;
  }

  @override
  List<Object?> equalizedProperties() => [
    _name,
    _version,
    _languageVersion,
    _isRootPackage,
    _filePath,
    _rootUri,
    _jetleafDependencies,
    _dependencies,
    _devDependencies
  ];

  @override
  ToStringOptions toStringOptions() => ToStringOptions(
    customParameterNames: [
      "name",
      "version",
      "languageVersion",
      "isCurrentPackage",
      "filePath",
      "rootUri",
      "jetleafDependencies",
      "dependencies",
      "devDependencies"
    ]
  );
}

/// {@template package_implementation}
/// A concrete, immutable implementation of the [Package] interface.
///
/// Represents a Dart package with metadata such as name, version,
/// file path, and language version.
///
/// Useful in reflective frameworks, build tools, or analyzers
/// that inspect or manipulate Dart packages programmatically.
///
/// ### Example
/// ```dart
/// final package = MaterialPackage(
///   name: 'jetleaf',
///   version: '1.2.3',
///   languageVersion: '3.3',
///   isRootPackage: true,
///   filePath: '/project/jetleaf/pubspec.yaml',
/// );
///
/// print(package.name); // jetleaf
/// print(package.isRootPackage); // true
/// ```
/// {@endtemplate}
@internal
final class MaterialPackage extends Package with EqualsAndHashCode {
  /// {@macro package_implementation}
  const MaterialPackage({
    required super.name,
    required super.version,
    super.languageVersion,
    required super.isRootPackage,
    required super.filePath,
    required super.rootUri,
    required super.jetleafDependencies,
    required super.dependencies,
    required super.devDependencies
  });
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
    jetleafDependencies: const [],
    dependencies: const [],
    devDependencies: const []
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

  @override
  Iterable<String> getJetleafDependencies();

  @override
  Iterable<String> getDependencies();

  @override
  Iterable<String> getDevDependencies();
}