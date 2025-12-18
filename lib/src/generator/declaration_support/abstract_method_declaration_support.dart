// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import '../abstract_element_support.dart';
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

  @override
  Future<MethodDeclaration> generateMethod(mirrors.MethodMirror methodMirror, AnalyzedMemberList? members, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration? parentClass) async {
    final methodName = mirrors.MirrorSystem.getName(methodMirror.simpleName);
    final methodClass = methodMirror.returnType;
    final methodClassName = mirrors.MirrorSystem.getName(methodClass.simpleName);
    Type type = methodClass.hasReflectedType ? methodClass.reflectedType : methodClass.runtimeType;

    final logMessage = "Extracting $methodName method of $methodClassName in $className";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

    final result = await RuntimeBuilder.timeExecution(() async {
      final analyzedMethod = getAnalyzedMethod(members, methodName);
      final dartType = analyzedMethod?.returnType;
      type = await resolveGenericAnnotationIfNeeded(type, methodClass, package, libraryUri, sourceUri, methodClassName);

      final sourceCode = await readSourceCode(sourceUri);

      final result = StandardMethodDeclaration(
        name: methodName,
        type: type,
        libraryDeclaration: await getLibrary(libraryUri),
        returnType: await getLinkDeclaration(methodMirror.returnType, package, libraryUri, dartType),
        annotations: await extractAnnotations(methodMirror.metadata, libraryUri, sourceUri, package, analyzedMethod?.metadata),
        isPublic: !isInternal(methodName),
        isSynthetic: analyzedMethod?.isSynthetic ?? isSynthetic(methodName),
        sourceLocation: sourceUri,
        isStatic: methodMirror.isStatic,
        isAbstract: methodMirror.isAbstract,
        hasNullableReturn: checkTypeAnnotationNullable(dartType) || hasNullableReturn(methodMirror.source, sourceCode, methodName),
        isGetter: analyzedMethod?.isGetter ?? methodMirror.isGetter,
        isSetter: analyzedMethod?.isSetter ?? methodMirror.isSetter,
        parentClass: parentClass != null ? StandardLinkDeclaration(
          name: parentClass.getName(),
          type: parentClass.getType(),
          pointerType: parentClass.getType(),
          qualifiedName: parentClass.getQualifiedName(),
          isPublic: parentClass.getIsPublic(),
          canonicalUri: Uri.parse(parentClass.getPackageUri()),
          referenceUri: Uri.parse(parentClass.getPackageUri()),
          isSynthetic: parentClass.getIsSynthetic(),
        ) : null,
        isFactory: methodMirror.isFactoryConstructor,
        isConst: methodMirror.isConstConstructor,
        isExternal: analyzedMethod?.externalKeyword != null || false
      );

      result.parameters = await extractParameters(methodMirror.parameters, analyzedMethod?.parameters, package, libraryUri, result);

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
      final analyzedMethod = await getAnalyzedTopLevelMethod(libraryUri, methodName);
      final dartType = analyzedMethod?.returnType;
      type = await resolveGenericAnnotationIfNeeded(type, methodClass, package, libraryUri.toString(), sourceUri, methodClassName);

      final sourceCode = await readSourceCode(sourceUri);

      final result = StandardMethodDeclaration(
        name: methodName,
        type: type,
        libraryDeclaration: await getLibrary(libraryUri.toString()),
        returnType: await getLinkDeclaration(methodMirror.returnType, package, libraryUri.toString(), dartType),
        annotations: await extractAnnotations(methodMirror.metadata, libraryUri.toString(), sourceUri, package, analyzedMethod?.metadata),
        sourceLocation: sourceUri,
        isGetter: methodMirror.isGetter,
        isSetter: methodMirror.isSetter,
        isFactory: false,
        hasNullableReturn: checkTypeAnnotationNullable(dartType) || hasNullableReturn(methodMirror.source, sourceCode, methodName),
        isPublic: !isInternal(methodName),
        isSynthetic: analyzedMethod?.isSynthetic ?? isSynthetic(methodName),
        isConst: false,
        isTopLevel: true
      );

      result.parameters = await extractParameters(methodMirror.parameters, analyzedMethod?.functionExpression.parameters, package, libraryUri.toString(), result);

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