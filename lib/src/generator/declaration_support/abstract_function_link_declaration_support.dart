import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../../declaration/declaration.dart';
import 'abstract_link_declaration_support.dart';

/// {@template abstract_function_link_declaration_support}
/// Abstract base class providing **function-type link generation support**
/// for the JetLeaf linking and runtime reflection system.
///
/// `AbstractFunctionLinkDeclarationSupport` specializes
/// [AbstractLinkDeclarationSupport] with comprehensive logic for resolving,
/// normalizing, and materializing **function and callable type declarations**
/// from both **Dart runtime mirrors** and **analyzer `DartType`s**.
///
/// ## Responsibilities
/// This class is responsible for:
/// - Translating `FunctionTypeMirror` and analyzer `FunctionType` instances
///   into canonical [FunctionLinkDeclaration] objects.
/// - Resolving return types, parameters, generic type parameters, and
///   applied type arguments.
/// - Detecting and preventing **cyclic type resolution** during link
///   generation.
/// - Producing stable identities for caching, deduplication, and reuse
///   across multiple resolution passes.
///
/// ## Dual Source Resolution
/// Function signatures are resolved using a **hybrid strategy**:
/// - **Mirrors-first**: Runtime reflection is treated as authoritative when
///   available.
/// - **Analyzer fallback**: Analyzer metadata is used to improve accuracy
///   for nullability, generics, and bounds when mirrors are insufficient.
///
/// ## Design Notes
/// - This class is intentionally abstract and intended to be extended by
///   concrete link-generation backends.
/// - All heavy lifting related to function signatures is centralized here
///   to ensure consistent behavior across the runtime, build-time scanners,
///   and generated artifacts.
/// - Identity-based cycle detection ensures safe handling of recursive and
///   self-referential function types.
///
/// This class forms a critical part of JetLeaf’s **type-aware runtime
/// linking pipeline**, enabling precise and performant function invocation
/// modeling without relying on runtime reflection at execution time.
/// {@endtemplate}
abstract class AbstractFunctionLinkDeclarationSupport extends AbstractLinkDeclarationSupport {
  /// {@macro abstract_function_link_declaration_support}
  AbstractFunctionLinkDeclarationSupport({required super.mirrorSystem, required super.forceLoadedMirrors, required super.configuration, required super.packages});

  @override
  Future<FunctionLinkDeclaration?> generateFunctionLinkDeclaration(mirrors.TypeMirror mirror, FunctionType? dartType, Package package, String libraryUri) async {
    if (mirror case mirrors.FunctionTypeMirror functionTypeMirror) {
      return await generateFunctionLinkDeclarationFromMirror(functionTypeMirror, dartType, package, libraryUri);
    } else if (dartType case final functionType?) {
      return await _generateFunctionLinkDeclarationFromDartType(functionType, package, libraryUri, mirror);
    }

    return null;
  }

  /// Generates a [FunctionLinkDeclaration] from a runtime mirror.
  ///
  /// {@template generate_function_from_mirror}
  /// This method converts a [mirrors.FunctionTypeMirror] and optional analyzer
  /// [FunctionType] into a fully materialized [FunctionLinkDeclaration].
  ///
  /// It performs the following steps:
  /// 1. Computes a stable **identity** for cycle detection.
  /// 2. Extracts the function signature using [_extractFunctionSignatureFromMirror],
  ///    including return type, parameters, type parameters, nullability, and synthetic status.
  /// 3. Constructs a [StandardFunctionLinkDeclaration] with all collected information.
  /// 4. Optionally links a [MethodDeclaration] if the function corresponds to a method.
  ///
  /// ### Parameters
  /// - [functionTypeMirror]: The runtime reflection mirror for the function type.
  /// - [dartType]: Optional analyzer [FunctionType] for additional metadata.
  /// - [package]: The [Package] context for type resolution.
  /// - [libraryUri]: URI of the library containing this function.
  ///
  /// ### Returns
  /// A [Future] completing with a fully initialized [FunctionLinkDeclaration].
  ///
  /// ### Example
  /// ```dart
  /// final mirror = reflectType(void Function(int)) as FunctionTypeMirror;
  /// final functionLink = await generateFunctionLinkDeclarationFromMirror(
  ///   mirror,
  ///   null,
  ///   myPackage,
  ///   'package:my_app/utils.dart'
  /// );
  ///
  /// print(functionLink.getReturnType().getName()); // "void"
  /// print(functionLink.getParameters()[0].getName()); // "int"
  /// print(functionLink.isNullable()); // false
  /// ```
  /// {@endtemplate}
  @protected
  Future<FunctionLinkDeclaration> generateFunctionLinkDeclarationFromMirror(mirrors.FunctionTypeMirror functionTypeMirror, FunctionType? dartType, Package package, String libraryUri) async {
    final typeIdentity = _buildFunctionTypeIdentity(functionTypeMirror, dartType, libraryUri);
    linkGenerationInProgress.add(typeIdentity);

    try {
      // Extract function signature information
      final signature = await _extractFunctionSignatureFromMirror(functionTypeMirror, package, libraryUri, dartType);
      final functionUri = await findRealClassUriFromMirror(mirrors.reflectType(Function), null) ?? libraryUri;

      // Build the final function link
      return StandardFunctionLinkDeclaration(
        returnType: signature.returnType,
        parameters: signature.parameters,
        typeParameters: signature.typeParameters,
        typeArguments: signature.typeArguments,
        isNullable: signature.isNullable,
        name: dartType?.getDisplayString() ?? signature.displayName,
        dartType: dartType,
        type: Function,
        pointerType: Function,
        qualifiedName: buildQualifiedName("Function", functionUri),
        canonicalUri: Uri.tryParse(libraryUri),
        referenceUri: Uri.tryParse(libraryUri),
        isPublic: true,
        isSynthetic: signature.isSynthetic,
        variance: TypeVariance.invariant,
        methodDeclaration: await generateMethod(
          functionTypeMirror.callMethod,
          null,
          package,
          libraryUri,
          functionTypeMirror.location?.sourceUri ?? Uri.parse(libraryUri),
          signature.displayName,
          null
        )
      );
    } finally {
      linkGenerationInProgress.remove(typeIdentity);
    }
  }

  /// Extracts a complete function signature from a
  /// [mirrors.FunctionTypeMirror].
  ///
  /// This method serves as the **primary signature extractor**, translating
  /// reflection metadata into a normalized [_FunctionSignature] model that
  /// can be consumed by the linker.
  ///
  /// It resolves:
  /// - Return type
  /// - Positional parameters
  /// - Generic type parameters
  /// - Type arguments
  /// - Nullability
  /// - Display name
  /// - Synthetic status
  ///
  /// Analyzer information is used opportunistically to improve accuracy,
  /// but reflection data remains the authoritative source.
  ///
  /// ### Parameters
  /// - [mirror] — The reflection-based function type mirror.
  /// - [package] — The package context for type resolution.
  /// - [libraryUri] — The URI of the declaring library.
  /// - [dartType] — The analyzer-based function type, if available.
  ///
  /// ### Returns
  /// A [_FunctionSignature] describing the function’s complete type shape.
  Future<_FunctionSignature> _extractFunctionSignatureFromMirror(mirrors.FunctionTypeMirror mirror, Package package, String libraryUri, FunctionType? dartType) async {
    // Get return type
    final returnTypeLink = await getLinkDeclaration(mirror.returnType, package, libraryUri, dartType);
    
    // Get parameters
    final parameters = <LinkDeclaration>[];
    final mirrorParameters = mirror.parameters;
    final dartTypeParameters = dartType?.formalParameters ?? <FormalParameterElement>[];
    for (int i = 0; i < mirrorParameters.length; i++) {
      final param = mirrorParameters[i];
      final paramName = mirrors.MirrorSystem.getName(param.simpleName);
      final paramType = dartTypeParameters.where((p) => p.displayName == paramName).firstOrNull;

      final paramLink = await getLinkDeclaration(param.type, package, libraryUri, paramType?.type);
      parameters.add(paramLink);
    }

    // Get type parameters
    final typeParameters = <LinkDeclaration>[];
    if (mirror is mirrors.MethodMirror) {
      final mirrorVariables = mirror.typeVariables;
      final dartTypeParameters = dartType?.typeParameters ?? <TypeParameterElement>[];

      for (int i = 0; i < mirrorVariables.length; i++) {
        final variable = mirrorVariables[i];
        final variableName = mirrors.MirrorSystem.getName(variable.simpleName);
        final variableType = dartTypeParameters.where((p) => p.displayName == variableName).firstOrNull;
        
        final typeParamLink = await generateLinkDeclaration(variable, package, libraryUri, variableType?.bound);
        if (typeParamLink != null) {
          typeParameters.add(typeParamLink);
        }
      }
    }

    final typeArguments = await extractTypeArgumentAsLinks(mirror.typeArguments, [], package, libraryUri);

    // Determine nullability
    final isNullable = mirrors.MirrorSystem.getName(mirror.simpleName).endsWith('?') ||
        (mirror.returnType.hasReflectedType 
            ? mirror.returnType.reflectedType
            : mirror.returnType.runtimeType).toString().endsWith('?');

    // Build display name
    final displayName = _buildFunctionDisplayName(returnTypeLink, parameters, typeParameters, isNullable);

    return _FunctionSignature(
      returnType: returnTypeLink,
      parameters: parameters,
      typeParameters: typeParameters,
      isNullable: dartType?.returnType.nullabilitySuffix == NullabilitySuffix.question || isNullable,
      displayName: displayName,
      isSynthetic: isSynthetic(displayName),
      typeArguments: typeArguments
    );
  }

  Future<FunctionLinkDeclaration?> _generateFunctionLinkDeclarationFromDartType(FunctionType functionType, Package package, String libraryUri, [mirrors.TypeMirror? mirror]) async {
    // Create a unique key for this function type
    final typeKey = 'dart_func_${functionType.getDisplayString()}_${functionType.hashCode}';
    
    // Check if we're already processing this function type
    if (linkGenerationInProgress.contains(typeKey)) {
      return null;
    }
    // Mark as in progress
    linkGenerationInProgress.add(typeKey);
    
    try {
      // Get return type
      final returnTypeLink = await _generateLinkDeclarationFromDartType(functionType, package, libraryUri);

      // Get parameter types
      final parameterLinks = <LinkDeclaration>[];
      for (final param in functionType.formalParameters) {
        final paramTypeLink = await _generateLinkDeclarationFromDartType(param.type, package, libraryUri);
        
        if (paramTypeLink case final typed?) {
          parameterLinks.add(typed);
        }
      }

      // Get type parameters
      final typeParamLinks = <LinkDeclaration>[];
      for (final typeParam in functionType.typeParameters) {
        if (typeParam.bound case final dartType?) {
          final typeParamLink = await _generateLinkDeclarationFromDartType(dartType, package, libraryUri);
          final typeName = typeParam.name ?? typeParam.displayName;

          // Create a proper type parameter link with variance
          final typeParamDeclaration = StandardLinkDeclaration(
            name: typeName,
            type: Object,
            pointerType: Object,
            dartType: dartType,
            typeArguments: [],
            qualifiedName: buildQualifiedName(typeName, libraryUri),
            canonicalUri: Uri.tryParse(libraryUri),
            referenceUri: Uri.tryParse(libraryUri),
            variance: inferVarianceFromContext(typeParam.instantiate(nullabilitySuffix: NullabilitySuffix.question)),
            upperBound: typeParamLink,
            isPublic: !isInternal(typeName),
            isSynthetic: isSynthetic(typeName),
          );
          typeParamLinks.add(typeParamDeclaration);
        }
      }

      // Build the function signature
      if (returnTypeLink != null) {
        final signature = functionType.getDisplayString();
        final functionUri = await findRealClassUriFromMirror(mirrors.reflectType(Function), null) ?? libraryUri;

        return StandardFunctionLinkDeclaration(
          returnType: returnTypeLink,
          parameters: parameterLinks,
          typeParameters: typeParamLinks,
          isNullable: functionType.returnType.nullabilitySuffix == NullabilitySuffix.question,
          name: signature,
          type: Function,
          dartType: functionType,
          pointerType: Function,
          qualifiedName: buildQualifiedName("Function", functionUri),
          canonicalUri: Uri.tryParse(libraryUri),
          referenceUri: Uri.tryParse(libraryUri),
          isPublic: true,
          isSynthetic: isSynthetic(functionType.getDisplayString()),
          variance: TypeVariance.invariant,
        );
      } else {
        return null;
      }
    } finally {
      // Always remove from in-progress set
      linkGenerationInProgress.remove(typeKey);
    }
  }

  /// Generates a [LinkDeclaration] from an analyzer [DartType], with **cycle detection**.
  ///
  /// This method handles:
  /// - Function types (`FunctionType`) by delegating to `_generateFunctionLinkDeclarationFromDartType`.
  /// - Parameterized types, recursively generating links for type arguments.
  /// - Type parameters, including variance and upper bound resolution.
  /// - Cycle detection to avoid infinite recursion in recursive type definitions.
  ///
  /// Parameters:
  /// - [dartType]: The analyzer [DartType] representing the type to generate a link for.
  /// - [package]: The [Package] context for resolving type references.
  /// - [libraryUri]: URI of the library where the type is declared.
  /// - [mirror]: Optional [mirrors.TypeMirror] to supplement type resolution from runtime mirrors.
  ///
  /// Returns a [Future] that completes with the generated [LinkDeclaration], or `null`
  /// if the type cannot be resolved.
  Future<LinkDeclaration?> _generateLinkDeclarationFromDartType(DartType dartType, Package package, String libraryUri, [mirrors.TypeMirror? mirror]) async {
    if (dartType is FunctionType) {
      return await _generateFunctionLinkDeclarationFromDartType(dartType, package, libraryUri, mirror);
    }
    
    final element = dartType.element;
    if (element == null) return null;

    // Create a unique key for this type to detect cycles
    final typeKey = '${element.library?.uri}_${element.name}_${dartType.getDisplayString()}';
    
    // Check if we're already processing this type (cycle detection)
    if (linkGenerationInProgress.contains(typeKey)) {
      return null; // Break the cycle
    }
    
    // Mark as in progress
    linkGenerationInProgress.add(typeKey);
    
    try {
      // Find the real class in the runtime system to get the actual package URI
      final realClassUri = await findRealClassUri(element.name!, element.library?.uri.toString());

      // Get the actual runtime type for this DartType
      final actualRuntimeType = await findRuntimeTypeFromDartType(dartType, libraryUri, package);
      
      // Get the base type (without type parameters)
      final baseRuntimeType = await findBaseRuntimeTypeFromDartType(dartType, libraryUri, package);
      final realPackageUri = realClassUri ?? element.library?.uri.toString() ?? libraryUri;

      // Get type arguments from the implementing class (with cycle protection)
      final typeArguments = <LinkDeclaration>[];
      if (dartType is ParameterizedType && dartType.typeArguments.isNotEmpty) {
        for (final arg in dartType.typeArguments) {
          final argKey = '${arg.element?.library?.uri}_${arg.element?.name}_${arg.getDisplayString()}';
          if (!linkGenerationInProgress.contains(argKey)) {
            final argLink = mirror != null 
              ? await getLinkDeclaration(mirror, package, libraryUri, arg)
              : await _generateLinkDeclarationFromDartType(arg, package, libraryUri);
            
            if (argLink != null) {
              typeArguments.add(argLink);
            }
          }
        }
      }

      // Determine variance and upper bound for type parameters (with cycle protection)
      TypeVariance variance = TypeVariance.invariant;
      LinkDeclaration? upperBound;
      
      if (dartType is TypeParameterType) {
        // Handle type parameter variance and bounds
        final bound = dartType.bound;
        if (!bound.isDartCoreObject) {
          final boundKey = '${bound.element?.library?.uri}_${bound.element?.name}_${bound.getDisplayString()}';
          if (!linkGenerationInProgress.contains(boundKey)) {
            upperBound = mirror != null 
              ? await getLinkDeclaration(mirror, package, libraryUri, bound)
              : await _generateLinkDeclarationFromDartType(bound, package, libraryUri);
          }
        }
      
        // Infer variance from usage context (simplified)
        variance = inferVarianceFromContext(dartType);
      }

      final displayString = await getClassNameFromDartType(dartType, libraryUri) ?? (element is InterfaceElement 
        ? element.thisType.getDisplayString()
        : dartType.getDisplayString());

      return StandardLinkDeclaration(
        name: dartType.getDisplayString(),
        type: actualRuntimeType,
        pointerType: baseRuntimeType,
        typeArguments: typeArguments,
        dartType: dartType,
        qualifiedName: buildQualifiedName(displayString, realPackageUri),
        canonicalUri: Uri.tryParse(realPackageUri),
        referenceUri: Uri.tryParse(libraryUri),
        variance: variance,
        upperBound: upperBound,
        isPublic: !isInternal(displayString),
        isSynthetic: isSynthetic(displayString),
      );
    } finally {
      // Always remove from in-progress set
      linkGenerationInProgress.remove(typeKey);
    }
  }

  /// Builds a **human-readable display name** for a function type.
  ///
  /// This method constructs a canonical, compact string representation of a
  /// function type suitable for diagnostics, logging, and debugging output.
  /// It does **not** encode identity or uniqueness guarantees—only readability.
  ///
  /// The resulting format follows this structure:
  ///
  /// ```text
  /// <return-type><type-parameters>(<parameter-types>)?
  /// ```
  ///
  /// ### Formatting Rules
  /// - If [returnType] is `null`, the return type defaults to `dynamic`.
  /// - Generic type parameters are rendered inside angle brackets (`<T, U>`).
  /// - Parameter types are rendered in declaration order.
  /// - If [isNullable] is `true`, a trailing `?` is appended.
  ///
  /// ### Parameters
  /// - [returnType] — The return type declaration, or `null` if implicit.
  /// - [parameters] — The ordered list of parameter type declarations.
  /// - [typeParameters] — The generic type parameters declared by the function.
  /// - [isNullable] — Whether the function’s return type is nullable.
  ///
  /// ### Returns
  /// A formatted string representing the function type.
  ///
  /// ### Example
  /// ```dart
  /// // Represents: int<T>(String, bool)?
  /// _buildFunctionDisplayName(
  ///   intDecl,
  ///   [stringDecl, boolDecl],
  ///   [tDecl],
  ///   true,
  /// );
  /// ```
  String _buildFunctionDisplayName(LinkDeclaration? returnType, List<LinkDeclaration> parameters, List<LinkDeclaration> typeParameters, bool isNullable) {
    final returnName = returnType?.getName() ?? 'dynamic';
    final typeParams = typeParameters.isNotEmpty
        ? '<${typeParameters.map((p) => p.getName()).join(', ')}>'
        : '';
    
    final paramString = parameters.isEmpty
        ? '()'
        : '(${parameters.map((p) => p.getName()).join(', ')})';
    
    final nullableSuffix = isNullable ? '?' : '';
    
    return '$returnName$typeParams$paramString$nullableSuffix';
  }

  /// Builds a **stable identity string** for a function type.
  ///
  /// This method generates a unique identity key used internally for caching,
  /// deduplication, and cycle prevention during function-type link generation.
  ///
  /// The identity combines:
  /// - Reflection metadata from [mirror]
  /// - Analyzer metadata from [dartType], when available
  /// - Hash codes for collision resistance
  /// - The [libraryUri] to ensure cross-library uniqueness
  ///
  /// When analyzer information is unavailable, the identity falls back to a
  /// mirror-only representation.
  ///
  /// ### Parameters
  /// - [mirror] — The reflection-based type mirror of the function.
  /// - [dartType] — The analyzer-based type representation, if available.
  /// - [libraryUri] — The URI of the declaring library.
  ///
  /// ### Returns
  /// A unique string suitable for identifying a function type across
  /// link-generation passes.
  ///
  /// ### Notes
  /// - This identity is **not** intended for display purposes.
  /// - Changes in analyzer or mirror metadata will result in a different key.
  String _buildFunctionTypeIdentity(mirrors.TypeMirror mirror, DartType? dartType, String libraryUri) {
    final mirrorName = mirrors.MirrorSystem.getName(mirror.simpleName);
    final mirrorHash = mirror.hashCode;
    
    if (dartType != null) {
      final dartName = dartType.getDisplayString();
      final dartHash = dartType.hashCode;
      return 'func_${mirrorName}_${dartName}_${mirrorHash}_${dartHash}_$libraryUri';
    }
    
    return 'func_mirror_${mirrorName}_${mirrorHash}_$libraryUri';
  }

  /// Generates a [MethodDeclaration] for a class or instance method using
  /// Dart reflection (`mirrors`) and analyzer support.
  ///
  /// This method combines information from a [mirrors.MethodMirror] and an
  /// optional analyzer [Element] (if available) to build a complete
  /// metadata representation of a method. It resolves:
  /// - Method name, visibility (public/private), and whether it is static, abstract,
  ///   a getter, a setter, factory, or const constructor.
  /// - Return type using both analyzer and mirror reflection, with support for
  ///   generic type resolution via annotations.
  /// - Method parameters, including nullability, optionality, named parameters,
  ///   default values, and annotations.
  /// - Associated annotations on the method.
  /// - Source location of the method in the library.
  ///
  /// This is intended for internal framework use (annotated with `@protected`),
  /// primarily in code generation, reflection-based analysis, or automated API
  /// documentation tools.
  ///
  /// Parameters:
  /// - [methodMirror]: The mirror representing the method to generate.
  /// - [parentElement]: Optional analyzer element corresponding to the containing
  ///   class or interface; used to provide richer type information.
  /// - [package]: The package context to resolve types and annotations.
  /// - [libraryUri]: URI of the library containing the method, used for caching
  ///   and source resolution.
  /// - [sourceUri]: URI of the source file for the method.
  /// - [className]: Name of the class containing the method.
  /// - [parentClass]: Optional [ClassDeclaration] of the parent class for linking.
  ///
  /// Returns: A fully populated [MethodDeclaration] object representing the method.
  @protected
  Future<MethodDeclaration> generateMethod(mirrors.MethodMirror methodMirror, InterfaceElement? parentElement, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass);
}

/// Helper class representing a **fully materialized function signature**.
///
/// `_FunctionSignature` aggregates all information required to describe a
/// function, method, or callable entity in a uniform, runtime-friendly form.
/// It is used internally for invocation modeling, signature comparison, and
/// runtime linking.
///
/// This class captures both structural and semantic properties of a function
/// without embedding executable logic.
///
/// ## Fields
///
/// - [returnType]  
///   The return type of the function, represented as a [LinkDeclaration].
///   May be `null` when the return type is implicit or unresolved.
///
/// - [parameters]  
///   A list of parameter type declarations, in declaration order.
///
/// - [typeParameters]  
///   A list of generic type parameter declarations defined by the function.
///
/// - [typeArguments]  
///   The concrete type arguments applied to the function, if any.
///
/// - [isNullable]  
///   Indicates whether the function’s return type is nullable.
///
/// - [displayName]  
///   A human-readable signature name used for diagnostics and debugging.
///
/// - [isSynthetic]  
///   Indicates whether the function is compiler-generated or synthetic.
///
/// Instances of this class are typically produced during reflection or
/// analyzer passes and consumed by invocation dispatch or signature matching
/// logic.
class _FunctionSignature {
  final LinkDeclaration returnType;
  final List<LinkDeclaration> parameters;
  final List<LinkDeclaration> typeParameters;
  final List<LinkDeclaration> typeArguments;
  final bool isNullable;
  final String displayName;
  final bool isSynthetic;

  _FunctionSignature({
    required this.returnType,
    required this.parameters,
    required this.typeParameters,
    required this.isNullable,
    required this.displayName,
    required this.isSynthetic,
    required this.typeArguments,
  });
}