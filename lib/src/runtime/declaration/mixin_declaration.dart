part of 'declaration.dart';

/// {@template mixin}
/// Represents a reflected Dart `mixin` declaration, providing access to its
/// members, type constraints, and metadata.
///
/// Mixins in Dart allow code reuse across multiple class hierarchies. This
/// interface provides runtime introspection of mixin declarations, including
/// their fields, methods, type constraints, and annotations.
///
/// ### Example
/// ```dart
/// mixin TimestampMixin on BaseModel {
///   DateTime? createdAt;
///   DateTime? updatedAt;
///   
///   void updateTimestamp() {
///     updatedAt = DateTime.now();
///   }
/// }
///
/// final mixinType = reflector.reflectType(TimestampMixin).asMixinType();
/// print(mixinType?.getName()); // TimestampMixin
/// print(mixinType?.getFields().length); // 2
/// print(mixinType?.getMethods().length); // 1
/// ```
/// {@endtemplate}
abstract final class MixinDeclaration extends ClassDeclaration implements SourceDeclaration {
  /// {@macro mixin}
  const MixinDeclaration();

  /// Returns the `on` constraint types for this mixin.
  ///
  /// Mixins in Dart can declare `on` constraints to specify the
  /// classes or interfaces they can be applied to. This method
  /// returns a list of [LinkDeclaration] objects representing
  /// those types.
  ///
  /// ### Example
  /// ```dart
  /// mixin MyMixin on BaseClass, SomeInterface {}
  /// final constraints = mixinDecl.getConstraints();
  /// // constraints contains LinkDeclaration for BaseClass and SomeInterface
  /// ```
  ///
  /// Returns an empty list if the mixin has no `on` constraints.
  List<LinkDeclaration> getConstraints();

  /// Returns `true` if this mixin declares `on` type constraints.
  ///
  /// This is a convenience method equivalent to checking
  /// `getConstraints().isNotEmpty`.
  ///
  /// ### Example
  /// ```dart
  /// mixin MyMixin on BaseClass {}
  /// print(mixinDecl.getHasConstraints()); // true
  /// ```
  bool getHasConstraints();
}

/// {@template standard_mixin}
/// A standard implementation of [MixinDeclaration] that provides reflection
/// metadata about a Dart mixin declaration.
///
/// This class exposes the mixin's name, runtime type, type parameters,
/// constraints, fields, methods, and other metadata necessary for
/// runtime introspection of mixin declarations.
///
/// ## Example
///
/// ```dart
/// mixin TimestampMixin on BaseModel {
///   DateTime? createdAt;
///   DateTime? updatedAt;
///   
///   void updateTimestamp() {
///     updatedAt = DateTime.now();
///   }
/// }
///
/// final mixinReflection = StandardReflectedMixin(
///   name: 'TimestampMixin',
///   type: TimestampMixin,
///   parentLibrary: myLibrary,
///   constraints: [baseModelType],
///   fields: [createdAtField, updatedAtField],
///   methods: [updateTimestampMethod],
/// );
///
/// print(mixinReflection.getName()); // TimestampMixin
/// print(mixinReflection.getOnConstraints().length); // 1
/// ```
///
/// This implementation supports all the standard reflection operations
/// including type checking, member access, constraint inspection, and annotation access.
///
/// {@endtemplate}
@internal
final class StandardMixinDeclaration extends StandardClassDeclaration implements MixinDeclaration {
  final List<LinkDeclaration> _constraints;

  /// {@macro standard_mixin}
  StandardMixinDeclaration({
    List<LinkDeclaration> constraints = const [],
    required super.name,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    super.qualifiedName,
    required super.library,
    super.typeArguments,
    super.annotations,
    super.constructors = const [],
    super.fields = const [],
    super.interfaces = const [],
    super.isAbstract = false,
    super.isBase = false,
    super.isFinal = false,
    super.isInterface = false,
    super.isMixin = true,
    super.isRecord = false,
    super.isSealed = false,
    super.methods,
    super.mixins,
    super.sourceLocation,
    super.superClass
  })  : _constraints = constraints, super(kind: TypeKind.mixinType);

  @override
  List<LinkDeclaration> getConstraints() => List.unmodifiable(_constraints);

  @override
  bool getHasConstraints() => _constraints.isNotEmpty;

  /// Creates a copy of this mixin with the specified properties changed.
  StandardMixinDeclaration updateWith({
    List<ConstructorDeclaration>? constructors,
    List<FieldDeclaration>? fields,
    List<MethodDeclaration>? methods,
    List<LinkDeclaration>? constraints
  }) {
    return StandardMixinDeclaration(
      name: getName(),
      type: getType(),
      isPublic: getIsPublic(),
      isSynthetic: getIsSynthetic(),
      library: getLibrary(),
      constraints: constraints ?? getConstraints(),
      constructors: constructors ?? getConstructors(),
      fields: fields ?? getFields(),
      methods: methods ?? getMethods(),
      typeArguments: getTypeArguments(),
      annotations: getAnnotations(),
      sourceLocation: getSourceLocation(),
      qualifiedName: getQualifiedName(),
      mixins: getMixins(),
      interfaces: getInterfaces(),
      superClass: getSuperClass(),
      isRecord: false,
      isAbstract: getIsAbstract(),
      isBase: getIsBase(),
      isFinal: getIsFinal(),
      isInterface: getIsInterface(),
      isMixin: getIsMixin(),
      isSealed: getIsSealed(),
    );
  }

  @override
  String getDebugIdentifier() => 'mixin_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result.addAll(super.toJson());
    
    result['declaration'] = 'mixin';
    result['name'] = getName();
    
    final parentLibrary = getLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if (annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }

    final sourceLocation = getSourceLocation();
    if (sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }
    
    final constraints = getConstraints().map((c) => c.toJson()).toList();
    if (constraints.isNotEmpty) {
      result['constraints'] = constraints;
    }
    
    final interfaces = getInterfaces().map((i) => i.toJson()).toList();
    if (interfaces.isNotEmpty) {
      result['interfaces'] = interfaces;
    }
    
    final fields = getFields().map((f) => f.toJson()).toList();
    if (fields.isNotEmpty) {
      result['fields'] = fields;
    }
    
    final methods = getMethods().map((m) => m.toJson()).toList();
    if (methods.isNotEmpty) {
      result['methods'] = methods;
    }

    final typeArguments = getTypeArguments().map((t) => t.toJson()).toList();
    if (typeArguments.isNotEmpty) {
      result['typeArguments'] = typeArguments;
    }

    final members = getMembers().map((m) => m.toJson()).toList();
    if (members.isNotEmpty) {
      result['members'] = members;
    }
    
    result['type'] = getType().toString();
    result['kind'] = getKind().toString();
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getSourceLocation(),
      getType(),
      getKind(),
      getQualifiedName(),
    ];
  }
}