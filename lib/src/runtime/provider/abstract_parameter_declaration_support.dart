// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// ---------------------------------------------------------------------------

// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/token.dart' as tok;
import 'package:meta/meta.dart';

import '../../builder/runtime_builder.dart';
import '../declaration/declaration.dart';
import '../../utils/dart_type_resolver.dart';
import '../../utils/generic_type_parser.dart';
import '../../utils/utils.dart';
import 'abstract_field_declaration_support.dart';
import 'abstract_material_library_analyzer_support.dart';

/// {@template abstract_parameter_declaration_support}
/// Abstract support class for generating and extracting parameter declarations.
///
/// `AbstractParameterDeclarationSupport` extends [AbstractFieldDeclarationSupport]
/// and provides specialized mechanisms for analyzing and generating **method
/// and constructor parameter metadata** within the JetLeaf framework.
///
/// # Responsibilities
/// This class is responsible for:
/// 1. **Parameter type resolution**
///    - Resolves parameter types using both analyzer elements ([FormalParameterElement])
///      and mirrors ([ParameterMirror]) to provide accurate runtime and static types.
///    - Supports generic types via [GenericTypeParser] and resolves them when needed.
///
/// 2. **Parameter metadata extraction**
///    - Extracts annotations associated with parameters.
///    - Determines parameter properties, such as `isOptional`, `isRequired`,
///      `isNamed`, and `hasDefaultValue`.
///    - Detects nullability using AST parsing and source code heuristics.
///
/// 3. **Link generation**
///    - Produces [LinkDeclaration]s for each parameter type using inherited methods
///      from [AbstractLinkDeclarationSupport].
///    - Ensures cycle-safe processing and caches results for efficiency.
///
/// 4. **Support for constructors, methods, and top-level functions**
///    - Can extract parameters from class constructors, named constructors, methods,
///      or top-level functions, correctly handling static and instance contexts.
///
/// # Notes
/// - The class is **abstract** and intended to be extended by framework or tooling
///   modules for parameter processing.
/// - Fully compatible with runtime reflection and analyzer-based metadata,
///   suitable for both JIT and AOT contexts.
/// - Includes fallback mechanisms for nullability detection in case AST parsing fails.
///
/// # Usage
/// Subclasses should use [extractParameters] to generate a structured list of
/// [ParameterDeclaration]s for a given method or constructor.
/// 
/// # Example
/// ```dart
/// final parameters = myParamSupport.extractParameters(
///   mirrorParams,
///   analyzerParams,
///   package,
///   libraryUri,
///   parentMember,
/// );
/// ```
/// {@endtemplate}
abstract class AbstractParameterDeclarationSupport extends AbstractFieldDeclarationSupport {
  /// {@macro abstract_parameter_declaration_support}
  AbstractParameterDeclarationSupport();

  @override
  List<ParameterDeclaration> extractParameters(List<mirrors.ParameterMirror> mirrorParams, AnalyzedFormalParameterList? analyzerParams, String libraryUri, MemberDeclaration parentMember) {
    final isMethod = parentMember is MethodDeclaration;
    final className = parentMember is MethodDeclaration 
      ? parentMember.getParentClass()?.getName()
      : parentMember is ConstructorDeclaration
        ? parentMember.getParentClass()?.getName()
        : parentMember.getName();

    final logMessage = "Extracting ${isMethod ? "method" : "constructor"} [${parentMember.getName()}] parameters in $className";
    RuntimeBuilder.logFullyVerboseInfo(logMessage, level: 4);

    final result = RuntimeBuilder.timeExecution(() {
      final parameters = <ParameterDeclaration>[];
    
      for (int i = 0; i < mirrorParams.length; i++) {
        final mirrorParam = mirrorParams[i];
        final paramName = mirrors.MirrorSystem.getName(mirrorParam.simpleName);
        final analyzedParam = _findParameterInList(analyzerParams?.parameters, paramName);
        final sourceUri = findRealClassUriFromMirror(mirrorParam) ?? Uri.parse(libraryUri);

        try {
          final paramCheck = _checkParameter(
            sourceCode: readSourceCode(Uri.parse(libraryUri)),
            methodName: parentMember.getName(),
            paramName: paramName,
            className: className,
            isConstructor: parentMember is ConstructorDeclaration,
            constructorName: parentMember is ConstructorDeclaration ? parentMember.getName() : null,
            isStatic: parentMember.getIsStatic(),
          );
          
          final dartType = getAnalyzedTypeAnnotationFromParameter(analyzedParam);
          final paramType = getLinkDeclaration(mirrorParam.type, libraryUri, dartType);
          final annotations = extractAnnotations(mirrorParam.metadata, libraryUri, sourceUri, analyzedParam?.metadata);

          // Safe access to default value
          dynamic defaultValue;
          if (mirrorParam.hasDefaultValue && mirrorParam.defaultValue != null && mirrorParam.defaultValue!.hasReflectee) {
            defaultValue = mirrorParam.defaultValue!.reflectee;
          }

          final paramClass = mirrorParam.type;
          final paramClassName = mirrors.MirrorSystem.getName(paramClass.simpleName);
          Type type = paramClass.hasReflectedType ? paramClass.reflectedType : paramClass.runtimeType;
          type = resolveGenericAnnotationIfNeeded(type, paramClass, libraryUri, sourceUri, paramClassName);
          
          parameters.add(StandardParameterDeclaration(
            name: paramName,
            type: type,
            typeDeclaration: paramType,
            isNullable: checkTypeAnnotationNullable(dartType) || paramCheck.isNullable,
            isOptional: analyzedParam?.isOptional ?? mirrorParam.isOptional || mirrorParam.hasDefaultValue || (paramCheck.param?.isOptional ?? mirrorParam.isOptional),
            isRequired: analyzedParam?.isRequired ?? paramCheck.param?.isRequired ?? !mirrorParam.isOptional,
            isNamed: mirrorParam.isNamed,
            hasDefaultValue: mirrorParam.hasDefaultValue,
            defaultValue: defaultValue,
            index: i,
            isPublic: !isInternal(paramName) || !mirrorParam.isPrivate,
            isSynthetic: analyzedParam?.isSynthetic ?? isSynthetic(paramName),
            sourceLocation: Uri.parse(libraryUri),
            annotations: annotations,
          ));
        } catch (_) { }
      }
      
      return parameters;
    });

    RuntimeBuilder.logFullyVerboseInfo("Completed ${logMessage.toLowerCase()} within ${result.getFormatted()}", trackWith: logMessage, level: 4);
    return result.result;
  }

  /// Checks if a parameter is nullable by parsing the source code AST.
  ///
  /// Attempts to parse the Dart [sourceCode] using the analyzer AST. Depending on
  /// whether the parameter belongs to a constructor, class method, or top-level
  /// function, it delegates to the appropriate AST-based checking method. If parsing
  /// fails, it falls back to a simpler pattern-based check.
  ///
  /// # Parameters
  /// - [sourceCode]: The source code of the library containing the parameter.
  /// - [methodName]: The name of the method or constructor the parameter belongs to.
  /// - [paramName]: The name of the parameter to check.
  /// - [className]: Optional class name if the parameter belongs to a class method or constructor.
  /// - [isConstructor]: Indicates if the parameter is part of a constructor.
  /// - [constructorName]: Optional named constructor name if applicable.
  /// - [isStatic]: Indicates if the method is static.
  ///
  /// # Returns
  /// An [_Param] object containing the nullability result and the AST node of the parameter.
  @protected
  _Param _checkParameter({
    required String sourceCode,
    required String methodName,
    required String paramName,
    String? className,
    bool isConstructor = false,
    String? constructorName,
    bool isStatic = false,
  }) {
    try {
      final parseResult = parseString(content: sourceCode);
      final ast = parseResult.unit;

      if (isConstructor && className != null && constructorName != null) {
        return _checkConstructorParameterAst(ast, className, paramName, constructorName);
      } else {
        return _checkMethodParameterAst(ast, methodName, paramName, className, isStatic);
      }
    } catch (e) {
      // Fallback to simpler regex check if AST parsing fails
      final nullable = _fallbackNullableCheck(sourceCode, methodName, paramName, className, isConstructor, constructorName);
      return _Param(nullable, null);
    }
  }

  /// Checks nullability of a constructor parameter via AST.
  ///
  /// Finds the class and the specified constructor within the AST and then
  /// locates the parameter to determine its nullability.
  ///
  /// # Parameters
  /// - [unit]: The AST compilation unit of the source code.
  /// - [className]: The name of the class containing the constructor.
  /// - [paramName]: The name of the parameter to check.
  /// - [constructorName]: The name of the constructor.
  ///
  /// # Returns
  /// An [_Param] object indicating whether the parameter is nullable and its AST node.
  _Param _checkConstructorParameterAst(ast.CompilationUnit unit, String className, String paramName, String constructorName) {
    // Find the class
    final classDecl = unit.declarations.whereType<ast.ClassDeclaration>().where((c) => c.name.toString() == className).firstOrNull;
    if (classDecl == null) return _Param(false, null);
    
    // Find constructors
    for (final member in classDecl.members) {
      if (member is ast.ConstructorDeclaration) {
        // Check named constructor or default constructor
        if ((member.name?.toString() == constructorName) || member.name == null) {
          // Check parameters
          final param = _findParameterInList(member.parameters.parameters, paramName);
          if (param != null) {
            return _Param(_isParameterNullable(param, paramName, classDecl), param);
          }
        }
      }
    }
    
    return _Param(false, null);
  }

  /// Checks nullability of a method or top-level function parameter via AST.
  ///
  /// Locates the parameter within the class or top-level function and determines
  /// if it is nullable.
  ///
  /// # Parameters
  /// - [unit]: The AST compilation unit of the source code.
  /// - [methodName]: The name of the method or function.
  /// - [paramName]: The name of the parameter.
  /// - [className]: Optional class name if the method belongs to a class.
  /// - [isStatic]: Indicates if the method is static.
  ///
  /// # Returns
  /// An [_Param] object indicating nullability and the parameter AST node.
  _Param _checkMethodParameterAst(ast.CompilationUnit unit, String methodName, String paramName, String? className, bool isStatic) {
    if (className != null) {
      // Instance or static class method
      final classDecl = unit.declarations.whereType<ast.ClassDeclaration>().where((c) => c.name.toString() == className).firstOrNull;
      
      if (classDecl != null) {
        for (final member in classDecl.members) {
          if (member is ast.MethodDeclaration && member.name.toString() == methodName && member.isStatic == isStatic) {
            final param = _findParameterInList(member.parameters?.parameters, paramName);
            if (param != null) {
              return _Param(_isParameterNullable(param, paramName, classDecl), param);
            }
          }
        }
      }
    } else {
      // Top-level function
      for (final declaration in unit.declarations) {
        if (declaration is ast.FunctionDeclaration && declaration.name.toString() == methodName) {
          final param = _findParameterInList(declaration.functionExpression.parameters?.parameters, paramName);
          if (param != null) {
            return _Param(_isParameterNullable(param, paramName, null), param);
          }
        }
      }
    }
    
    return _Param(false, null);
  }

  /// Searches a list of AST parameters to locate a parameter by name, supporting all parameter types.
  ///
  /// # Parameters
  /// - [parameters]: List of [ast.FormalParameter] nodes.
  /// - [paramName]: The name of the parameter to find.
  ///
  /// # Returns
  /// The [ast.FormalParameter] if found, otherwise `null`.
  ast.FormalParameter? _findParameterInList(List<ast.FormalParameter>? parameters, String paramName) {
    if (parameters == null) return null;

    for (final param in parameters) {
      if (param is ast.SimpleFormalParameter && param.name?.lexeme == paramName) {
        return param;
      } else if (param is ast.FieldFormalParameter && param.name.lexeme == paramName) {
        return param;
      } else if (param is ast.DefaultFormalParameter) {
        final innerParam = param.parameter;
        if (innerParam is ast.SimpleFormalParameter && innerParam.name?.lexeme == paramName) return innerParam;
        if (innerParam is ast.FieldFormalParameter && innerParam.name.lexeme == paramName) return innerParam;
        if (innerParam is ast.FunctionTypedFormalParameter && innerParam.name.lexeme == paramName) return innerParam;
        if (innerParam is ast.SuperFormalParameter && innerParam.name.lexeme == paramName) return innerParam;
      } else if (param is ast.FunctionTypedFormalParameter && param.name.lexeme == paramName) {
        return param;
      } else if (param is ast.SuperFormalParameter && param.name.lexeme == paramName) {
        return param;
      }
    }

    return null;
  }

  /// Determines nullability of a parameter based on its AST node.
  ///
  /// Delegates to specific nullability check methods depending on the parameter type.
  ///
  /// # Parameters
  /// - [param]: The AST parameter node.
  /// - [paramName]: The parameter name.
  /// - [classDecl]: Optional class declaration context.
  ///
  /// # Returns
  /// `true` if the parameter is nullable, otherwise `false`.
  bool _isParameterNullable(ast.FormalParameter param, String paramName, ast.ClassDeclaration? classDecl) {
    if (param is ast.SimpleFormalParameter) return _checkSimpleParameterNullable(param);
    if (param is ast.FieldFormalParameter) return _checkFieldParameterNullable(param, classDecl);
    if (param is ast.FunctionTypedFormalParameter) return _checkFunctionTypedParameterNullable(param);
    if (param is ast.DefaultFormalParameter) return _isParameterNullable(param.parameter, paramName, classDecl);
    if (param is ast.SuperFormalParameter) return _checkSuperParameterNullable(param);
    return false;
  }

 /// Checks nullability of a simple parameter like `String param` or `String? param`.
  ///
  /// This method considers the explicit type annotation, the `?` suffix,
  /// and optional positional parameters without type annotations (which
  /// are treated as `dynamic?`).
  ///
  /// # Parameters
  /// - [param]: The [ast.SimpleFormalParameter] to check.
  ///
  /// # Returns
  /// `true` if the parameter is nullable, `false` otherwise.
  bool _checkSimpleParameterNullable(ast.SimpleFormalParameter param) {
    final type = param.type;
    if (type != null) return checkTypeAnnotationNullable(type);
    return param.isOptional && type == null;
  }

  /// Checks nullability of a field formal parameter like `this.fieldName`.
  ///
  /// If the parameter has no type annotation, the corresponding field's
  /// type in the class declaration is checked.
  ///
  /// # Parameters
  /// - [param]: The [ast.FieldFormalParameter] to check.
  /// - [classDecl]: Optional containing class [ast.ClassDeclaration] to
  ///   look up the field type.
  ///
  /// # Returns
  /// `true` if the parameter is nullable, `false` otherwise.
  bool _checkFieldParameterNullable(ast.FieldFormalParameter param, ast.ClassDeclaration? classDecl) {
    final type = param.type;
    if (type != null) return checkTypeAnnotationNullable(type);

    if (classDecl != null) {
      final fieldName = param.name.lexeme;
      for (final member in classDecl.members) {
        if (member is ast.FieldDeclaration) {
          for (final variable in member.fields.variables) {
            if (variable.name.lexeme == fieldName) {
              final fieldType = member.fields.type;
              if (fieldType != null) return checkTypeAnnotationNullable(fieldType);
            }
          }
        }
      }
    }

    return false;
  }

  /// Checks nullability of a function-typed parameter like `String Function() callback`.
  ///
  /// Considers the `?` suffix on the parameter, the return type, and any
  /// type annotation nullability recursively.
  ///
  /// # Parameters
  /// - [param]: The [ast.FunctionTypedFormalParameter] to check.
  ///
  /// # Returns
  /// `true` if the parameter is nullable, `false` otherwise.
  bool _checkFunctionTypedParameterNullable(ast.FunctionTypedFormalParameter param) {
    final type = param.returnType;
    if (type != null) return checkTypeAnnotationNullable(type);
    return false;
  }

  /// Checks nullability of a super formal parameter like `super.param`.
  ///
  /// Considers the `?` suffix on the parameter and the type annotation.
  ///
  /// # Parameters
  /// - [param]: The [ast.SuperFormalParameter] to check.
  ///
  /// # Returns
  /// `true` if the parameter is nullable, `false` otherwise.
  bool _checkSuperParameterNullable(ast.SuperFormalParameter param) {
    final type = param.type;
    if (type != null) return checkTypeAnnotationNullable(type);
    return false;
  }

  /// Fallback method to check parameter nullability using simple pattern matching.
  ///
  /// Used when AST parsing fails. Scans the source code for `?` markers,
  /// `Null` types, and optional/positional parameter syntax.
  ///
  /// # Parameters
  /// - [sourceCode]: The source code of the method or constructor.
  /// - [methodName]: Name of the method or constructor.
  /// - [paramName]: Name of the parameter to check.
  /// - [className]: Optional containing class name.
  /// - [isConstructor]: Whether the parameter belongs to a constructor.
  /// - [constructorName]: Optional constructor name.
  ///
  /// # Returns
  /// `true` if the parameter is nullable, `false` otherwise.
  bool _fallbackNullableCheck(
    String sourceCode,
    String methodName,
    String paramName,
    String? className,
    bool isConstructor,
    String? constructorName,
  ) {
    final code = RuntimeUtils.stripComments(sourceCode);
    String pattern;

    if (isConstructor && className != null) {
      if (constructorName != null && constructorName.isNotEmpty) {
        pattern = RegExp.escape(className) + r'\s*\.\s*' + RegExp.escape(constructorName) + r'\s*\([^)]*';
      } else {
        pattern = r'\b' + RegExp.escape(className) + r'\s*\([^)]*';
      }
    } else if (className != null) {
      pattern = r'\b(?:static\s+)?' + RegExp.escape(methodName) + r'\s*\([^)]*';
    } else {
      pattern = r'\b' + RegExp.escape(methodName) + r'\s*\([^)]*';
    }

    final signatureMatch = RegExp(pattern, multiLine: true).firstMatch(code);
    if (signatureMatch == null) return false;

    final paramSection = signatureMatch.group(0) ?? '';
    final paramPatterns = [
      RegExp(r'\b[A-Za-z_][A-Za-z0-9_<>,\s]*\?\s+' + RegExp.escape(paramName) + r'\b'),
      RegExp(r'\bNull\s+' + RegExp.escape(paramName) + r'\b'),
      RegExp(r'\{\s*[A-Za-z_][A-Za-z0-9_<>,\s]*\?\s+' + RegExp.escape(paramName) + r'\s*\}'),
      RegExp(r'\[\s*[A-Za-z_][A-Za-z0-9_<>,\s]*\?\s+' + RegExp.escape(paramName) + r'\s*\]'),
      RegExp(r'\b[A-Za-z_][A-Za-z0-9_<>,\s]*\?\s+this\.' + RegExp.escape(paramName) + r'\b'),
    ];

    return paramPatterns.any((pattern) => pattern.hasMatch(paramSection));
  }
}

/// A lightweight internal model representing a single function or method
/// parameter, capturing both its AST node and whether the parameter is
/// nullable.
///
/// This class is used internally by the generator to simplify analysis of
/// parameter metadata—particularly when determining how to generate runtime
/// bindings, reflection metadata, or invocation adapters.
///
/// It does **not** perform any semantic evaluation on its own; it simply holds
/// structured information extracted from the analyzer AST.
///
/// ### Fields
/// - [isNullable] — whether the parameter's type is nullable (i.e., has a `?`).
/// - [param] — the underlying analyzer AST node representing the parameter.
///
/// ### Example (internal usage)
/// ```dart
/// final _Param p = _Param(
///   typeIsNullable(parameterElement.type),
///   parameterAstNode,
/// );
/// ```
final class _Param {
  /// Whether the parameter's type is nullable.
  ///
  /// This boolean typically reflects the presence of a `?` on the type, e.g.:
  /// `String? name` → `isNullable == true`
  /// `int count`    → `isNullable == false`
  final bool isNullable;

  /// The underlying analyzer AST representation of the parameter.
  ///
  /// Provides access to parameter metadata such as:
  /// - parameter name
  /// - type annotation
  /// - default value (if any)
  /// - whether it is positional, named, required, etc.
  final ast.FormalParameter? param;

  /// Creates a new internal parameter wrapper.
  ///
  /// - [isNullable] — whether the parameter type is nullable.
  /// - [param] — the raw AST node representing this parameter.
  const _Param(this.isNullable, this.param);
}