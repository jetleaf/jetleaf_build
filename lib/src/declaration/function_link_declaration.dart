part of 'declaration.dart';

/// {@template function_link_declaration}
/// Specialized LinkDeclaration for function type references.
///
/// Represents references to function types such as:
/// - `String Function(String)`
/// - `void Function()?`
/// - `Future<T> Function(T input)`
///
/// {@template function_link_declaration_features}
/// ## Key Features
/// - Function type return type information
/// - Parameter type information
/// - Type parameter support for generic functions
/// - Nullability support for function types
/// - Full type signature representation
///
/// ## Typical Usage
/// Used by reflection systems to represent:
/// - Function type parameters
/// - Method return types
/// - Callback parameters
/// - Generic function types
/// {@endtemplate}
///
/// {@template function_link_declaration_example}
/// ## Example Usage
/// ```dart
/// final functionLink = FunctionLinkDeclaration(
///   returnType: stringLink,
///   parameters: [stringLink],
///   typeParameters: [],
///   isNullable: false,
/// );
///
/// print(functionLink.getReturnType().getName()); // "String"
/// print(functionLink.getParameters()[0].getName()); // "String"
/// print(functionLink.isNullable()); // false
/// ```
/// {@endtemplate}
/// {@endtemplate}
abstract class FunctionLinkDeclaration implements LinkDeclaration {
  /// {@macro function_link_declaration}
  const FunctionLinkDeclaration();

  /// Gets the return type of the function.
  ///
  /// {@template get_return_type}
  /// Returns:
  /// - A [LinkDeclaration] representing the function's return type
  /// - For `void` functions, returns a representation of `void`
  /// - Never returns `null`
  /// {@endtemplate}
  LinkDeclaration getReturnType();

  /// Gets the parameter types of the function.
  ///
  /// {@template get_parameters}
  /// Returns:
  /// - A list of [LinkDeclaration] representing each parameter type
  /// - Empty list for functions with no parameters
  /// - Preserves parameter order
  /// - Does not include parameter names, only types
  /// {@endtemplate}
  List<LinkDeclaration> getParameters();

  /// Gets the type parameters for generic function types.
  ///
  /// {@template get_type_parameters}
  /// Returns:
  /// - A list of [LinkDeclaration] for each type parameter
  /// - Empty list for non-generic function types
  /// - Preserves declaration order
  /// - Includes bounds and variance information
  /// {@endtemplate}
  List<LinkDeclaration> getTypeParameters();

  /// Checks if this function type is nullable.
  ///
  /// {@template is_function_nullable}
  /// Returns:
  /// - `true` if the function type itself is nullable (e.g., `void Function()?`)
  /// - `false` otherwise
  /// - Note: This is different from parameters or return types being nullable
  /// {@endtemplate}
  bool isNullable();

  /// Gets the function signature as a string.
  ///
  /// {@template get_signature}
  /// Returns:
  /// - Human-readable function signature
  /// - Example: "String Function(String)" or "void Function()?"
  /// - Includes type parameters if present
  /// {@endtemplate}
  String getSignature();

  /// Returns the [MethodDeclaration] representing the underlying method,
  /// if this function link was created from a concrete method reference.
  ///
  /// This is particularly useful when bridging between **function-type
  /// references** and **actual method declarations**, allowing you to
  /// inspect metadata, modifiers, parameters, and return types
  /// from the original method.
  ///
  /// Returns:
  /// - A [MethodDeclaration] if the function link corresponds to a real
  ///   method or getter/setter.
  /// - `null` if the function link represents an abstract, anonymous,
  ///   or dynamically generated function type.
  ///
  /// ### Example
  /// ```dart
  /// final methodLink = functionLink.getMethodCall();
  /// if (methodLink != null) {
  ///   print(methodLink.getName()); // e.g., "myCallback"
  ///   print(methodLink.getReturnType().getName()); // e.g., "String"
  ///   print(methodLink.getParameters().length); // Number of parameters
  /// }
  /// ```
  ///
  /// This allows reflection code to map function type references
  /// back to their original declarations for detailed inspection or
  /// invocation purposes.
  MethodDeclaration? getMethodCall();
}