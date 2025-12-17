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

import 'package:analyzer/dart/element/element.dart';
import 'package:meta/meta.dart';

import 'library_generator.dart';

/// {@template abstract_element_support}
/// An abstract base class that enhances [LibraryGenerator] with high-level
/// support for Dart analyzer *elements* (classes, enums, typedefs, mixins).
///
/// Whereas [LibraryGenerator] focuses on loading metadata through mirrors and
/// high-level library analysis, **AbstractElementSupport** adds the ability to
/// cache, resolve, and reuse static analyzer elements obtained from
/// `package:analyzer`.
///
/// This class does not perform resolution itself—subclasses are responsible for
/// populating these caches—but it provides the structure necessary for:
///
/// ### Why This Exists
/// - Avoiding expensive repeated analyzer lookups.
/// - Offering a unified element-layer to JetLeaf generators.
/// - Supporting mixed reflection (mirrors + analyzer) without duplicated work.
/// - Providing a bridge that allows declaration generators to use fully
///   resolved semantic information rather than only Mirror metadata.
///
/// ### Element Caches
/// Each cache maps a canonical or fully qualified Dart name to its corresponding
/// analyzer element:
///
/// | Cache Field | Element Type            | Description |
/// |-------------|-------------------------|-------------|
/// | `_classes`  | [ClassElement]          | Stores analyzer representations of all resolved classes. Useful for semantic type inspection, constructors, mixins, interfaces, generic parameters, etc. |
/// | `_enums`    | [EnumElement]           | Stores analyzer metadata for discovered enums, including values, documentation, and annotations. |
/// | `_typedefs` | [TypeAliasElement]      | Stores typedef / alias declarations, supporting generic typedef resolution and function alias discovery. |
/// | `_mixins`   | [MixinElement]          | Stores discovered mixins and their constrained type requirements. |
///
/// These caches enable rapid lookups when generating declarations, resolving
/// types, or building metadata trees across multiple libraries.
///
/// ### Typical Usage in Subclasses
/// Subclasses may:
/// - Populate caches when scanning resolved library elements.
/// - Query caches before calling analyzer APIs again.
/// - Use caches to resolve a type string → analyzer element.
/// - Build custom declaration objects from these element models.
///
/// This design ensures the JetLeaf build/runtime-generator pipeline remains
/// performant even as the complexity of type resolution increases.
/// {@endtemplate}
abstract class AbstractElementSupport extends LibraryGenerator {
  /// Internal cache of all resolved class declarations.
  ///
  /// Keys are fully qualified library URIs combined with the class name, such as:
  /// ```
  /// package:example/src/foo.dart:MyClass
  /// ```
  ///
  /// Values are the analyzer's semantic model objects describing each class.
  final Map<String, ClassElement> _classes = {};

  /// Internal cache of all resolved enum declarations.
  ///
  /// The key format mirrors that used for [_classes].
  ///
  /// This cache allows JetLeaf to quickly retrieve enum metadata such as
  /// value identifiers, annotations, documentation comments, and their
  /// underlying index values without repeated analyzer passes.
  final Map<String, EnumElement> _enums = {};

  /// Internal cache of all typedef (type alias) declarations.
  ///
  /// These include:
  /// - Function type aliases
  /// - Generic alias declarations
  /// - Aliases referencing classes or other typedefs
  ///
  /// Stored for quick lookup and expansion during type resolution.
  final Map<String, TypeAliasElement> _typedefs = {};

  /// Internal cache of all resolved mixin declarations.
  ///
  /// Useful for retrieving:
  /// - Required "on" type constraints
  /// - Methods and fields defined by mixins
  /// - Mixin constructors and annotations
  ///
  /// Often used when building full type graphs.
  final Map<String, MixinElement> _mixins = {};

  /// Creates the base element-support layer used by JetLeaf library and
  /// declaration generators.
  ///
  /// All parameters are forwarded directly to the [LibraryGenerator] constructor.
  /// 
  /// {@macro abstract_element_support}
  AbstractElementSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  /// Retrieves the resolved [LibraryElement] associated with the given [uri].
  ///
  /// This method must be implemented by subclasses and serves as the primary
  /// entry point for obtaining analyzer semantic models for Dart libraries.
  ///
  /// ### Responsibilities
  /// - Convert a `Uri` representing a Dart source file or package asset into an
  ///   analyzer [LibraryElement].
  /// - Provide cached results where possible to avoid repeated analyzer lookups.
  /// - Return `null` if the library cannot be resolved or if analyzer
  ///   initialization was not performed.
  ///
  /// This API is marked `@protected` because it is intended only for use inside
  /// JetLeaf's generator infrastructure.
  @protected
  Future<LibraryElement?> getLibraryElement(Uri uri);

  /// Retrieves the [ClassElement] corresponding to [className] within the
  /// library identified by [sourceUri].
  ///
  /// This method provides a cached, analyzer-based resolution mechanism for Dart
  /// class declarations. It ensures that repeated lookups for the same class do
  /// not require additional analyzer queries.
  ///
  /// ### Behavior
  /// - Computes a canonical key combining the library URI and class name.
  /// - Returns the cached [ClassElement] if it exists.
  /// - Otherwise resolves the library via [getLibraryElement] and looks up the
  ///   class using `libraryElement.getClass(className)`.
  /// - Stores resolved elements into the internal cache for future use.
  ///
  /// ### Parameters
  /// - `className`: The simple name of the class (e.g., `"MyService"`).
  /// - `sourceUri`: The URI of the library where the class is expected to be
  ///   declared.
  ///
  /// ### Returns
  /// - The resolved [ClassElement], or `null` if not found.
  ///
  /// ### Notes
  /// Resolution depends on analyzer semantic models, so it requires the
  /// analysis context to be initialized beforehand.
  @protected
  Future<ClassElement?> getClassElement(String className, Uri sourceUri) async {
    final key = _getUriKey(className, sourceUri);
    
    final existing = _classes[key];
    if (existing != null) {
      return existing;
    }

    final libraryElement = await getLibraryElement(sourceUri);
    final element = libraryElement?.getClass(className);

    if (element != null) {
      _classes[key] = element;
    }

    return element;
  }

  /// Creates a stable cache key for analyzer element lookups.
  ///
  /// The key uniquely identifies a declaration within a library by combining:
  /// - The library URI
  /// - The declaration name (class, enum, mixin, typedef)
  ///
  /// Example output:
  /// ```
  /// package:example/src/foo.dart#MyClass
  /// ```
  ///
  /// Used internally for caching analyzer elements.
  String _getUriKey(String name, Uri sourceUri) => "${sourceUri.toString()}#$name";

  /// Retrieves the [EnumElement] corresponding to [enumName] within the library
  /// identified by [sourceUri].
  ///
  /// This method mirrors the behavior of [getClassElement], but for enum
  /// declarations. It provides efficient, analyzer-based enum resolution with
  /// automatic caching.
  ///
  /// ### Behavior
  /// - Generates a lookup key based on the library URI and enum name.
  /// - Returns a cached [EnumElement] if available.
  /// - Otherwise resolves the library using [getLibraryElement].
  /// - Looks up the enum via `libraryElement.getEnum(enumName)`.
  /// - Caches the resolved element for future requests.
  ///
  /// ### Parameters
  /// - `enumName`: The simple name of the enum (e.g., `"LogLevel"`).
  /// - `sourceUri`: The URI of the file where the enum is expected to reside.
  ///
  /// ### Returns
  /// - The resolved [EnumElement], or `null` if the enum is not found.
  ///
  /// ### Notes
  /// This method is part of JetLeaf's internal reflection system and is not
  /// intended to be used directly by user code.
  @protected
  Future<EnumElement?> getEnumElement(String enumName, Uri sourceUri) async {
    final key = _getUriKey(enumName, sourceUri);
    
    final existing = _enums[key];
    if (existing != null) {
      return existing;
    }

    final libraryElement = await getLibraryElement(sourceUri);
    final element = libraryElement?.getEnum(enumName);

    if (element != null) {
      _enums[key] = element;
    }

    return element;
  }

  /// Retrieves the [TypeAliasElement] corresponding to the typedef named
  /// [typedefName] within the library identified by [sourceUri].
  ///
  /// This method provides a cached lookup mechanism for Dart typedefs using the
  /// analyzer's semantic model. It ensures that repeated requests for the same
  /// typedef do not require redundant analyzer traversal.
  ///
  /// ### Behavior
  /// - Builds a unique cache key combining the source URI and typedef name.
  /// - Checks the local typedef cache for an existing entry.
  /// - If absent, resolves the library using [getLibraryElement].
  /// - Retrieves the typedef via `libraryElement.getTypeAlias(typedefName)`.
  /// - Stores and returns the resolved element.
  ///
  /// ### Parameters
  /// - `typedefName`: The simple identifier of the typedef.
  /// - `sourceUri`: The library URI where the typedef is expected to be
  ///   declared.
  ///
  /// ### Returns
  /// - The resolved [TypeAliasElement], or `null` if the typedef is not found.
  ///
  /// This API is restricted to JetLeaf internals and marked `@protected`.
  @protected
  Future<TypeAliasElement?> getTypedefElement(String typedefName, Uri sourceUri) async {
    final key = _getUriKey(typedefName, sourceUri);
    
    final existing = _typedefs[key];
    if (existing != null) {
      return existing;
    }

    final libraryElement = await getLibraryElement(sourceUri);
    final element = libraryElement?.getTypeAlias(typedefName);

    if (element != null) {
      _typedefs[key] = element;
    }

    return element;
  }

  /// Retrieves the [MixinElement] corresponding to the mixin named [mixinName]
  /// within the library identified by [sourceUri].
  ///
  /// Provides analyzer-backed mixin resolution with caching to avoid unnecessary
  /// repeated analyzer calls.
  ///
  /// ### Behavior
  /// - Constructs a cache key using the library URI and mixin name.
  /// - Returns a cached [MixinElement] if available.
  /// - Otherwise resolves the library via [getLibraryElement].
  /// - Looks up the mixin using `libraryElement.getMixin(mixinName)`.
  /// - Caches and returns the resolved analyzer element.
  ///
  /// ### Parameters
  /// - `mixinName`: The simple name of the mixin (e.g., `"Serializable"`).
  /// - `sourceUri`: The URI of the library where the mixin is defined.
  ///
  /// ### Returns
  /// - The resolved [MixinElement], or `null` if not found.
  @protected
  Future<MixinElement?> getMixinElement(String mixinName, Uri sourceUri) async {
    final key = _getUriKey(mixinName, sourceUri);
    
    final existing = _mixins[key];
    if (existing != null) {
      return existing;
    }

    final libraryElement = await getLibraryElement(sourceUri);
    final element = libraryElement?.getMixin(mixinName);

    if (element != null) {
      _mixins[key] = element;
    }

    return element;
  }

  /// Attempts to resolve **any supported analyzer element** (class, mixin,
  /// enum, or typedef) by name within the library referenced by [sourceUri].
  ///
  /// This method acts as a unified lookup utility when the caller is unsure
  /// what kind of declaration a given identifier refers to.
  ///
  /// ### Resolution Order
  /// The element is returned according to this priority:
  /// 1. `ClassElement`
  /// 2. `MixinElement`
  /// 3. `EnumElement`
  /// 4. `TypeAliasElement`
  ///
  /// ### Parameters
  /// - `typeName`: The simple identifier of the type-like element.
  /// - `sourceUri`: The URI of the library where the element is expected.
  ///
  /// ### Returns
  /// - A resolved [Element] (any of the supported analyzer element types),  
  ///   or `null` if no matching declaration is found.
  ///
  /// ### Notes
  /// This method does **not** use caching directly, but instead relies on the
  /// analyzer's own library element model. Use the type-specific lookup methods
  /// when performance matters.
  @protected
  Future<Element?> getTypeElement(String typeName, Uri sourceUri) async {
    final libraryElement = await getLibraryElement(sourceUri);
    if (libraryElement == null) return null;

    return libraryElement.getClass(typeName) ??
           libraryElement.getMixin(typeName) ??
           libraryElement.getEnum(typeName) ??
           libraryElement.getTypeAlias(typeName);
  }

  /// Clears all analyzer element caches maintained by this support class.
  ///
  /// JetLeaf caches resolved analyzer elements (classes, enums, mixins, and
  /// typedefs) to provide fast repeated access during metadata generation.
  /// 
  /// This method resets all caches and is invoked automatically during cleanup
  /// operations performed by JetLeaf’s generation engine.
  ///
  /// ### When Overriding
  /// - Subclasses **must** invoke `super.cleanup()` due to `@mustCallSuper`.
  /// - Subclasses **must** provide their own cleanup behavior due to
  ///   `@mustBeOverridden`.
  ///
  /// ### Side Effects
  /// - `_classes`, `_enums`, `_mixins`, `_typedefs` are all cleared.
  @mustCallSuper
  Future<void> cleanup() async {
    _classes.clear();
    _enums.clear();
    _mixins.clear();
    _typedefs.clear();
  }
}