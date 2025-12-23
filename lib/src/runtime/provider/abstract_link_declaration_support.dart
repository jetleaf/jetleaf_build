// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../../classes.dart';
import '../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import 'abstract_type_support.dart';
import 'abstract_material_library_analyzer_support.dart';

/// {@template abstract_link_declaration_support}
/// Abstract support class for generating [LinkDeclaration] objects in JetLeaf.
///
/// This class serves as a central helper for converting Dart types (from both
/// analyzer elements and mirrors) into standardized [LinkDeclaration] representations.
/// It handles the complexities of Dart's type system, including:
/// 
/// - **Cycle detection**: Prevents infinite recursion when types reference themselves,
///   such as in recursive generics or bounded type parameters.
/// - **Caching**: Stores previously generated link declarations to avoid redundant computation.
/// - **Type resolution**: Resolves runtime types from both analyzer [AnalyzedTypeAnnotation] and mirrors,
///   including handling of generics, parameterized types, function types, and special types
///   like `dynamic` and `void`.
/// - **Variance inference**: Supports variance for type parameters (covariant, contravariant, invariant),
///   inferred from the context or declared bounds.
/// - **Upper bounds and type arguments**: Extracts and generates link declarations for
///   type arguments, type parameter bounds, supertypes, interfaces, mixins, and constraints.
/// - **Mirror & Analyzer dual support**: Works seamlessly with both `dart:mirrors`
///   and `package:analyzer` element models, allowing JetLeaf to operate in runtime
///   reflection or source analysis contexts.
///
/// Subclasses are expected to implement certain abstract methods such as
/// [extractAnnotations] for retrieving annotation metadata, and may extend
/// this class for framework-specific type linking behavior.
///
/// ### Responsibilities
/// 1. Generate link declarations from `AnalyzedTypeAnnotation` or mirror objects.
/// 2. Maintain caches to avoid repeated computation and infinite recursion.
/// 3. Resolve runtime types accurately, including generics and specialized types.
/// 4. Infer type variances and bounds for proper type representation.
/// 5. Build fully qualified names and URIs for type declarations.
/// 6. Handle function types, including parameter types, return types, and generic type parameters.
///
/// ### Caching and Cycle Detection
/// The class uses two primary mechanisms to ensure correctness and performance:
/// 
/// - [linkGenerationInProgress]: A `Set<String>` of unique type keys currently being
///   processed. Before generating a link declaration, the class checks if the type key
///   is present; if so, the generation is skipped to break recursion cycles.
///
/// These mechanisms ensure that recursive or cyclic type structures are handled
/// safely without crashing the framework.
///
/// ### Example Usage
/// ```dart
/// final linkSupport = MyLinkDeclarationSupport(...);
/// final link = linkSupport.generateLinkDeclarationFromDartType(myDartType, myPackage, 'package:my_pkg');
/// ```
///
/// The class is abstract; concrete subclasses must implement [extractAnnotations] and
/// can override other methods for framework-specific behavior.
/// {@endtemplate}
abstract class AbstractLinkDeclarationSupport extends AbstractTypeSupport {
  /// Tracks types currently being processed to prevent infinite recursion.
  ///
  /// When generating link declarations, certain types may reference themselves
  /// either directly or indirectly (via type arguments or bounds).  
  /// This set stores unique keys representing the type currently being processed.
  /// If a type key is already present in this set, cycle detection logic
  /// will skip further processing for that type.
  final Set<String> linkGenerationInProgress = {};

  /// {@macro abstract_link_declaration_support}
  AbstractLinkDeclarationSupport();

  /// Clears all **processing caches** used during link declaration generation.
  ///
  /// This method should be called when starting to process a new library or module to
  /// prevent stale or cross-library cached data from affecting the current processing.
  ///
  /// Clears:
  /// - [linkGenerationInProgress]: Tracks type keys currently being processed to prevent cycles.
  @protected
  void clearProcessingCaches() {
    linkGenerationInProgress.clear();
  }

  /// Retrieves a [LinkDeclaration] for a given type, using either the analyzer [AnalyzedTypeAnnotation]
  /// or mirror [mirrors.TypeMirror] as the source of truth. Handles special types and provides
  /// fallbacks for unknown types.
  ///
  /// - [typeMirror]: The mirror representing the type at runtime.
  /// - [libraryUri]: The URI of the library containing the type.
  /// - [dartType]: Optional analyzer [AnalyzedTypeAnnotation] for more precise resolution.
  ///
  /// Workflow:
  /// 1. If a [AnalyzedTypeAnnotation] is provided, attempts to generate a link declaration from it.
  /// 2. Otherwise, attempts to generate from the mirror.
  /// 3. If generation fails, checks for special cases:
  ///    - `dynamic` → creates a dynamic declaration.
  ///    - `void` → creates a void declaration.
  ///    - Otherwise, falls back to a generic Object declaration.
  ///
  /// Returns a [LinkDeclaration] representing the type.
  @protected
  LinkDeclaration getLinkDeclaration(mirrors.TypeMirror typeMirror, String libraryUri, [AnalyzedTypeAnnotation? dartType]) {
    if (generateLinkDeclaration(typeMirror, libraryUri, dartType) case final result?) {
      return result;
    }

    // Check for special cases where we need custom handling
    final typeName = mirrors.MirrorSystem.getName(typeMirror.simpleName);
      
    // Handle dynamic type
    if (typeName == 'dynamic' || typeName == 'Dynamic') {
      return _createDynamicDeclaration();
    }
    
    // Handle void type
    if (typeName == 'void' || typeName == 'Void') {
      return _createVoidDeclaration();
    }
    
    return _createDefaultLinkDeclaration();
  }

  /// Creates a [LinkDeclaration] representing the Dart `void` type.
  ///
  /// This method is used internally by the type-linking and resolution system
  /// when a type cannot be resolved through normal means, but is explicitly
  /// recognized as `void`.
  ///
  /// Unlike user-defined or library types, `void` has no members, no generic
  /// parameters, and no instantiable representation. This declaration exists
  /// solely to preserve type correctness and allow the linker to continue
  /// operating without failure.
  ///
  /// ### Characteristics
  /// - Represents the built-in `void` type
  /// - Contains no type arguments
  /// - Uses `Void` as both the runtime and pointer type
  /// - Marked as public and non-synthetic
  ///
  /// ### Usage Context
  /// This declaration is typically produced when:
  /// - Resolving return types of methods that explicitly return `void`
  /// - Handling unresolved symbols that are semantically known to be `void`
  ///
  /// ### Returns
  /// A [LinkDeclaration] describing the `void` type.
  LinkDeclaration _createVoidDeclaration() => StandardLinkDeclaration(
    name: 'void',
    type: Void,
    pointerType: Void,
    typeArguments: [],
    qualifiedName: Void.getQualifiedName(),
    canonicalUri: Void.getUri(),
    referenceUri: Void.getUri(),
    isPublic: true,
    isSynthetic: false,
  );

  /// Creates a [LinkDeclaration] representing the Dart `dynamic` type.
  ///
  /// This method is used internally when a type cannot be statically resolved
  /// and is determined to be `dynamic`. The `dynamic` type disables static
  /// checking and allows any operation at runtime.
  ///
  /// This declaration ensures that dynamic typing is explicitly modeled within
  /// the linking system rather than treated as an error or unresolved symbol.
  ///
  /// ### Characteristics
  /// - Represents the built-in `dynamic` type
  /// - Contains no type arguments
  /// - Uses `Dynamic` as both the runtime and pointer type
  /// - Marked as public and non-synthetic
  ///
  /// ### Usage Context
  /// This declaration is typically produced when:
  /// - A type is inferred as `dynamic`
  /// - Static type information is intentionally unavailable
  /// - Interoperating with loosely typed or reflective code
  ///
  /// ### Returns
  /// A [LinkDeclaration] describing the `dynamic` type.
  LinkDeclaration _createDynamicDeclaration() => StandardLinkDeclaration(
    name: 'dynamic',
    type: Dynamic,
    pointerType: Dynamic,
    typeArguments: [],
    qualifiedName: Dynamic.getQualifiedName(),
    canonicalUri: Dynamic.getUri(),
    referenceUri: Dynamic.getUri(),
    isPublic: true,
    isSynthetic: false,
  );

  /// Creates a fallback [LinkDeclaration] representing Dart’s `Object` type.
  ///
  /// This method acts as a **last-resort safety mechanism** when type resolution
  /// fails completely and the type cannot be identified as `void` or `dynamic`.
  ///
  /// Using `Object` ensures that the linker always produces a valid type
  /// declaration, preserving runtime stability and preventing hard failures
  /// during linking or code generation.
  ///
  /// ### Characteristics
  /// - Represents `Object` from `dart:core`
  /// - Has no generic parameters
  /// - Used only when no more specific type can be resolved
  /// - Marked as public and non-synthetic
  ///
  /// ### Usage Context
  /// This declaration is typically produced when:
  /// - A referenced type cannot be found
  /// - Metadata is incomplete or corrupted
  /// - Defensive fallback behavior is required
  ///
  /// ### Returns
  /// A [LinkDeclaration] describing the `Object` type.
  LinkDeclaration _createDefaultLinkDeclaration() => StandardLinkDeclaration(
    name: 'Object',
    type: Object,
    pointerType: Object,
    qualifiedName: buildQualifiedName('Object', findRealClassUriFromMirror(mirrors.reflectType(Object))?.toString() ?? 'dart:core'),
    isPublic: true,
    isSynthetic: false,
  );

  /// Extracts **type arguments** (generic type parameters) as a list of [LinkDeclaration]s,
  /// with cycle detection to avoid infinite recursion when processing recursive or mutually
  /// referencing type parameters.
  ///
  /// - [mirrorTypeVars]: List of [mirrors.TypeVariableMirror] objects representing the type parameters
  ///   at runtime (from mirrors).
  /// - [analyzerTypeParams]: Optional list of [TypeParameterElement] objects from analyzer
  ///   metadata for additional type information.
  /// - [libraryUri]: The URI of the library where the type parameters are declared.
  ///
  /// For each type parameter:
  /// 1. Determines a unique key to prevent cycles.
  /// 2. Resolves the upper bound of the type parameter (either from mirror or analyzer).
  /// 3. Infers the variance of the type parameter (covariant, contravariant, invariant).
  /// 4. Creates a [StandardLinkDeclaration] representing the type parameter.
  ///
  /// Returns a list of [LinkDeclaration] objects for all type arguments. Returns an empty
  /// list if there are no type parameters.
  @protected
  List<LinkDeclaration> extractTypeVariableAsLinks(List<mirrors.TypeVariableMirror> mirrorTypeVars, AnalyzedTypeParameterList? analyzerTypeParams, String libraryUri) {
    final typeArgs = <LinkDeclaration>[];
  
    for (int i = 0; i < mirrorTypeVars.length; i++) {
      final mirrorTypeVar = mirrorTypeVars[i];
      final type = mirrorTypeVar.hasReflectedType ? mirrorTypeVar.reflectedType : Object;
      String typeVarName = mirrors.MirrorSystem.getName(mirrorTypeVar.simpleName);
      if (isMirrorSyntheticType(typeVarName)) {
        typeVarName = "Object";
      }

      // final analyzerTypeParam = _getParameter(typeVarName, i, analyzerTypeParams);
      final typeKey = 'typevar_${typeVarName}_${libraryUri}_$i';
    
      // Skip if already processing to prevent infinite recursion
      if (linkGenerationInProgress.contains(typeKey)) {
        continue;
      }
    
      // Mark as in progress
      linkGenerationInProgress.add(typeKey);
    
      try {
        final typeArgLink = StandardLinkDeclaration(
          name: typeVarName,
          type: type,
          pointerType: type,
          typeArguments: [], // Type parameters don't have their own type arguments
          qualifiedName: buildQualifiedName(typeVarName, libraryUri),
          canonicalUri: Uri.tryParse(libraryUri),
          referenceUri: Uri.tryParse(libraryUri),
          isPublic: !isInternal(typeVarName),
          isSynthetic: isSynthetic(typeVarName),
        );
      
        typeArgs.add(typeArgLink);
      } finally {
        // Always remove from in-progress set
        linkGenerationInProgress.remove(typeKey);
      }
    }
  
    return typeArgs;
  }

  /// Extracts the **supertype** of a class as a [LinkDeclaration].
  ///
  /// This method first attempts to use the analyzer's [AnalyzedSuperClassClause] if available.
  /// If the analyzer data is not present, it falls back to using the `dart:mirrors`
  /// [mirrors.ClassMirror] to find the superclass.
  ///
  /// - [classMirror]: The mirror representing the class in the runtime system.
  /// - [analyzedClass]: The analyzer element representing the class, if available.
  /// - [libraryUri]: The URI of the library containing the class.
  ///
  /// Returns a [LinkDeclaration] representing the superclass, or `null` if the class
  /// has no superclass (e.g., `Object`) or the supertype cannot be determined.
  @protected
  LinkDeclaration? extractSupertypeAsLink(mirrors.ClassMirror classMirror, AnalyzedSuperClassClause? analyzedClass, String libraryUri) {
    if (classMirror.superclass case final superClass?) {
      final superClassName = mirrors.MirrorSystem.getName(superClass.simpleName);
      final className = mirrors.MirrorSystem.getName(classMirror.simpleName);

      final logMessage = "Extracting super class $superClassName for $className";
      RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 2);
      
      final result = RuntimeBuilder.timeExecution(() {
        return generateLinkDeclaration(superClass, libraryUri, analyzedClass?.superclass);
      });

      RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 2);
      return result.result;
    }

    return null;
  }

  /// Extracts all **interfaces** implemented by a class as a list of [LinkDeclaration]s.
  ///
  /// Uses the analyzer [AnalyzedInterfaceClause] if available, otherwise
  /// falls back to the mirror system [mirrors.ClassMirror.superinterfaces].
  ///
  /// - [classMirror]: The mirror representing the class at runtime.
  /// - [analyzedClass]: The analyzer element representing the class, if available.
  /// - [libraryUri]: The URI of the library containing the class.
  ///
  /// Returns a list of [LinkDeclaration] objects representing each interface. Returns
  /// an empty list if no interfaces are implemented or they cannot be resolved.
  @protected
  List<LinkDeclaration> extractInterfacesAsLink(mirrors.ClassMirror classMirror, AnalyzedInterfaceClause? analyzedClass, String libraryUri) {
    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);

    final logMessage = "Extracting interfaces for $className";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 2);

    final result = RuntimeBuilder.timeExecution(() {
      final interfaces = <LinkDeclaration>[];
      final superInterfaces = classMirror.superinterfaces;
      final analyzedInterfaces = analyzedClass?.interfaces.toList() ?? <AnalyzedNamedType>[];

      for (int i = 0; i < superInterfaces.length; i++) {
        final interfaceMirror = superInterfaces[i];
        final interfaceName = mirrors.MirrorSystem.getName(interfaceMirror.simpleName);
        final interfaceType = analyzedInterfaces.where((c) => getNameFromAnalyzedTypeAnnotation(c) == interfaceName).firstOrNull;

        final logMessage = "Extracting $interfaceName interface for $className";
        RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

        final result = RuntimeBuilder.timeExecution(() {
          final linked = generateLinkDeclaration(interfaceMirror, libraryUri, interfaceType);
          if (linked != null) {
            interfaces.add(linked);
          }
        });

        RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
      }

      return interfaces;
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 2);
    return result.result;
  }

  /// Extracts all **mixins** applied to a class as a list of [LinkDeclaration]s.
  ///
  /// When the analyzer [AnalyzedMixinClause] is available, it uses it to
  /// extract mixin types. There is currently no fallback for mirrors for mixins.
  ///
  /// - [classMirror]: The mirror representing the class at runtime.
  /// - [analyzedClass]: The analyzer element representing the class, if available.
  /// - [libraryUri]: The URI of the library containing the class.
  ///
  /// Returns a list of [LinkDeclaration] objects representing each mixin applied to
  /// the class. Returns an empty list if no mixins are present.
  @protected
  List<LinkDeclaration> extractMixinsAsLink(mirrors.ClassMirror classMirror, AnalyzedMixinClause? analyzedClass, String libraryUri) {
    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);

    final logMessage = "Extracting mixins for $className";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 2);

    final result = RuntimeBuilder.timeExecution(() {
      final mixins = <LinkDeclaration>[];
      final mixinMirrors = _collectMixinsFromClassMirror(classMirror, libraryUri);

      final mixinElements = analyzedClass?.mixinTypes.toList() ?? <AnalyzedNamedType>[];
      for (int i = 0; i < mixinMirrors.length; i++) {
        final mixinMirror = mixinMirrors[i];
        final mixinName = mirrors.MirrorSystem.getName(mixinMirror.simpleName);
        final mixinType = mixinElements.where((c) => getNameFromAnalyzedTypeAnnotation(c) == mixinName).firstOrNull;

        final logMessage = "Extracting $mixinName mixin for $className";
        RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

        final result = RuntimeBuilder.timeExecution(() {
          final linked = generateLinkDeclaration(mixinMirror, libraryUri, mixinType);
          if (linked != null) {
            mixins.add(linked);
          }
        });

        RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
      }
      
      return mixins;
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 2);
    return result.result;
  }

  /// Collects all *real mixin declarations* reachable from a root class mirror.
  ///
  /// This method serves as the public entry point for mixin discovery using
  /// Dart’s `mirrors` API. It initializes the traversal state and delegates
  /// the actual graph walk to [_collectMixinsRecursive].
  ///
  /// The collection process inspects:
  /// - The class itself
  /// - Its applied mixins
  /// - Its superclass hierarchy
  /// - All implemented interfaces
  ///
  /// Cycles in the inheritance graph are handled safely using a visited set.
  ///
  /// ### Parameters
  /// - [root] — The starting [mirrors.ClassMirror] from which mixin discovery
  ///   begins.
  /// - [libraryUri] — A fallback library URI used when a mirror does not expose
  ///   a source location.
  ///
  /// ### Returns
  /// A [Future] that completes with a list of [mirrors.ClassMirror] instances,
  /// each representing a *real* mixin declaration encountered during traversal.
  ///
  /// ### Notes
  /// - Only **real mixins** (as verified by source analysis) are included.
  /// - Synthetic, compiler-generated, or non-mixin classes are excluded.
  /// - The returned list preserves discovery order.
  List<mirrors.ClassMirror> _collectMixinsFromClassMirror(mirrors.ClassMirror root, String libraryUri) {
    final result = <mirrors.ClassMirror>[];
    final visited = <mirrors.ClassMirror>{};

    _collectMixinsRecursive(root, libraryUri, result, visited);
    return result;
  }

  /// Recursively traverses the class hierarchy to discover real mixin
  /// declarations.
  ///
  /// This method performs a **depth-first traversal** over the inheritance
  /// graph starting from the given [mirror]. It explores:
  ///
  /// 1. The class itself  
  /// 2. Its applied mixin  
  /// 3. Its superclass chain  
  /// 4. All implemented interfaces  
  ///
  /// Each class mirror is visited at most once to avoid infinite recursion
  /// caused by cyclic relationships.
  ///
  /// When a *real mixin* is detected, traversal **stops immediately** for that
  /// branch, since mixins do not contribute further inheritance paths.
  ///
  /// ### Parameters
  /// - [mirror] — The current [mirrors.ClassMirror] being inspected.
  /// - [libraryUri] — A fallback URI used for source lookup.
  /// - [out] — A mutable list used to collect discovered mixin mirrors.
  /// - [visited] — A set tracking visited mirrors to prevent repeated visits.
  ///
  /// ### Traversal Rules
  /// - If a mirror has already been visited, it is skipped.
  /// - If a mirror is confirmed to be a real mixin, it is added to [out]
  ///   and no further traversal is performed for that node.
  /// - Traversal continues through mixins, superclasses, and interfaces
  ///   in that order.
  void _collectMixinsRecursive(mirrors.ClassMirror mirror, String libraryUri, List<mirrors.ClassMirror> out, Set<mirrors.ClassMirror> visited) {
    if (visited.contains(mirror)) return;
    visited.add(mirror);

    // 1️⃣ Check this mirror itself
    if (_isRealMixin(mirror, libraryUri)) {
      out.add(mirror);
      return; // Important: stop here, mixins don't need further traversal
    }

    // 2️⃣ Traverse mixin
    final mixin = mirror.mixin;
    if (mixin != mirror) {
      _collectMixinsRecursive(mixin, libraryUri, out, visited);
    }

    // 3️⃣ Traverse superclass
    final superClass = mirror.superclass;
    if (superClass != null) {
      _collectMixinsRecursive(superClass, libraryUri, out, visited);
    }

    // 4️⃣ Traverse interfaces
    for (final interface in mirror.superinterfaces) {
      _collectMixinsRecursive(interface, libraryUri, out, visited);
    }
  }

  /// Determines whether a class mirror represents a **real Dart mixin
  /// declaration**.
  ///
  /// This method validates a mixin using **source-level analysis** rather than
  /// relying solely on reflection metadata. This ensures accurate detection
  /// of mixins declared with the `mixin` keyword and excludes:
  /// - Synthetic classes
  /// - Compiler-generated artifacts
  /// - Regular classes used as mixins
  ///
  /// ### Resolution Strategy
  /// 1. Reject synthetic or generated symbols.
  /// 2. Locate the source file using the mirror’s location or a fallback URI.
  /// 3. Load and cache the source code.
  /// 4. Parse the source to confirm the class is declared as a mixin.
  ///
  /// ### Parameters
  /// - [mirror] — The [mirrors.ClassMirror] to validate.
  /// - [libraryUri] — A fallback URI used when the mirror lacks source metadata.
  ///
  /// ### Returns
  /// A [Future] that completes with `true` if the mirror represents a real
  /// mixin declaration, or `false` otherwise.
  bool _isRealMixin(mirrors.ClassMirror mirror, String libraryUri) {
    final name = mirrors.MirrorSystem.getName(mirror.simpleName);
    if (isSynthetic(name)) return false;

    final uri = mirror.location?.sourceUri ?? Uri.parse(libraryUri);
    final sourceCode = readSourceCode(uri);

    return isMixinClass(sourceCode, name);
  }

  /// Extracts the **superclass constraints** of a mixin as a list of [LinkDeclaration]s.
  ///
  /// If a [AnalyzedMixinOnClause] is provided, this method uses its
  /// [AnalyzedMixinOnClause.superclassConstraints] to extract the upper bounds for the mixin.
  /// There is no mirror-based fallback for constraints.
  ///
  /// - [mixinMirror]: The mirror representing the mixin (used only for type context).
  /// - [onClause]: The analyzer element representing the mixin, if available.
  /// - [libraryUri]: The URI of the library containing the mixin.
  ///
  /// Returns a list of [LinkDeclaration] objects representing the superclass constraints
  /// of the mixin. Returns an empty list if no constraints are defined.
  @protected
  List<LinkDeclaration> extractMixinConstraintsAsLink(mirrors.ClassMirror mixinMirror, AnalyzedMixinOnClause? onClause, String libraryUri) {
    final mixinName = mirrors.MirrorSystem.getName(mixinMirror.simpleName);

    final logMessage = "Extracting mixin constraints for $mixinName";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);
    
    final result = RuntimeBuilder.timeExecution(() {
      final constraints = <LinkDeclaration>[];
      final constraintMirrors = <mirrors.ClassMirror>[];
      
      if (mixinMirror.superclass case final superClass?) {
        final superClassName = mirrors.MirrorSystem.getName(superClass.simpleName);

        if (!isSynthetic(superClassName)) {
          constraintMirrors.add(superClass);
        } else {
          constraintMirrors.addAll(_gatherConstraintsFromMirror(superClass.superinterfaces));
        }
      }

      final superConstraints = onClause?.superclassConstraints ?? <AnalyzedNamedType>[];
      for (int i = 0; i < constraintMirrors.length; i++) {
        final constraintMirror = constraintMirrors[i];
        final constraintName = mirrors.MirrorSystem.getName(constraintMirror.simpleName);
        final constraintType = superConstraints.where((c) => getNameFromAnalyzedTypeAnnotation(c) == constraintName).firstOrNull;

        final logMessage = "Extracting $constraintName mixin constraint for $mixinName";
        RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 4);

        final result = RuntimeBuilder.timeExecution(() {
          final linked = generateLinkDeclaration(constraintMirror, libraryUri, constraintType);
          if (linked != null) {
            constraints.add(linked);
          }
        });

        RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} ${result.getFormatted()}", trackWith: logMessage, level: 4);
      }

      return constraints;
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
    return result.result;
  }

  /// Extracts function type arguments and converts them into [LinkDeclaration]s.
  ///
  /// This method performs **intelligent type argument resolution** by combining
  /// reflection-based type mirrors with analyzer-based [AnalyzedTypeAnnotation] information
  /// when available.
  ///
  /// To prevent infinite recursion during link generation, each type argument
  /// is guarded by a generation key and skipped if it is already being processed.
  ///
  /// ### Resolution Strategy
  /// 1. Iterate over all reflected type arguments.
  /// 2. Attempt to match each mirror argument with a corresponding analyzer
  ///    [AnalyzedTypeAnnotation] using the display name.
  /// 3. Generate a [LinkDeclaration] for each argument.
  /// 4. Deduplicate results using a set.
  ///
  /// ### Parameters
  /// - [typeArguments] — Reflected type argument mirrors.
  /// - [dartTypeArguments] — Analyzer type arguments, if available.
  /// - [libraryUri] — The URI of the declaring library.
  ///
  /// ### Returns
  /// A [Future] that completes with a list of resolved [LinkDeclaration]s
  /// representing the function’s type arguments.
  ///
  /// ### Notes
  /// - Order is not guaranteed due to internal deduplication.
  /// - Unresolvable arguments are silently ignored.
  /// - Cycle prevention is enforced via `linkGenerationInProgress`.
  List<LinkDeclaration> extractTypeArgumentAsLinks(List<mirrors.TypeMirror> typeArguments, List<AnalyzedTypeAnnotation> dartTypeArguments, String libraryUri) {
    final typeArgumentLinks = <LinkDeclaration>{};

    for (final arg in typeArguments) {
      final argName = mirrors.MirrorSystem.getName(arg.simpleName);
      final argKey = 'mirror_arg_${argName}_${arg.hashCode}';
      final dartArg = dartTypeArguments.where((c) => getNameFromAnalyzedTypeAnnotation(c) == argName).firstOrNull;
      
      if (!linkGenerationInProgress.contains(argKey)) {
        final argLink = generateLinkDeclaration(arg, libraryUri, dartArg);
        if (argLink != null) {
          typeArgumentLinks.add(argLink);
        }
      }
    }

    return typeArgumentLinks.toList();
  }

  /// Collects all *non-synthetic constraint interfaces* from a list of
  /// [mirrors.ClassMirror]s.
  ///
  /// This method recursively traverses interface hierarchies to extract
  /// **meaningful constraint types** while filtering out synthetic or
  /// compiler-generated interfaces.
  ///
  /// Synthetic interfaces are treated as transparent wrappers and are
  /// recursively expanded until real (non-synthetic) interfaces are found.
  /// This ensures that only user-declared or semantically relevant constraint
  /// types are returned.
  ///
  /// ### Resolution Strategy
  /// For each interface in [interfaces]:
  /// 1. If the interface name is **not synthetic**, it is added directly to
  ///    the constraint list.
  /// 2. If the interface is **synthetic**, its superinterfaces are recursively
  ///    inspected instead.
  ///
  /// This approach effectively *flattens* synthetic layers in the interface
  /// graph while preserving all real constraints.
  ///
  /// ### Parameters
  /// - [interfaces] — A list of interface mirrors to inspect for constraint
  ///   resolution.
  ///
  /// ### Returns
  /// A list of [mirrors.ClassMirror] instances representing all resolved,
  /// non-synthetic constraint interfaces.
  ///
  /// ### Notes
  /// - The returned list may contain multiple constraint interfaces.
  /// - Interface order follows the depth-first traversal order.
  /// - No deduplication is performed; callers may normalize the result if
  ///   necessary.
  ///
  /// ### Example
  /// ```dart
  /// Given:
  /// class A {}
  /// class _Synthetic implements A {}
  /// class B implements _Synthetic {}
  ///
  /// final constraints = _gatherConstraintsFromMirror(BMirror.superinterfaces);
  /// Result: [AMirror]
  /// ```
  ///
  /// This method is typically used during **generic constraint resolution**
  /// or **type validation**, where synthetic interfaces must be ignored in
  /// favor of their real semantic constraints.
  List<mirrors.ClassMirror> _gatherConstraintsFromMirror(List<mirrors.ClassMirror> interfaces) {
    final constraints = <mirrors.ClassMirror>[];

    for (final interface in interfaces) {
      final className = mirrors.MirrorSystem.getName(interface.simpleName);

      if (!isSynthetic(className)) {
        constraints.add(interface);
      } else {
        constraints.addAll(_gatherConstraintsFromMirror(interface.superinterfaces));
      }
    }

    return constraints;
  }

  /// Generates a [LinkDeclaration] by intelligently combining information from runtime mirror
  /// and analyzer AnalyzedTypeAnnotation, with **mirror data taking precedence** and AnalyzedTypeAnnotation providing
  /// fallback information when mirror data is insufficient or unavailable.
  ///
  /// This unified method handles:
  /// - Function types by delegating to `gateFunctionLinkDeclaration`
  /// - Parameterized types with recursive type argument resolution
  /// - Type parameters with variance and upper bound resolution
  /// - @Generic annotations for type resolution
  /// - Robust cycle detection and caching
  /// - Intelligent fallback: Mirror → AnalyzedTypeAnnotation → defaults
  ///
  /// ## Resolution Priority
  /// 1. **Mirror data** (primary source - always available)
  /// 2. **AnalyzedTypeAnnotation data** (supplementary when mirror is incomplete or ambiguous)
  /// 3. **Defaults/inference** (when both sources lack information)
  ///
  /// ## Use Cases
  /// - Complete mirror with partial AnalyzedTypeAnnotation → Mirror data used, AnalyzedTypeAnnotation fills gaps
  /// - Mirror with ambiguous generic info + AnalyzedTypeAnnotation → Combined resolution
  /// - Mirror-only (no AnalyzedTypeAnnotation) → Mirror data used exclusively
  /// - Cyclic types → Safe termination with cycle detection
  ///
  /// Parameters:
  /// - [mirror]: Primary [mirrors.TypeMirror] source (always non-null)
  /// - [dartType]: Supplementary [AnalyzedTypeAnnotation] source (null if unavailable from analyzer)
  /// - [libraryUri]: URI of the declaring library
  ///
  /// Returns a [Future<LinkDeclaration?>] with the best possible type resolution,
  /// or null if the type cannot be resolved at all.
  @protected
  LinkDeclaration? generateLinkDeclaration(mirrors.TypeMirror mirror, String libraryUri, AnalyzedTypeAnnotation? dartType) {
    if (isReallyARecordType(mirror, dartType)) {
      return generateRecordDeclaration(mirror, libraryUri, dartType!);
    }
    
    // Handle function types specially
    if (generateFunctionDeclaration(mirror, dartType is AnalyzedGenericFunctionTypeAnnotation ? dartType : null, libraryUri) case final result?) {
      return result;
    }

    // Determine type identity for caching and cycle detection
    final typeIdentity = _buildTypeIdentity(mirror, dartType, libraryUri);
    
    // Check for cycles first
    if (linkGenerationInProgress.contains(typeIdentity)) {
      _logCycleDetection(typeIdentity, mirror, dartType);
      return null;
    }

    // Begin processing this type
    linkGenerationInProgress.add(typeIdentity);

    try {
      // PHASE 1: Extract core type information (mirror primary, AnalyzedTypeAnnotation fallback)
      final coreInfo = _extractCoreTypeInfo(mirror, dartType, libraryUri);
      
      if (coreInfo.name.isEmpty) {
        // Could not determine even basic type name
        return null;
      }

      // PHASE 2: Extract type arguments/generics (with cycle protection)
      List<LinkDeclaration> typeArguments = [];

      if (mirror is mirrors.ClassMirror) {
        final dartArgs = dartType is AnalyzedNamedType ? dartType.typeArguments?.arguments : <AnalyzedTypeAnnotation>[];
        typeArguments.addAll(extractTypeArgumentAsLinks(mirror.typeArguments, dartArgs ?? [], libraryUri));
      }

      // PHASE 4: Build the final link declaration
      return StandardLinkDeclaration(
        name: coreInfo.displayName,
        type: coreInfo.actualRuntimeType,
        pointerType: coreInfo.baseRuntimeType,
        typeArguments: typeArguments,
        qualifiedName: buildQualifiedName(coreInfo.name, coreInfo.sourceUri),
        canonicalUri: Uri.tryParse(coreInfo.sourceUri),
        referenceUri: Uri.tryParse(libraryUri),
        isPublic: _determineIsPublic(coreInfo.name, mirror, dartType),
        isSynthetic: _determineIsSynthetic(coreInfo.name, mirror, dartType),
      );

    } finally {
      // Always remove from in-progress set
      linkGenerationInProgress.remove(typeIdentity);
    }
  }

  /// Extracts **core type information** from a [mirrors.TypeMirror], with
  /// [AnalyzedTypeAnnotation] as a fallback.
  ///
  /// This method produces a fully materialized [_TypeInfo] object containing:
  /// - Canonical type name
  /// - Display-friendly name
  /// - Actual runtime type (possibly generic-aware)
  /// - Base runtime type (unparameterized)
  /// - Source URI for traceability
  ///
  /// The extraction process prefers mirror-based metadata, resolving
  /// generic annotations when present. If mirror resolution fails, the
  /// method falls back to analyzer ([AnalyzedTypeAnnotation]) metadata for robustness.
  ///
  /// ### Resolution Strategy
  /// 1. Start with mirror-based extraction:
  ///    - Extract type name and source URI
  ///    - Determine actual runtime type (with @Generic resolution)
  ///    - Determine base runtime type (original declaration for parameterized types)
  /// 2. Extract a display-friendly name:
  ///    - Prefer AnalyzedTypeAnnotation formatting when available
  /// 3. Refine source URI using AnalyzedTypeAnnotation library information if present
  ///
  /// ### Parameters
  /// - [mirror] — The reflection-based type mirror.
  /// - [dartType] — Analyzer-based type information, optional.
  /// - [libraryUri] — URI of the declaring library.
  ///
  /// ### Returns
  /// A [_TypeInfo] object representing the fully resolved type.
  _TypeInfo _extractCoreTypeInfo(mirrors.TypeMirror mirror, AnalyzedTypeAnnotation? dartType, String libraryUri) {
    // Start with mirror-based extraction
    String typeName = mirrors.MirrorSystem.getName(mirror.simpleName);
    String sourceUri = (findRealClassUriFromMirror(mirror) ?? Uri.parse(libraryUri)).toString();
    
    // Get runtime types from mirror
    Type actualRuntimeType;
    Type baseRuntimeType;
    
    try {
      // Get actual runtime type (with @Generic annotation resolution)
      actualRuntimeType = mirror.hasReflectedType ? mirror.reflectedType : mirror.runtimeType;
      actualRuntimeType = resolveGenericAnnotationIfNeeded(actualRuntimeType, mirror, libraryUri, Uri.parse(sourceUri), typeName);

      // Get base runtime type (unparameterized)
      if (mirror is mirrors.ClassMirror && mirror.originalDeclaration != mirror) {
        // Parameterized type, get original declaration
        final originalMirror = mirror.originalDeclaration;
        final originalName = mirrors.MirrorSystem.getName(originalMirror.simpleName);
        final sourceUri = originalMirror.location?.sourceUri.toString() ?? libraryUri;

        baseRuntimeType = originalMirror.hasReflectedType ? originalMirror.reflectedType : originalMirror.runtimeType;
        baseRuntimeType = resolveGenericAnnotationIfNeeded(baseRuntimeType, originalMirror, libraryUri, Uri.parse(sourceUri), originalName);
      } else {
        baseRuntimeType = actualRuntimeType;
      }
    } catch (e) {
      // Both failed, use defaults
      actualRuntimeType = mirror.runtimeType;
      baseRuntimeType = mirror.runtimeType;
    }

    // Get display name (prefer AnalyzedTypeAnnotation if available for better formatting)
    String displayName = typeName;
    if (dartType != null) {
      final dartDisplayName = getNameFromAnalyzedTypeAnnotation(dartType);
      if (dartDisplayName.isNotEmpty && dartDisplayName != 'dynamic') {
        displayName = dartDisplayName;
      }
    }

    return _TypeInfo(
      name: typeName,
      displayName: displayName,
      actualRuntimeType: actualRuntimeType,
      baseRuntimeType: baseRuntimeType,
      sourceUri: sourceUri,
    );
  }

  /// Builds a **stable, unique identity string** for a type.
  ///
  /// This identity is used internally for:
  /// - Link declaration caching
  /// - Cycle detection
  /// - Deduplication across resolution passes
  ///
  /// The identity combines:
  /// - Reflection metadata (mirror name and hash)
  /// - Analyzer metadata (display string, element name, hash), when available
  /// - The declaring library URI
  ///
  /// When analyzer information is unavailable, the identity falls back to a
  /// mirror-only representation.
  ///
  /// ### Parameters
  /// - [mirror] — The reflection-based type mirror.
  /// - [dartType] — The analyzer-based type, if available.
  /// - [libraryUri] — The URI of the declaring library.
  ///
  /// ### Returns
  /// A unique string suitable for identifying a type across link-generation
  /// phases.
  String _buildTypeIdentity(mirrors.TypeMirror mirror, AnalyzedTypeAnnotation? dartType, String libraryUri) {
    final mirrorName = mirrors.MirrorSystem.getName(mirror.simpleName);
    final mirrorHash = mirror.hashCode;
    
    if (dartType != null) {
      final dartDisplay = getNameFromAnalyzedTypeAnnotation(dartType);
      final dartHash = dartType.hashCode;
      
      return 'type_${mirrorName}_${dartDisplay}_${mirrorHash}_${dartHash}_$libraryUri';
    }
    
    return 'type_mirror_${mirrorName}_${mirrorHash}_$libraryUri';
  }

  /// Determines whether a type should be treated as **publicly visible**.
  ///
  /// This method applies a layered visibility check using both reflection
  /// and analyzer metadata, followed by a final naming-convention safeguard.
  ///
  /// ### Visibility Rules
  /// 1. If the mirror indicates the type is private, the type is not public.
  /// 2. If analyzer metadata exists and the element is private, the type
  ///    is not public.
  /// 3. If the type name follows internal naming conventions, it is
  ///    considered non-public.
  ///
  /// ### Parameters
  /// - [typeName] — The resolved display or declaration name of the type.
  /// - [mirror] — The reflection-based type mirror.
  /// - [dartType] — The analyzer-based type, if available.
  ///
  /// ### Returns
  /// `true` if the type is public and externally visible; otherwise `false`.
  bool _determineIsPublic(String typeName, mirrors.TypeMirror mirror, AnalyzedTypeAnnotation? dartType) {
    // Check mirror first
    final isMirrorPublic = !mirror.isPrivate;
    if (!isMirrorPublic) return false;
    
    // Final check by name convention
    return !isInternal(typeName);
  }

  /// Determines whether a type should be marked as **synthetic**.
  ///
  /// Synthetic types are compiler-generated or otherwise not part of the
  /// public API surface. This method prefers analyzer metadata when available,
  /// as it provides more reliable synthetic detection.
  ///
  /// ### Detection Rules
  /// 1. If analyzer metadata marks the element as synthetic, the type is synthetic.
  /// 2. If the mirror indicates the type is private and the name is prefixed
  ///    with `_`, the type is treated as synthetic.
  /// 3. If the type name matches known synthetic naming patterns, it is
  ///    treated as synthetic.
  ///
  /// ### Parameters
  /// - [typeName] — The resolved name of the type.
  /// - [mirror] — The reflection-based type mirror.
  /// - [dartType] — The analyzer-based type, if available.
  ///
  /// ### Returns
  /// `true` if the type is synthetic; otherwise `false`.
  bool _determineIsSynthetic(String typeName, mirrors.TypeMirror mirror, AnalyzedTypeAnnotation? dartType) {
    // Check AnalyzedTypeAnnotation first (analyzer has better synthetic detection)
    if (dartType?.isSynthetic case final element?) {
      return element;
    }
    
    // Check mirror
    if (mirror.isPrivate && typeName.startsWith('_')) return true;
    
    // Check by name patterns
    return isSynthetic(typeName);
  }

  /// Logs detailed diagnostic information when a **cycle is detected during
  /// type resolution**.
  ///
  /// This method is invoked when a function type is encountered whose
  /// identity is already present in the active link-generation stack. Such
  /// cycles can arise from:
  /// - Recursive function type definitions
  /// - Self-referential generic bounds
  /// - Mutually recursive typedefs or signatures
  ///
  /// The log output includes:
  /// - The computed type identity key
  /// - The reflection-based mirror name and runtime type
  /// - The analyzer-based Dart type, if available
  ///
  /// This method is intended **solely for debugging and diagnostics** and has
  /// no effect on resolution flow or error handling.
  ///
  /// ### Parameters
  /// - [typeIdentity] — The unique identity key of the function type.
  /// - [mirror] — The reflection-based representation of the function type.
  /// - [dartType] — The analyzer-based function type, if available.
  void _logCycleDetection(String typeIdentity, mirrors.TypeMirror mirror, AnalyzedTypeAnnotation? dartType) {
    final mirrorName = mirrors.MirrorSystem.getName(mirror.simpleName);
    final dartName = dartType != null ? getNameFromAnalyzedTypeAnnotation(dartType) : 'no-dart-type';
    StringBuffer buffer = StringBuffer();
    buffer.writeln('Cycle detected in type resolution: $typeIdentity');
    buffer.writeln('  Mirror: $mirrorName (${mirror.runtimeType})');
    buffer.writeln('  AnalyzedTypeAnnotation: $dartName');

    RuntimeBuilder.logCycle(buffer.toString());
  }

  /// Generates a unified [FunctionDeclaration] for a function type.
  ///
  /// This method is the **central entry point** for function type linking.
  /// It combines reflection (`mirrors`) and analyzer (`AnalyzedGenericFunctionTypeAnnotation`)
  /// information to produce a fully materialized
  /// [StandardFunctionDeclaration].
  ///
  /// The generation process is **cycle-safe** and **cache-aware**, ensuring
  /// that recursive or repeated function types do not cause infinite loops
  /// or duplicate declarations.
  ///
  /// ### Resolution Flow
  /// 1. Compute a stable type identity.
  /// 2. Abort if the identity is already being generated (cycle detection).
  /// 3. Return a cached declaration if available.
  /// 4. Extract the function signature from the mirror.
  /// 5. Construct a [StandardFunctionDeclaration].
  /// 6. Cache and return the result.
  ///
  /// ### Parameters
  /// - [mirror] — The reflection-based function type mirror.
  /// - [dartType] — The analyzer-based function type, if available.
  /// - [package] — The package context for link generation.
  /// - [libraryUri] — The URI of the declaring library.
  ///
  /// ### Returns
  /// A [Future] that completes with a [FunctionDeclaration] representing the
  /// function type, or `null` if generation fails or a cycle is detected.
  @protected
  FunctionDeclaration? generateFunctionDeclaration(mirrors.TypeMirror mirror, AnalyzedGenericFunctionTypeAnnotation? dartType, String libraryUri);

  /// Generates a [RecordDeclaration] from a Dart **record type**.
  ///
  /// This method is responsible for translating a runtime [mirrors.TypeMirror]
  /// that represents a record into a fully materialized [RecordDeclaration].
  /// It bridges runtime reflection with analyzer metadata to accurately describe
  /// record shape, field order, and field types.
  ///
  /// The implementation is expected to:
  /// - Inspect positional and named fields of the record
  /// - Resolve each field type into a [LinkDeclaration]
  /// - Preserve the original declaration order for positional fields
  /// - Respect nullability and type information from [dartType] when available
  ///
  /// ### Parameters
  /// - [mirror] — The runtime type mirror representing the record type.
  /// - [package] — The package context used for resolving referenced types.
  /// - [libraryUri] — The URI of the library declaring the record.
  /// - [dartType] — The analyzer-based [AnalyzedTypeAnnotation] for improved accuracy.
  ///
  /// ### Returns
  /// A [Future] that completes with a [RecordDeclaration] describing the
  /// record type, or `null` if the record cannot be resolved.
  ///
  /// ### Notes
  /// - This method is marked `@protected` and intended to be implemented by
  ///   subclasses that support record-type linking.
  /// - Implementations should include cycle detection if recursive record
  ///   types are possible.
  @protected
  RecordDeclaration? generateRecordDeclaration(mirrors.TypeMirror mirror, String libraryUri, AnalyzedTypeAnnotation dartType);
}
/// Helper class that encapsulates **core type identity and source metadata**.
///
/// `_TypeInfo` is a lightweight, immutable data holder used internally during
/// type discovery, linking, and resolution. It bundles together all essential
/// information required to reason about a type’s identity, runtime behavior,
/// and origin without repeatedly querying reflection or analyzer APIs.
///
/// This class is intentionally kept simple and free of logic, serving purely
/// as a transport structure between resolution phases.
///
/// ## Fields
///
/// - [name]  
///   The canonical internal name of the type, typically used for lookup and
///   qualified name construction.
///
/// - [displayName]  
///   A human-readable representation of the type name, suitable for error
///   messages, diagnostics, or debugging output.
///
/// - [actualRuntimeType]  
///   The concrete runtime [Type] represented by this entry. This may differ
///   from [baseRuntimeType] when generics, typedefs, or aliases are involved.
///
/// - [baseRuntimeType]  
///   The underlying runtime [Type] stripped of type arguments or indirection.
///   Used for assignability checks and base-type comparisons.
///
/// - [sourceUri]  
///   The URI pointing to the source file where the type is declared. This
///   allows source-level inspection and traceability.
///
/// This class is commonly produced during early reflection or analyzer passes
/// and consumed by link construction and validation stages.
class _TypeInfo {
  final String name;
  final String displayName;
  final Type actualRuntimeType;
  final Type baseRuntimeType;
  final String sourceUri;

  _TypeInfo({
    required this.name,
    required this.displayName,
    required this.actualRuntimeType,
    required this.baseRuntimeType,
    required this.sourceUri,
  });
}