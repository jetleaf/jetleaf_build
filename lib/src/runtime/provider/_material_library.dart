part of 'runtime_provider.dart';

/// {@template _unresolved_class}
/// Represents a class that could not be fully resolved or identified
/// during runtime analysis or reflection.
///
/// This class is typically used by the runtime system to track classes
/// that are referenced but whose metadata could not be loaded or
/// interpreted completely. It stores the essential identifying
/// information to allow partial introspection, logging, or error
/// reporting, without causing runtime failures.
///
/// Instances of `_UnresolvedClass` include:
/// - The simple name of the class (without package/library prefix)
/// - The fully qualified name of the class (including package/library context)
///
/// This enables tools and runtime resolvers to reference these
/// classes in diagnostics, logs, or for potential future resolution.
///
/// Example:
/// ```dart
/// final unresolved = _UnresolvedClass('MyClass', 'my_package.lib.MyClass');
/// print(unresolved.getName()); // "MyClass"
/// print(unresolved.getQualifiedName()); // "my_package.lib.MyClass"
/// ```
/// {@endtemplate}
final class _UnresolvedClass implements UnresolvedClass {
  /// The fully qualified name of the unresolved class, including
  /// the package and library context.
  final String _qualifiedName;

  /// The simple name of the unresolved class (without package or library prefix).
  final String _name;

  /// {@macro _unresolved_class}
  _UnresolvedClass(this._name, this._qualifiedName);

  @override
  String getName() => _name;

  @override
  String getQualifiedName() => _qualifiedName;

  @override
  String toString() => "UnresolvedClass($_name **** $_qualifiedName)";

  @override
  List<Object?> equalizedProperties() => [_name, _qualifiedName];
}

// ====================================================== MATERIAL LIBRARY ==============================================================

/// {@template material_library_impl}
/// Internal implementation of the [MaterialLibrary] interface that manages
/// runtime reflection, class and method discovery, and source library
/// metadata. This class provides mechanisms for efficiently caching and
/// resolving class declarations, methods, and source code from both SDK
/// and package libraries. It also supports periodic automatic cleanup
/// to prevent memory leaks and maintain up-to-date reflection data.
///
/// Fields:
/// - [_taggedLocation]: Debug label or tag for the library instance, useful
///   for logging and diagnostics.
/// - [_sourceLibraries]: A list of [_SourceLibrary] instances representing
///   all libraries loaded into the material library, including SDK and
///   user-defined packages.
/// - [_caveats]: Keywords that require special handling during generic type
///   parsing (e.g., `_Map` or `_Set` are normalized to standard types).
/// - [_typeCache]: Maps Dart [Type] objects to their corresponding
///   [ClassDeclaration] for fast lookup.
/// - [_nameCache]: Maps simple class names to their corresponding
///   [ClassDeclaration].
/// - [_qualifiedNameCache]: Maps fully qualified class names (including
///   package and library info) to their [ClassDeclaration].
///   [ClassDeclaration] for efficient object-based reflection.
/// - [_periodicCleanupTimer]: Optional [Timer] that schedules automatic
///   cleanup of caches and internal metadata to reduce memory footprint
///   in long-running applications.
/// {@endtemplate}
abstract final class _MaterialLibrary extends AbstractClassDeclarationSupport implements MaterialLibrary {
  /// Debug label for this material library instance.
  String _taggedLocation = "$MaterialLibrary";

  /// All loaded source libraries, including SDK and package libraries.
  List<_SourceLibrary> _sourceLibraries = [];

  /// Keywords requiring normalization or special handling during type parsing.
  final List<String> _caveats = ['_Map', '_Set'];

  /// Cache for fast type-based lookups.
  final HashMap<Type, ClassDeclaration> _typeCache = HashMap();

  /// Cache for fast name-based lookups.
  final HashMap<String, ClassDeclaration> _nameCache = HashMap();

  /// Cache for fast fully qualified name-based lookups.
  final LinkedHashMap<String, ClassDeclaration> _qualifiedNameCache = LinkedHashMap();

  /// Holds the sub classes of a qualified name lookup
  final LinkedHashMap<String, List<_ClassReference>> _qualifiedNameSubClassCache = LinkedHashMap();

  /// Holds the sub classes of a type lookup
  final LinkedHashMap<Type, List<_ClassReference>> _typedSubClassCache = LinkedHashMap();

  /// Holds the sub classes of a class declaration lookup
  final LinkedHashMap<String, List<ClassDeclaration>> _classDeclarationSubClassCache = LinkedHashMap();

  /// Holds the annotated methods of a type lookup
  final LinkedHashMap<Type, List<MethodDeclaration>> _annotatedMethodCache = LinkedHashMap();

  /// Holds the generated class of each package
  final LinkedHashMap<Uri, List<ClassDeclaration>> _generatedClassCacheByPackageName = LinkedHashMap();

  /// Holds the cache of libraries to be searched for sub classes of a class.
  final HashMap<String, List<_SourceLibrary>> _packagedSubClassLibrariesToSearch = HashMap();

  /// Optional timer used to schedule **automatic periodic cleanup**
  /// of internal runtime caches.
  ///
  /// When enabled via `enablePeriodicCleanup`, this timer triggers
  /// batch cleanup at a fixed interval to prevent unbounded memory
  /// growth in long-running applications.
  ///
  /// If `null`, periodic cleanup is disabled and cleanup is only
  /// performed opportunistically during lookups.
  Timer? _periodicCleanupTimer;

  /// Maximum number of entries allowed across internal runtime caches.
  ///
  /// This value acts as a **soft upper bound** rather than a strict limit.
  /// Cleanup is only triggered when cache sizes significantly exceed
  /// this threshold to avoid excessive churn.
  ///
  /// Default: `1,000,000`
  int _cacheSize = 1_000_000;

  /// Counts lookup operations performed by the runtime provider.
  ///
  /// This counter is used to **throttle cleanup checks**, ensuring that
  /// cleanup logic is not evaluated on every cache access, which would
  /// degrade performance.
  int _lookupCounter = 0;

  /// Number of lookups required before triggering a cleanup check.
  ///
  /// Cleanup is evaluated only once every [CLEANUP_CHECK_INTERVAL]
  /// lookups to amortize cleanup cost across many read operations.
  ///
  /// Default: `1000`
  final int CLEANUP_CHECK_INTERVAL = 1000;

  /// Adds a new library to the material library.
  ///
  /// This method wraps the given [package], [sourceCode], and
  /// [library] mirror into a [_SourceLibrary] instance and stores it in
  /// [_sourceLibraries]. The [isSdkLibrary] flag indicates whether the library
  /// belongs to the Dart SDK.
  ///
  /// Example:
  /// ```dart
  /// library.addLibrary(myPackage, Uri.parse('package:my_package/my_lib.dart'), sourceCode, false, libraryMirror);
  /// ```
  void addLibrary(Package package, String sourceCode, bool isSdkLibrary, mirrors.LibraryMirror library) {
    final source = _SourceLibrary(package, sourceCode, isSdkLibrary, library);
    source._init(resolveGenericAnnotationIfNeeded);
  
    _sourceLibraries.add(source);
  }

  /// Sorts and finalizes the list of loaded libraries.
  ///
  /// This method assigns a hierarchy to each library based on its type:
  /// - Root package libraries get hierarchy 0
  /// - The main package library gets hierarchy 1
  /// - Sub-packages of the main package get hierarchy 2
  /// - Other packages get incrementing hierarchy starting at 3
  /// - Dart SDK libraries are always placed last
  ///
  /// After computing the hierarchy, the libraries are sorted accordingly and
  /// stored in an unmodifiable view.
  ///
  /// Example:
  /// ```dart
  /// library.freezeLibrary();
  /// final libraries = library.getSourceLibraries();
  /// ```
  void freezeLibrary() {
    if (_sourceLibraries is UnmodifiableListView) return;

    List<_SourceLibrary> sourceLibraries = List<_SourceLibrary>.from(_sourceLibraries);
    int hierarchyCounter = 3;
    final mainPackage = PackageNames.MAIN;

    // First pass: assign non-dart packages
    for (final lib in sourceLibraries) {
      final pkg = lib.getPackage();

      if (lib.isSdkLibrary()) {
        lib._setHierarchy(-1); // mark for later
        continue;
      }

      if (pkg.getIsRootPackage()) {
        lib._setHierarchy(0);
      } else if (pkg.getName() == mainPackage) {
        lib._setHierarchy(1);
      } else if (pkg.getName().startsWith('$mainPackage.')) {
        lib._setHierarchy(2);
      } else {
        lib._setHierarchy(hierarchyCounter++);
      }
    }

    // Dart SDK libraries always come last
    final dartHierarchy = hierarchyCounter;
    for (final lib in sourceLibraries) {
      if (lib.isSdkLibrary()) {
        lib._setHierarchy(dartHierarchy);
      }
    }

    // Sort by hierarchy (stable order)
    sourceLibraries.sort((a, b) => a._hierarchy.compareTo(b._hierarchy));

    RuntimeBuilder.logLibraryVerboseInfo("Warming up application classes");
    final result = RuntimeBuilder.timeExecution(() {
      // Init type classes
      findClass<String>();
      findClass<int>();
      findClass<double>();
      findClass<List>();
      findClass<Map>();
      findClass<bool>();
      findClass<Set>();
      findClass<Iterable>();
      findClass<Object>();

      // Init name classes
      findClassByName("String");
      findClassByName("int");
      findClassByName("double");
      findClassByName("List");
      findClassByName("Map");
      findClassByName("bool");
      findClassByName("Set");
      findClassByName("Iterable");
      findClassByName("Object");

      // Cold start libraries that are jetleaf-packaged
      final jetleafLibraries = sourceLibraries.where((s) => s._package.isJetleafPackaged() || s._package.getIsRootPackage());

      for (final library in jetleafLibraries) {
        _getClasses(library).toList();
      }

      return;
    });
    RuntimeBuilder.logLibraryVerboseInfo("Warming up application classes completed within ${result.getFormatted()}");

    _sourceLibraries = UnmodifiableListView(sourceLibraries);
  }

  /// Sets a debug or descriptive tag for this material library.
  ///
  /// This tag is primarily used for logging, diagnostics, or labeling
  /// the library instance.
  ///
  /// Example:
  /// ```dart
  /// library.setTag("MainAppLibrary");
  /// ```
  void setTag(String taggedLocation) {
    _taggedLocation = taggedLocation;
  }

  @override
  void enablePeriodicCleanup({Duration interval = const Duration(minutes: 5)}) {
    // Cancel previous timer if any
    _periodicCleanupTimer?.cancel();

    // Schedule new periodic cleanup
    _periodicCleanupTimer = Timer.periodic(interval, (_) => _cleanupWhenNeeded());
  }

  @override
  void provideMaxCacheSize(int cacheSize) {
    _cacheSize = cacheSize;
  }

  @override
  void cleanup() {
    _typeCache.clear();
    _nameCache.clear();
    _qualifiedNameCache.clear();
    linkGenerationInProgress.clear();
    _typedSubClassCache.clear();
    _qualifiedNameSubClassCache.clear();
    _annotatedMethodCache.clear();
    _generatedClassCacheByPackageName.clear();
    _packagedSubClassLibrariesToSearch.clear();
    _classDeclarationSubClassCache.clear();
  }

  @override
  List<Object?> equalizedProperties() => [_taggedLocation, getCurrentTag().label];

  @override
  ClassDeclaration findClass<T>([String? package]) {
    try {
      return findClassByType(T, package);
    } on ClassNotFoundException catch (_) {
      return obtainClassDeclaration(T, package);
    }
  }
  
  @override
  ClassDeclaration findClassByName(String name, [String? package]) {
    if (_nameCache[name] case final classDeclaration?) return classDeclaration;

    _cleanupWhenNeeded();

    if (package case final package?) {
      final interestedParties = _performLibraryLookups(package);
      for (final interestedParty in interestedParties) {
        if (_performSpecificMirrorLookupBySimpleName(name, interestedParty) case final declarationMirror?) {
          final result = _buildClassDeclaration(declarationMirror, interestedParty);
          _nameCache[name] = result;
          return result;
        }
      }
    }

    if (_performMirrorLookupBySimpleName(name) case final declarationMirror?) {
      final result = _buildClassDeclaration(declarationMirror);
      _nameCache[name] = result;
      return result;
    }

    if (name == Dynamic.KEYWORD || name == "dart:mirrors.dynamic") {
      final result = findClass<Dynamic>();
      _nameCache[name] = result;
      return result;
    } else if (name == Void.KEYWORD || name == "dart:mirrors.void") {
      final result = findClass<Void>();
      _nameCache[name] = result;
      return result;
    }

    if (GenericTypeParser.isGeneric(name)) {
      final result = _findGenericClass(name);
      _nameCache[name] = result;
      return result;
    }

    throw ClassNotFoundException(name);
  }
  
  @override
  ClassDeclaration findClassByQualifiedName(String qualifiedName) {
    if (_findInQualifiedNameCache(qualifiedName) case final classDeclaration?) return classDeclaration;

    _cleanupWhenNeeded();

    for (final source in _sourceLibraries) {
      if (source._classReferences.where((ref) => ref._qualifiedName == qualifiedName).firstOrNull case final reference?) {
        return _fetchOrGenerate(reference._classMirror, reference._libraryUri, source._sourceCode);
      }
    }

    final uriString = ReflectionUtils.extractLibraryUri(qualifiedName);
    final className = ReflectionUtils.extractClassName(qualifiedName);
    if (_performLibraryLookup(uriString) case final source?) {
      if (_performSpecificMirrorLookupBySimpleName(className, source) case final declarationMirror?) {
        return _buildClassDeclaration(declarationMirror);
      }
    }

    if (RuntimeUtils.getPackageNameFromUri(uriString) case final package?) {
      final interestedParties = _performLibraryLookups(package);
      for (final interestedParty in interestedParties) {
        if (_performSpecificMirrorLookupBySimpleName(className, interestedParty) case final declarationMirror?) {
          return _buildClassDeclaration(declarationMirror, interestedParty);
        }
      }
    }

    return findClassByName(className, RuntimeUtils.getPackageNameFromUri(uriString));
  }
  
  @override
  ClassDeclaration findClassByType(Type type, [String? package]) {
    if (type == mirrors.Mirror 
      || type == mirrors.ObjectMirror
      || type == mirrors.ClassMirror
      || type == mirrors.TypeMirror
      || type == mirrors.DeclarationMirror
    ) {
      throw ImmaterialClassException(type.toString());
    }

    if (_findInTypeCache(type) case final classDeclaration?) return classDeclaration;

    final mirrorType = mirrors.reflectType(type);
    if (findRealClassUriFromMirror(mirrorType) case final location?) {
      final qualifiedName = ReflectionUtils.buildQualifiedName(type.toString(), location.toString());
      if (_findInQualifiedNameCache(qualifiedName) case final cache?) {
        return cache;
      }
    }

    _cleanupWhenNeeded();

    final typeString = type.toString();

    if (type == dynamic || typeString == Dynamic.KEYWORD) {
      return findClass<Dynamic>();
    } else if (typeString == Void.KEYWORD) {
      return findClass<Void>();
    }

    if (GenericTypeParser.isGeneric(typeString)) return _findGenericClass(typeString, type, package);

    if (package case final package?) {
      final interestedParties = _performLibraryLookups(package);
      for (final interestedParty in interestedParties) {
        if (_performSpecificMirrorLookupByType(type, interestedParty) case final declarationMirror?) {
          return _buildClassDeclaration(declarationMirror, interestedParty, type);
        }
      }
    }

    if (_performMirrorLookupByType(type) case final declarationMirror?) {
      return _buildClassDeclaration(declarationMirror, null, type);
    }

    final reflected = _getMirror(type);
    return _buildClassDeclaration(reflected, null, type);
  }

  @override
  SourceLibrary? getSourceLibrary(String identifier) => _performLibraryLookup(identifier);

  @override
  List<SourceLibrary> getSourceLibraries() {
    freezeLibrary();
    return _sourceLibraries;
  }

  @override
  ClassDeclaration obtainClassDeclaration(Object object, [String? package]) {
    if (object case Type object) {
      return findClassByType(object, package);
    }

    final objectString = object.toString();
    final objectRuntimeType = object.runtimeType;
    final objectRuntimeTypeString = objectRuntimeType.toString();

    if (_getMirror(object) case mirrors.FunctionTypeMirror reflected) {
      return _buildClassDeclaration(reflected);
    }

    if (_getMirror(object) case mirrors.ClosureMirror reflected) {
      return _buildClassDeclaration(reflected);
    }
    
    try {
      if(objectRuntimeTypeString.notEqualsIgnoreCase("object") || objectRuntimeTypeString.notEqualsIgnoreCase(Dynamic.KEYWORD)) {
        final qualifiedName = ReflectionUtils.findQualifiedNameFromType(objectRuntimeType);

        if (qualifiedName == ReflectionUtils.KEYWORD) {
          final reflected = _getMirror(object);
          return _buildClassDeclaration(reflected);
        }
        
        return findClassByQualifiedName(qualifiedName);
      } else {
        final qualifiedName = ReflectionUtils.findQualifiedName(object);

        if (qualifiedName == ReflectionUtils.KEYWORD) {
          final reflected = _getMirror(object);
          return _buildClassDeclaration(reflected);
        }

        return findClassByQualifiedName(qualifiedName);
      }
    } on ClassNotFoundException catch (_) {
      try {
        final reflected = _getMirror(object);
        return _buildClassDeclaration(reflected);
      } catch (_) {}

      try {
        final reflected = _getMirror(objectRuntimeType);
        return _buildClassDeclaration(reflected);
      } catch (_) {}
      
      if(objectRuntimeTypeString.notEqualsIgnoreCase("type")) {
        return findClassByName(objectRuntimeTypeString, package);
      }

      return findClassByName(objectString, package);
    }
  }

  @override
  LibraryDeclaration getLibrary(String uri) {
    if (_performLibraryLookup(uri) case final cache?) {
      final name = mirrors.MirrorSystem.getName(cache._libraryMirror.simpleName);

      return StandardLibraryDeclaration(
        uri: uri,
        parentPackage: cache.getPackage(),
        name: name,
        isPublic: !cache._libraryMirror.isPrivate,
        isSynthetic: !isSynthetic(name)
      );
    }

    final name = RuntimeUtils.getPackageNameFromUri(uri) ?? "Unknown";

    return StandardLibraryDeclaration(
      uri: uri.toString(),
      parentPackage: createDefaultPackage(name),
      isPublic: !isInternal(uri.toString()),
      isSynthetic: isSynthetic(uri.toString()),
      name: name
    );
  }

  @override
  String readSourceCode(Object uri) {
    if (uri case Uri uri) {
      if (_performLibraryLookup(uri.toString()) case final source?) {
        return source._sourceCode;
      }
    } else if (uri case String uri) {
      try {
        return readSourceCode(Uri.parse(uri));
      } catch (_) {}
    }

    return "";
  }

  @override
  Iterable<UnresolvedClass> getUnresolvedClasses() sync* {
    if (_sourceLibraries.where((f) => f._package.getIsRootPackage()).firstOrNull case final rootLibrary?) {
      for (final source in rootLibrary._libraryMirror.declarations.values) {
        if (source case mirrors.ClassMirror source) {
          final name = mirrors.MirrorSystem.getName(source.simpleName);
          final libraryUri = source.location?.sourceUri.toString() ?? rootLibrary._uri.toString();
          Type type = source.hasReflectedType ? source.reflectedType : source.runtimeType;
          type = resolveGenericAnnotationIfNeeded(type, source, libraryUri, Uri.parse(libraryUri), name);
          
          if (!source.isPrivate && !isSynthetic(name) && GenericTypeParser.shouldCheckGeneric(type)) {
            yield _UnresolvedClass(name, buildQualifiedName(name, libraryUri));
          }
        }
      }
    }
  }

  @override
  Iterable<UnresolvedClass> getPackageUnresolvedClasses(String packageName) sync* {
    if (_performLibraryLookup(packageName) case final rootLibrary?) {
      for (final source in rootLibrary._libraryMirror.declarations.values) {
        if (source case mirrors.ClassMirror source) {
          final name = mirrors.MirrorSystem.getName(source.simpleName);
          final libraryUri = source.location?.sourceUri.toString() ?? rootLibrary._uri.toString();
          Type type = source.hasReflectedType ? source.reflectedType : source.runtimeType;
          type = resolveGenericAnnotationIfNeeded(type, source, libraryUri, Uri.parse(libraryUri), name);
          
          if (!source.isPrivate && !isSynthetic(name) && GenericTypeParser.shouldCheckGeneric(type)) {
            yield _UnresolvedClass(name, buildQualifiedName(name, libraryUri));
          }
        }
      }
    }
  }

  @override
  Iterable<ClassDeclaration> getAllClassesInAPackage(String packageName) sync* {
    final possibleSuspects = _performLibraryLookups(packageName);

    for (final suspect in possibleSuspects) {
      yield* _getClasses(suspect);
    }
  }

  /// Materializes all classes declared in the given [_SourceLibrary].
  ///
  /// This method iterates over the library’s internal `_classReferences` collection
  /// and lazily converts each `_ClassReference` into a full [ClassDeclaration]
  /// using [_fetchOrGenerate].
  ///
  /// The generation process preserves:
  /// - The class’s originating library URI
  /// - SDK vs non-SDK library classification
  /// - Reflection metadata from the underlying `ClassMirror`
  ///
  /// ### Parameters
  /// - [suspect]: The source library whose class declarations should be materialized.
  ///
  /// ### Yields
  /// - A lazily generated sequence of [ClassDeclaration] objects representing
  ///   every class declared in the library.
  ///
  /// ### Notes
  /// - This method performs **no filtering** (e.g. abstract, private, or subtype checks).
  /// - Classes are generated on demand, making it suitable for large libraries.
  /// - Intended for internal use during runtime scanning and hierarchy analysis.
  ///
  /// ### Example
  /// ```dart
  /// for (final clazz in _getClasses(library)) {
  ///   print(clazz.getQualifiedName());
  /// }
  /// ```
  Iterable<ClassDeclaration> _getClasses(_SourceLibrary suspect) sync* {
    final key = suspect._libraryMirror.uri;
    
    if (_generatedClassCacheByPackageName[key] case final classes?) {
      yield* classes;
      return;
    }

    final references = suspect._classReferences;
    final result = <ClassDeclaration>[];

    for (final reference in references) {
      final uri = reference._libraryUri;
      final name = mirrors.MirrorSystem.getName(reference._classMirror.simpleName);

      if (isSynthetic(name)) continue;

      if (_findInQualifiedNameCache(ReflectionUtils.buildQualifiedName(name, uri.toString())) case final classDeclaration?) {
        result.add(classDeclaration);
      } else {
        result.add(_fetchOrGenerate(reference._classMirror, reference._libraryUri));
      }
    }

    _generatedClassCacheByPackageName[key] = result;

    yield* result;
  }

  @override
  Iterable<ClassDeclaration> getAllClasses() sync* {
    for (final library in _sourceLibraries) {
      yield* _getClasses(library);
    }
  }

  @override
  Iterable<ClassDeclaration> getAllClassesInAPackageUri(String packageUri) sync* {
    if (_performLibraryLookup(packageUri) case final suspect?) {
      yield* _getClasses(suspect);
    }
  }

  @override
  Iterable<ClassReference> getSubClassReferences(String qualifiedName) sync* {
    yield* _getSubClassReferencesUsingQualifiedName(qualifiedName);
  }

  @override
  Iterable<ClassDeclaration> getSubClasses(ClassDeclaration classDeclaration) sync* {
    if (_classDeclarationSubClassCache[classDeclaration.getQualifiedName()] case final declarations?) {
      yield* declarations;
      return;
    }

    final references = _getSubClassReferencesUsingQualifiedName(classDeclaration.getQualifiedName(), classDeclaration.getType());

    final result = <ClassDeclaration>[];

    for (final reference in references) {
      result.add(_fetchOrGenerate(reference._classMirror, reference._libraryUri));
    }

    _classDeclarationSubClassCache[classDeclaration.getQualifiedName()] = result;
    yield* result;
  }

  @override
  Iterable<MethodDeclaration> collectAnnotatedMethods<T>([bool onlyJetleafPackages = true]) sync* {
    if (_annotatedMethodCache[T] case final methods?) {
      yield* methods;
      return;
    }

    final seen = <String>{};
    final results = <MethodDeclaration>[];
    Iterable<_SourceLibrary> libraries;

    if (onlyJetleafPackages) {
      libraries = _sourceLibraries.where((s) => s._package.getJetleafDependencies().isNotEmpty);
    } else {
      libraries = _sourceLibraries;
    }

    final references = libraries.flatMap((lib) => lib._classReferences
      .where((ref) => ref._annotatedMethods.any((meth) => meth.annotationInstance == T || meth.annotationInstance is T)));

    for (final reference in references) {
      for (final methodReference in reference._annotatedMethods) {
        if (seen.add(methodReference._id) && methodReference.annotationInstance == T || methodReference.annotationInstance is T) {
          final className = mirrors.MirrorSystem.getName(reference._classMirror.simpleName);
          final analyzedClass = getAnalyzedClassDeclaration(className, reference._libraryUri);
          final parentClass = getLinkDeclaration(reference._classMirror, reference._libraryUri.toString());
          
          results.add(generateMethod(
            methodReference._methodMirror,
            analyzedClass?.members,
            reference._libraryUri.toString(),
            reference._libraryUri,
            className,
            parentClass
          ));
        }
      }
    }

    // Cache the results
    _annotatedMethodCache[T] = results;
    
    yield* results;
  }

  @override
  Iterable<MethodDeclaration> getAllMethods() sync* {
    yield* _getMethods(_sourceLibraries);
  }

  /// Iterates through a collection of source libraries and yields all methods
  /// declared within all classes in those libraries.
  ///
  /// This method performs a **library-scoped traversal**:
  /// 1. Iterates over each [_SourceLibrary] provided.
  /// 2. For each library, examines all declarations exposed by its mirror.
  /// 3. Filters only class declarations (`mirrors.ClassMirror`).
  /// 4. Converts each class mirror into a materialized [ClassDeclaration]
  ///    using [_fetchOrGenerate], respecting the library URI and SDK flag.
  /// 5. Iterates over the methods of each class and yields them individually.
  ///
  /// ### Parameters
  /// - [libraries]: An iterable of [_SourceLibrary] objects to inspect.
  ///
  /// ### Yields
  /// - [MethodDeclaration] instances representing each method of every class
  ///   in the given libraries.
  ///
  /// ### Notes
  /// - This method does **not** traverse top-level functions or extensions.
  /// - Only methods from class declarations are returned.
  /// - The use of `sync*` ensures methods are lazily generated, avoiding
  ///   unnecessary memory allocation for large libraries.
  ///
  /// ### Example
  /// ```dart
  /// final libraries = [myLibrary1, myLibrary2];
  /// for (final method in _getMethods(libraries)) {
  ///   print(method.name);
  /// }
  /// ```
  Iterable<MethodDeclaration> _getMethods(Iterable<_SourceLibrary> libraries) sync* {
    for (final suspect in libraries) {
      yield* _getClasses(suspect).toList().flatMap((c) => c.getMethods());
    }
  }

  @override
  Iterable<MethodDeclaration> getAllJetleafDependentMethods() sync* {
    yield* _getMethods(_sourceLibraries.where((s) => s._package.getJetleafDependencies().isNotEmpty));
  }

  @override
  List<mirrors.LibraryMirror> getLibraries() => _sourceLibraries.map((s) => s._libraryMirror).toList();

  // ==================================================== HELPER METHODS ============================================================

  /// Performs a lightweight cleanup check based on lookup frequency.
  ///
  /// This method is invoked during normal lookup operations and:
  /// - Increments the lookup counter
  /// - Triggers batch cleanup only when the counter reaches the
  ///   configured [CLEANUP_CHECK_INTERVAL]
  ///
  /// This design ensures:
  /// - **O(1)** overhead per lookup
  /// - Cleanup cost is amortized
  /// - No cleanup occurs during hot paths unless necessary
  void _cleanupWhenNeeded() {
    _lookupCounter++;
    if (_lookupCounter % CLEANUP_CHECK_INTERVAL != 0) return;
    
    // Batch cleanup operations
    _performBatchCleanup();
  }

  /// Performs **batched eviction** across all internal runtime caches.
  ///
  /// Cleanup is conservative and only activates when a cache exceeds
  /// its allowed capacity by a significant margin. Rather than removing
  /// entries one-by-one, this method trims caches in **bulk** to reduce
  /// overhead and lock contention.
  ///
  /// ---
  ///
  /// ## Eviction Strategy
  ///
  /// - Cleanup triggers only when cache size exceeds
  ///   `_cacheSize × OVERFLOW_FACTOR`
  /// - Removes the **oldest 10% of entries** in a single pass
  /// - Applies uniformly across all runtime caches
  ///
  /// This approach provides:
  /// - Stable memory usage
  /// - Predictable cleanup cost
  /// - Minimal impact on lookup performance
  ///
  /// ---
  ///
  /// ## Notes
  ///
  /// - Cache ordering assumes insertion-order maps
  /// - Eviction is best-effort, not deterministic
  /// - Link-generation state is always cleared to prevent deadlocks
  void _performBatchCleanup() {
    // Only trim if significantly over limit
    const double OVERFLOW_FACTOR = 1.2;
    
    void trimCache<K, V>(Map<K, V> cache) {
      if (cache.length <= _cacheSize * OVERFLOW_FACTOR) return;
      
      // Remove oldest 10% instead of one-by-one
      final keysToRemove = cache.keys.take(cache.length ~/ 10).toList();
      for (final key in keysToRemove) {
        cache.remove(key);
      }
    }

    trimCache(_typeCache);
    trimCache(_nameCache);
    trimCache(_qualifiedNameCache);
    trimCache(_qualifiedNameSubClassCache);
    trimCache(_typedSubClassCache);
    trimCache(_annotatedMethodCache);
    trimCache(_generatedClassCacheByPackageName);
    trimCache(_classDeclarationSubClassCache);
    trimCache(_packagedSubClassLibrariesToSearch);
    linkGenerationInProgress.clear();
  }

  /// Performs a lookup to find a single library by its [identifier], which
  /// can be either a package name or a library URI.
  ///
  /// Returns the matching [_SourceLibrary] instance or `null` if none is found.
  ///
  /// Example:
  /// ```dart
  /// final lib = _performLibraryLookup('my_package');
  /// final sdkLib = _performLibraryLookup('dart:core');
  /// ```
  _SourceLibrary? _performLibraryLookup(String identifier) => _sourceLibraries
    .where((s) => s._package.getName() == identifier || s._uri.toString() == identifier)
    .firstOrNull;

  /// Returns all libraries that belong to the given [packageName].
  ///
  /// This performs a package-scoped lookup, returning a list of all
  /// [_SourceLibrary] instances whose package matches [packageName].
  ///
  /// Example:
  /// ```dart
  /// final libs = _performLibraryLookups('my_package');
  /// for (final lib in libs) {
  ///   print(lib.getUri());
  /// }
  /// ```
  List<_SourceLibrary> _performLibraryLookups(String packageName) => _sourceLibraries
    .where((s) => s._package.getName() == packageName)
    .toList();

  /// Searches all loaded libraries for a declaration with the given simple [name].
  ///
  /// This method iterates through every `_SourceLibrary` in `_sourceLibraries`
  /// and checks the library mirror declarations for a matching symbol. 
  /// Returns the first matching [mirrors.DeclarationMirror], or `null` if none is found.
  ///
  /// Example:
  /// ```dart
  /// final declaration = _performMirrorLookupBySimpleName('MyClass');
  /// if (declaration != null) print(declaration.simpleName);
  /// ```
  mirrors.DeclarationMirror? _performMirrorLookupBySimpleName(String name) {
    final declarations = _sourceLibraries.flatMap((library) => library._libraryMirror.declarations.entries);
  
    for (final library in declarations) {
      if (library.key == Symbol(name)) {
        return library.value;
      }
    }

    return null;
  }

  /// Searches all loaded libraries for a declaration corresponding to a runtime [type].
  ///
  /// Iterates through all `_SourceLibrary` instances and checks each declaration
  /// to see if it is a [mirrors.TypeMirror] with a reflected type equal to [type].
  /// Returns the first match or `null` if none is found.
  ///
  /// Example:
  /// ```dart
  /// final typeMirror = _performMirrorLookupByType(MyClass);
  /// ```
  mirrors.DeclarationMirror? _performMirrorLookupByType(Type type) {
    final declarations = _sourceLibraries.flatMap((library) => library._libraryMirror.declarations.entries);
    for (final library in declarations) {
      final value = library.value;

      if (value case mirrors.TypeMirror typeMirror) {
        if (typeMirror.hasReflectedType && typeMirror.reflectedType == type) {
          return typeMirror;
        }
      }
    }

    return null;
  }

  /// Searches the declarations of a specific [_SourceLibrary] for a simple name [name].
  ///
  /// Only checks the declarations within [sourceLibrary]. Returns the matching
  /// [mirrors.DeclarationMirror], or `null` if none exists.
  ///
  /// Example:
  /// ```dart
  /// final mirror = _performSpecificMirrorLookupBySimpleName('User', mySourceLibrary);
  /// ```
  mirrors.DeclarationMirror? _performSpecificMirrorLookupBySimpleName(String name, _SourceLibrary sourceLibrary) {
    for (final library in sourceLibrary._libraryMirror.declarations.entries) {
      if (library.key == Symbol(name)) {
        return library.value;
      }
    }

    return null;
  }

  /// Searches the declarations of a specific [_SourceLibrary] for a runtime [type].
  ///
  /// Iterates through the declarations of [sourceLibrary] and returns the first
  /// [mirrors.TypeMirror] whose reflected type matches [type], or `null` if none found.
  ///
  /// Example:
  /// ```dart
  /// final mirror = _performSpecificMirrorLookupByType(MyClass, mySourceLibrary);
  /// ```
  mirrors.DeclarationMirror? _performSpecificMirrorLookupByType(Type type, _SourceLibrary sourceLibrary) {
    for (final library in sourceLibrary._libraryMirror.declarations.entries) {
      final value = library.value;

      if (value case mirrors.TypeMirror typeMirror) {
        if (typeMirror.hasReflectedType && typeMirror.reflectedType == type) {
          return typeMirror;
        }
      }
    }

    return null;
  }

  /// Obtains a [mirrors.Mirror] for a given [objectOrType].
  ///
  /// If [objectOrType] is a [Type], attempts to reflect it as a type mirror.
  /// Falls back to `reflectClass` for cases like typedefs, records, or other
  /// special types. If [objectOrType] is a [Function], it reflects the function,
  /// otherwise it reflects a regular object instance.
  ///
  /// Example:
  /// ```dart
  /// final mirror = _getMirror(MyClass);
  /// final instanceMirror = _getMirror(MyClass());
  /// final functionMirror = _getMirror(() => print('hi'));
  /// ```
  mirrors.Mirror _getMirror(dynamic objectOrType) {
    if (objectOrType is Type) {
      try {
        return mirrors.reflectType(objectOrType);
      } catch (_) {
        // fallback for things like typedefs, records, etc
        return mirrors.reflectClass(objectOrType);
      }
    } else if (objectOrType is Function) {
      return mirrors.reflect(objectOrType);
    } else {
      return mirrors.reflect(objectOrType);
    }
  }

  /// Recursively finds all subclasses of a class given its fully qualified name
  /// (and optionally a runtime [Type]).
  ///
  /// This method is **library-scoped** and dependency-aware:
  /// it searches only within libraries that are relevant to the parent class’s
  /// package, avoiding expensive global scans.
  ///
  /// Subclass resolution is performed using lightweight [_ClassReference] objects
  /// and relies on structural relationships rather than materialized declarations.
  ///
  /// ---
  ///
  /// ## Resolution Strategy
  ///
  /// The search considers:
  /// - Direct superclass relationships (`_superClass`)
  /// - Implemented interfaces (`_interfaces`)
  /// - Transitive inheritance chains (recursive DFS)
  ///
  /// The algorithm:
  /// 1. Resolves the parent class reference using [qualifiedName] or [type]
  /// 2. Determines which libraries are eligible based on package dependencies
  /// 3. Performs a depth-first subtype check for each candidate class
  /// 4. Caches results for fast subsequent lookups
  ///
  /// Cyclic inheritance graphs are handled safely using a `visited` set to prevent
  /// infinite recursion.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [qualifiedName]
  ///   Fully qualified name of the parent class
  ///   (e.g. `package:foo/src/base.dart.BaseClass`).
  ///
  /// - [type]
  ///   Optional runtime [Type] used as a fallback if the qualified name lookup fails.
  ///
  /// ---
  ///
  /// ## Yields
  /// - `_ClassReference` instances representing all discovered subclasses
  ///   within eligible libraries.
  ///
  /// ---
  ///
  /// ## Caching
  /// - Results are cached by qualified name
  /// - If [type] is provided, results are also cached by type
  ///
  /// ---
  ///
  /// ## Example
  /// ```dart
  /// final subclasses = _getSubClassReferencesUsingQualifiedName('package:foo/src/base.dart.BaseClass');
  ///
  /// for (final ref in subclasses) {
  ///   print(ref.getQualifiedName());
  /// }
  /// ```
  Iterable<_ClassReference> _getSubClassReferencesUsingQualifiedName(String qualifiedName, [Type? type]) sync* {
    if (_qualifiedNameSubClassCache[qualifiedName] case final references?) {
      yield* references;
      return;
    }

    if (type != null) {
      if (_typedSubClassCache[type] case final references?) {
        yield* references;
        return;
      }
    }

    // Locate the parent class reference and package
    final lookup = _resolveParentReferenceAndPackage(qualifiedName, type);
    if (lookup == null) {
      // Cache empty result
      _qualifiedNameSubClassCache[qualifiedName] = [];
      if (type != null) {
        _typedSubClassCache[type] = [];
      }
      return;
    }

    final (parentRef, parentPackage) = lookup;

    // Use the shared method
    final results = _findSubclasses(parentRef, parentPackage);

    // Cache the results before returning
    _qualifiedNameSubClassCache[qualifiedName] = results;
    if (type != null) {
      _typedSubClassCache[type] = results;
    }

    // Yield the results
    yield* results;
  }

  /// Resolves the **parent class reference** and its **owning package**
  /// from a fully qualified class name and optional runtime [Type].
  ///
  /// This method acts as a normalization step for subclass discovery by:
  /// - Locating the `_ClassReference` that represents the requested parent class
  /// - Determining the package in which that class is defined
  ///
  /// The lookup is performed in a **library-scoped** manner to avoid
  /// expensive global scans:
  /// - If the qualified name represents a library itself, all source libraries
  ///   are searched until a match is found
  /// - Otherwise, the search is restricted to the extracted library URI
  ///
  /// If the class reference is found but the package cannot be inferred
  /// from the source library, a fallback package is created using
  /// [_findPackage].
  ///
  /// ---
  ///
  /// ### Parameters
  /// - [qualifiedName]: Fully qualified class name
  ///   (e.g. `package:foo/src/MyClass`)
  /// - [type]: Optional runtime `Type` used as a fallback resolution key
  ///
  /// ### Returns
  /// - A tuple containing:
  ///   - `_ClassReference`: the resolved parent class
  ///   - `Package`: the package that owns the class
  ///
  /// Returns `null` if the parent class cannot be resolved.
  ///
  /// ---
  ///
  /// ### Usage
  /// This helper is primarily used as a prerequisite for
  /// subclass discovery and type hierarchy analysis.
  (_ClassReference, Package)? _resolveParentReferenceAndPackage(String qualifiedName, [Type? type]) {
    _ClassReference? parentRef;
    Package? parentPackage;
    final libraryUri = ReflectionUtils.extractLibraryUri(qualifiedName);

    if (qualifiedName == libraryUri) {
      for (final source in _sourceLibraries) {
        if (_findReference(source, qualifiedName, type) case final reference?) {
          parentRef = reference;
          parentPackage = source._package;
          break;
        }
      }
    } else {
      if (_performLibraryLookup(libraryUri) case final source?) {
        if (_findReference(source, qualifiedName, type) case final reference?) {
          parentRef = reference;
          parentPackage = source._package;
        }
      }
    }

    parentPackage ??= _findPackage(libraryUri);
    if (parentRef == null) return null;

    return (parentRef, parentPackage);
  }

  /// Returns all subclasses of the given [parentReference] that are visible
  /// within the dependency scope of the provided [package].
  ///
  /// This method:
  /// - Acts as a **cached wrapper** around the core subclass search logic
  /// - Prevents repeated deep scans for the same parent class
  /// - Yields results lazily via a synchronous generator
  ///
  /// Results are cached using the parent class’s qualified name as the key.
  ///
  /// ---
  ///
  /// ### Parameters
  /// - [parentReference]: The parent class whose subclasses are requested
  /// - [package]: The package that owns the parent class
  ///
  /// ### Yields
  /// - `_ClassReference` instances representing discovered subclasses
  ///
  /// ---
  ///
  /// ### Caching Behavior
  /// - Results are memoized in `_qualifiedNameSubClassCache`
  /// - Subsequent calls with the same parent class are O(1)
  // Iterable<_ClassReference> _getSubClassReferences(_ClassReference parentReference, Package package) sync* {
  //   final cacheKey = parentReference._qualifiedName;
  
  //   if (_qualifiedNameSubClassCache[cacheKey] case final references?) {
  //     yield* references;
  //     return;
  //   }

  //   final results = _findSubclasses(parentReference, package);
  //   _qualifiedNameSubClassCache[cacheKey] = results;
    
  //   yield* results;
  // }

  /// Performs the **core subclass discovery logic** for a given parent class.
  ///
  /// This method executes a dependency-aware, library-scoped search by:
  /// - Identifying which source libraries should be scanned based on
  ///   package dependency relationships
  /// - Iterating over known class references only within those libraries
  /// - Performing recursive subtype checks using DFS
  ///
  /// Direct superclass relationships, implemented interfaces, and
  /// transitive inheritance chains are all considered.
  ///
  /// Cyclic inheritance is handled safely via a per-check visited set.
  ///
  /// ---
  ///
  /// ### Parameters
  /// - [parentRef]: The parent class reference
  /// - [parentPackage]: The package that owns the parent class
  ///
  /// ### Returns
  /// - A list of `_ClassReference` objects representing all discovered subclasses
  ///
  /// ---
  ///
  /// ### Notes
  /// - The parent class itself is always excluded from the result
  /// - Matching is performed using qualified name comparison or
  ///   non-generic type equality
  /// - This method does **not** perform caching; callers are responsible
  ///   for memoization
  List<_ClassReference> _findSubclasses(_ClassReference parentRef, Package parentPackage) {
    final results = <_ClassReference>[];

    // Determine which libraries to search based on package dependencies
    final librariesToSearch = _getLibrariesToSearch(parentPackage);

    // Check classes only in relevant libraries
    for (final clazz in librariesToSearch.flatMap((src) => src._classReferences)) {
      // Skip the parent class itself
      if (clazz == parentRef || _referenceMatches(clazz, parentRef)) {
        continue;
      }
      
      // Create a new visited set for each class check
      final visited = <String>{};
      if (_isSubtypeOf(clazz, parentRef, visited)) {
        results.add(clazz);
      }
    }

    return results;
  }

  /// Compares two class references for identity equivalence.
  ///
  /// Two references are considered matching if:
  /// - Their qualified names are identical, **or**
  /// - Their runtime [Type] objects are equal **and**
  ///   neither type is generic
  ///
  /// This allows stable matching across mirrored and resolved
  /// type representations.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [first]: First class reference.
  /// - [second]: Second class reference.
  ///
  /// ## Returns
  /// - `true` if the references represent the same class.
  bool _referenceMatches(_ClassReference first, _ClassReference second) =>
      first._qualifiedName == second._qualifiedName ||
      (first._type == second._type &&
          !GenericTypeParser.isMirrored(first._type.toString()) &&
          !GenericTypeParser.isMirrored(second._type.toString()));

  /// Performs a recursive depth-first search to determine whether [clazz]
  /// is a subtype of [parent].
  ///
  /// This method traverses:
  /// - The direct superclass chain
  /// - All implemented interfaces
  ///
  /// A `visited` set is used to prevent infinite recursion in the presence
  /// of cyclic inheritance graphs.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [clazz]: Candidate class being tested.
  /// - [parent]: Target superclass or interface.
  /// - [visited]: Set of visited qualified names for cycle detection.
  ///
  /// ## Returns
  /// - `true` if [clazz] is a subtype of [parent], otherwise `false`.
  bool _isSubtypeOf(_ClassReference clazz, _ClassReference parent, Set<String> visited) {
    if (visited.contains(clazz._qualifiedName)) return false;
    visited.add(clazz._qualifiedName);

    // Direct superclass match
    if (clazz._superClass case final superClass?) {
      if (_referenceMatches(superClass, parent)) return true;
      if (_isSubtypeOf(superClass, parent, visited)) return true;
    }

    // Check all interfaces
    for (final interface in clazz._interfaces) {
      if (_referenceMatches(interface, parent)) return true;
      if (_isSubtypeOf(interface, parent, visited)) return true;
    }

    return false;
  }

  /// Attempts to locate a class reference inside a given [_SourceLibrary].
  ///
  /// The lookup is performed in the following order:
  /// 1. By fully qualified name
  /// 2. By runtime [Type] (if provided)
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [source]: The source library to search within.
  /// - [qualifiedName]: Fully qualified class name.
  /// - [type]: Optional runtime type fallback.
  ///
  /// ## Returns
  /// - The matching [_ClassReference], or `null` if not found.
  _ClassReference? _findReference(_SourceLibrary source, String qualifiedName, Type? type) {
    if (source.findClass(qualifiedName) case final reference?) {
      return reference;
    } else if (type != null) {
      if (source.findClassByType(type) case final reference?) {
        return reference;
      }
    }

    return null;
  }

  /// Determines which source libraries should be searched when resolving
  /// subclasses of a class that belongs to the given [parentPackage].
  ///
  /// This method enforces **package-aware search boundaries** to avoid
  /// unnecessary global scans while still guaranteeing correctness across
  /// dependency graphs.
  ///
  /// ---
  ///
  /// ## Search Rules
  ///
  /// The returned libraries are selected according to the following logic:
  ///
  /// ### 1. Dart SDK classes
  /// If [parentPackage] is `null` or represents the Dart SDK
  /// (`dart:*` libraries), **all source libraries** are searched.
  ///
  /// This is required because SDK types may be extended or implemented
  /// anywhere in the application or dependency graph.
  ///
  /// ### 2. Cached package resolution
  /// If the libraries-to-search set has already been computed for the
  /// given package name, the cached result is returned immediately.
  /// This ensures repeated subclass lookups are **O(1)**.
  ///
  /// ### 3. Package-scoped dependency resolution
  /// Otherwise, each source library is evaluated:
  ///
  /// A library is included if **any** of the following conditions hold:
  /// - It belongs to the same package as the parent class
  /// - Its package declares a **direct dependency** on the parent package
  /// - Its package declares a **dev dependency** on the parent package
  /// - Its package name starts with `"file://"` (local or dynamically
  ///   loaded source libraries)
  ///
  /// This ensures subclasses are discovered across:
  /// - Same-package inheritance
  /// - Cross-package extension via dependencies
  /// - Local development or dynamically loaded code
  ///
  /// ---
  ///
  /// ## Caching Behavior
  ///
  /// The computed list is cached in `_packagedSubClassLibrariesToSearch`
  /// using the parent package name as the key. This avoids repeating
  /// dependency graph analysis on subsequent lookups.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [parentPackage]: The package that owns the parent class
  ///
  /// ## Returns
  /// - A list of `_SourceLibrary` instances that are eligible to contain
  ///   subclasses of the parent class
  List<_SourceLibrary> _getLibrariesToSearch(Package? parentPackage) {
    // If parent is from Dart SDK, search all libraries
    if (parentPackage == null || parentPackage.getName() == Constant.DART_PACKAGE_NAME) {
      return _sourceLibraries;
    }

    if (_packagedSubClassLibrariesToSearch[parentPackage.getName()] case final libraries?) {
      return libraries;
    }

    final parentPackageName = parentPackage.getName();
    final librariesToSearch = <_SourceLibrary>[];

    for (final source in _sourceLibraries) {
      final sourcePackage = source._package;
      
      // Check if source package is the same as parent package
      if (sourcePackage.getName() == parentPackageName) {
        librariesToSearch.add(source);
        continue;
      }
      
      // Check if source package has parent package in its dependencies
      final hasDirect = sourcePackage.getDependencies().contains(parentPackageName);
      
      // Check if source package has parent package in its dev dependencies
      final hasDev = sourcePackage.getDevDependencies().contains(parentPackageName);
      
      if (hasDirect || hasDev || sourcePackage.getName().startsWith("file://")) {
        librariesToSearch.add(source);
      }
    }

    _packagedSubClassLibrariesToSearch[parentPackage.getName()] = librariesToSearch;
    return librariesToSearch;
  }

  /// Resolves the [Package] associated with a given library or package [uri].
  ///
  /// This method attempts to locate a previously scanned [_SourceLibrary]
  /// corresponding to the provided [uri]. If a matching source library
  /// is found, its owning package is returned.
  ///
  /// If no source library exists for the given [uri], a **default package**
  /// is synthesized using [createDefaultPackage].
  ///
  /// ---
  ///
  /// ## Purpose
  /// - Provide a consistent way to map library URIs to packages
  /// - Ensure package resolution never returns `null`
  /// - Support SDK, third-party, and dynamically discovered libraries
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [uri]: A library or package URI (e.g. `package:foo/bar.dart`, `dart:core`)
  ///
  /// ## Returns
  /// - The resolved [Package] instance, or a default package if none was found
  Package _findPackage(String uri) {
    if (_performLibraryLookup(uri) case final source?) {
      return source._package;
    }

    return createDefaultPackage(uri);
  }

  /// Attempts to retrieve a previously materialized [ClassDeclaration]
  /// from the **qualified-name cache**.
  ///
  /// This cache maps fully qualified class names to their corresponding
  /// declarations and is the fastest lookup path during class resolution.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [qualifiedName]: Fully qualified class name
  ///   (e.g. `package:foo/bar.dart.MyClass`)
  ///
  /// ## Returns
  /// - The cached [ClassDeclaration] if present, otherwise `null`
  ClassDeclaration? _findInQualifiedNameCache(String qualifiedName) => _qualifiedNameCache[qualifiedName];

  /// Attempts to retrieve a previously materialized [ClassDeclaration]
  /// from the **runtime type cache**.
  ///
  /// This cache maps Dart runtime [Type] objects to their resolved
  /// class declarations, allowing fast lookup when working with
  /// reflected or instantiated objects.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [type]: The Dart runtime type to look up
  ///
  /// ## Returns
  /// - The cached [ClassDeclaration] if present, otherwise `null`
  ClassDeclaration? _findInTypeCache(Type type) => _typeCache[type];

  /// Fetches an existing [ClassDeclaration] from cache or **generates**
  /// a new one from a Dart mirror.
  ///
  /// This method is the **core materialization engine** of JetLeaf.
  /// It converts Dart mirrors into stable, cached [ClassDeclaration]
  /// objects while ensuring:
  ///
  /// - Identity stability
  /// - Generic type resolution
  /// - Proper handling of closures and instances
  /// - Cache reuse to avoid duplication
  ///
  /// ---
  ///
  /// ## Supported Mirror Types
  ///
  /// This method handles:
  /// - [mirrors.ClosureMirror] → Generates a synthetic closure class
  /// - [mirrors.InstanceMirror] → Resolves its underlying class
  /// - [mirrors.ClassMirror] → Generates or fetches a concrete class
  /// - [mirrors.TypeMirror] → Fallback for unresolved or synthetic types
  ///
  /// ---
  ///
  /// ## Caching Strategy
  /// - Qualified-name cache is checked first
  /// - Runtime type cache is checked second
  /// - Generic resolution is attempted before generation
  /// - Newly generated classes are cached before returning
  ///
  /// ---
  ///
  /// ## Parameters
  /// - [mirror]: Any supported Dart mirror representing a runtime entity
  /// - [libraryUri]: The library URI used as resolution context
  /// - [sourceCode]: Optional source code used for modifier detection
  ///
  /// ## Returns
  /// - A fully materialized [ClassDeclaration]
  ///
  /// ## Throws
  /// - [ImmaterialClassException] if the class cannot be resolved into
  ///   a concrete runtime declaration
  ClassDeclaration _fetchOrGenerate(mirrors.Mirror mirror, Uri libraryUri, [String? sourceCode]) {
    ClassDeclaration result;

    if (mirror case mirrors.ClosureMirror mirror) { // --- Closure handling -----------------------------------------------------
      final classMirror = mirror.type;
      final resolvedUri = findRealClassUriFromMirror(classMirror) ?? libraryUri;
      final generatedClass = _fetchOrGenerate(classMirror, resolvedUri);
      final function = generateMethod(mirror.function, null, resolvedUri.toString(), resolvedUri, "Closure", null);

      result = StandardClosureDeclaration(function: function, classDeclaration: generatedClass);
    } else if (mirror case mirrors.InstanceMirror mirror) { // --- Instance handling ----------------------------------------------------
      final classMirror = mirror.type;
      final resolvedUri = findRealClassUriFromMirror(classMirror) ?? libraryUri;
      result = _fetchOrGenerate(classMirror, resolvedUri);
    } else if (mirror case mirrors.ClassMirror classMirror) { // --- Class handling -------------------------------------------------------
      final resolvedLibraryUri = findRealClassUriFromMirror(classMirror) ?? libraryUri;
      final typeName = mirrors.MirrorSystem.getName(classMirror.simpleName);
      final type = classMirror.runtimeType;

      if (_findInQualifiedNameCache(ReflectionUtils.buildQualifiedName(typeName, resolvedLibraryUri.toString())) case final classDeclaration?) {
        return classDeclaration;
      }

      // Check reflected type
      if (classMirror.hasReflectedType) {
        if (_findInTypeCache(classMirror.reflectedType) case final classDeclaration?) {
          return classDeclaration;
        }
      }

      // Try typed resolution
      if (GenericTypeParser.isMirrored(type.toString())) {
        final resolved = resolveGenericAnnotationIfNeeded(type, classMirror, resolvedLibraryUri.toString(), resolvedLibraryUri, typeName);

        if (resolved != type) {
          if (_findInTypeCache(resolved) case final classDeclaration?) {
            return classDeclaration;
          }
        }
      }

      result = generateClass(classMirror, resolvedLibraryUri.toString(), resolvedLibraryUri, isBuiltInDartLibrary(resolvedLibraryUri));
    } else { // --- TypeMirror fallback --------------------------------------------------
      final typeMirror = mirror as mirrors.TypeMirror;
      final resolvedUri = findRealClassUriFromMirror(typeMirror) ?? libraryUri;
      final className = mirrors.MirrorSystem.getName(typeMirror.simpleName);
      final qualifiedName = buildQualifiedName(className, resolvedUri.toString());

      if (_findInQualifiedNameCache(qualifiedName) case final classDeclaration?) {
        return classDeclaration;
      }

      Type type = typeMirror.hasReflectedType ? typeMirror.reflectedType : typeMirror.runtimeType;
      type = resolveGenericAnnotationIfNeeded(type, typeMirror, resolvedUri.toString(), resolvedUri, className);

      // Try typed resolution
      if (!GenericTypeParser.isMirrored(type.toString())) {
        if (_findInTypeCache(type) case final classDeclaration?) {
          return classDeclaration;
        }
      }

      final analyzedClass = getAnalyzedClassDeclaration(className, resolvedUri);

      result = StandardClassDeclaration(
        name: className,
        type: type,
        qualifiedName: qualifiedName,
        library: getLibrary(resolvedUri.toString()),
        typeArguments: extractTypeVariableAsLinks(typeMirror.typeVariables, analyzedClass?.typeParameters, resolvedUri.toString()),
        annotations: extractAnnotations(typeMirror.metadata, resolvedUri.toString(), resolvedUri),
        sourceLocation: resolvedUri,
        superClass: null,
        interfaces: [],
        mixins: [],
        isAbstract: false,
        isMixin: analyzedClass?.mixinKeyword != null || isMixinClass(sourceCode, className),
        isSealed: analyzedClass?.sealedKeyword != null || isSealedClass(sourceCode, className),
        isBase: analyzedClass?.baseKeyword != null || isBaseClass(sourceCode, className),
        isInterface: analyzedClass?.interfaceKeyword != null || isInterfaceClass(sourceCode, className),
        isFinal: analyzedClass?.finalKeyword != null || isFinalClass(sourceCode, className),
        isPublic: !isInternal(className),
        isSynthetic: analyzedClass?.isSynthetic ?? isSynthetic(className),
        isRecord: false,
      );
    }

    // --- Cache population -----------------------------------------------------
    _qualifiedNameCache[result.getQualifiedName()] = result;
    if (!GenericTypeParser.isMirrored(result.getType().toString())) _typeCache[result.getType()] = result;

    return result;
  }

  /// Builds a [ClassDeclaration] from a [mirrors.Mirror] and caches it in [cache].
  ///
  /// If [library] is provided, uses its metadata to generate the class declaration.
  /// Supports both [mirrors.ClassMirror] and [mirrors.FunctionTypeMirror]. Caches
  /// the resulting [ClassDeclaration] using [key].
  ///
  /// Example:
  /// ```dart
  /// final classDecl = _buildClassDeclaration<MyClass>(
  ///   mirror,
  ///   _typeCache,
  ///   MyClass,
  ///   mySourceLibrary,
  /// );
  /// ```
  ClassDeclaration _buildClassDeclaration<K>(mirrors.Mirror mirror, [_SourceLibrary? library, Type? type]) {
    if (mirror case mirrors.InstanceMirror mirror) {
      if (findRealClassUriFromMirror(mirror.type) case final location?) {
        final name = mirrors.MirrorSystem.getName(mirror.type.simpleName);
        final qualifiedName = ReflectionUtils.buildQualifiedName(name, location.toString());
        if (_findInQualifiedNameCache(qualifiedName) case final cache?) {
          return cache;
        }
      }
    } else if (mirror case mirrors.TypeMirror mirror) {
      if (findRealClassUriFromMirror(mirror) case final location?) {
        final name = mirrors.MirrorSystem.getName(mirror.simpleName);
        final qualifiedName = ReflectionUtils.buildQualifiedName(name, location.toString());
        if (_findInQualifiedNameCache(qualifiedName) case final cache?) {
          return cache;
        }
      }
    }

    if (library case final library?) {
      return _fetchOrGenerate(mirror, library._uri, library._sourceCode);
    } else {
      return _fetchOrGenerate(mirror, library?._uri ?? Dynamic.getUri(), library?._sourceCode);
    }
  }

  /// Parses a [GenericTypeParsingResult] and converts all contained generic
  /// types into [ClassDeclaration] instances.
  ///
  /// This method iterates through each generic type in [result.types] and uses
  /// [_convertGenericResultToTypeDeclaration] to resolve it into a usable
  /// [ClassDeclaration]. Non-resolvable types are skipped.
  ///
  /// Example:
  /// ```dart
  /// final parsed = GenericTypeParser.resolveGenericType("List<String>");
  /// final typeDeclarations = _parseGenericTypes(parsed);
  /// for (final typeDecl in typeDeclarations) {
  ///   print(typeDecl.getName());
  /// }
  /// ```
  List<ClassDeclaration> _parseGenericTypes(GenericTypeParsingResult result, [Type? type]) {
    final types = <ClassDeclaration>[];
    
    for (final genericType in result.types) {
      final typeDecl = _convertGenericResultToTypeDeclaration(genericType, type);
      if (typeDecl != null) {
        types.add(typeDecl);
      }
    }
    
    return types;
  }

  /// Converts a single [GenericTypeParsingResult] into a [ClassDeclaration].
  ///
  /// If [result] contains no generic parameters, it resolves the base type by
  /// name using [findClassByName]. If generics are present, it recursively
  /// resolves the full generic type using [_findGenericClass].
  ///
  /// Example:
  /// ```dart
  /// final result = GenericTypeParser.resolveGenericType("Map<String, int>");
  /// final classDecl = _convertGenericResultToTypeDeclaration(result);
  /// print(classDecl?.getName());
  /// ```
  ClassDeclaration? _convertGenericResultToTypeDeclaration(GenericTypeParsingResult result, [Type? type]) {
    if (result.types.isEmpty) {
      // Non-generic type, find by name
      return findClassByName(result.base);
    } else {
      // Generic type, recursively resolve
      return _findGenericClass(result.typeString, type);
    }
  }

  /// Resolves a generic class type at runtime, creating a fully qualified
  /// [ClassDeclaration] including its generic type parameters.
  ///
  /// This method parses the provided [typeString] (e.g., `"List<String>"`) and
  /// handles special naming caveats defined in [_caveats]. It then resolves the
  /// base class and recursively resolves all generic type arguments.
  ///
  /// If any generic type arguments exist, an enhanced generic
  /// [ClassDeclaration] is created via [_createGenericClassDeclaration].
  ///
  /// Example:
  /// ```dart
  /// final clazz = _findGenericClass("Map<String, int>");
  /// print(clazz.getName()); // "Map<String, int>"
  /// ``` 
  ClassDeclaration _findGenericClass(String typeString, [Type? type, String? package]) {
   final parseResult = GenericTypeParser.resolveGenericType(typeString);

    // Handle caveats for base name
    String baseName = parseResult.base;
    if(_caveats.any((c) => c == baseName)) {
      baseName = baseName.replaceAll("_", "");
    }

    final baseDeclaration = findClassByName(baseName, package);

    // Convert GenericParsingResult types to TypeDeclarations
    final genericTypes = _parseGenericTypes(parseResult, type);
    
    if (genericTypes.isNotEmpty) {
      // Create enhanced declaration with generic information
      return _createGenericClassDeclaration(baseDeclaration, genericTypes, typeString, type);
    }
    
    return baseDeclaration;
  }

  /// Creates a fully resolved [ClassDeclaration] for a generic type, preserving
  /// its base class and type arguments.
  ///
  /// This method generates a new class declaration that includes the generic
  /// type parameters provided in [types]. It handles different kinds of
  /// base declarations such as [MixinDeclaration], [EnumDeclaration], or
  /// standard classes. The resulting declaration preserves all metadata from
  /// the original base declaration, including methods, fields, annotations,
  /// and source location.
  ///
  /// [base] is the non-generic class to enhance.
  /// [types] is the list of generic type arguments as [ClassDeclaration] instances.
  /// [fullTypeName] is the complete type string including generics.
  ///
  /// Example:
  /// ```dart
  /// final base = library.findClassByName('Map');
  /// final stringType = library.findClassByName('String');
  /// final intType = library.findClassByName('int');
  /// final genericClass = _createGenericClassDeclaration(base, [stringType, intType], 'Map<String, int>');
  /// print(genericClass.getName()); // "Map<String, int>"
  /// ``` 
  ClassDeclaration _createGenericClassDeclaration(ClassDeclaration base, List<ClassDeclaration> types, String fullTypeName, [Type? type]) {
    final genericLinks = types.map((type) => 
      StandardLinkDeclaration(
        name: type.getName(),
        type: type.getType(),
        pointerType: type.getType(),
        qualifiedName: type.getQualifiedName(),
        canonicalUri: Uri.parse(type.getPackageUri()),
        referenceUri: Uri.parse(type.getPackageUri()),
        typeArguments: type.getTypeArguments(),
        isPublic: type.getIsPublic(),
        isSynthetic: type.getIsSynthetic(),
      )
    ).toList();
    final classMirror = type != null ? mirrors.reflectClass(type) : null;
    final analyzed = getAnalyzedClassDeclaration(base.getName(), Uri.parse(base.getPackageUri()));
    final analyzedMixin = getAnalyzedMixinDeclaration(base.getName(), Uri.parse(base.getPackageUri()));
    
    final interfaces = classMirror != null
      ? extractInterfacesAsLink(classMirror, analyzed?.implementsClause, base.getPackageUri())
      : base.getInterfaces();
    
    final mixins = classMirror != null
      ? extractMixinsAsLink(classMirror, analyzed?.withClause, base.getPackageUri())
      : base.getMixins();
    
    final superClass = classMirror != null
      ? extractSupertypeAsLink(classMirror, analyzed?.extendsClause, base.getPackageUri())
      : base.getSuperClass();
    
    final constraints = classMirror != null
      ? extractMixinConstraintsAsLink(classMirror, analyzedMixin?.onClause, base.getPackageUri())
      : base is MixinDeclaration ? base.getConstraints() : <LinkDeclaration>[];
    
    final annotations = classMirror != null
      ? extractAnnotations(classMirror.metadata, base.getPackageUri(), Uri.parse(base.getPackageUri()))
      : base.getAnnotations();

    if(base is MixinDeclaration) {
      return StandardMixinDeclaration(
        name: fullTypeName,
        library: base.getLibrary(),
        type: base.getType(), // Keep base type for compatibility
        qualifiedName: base.getQualifiedName(),
        typeArguments: genericLinks,
        superClass: superClass ?? base.getSuperClass(),
        interfaces: interfaces,
        methods: base.getMethods(),
        fields: base.getFields(),
        constraints: constraints,
        annotations: annotations,
        sourceLocation: base.getSourceLocation(),
        isPublic: base.getIsPublic(),
        isSynthetic: base.getIsSynthetic(),
      );
    } else if(base is EnumDeclaration) {
      return StandardEnumDeclaration(
        values: base.getValues(),
        name: fullTypeName,
        library: base.getLibrary(),
        type: base.getType(), // Keep base type for compatibility
        qualifiedName: base.getQualifiedName(),
        typeArguments: genericLinks,
        isAbstract: base.getIsAbstract(),
        isBase: base.getIsBase(),
        isFinal: base.getIsFinal(),
        isInterface: base.getIsInterface(),
        isMixin: base.getIsMixin(),
        isRecord: base.getIsRecord(),
        superClass: superClass ?? base.getSuperClass(),
        interfaces: interfaces,
        mixins: mixins,
        constructors: base.getConstructors(),
        methods: base.getMethods(),
        fields: base.getFields(),
        annotations: annotations,
        sourceLocation: base.getSourceLocation(),
        isPublic: base.getIsPublic(),
        isSynthetic: base.getIsSynthetic(),
      );
    }

    return StandardClassDeclaration(
      name: fullTypeName,
      library: base.getLibrary(),
      type: base.getType(), // Keep base type for compatibility
      qualifiedName: base.getQualifiedName(),
      typeArguments: genericLinks,
      isAbstract: base.getIsAbstract(),
      isBase: base.getIsBase(),
      isFinal: base.getIsFinal(),
      isInterface: base.getIsInterface(),
      isMixin: base.getIsMixin(),
      isRecord: base.getIsRecord(),
      superClass: superClass ?? base.getSuperClass(),
      interfaces: interfaces,
      mixins: mixins,
      constructors: base.getConstructors(),
      methods: base.getMethods(),
      fields: base.getFields(),
      annotations: annotations,
      sourceLocation: base.getSourceLocation(),
      isPublic: base.getIsPublic(),
      isSynthetic: base.getIsSynthetic(),
    );
  }
}