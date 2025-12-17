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

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';
import 'dart:mirrors' as mirrors;
import 'dart:typed_data';

import '../classes.dart';

/// Resolves a **public Dart platform type** using a library URI and class name.
///
/// This utility is part of JetLeaf's reflective and generative runtime
/// type-resolution system. Many parts of the AOT pipeline must convert
/// metadata-level type descriptors (for example, `"dart:core" + "List"`)
/// into **actual Dart Type objects** that can be used for hint generation,
/// runtime execution, or serialization.
///
/// ## Behavior Overview
///
/// - Private class names (`_Something`) are automatically ignored and return
///   `null`.
/// - Only a *curated subset* of SDK types is supported — specifically those
///   exposed by the libraries JetLeaf requires for runtime reflection.
/// - Each supported SDK library (`dart:core`, `dart:async`, etc.) is delegated
///   to an internal resolver function.
/// - Unknown libraries or unknown type names return `null` rather than throwing.
///
/// ## Example
/// ```dart
/// resolvePublicDartType('dart:core', 'List'); // → List
/// resolvePublicDartType('dart:async', 'Stream'); // → Stream
/// resolvePublicDartType('dart:core', '_Hidden'); // → null
/// resolvePublicDartType('dart:fake', 'Foo'); // → null
/// ```
///
/// ## Usage Context
/// This function is primarily used during:
/// - RuntimeHint descriptor loading
/// - Type reconstruction during reflection snapshots
/// - AOT-reflection alignment with manually provided metadata
///
/// It is *not* intended for general-purpose type lookup.
///
/// Returns:
/// - A matching Dart `Type` if recognized, otherwise `null`.
Type? resolvePublicDartType(String uri, String className, [mirrors.DeclarationMirror? mirror]) {
  if (mirror != null) {
    final simpleName = mirrors.MirrorSystem.getName(mirror.simpleName);
    final qualifiedName = mirrors.MirrorSystem.getName(mirror.qualifiedName);

    if (resolvePublicDartType(mirror.location?.sourceUri.toString() ?? "", simpleName) case final type?) {
      return type;
    }

    if (resolvePublicDartType(qualifiedName, simpleName) case final type?) {
      return type;
    }
  }

  // Skip all private classes
  if (className.startsWith('_')) {
    return null;
  }

  if (uri.startsWith('dart:core') || uri.startsWith('dart.core')) {
    return _resolveCorePublicType(className);
  } else if (uri.startsWith('dart:async') || uri.startsWith('dart.async')) {
    return _resolveAsyncPublicType(className);
  } else if (uri.startsWith('dart:collection') || uri.startsWith('dart.collection')) {
    return _resolveCollectionPublicType(className);
  } else if (uri.startsWith('dart:math') || uri.startsWith('dart.math')) {
    return _resolveMathPublicType(className);
  } else if (uri.startsWith('dart:convert') || uri.startsWith('dart.convert')) {
    return _resolveConvertPublicType(className);
  } else if (uri.startsWith('dart:io') || uri.startsWith('dart.io')) {
    return _resolveIoPublicType(className);
  } else if (uri.startsWith('dart:ffi') || uri.startsWith('dart.ffi')) {
    return _resolveFfiPublicType(className);
  } else if (uri.startsWith('dart:typed_data') || uri.startsWith('dart.typed_data')) {
    return _resolveTypedDataPublicType(className);
  }

  if (className == "void") {
    return Void;
  }

  if (className == "dynamic") {
    return Dynamic;
  }

  return null;
}

/// Resolves a subset of public types from `dart:core`.
///
/// Supports only the types used within JetLeaf’s runtime analysis layer.
///
/// Returns `null` if the type name is not recognized.
Type? _resolveCorePublicType(String typeName) {
  switch (typeName) {
    case 'List': return List;
    case 'Set': return Set;
    case 'Map': return Map;
    case 'MapEntry': return MapEntry;
    case 'Iterable': return Iterable;
    case 'Iterator': return Iterator;
    case 'WeakReference': return WeakReference;
    case 'Finalizer': return Finalizer;
    case 'Sink': return Sink;
    case 'Expando': return Expando;
    case 'Comparable': return Comparable;
    case 'Pointer': return ffi.Pointer;
    default: return null;
  }
}

/// Resolves a subset of public types from `dart:async`.
///
/// Includes common asynchronous primitives such as `Future`, `Stream`,
/// controllers, transformers, and related foundational classes.
Type? _resolveAsyncPublicType(String typeName) {
  switch (typeName) {
    case 'Future': return Future;
    case 'Stream': return Stream;
    case 'EventSink': return EventSink;
    case 'FutureOr': return FutureOr;
    case 'StreamConsumer': return StreamConsumer;
    case 'StreamController': return StreamController;
    case 'StreamSubscription': return StreamSubscription;
    case 'StreamTransformerBase': return StreamTransformerBase;
    case 'StreamSink': return StreamSink;
    case 'StreamTransformer': return StreamTransformer;
    case 'MultiStreamController': return MultiStreamController;
    case 'SynchronousStreamController': return SynchronousStreamController;
    case 'Completer': return Completer;
    case 'StreamIterator': return StreamIterator;
    case 'StreamView': return StreamView;
    case 'ParallelWaitError': return ParallelWaitError;
    default: return null;
  }
}

/// Resolves public types from `dart:collection`.
///
/// Covers many collection variants including views, trees, queues, and
/// unmodifiable wrappers.
Type? _resolveCollectionPublicType(String typeName) {
  switch (typeName) {
    case 'MapView': return MapView;
    case 'SetBase': return SetBase;
    case 'LinkedHashSet': return LinkedHashSet;
    case 'LinkedHashMap': return LinkedHashMap;
    case 'DoubleLinkedQueue': return DoubleLinkedQueue;
    case 'HasNextIterator': return HasNextIterator;
    case 'SplayTreeMap': return SplayTreeMap;
    case 'SplayTreeSet': return SplayTreeSet;
    case 'LinkedListEntry': return LinkedListEntry;
    case 'LinkedList': return LinkedList;
    case 'UnmodifiableMapView': return UnmodifiableMapView;
    case 'UnmodifiableSetView': return UnmodifiableSetView;
    case 'UnmodifiableMapBase': return UnmodifiableMapBase;
    case 'MapBase': return MapBase;
    case 'ListQueue': return ListQueue;
    case 'HashSet': return HashSet;
    case 'ListBase': return ListBase;
    case 'HashMap': return HashMap;
    case 'Queue': return Queue;
    case 'UnmodifiableListView': return UnmodifiableListView;
    default: return null;
  }
}

/// Resolves numeric geometry types from `dart:math`.
///
/// Includes 2D shapes and coordinate classes like [Point] and [Rectangle].
Type? _resolveMathPublicType(String typeName) {
  switch (typeName) {
    case 'Rectangle': return Rectangle;
    case 'Point': return Point;
    case 'MutableRectangle': return MutableRectangle;
    default: return null;
  }
}

/// Resolves conversion-related types from `dart:convert`.
///
/// Supports foundational codec and conversion types.
Type? _resolveConvertPublicType(String typeName) {
  switch (typeName) {
    case 'Codec': return Codec;
    case 'Converter': return Converter;
    case 'ChunkedConversionSink': return ChunkedConversionSink;
    default: return null;
  }
}


/// Resolves a subset of public types from `dart:io`.
///
/// Only includes types required internally by JetLeaf.
Type? _resolveIoPublicType(String typeName) {
  switch (typeName) {
    case 'ConnectionTask': return ConnectionTask;
    default: return null;
  }
}

/// Resolves FFI interop types from `dart:ffi`.
///
/// This includes pointer types, native function descriptors, varargs support,
/// and wrapper classes required for low-level native integration.
Type? _resolveFfiPublicType(String typeName) {
  switch (typeName) {
    case 'Pointer': return ffi.Pointer;
    case 'NativeFunction': return ffi.NativeFunction;
    case 'Array': return ffi.Array;
    case 'NativeCallable': return ffi.NativeCallable;
    case 'VarArgs': return ffi.VarArgs;
    case 'Native': return ffi.Native;
    default: return null;
  }
}

/// Resolves typed-data types from `dart:typed_data`.
///
/// This layer is intentionally shallow and only includes the types JetLeaf
/// may need to deserialize or reflect.
Type? _resolveTypedDataPublicType(String typeName) {
  switch (typeName) {
    case 'TypedDataList': return TypedDataList;
    default: return null;
  }
}