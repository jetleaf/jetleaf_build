import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../declaration/declaration.dart';
import 'abstract_link_declaration_support.dart';
import 'abstract_material_library_analyzer_support.dart';

/// {@template abstract_function_link_declaration_support}
/// Abstract base class providing **function-type link generation support**
/// for the JetLeaf linking and runtime reflection system.
///
/// `AbstractFunctionDeclarationSupport` specializes
/// [AbstractLinkDeclarationSupport] with comprehensive logic for resolving,
/// normalizing, and materializing **function and callable type declarations**
/// from both **Dart runtime mirrors** and **analyzer `AnalyzedTypeAnnotation`s**.
///
/// ## Responsibilities
/// This class is responsible for:
/// - Translating `FunctionTypeMirror` and analyzer `AnalyzedTypeAnnotation` instances
///   into canonical [FunctionDeclaration] objects.
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
abstract class AbstractFunctionDeclarationSupport extends AbstractLinkDeclarationSupport {
  /// {@macro abstract_function_link_declaration_support}
  AbstractFunctionDeclarationSupport();

  @override
  FunctionDeclaration? generateFunctionDeclaration(mirrors.TypeMirror mirror, AnalyzedGenericFunctionTypeAnnotation? dartType, String libraryUri) {
    if (mirror case mirrors.FunctionTypeMirror functionTypeMirror) {
      return generateFunctionDeclarationFromMirror(functionTypeMirror, dartType, libraryUri);
    } else if (dartType case final functionType?) {
      return _generateFunctionDeclarationFromDartType(functionType, libraryUri, mirror);
    }

    return null;
  }

  /// Generates a [FunctionDeclaration] from a runtime mirror.
  ///
  /// {@template generate_function_from_mirror}
  /// This method converts a [mirrors.FunctionTypeMirror] and optional analyzer
  /// [AnalyzedTypeAnnotation] into a fully materialized [FunctionDeclaration].
  ///
  /// It performs the following steps:
  /// 1. Computes a stable **identity** for cycle detection.
  /// 2. Extracts the function signature using [_extractFunctionSignatureFromMirror],
  ///    including return type, parameters, type parameters, nullability, and synthetic status.
  /// 3. Constructs a [StandardFunctionDeclaration] with all collected information.
  /// 4. Optionally links a [MethodDeclaration] if the function corresponds to a method.
  ///
  /// ### Parameters
  /// - [functionTypeMirror]: The runtime reflection mirror for the function type.
  /// - [dartType]: Optional analyzer [AnalyzedTypeAnnotation] for additional metadata.
  /// - [libraryUri]: URI of the library containing this function.
  ///
  /// ### Returns
  /// A [Future] completing with a fully initialized [FunctionDeclaration].
  ///
  /// ### Example
  /// ```dart
  /// final mirror = reflectType(void Function(int)) as FunctionTypeMirror;
  /// final functionLink = generateFunctionDeclarationFromMirror(
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
  FunctionDeclaration generateFunctionDeclarationFromMirror(mirrors.FunctionTypeMirror functionTypeMirror, AnalyzedGenericFunctionTypeAnnotation? dartType, String libraryUri) {
    final typeIdentity = _buildFunctionTypeIdentity(functionTypeMirror, dartType, libraryUri);
    linkGenerationInProgress.add(typeIdentity);
    final resolvedLibraryUri = findRealClassUriFromMirror(functionTypeMirror) ?? Uri.parse(libraryUri);
    final uriString = resolvedLibraryUri.toString();
    final name = mirrors.MirrorSystem.getName(functionTypeMirror.simpleName);
    final generatedClass = dartType != null ? null : generateClass(functionTypeMirror, uriString, resolvedLibraryUri, isBuiltInDartLibrary(resolvedLibraryUri), false);

    final functionAlias = getAnalyzedTypeAliasDeclaration(name, resolvedLibraryUri);

    try {
      // Extract function signature information
      final signature = _extractFunctionSignatureFromMirror(functionTypeMirror, uriString, functionAlias?.returnType ?? dartType);
      final functionUri = findRealClassUriFromMirror(mirrors.reflectType(Function))?.toString() ?? uriString;

      if (generatedClass == null) {
        return StandardFunctionDeclaration(
          returnType: signature.returnType,
          linkParameters: signature.parameters,
          typeParameters: signature.typeParameters,
          typeArguments: signature.typeArguments,
          isNullable: signature.isNullable,
          name: functionAlias?.name.lexeme ?? dartType?.functionKeyword.lexeme ?? signature.displayName,
          type: Function,
          pointerType: Function,
          qualifiedName: buildQualifiedName("Function", functionUri),
          canonicalUri: Uri.tryParse(functionUri),
          referenceUri: Uri.tryParse(functionUri),
          isPublic: true,
          isSynthetic: signature.isSynthetic,
          library: getLibrary(functionUri),
          methodDeclaration: generateMethod(
            functionTypeMirror.callMethod,
            null,
            functionUri,
            functionTypeMirror.location?.sourceUri ?? Uri.parse(functionUri),
            signature.displayName,
            null
          ),
        );
      }

      // Build the final function link
      final result = StandardFunctionDeclaration(
        returnType: signature.returnType,
        linkParameters: signature.parameters,
        typeParameters: signature.typeParameters,
        typeArguments: signature.typeArguments,
        isNullable: signature.isNullable,
        name: functionAlias?.name.lexeme ?? dartType?.functionKeyword.lexeme ?? signature.displayName,
        type: Function,
        pointerType: Function,
        qualifiedName: buildQualifiedName("Function", functionUri),
        canonicalUri: Uri.tryParse(functionUri),
        referenceUri: Uri.tryParse(functionUri),
        isPublic: true,
        isSynthetic: signature.isSynthetic,
        library: getLibrary(functionUri),
        kind: TypeKind.typedef,
        methodDeclaration: generateMethod(
          functionTypeMirror.callMethod,
          null,
          functionUri,
          functionTypeMirror.location?.sourceUri ?? Uri.parse(functionUri),
          signature.displayName,
          null
        ),
        isAbstract: generatedClass.getIsAbstract(),
        isBase: generatedClass.getIsBase(),
        isFinal: generatedClass.getIsFinal(),
        isInterface: generatedClass.getIsInterface(),
        isMixin: generatedClass.getIsMixin(),
        isRecord: generatedClass.getIsRecord(),
        isSealed: generatedClass.getIsSealed(),
        interfaces: generatedClass.getInterfaces(),
        packageUri: generatedClass.getPackageUri(),
        annotations: generatedClass.getAnnotations(),
        simpleName: generatedClass.getSimpleName(),
        sourceLocation: generatedClass.getSourceLocation(),
        superClass: generatedClass.getSuperClass(),
        fields: generatedClass.getFields(),
        constructors: generatedClass.getConstructors(),
        methods: generatedClass.getMethods(),
        mixins: generatedClass.getMixins()
      );

      result.parameters = extractParameters(functionTypeMirror.parameters, functionAlias?.parameters, libraryUri, result);
      return result;
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
  /// - [libraryUri] — The URI of the declaring library.
  /// - [dartType] — The analyzer-based function type, if available.
  ///
  /// ### Returns
  /// A [_FunctionSignature] describing the function’s complete type shape.
  _FunctionSignature _extractFunctionSignatureFromMirror(mirrors.FunctionTypeMirror mirror, String libraryUri, AnalyzedTypeAnnotation? dartType) {
    // Get return type
    final returnTypeLink = getLinkDeclaration(mirror.returnType, libraryUri, dartType);
    
    // Get parameters
    final parameters = <LinkDeclaration>[];
    final mirrorParameters = mirror.parameters;
    for (int i = 0; i < mirrorParameters.length; i++) {
      final param = mirrorParameters[i];
      final paramLink = getLinkDeclaration(param.type, libraryUri, null);
      parameters.add(paramLink);
    }

    // Get type parameters
    final typeParameters = <LinkDeclaration>[];
    if (mirror is mirrors.MethodMirror) {
      final mirrorVariables = mirror.typeVariables;
      final dartTypeParameters = dartType is AnalyzedGenericFunctionTypeAnnotation 
        ? dartType.typeParameters?.typeParameters ?? <AnalyzedTypeParameter>[] 
        : <AnalyzedTypeParameter>[];

      for (int i = 0; i < mirrorVariables.length; i++) {
        final variable = mirrorVariables[i];
        final variableName = mirrors.MirrorSystem.getName(variable.simpleName);
        final variableType = dartTypeParameters.where((p) => p.name.toString() == variableName).firstOrNull;
        
        final typeParamLink = generateLinkDeclaration(variable, libraryUri, variableType?.bound);
        if (typeParamLink != null) {
          typeParameters.add(typeParamLink);
        }
      }
    }

    final typeArguments = extractTypeArgumentAsLinks(mirror.typeArguments, [], libraryUri);

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
      isNullable: checkTypeAnnotationNullable(dartType) || isNullable,
      displayName: displayName,
      isSynthetic: isSynthetic(displayName),
      typeArguments: typeArguments
    );
  }

  /// Generates a [FunctionDeclaration] from an analyzer-based
  /// [AnalyzedGenericFunctionTypeAnnotation].
  ///
  /// This method acts as the **analyzer-first counterpart** to
  /// `_extractFunctionSignatureFromMirror`, constructing a concrete
  /// [FunctionDeclaration] using static analyzer metadata when reflection
  /// data is unavailable, incomplete, or intentionally bypassed.
  ///
  /// The method:
  /// - Resolves the function’s return type
  /// - Resolves positional parameter types
  /// - Resolves generic type parameter bounds
  /// - Computes nullability from analyzer annotations
  /// - Derives a stable, canonical function identity
  ///
  /// To prevent infinite recursion when resolving self-referential or
  /// mutually recursive function types, the method maintains an
  /// **in-progress generation guard** keyed by a unique function type
  /// identity. If generation is already underway, `null` is returned to
  /// allow upstream callers to short-circuit safely.
  ///
  /// Reflection metadata may be optionally provided to improve URI and
  /// library resolution, but analyzer data remains the authoritative
  /// source for the function’s type shape.
  ///
  /// ### Parameters
  /// - [functionType] — The analyzer-based generic function type.
  /// - [libraryUri] — The URI of the declaring library.
  /// - [mirror] — Optional reflection mirror used for URI resolution.
  ///
  /// ### Returns
  /// A fully populated [FunctionDeclaration] if generation succeeds;
  /// otherwise `null` if the function type is currently being generated
  /// or cannot be resolved.
  ///
  /// ### Notes
  /// - This method is cycle-safe and may return `null` during recursive
  ///   resolution.
  /// - The returned declaration represents a **canonical runtime
  ///   function type**, not a callable symbol.
  FunctionDeclaration? _generateFunctionDeclarationFromDartType(AnalyzedGenericFunctionTypeAnnotation functionType, String libraryUri, [mirrors.TypeMirror? mirror]) {
    // Create a unique key for this function type
    final typeKey = 'dart_func_${getNameFromAnalyzedTypeAnnotation(functionType)}_${functionType.hashCode}';
    
    // Check if we're already processing this function type
    if (linkGenerationInProgress.contains(typeKey)) {
      return null;
    }
    // Mark as in progress
    linkGenerationInProgress.add(typeKey);
    
    try {
      // Get return type
      final returnTypeLink = _generateLinkDeclarationFromDartType(functionType, libraryUri);

      // Get parameter types
      final parameterLinks = <LinkDeclaration>[];
      for (final param in functionType.parameters.parameters) {
        if (getAnalyzedTypeAnnotationFromParameter(param) case final paramType?) {
          final paramTypeLink = _generateLinkDeclarationFromDartType(paramType, libraryUri);
        
          if (paramTypeLink case final typed?) {
            parameterLinks.add(typed);
          }
        }
      }

      // Get type parameters
      final typeParamLinks = <LinkDeclaration>[];
      for (final typeParam in functionType.typeParameters?.typeParameters ?? <AnalyzedTypeParameter>[]) {
        if (typeParam.bound case final dartType?) {
          final typeParamLink = _generateLinkDeclarationFromDartType(dartType, libraryUri);
          if (typeParamLink != null) {
            typeParamLinks.add(typeParamLink);
          }
        }
      }

      // Build the function signature
      if (returnTypeLink != null) {
        final signature = getNameFromAnalyzedTypeAnnotation(functionType);
        final functionUri = findRealClassUriFromMirror(mirrors.reflectType(Function))?.toString() ?? libraryUri;

        return StandardFunctionDeclaration(
          returnType: returnTypeLink,
          linkParameters: parameterLinks,
          typeParameters: typeParamLinks,
          isNullable: checkTypeAnnotationNullable(functionType),
          name: signature,
          type: Function,
          pointerType: Function,
          qualifiedName: buildQualifiedName("Function", functionUri),
          canonicalUri: Uri.tryParse(functionUri),
          referenceUri: Uri.tryParse(functionUri),
          isPublic: true,
          library: getLibrary(functionUri),
          isSynthetic: isSynthetic(getNameFromAnalyzedTypeAnnotation(functionType)),
        );
      } else {
        return null;
      }
    } finally {
      // Always remove from in-progress set
      linkGenerationInProgress.remove(typeKey);
    }
  }

  /// Generates a [LinkDeclaration] from an analyzer [AnalyzedTypeAnnotation], with **cycle detection**.
  ///
  /// This method handles:
  /// - Function types (`AnalyzedTypeAnnotation`) by delegating to `_generateFunctionDeclarationFromDartType`.
  /// - Parameterized types, recursively generating links for type arguments.
  /// - Type parameters, including variance and upper bound resolution.
  /// - Cycle detection to avoid infinite recursion in recursive type definitions.
  ///
  /// Parameters:
  /// - [dartType]: The analyzer [AnalyzedTypeAnnotation] representing the type to generate a link for.
  /// - [libraryUri]: URI of the library where the type is declared.
  /// - [mirror]: Optional [mirrors.TypeMirror] to supplement type resolution from runtime mirrors.
  ///
  /// Returns a [Future] that completes with the generated [LinkDeclaration], or `null`
  /// if the type cannot be resolved.
  LinkDeclaration? _generateLinkDeclarationFromDartType(AnalyzedTypeAnnotation dartType, String libraryUri, [mirrors.TypeMirror? mirror]) {
    if (dartType is AnalyzedGenericFunctionTypeAnnotation) {
      return _generateFunctionDeclarationFromDartType(dartType, libraryUri, mirror);
    }

    final name = getNameFromAnalyzedTypeAnnotation(dartType);
    // Create a unique key for this type to detect cycles
    final typeKey = '${libraryUri}_${name}_$name';
    
    // Check if we're already processing this type (cycle detection)
    if (linkGenerationInProgress.contains(typeKey)) {
      return null; // Break the cycle
    }
    
    // Mark as in progress
    linkGenerationInProgress.add(typeKey);
    
    try {
      // Find the real class in the runtime system to get the actual package URI
      final realClassUri = findRealClassUri(name, libraryUri.toString())?.toString();

      // Get the actual runtime type for this AnalyzedTypeAnnotation
      final actualRuntimeType = findRuntimeTypeFromDartType(dartType, libraryUri);
      
      // Get the base type (without type parameters)
      final baseRuntimeType = findBaseRuntimeTypeFromDartType(dartType, libraryUri);
      final realPackageUri = realClassUri ?? libraryUri;

      // Get type arguments from the implementing class (with cycle protection)
      final typeArguments = <LinkDeclaration>[];
      if (dartType is AnalyzedNamedType && dartType.typeArguments != null) {
        for (final arg in dartType.typeArguments!.arguments) {
          final argKey = '${libraryUri}_${getNameFromAnalyzedTypeAnnotation(arg)}';
          if (!linkGenerationInProgress.contains(argKey)) {
            final argLink = mirror != null 
              ? getLinkDeclaration(mirror, libraryUri, arg)
              : _generateLinkDeclarationFromDartType(arg, libraryUri);
            
            if (argLink != null) {
              typeArguments.add(argLink);
            }
          }
        }
      }

      final displayString = getClassNameFromDartType(dartType, libraryUri) ?? getNameFromAnalyzedTypeAnnotation(dartType);

      return StandardLinkDeclaration(
        name: getNameFromAnalyzedTypeAnnotation(dartType),
        type: actualRuntimeType,
        pointerType: baseRuntimeType,
        typeArguments: typeArguments,
        qualifiedName: buildQualifiedName(displayString, realPackageUri),
        canonicalUri: Uri.tryParse(realPackageUri),
        referenceUri: Uri.tryParse(libraryUri),
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
        ? 'Function()'
        : 'Function(${parameters.map((p) => p.getName()).join(', ')})';
    
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
  String _buildFunctionTypeIdentity(mirrors.TypeMirror mirror, AnalyzedTypeAnnotation? dartType, String libraryUri) {
    final mirrorName = mirrors.MirrorSystem.getName(mirror.simpleName);
    final mirrorHash = mirror.hashCode;
    
    if (dartType != null) {
      final dartName = getNameFromAnalyzedTypeAnnotation(dartType);
      final dartHash = dartType.hashCode;
      return 'func_${mirrorName}_${dartName}_${mirrorHash}_${dartHash}_$libraryUri';
    }
    
    return 'func_mirror_${mirrorName}_${mirrorHash}_$libraryUri';
  }

  /// Generates a [MethodDeclaration] for a class or instance method using
  /// Dart reflection (`mirrors`) and analyzer support.
  ///
  /// This method combines information from a [mirrors.MethodMirror] and an
  /// optional analyzer [AnalyzedMemberList] (if available) to build a complete
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
  /// - [members]: Optional analyzer element corresponding to the containing
  ///   class or interface; used to provide richer type information.
  /// - [libraryUri]: URI of the library containing the method, used for caching
  ///   and source resolution.
  /// - [sourceUri]: URI of the source file for the method.
  /// - [className]: Name of the class containing the method.
  /// - [parentClass]: Optional [LinkDeclaration] of the parent class for linking.
  ///
  /// Returns: A fully populated [MethodDeclaration] object representing the method.
  @protected
  MethodDeclaration generateMethod(mirrors.MethodMirror methodMirror, AnalyzedMemberList? members, String libraryUri, Uri sourceUri, String className, LinkDeclaration? parentClass);

  /// Generates a JetLeaf [`ClassDeclaration`] by combining mirrors-based
  /// reflection, static analyzer metadata, source parsing, and JetLeaf’s
  /// declaration synthesis rules.
  ///
  /// This method is the primary workhorse for class modeling: it takes a
  /// runtime [`ClassMirror`] and a linked analyzer [`ClassElement`] (when
  /// available), merges their information, and produces a complete normalized
  /// representation suitable for further processing throughout the JetLeaf
  /// pipeline.
  ///
  /// ### What This Method Resolves
  ///
  /// **1. Type Metadata**
  /// - Determines the runtime type (reflected or inferred).
  /// - Applies JetLeaf's generic-type resolution (`@Generic(...)`).
  /// - Extracts analyzer type metadata (`InterfaceType`).
  ///
  /// **2. Class Annotations**
  /// - Merges mirror metadata with static analyzer metadata.
  /// - Expands annotations into canonical JetLeaf annotation declarations.
  ///
  /// **3. Inheritance Structure**
  /// Uses JetLeaf’s link-resolution helpers to map:
  /// - `extends` → `superClass`
  /// - `implements` → `interfaces`
  /// - `with` → `mixins`
  ///
  /// All members are returned as `LinkDeclaration` objects ensuring stability
  /// across mirrors, analyzer types, and different compilation environments.
  ///
  /// **4. Member Extraction**
  /// The method iterates over the mirror's declarations:
  /// - Constructors → via [`generateConstructor`]
  /// - Fields → via [`generateField`]
  /// - Methods → via [`generateMethod`]
  ///
  /// Each member is resolved using both reflection and analyzer metadata where
  /// possible, guaranteeing accurate type information, nullability, synthetic
  /// status, and access modifiers.
  ///
  /// **5. Class Modifiers**
  /// Uses analyzer metadata when present, but falls back to JetLeaf’s
  /// source-parsing utilities for environments where reflection does not expose
  /// modifier flags:
  /// - `abstract`
  /// - `base`
  /// - `interface`
  /// - `sealed`
  /// - `final`
  /// - `mixin class` detection
  ///
  /// **6. Synthetic & Public Flags**
  /// Determined through analyzer API when available, otherwise inferred via
  /// JetLeaf's naming conventions (`_internal` / leading underscores).
  ///
  /// ### Parameters
  /// - **[classMirror]**  
  ///   The runtime reflection descriptor for the class.
  ///
  /// - **[libraryUri]**  
  ///   The canonical URI of the parent library in string form.
  ///
  /// - **[sourceUri]**  
  ///   The URI of the original source file, used for source-based modifier
  ///   detection and accurate error reporting.
  ///
  /// - **[isBuiltIn]**  
  ///   Signals whether the class originates from SDK/Built-in libraries,
  ///   affecting how members are extracted and how synthetic status is
  ///   determined.
  ///
  /// ### Returns
  /// A fully synthesized, analyzer-integrated [`ClassDeclaration`] containing:
  /// - Full inheritance graph
  /// - Constructors
  /// - Fields
  /// - Methods
  /// - Annotations
  /// - Type arguments
  /// - Modifier flags
  /// - Source location metadata
  ///
  /// ### Notes
  /// - This method updates the global [`typeCache`] so future lookups for the
  ///   same type reuse the declaration instead of re-reflecting.
  /// - Any missing analyzer information is gracefully handled; JetLeaf
  ///   prioritizes analyzer metadata but falls back to mirrors and source
  ///   parsing.
  /// - This method does **not** process record types embedded in classes; record
  ///   extraction is delegated elsewhere in the pipeline.
  @protected
  ClassDeclaration generateClass(mirrors.ClassMirror classMirror, String libraryUri, Uri sourceUri, bool isBuiltIn, [bool treatFunctionAsItsOwnClass = true]);

  /// Extracts a list of parameter declarations from mirrors and analyzer elements.
  ///
  /// This method produces a list of [ParameterDeclaration]s for a given method,
  /// constructor, or top-level function. It combines runtime reflection information
  /// from [mirrorParams] with static analyzer metadata from [analyzerParams] to provide
  /// fully-resolved types, nullability, default values, and annotations.
  ///
  /// It also performs:
  /// - Nullability detection via AST parsing and fallback source code checks.
  /// - Generic type resolution using [GenericTypeParser].
  /// - Annotation extraction for each parameter.
  ///
  /// # Parameters
  /// - [mirrorParams]: List of [mirrors.ParameterMirror] representing the runtime parameters.
  /// - [analyzerParams]: Optional list of [AnalyzedFormalParameterList] from the analyzer.
  /// - [libraryUri]: The URI of the library containing the parameters.
  /// - [parentMember]: The [MemberDeclaration] (method, constructor, or function) these parameters belong to.
  ///
  /// # Returns
  /// A [Future] that completes with a list of [ParameterDeclaration]s representing
  /// all parameters for the specified member.
  @protected
  List<ParameterDeclaration> extractParameters(List<mirrors.ParameterMirror> mirrorParams, AnalyzedFormalParameterList? analyzerParams, String libraryUri, MemberDeclaration parentMember);
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