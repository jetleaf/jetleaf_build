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

import 'dart:typed_data';
import 'package:jetleaf_build/src/helpers/equals_and_hash_code.dart';
import 'package:test/test.dart';

/// A model that includes raw bytes (`Uint8List`) and complex nested data
class Document with EqualsAndHashCode {
  final String id;
  final Uint8List content;
  final Map<String, dynamic> metadata;
  final List<String> tags;

  Document(this.id, this.content, this.metadata, this.tags);

  @override
  List<Object?> equalizedProperties() => [id, content, metadata, tags];
}

/// A model that wraps nested objects (composition test)
class Folder with EqualsAndHashCode {
  final String name;
  final List<Document> documents;

  Folder(this.name, this.documents);

  @override
  List<Object?> equalizedProperties() => [name, documents];
}

void main() {
  group('EqualsAndHashCode (Uint8List + complex data types)', () {
    test('Uint8List with identical bytes are equal', () {
      final bytesA = Uint8List.fromList([1, 2, 3, 4, 5]);
      final bytesB = Uint8List.fromList([1, 2, 3, 4, 5]);

      final docA = Document('doc1', bytesA, {'author': 'Alice'}, ['tag1']);
      final docB = Document('doc1', bytesB, {'author': 'Alice'}, ['tag1']);

      expect(docA, equals(docB));
      expect(docA.hashCode, equals(docB.hashCode));
    });

    test('Uint8List with different content are not equal', () {
      final bytesA = Uint8List.fromList([1, 2, 3, 4, 5]);
      final bytesB = Uint8List.fromList([9, 9, 9, 9, 9]);

      final docA = Document('doc1', bytesA, {'author': 'Alice'}, ['tag1']);
      final docB = Document('doc1', bytesB, {'author': 'Alice'}, ['tag1']);

      expect(docA, isNot(equals(docB)));
      expect(docA.hashCode, isNot(equals(docB.hashCode)));
    });

    test('metadata deep equality works', () {
      final docA = Document('doc1', Uint8List.fromList([1]), {
        'author': 'Alice',
        'nested': {'key': 'value'}
      }, ['tag1']);

      final docB = Document('doc1', Uint8List.fromList([1]), {
        'author': 'Alice',
        'nested': {'key': 'value'}
      }, ['tag1']);

      expect(docA, equals(docB));
    });

    test('order of list in metadata or tags matters', () {
      final docA = Document('doc1', Uint8List.fromList([1]), {
        'list': [1, 2, 3]
      }, ['tag1', 'tag2']);

      final docB = Document('doc1', Uint8List.fromList([1]), {
        'list': [3, 2, 1] // different order
      }, ['tag2', 'tag1']); // different order

      expect(docA, isNot(equals(docB)));
    });

    test('Folder equality with nested documents', () {
      final docA = Document('doc1', Uint8List.fromList([1, 2]), {'author': 'Alice'}, ['x']);
      final docB = Document('doc1', Uint8List.fromList([1, 2]), {'author': 'Alice'}, ['x']);

      final folder1 = Folder('root', [docA]);
      final folder2 = Folder('root', [docB]);

      expect(folder1, equals(folder2));
      expect(folder1.hashCode, equals(folder2.hashCode));
    });

    test('Folder inequality with different nested document content', () {
      final docA = Document('doc1', Uint8List.fromList([1, 2]), {'author': 'Alice'}, ['x']);
      final docB = Document('doc1', Uint8List.fromList([9, 9]), {'author': 'Alice'}, ['x']);

      final folder1 = Folder('root', [docA]);
      final folder2 = Folder('root', [docB]);

      expect(folder1, isNot(equals(folder2)));
    });
  });
}