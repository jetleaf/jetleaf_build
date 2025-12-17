// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:async';
import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import 'abstract_method_declaration_support.dart';

/// {@template abstract_constructor_declaration_support}
/// Abstract support class for generating [ConstructorDeclaration]s
/// with both mirrors and analyzer support.
///
/// [AbstractConstructorDeclarationSupport] extends
/// [AbstractMethodDeclarationSupport] to provide specialized functionality
/// for handling Dart class constructors. It allows framework users or
/// code generation tools to create rich, type-safe representations of
/// constructors, including all their parameters, annotations, and metadata.
///
/// This class is primarily intended for internal framework use to
/// facilitate reflection-based analysis and code generation. It abstracts
/// away the differences between unnamed and named constructors and provides
/// robust support for:
///
/// - Resolving constructors from analyzer [ClassElement]s or mirror
///   information ([mirrors.MethodMirror]).
/// - Extracting parameters, including positional, named, optional, and
///   required parameters.
/// - Determining nullability and default values for all parameters, even
///   in complex cases like field formal parameters or super parameters.
/// - Resolving generic types using annotations and mirrors.
/// - Extracting metadata such as `const`, `factory`, `public/private`,
///   and `synthetic` flags.
/// - Linking constructors to their parent class representation through
///   [StandardLinkDeclaration].
///
/// Typical usage:
/// ```dart
/// final constructorSupport = MyConstructorSupport(...);
/// final constructorDeclaration = await constructorSupport.generateConstructor(
///   constructorMirror,
///   element,
///   package,
///   libraryUri,
///   sourceUri,
///   className,
///   parentClassDeclaration,
/// );
/// ```
///
/// **Notes:**
/// - This class does not directly instantiate constructors; it generates
///   metadata representations for use in reflection or code generation.
/// - It handles both unnamed constructors and named constructors,
///   ensuring accurate linking and parameter extraction.
/// - Parameter nullability and types are inferred using a combination of
///   mirrors, analyzer elements, and source code analysis.
/// - Annotations on constructors are fully supported, including generic
///   type annotations that require resolution.
/// {@endtemplate}
abstract class AbstractConstructorDeclarationSupport extends AbstractMethodDeclarationSupport {
  /// Initializes an instance of [AbstractConstructorDeclarationSupport].
  ///
  /// The constructor requires the same configuration parameters as the
  /// superclass [AbstractMethodDeclarationSupport], including access to
  /// the mirror system, package context, and logging callbacks.
  /// 
  /// {@macro abstract_constructor_declaration_support}
  AbstractConstructorDeclarationSupport({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.configuration,
    required super.packages,
  });

  /// Retrieves a [ConstructorElement] from a [InterfaceElement], given a
  /// constructor name.
  ///
  /// If [constructorName] is empty, returns the unnamed constructor;
  /// otherwise, returns the named constructor if it exists.
  ConstructorElement? _getConstructorElement(InterfaceElement? element, String constructorName) {
    ConstructorElement? constructorElement;
    if (element case final element?) {
      if (constructorName.isEmpty) {
        constructorElement = element.unnamedConstructor;
      } else {
        constructorElement = element.getNamedConstructor(constructorName);
      }
    }

    return constructorElement;
  }

  /// Generates a [ConstructorDeclaration] for a class using mirrors and
  /// analyzer support.
  ///
  /// This method extracts complete metadata for a constructor, including:
  /// - Constructor name and type, handling generic type resolution if needed.
  /// - Parameters with full support for nullability, optionality, default
  ///   values, named parameters, and annotations.
  /// - Constructor annotations.
  /// - Constructor modifiers such as factory, const, public/private, and synthetic.
  /// - Parent class linking via [StandardLinkDeclaration].
  ///
  /// Intended for internal framework use (`@protected`) for reflection-based
  /// code generation or analysis.
  ///
  /// Parameters:
  /// - [constructorMirror]: The mirror representing the constructor.
  /// - [element]: Optional analyzer [InterfaceElement] to obtain richer
  ///   type information.
  /// - [package]: Package context for type and annotation resolution.
  /// - [libraryUri]: URI of the library containing the constructor.
  /// - [sourceUri]: URI of the source file for the constructor.
  /// - [className]: Name of the class containing the constructor.
  /// - [parentClass]: [ClassDeclaration] representing the parent class.
  ///
  /// Returns: A fully populated [ConstructorDeclaration] representing the constructor.
  @protected
  Future<ConstructorDeclaration> generateConstructor(mirrors.MethodMirror constructorMirror, InterfaceElement? element, Package package, String libraryUri, Uri sourceUri, String className, ClassDeclaration parentClass) async {
    final constructorName = mirrors.MirrorSystem.getName(constructorMirror.constructorName);
    final constructorClass = constructorMirror.returnType;
    Type type = constructorClass.hasReflectedType ? constructorClass.reflectedType : constructorClass.runtimeType;
    
    final logMessage = "Extracting ${constructorName.isEmpty ? 'default' : constructorName} constructor in $className";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 3);

    final result = await RuntimeBuilder.timeExecution(() async {
      final constructorElement = _getConstructorElement(element, constructorName);
      type = await resolveGenericAnnotationIfNeeded(type, constructorClass, package, libraryUri, sourceUri, className);

      final result = StandardConstructorDeclaration(
        name: constructorName.isEmpty ? '' : constructorName,
        type: type,
        element: constructorElement,
        dartType: constructorElement?.type,
        libraryDeclaration: await getLibrary(libraryUri),
        parentClass: StandardLinkDeclaration(
          name: parentClass.getName(),
          type: parentClass.getType(),
          pointerType: parentClass.getType(),
          dartType: parentClass.getDartType(),
          qualifiedName: parentClass.getQualifiedName(),
          isPublic: parentClass.getIsPublic(),
          canonicalUri: Uri.parse(parentClass.getPackageUri()),
          referenceUri: Uri.parse(parentClass.getPackageUri()),
          isSynthetic: parentClass.getIsSynthetic(),
        ),
        annotations: await extractAnnotations(constructorMirror.metadata, libraryUri, sourceUri, package, constructorElement?.metadata.annotations),
        sourceLocation: sourceUri,
        isFactory: constructorElement?.isFactory ?? constructorMirror.isFactoryConstructor,
        isConst: constructorElement?.isConst ?? constructorMirror.isConstConstructor,
        isPublic: constructorElement?.isPublic ?? !isInternal(constructorName),
        isSynthetic: constructorElement?.isSynthetic ?? isSynthetic(constructorName),
      );

      result.parameters = await extractParameters(constructorMirror.parameters, constructorElement?.formalParameters, package, libraryUri, result);

      return result;
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 3);
    return result.result;
  }
}