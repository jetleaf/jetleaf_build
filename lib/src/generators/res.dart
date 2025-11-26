// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

// import 'dart:async' as dart_async;
// import 'dart:collection' as dart_collection;
// import 'dart:convert' as dart_convert;
// import 'dart:ffi' as dart_ffi;
// import 'dart:io' as dart_io;
// import 'dart:isolate' as dart_isolate;
// import 'dart:math' as dart_math;
// import 'dart:mirrors' as dart_mirrors;
// import 'dart:typed_data' as dart_typed_data;

// import 'package:analyzer/dart/analysis/analysis_context_collection.dart' as analyzer_analysis_context_collection;
// import 'package:analyzer/dart/analysis/results.dart' as analyzer_analysis_results;
// import 'package:analyzer/dart/element/element.dart' as analyzer_dart_element_element;
// import 'package:analyzer/file_system/physical_file_system.dart' as analyzer_file_system_physical_file_system;
// import 'package:jetleaf_lang/lang.dart';

// /// This will be the class each file generated will extend or implement in order to provide the necessary
// /// generated declarations while resolving type issues
// abstract class RuntimeDeclaration {
//   List<LibraryDeclaration> getLibraryDeclarations();
//   /// ... add other declarations here
// }

// /// Example of a class using the RuntimeDeclaration
// class DartCoreRuntimeDeclaration extends RuntimeDeclaration {
//   List<LibraryDeclaration> getLibraryDeclaration() => [
//     // Here, you will write the LibraryDeclaration generated for dart_core library
//     // While doing so, when you get to where the type is, you can then do: type: dart_core.String,
//     // while making sure the correct type is used for each - you can use qualifiedName as a helper.
//   ];

//   /// .. This will also contain other declarations generated for dart_core library like
//   /// ClassDeclaration, ParameterDeclaration, etc.
//   /// 
//   /// Since dart_core library might make the use of normal things be errored, you have to handle those specific issue
//   /// 
//   /// this means, doing `import 'dart_core' as dart_core; will make writing something like
//   /// int a = 3; an error since int is a class in dart_core which the dart sdk resolves without importing the library.
//   /// 
//   /// So, the solution now has to be dart_core.int a = 3;
// }