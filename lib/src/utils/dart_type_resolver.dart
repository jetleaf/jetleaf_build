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
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

Type? resolvePublicDartType(String uri, String className) {
  // Skip all private classes
  if (className.startsWith('_')) {
    return null;
  }

  // Handle core libraries
  switch (uri) {
    case 'dart:core':
      return _resolveCorePublicType(className);
    case 'dart:async':
      return _resolveAsyncPublicType(className);
    case 'dart:collection':
      return _resolveCollectionPublicType(className);
    case 'dart:math':
      return _resolveMathPublicType(className);
    case 'dart:convert':
      return _resolveConvertPublicType(className);
    case 'dart:io':
      return _resolveIoPublicType(className);
    case 'dart:ffi':
      return _resolveFfiPublicType(className);
    case 'dart:typed_data':
      return _resolveTypedDataPublicType(className);
    default:
      return null;
  }
}

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
    case 'Pointer': return Pointer;
    default: return null;
  }
}

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

Type? _resolveMathPublicType(String typeName) {
  switch (typeName) {
    case 'Rectangle': return Rectangle;
    case 'Point': return Point;
    case 'MutableRectangle': return MutableRectangle;
    default: return null;
  }
}

Type? _resolveConvertPublicType(String typeName) {
  switch (typeName) {
    case 'Codec': return Codec;
    case 'Converter': return Converter;
    case 'ChunkedConversionSink': return ChunkedConversionSink;
    default: return null;
  }
}

Type? _resolveIoPublicType(String typeName) {
  switch (typeName) {
    case 'ConnectionTask': return ConnectionTask;
    default: return null;
  }
}

Type? _resolveFfiPublicType(String typeName) {
  switch (typeName) {
    case 'Pointer': return Pointer;
    case 'NativeFunction': return NativeFunction;
    case 'Array': return Array;
    case 'NativeCallable': return NativeCallable;
    case 'VarArgs': return VarArgs;
    case 'Native': return Native;
    default: return null;
  }
}

Type? _resolveTypedDataPublicType(String typeName) {
  switch (typeName) {
    case 'TypedDataList': return TypedDataList;
    default: return null;
  }
}