part of 'declaration.dart';

/// {@template library}
/// Represents a Dart library, providing access to its URI, the
/// containing package, and all top-level declarations inside it.
///
/// Libraries in Dart map directly to `.dart` files and can expose
/// multiple classes, functions, and constants.
///
/// ### Example
/// ```dart
/// final library = reflector.getLibraries().firstWhere(
///   (lib) => lib.getUri().contains('my_library.dart'),
/// );
/// print(library.getParentPackage().getName());
/// for (final decl in library.getDeclarations()) {
///   print(decl.getName());
/// }
/// ```
/// {@endtemplate}
abstract class LibraryDeclaration extends SourceDeclaration {
  /// {@macro library}
  const LibraryDeclaration();

  /// Returns the URI of the library.
  ///
  /// The URI is typically a string representing the library location
  /// in either a package or file context.
  ///
  /// ### Example
  /// ```dart
  /// final uri = myLibrary.getUri();
  /// print(uri); // e.g., "package:my_app/main.dart"
  /// ```
  String getUri();

  /// Returns the [Package] that contains this library.
  ///
  /// This allows resolving relative URIs and accessing package-specific
  /// configuration, dependencies, or metadata.
  ///
  /// ### Example
  /// ```dart
  /// final pkg = myLibrary.getPackage();
  /// print(pkg.getName()); // "my_app"
  /// ```
  Package getPackage();

  /// Returns all top-level declarations in this library.
  ///
  /// This includes classes, enums, typedefs, top-level functions, fields,
  /// and records.
  ///
  /// ### Example
  /// ```dart
  /// for (final decl in myLibrary.getDeclarations()) {
  ///   print(decl.getName());
  /// }
  /// ```
  List<SourceDeclaration> getDeclarations();

  /// Returns all classes declared directly in this library.
  ///
  /// Inherited classes or imported classes are excluded.
  ///
  /// ### Example
  /// ```dart
  /// final classes = myLibrary.getClasses();
  /// classes.forEach((c) => print(c.getName()));
  /// ```
  List<ClassDeclaration> getClasses();

  /// Returns all enums declared directly in this library.
  ///
  /// ### Example
  /// ```dart
  /// final enums = myLibrary.getEnums();
  /// enums.forEach((e) => print(e.getName()));
  /// ```
  List<EnumDeclaration> getEnums();

  /// Returns all typedefs declared directly in this library.
  ///
  /// Useful for resolving function type aliases or generic type aliases.
  ///
  /// ### Example
  /// ```dart
  /// final typedefs = myLibrary.getTypedefs();
  /// typedefs.forEach((t) => print(t.getName()));
  /// ```
  List<TypedefDeclaration> getTypedefs();

  /// Returns all top-level methods declared in this library.
  ///
  /// Excludes class or mixin methods; only top-level functions are included.
  ///
  /// ### Example
  /// ```dart
  /// final methods = myLibrary.getTopLevelMethods();
  /// methods.forEach((m) => print(m.getName()));
  /// ```
  List<MethodDeclaration> getTopLevelMethods();

  /// Returns all top-level fields declared in this library.
  ///
  /// This includes constants, variables, and potentially record fields
  /// if declared at the top level.
  ///
  /// ### Example
  /// ```dart
  /// final fields = myLibrary.getTopLevelFields();
  /// fields.forEach((f) => print(f.getName()));
  /// ```
  List<FieldDeclaration> getTopLevelFields();

  /// Returns all top-level records declared in this library.
  ///
  /// Records are Dart 3+ structured types that can contain positional
  /// and named elements.
  ///
  /// ### Example
  /// ```dart
  /// final records = myLibrary.getTopLevelRecords();
  /// records.forEach((r) => print(r.getName()));
  /// ```
  List<RecordLinkDeclaration> getTopLevelRecords();

  @override
  String getName() => getUri(); // Libraries typically use their URI as their identifier.
}