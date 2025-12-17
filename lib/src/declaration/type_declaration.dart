part of 'declaration.dart';

/// {@template type}
/// Represents metadata information about any Dart type — including classes,
/// enums, typedefs, generic types like `List<int>`, and even nullable types.
///
/// You can use this class to:
/// - Introspect type names and type arguments
/// - Determine type kind (list, map, class, enum, etc.)
/// - Resolve the declaration (e.g., to [ClassDeclaration] or [EnumDeclaration])
/// - Perform runtime type comparisons or assignability checks
///
/// ### Example
/// ```dart
/// final type = reflector.reflectType(MyClass);
/// print(type.getName()); // MyClass
///
/// if (type.asClassType() != null) {
///   final reflectedClass = type.asClassType()!;
///   print(reflectedClass.getConstructors());
/// }
/// ```
/// {@endtemplate}
abstract class TypeDeclaration extends EntityDeclaration {
  /// {@macro type}
  const TypeDeclaration();

  /// Returns the fully qualified name of this type.
  ///
  /// For example:
  /// ```
  /// "package:myapp/models.dart.BaseInterface"
  /// ```
  String getQualifiedName();

  /// Returns the simple name of the type without the package or library URI.
  ///
  /// Example:
  /// ```
  /// "BaseInterface"
  /// ```
  String getSimpleName();

  /// Returns the package URI where this type is declared.
  ///
  /// This is typically a `package:` URI such as:
  /// ```
  /// "package:myapp/models.dart"
  /// ```
  String getPackageUri();

  /// Returns the [TypeKind] of this type, indicating whether it is a class, enum, mixin, etc.
  ///
  /// This is useful when performing conditional logic based on what kind of type it is.
  ///
  /// ```dart
  /// if (identity.getKind() == TypeKind.classType) {
  ///   print("This is a class.");
  /// }
  /// ```
  TypeKind getKind();

  /// Returns `true` if the type is nullable, such as `'String?'` or `'int?'`.
  bool getIsNullable();

  /// #### Type Assignability Table:
  /// ```sql
  /// DART TYPE ASSIGNABILITY TABLE
  /// ────────────────────────────────────────────────────────────────────────────
  /// From (B) → To (A)                     A.isAssignableFrom(B)   Valid?   Notes
  /// ────────────────────────────────────────────────────────────────────────────
  /// Object    ← String                   ✅ true                  ✅      String extends Object
  /// String    ← Object                   ❌ false                 ❌      Super not assignable from subclass
  /// num       ← int                      ✅ true                  ✅      int is a subclass of num
  /// int       ← num                      ❌ false                 ❌      num is broader than int
  /// List<int> ← List<int>                ✅ true                  ✅      Same type
  /// List<T>   ← List<S>                  ❌ false                 ❌      Dart generics are invariant
  /// List<dynamic> ← List<int>            ❌ false                 ❌      Still invariant
  /// A         ← B (B extends A)          ✅ true                  ✅      Subclass to superclass is OK
  /// A         ← C (unrelated)            ❌ false                 ❌      No inheritance/interface link
  /// Interface ← Class implements Itf     ✅ true                  ✅      Implements is assignable to interface
  /// Mixin     ← Class with Mixin         ✅ true                  ✅      Mixed-in type present
  /// dynamic   ← anything                 ✅ true                  ✅      dynamic accepts all types
  /// anything  ← dynamic                  ✅ true (unsafe)         ✅      Allowed but unchecked
  /// Never     ← anything                 ❌ false                 ❌      Never can’t accept anything
  /// anything  ← Never                    ✅ true                  ✅      Never fits anywhere (bottom type)
  /// ────────────────────────────────────────────────────────────────────────────
  ///
  /// RULE OF THUMB:
  /// A.isAssignableFrom(B) → Can you do: A a = B();
  /// ✓ Subclass → Superclass: OK
  /// ✗ Superclass → Subclass: Not OK
  /// ✓ Class implements Interface → Interface: OK
  /// ✗ Interface → Class: Not OK
  /// ✓ Identical types: OK
  /// ✗ Unrelated types: Not OK
  /// ```
  ///
  /// Checks if this type is assignable from the given [other] type.
  /// 
  /// Returns `true` if a value of type [other] can be assigned to a variable of this type.
  /// This follows Dart's assignability rules including inheritance, interfaces, and mixins.
  bool isAssignableFrom(TypeDeclaration other);
  
  /// #### Type Assignability Table:
  /// ```sql
  /// DART TYPE ASSIGNABILITY TABLE
  /// ────────────────────────────────────────────────────────────────────────────
  /// From (A) → To (B)                   A.isAssignableTo(B)   Valid?   Notes
  /// ────────────────────────────────────────────────────────────────────────────
  /// String    → Object                 ✅ true               ✅      String extends Object
  /// Object    → String                 ❌ false              ❌      Superclass to subclass not allowed
  /// int       → num                    ✅ true               ✅      int is a subtype of num
  /// num       → int                    ❌ false              ❌      Can't assign broader to narrower
  /// List<int> → List<int>              ✅ true               ✅      Identical type
  /// List<S>   → List<T>                ❌ false              ❌      Dart generics are invariant
  /// List<int> → List<dynamic>          ❌ false              ❌      Invariant generics
  /// B         → A (B extends A)        ✅ true               ✅      Subclass to superclass: OK
  /// C         → A (no relation)        ❌ false              ❌      Unrelated types
  /// Class     → Interface (implements) ✅ true               ✅      Implements interface
  /// Class     → Mixin (with mixin)     ✅ true               ✅      Class includes mixin
  /// anything  → dynamic                ✅ true               ✅      Everything is assignable to dynamic
  /// dynamic   → anything               ✅ true (unchecked)   ✅      Allowed but unsafe
  /// anything  → Never                  ❌ false              ❌      Can't assign anything to Never
  /// Never     → anything               ✅ true               ✅      Never fits anywhere
  /// ────────────────────────────────────────────────────────────────────────────
  ///
  /// RULE OF THUMB:
  /// A.isAssignableTo(B) → Can you do: B b = A();
  /// ✓ Subclass → Superclass: OK
  /// ✗ Superclass → Subclass: Not OK
  /// ✓ Class → Interface it implements: OK
  /// ✗ Interface → Class: Not OK
  /// ✓ Identical types: OK
  /// ✗ Unrelated types: Not OK
  /// ```
  ///
  /// Checks if this type is assignable to the given [target] type.
  /// 
  /// Returns `true` if a value of this type can be assigned to a variable of type [target].
  /// This is the inverse of [isAssignableFrom].
  bool isAssignableTo(TypeDeclaration target);

  /// Check if this is a generic type.
  bool isGeneric();

  /// Returns the list of mixin identities that are applied to this type.
  ///
  /// This includes all mixins directly used in class declarations:
  ///
  /// ```dart
  /// class MyService with LoggingMixin {}
  /// ```
  /// In this case, `LoggingMixin` would appear in the result.
  List<LinkDeclaration> getMixins() => [];

  /// Returns the list of interfaces this type implements.
  ///
  /// This includes all interfaces declared in the `implements` clause.
  ///
  /// ```dart
  /// class MyService implements Disposable, Serializable {}
  /// ```
  /// Would return both `Disposable` and `Serializable`.
  List<LinkDeclaration> getInterfaces() => [];

  /// Returns the list of type arguments for generic types.
  ///
  /// If the type is not generic, this returns an empty list.
  /// For example, `List<String>` will return a list with one [LinkDeclaration] for `String`.
  List<LinkDeclaration> getTypeArguments() => [];

  /// Returns the direct superclass of this type.
  ///
  /// Returns `null` if this type has no superclass or extends `Object`.
  ///
  /// ```dart
  /// final superClass = identity.getSuperClass();
  /// print(superClass?.getQualifiedName()); // e.g., "package:core/BaseService"
  /// ```
  LinkDeclaration? getSuperClass();

  @override
  Map<String,Object> toJson() {
    Map<String, Object> result = {};

    result['declaration'] = 'type';
    result['name'] = getName();
    result['runtimeType'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();

    final arguments = getTypeArguments().map((t) => t.toJson()).toList();
    if(arguments.isNotEmpty) {
      result['typeArguments'] = arguments;
    }

    final declaration = getDeclaration()?.toJson();
    if(declaration != null) {
      result['declaration'] = declaration;
    }
    
    final classType = asClass()?.toJson();
    if(classType != null) {
      result['asClassType'] = classType;
    }
    
    final enumType = asEnum()?.toJson();
    if(enumType != null) {
      result['asEnumType'] = enumType;
    }
    
    final mixinType = asMixin()?.toJson();
    if(mixinType != null) {
      result['asMixinType'] = mixinType;
    }

    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeDeclaration &&
          runtimeType == other.runtimeType && // Crucial for distinguishing concrete types
          getName() == other.getName() &&
          getType() == other.getType() &&
          getIsNullable() == other.getIsNullable() &&
          getKind() == other.getKind();

  @override
  int get hashCode =>
      getName().hashCode ^
      getType().hashCode ^
      getIsNullable().hashCode ^
      getKind().hashCode;

  @override
  String getDebugIdentifier() => 'ReflectedType(${getName()})';
}