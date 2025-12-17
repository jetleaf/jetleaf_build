part of 'declaration.dart';

/// {@template class}
/// Represents a reflected Dart class and all of its metadata, including
/// fields, methods, constructors, superclasses, mixins, interfaces, and
/// declaration-level modifiers (abstract, sealed, etc.).
///
/// This interface combines both [SourceDeclaration] and [TypeDeclaration],
/// allowing it to be used both as a type descriptor and a declaration node.
///
/// Use this class to introspect:
/// - Class members: fields, methods, constructors
/// - Generic type parameters
/// - Supertype, mixins, and implemented interfaces
/// - Modifiers like `abstract`, `sealed`, `base`, etc.
/// - Runtime instantiation via `newInstance()`
///
/// ### Example
/// ```dart
/// final type = reflector.reflectType(MyService).asClassType();
/// print('Class: ${type?.getName()}');
///
/// for (final method in type!.getMethods()) {
///   print('Method: ${method.getName()}');
/// }
///
/// final instance = type.newInstance({'message': 'Hello'});
/// ```
/// {@endtemplate}
abstract class ClassDeclaration extends TypeDeclaration implements SourceDeclaration {
  /// {@macro class}
  const ClassDeclaration();

  /// Returns all members declared in this class, including fields, methods, and constructors.
  ///
  /// This method provides a comprehensive view of the class structure
  /// without including inherited members. Useful for code analysis,
  /// generation, or runtime introspection.
  ///
  /// Members include:
  /// - [FieldDeclaration] objects for each field
  /// - [MethodDeclaration] objects for each method
  /// - [ConstructorDeclaration] objects for each constructor
  ///
  /// ### Example
  /// ```dart
  /// for (final member in clazz.getMembers()) {
  ///   print('${member.getName()} (${member.runtimeType})');
  /// }
  /// ```
  ///
  /// Returns an empty list if the class has no declared members.
  List<MemberDeclaration> getMembers();

  /// Returns all constructors declared in this class.
  ///
  /// Each constructor can be inspected for:
  /// - Name (unnamed or named)
  /// - Parameters ([ParameterDeclaration])
  /// - Modifiers like `const`, `factory`, or `external`
  ///
  /// ### Example
  /// ```dart
  /// for (final ctor in clazz.getConstructors()) {
  ///   print(ctor.getName());
  /// }
  /// ```
  ///
  /// Returns an empty list if the class has no constructors.
  List<ConstructorDeclaration> getConstructors();

  /// Returns all fields declared in this class, excluding inherited fields.
  ///
  /// Fields include both instance and static fields.
  /// Each field can be inspected via [FieldDeclaration] to check
  /// its type, nullability, and modifiers (`final`, `const`, `late`, `static`).
  ///
  /// ### Example
  /// ```dart
  /// for (final field in clazz.getFields()) {
  ///   print('${field.getName()} : ${field.getLinkDeclaration().getName()}');
  /// }
  /// ```
  List<FieldDeclaration> getFields();

  /// Returns all static fields declared in this class or mixin.
  ///
  /// Static fields are those declared with the `static` keyword.
  /// Each returned [FieldDeclaration] provides access to type, value,
  /// and metadata.
  ///
  /// ### Example
  /// ```dart
  /// for (final field in clazz.getStaticFields()) {
  ///   print('${field.getName()} : ${field.getLinkDeclaration().getName()}');
  /// }
  /// ```
  List<FieldDeclaration> getStaticFields();

  /// Returns all instance fields declared in this class or mixin.
  ///
  /// Excludes static fields and inherited fields.
  /// Useful for runtime introspection or code generation targeting
  /// instance-specific properties.
  ///
  /// ### Example
  /// ```dart
  /// for (final field in clazz.getInstanceFields()) {
  ///   print('${field.getName()} : ${field.getLinkDeclaration().getName()}');
  /// }
  /// ```
  List<FieldDeclaration> getInstanceFields();

  /// Returns a field by its [fieldName], or `null` if no field with that name exists.
  ///
  /// Can be used to access the field type, value, or metadata dynamically.
  ///
  /// ### Example
  /// ```dart
  /// final nameField = clazz.getField('name');
  /// if (nameField != null) {
  ///   print(nameField.getLinkDeclaration().getName()); // String
  /// }
  /// ```
  FieldDeclaration? getField(String fieldName);

  /// Checks if this class or mixin declares a field with the given [fieldName].
  ///
  /// Returns `true` if a field exists, `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// if (clazz.hasField('id')) {
  ///   print('Field "id" exists');
  /// }
  /// ```
  bool hasField(String fieldName);

  /// Returns all methods declared in this class, excluding inherited methods.
  ///
  /// Methods include instance and static methods, as well as getters and setters.
  /// Each method can be inspected via [MethodDeclaration] for return type,
  /// parameters, and invocation.
  ///
  /// ### Example
  /// ```dart
  /// for (final method in clazz.getMethods()) {
  ///   print('${method.getName()} returns ${method.getReturnType().getName()}');
  /// }
  /// ```
  ///
  /// Returns an empty list if the class has no declared methods.
  List<MethodDeclaration> getMethods();

  /// Returns all static methods declared in this class or mixin.
  ///
  /// Static methods are declared with the `static` keyword and do not
  /// require an instance to invoke. Each [MethodDeclaration] provides
  /// metadata about parameters, return type, and modifiers.
  ///
  /// ### Example
  /// ```dart
  /// for (final method in clazz.getStaticMethods()) {
  ///   print('${method.getName()} : ${method.getReturnType().getName()}');
  /// }
  /// ```
  List<MethodDeclaration> getStaticMethods();

  /// Returns all instance methods declared in this class or mixin.
  ///
  /// Excludes static methods and inherited methods. Useful for runtime
  /// inspection or code generation targeting instance behavior.
  ///
  /// ### Example
  /// ```dart
  /// for (final method in clazz.getInstanceMethods()) {
  ///   print('${method.getName()} : ${method.getReturnType().getName()}');
  /// }
  /// ```
  List<MethodDeclaration> getInstanceMethods();

  /// Returns a method by its [methodName], or `null` if no method with that name exists.
  ///
  /// Useful for dynamic invocation or analyzing a specific method’s
  /// parameters, return type, and metadata.
  ///
  /// ### Example
  /// ```dart
  /// final addMethod = clazz.getMethod('add');
  /// if (addMethod != null) {
  ///   print(addMethod.getReturnType().getName()); // int
  /// }
  /// ```
  MethodDeclaration? getMethod(String methodName);

  /// Checks if this class or mixin declares a method with the given [methodName].
  ///
  /// Returns `true` if the method exists, `false` otherwise.
  ///
  /// ### Example
  /// ```dart
  /// if (clazz.hasMethod('toString')) {
  ///   print('Method "toString" exists');
  /// }
  /// ```
  bool hasMethod(String methodName);

  /// Returns `true` if this class is marked `abstract`.
  ///
  /// Abstract classes cannot be instantiated directly and are intended
  /// to be subclassed. They may contain abstract methods that must be
  /// implemented by subclasses.
  ///
  /// ### Example
  /// ```dart
  /// abstract class Shape {}
  /// print(shapeClass.getIsAbstract()); // true
  /// ```
  bool getIsAbstract();

  /// Returns `true` if this declaration is a `mixin` or a mixin application.
  ///
  /// Mixins are reusable sets of methods and fields that can be applied
  /// to classes without using inheritance.
  ///
  /// ### Example
  /// ```dart
  /// mixin Logging {}
  /// print(loggingMixin.getIsMixin()); // true
  /// ```
  bool getIsMixin();

  /// Returns `true` if this class is marked `sealed`.
  ///
  /// Sealed classes restrict which other classes may extend them,
  /// providing compile-time guarantees about subclassing.
  bool getIsSealed();

  /// Returns `true` if this class is marked `base`.
  ///
  /// Base classes are designed to be extended but not implemented by
  /// unrelated classes.
  bool getIsBase();

  /// Returns `true` if this class is declared as an `interface`.
  ///
  /// Interfaces define a contract that other classes may implement.
  bool getIsInterface();

  /// Returns `true` if this class is marked `final`.
  ///
  /// Final classes cannot be extended or subclassed.
  bool getIsFinal();

  /// Returns `true` if this class is a `record class`, typically
  /// representing a wrapper around a Dart record type.
  bool getIsRecord();

  /// Returns `true` if this class implements any interfaces.
  ///
  /// Useful for reflection or generating interface-specific behavior.
  bool getHasInterfaces();

  /// Instantiates this class using the default (unnamed) constructor.
  ///
  /// [arguments] is a map of parameter names to their corresponding values.
  /// The runtime system resolves the constructor and passes the arguments.
  ///
  /// ### Example
  /// ```dart
  /// final instance = clazz.newInstance({'name': 'Alice', 'age': 25});
  /// print(instance); // Instance of MyClass
  /// ```
  dynamic newInstance(Map<String, dynamic> arguments);
}