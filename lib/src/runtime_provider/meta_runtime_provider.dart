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

import '../utils/constant.dart';
import '../exceptions.dart';
import 'runtime_provider.dart';
import '../runtime_resolver/runtime_resolver.dart';
import '../declaration/declaration.dart';
import '../utils/meta_table.dart';

/// {@template central_runtime}
/// A central, globally accessible proxy for runtime metadata in JetLeaf.
///
/// The [_MetaRuntimeProvider] class is the internal implementation behind the
/// global [Runtime] instance. It delegates all reflection and metadata queries
/// to a configured [RuntimeProvider] that is registered during bootstrap.
///
/// Once initialized, it allows the system to:
/// - Discover all reflected Dart entities (classes, enums, mixins, typedefs, etc.).
/// - Access runtime metadata such as [Package]s, [Asset]s, [LibraryDeclaration]s, etc.
/// - Query annotations, fields, methods, constructors, and more from a
///   single, consistent API.
///
/// ---
/// ⚠️ **Initialization Requirement**
/// The [register] method must be invoked before calling any query methods,
/// typically from generated bootstrap code:
///
/// ```dart
/// void main() {
///   final provider = MyGeneratedRuntimeProvider();
///   Runtime.register(StandardRuntimeRegistry.create(provider));
///   runApp();
/// }
///
/// final clazz = Runtime.getAllClasses().firstWhere(
///   (c) => c.getName() == 'MyService',
/// );
/// ```
///
/// {@endtemplate}
class _MetaRuntimeProvider extends RuntimeProvider {
  Map<Package, PackageContent>? _contents = {};
  RuntimeResolver? _resolver;
  List<Package> _packages = [];
  List<Asset> _assets = [];
  List<TypeDeclaration> _specialTypes = [];
  List<LibraryDeclaration> _libraries = [];

  _MetaRuntimeProvider._();

  /// {@template central_runtime_register}
  /// Sets the underlying [RuntimeProvider] that this central runtime will delegate to.
  ///
  /// This method must be called exactly once during application bootstrap.
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   final generated = MyGeneratedRuntimeProvider();
  ///   Runtime.register(StandardRuntimeRegistry.create(generated));
  ///   runApp();
  /// }
  /// ```
  /// After registration, you can query runtime metadata:
  /// ```dart
  /// final classes = Runtime.getAllClasses();
  /// for (final c in classes) {
  ///   print("Discovered class: ${c.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  void register(RuntimeProvider registry) {
    Map<Package, PackageContentImpl> sections = {};

    for(var reg in registry.getAllLibraries()) {
      if(sections.containsKey(reg.getPackage())) {
        sections[reg.getPackage()]!.setLibraries([...sections[reg.getPackage()]!.getAllLibraries(), reg]);
      } else {
        sections[reg.getPackage()] = PackageContentImpl(reg.getPackage(), [], [reg], -1);
      }
    }

    for(var asset in registry.getAllAssets()) {
      final pkg = sections.keys.where((k) => k.getName() == asset.getPackageName()).firstOrNull;
      if(pkg != null) {
        sections[pkg]!.setAssets([...sections[pkg]!.getAllAssets(), asset]);
      }
    }

    int hierarchyCounter = 3; // start counting non-dart packages from 3
    int? dartHierarchy;

    for (var section in sections.entries) {
      var pkg = section.key;
      int hierarchy;

      if (pkg.getIsRootPackage()) {
        hierarchy = 0;
      } else if (pkg.getName() == PackageNames.MAIN) {
        hierarchy = 1;
      } else if (pkg.getName().startsWith(PackageNames.MAIN)) {
        hierarchy = 2;
      } else if (pkg.getName() == Constant.DART_PACKAGE_NAME) {
        // mark dart for later assignment
        dartHierarchy = null; 
        continue;
      } else {
        hierarchy = hierarchyCounter++;
      }

      section.value.setHierarchy(hierarchy);
    }

    // finally assign dart package as last number
    if (dartHierarchy == null) {
      int last = hierarchyCounter; 
      for (var section in sections.entries) {
        if (section.key.getName() == Constant.DART_PACKAGE_NAME) {
          section.value.setHierarchy(last);
        }
      }
    }

    _contents = sections;
    _assets = registry.getAllAssets();
    _packages = registry.getAllPackages();
    _resolver = registry.getRuntimeResolver();
    _specialTypes = registry.getSpecialTypes();
    _libraries = registry.getAllLibraries();
  }

  Iterable<PackageContent> _sortedSections() {
    final sections = _contents!.entries.toList();
    sections.sort((a, b) => a.value.getHierarchy().compareTo(b.value.getHierarchy()));
    return sections.map((e) => e.value);
  }

  void _assertInitialized() {
    if (_contents == null || _resolver == null) {
      throw BuildException('Runtime loader has not been initialized. Call Runtime.register() before accessing any members.');
    }
  }

  @override
  List<Asset> getAllAssets() => List.unmodifiable(_assets);

  @override
  List<Package> getAllPackages() => List.unmodifiable(_packages);

  @override
  RuntimeResolver getRuntimeResolver() {
    _assertInitialized();
    return _resolver!;
  }
  
  @override
  List<LibraryDeclaration> getAllLibraries() => List.unmodifiable(_libraries);
  
  @override
  List<TypeDeclaration> getSpecialTypes() => List.unmodifiable(_specialTypes);

  List<EntityDeclaration> getAllEntities() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getAnnotations(),
          ...lib.getDeclarations(),
          ...lib.getTopLevelMethods(),
          ...lib.getTopLevelFields(),
        ],
    ];
  }

  /// {@template runtime_get_classes}
  /// Returns all discovered [ClassDeclaration]s in sorted order.
  ///
  /// Example:
  /// ```dart
  /// final classes = Runtime.getAllClasses();
  /// for (final c in classes) {
  ///   print("Class: ${c.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<ClassDeclaration> getAllClasses() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getClasses().sortedByPublicFirstThenSyntheticLast(),
        ]
    ];
  }

  /// {@template runtime_get_mixins}
  /// Returns all discovered [MixinDeclaration]s in sorted order.
  ///
  /// Mixins provide reusable class fragments that can be applied to
  /// multiple classes. This method retrieves every mixin discovered
  /// in the runtime registry.
  ///
  /// Example:
  /// ```dart
  /// final mixins = Runtime.getAllMixins();
  /// for (final m in mixins) {
  ///   print("Mixin: ${m.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<MixinDeclaration> getAllMixins() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getDeclarations().whereType<MixinDeclaration>().sortedByPublicFirstThenSyntheticLast(),
        ]
    ];
  }

  /// {@template runtime_get_enums}
  /// Returns all discovered [EnumDeclaration]s in sorted order.
  ///
  /// Enums represent fixed sets of named values. This method retrieves
  /// every enum type discovered in the runtime registry.
  ///
  /// Example:
  /// ```dart
  /// final enums = Runtime.getAllEnums();
  /// for (final e in enums) {
  ///   print("Enum: ${e.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<EnumDeclaration> getAllEnums() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getEnums().sortedByPublicFirstThenSyntheticLast(),
        ]
    ];
  }

  /// {@template runtime_get_typedefs}
  /// Returns all discovered [TypedefDeclaration]s in sorted order.
  ///
  /// Typedefs are type aliases that give alternate names to function
  /// signatures or other types.
  ///
  /// Example:
  /// ```dart
  /// final typedefs = Runtime.getAllTypedefs();
  /// for (final t in typedefs) {
  ///   print("Typedef: ${t.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<TypedefDeclaration> getAllTypedefs() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getTypedefs().sortedByPublicFirstThenSyntheticLast(),
        ]
    ];
  }

  /// {@template runtime_get_types}
  /// Returns all discovered [TypeDeclaration]s in sorted order.
  ///
  /// This includes classes, enums, mixins, and any other
  /// type declarations found during runtime scanning.
  ///
  /// Example:
  /// ```dart
  /// final types = Runtime.getAllTypes();
  /// for (final t in types) {
  ///   print("Type: ${t.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<TypeDeclaration> getAllTypes() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getDeclarations().whereType<TypeDeclaration>().sortedByPublicFirstThenSyntheticLast(),
        ]
    ];
  }

  /// {@template runtime_get_extensions}
  /// Returns all discovered [ExtensionDeclaration]s in sorted order.
  ///
  /// Extensions add methods, getters, and setters to existing
  /// types without modifying their original source.
  ///
  /// Example:
  /// ```dart
  /// final extensions = Runtime.getAllExtensions();
  /// for (final e in extensions) {
  ///   print("Extension: ${e.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<ExtensionDeclaration> getAllExtensions() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getExtensions().sortedByPublicFirstThenSyntheticLast(),
        ]
    ];
  }

  /// {@template runtime_get_constructors}
  /// Returns all discovered [ConstructorDeclaration]s in sorted order.
  ///
  /// This includes constructors from all discovered classes,
  /// sorted with public ones first and synthetic ones last.
  ///
  /// Example:
  /// ```dart
  /// final constructors = Runtime.getAllConstructors();
  /// for (final c in constructors) {
  ///   print("Constructor: ${c.getName()} in class ${c.getEnclosingClass().getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<ConstructorDeclaration> getAllConstructors() {
    _assertInitialized();
    return [
      for (final cls in getAllClasses())
        ...cls.getConstructors().sortedByPublicFirstThenSyntheticLast(),
    ];
  }

  /// {@template runtime_get_methods}
  /// Returns all discovered [MethodDeclaration]s, including top-level, class,
  /// enum, and extension methods.
  ///
  /// Example:
  /// ```dart
  /// final methods = Runtime.getAllMethods();
  /// for (final m in methods) {
  ///   print("Method: ${m.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<MethodDeclaration> getAllMethods() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getTopLevelMethods().sortedByPublicFirstThenSyntheticLast(),
        ],
      for (final cls in getAllClasses())
        ...cls.getMethods().sortedByPublicFirstThenSyntheticLast(),
      for (final enm in getAllEnums())
        ...enm.getMembers().whereType<MethodDeclaration>().sortedByPublicFirstThenSyntheticLast(),
      for (final ext in getAllExtensions())
        ...ext.getMembers().whereType<MethodDeclaration>().sortedByPublicFirstThenSyntheticLast(),
    ];
  }

  /// {@template runtime_get_fields}
  /// Returns all discovered [FieldDeclaration]s in sorted order.
  ///
  /// Includes:
  /// - Top-level fields
  /// - Fields declared in classes
  /// - Fields declared in enums
  /// - Fields declared in extensions
  ///
  /// Example:
  /// ```dart
  /// final fields = Runtime.getAllFields();
  /// for (final f in fields) {
  ///   print("Field: ${f.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<FieldDeclaration> getAllFields() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        for (final lib in section.getAllLibraries()) ...[
          ...lib.getTopLevelFields().sortedByPublicFirstThenSyntheticLast(),
        ],
      for (final cls in getAllClasses())
        ...cls.getFields().sortedByPublicFirstThenSyntheticLast(),
      for (final enm in getAllEnums())
        ...enm.getMembers().whereType<FieldDeclaration>().sortedByPublicFirstThenSyntheticLast(),
      for (final ext in getAllExtensions())
        ...ext.getMembers().whereType<FieldDeclaration>().sortedByPublicFirstThenSyntheticLast(),
    ];
  }

  /// {@template runtime_get_records}
  /// Returns all discovered [RecordDeclaration]s in sorted order.
  ///
  /// Includes:
  /// - Top-level records
  /// - Records declared inside classes
  /// - Records declared inside enums
  /// - Records declared inside extensions
  ///
  /// Example:
  /// ```dart
  /// final records = Runtime.getAllRecords();
  /// for (final r in records) {
  ///   print("Record: ${r.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<RecordDeclaration> getAllRecords() {
    _assertInitialized();
    return [
      for (final section in _sortedSections())
        ...section.getAllLibraries().flatMap((l) => l.getTopLevelRecords().sortedByPublicFirstThenSyntheticLast()),
      for (final cls in getAllClasses())
        ...cls.getRecords().sortedByPublicFirstThenSyntheticLast(),
      for (final enm in getAllEnums())
        ...enm.getMembers().whereType<RecordDeclaration>().sortedByPublicFirstThenSyntheticLast(),
      for (final ext in getAllExtensions())
        ...ext.getMembers().whereType<RecordDeclaration>().sortedByPublicFirstThenSyntheticLast(),
    ];
  }

  /// {@template runtime_get_annotations}
  /// Returns all discovered [AnnotationDeclaration]s across the entire runtime.
  ///
  /// Example:
  /// ```dart
  /// final annotations = Runtime.getAllAnnotations();
  /// for (final a in annotations) {
  ///   print("Annotation: ${a.getName()}");
  /// }
  /// ```
  /// {@endtemplate}
  List<AnnotationDeclaration> getAllAnnotations() {
    _assertInitialized();
    final Set<AnnotationDeclaration> allAnnotations = {};

    final flat = _sortedSections().flatMap((s) => s.getAllLibraries()).flatMap((l) => l.getDeclarations());

    for (final decl in flat) {
      allAnnotations.addAll(decl.getAnnotations());

      if (decl is ClassDeclaration) {
        final res = decl.getMembers().flatMap((m) => m.getAnnotations());
        allAnnotations.addAll(res);
      }
    }

    return allAnnotations.toList().sortedByPublicFirstThenSyntheticLast();
  }
}

/// {@macro central_runtime}
///
/// This singleton is the **globally accessible runtime registry**.
/// It must be registered before any queries are made.
///
/// Example:
/// ```dart
/// void main() {
///   Runtime.register(MyGeneratedRegistry());
///   print(Runtime.getAllPackages());
/// }
/// ```
final _MetaRuntimeProvider Runtime = _MetaRuntimeProvider._();