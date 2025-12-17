// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import 'abstract_parameter_declaration_support.dart';

/// {@template abstract_method_declaration_support}
/// Abstract base class providing support for generating method declarations
/// within the JetLeaf framework.
///
/// `AbstractMethodDeclarationSupport` extends [AbstractParameterDeclarationSupport],
/// inheriting functionality for extracting parameters, resolving types,
/// handling annotations, and determining nullability. This class focuses
/// methods specifically, allowing both class-level (instance and static)
/// and top-level functions to be analyzed and converted into
/// [MethodDeclaration] objects, which encapsulate metadata such as:
/// - Name and visibility (public/private)
/// - Return type and resolved runtime type
/// - Parameters (with nullability, optionality, and default values)
/// - Annotations
/// - Source location
/// - Synthetic or abstract status
/// - Getter/setter flags
/// - Factory or constructor flags for special methods
///
/// The class integrates with Dart’s reflection and analyzer systems to provide
/// a robust mechanism for generating code or metadata representations
/// for methods while respecting Dart type semantics, null-safety,
/// generics, and class hierarchies.
///
/// ## Key Capabilities
/// - Analyze method mirrors (`mirrors.MethodMirror`) and optional analyzer
///   elements to resolve full method metadata.
/// - Extract parameter metadata, including nullability and default values,
///   for both constructor and regular methods.
/// - Resolve generic return types and annotations to runtime types when necessary.
/// - Support for static methods, getters, setters, factory constructors, and const constructors.
/// - Handle top-level functions in libraries in addition to class methods.
///
/// This class serves as a foundation for higher-level code generation or
/// reflection utilities in the JetLeaf framework, enabling consistent
/// metadata extraction for automated tasks like serialization,
/// dependency injection, and API generation.
///
/// ### Usage
/// Extend this class and use the provided `generateMethod` and
/// `generateTopLevelMethod` methods to convert Dart mirrors into
/// fully-featured [MethodDeclaration] objects, ready for further processing
/// or code generation tasks.
/// {@endtemplate}
abstract class AbstractMethodDeclarationSupport extends AbstractParameterDeclarationSupport {
  /// Constructs an instance of method declaration support.
  ///
  /// All parameters are required and forwarded to the superclass
  /// [AbstractParameterDeclarationSupport] to initialize:
  /// - [mirrorSystem]: The Dart reflection system.
  /// - [forceLoadedMirrors]: Forces mirrors to load fully if necessary.
  /// - [configuration]: JetLeaf framework configuration object.
  /// - [packages]: Loaded package metadata for resolving types and annotations.
  /// 
  /// {@macro abstract_method_declaration_support}
  AbstractMethodDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  /// Resolves the corresponding analyzer [`ExecutableElement`] for a reflected
  /// method represented by [methodMirror].
  ///
  /// This utility bridges JetLeaf’s hybrid reflection system by mapping a
  /// runtime mirror method (from `dart:mirrors`) to its static counterpart
  /// obtained from the Dart Analyzer via an [InterfaceElement].
  ///
  /// Because getters, setters, and regular methods are represented differently
  /// in the Analyzer, this method selects the correct lookup path based on the
  /// mirror’s characteristics.
  ///
  /// ### Parameters
  /// - **[methodName]**  
  ///   The simple name of the method as extracted from the mirror system.
  ///
  /// - **[methodMirror]**  
  ///   The reflective descriptor of the method. Used to determine whether the
  ///   method is a getter, setter, or a standard function.
  ///
  /// - **[parentElement]**  
  ///   The analyzer element representing the containing class, mixin, or enum.
  ///   This is required to resolve members through the Analyzer API.
  ///
  /// ### Behavior
  /// The method resolves elements according to this precedence:
  ///
  /// 1. **If the mirror represents a getter**  
  ///    → returns `parentElement.getGetter(methodName)`
  ///
  /// 2. **If the mirror represents a setter**  
  ///    → returns `parentElement.getSetter(methodName)`
  ///
  /// level: 3. **Otherwise (regular method)**  
  ///    → returns `parentElement.getMethod(methodName)`
  ///
  /// If [parentElement] is `null`, this method returns `null` without throwing.
  ///
  /// ### Returns
  /// The analyzer [`ExecutableElement`] corresponding to the reflected method,
  /// or `null` if the element is not present or the parent element is missing.
  ///
  /// ### Notes
  /// - This method does **not** attempt to resolve inherited members; it only
  ///   queries the provided [parentElement].
  /// - This is an internal resolution helper used during method and field
  ///   declaration generation, ensuring consistency between reflected and
  ///   analyzer-backed metadata.
  ExecutableElement? _getMethod(String methodName, mirrors.MethodMirror methodMirror, InterfaceElement? parentElement) {
    if (methodMirror.isGetter) {
      return parentElement?.getGetter(methodName);
    } else if (methodMirror.isSetter) {
      return parentElement?.getSetter(methodName);
    } else {
      return parentElement?.getMethod(methodName);
    }
  }

  @override
  Future<MethodDeclaration> generateMethod(mirrors.MethodMirror methodMirror, InterfaceElement? parentElement, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);
    final methodClass = methodMirror.returnType;
    final methodClassName = mirrors.MirrorSystem.getName(methodClass.simpleName);
    Type type = methodClass.hasReflectedType ? methodClass.reflectedType : methodClass.runtimeType;

    final logMessage = "Extracting $methodName method of $methodClassName in $className";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

    final result = await RuntimeBuilder.timeExecution(() async {
      final methodElement = _getMethod(methodName, methodMirror, parentElement);
      final dartType = methodElement?.type;
      type = await resolveGenericAnnotationIfNeeded(type, methodClass, package, libraryUri, sourceUri, methodClassName);

      final sourceCode = sourceCache[sourceUri.toString()] ?? await readSourceCode(sourceUri);

      final result = StandardMethodDeclaration(
        name: methodName,
        element: methodElement,
        dartType: dartType,
        type: type,
        libraryDeclaration: await getLibrary(libraryUri),
        returnType: await getLinkDeclaration(methodMirror.returnType, package, libraryUri, dartType),
        annotations: await extractAnnotations(methodMirror.metadata, libraryUri, sourceUri, package, methodElement?.metadata.annotations),
        isPublic: methodElement?.isPublic ?? !isInternal(methodName),
        isSynthetic: methodElement?.isSynthetic ?? isSynthetic(methodName),
        sourceLocation: sourceUri,
        isStatic: methodMirror.isStatic,
        isAbstract: methodMirror.isAbstract,
        hasNullableReturn: methodElement?.returnType.nullabilitySuffix == NullabilitySuffix.question || hasNullableReturn(methodMirror.source, sourceCode, methodName),
        isGetter: methodElement != null ? methodElement is GetterElement : methodMirror.isGetter,
        isSetter: methodElement != null ? methodElement is SetterElement : methodMirror.isSetter,
        parentClass: parentClass != null ? StandardLinkDeclaration(
          name: parentClass.getName(),
          type: parentClass.getType(),
          pointerType: parentClass.getType(),
          qualifiedName: parentClass.getQualifiedName(),
          isPublic: parentClass.getIsPublic(),
          dartType: parentClass.getDartType(),
          canonicalUri: Uri.parse(parentClass.getPackageUri()),
          referenceUri: Uri.parse(parentClass.getPackageUri()),
          isSynthetic: parentClass.getIsSynthetic(),
        ) : null,
        isFactory: methodMirror.isFactoryConstructor,
        isConst: methodMirror.isConstConstructor,
        isExternal: methodElement?.isExternal ?? false
      );

      result.parameters = await extractParameters(methodMirror.parameters, methodElement?.formalParameters, package, libraryUri, result);

      return result;
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
    return result.result;
  }

  /// Generates a [MethodDeclaration] for a top-level function using Dart
  /// reflection (`mirrors`) and analyzer support.
  ///
  /// Similar to [generateMethod], this method builds a complete metadata
  /// representation for a top-level function. It supports:
  /// - Return type resolution using analyzer elements or mirrors, including generics.
  /// - Parameter extraction with full support for nullability, optionality,
  ///   named parameters, default values, and annotations.
  /// - Determining function visibility and synthetic status.
  /// - Linking to the library declaration and source location.
  ///
  /// This method is intended for internal framework use (annotated with `@protected`)
  /// and is used in scenarios where top-level functions need to be analyzed or
  /// represented as [MethodDeclaration] objects for code generation or reflection.
  ///
  /// Parameters:
  /// - [methodMirror]: The mirror representing the top-level function.
  /// - [package]: The package context to resolve types and annotations.
  /// - [libraryUri]: URI of the library containing the function.
  /// - [sourceUri]: URI of the source file containing the function.
  ///
  /// Returns: A fully populated [MethodDeclaration] object representing the top-level function.
  @protected
  Future<MethodDeclaration> generateTopLevelMethod(mirrors.MethodMirror methodMirror, Package package, Uri libraryUri, Uri sourceUri) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);
    final methodClass = methodMirror.returnType;
    final methodClassName = mirrors.MirrorSystem.getName(methodClass.simpleName);
    Type type = methodClass.hasReflectedType ? methodClass.reflectedType : methodClass.runtimeType;

    final logMessage = "Extracting top-level $methodName method of $methodClassName";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

    final result = await RuntimeBuilder.timeExecution(() async {
      final libraryElement = await getLibraryElement(libraryUri);
      final functionElement = libraryElement?.getTopLevelFunction(methodName) ?? libraryElement?.topLevelFunctions.where((f) => f.name == methodName).firstOrNull;
      final dartType = functionElement?.type;
      type = await resolveGenericAnnotationIfNeeded(type, methodClass, package, libraryUri.toString(), sourceUri, methodClassName);

      final sourceCode = sourceCache[sourceUri.toString()] ?? await readSourceCode(sourceUri);

      final result = StandardMethodDeclaration(
        name: methodName,
        element: functionElement,
        dartType: dartType,
        type: type,
        libraryDeclaration: await getLibrary(libraryUri.toString()),
        returnType: await getLinkDeclaration(methodMirror.returnType, package, libraryUri.toString(), dartType),
        annotations: await extractAnnotations(methodMirror.metadata, libraryUri.toString(), sourceUri, package, functionElement?.metadata.annotations),
        sourceLocation: sourceUri,
        isStatic: functionElement?.isStatic ?? true,
        isAbstract: functionElement?.isAbstract ?? false,
        isGetter: methodMirror.isGetter,
        isSetter: methodMirror.isSetter,
        isFactory: false,
        hasNullableReturn: functionElement != null 
          ? functionElement.type.nullabilitySuffix == NullabilitySuffix.question
          : hasNullableReturn(methodMirror.source, sourceCode, methodName),
        isPublic: functionElement?.isPublic ?? !isInternal(methodName),
        isSynthetic: functionElement?.isSynthetic ?? isSynthetic(methodName),
        isConst: false,
        isEntrypoint: functionElement?.isEntryPoint ?? false,
        isTopLevel: true
      );

      result.parameters = await extractParameters(methodMirror.parameters, functionElement?.formalParameters, package, libraryUri.toString(), result);

      return result;
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
    return result.result;
  }
  
  /// Checks if a method has a nullable return type.
  /// Only considers the outer type. For example:
  /// - `String? foo()` → true
  /// - `Future<T>? foo()` → true
  /// - `Future<String?> foo()` → false
  ///
  /// [methodSourceCode] is the snippet containing the method (if available)
  /// [sourceCode] is the full source code to fall back on
  /// [methodName] is the name of the method
  bool hasNullableReturn(String? methodSourceCode, String sourceCode, String methodName) {
    String sourceToCheck = methodSourceCode?.trim() ?? '';

    // If no snippet is given, try to extract the method declaration from full source
    if (sourceToCheck.isEmpty) {
      final pattern = RegExp(
        r'([\w<>, ?]+)\s+' + RegExp.escape(methodName) + r'\s*\(',
        multiLine: true,
      );
      final match = pattern.firstMatch(sourceCode);
      if (match != null) {
        sourceToCheck = match.group(0)!;
      }
    }

    if (sourceToCheck.isEmpty) return false;

    // Remove annotations and comments
    final cleaned = sourceToCheck
        .replaceAll(RegExp(r'//.*'), '')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'@\w+(\([^)]*\))?'), '')
        .trim();

    // Extract return type
    final returnTypePattern = RegExp(r'^([\w<>, ?]+)\s+' + RegExp.escape(methodName) + r'\s*\(');
    final match = returnTypePattern.firstMatch(cleaned);
    if (match == null) return false;

    final returnType = match.group(1)?.trim();
    if (returnType == null) return false;

    // Outer nullability check
    return returnType.endsWith('?');
  }
}