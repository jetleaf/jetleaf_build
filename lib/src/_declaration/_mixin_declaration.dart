part of '../declaration/declaration.dart';

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
final class StandardMixinDeclaration extends StandardClassDeclaration implements MixinDeclaration {
  final List<LinkDeclaration> _constraints;

  /// {@macro standard_mixin}
  StandardMixinDeclaration({
    List<LinkDeclaration> constraints = const [],
    required super.name,
    required super.type,
    required super.element,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    super.qualifiedName,
    required super.parentLibrary,
    super.isNullable = false,
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
      element: getElement(),
      dartType: getDartType(),
      isPublic: getIsPublic(),
      isSynthetic: getIsSynthetic(),
      parentLibrary: getParentLibrary(),
      constraints: constraints ?? getConstraints(),
      constructors: constructors ?? getConstructors(),
      fields: fields ?? getFields(),
      methods: methods ?? getMethods(),
      isNullable: getIsNullable(),
      typeArguments: getTypeArguments(),
      annotations: getAnnotations(),
      sourceLocation: getSourceLocation(),
      qualifiedName: getQualifiedName(),
      mixins: getMixins(),
      interfaces: getInterfaces(),
      superClass: getSuperClass()
    );
  }

  @override
  String getDebugIdentifier() => 'mixin_${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'mixin';
    result['name'] = getName();
    
    final parentLibrary = getParentLibrary().toJson();
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
    
    final declaration = getDeclaration();
    if (declaration != null) {
      result['declaration'] = declaration.toJson();
    }
    

    final members = getMembers().map((m) => m.toJson()).toList();
    if (members.isNotEmpty) {
      result['members'] = members;
    }
    
    result['type'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getType(),
      getIsNullable(),
      getKind(),
      getTypeArguments(),
      getFields(),
      getMethods(),
      getHasConstraints(),
      getHasInterfaces(),
      getMembers(),
    ];
  }
}