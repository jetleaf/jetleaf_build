part of 'declaration.dart';

/// Represents a **closure or anonymous function** as a class-like declaration
/// within the JetLeaf reflection system.
///
/// A `ClosureDeclaration` provides a canonical abstraction for **function
/// literals, closures, or lambda expressions**. In JetLeaf, closures are
/// materialized as first-class `ClassDeclaration` objects so that:
/// - Runtime metadata can be associated
/// - Reflection and type resolution can occur uniformly
/// - Closures can participate in generic type resolution and code generation
///
/// Unlike standard `ClassDeclaration`s, closures:
/// - Have exactly one callable method, accessible via [getFunction()]
/// - Retain a reference to the underlying generated class via [getClassDeclaration()]
/// - Can be nested, generic, or dynamically created at runtime
abstract final class ClosureDeclaration extends ClassDeclaration with EqualsAndHashCode {
  /// Returns the **function representation** of this closure.
  ///
  /// This is a fully materialized [MethodDeclaration] representing the
  /// executable body of the closure, including parameters, return type,
  /// annotations, and generic type information.
  ///
  /// Example:
  /// ```dart
  /// final closureDecl = runtime.generateMirroredClass(reflect(() => 42)) as ClosureDeclaration;
  /// final function = closureDecl.getFunction();
  /// print(function.name); // 'Closure' or inferred name
  /// print(function.parameters.map((p) => p.name));
  /// ```
  MethodDeclaration getFunction();

  /// Returns the **underlying class declaration** associated with this closure.
  ///
  /// In JetLeaf, closures are modeled as synthetic classes to support
  /// uniform reflection, generic type resolution, and metadata extraction.
  /// This method returns the `ClassDeclaration` that backs the closure.
  ///
  /// Example:
  /// ```dart
  /// final closureDecl = runtime.generateMirroredClass(reflect(() => 42)) as ClosureDeclaration;
  /// final classDecl = closureDecl.getClassDeclaration();
  /// print(classDecl.getQualifiedName());
  /// ```
  ClassDeclaration getClassDeclaration();
}

/// {@template standard_closure_declaration}
/// A concrete, internal implementation of [ClosureDeclaration].
///
/// `StandardClosureDeclaration` wraps a closure function along with its
/// associated synthetic class, providing full access to:
/// - The function body via [_function]
/// - The generated class via [_classDeclaration]
/// - All standard `ClassDeclaration` metadata inherited from
///   [StandardClassDeclaration]
///
/// This class is **intended for internal use only** and should not be
/// instantiated directly by consumers.
/// {@endtemplate}
@internal
final class StandardClosureDeclaration extends StandardClassDeclaration implements ClosureDeclaration {
  /// The **materialized function** corresponding to the closure.
  ///
  /// This is a fully resolved [MethodDeclaration] representing the closure
  /// body, parameters, and return type.
  final MethodDeclaration _function;

  /// The **synthetic class declaration** that backs this closure.
  ///
  /// This class enables closures to participate in reflection, generic
  /// type resolution, and metadata extraction as if they were first-class
  /// classes.
  final ClassDeclaration _classDeclaration;

  /// Creates a `StandardClosureDeclaration` with the given function
  /// and associated class declaration.
  ///
  /// Typically used internally by the JetLeaf runtime when materializing
  /// closure mirrors.
  StandardClosureDeclaration({
    required MethodDeclaration function,
    required ClassDeclaration classDeclaration,
  })  : _function = function,
        _classDeclaration = classDeclaration,
        super(
          name: classDeclaration.getName(),
          type: classDeclaration.getType(),
          qualifiedName: classDeclaration.getQualifiedName(),
          library: classDeclaration.getLibrary(),
          typeArguments: classDeclaration.getTypeArguments(),
          annotations: classDeclaration.getAnnotations(),
          sourceLocation: classDeclaration.getSourceLocation(),
          superClass: classDeclaration.getSuperClass(),
          interfaces: classDeclaration.getInterfaces(),
          mixins: classDeclaration.getMixins(),
          constructors: classDeclaration.getConstructors(),
          methods: classDeclaration.getMethods(),
          fields: classDeclaration.getFields(),
          isAbstract: classDeclaration.getIsAbstract(),
          isBase: classDeclaration.getIsBase(),
          isFinal: classDeclaration.getIsFinal(),
          isInterface: classDeclaration.getIsInterface(),
          isMixin: classDeclaration.getIsMixin(),
          isRecord: classDeclaration.getIsRecord(),
          isPublic: classDeclaration.getIsPublic(),
          isSynthetic: classDeclaration.getIsSynthetic(),
          kind: TypeKind.closureType
        );

  @override
  MethodDeclaration getFunction() => _function;

  @override
  ClassDeclaration getClassDeclaration() => _classDeclaration;
}