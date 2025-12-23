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

import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../../classes.dart';
import '../../helpers/qualified_name.dart';
import '../declaration/declaration.dart';
import '../../exceptions.dart';
import '../../helpers/equals_and_hash_code.dart';
import '../../utils/constant.dart';
import '../../utils/generic_type_parser.dart';
import '../../utils/reflection_utils.dart';
import '../../utils/utils.dart';
import '../executor/runtime_executor.dart';
import 'abstract_class_declaration_support.dart';

part '_material_library.dart';
part '_internal_runtime_helpers.dart';
part '_material_runtime_provider.dart';
part '_source_library.dart';

/// {@template source_library}
/// A **first-class representation of a Dart library’s source code** within
/// the JetLeaf framework. [SourceLibrary] is the **canonical source-level library abstraction** in
/// JetLeaf. It bridges file systems, packages, analyzers, and generators while
/// remaining lightweight, stable, and environment-agnostic.
///
/// Every declaration, element, and metadata tree in JetLeaf ultimately traces
/// back to a [SourceLibrary].
///
/// ---
///
/// #### What This Class Represents
///
/// [SourceLibrary] models a **single Dart library unit** as it exists in source
/// form. Unlike analyzer `LibraryElement`s or mirror-based representations,
/// this abstraction focuses on the **physical and textual identity** of a
/// library:
///
/// - Where the library came from (package or file URI)
/// - What source code it contains
/// - Which package owns it
/// - How it should be uniquely identified and compared
///
/// It acts as the **root object** for all source-driven reflection,
/// analysis, and generation performed by JetLeaf.
///
/// ---
///
/// #### Role in the JetLeaf Architecture
///
/// [SourceLibrary] sits at the **boundary layer** between:
///
/// - Low-level source loading (files, packages, in-memory assets)
/// - Analyzer AST and element resolution
/// - High-level declaration and metadata generation
///
/// Typical flow:
///
/// ```text
/// Package
///   └── SourceLibrary
///         ├── sourceCode()
///         ├── getUri()
///         └── getSourceLocation()
///                 ↓
///          Analyzer / AST / Declarations
/// ```
///
/// This allows JetLeaf to:
/// - Parse documentation comments directly from source
/// - Re-run analysis without reloading files
/// - Share a single library instance across multiple generators
///
/// ---
///
/// #### Immutability & Safety
///
/// Implementations of [SourceLibrary] are expected to be:
///
/// - **Immutable** after creation
/// - **Thread-safe** for concurrent generator use
/// - **Side-effect free**
///
/// Once created, a [SourceLibrary] should represent a frozen snapshot of the
/// library’s source state.
/// 
/// Example:
/// ```dart
/// final lib = user.getSourceLibrary();
/// print(lib.getUri()); // 'package:my_app/main.dart'
/// print(lib.getPackage().getName()); // 'my_app'
/// ```
/// {@endtemplate}
abstract final class SourceLibrary with EqualsAndHashCode {
  /// Returns the **physical or logical source location** where this library
  /// originates.
  ///
  /// This is typically:
  /// - A `file://` URI for local sources, or
  /// - A `package:` URI for package-resolved libraries.
  ///
  /// Implementations may return `null` when source location data is unavailable
  /// (e.g., generated libraries or runtime-only assets).
  ///
  /// ### Notes
  /// - This value is primarily intended for diagnostics and tooling.
  /// - It should not be used as a stable identifier.
  Uri getSourceLocation();

  /// Returns a **stable debug identifier** for this library.
  ///
  /// This identifier:
  /// - Must uniquely identify the library within the current reflection scope.
  /// - Is used as the basis for equality and hash code computation.
  /// - Should remain stable across generator runs for the same library.
  ///
  /// Typical implementations use the canonical library URI or a normalized
  /// package path.
  String getDebugIdentifier();

  /// Returns the **canonical URI string** of this library.
  ///
  /// The URI represents how the Dart runtime or analyzer would reference the
  /// library, such as:
  /// - `package:my_app/main.dart`
  /// - `file:///absolute/path/to/file.dart`
  ///
  /// ### Example
  /// ```dart
  /// final uri = myLibrary.getUri();
  /// print(uri); // "package:my_app/main.dart"
  /// ```
  ///
  /// This value is commonly used for:
  /// - Analyzer lookups,
  /// - Import generation,
  /// - Cross-library resolution.
  String getUri();

  /// Returns the **raw Dart source code** of this library.
  ///
  /// The returned string should contain the complete contents of the source
  /// file, exactly as it exists on disk or in memory.
  ///
  /// ### Use Cases
  /// - Parsing documentation comments.
  /// - Feeding analyzer or AST parsers.
  /// - Performing source-level inspection or transformation.
  String sourceCode();

  /// Returns the [Package] that owns and contains this library.
  ///
  /// This enables:
  /// - Resolving relative imports,
  /// - Accessing package-level configuration,
  /// - Associating the library with dependency metadata.
  ///
  /// ### Example
  /// ```dart
  /// final pkg = myLibrary.getPackage();
  /// print(pkg.getName()); // "my_app"
  /// ```
  Package getPackage();

  /// Indicates whether this library is part of the **Dart SDK**.
  /// [isSdkLibrary] acts as a **classification signal** that allows JetLeaf to
  /// distinguish between platform-provided libraries and user-controlled
  /// source code, ensuring correct behavior across analysis, reflection,
  /// and generation phases.
  ///
  /// ---
  ///
  /// #### What This Means
  ///
  /// Returns `true` when this [SourceLibrary] represents a library that is
  /// **shipped with the Dart SDK itself**, such as:
  ///
  /// - `dart:core`
  /// - `dart:async`
  /// - `dart:collection`
  /// - `dart:io`
  /// - `dart:convert`
  ///
  /// and returns `false` for:
  /// - Application libraries
  /// - Third-party package libraries
  /// - Generated or workspace-local sources
  bool isSdkLibrary();

  /// Returns the **logical name** of this source library.
  ///
  /// The library name is a **human-readable identifier** derived from the
  /// library’s canonical URI or declaration context. Unlike [getUri] or
  /// [getDebugIdentifier], this value is intended primarily for:
  ///
  /// - Diagnostics and logging
  /// - Error and warning messages
  /// - Developer-facing tooling and reports
  ///
  /// ---
  ///
  /// #### What This Represents
  ///
  /// The returned name is typically:
  ///
  /// - The library’s Dart `library` name (if explicitly declared), or
  /// - A normalized name inferred from the library URI (e.g. file or package path)
  ///
  /// It is **not required to be globally unique** and **must not** be used
  /// for identity comparison or hashing.
  ///
  /// ---
  ///
  /// #### Relationship to Other Identifiers
  ///
  /// | Method               | Purpose                          | Stable |
  /// |----------------------|----------------------------------|--------|
  /// | [getName]            | Display / diagnostics            | ❌     |
  /// | [getUri]             | Canonical reference              | ✅     |
  /// | [getDebugIdentifier] | Equality & hashing               | ✅     |
  ///
  /// ---
  ///
  /// #### Example
  ///
  /// ```dart
  /// final library = runtime.getSourceLibrary('package:my_app/main.dart')!;
  /// print(library.getName()); // 'main' or 'my_app.main'
  /// ```
  ///
  /// Use this method when you need a **clear, readable name** for a library,
  /// not when performing lookups or comparisons.
  String getName();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is SourceLibrary && getDebugIdentifier() == other.getDebugIdentifier();
  }

  @override
  int get hashCode => getDebugIdentifier().hashCode;
}

/// Represents a **class whose type could not be fully resolved** at runtime.
///
/// The `UnresolvedClass` abstraction is used to track classes that the
/// reflection or analysis system recognizes but cannot fully determine
/// type parameters, generics, or runtime metadata for.
///
/// This is especially useful in scenarios involving:
/// - Generic classes with complex type constraints
/// - Dynamically loaded code
/// - Classes from packages that are partially unavailable
///
/// The class provides minimal identifying information:
/// - [getName]: The simple class name (without package or library prefix)
/// - [getQualifiedName]: The fully qualified class name, including package and library.
/// 
/// Example:
/// ```dart
/// final unresolved = Runtime.getUnresolvedClasses().first;
/// print(unresolved.getName()); // "MyClass"
/// print(unresolved.getQualifiedName()); // "my_package.lib.MyClass"
/// ```
abstract final class UnresolvedClass with EqualsAndHashCode implements QualifiedName {
  /// Returns the **simple name** of the unresolved class.
  ///
  /// Example:
  /// ```dart
  /// final name = unresolvedClass.getName(); // 'MyGenericClass'
  /// ```
  String getName();
}

/// A **lightweight class reference** containing minimal structural information
/// about a Dart class.
///
/// `ClassReference` exists to provide just enough metadata to:
/// - Identify a class uniquely via its qualified name
/// - Describe its raw Dart [Type]
/// - Establish superclass and interface relationships
///
/// This minimal representation is intentionally designed for **fast graph
/// traversal**, particularly when resolving **subclass and interface
/// relationships** without materializing full [ClassDeclaration] objects.
///
/// ---
///
/// ## Purpose
///
/// `ClassReference` is primarily used during:
/// - Subclass discovery
/// - Type hierarchy traversal
/// - Dependency and inheritance graph analysis
///
/// By avoiding full declaration loading, it enables **O(1) lookups**
/// and minimizes memory overhead in large reflection graphs.
///
/// ---
///
/// ## Design Notes
///
/// - Implements [QualifiedName] to guarantee a stable, unique identifier
/// - Exposes the raw Dart [Type] for fast runtime comparisons
/// - Stores only **structural relationships** (superclass and interfaces)
/// - Intentionally omits members, annotations, generics, and metadata
///
/// This makes `ClassReference` ideal for **internal indexing, caching, and
/// hierarchy resolution**, rather than full introspection.
///
/// ---
///
/// ## Example
///
/// ```dart
/// final ref = runtime.getClassReference(MyService);
///
/// print(ref.getQualifiedName()); // dart:core.MyService
/// print(ref.getType() == MyService); // true
///
/// final superClass = ref.getSuperClass();
/// final interfaces = ref.getInterfaces();
/// ```
///
/// ---
///
/// ## See Also
/// - [ClassDeclaration] for full structural metadata
/// - [Class] for runtime reflection and instantiation
/// - [LinkDeclaration] for build-time type references
abstract final class ClassReference with EqualsAndHashCode implements QualifiedName {
  /// Returns the raw Dart [Type] represented by this class reference.
  ///
  /// This is primarily used for:
  /// - Fast identity comparison
  /// - Pointer-level resolution
  /// - Fallback matching during hierarchy traversal
  Type getType();

  /// Returns the direct superclass of this class, if any.
  ///
  /// - Returns `null` if this class has no explicit superclass
  ///   (for example, `Object` or root types).
  /// - The returned value is a [ClassReference], not a full declaration,
  ///   allowing lightweight traversal of the inheritance tree.
  ClassReference? getSuperClass();

  /// Returns the list of interfaces implemented by this class.
  ///
  /// This includes:
  /// - Explicit `implements` interfaces
  /// - Mixin-applied interfaces, where applicable
  ///
  /// The returned references are lightweight and suitable for
  /// hierarchy analysis and interface matching.
  List<ClassReference> getInterfaces();
}

/// {@template material_library}
/// A **centralized, immutable registry of materialized Dart libraries**
/// within the JetLeaf reflection and generation system. This is the **backbone registry** of JetLeaf’s reflection
/// system. It materializes raw libraries into a frozen, queryable structure
/// that enables fast, deterministic, and cross-domain type resolution.
///
/// Every class lookup, declaration discovery, and object-to-source mapping
/// ultimately flows through this abstraction.
///
/// ---
///
/// #### What This Class Represents
///
/// [MaterialLibrary] acts as the **authoritative aggregation point** for all
/// Dart libraries that have been *materialized* into JetLeaf’s internal model.
/// It follows a **strict lifecycle**:
///
/// ```text
/// create
///   └── addLibrary(...)   ← internal population phase
///           ↓
///       freezeLibrary()   ← registry becomes immutable
///           ↓
///        query APIs       ← safe, deterministic access
///           ↓
///         cleanup()       ← resource release
/// ```
///
/// After freezing:
/// - No new libraries may be added
/// - Identity and lookup results are stable
/// - Thread-safe read access is guaranteed
///
/// This design ensures predictable behavior during generation and reflection.
///
/// ---
///
/// #### Role in the JetLeaf Architecture
///
/// [MaterialLibrary] sits **above** low-level abstractions such as
/// [SourceLibrary] and mirrors, and **below** high-level declaration models:
///
/// ```text
/// Packages / Files / SDK
///        ↓
///   SourceLibrary
///        ↓
///   MaterialLibrary   ← aggregation & identity boundary
///        ↓
///   ClassDeclaration / Metadata / Generators
/// ```
///
/// It is the **primary entry point** for:
/// - Locating class declarations
/// - Resolving types across packages
/// - Bridging runtime objects to source-level declarations
///
/// Application and package authors should interact with *declarations* and
/// *metadata outputs*, not the registry itself.
/// {@endtemplate}
abstract final class MaterialLibrary with EqualsAndHashCode {
  /// {@macro material_library}
  const MaterialLibrary._();

  /// Cleans up internal caches, temporary data, and metadata stored
  /// during runtime reflection.
  ///
  /// Use this when the library's runtime scanning or reflection data
  /// is no longer needed. This helps free memory and prevent stale
  /// references.
  ///
  /// Example:
  /// ```dart
  /// final library = myMaterialLibrary;
  /// // After using the library for runtime introspection:
  /// library.cleanup();
  /// ```
  void cleanup();

  /// Enables periodic automatic cleanup of the library's internal caches,
  /// temporary data, and reflection metadata.
  ///
  /// This method sets up a background or scheduled mechanism to regularly
  /// free memory and remove stale references from the material library.
  /// It is useful in long-running applications or servers where runtime
  /// scanning and reflection occur frequently, helping prevent memory
  /// leaks and ensuring that metadata stays up-to-date.
  ///
  /// ⚠️ The exact interval and mechanism depend on the implementation
  /// of the concrete MaterialLibrary class.
  ///
  /// The optional [interval] parameter defines how often the cleanup
  /// should be executed. By default, it runs every 5 minutes.
  ///
  /// Example:
  /// ```dart
  /// final library = myMaterialLibrary;
  /// // Enable automatic periodic cleanup every 10 minutes
  /// library.enablePeriodicCleanup(interval: Duration(minutes: 10));
  /// ``` 
  void enablePeriodicCleanup({Duration interval = const Duration(minutes: 5)});

  /// Configures the **maximum number of entries** allowed in the internal
  /// reflection and declaration caches.
  ///
  /// JetLeaf uses bounded in-memory caches to store:
  /// - Materialized class declarations
  /// - Source libraries
  /// - Runtime-to-source resolution results
  ///
  /// This method defines the **upper limit** for those caches, enabling
  /// predictable memory usage and controlled eviction behavior.
  ///
  /// ---
  ///
  /// #### When to Use This
  ///
  /// - Large applications with many scanned libraries or classes
  /// - Long-running servers where reflection metadata grows over time
  /// - Memory-constrained environments
  ///
  /// ---
  ///
  /// #### Example
  ///
  /// ```dart
  /// final library = myMaterialLibrary;
  ///
  /// // Increase cache capacity for large projects
  /// library.provideMaxCacheSize(500);
  /// ```
  ///
  /// ⚠️ **Note**: Setting this value too high may increase memory usage,
  /// while setting it too low may cause frequent re-materialization and
  /// performance degradation.
  void provideMaxCacheSize(int cacheSize);

  /// Returns a [SourceLibrary] corresponding to the given [identifier].
  ///
  /// The [identifier] can be either:
  /// - A package name (e.g., `'my_package'`)
  /// - A library URI (e.g., `'package:my_package/src/foo.dart'` or `'dart:core'`)
  ///
  /// If no library matches the identifier, this method returns `null`.
  ///
  /// Example:
  /// ```dart
  /// final lib = library.getSourceLibrary('my_package');
  /// final sdkLib = library.getSourceLibrary('dart:core');
  /// print(lib?.getUri()); // 'package:my_package/my_package.dart'
  /// print(sdkLib?.getUri()); // 'dart:core'
  /// ```
  SourceLibrary? getSourceLibrary(String identifier);

  /// Returns all [SourceLibrary] instances currently loaded in this material library.
  ///
  /// This includes both:
  /// - SDK libraries (e.g., `dart:core`, `dart:async`)
  /// - Application or package libraries scanned during runtime reflection
  ///
  /// Example:
  /// ```dart
  /// for (final lib in library.getSourceLibraries()) {
  ///   print(lib.getUri());
  /// }
  /// ```
  List<SourceLibrary> getSourceLibraries();

  /// Finds a class of type [T] in the scanned libraries, optionally restricted
  /// to a specific [package].
  ///
  /// This method performs a generic lookup for a class of the specified
  /// type [T] and returns its corresponding [ClassDeclaration], which
  /// contains metadata such as name, package, and library context.
  ///
  /// If [package] is provided, the search is limited to that package only.
  ///
  /// Example:
  /// ```dart
  /// final myClass = library.findClass<MyWidget>('my_package');
  /// print(myClass.getName()); // 'MyWidget'
  /// ```
  ClassDeclaration findClass<T>([String? package]);

  /// Finds a class declaration corresponding to a runtime [type], optionally
  /// restricted to a specific [package].
  ///
  /// This method is useful when you have a Type object at runtime and
  /// need to retrieve the associated [ClassDeclaration] for reflection
  /// or metadata inspection.
  ///
  /// Example:
  /// ```dart
  /// final clazz = library.findClassByType(MyWidget);
  /// print(clazz.getQualifiedName()); // 'package:my_package/my_widget.dart.MyWidget'
  /// ```
  ClassDeclaration findClassByType(Type type, [String? package]);

  /// Finds a class declaration by its simple [name], optionally restricted
  /// to a specific [package].
  ///
  /// This method searches the scanned libraries for a class matching
  /// the provided simple name. If [package] is specified, the search
  /// is limited to that package only.
  ///
  /// Example:
  /// ```dart
  /// final userClass = library.findClassByName('User');
  /// print(userClass.getPackage().getName()); // e.g., 'my_package'
  /// ```
  /// 
  /// **NOTE:** The use of [findClassByName] is presented as a last-effort to finding a class.
  /// This method should not be used as a priority. It is recommended that you use other methods
  /// like: [findClass], [findClassByType] and [obtainClassDeclaration]
  ClassDeclaration findClassByName(String name, [String? package]);

  /// Finds a class declaration by its fully qualified name [qualifiedName].
  ///
  /// The qualified name includes package and library context, allowing
  /// precise lookup even if multiple classes share the same simple name.
  ///
  /// Example:
  /// ```dart
  /// final clazz = library.findClassByQualifiedName('package:example/example.dart.User');
  /// print(clazz.getName()); // 'User'
  /// ```
  ClassDeclaration findClassByQualifiedName(String qualifiedName);

  /// Obtains a [ClassDeclaration] corresponding to a runtime [object],
  /// optionally restricted to a specific [package].
  ///
  /// This is useful for reflection or runtime inspection when you have
  /// an instance of a class and want to retrieve its metadata.
  ///
  /// Example:
  /// ```dart
  /// final instance = User();
  /// final clazz = library.obtainClassDeclaration(instance);
  /// print(clazz.getQualifiedName()); // e.g., 'package:my_package/user.dart.User'
  /// ```
  ClassDeclaration obtainClassDeclaration(Object object, [String? package]);

  /// Returns all classes that could not be fully resolved or identified
  /// during runtime analysis or reflection.
  ///
  /// These classes may be:
  /// - Dynamically generated at runtime
  /// - Missing metadata due to partial compilation
  /// - Excluded by configuration or package filters
  ///
  /// This allows runtime tools, analyzers, and diagnostics to reference
  /// unresolved classes safely without throwing exceptions.
  ///
  /// Example:
  /// ```dart
  /// for (final unresolved in library.getUnresolvedClasses()) {
  ///   print(unresolved.getQualifiedName());
  /// }
  /// ```
  Iterable<UnresolvedClass> getUnresolvedClasses();

  /// Returns unresolved classes that specifically belong to [packageName].
  ///
  /// This is useful to isolate classes that failed resolution
  /// within a particular package scope.
  ///
  /// Example:
  /// ```dart
  /// final unresolvedInPackage = library.getPackageUnresolvedClasses('my_package');
  /// for (final clazz in unresolvedInPackage) {
  ///   print(clazz.getName());
  /// }
  /// ```
  Iterable<UnresolvedClass> getPackageUnresolvedClasses(String packageName);

  /// Returns all methods across all loaded classes, including those in
  /// SDK libraries, packages, and application code.
  ///
  /// ⚠️ This is an **expensive and blocking operation** because it
  /// traverses all loaded classes and collects their methods.
  /// Use only when necessary, e.g., for diagnostics or full reflection.
  ///
  /// Example:
  /// ```dart
  /// for (final method in library.getAllMethods()) {
  ///   print(method.name);
  /// }
  /// ```
  Iterable<MethodDeclaration> getAllMethods();

  /// Returns all methods across all loaded classes that have any jetleaf package as a dependency.
  ///
  /// ⚠️ This is an **expensive and blocking operation** because it
  /// traverses all loaded classes and collects their methods.
  /// Use only when necessary, e.g., for diagnostics or full reflection.
  ///
  /// Example:
  /// ```dart
  /// for (final method in library.getAllJetleafDependentMethods()) {
  ///   print(method.name);
  /// }
  /// ```
  Iterable<MethodDeclaration> getAllJetleafDependentMethods();

  /// Collects all methods annotated with a specific annotation type [T] across
  /// the materialized classes.
  ///
  /// If [onlyJetleafPackages] is true, only classes whose package includes
  /// any JetLeaf packages are checked. This allows filtering to JetLeaf-related
  /// classes, avoiding unnecessary scanning of unrelated classes.
  ///
  /// ⚠️ This operation may be expensive if many classes are loaded,
  /// as it inspects all methods for the annotation type.
  ///
  /// ## Parameters
  /// - `onlyJetleafPackages`: When `true` (default), restricts the search to
  ///   classes in packages that include JetLeaf dependencies.
  ///
  /// ## Returns
  /// - An [Iterable] of [MethodDeclaration] instances that have the specified
  ///   annotation type [T].
  ///
  /// ## Example
  /// ```dart
  /// final annotatedMethods = library.collectAnnotatedMethods<MyAnnotation>();
  /// for (final method in annotatedMethods) {
  ///   print(method.getName());
  /// }
  /// ```
  Iterable<MethodDeclaration> collectAnnotatedMethods<T>([bool onlyJetleafPackages = true]);

  /// Returns all subclasses of the given [classDeclaration].
  ///
  /// This method searches the materialized type graph and finds every class
  /// that directly or indirectly extends the specified class.
  ///
  /// ⚠️ Expensive for large libraries since it traverses all loaded classes.
  ///
  /// ## Parameters
  /// - `classDeclaration`: The class whose subclasses should be retrieved.
  ///
  /// ## Returns
  /// - An [Iterable] of [ClassDeclaration] objects representing all subclasses.
  ///
  /// ## Example
  /// ```dart
  /// final subclasses = library.getSubClasses(baseClassDeclaration);
  /// for (final subclass in subclasses) {
  ///   print(subclass.getQualifiedName());
  /// }
  /// ```
  Iterable<ClassDeclaration> getSubClasses(ClassDeclaration classDeclaration);

  /// Returns all subclass references of a class identified by its fully qualified name.
  ///
  /// This method is similar to [getSubClasses] but returns lightweight
  /// [ClassReference] objects instead of full [ClassDeclaration]s. Useful
  /// for **fast hierarchy traversal** and internal graph operations.
  ///
  /// ⚠️ The [qualifiedName] must include package and library context for
  /// accurate lookup.
  ///
  /// ## Parameters
  /// - `qualifiedName`: The fully qualified name of the parent class.
  ///
  /// ## Returns
  /// - An [Iterable] of [ClassReference] representing all subclasses.
  ///
  /// ## Example
  /// ```dart
  /// final subclassRefs = library.getSubClassReferences('package:example/foo.dart.BaseClass');
  /// for (final subclassRef in subclassRefs) {
  ///   print(subclassRef.getQualifiedName());
  /// }
  /// ```
  Iterable<ClassReference> getSubClassReferences(String qualifiedName);

  /// Returns all class declarations in the specified [packageName].
  ///
  /// ⚠️ Expensive and blocking. Use only when necessary, as it
  /// enumerates all classes in the given package across all libraries.
  ///
  /// Example:
  /// ```dart
  /// for (final clazz in library.getAllClassesInAPackage('my_package')) {
  ///   print(clazz.getName());
  /// }
  /// ```
  Iterable<ClassDeclaration> getAllClassesInAPackage(String packageName);

  /// Returns all class declarations in the entire application.
  ///
  /// ⚠️ Expensive and blocking. Use only when necessary, as it
  /// enumerates all classes across all libraries.
  ///
  /// Example:
  /// ```dart
  /// for (final clazz in library.getAllClasses()) {
  ///   print(clazz.getName());
  /// }
  /// ```
  Iterable<ClassDeclaration> getAllClasses();

  /// Returns all class declarations contained in the library identified
  /// by [packageUri], typically a package or library URI.
  ///
  /// ⚠️ Expensive and blocking. Use only when necessary, since it
  /// inspects all classes in the given library URI.
  ///
  /// Example:
  /// ```dart
  /// for (final clazz in library.getAllClassesInAPackageUri('package:example/example.dart')) {
  ///   print(clazz.getQualifiedName());
  /// }
  /// ```
  Iterable<ClassDeclaration> getAllClassesInAPackageUri(String packageUri);
}

/// {@template runtime_provider}
/// A **runtime-backed extension** of [MaterialLibrary] that exposes
/// environment-level metadata and execution capabilities.
///
/// [RuntimeProvider] represents the **active reflection runtime context**.
/// While [MaterialLibrary] is responsible for *structural identity and lookup*,
/// this abstraction adds **runtime awareness**, enabling access to packaged
/// assets, resolved packages, and executable resolvers.
///
/// It is intentionally **non-instantiable by consumers** and is provided by
/// the JetLeaf runtime during initialization.
///
/// ---
///
/// #### Responsibilities
///
/// A [RuntimeProvider] augments the materialized library registry with:
///
/// - Asset discovery and enumeration
/// - Package-level metadata access
/// - Runtime execution and descriptor resolution
///
/// This separation ensures that:
/// - Structural reflection remains deterministic and immutable
/// - Runtime concerns are isolated and explicitly accessed
///
/// ---
///
/// #### Relationship to [MaterialLibrary]
///
/// [RuntimeProvider] **implements** [MaterialLibrary], inheriting all lookup
/// and declaration-resolution APIs, and extends them with runtime-specific
/// capabilities.
///
/// ```text
/// MaterialLibrary   ← structural identity & lookup
///        ↑
///   RuntimeProvider ← runtime metadata & execution
/// ```
///
/// Consumers should depend on this interface when both **reflection data**
/// and **runtime execution** are required.
/// {@endtemplate}
abstract final class RuntimeProvider implements MaterialLibrary {
  /// {@macro runtime_provider}
  const RuntimeProvider._();

  /// Returns all assets available in the current reflection runtime.
  ///
  /// Assets typically represent non-code resources bundled with the
  /// application, such as images, configuration files, or other packaged data.
  ///
  /// The returned collection is:
  /// - **Immutable**
  /// - **Deterministically ordered**
  /// - Scoped to the active runtime context
  ///
  /// Returns a list of [Asset] metadata descriptors.
  List<Asset> getAllAssets();

  /// Returns all Dart packages available in the current reflection runtime.
  ///
  /// This includes every package that has been processed and materialized by
  /// JetLeaf, along with their associated libraries and dependency metadata.
  ///
  /// The returned collection is:
  /// - **Immutable**
  /// - **Deterministically ordered**
  /// - Fully resolved at runtime initialization
  ///
  /// Returns a list of [Package] metadata descriptors.
  List<Package> getAllPackages();

  /// Returns the **currently active package** in the runtime context.
  ///
  /// The "current package" is typically determined by the last scanned or
  /// focused package during runtime initialization or during execution
  /// of package-scoped operations.
  ///
  /// This is useful when a default package context is needed for:
  /// - Resolving relative imports
  /// - Looking up libraries without explicitly specifying a package
  /// - Determining runtime execution scope for descriptors or assets
  ///
  /// Returns `null` if no current package has been set or initialized.
  ///
  /// ### Example
  /// ```dart
  /// final currentPkg = Runtime.getCurrentPackage();
  /// print(currentPkg?.getName()); // e.g., 'my_app'
  /// ```
  Package? getCurrentPackage();

  /// Returns a [Package] by its **name** within the runtime context.
  ///
  /// This method searches all packages that have been materialized and
  /// loaded into the runtime. It allows precise access to package-level
  /// metadata, including:
  /// - Contained libraries
  /// - Dependency information
  /// - Package URI and path resolution
  ///
  /// Returns `null` if the specified package is not found in the current
  /// runtime context.
  ///
  /// ### Example
  /// ```dart
  /// final pkg = Runtime.getPackage('my_package');
  /// print(pkg?.getName()); // 'my_package'
  /// print(pkg?.getLibraries()); // List of SourceLibrary instances
  /// ```
  Package? getPackage(String packageName);

  /// Returns the **runtime executor** responsible for resolving and executing
  /// descriptor-backed entities within the active reflection context.
  ///
  /// The returned [RuntimeExecutor] acts as the **execution bridge** between
  /// JetLeaf’s materialized declaration model and the live Dart runtime.
  /// It is responsible for:
  ///
  /// - Resolving runtime representations of classes, methods, and fields
  /// - Executing reflected constructors and invocations
  /// - Translating descriptor-level abstractions into concrete runtime behavior
  ///
  /// This executor is tightly coupled to the current [RuntimeProvider] instance
  /// and reflects the exact state of the runtime at the moment the reflection
  /// system was initialized.
  ///
  /// Consumers should treat the returned executor as:
  /// - **Context-bound** (not transferable across runtimes)
  /// - **Read-only in configuration**
  /// - **Authoritative** for runtime execution semantics
  ///
  /// Returns a fully-initialized [RuntimeExecutor].
  RuntimeExecutor getRuntimeResolver();
}

/// 🔹 Extension: `UnresolvedClassExtension`
///
/// Provides utility methods for iterables of [UnresolvedClass] instances,
/// allowing runtime diagnostics and convenient reporting of classes
/// whose types could not be fully resolved.
///
/// This extension is particularly useful in scenarios involving:
/// - Generic classes with complex type constraints
/// - Dynamically loaded code
/// - Partially unavailable packages or runtime metadata
///
/// It enables developers to quickly generate warning messages for
/// unresolved classes during runtime inspection or reflection.
extension UnresolvedClassExtension on Iterable<UnresolvedClass> {
  /// Generates a **human-readable warning message** for all unresolved classes
  /// in this iterable.
  ///
  /// If the iterable contains one or more [UnresolvedClass] instances, the
  /// returned string includes:
  /// - A warning header
  /// - A numbered or bulleted list of each unresolved class with:
  ///   - Its simple name (`getName()`)
  ///   - Its fully qualified name (`getQualifiedName()`)
  /// - Guidance on applying the `@Generic()` annotation to help JetLeaf
  ///   resolve types automatically.
  ///
  /// If the iterable is empty, an empty string is returned.
  ///
  /// ### Example
  /// ```dart
  /// final unresolvedClasses = Runtime.getUnresolvedClasses();
  /// print(unresolvedClasses.getWarningMessage());
  /// ```
  ///
  /// Example output when unresolved classes exist:
  /// ```
  /// ⚠️ Generic Class Discovery Issue ⚠️
  /// Found 2 classes with unresolved runtime types:
  ///   • MyGenericClass (my_package.lib.MyGenericClass)
  ///   • AnotherClass (another_package.lib.AnotherClass)
  ///
  /// These classes may need manual type resolution or have complex generic constraints.
  /// Use @Generic() annotation on these classes to avoid exceptions when invoking such classes
  /// ```
  String getWarningMessage([String? packageName]) {
    if (toList().isNotEmpty) {
      return '''
⚠️ Generic Class Discovery Issue (${packageName ?? Runtime.getCurrentPackage()?.getName()}) ⚠️
Found ${toList().length} classes with unresolved runtime types:
${toList().map((d) => "  • ${d.getName()} (${d.getQualifiedName()})").join("\n")}

These classes may need manual type resolution or have complex generic constraints.
Use @Generic() annotation on these classes to avoid exceptions when invoking such classes
''';
    }

    return "";
  }
}

/// 🔹 JetLeaf Runtime Singleton
///
/// The `Runtime` object is the **singleton instance of `RuntimeProvider`**
/// that represents the **active runtime reflection and execution context**
/// within the JetLeaf framework.
///
/// This singleton is the primary entry point for runtime-aware operations,
/// including:
/// - Accessing all materialized libraries (`MaterialLibrary`)
/// - Resolving Dart packages and their metadata
/// - Enumerating runtime assets (images, configuration files, templates)
/// - Executing reflected constructors, methods, and other runtime entities
///
/// ⚠️ This object is **internally initialized** and should **never be reassigned**
/// by application code. It is fully initialized at runtime startup via
/// `_InternalRuntime`.
///
/// ### Key Features
///
/// 1. **Materialized Library Access**
/// ```dart
/// final libraries = Runtime.getSourceLibraries();
/// for (final lib in libraries) {
///   print(lib.getUri());
/// }
/// ```
///
/// 2. **Runtime Package Access**
/// ```dart
/// final packages = Runtime.getAllPackages();
/// for (final pkg in packages) {
///   print(pkg.getName());
/// }
/// ```
///
/// 3. **Asset Access**
/// ```dart
/// final assets = Runtime.getAllAssets();
/// for (final asset in assets) {
///   print(asset.getFilePath());
/// }
/// ```
///
/// 4. **Runtime Execution**
/// ```dart
/// final executor = Runtime.getRuntimeResolver();
/// executor.invokeConstructor(SomeClass, []);
/// ```
///
/// ### Behavior
/// - Immutable after initialization: the registry of libraries, assets, and packages
///   is frozen for safe, thread-safe access.
/// - Deterministic: results are consistent across queries within the same runtime.
/// - Context-bound: the runtime executor reflects the state of the current runtime
///   instance and cannot be transferred across runtimes.
///
/// ### Usage Notes
/// - Use `Runtime` whenever **both reflection data and runtime execution** are required.
/// - Avoid direct modifications; use the JetLeaf API to add packages, assets,
///   or to perform runtime scans during the internal population phase.
/// - Designed for **internal framework usage**, though it is exposed for diagnostics,
///   generators, and reflection-aware applications.
final RuntimeProvider Runtime = _InternalRuntime;