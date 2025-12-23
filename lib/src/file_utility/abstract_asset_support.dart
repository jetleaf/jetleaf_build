import 'dart:io';
import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../runtime/declaration/declaration.dart';
import '../system/system.dart';
import '../utils/constant.dart';
import 'abstract_file_utility.dart';
import 'abstract_part_file_utility.dart';

/// Signature for file-level asset filtering during filesystem scans.
///
/// A [_Filter] is invoked for every file encountered while recursively
/// traversing directories during asset discovery.
///
/// Implementations should be **pure predicates**:
/// - They must not perform I/O
/// - They must not mutate external state
///
/// Returning `true` indicates that the file should be included
/// as an asset; returning `false` excludes it.
///
/// ---
///
/// ## Parameters
/// - [filePath]: Absolute path to the file being evaluated
/// - [extension]: Lower-cased file extension (including the leading `.`),
///   derived from [filePath]
///
/// ---
///
/// ## Typical Use Cases
/// - Excluding Dart source files (`.dart`)
/// - Ignoring configured extensions (e.g. `.md`, `.lock`)
/// - Restricting discovery to user-specified asset types
/// - Preventing duplicate discovery from canonical directories
///
/// ---
///
/// ## Example
/// ```dart
/// final filter = (String path, String ext) {
///   if (ext == '.dart') return false;
///   return ext == '.json' || ext == '.yaml';
/// };
/// ```
typedef _Filter = bool Function(String filePath, String extension);

/// Base class providing **comprehensive asset discovery infrastructure**
/// for JetLeaf-based applications and frameworks.
///
/// This class encapsulates all logic required to locate, load, and
/// aggregate resource assets from multiple sources, including:
///
/// - The current application project
/// - All resolved package dependencies
/// - Reflective (mirror-based) generative asset providers
///
/// ---
///
/// ## Responsibilities
///
/// `AbstractAssetSupport` is responsible for:
///
/// - Walking filesystem trees efficiently
/// - Applying configurable asset filters
/// - Preventing duplicate asset discovery
/// - Associating assets with their originating packages
/// - Handling I/O and reflection errors gracefully
///
/// ---
///
/// ## Design Notes
///
/// - This class is **abstract** and intended to be extended
///   by concrete build-time or runtime asset loaders
/// - Asset discovery is **eager**: file contents are read
///   fully into memory
/// - Discovery is **order-preserving** within each phase
///
/// ---
///
/// ## Performance Considerations
///
/// - Directory traversal is recursive and I/O heavy
/// - Consumers are strongly encouraged to cache results
/// - Dependency scanning can be restricted via configuration
///
/// ---
///
/// ## Related Types
/// - [Asset]
/// - [MaterialAsset]
/// - [GenerativeAsset]
/// - [AbstractPartFileUtility]
///
/// ---
///
/// ## Typical Lifecycle
///
/// 1. Load package configuration
/// 2. Discover project assets
/// 3. Discover dependency assets
/// 4. Discover generative assets (optional)
/// 5. Return unified asset list
abstract class AbstractAssetSupport extends AbstractPartFileUtility {
  /// Creates a new [AbstractAssetSupport] instance.
  ///
  /// This constructor wires together shared infrastructure required
  /// for asset discovery, including configuration access, logging,
  /// and isolate-safe execution utilities.
  ///
  /// All parameters are forwarded directly to the base
  /// [AbstractPartFileUtility] constructor.
  ///
  /// ---
  ///
  /// ## Parameters
  ///
  /// - [configuration]:
  ///   Global configuration controlling asset discovery behavior,
  ///   including extension filters and package inclusion rules.
  ///
  /// - [onError]:
  ///   Callback invoked for **fatal or unrecoverable errors**
  ///   during scanning or reflection.
  ///
  /// - [onInfo]:
  ///   Callback for informational progress messages.
  ///
  /// - [onWarning]:
  ///   Callback for non-fatal issues such as unreadable files.
  ///
  /// - [tryOutsideIsolate]:
  ///   Utility function used to execute blocking or unsafe operations
  ///   outside the current isolate when required.
  ///
  /// ---
  ///
  /// ## Notes
  ///
  /// - This constructor performs **no I/O**
  /// - Package configuration is loaded lazily
  /// - Asset discovery does not begin until explicitly requested
  AbstractAssetSupport(super.configuration, super.onError, super.onInfo, super.onWarning, super.tryOutsideIsolate);

  /// Discovers **all resource assets** available to the current application,
  /// including:
  /// - Project-local resources
  /// - Dependency resources
  /// - Generated (mirror-based) assets
  ///
  /// This method serves as the **primary asset discovery pipeline** in JetLeaf.
  /// It aggregates assets from multiple sources into a single, unified list.
  ///
  /// ---
  ///
  /// ## Discovery Phases
  ///
  /// The discovery process runs in the following order:
  ///
  /// ### 1️⃣ User Project Scan
  /// Scans the current project root for resources:
  /// - **Default directories** (`resources/`, `assets/`, and `lib/` variants)
  /// - **Root-level extension-based assets** (based on configuration)
  ///
  /// ### 2️⃣ Dependency Scan
  /// Iterates over all resolved package dependencies and performs the same
  /// scanning strategy as the user project, subject to package filters.
  ///
  /// Packages are skipped if:
  /// - They appear in `configuration.packagesToExclude`, or
  /// - They are not listed in `configuration.packagesToScan` (when non-empty)
  ///
  /// ### 3️⃣ Mirror-Based Generation
  /// Optionally scans runtime mirrors for **generative assets**, such as
  /// resources produced by annotations, code generation, or reflection-based
  /// providers.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [currentPackageName]: Name of the root application package
  /// - [mirrorSystem]: Optional [mirrors.MirrorSystem] used to discover generative assets
  /// - [libraries]: Optional subset of libraries to restrict mirror scanning
  ///
  /// ## Returns
  /// A flat list of all discovered [Asset] instances, including duplicates
  /// if they originate from different packages or sources.
  ///
  /// ---
  ///
  /// ## Notes
  /// - Asset discovery is **I/O intensive** and should not be run repeatedly
  ///   without caching.
  /// - This method assumes package configuration has been loaded; if not,
  ///   it will load it automatically.
  ///
  /// ---
  ///
  /// ## Example
  /// ```dart
  /// final assets = await discoverAllResources('my_app');
  /// for (final asset in assets) {
  ///   print('${asset.packageName}: ${asset.fileName}');
  /// }
  /// ```
  Future<List<Asset>> discoverAllResources(String currentPackageName, [mirrors.MirrorSystem? mirrorSystem, List<mirrors.LibraryMirror>? libraries]) async {
    if (packageConfigCache == null) {
      await loadPackageConfig();
    }

    final List<Asset> allResources = [];
    final currentProjectRoot = Directory.current.path;

    // 1. Scan user's project
    onInfo('🔍 Scanning user project for resources...', true);
    
    // 1a. Scan default directories (all non-Dart files)
    allResources.addAll(await _scanDefaultDirectories(currentProjectRoot, currentPackageName));
    
    // 1b. Scan project root for specific extensions
    allResources.addAll(await _scanRootForExtensions(currentProjectRoot, currentPackageName));

    // 2. Scan dependencies
    onInfo('🔍 Scanning all dependencies for resources...', true);
    for (final dep in (packageConfigCache ?? <PackageConfigEntry>[])) {
      final depPackagePath = dep.absoluteRootPath;
      final packageName = dep.name;

      // Check if package should be scanned
      if (!_shouldScanPackage(packageName)) continue;
      
      final depRoot = Directory(depPackagePath);
      if (!depRoot.existsSync()) continue;

      // 2a. Scan default directories in dependency
      allResources.addAll(await _scanDefaultDirectories(depPackagePath, packageName));
      
      // 2b. Scan dependency root for specific extensions
      if (configuration.searchAssetExtensionsInProjectOnly) {
        continue;
      } else {
        allResources.addAll(await _scanRootForExtensions(depPackagePath, packageName));
      }
    }

    // 3. Scan for generative assets from mirrors
    if (mirrorSystem != null) {
      allResources.addAll(await _scanMirrorForGenerativeAssets(mirrorSystem, libraries));
    }

    for (final asset in allResources) {
      print(asset.getFilePath());
    }
    
    return allResources;
  }

  /// Scans the **default resource directories** within a package root
  /// and returns all matching non-Dart assets.
  ///
  /// Default directories include:
  /// - `<root>/resources`
  /// - `<root>/lib/resources`
  /// - `<root>/assets`
  /// - `<root>/lib/assets`
  ///
  /// These locations are treated as **canonical asset roots**, and all
  /// non-Dart files within them are included unless explicitly ignored
  /// by configuration.
  ///
  /// ---
  ///
  /// ## Filtering Rules
  /// - `.dart` files are always excluded
  /// - Extensions listed in
  ///   `configuration.assetExtensionsToIgnoreSearch` are excluded
  /// - All remaining files are included
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [rootPath]: Absolute path to the package root
  /// - [packageName]: Name of the package owning the resources
  ///
  /// ## Returns
  /// A list of [Asset] instances discovered in default directories.
  ///
  /// ---
  ///
  /// ## Example
  /// ```dart
  /// final assets = await _scanDefaultDirectories(
  ///   '/my_package',
  ///   'my_package',
  /// );
  /// ```
  Future<List<Asset>> _scanDefaultDirectories(String rootPath, String packageName) async {
    final List<Asset> resources = [];
    
    final defaultDirs = _getSearchDirectories(rootPath);
    
    for (final dir in defaultDirs) {
      if (!dir.existsSync()) continue;
      
      final dirResources = await _scanWithFilter(
        dir,
        packageName,
        (filePath, extension) {
          // Skip Dart files
          if (extension == '.dart') return false;
          
          // Skip ignored extensions
          final extensionsToIgnore = configuration.assetExtensionsToIgnoreSearch;
          if (extensionsToIgnore.any((ext) => extension == ext.toLowerCase())) {
            return false;
          }
          
          // Include all non-Dart files in default directories
          return true;
        },
      );
      
      resources.addAll(dirResources);
    }
    
    return resources;
  }

  /// Returns the **default directories** that should be searched for
  /// package resources and assets under the given [root] path.
  ///
  /// JetLeaf supports both top-level and `lib/`-scoped resource layouts
  /// to accommodate different package structures and build systems.
  ///
  /// The following directories are considered (if they exist):
  /// - `<root>/<resources>`
  /// - `<root>/lib/<resources>`
  /// - `<root>/<assets>`
  /// - `<root>/lib/<assets>`
  ///
  /// where:
  /// - `<resources>` is [Constant.RESOURCES_DIR_NAME]
  /// - `<assets>` is [Constant.PACKAGE_ASSET_DIR]
  ///
  /// These directories are treated as **canonical locations** for
  /// resource discovery and are excluded from secondary scans to
  /// prevent duplicate asset detection.
  List<Directory> _getSearchDirectories(String root) => [
    Directory(p.join(root, Constant.RESOURCES_DIR_NAME)),
    Directory(p.join(root, 'lib', Constant.RESOURCES_DIR_NAME)),
    Directory(p.join(root, Constant.PACKAGE_ASSET_DIR)),
    Directory(p.join(root, 'lib', Constant.PACKAGE_ASSET_DIR)),
  ];

  /// Scans the given package [rootPath] for **non-Dart asset files**
  /// that match user-configured extensions and are **not located in
  /// default resource directories**.
  ///
  /// This method is intended to find **custom or extension-based assets**
  /// that live outside the conventional `resources/` or `assets/`
  /// directories.
  ///
  /// ---
  ///
  /// ### Filtering Rules
  ///
  /// A file is included only if:
  /// - It is **not** a `.dart` file
  /// - Its extension is **not** listed in
  ///   `configuration.assetExtensionsToIgnoreSearch`
  /// - It is **not** located in one of the default search directories
  /// - Its extension matches one of
  ///   `configuration.assetExtensionsToSearch`
  ///
  /// If `assetExtensionsToSearch` is empty, no files are included.
  ///
  /// ---
  ///
  /// ### Parameters
  /// - [rootPath]: Absolute path to the package root directory
  /// - [packageName]: Name of the package the assets belong to
  ///
  /// ### Returns
  /// A list of [Asset] instances representing the discovered resources.
  /// Returns an empty list if the root directory does not exist.
  Future<List<Asset>> _scanRootForExtensions(String rootPath, String packageName) async {
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) return [];
    
    return await _scanWithFilter(
      rootDir,
      packageName,
      (filePath, extension) {
        final fileName = p.basename(filePath);
        final extensionsToIgnore = configuration.assetExtensionsToIgnoreSearch;
        final extensionsToSearch = configuration.assetExtensionsToSearch;
        
        // Helper to check if file matches any in a list
        bool matchesAny(List<String> extensions) => extensions.any((ext) => _matchesExtension(ext, filePath, fileName, extension));
        
        // Check if explicitly requested
        final isExplicitlyRequested = matchesAny(extensionsToSearch);
        
        // If user explicitly requested this extension, skip normal filters
        if (isExplicitlyRequested) {
          // Still respect ignore list
          if (matchesAny(extensionsToIgnore)) return false;
          
          // Skip duplicate check for explicitly requested extensions
          return !_isInDefaultDirectory(filePath, rootPath);
        }
        
        // Normal filtering flow
        return _passesNormalFilters(filePath, extension, rootPath);
      }
    );
  }

  /// Applies the **standard, non-default-directory asset filtering rules**
  /// to a candidate file during root-level or dependency scans.
  ///
  /// This method centralizes the logic used to decide whether a file
  /// should be included as an asset when scanning directories **outside**
  /// of the canonical `resources/` and `assets/` locations.
  ///
  /// ---
  ///
  /// ## High-Level Behavior
  ///
  /// A file is included **only if all of the following are true**:
  ///
  /// 1. It is **not** a Dart source file
  /// 2. It does **not** match any ignored extensions
  /// 3. It is **not located** in a default resource directory
  /// 4. It matches at least one configured search extension
  ///
  /// With one exception:
  /// - In **development mode**, `.env` files are always included,
  ///   even if they are not explicitly listed in
  ///   `assetExtensionsToSearch`.
  ///
  /// ---
  ///
  /// ## Parameters
  ///
  /// - [filePath]:
  ///   Absolute path to the file being evaluated.
  ///
  /// - [extension]:
  ///   Lower-cased file extension derived from [filePath].
  ///
  /// - [rootPath]:
  ///   Absolute path to the package root currently being scanned.
  ///   Used to detect whether a file resides in default asset directories.
  ///
  /// ---
  ///
  /// ## Special Cases
  ///
  /// ### Development `.env` Files
  /// When running in development mode:
  /// - Files ending in `.env`
  /// - Or files whose names start with `.env`
  ///
  /// are included automatically, even if not explicitly configured.
  /// This supports local environment configuration without polluting
  /// production asset lists.
  ///
  /// ---
  ///
  /// ## Returns
  /// `true` if the file should be included as an asset,
  /// otherwise `false`.
  bool _passesNormalFilters(String filePath, String extension, String rootPath) {
    final fileName = p.basename(filePath);
    final extensionsToIgnore = configuration.assetExtensionsToIgnoreSearch;
    final extensionsToSearch = configuration.assetExtensionsToSearch;
    
    // Skip Dart files
    if (extension == '.dart') return false;
    
    // Skip ignored extensions
    if (extensionsToIgnore.any((ext) => _matchesExtension(ext, filePath, fileName, extension))) {
      return false;
    }
    
    // Skip if file is in default directories
    if (_isInDefaultDirectory(filePath, rootPath)) {
      return false;
    }
    
    // Development mode: auto-add .env if not present
    if (System.isDevelopmentMode() && !extensionsToSearch.contains(".env") && _isEnvFile(filePath, fileName)) {
      return true;
    }
    
    if (extensionsToSearch.isEmpty) return false;
    
    return extensionsToSearch.any((ext) => _matchesExtension(ext, filePath, fileName, extension));
  }

  /// Determines whether a file matches a configured extension rule.
  ///
  /// This method supports **flexible matching semantics** beyond
  /// simple suffix-based extension checks, allowing configuration
  /// entries to match:
  ///
  /// - Standard extensions (e.g. `.json`)
  /// - Full filename suffixes (e.g. `.config.json`)
  /// - Filename prefixes (e.g. `.env`)
  ///
  /// ---
  ///
  /// ## Matching Rules
  ///
  /// A match occurs if **any** of the following are true:
  ///
  /// 1. The file extension exactly equals the configured value
  /// 2. The full file path ends with the configured value
  /// 3. The file name starts with the configured value
  ///
  /// All comparisons are performed case-insensitively.
  ///
  /// ---
  ///
  /// ## Parameters
  ///
  /// - [ext]:
  ///   Configured extension or pattern from user configuration.
  ///
  /// - [filePath]:
  ///   Absolute path to the file being evaluated.
  ///
  /// - [fileName]:
  ///   Basename of the file (derived from [filePath]).
  ///
  /// - [extension]:
  ///   Lower-cased file extension derived from [filePath].
  ///
  /// ---
  ///
  /// ## Returns
  /// `true` if the file matches the extension rule,
  /// otherwise `false`.
  bool _matchesExtension(String ext, String filePath, String fileName, String extension) {
    final extLower = ext.toLowerCase();
    return extension == extLower || filePath.endsWith(extLower) || fileName.startsWith(extLower);
  }

  /// Determines whether a file should be treated as an environment file.
  ///
  /// A file is considered an environment file if:
  /// - Its path ends with `.env`, or
  /// - Its filename begins with `.env`
  ///
  /// This includes common patterns such as:
  /// - `.env`
  /// - `.env.local`
  /// - `.env.development`
  ///
  /// ---
  ///
  /// ## Parameters
  ///
  /// - [filePath]:
  ///   Absolute path to the file.
  ///
  /// - [fileName]:
  ///   Basename of the file.
  ///
  /// ---
  ///
  /// ## Returns
  /// `true` if the file is recognized as an environment file,
  /// otherwise `false`.
  bool _isEnvFile(String filePath, String fileName) => filePath.endsWith(".env") || fileName.startsWith(".env");

  /// Returns `true` if the given [filePath] resides inside one of the
  /// **default resource directories** for the specified [rootPath].
  ///
  /// This helper is used to prevent duplicate asset discovery when
  /// performing broader filesystem scans.
  bool _isInDefaultDirectory(String filePath, String rootPath) {
    final defaultDirs = _getSearchDirectories(rootPath);
    return defaultDirs.any((dir) => filePath.startsWith(dir.path));
  }

  /// Recursively scans the directory [dir] and returns all assets
  /// that satisfy the provided [filter].
  ///
  /// This method performs the core filesystem traversal and is shared
  /// by multiple scanning strategies.
  ///
  /// ---
  ///
  /// ### Behavior
  /// - Traverses directories recursively
  /// - Follows symbolic links
  /// - Applies the [filter] to each file before loading it
  /// - Reads file contents eagerly into memory
  ///
  /// ---
  ///
  /// ### Error Handling
  /// - Individual file read failures are logged as warnings and skipped
  /// - Directory traversal failures are logged as errors
  /// - A summary of failures is emitted after the scan completes
  ///
  /// ---
  ///
  /// ### Parameters
  /// - [dir]: Root directory to scan
  /// - [packageName]: Package name to associate with discovered assets
  /// - [filter]: Predicate that determines whether a file should be included
  ///
  /// ### Returns
  /// A list of [Asset] objects created from the files that passed the filter.
  Future<List<Asset>> _scanWithFilter(Directory dir, String packageName, _Filter filter) async {
    final List<Asset> resources = [];
    final List<String> failedFiles = [];
    
    try {
      await for (final entity in dir.list(recursive: true, followLinks: true)) {
        if (entity is! File) continue;
        
        final filePath = entity.path;
        final extension = p.extension(filePath).toLowerCase();
        
        // Apply filter
        if (!filter(filePath, extension)) continue;
        
        try {
          final asset = MaterialAsset(
            filePath: filePath,
            fileName: p.basename(filePath),
            packageName: packageName,
            contentBytes: await entity.readAsBytes(),
          );
          
          resources.add(asset);
        } catch (e) {
          failedFiles.add('$filePath: $e');
          onWarning('Could not read resource file $filePath: $e', false);
        }
      }
    } catch (e) {
      onError('Error scanning directory ${dir.path}: $e', true);
    }
    
    // Log summary
    if (failedFiles.isNotEmpty) {
      onWarning('Failed to read ${failedFiles.length} file(s) in ${dir.path}', true);
      for (final failure in failedFiles.take(3)) {
        onInfo('  - $failure', false);
      }
    }
    
    return resources;
  }

  /// Determines whether a package with the given [packageName]
  /// should be scanned for assets and resources.
  ///
  /// The decision is driven by user configuration:
  /// - A package is **excluded** if it appears in
  ///   `configuration.packagesToExclude`
  /// - A package is **included** if:
  ///   - `packagesToScan` is empty (scan all by default), or
  ///   - it explicitly appears in `packagesToScan`
  ///
  /// A package is scanned only if it is included **and not excluded**.
  ///
  /// ### Returns
  /// `true` if the package should be scanned, otherwise `false`.
  bool _shouldScanPackage(String packageName) {
    final bool excludePackage = configuration.packagesToExclude.contains(packageName);
    final bool includePackage = configuration.packagesToScan.isEmpty || configuration.packagesToScan.contains(packageName);
    return includePackage && !excludePackage;
  }

  /// Scans loaded Dart libraries (via `dart:mirrors`) for classes that define
  /// **generative assets** — i.e., classes that extend [GenerativeAsset] and
  /// expose a zero-argument constructor.
  ///
  /// This reflective scan supplements file-based resource discovery by allowing
  /// assets to be defined programmatically. Any class that:
  ///
  /// 1. Extends or implements [GenerativeAsset] (directly or indirectly),
  /// 2. Has a callable zero-argument constructor,
  ///
  /// will be instantiated and collected.
  ///
  /// **How discovery works:**
  /// - Iterate over all libraries in the provided [mirrorSystem] or a filtered
  ///   list of [libraries].
  /// - Inspect each class declaration.
  /// - Determine whether the class is a subtype of [GenerativeAsset] using
  ///   [isSubclassOf].
  /// - Look for a zero-argument constructor via `_findZeroArgsConstructorSymbol`
  ///   (defined elsewhere in this class).
  /// - Attempt instantiation via `ClassMirror.newInstance`.
  ///
  /// If instantiation succeeds and the reflected instance is a
  /// [GenerativeAsset], it is added to the returned list.
  ///
  /// **Fault tolerance:**
  /// - Constructor invocation errors are silently ignored to prevent a single
  ///   broken class from interrupting the entire discovery pipeline.
  ///
  /// **Parameters:**
  /// - [mirrorSystem]: The active reflective view of the Dart program.
  /// - [libraries]: Optional subset of libraries to restrict the scan.
  ///
  /// **Returns:**
  /// A list of instantiated generative assets discovered through reflection.
  Future<List<GenerativeAsset>> _scanMirrorForGenerativeAssets(mirrors.MirrorSystem mirrorSystem, List<mirrors.LibraryMirror>? libraries) async {
    final assets = <GenerativeAsset>[];
    final gaClass = mirrors.reflectClass(GenerativeAsset);

    for (final lib in libraries ?? mirrorSystem.libraries.values) {
      for (final decl in lib.declarations.values) {
        // We only care about classes
        if (decl is! mirrors.ClassMirror) continue;

        final classMirror = decl;

        // Must be a subclass of GenerativeAsset
        if (!isSubclassOf(classMirror, gaClass)) {
          continue;
        }

        // Must have zero-arg constructor symbol
        final symbol = findZeroArgsConstructorSymbol(classMirror);
        if (symbol == null) {
          continue;
        }

        // Try to instantiate
        try {
          final instanceMirror = classMirror.newInstance(symbol, const []);
          final instance = instanceMirror.reflectee;

          if (instance is GenerativeAsset) {
            assets.add(instance);
          }
        } catch (_) {}
      }
    }

    return assets;
  }

  /// Determines whether [classMirror] is the same type as [target] or a
  /// transitive subtype of it.
  ///
  /// The check is performed using a recursive traversal of:
  ///
  /// 1. The class itself  
  /// 2. All implemented interfaces  
  /// 3. The superclass chain  
  ///
  /// This ensures accurate subtype detection even for deep or mixed inheritance
  /// hierarchies, including classes that implement [GenerativeAsset] through
  /// multiple interfaces rather than direct extension.
  ///
  /// **Parameters:**
  /// - [classMirror]: The class being examined.
  /// - [target]: The type to compare against.
  ///
  /// **Returns:**
  /// `true` if [classMirror] is the same as or a subtype of [target],
  /// otherwise `false`.
  @protected
  bool isSubclassOf(mirrors.ClassMirror classMirror, mirrors.ClassMirror target) {
    // 1. Check the class itself
    if (classMirror == target) return true;

    // 2. Check all interfaces implemented by this class
    for (final interface in classMirror.superinterfaces) {
      if (interface == target) return true;
      if (isSubclassOf(interface, target)) return true;
    }

    // 3. Recurse into superclass (if exists)
    final superClass = classMirror.superclass;
    if (superClass == null) return false;

    return isSubclassOf(superClass, target);
  }

  /// Attempts to locate a **zero-argument constructor** for the given class.
  ///
  /// A class is considered eligible for reflective instantiation only if it
  /// exposes a constructor whose parameter list is empty. This method scans
  /// all declarations of the provided [mirror] and checks:
  ///
  /// - The declaration is a [mirrors.MethodMirror]
  /// - It represents a constructor (`isConstructor == true`)
  /// - It defines **no parameters**
  ///
  /// When such a constructor is found, this method returns the canonical
  /// invocation symbol `Symbol('')`, which corresponds to the unnamed
  /// (default) constructor in Dart’s reflective invocation model.
  ///
  /// ### Why return `Symbol("")`?
  /// Dart’s reflection system treats all unnamed constructors—no matter
  /// how they appear in source—as `Symbol('')`.  
  /// This aligns with how `ClassMirror.newInstance` expects the constructor
  /// symbol for default constructors.
  ///
  /// ### Parameters:
  /// - [mirror]: The class mirror to inspect for a zero-argument constructor.
  ///
  /// ### Returns:
  /// - The constructor symbol (`Symbol('')`) if such a constructor exists.
  /// - `null` if the class does not define any zero-argument constructor.
  @protected
  Symbol? findZeroArgsConstructorSymbol(mirrors.ClassMirror mirror) {
    for (final entry in mirror.declarations.entries) {
      final decl = entry.value;

      if (decl is mirrors.MethodMirror && decl.isConstructor && decl.parameters.isEmpty) {
        return Symbol(""); // constructor symbol
      }
    }

    return null;
  }
}