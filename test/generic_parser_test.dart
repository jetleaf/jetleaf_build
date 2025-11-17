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

import 'package:jetleaf_build/src/runtime/utils/generic_type_parser.dart';
import 'package:test/test.dart';

void main() {
  group('GenericParser', () {
    group('extractGenericPart', () {
      test('should extract simple generic part', () {
        expect(GenericTypeParser.extractGenericPart('List<String>'), equals('String'));
        expect(GenericTypeParser.extractGenericPart('Map<String, int>'), equals('String, int'));
      });

      test('should extract nested generic part', () {
        expect(GenericTypeParser.extractGenericPart('List<Map<String, int>>'), equals('Map<String, int>'));
        expect(GenericTypeParser.extractGenericPart('Map<String, List<int>>'), equals('String, List<int>'));
      });

      test('should return empty string for non-generic types', () {
        expect(GenericTypeParser.extractGenericPart('String'), equals(''));
        expect(GenericTypeParser.extractGenericPart('int'), equals(''));
      });

      test('should return empty string for malformed generic types', () {
        expect(GenericTypeParser.extractGenericPart('List<'), equals(''));
        expect(GenericTypeParser.extractGenericPart('List>'), equals(''));
        expect(GenericTypeParser.extractGenericPart('List><'), equals(''));
        expect(GenericTypeParser.extractGenericPart(''), equals(''));
      });

      test('should handle multiple nested levels', () {
        expect(GenericTypeParser.extractGenericPart('List<Map<String, List<int>>>'), 
               equals('Map<String, List<int>>'));
      });
    });

    group('parseGenericTypes', () {
      test('should parse simple generic types', () {
        final results = GenericTypeParser.parseGenericTypes('String');
        expect(results.length, equals(1));
        expect(results[0].base, equals('String'));
        expect(results[0].types, equals([]));
      });

      test('should parse multiple simple types', () {
        final results = GenericTypeParser.parseGenericTypes('String, int');
        expect(results.length, equals(2));
        expect(results[0].base, equals('String'));
        expect(results[1].base, equals('int'));
      });

      test('should parse nested generic types', () {
        final results = GenericTypeParser.parseGenericTypes('Map<String, int>');
        expect(results.length, equals(1));
        expect(results[0].base, equals('Map'));
        expect(results[0].types.length, equals(2));
        expect(results[0].types[0].base, equals('String'));
        expect(results[0].types[1].base, equals('int'));
      });

      test('should handle empty input', () {
        expect(GenericTypeParser.parseGenericTypes(''), equals([]));
      });

      test('should handle complex nested structures', () {
        final results = GenericTypeParser.parseGenericTypes('Map<String, List<int>>, Set<bool>');
        expect(results.length, equals(2));
        
        // First result: Map<String, List<int>>
        expect(results[0].base, equals('Map'));
        expect(results[0].types.length, equals(2));
        expect(results[0].types[0].base, equals('String'));
        expect(results[0].types[1].base, equals('List'));
        expect(results[0].types[1].types.length, equals(1));
        expect(results[0].types[1].types[0].base, equals('int'));
        
        // Second result: Set<bool>
        expect(results[1].base, equals('Set'));
        expect(results[1].types.length, equals(1));
        expect(results[1].types[0].base, equals('bool'));
      });
    });

    group('splitGenericParts', () {
      test('should split simple comma-separated parts', () {
        expect(GenericTypeParser.splitGenericParts('String, int'), equals(['String', 'int']));
        expect(GenericTypeParser.splitGenericParts('a, b, c'), equals(['a', 'b', 'c']));
      });

      test('should handle nested generics without splitting inner commas', () {
        expect(GenericTypeParser.splitGenericParts('Map<String, int>, List<bool>'), 
               equals(['Map<String, int>', 'List<bool>']));
      });

      test('should handle deeply nested generics', () {
        expect(GenericTypeParser.splitGenericParts('Map<String, List<Map<int, bool>>>, Set<String>'), 
               equals(['Map<String, List<Map<int, bool>>>', 'Set<String>']));
      });

      test('should handle single part without commas', () {
        expect(GenericTypeParser.splitGenericParts('String'), equals(['String']));
        expect(GenericTypeParser.splitGenericParts('Map<String, int>'), equals(['Map<String, int>']));
      });

      test('should handle empty input', () {
        expect(GenericTypeParser.splitGenericParts(''), equals([]));
      });
    });

    group('isGeneric', () {
      test('should identify generic types', () {
        expect(GenericTypeParser.isGeneric('List<String>'), isTrue);
        expect(GenericTypeParser.isGeneric('Map<String, int>'), isTrue);
        expect(GenericTypeParser.isGeneric('Set<bool>'), isTrue);
      });

      test('should identify non-generic types', () {
        expect(GenericTypeParser.isGeneric('String'), isFalse);
        expect(GenericTypeParser.isGeneric('int'), isFalse);
        expect(GenericTypeParser.isGeneric('bool'), isFalse);
      });

      test('should handle malformed generic syntax', () {
        expect(GenericTypeParser.isGeneric('List<'), isFalse);
        expect(GenericTypeParser.isGeneric('List>'), isFalse);
        expect(GenericTypeParser.isGeneric('><'), isFalse);
      });

      test('should handle nested generics', () {
        expect(GenericTypeParser.isGeneric('List<Map<String, int>>'), isTrue);
        expect(GenericTypeParser.isGeneric('Map<String, List<bool>>'), isTrue);
      });
    });

    group('resolveGenericType', () {
      test('should resolve simple generic types', () {
        final result = GenericTypeParser.resolveGenericType('List<String>');
        expect(result.base, equals('List'));
        expect(result.types.length, equals(1));
        expect(result.types[0].base, equals('String'));
        expect(result.typeString, equals('List<String>'));
      });

      test('should resolve multiple generic parameters', () {
        final result = GenericTypeParser.resolveGenericType('Map<String, int>');
        expect(result.base, equals('Map'));
        expect(result.types.length, equals(2));
        expect(result.types[0].base, equals('String'));
        expect(result.types[1].base, equals('int'));
        expect(result.typeString, equals('Map<String, int>'));
      });

      test('should handle caveat types (_Map, _Set)', () {
        final mapResult = GenericTypeParser.resolveGenericType('_Map<String, int>');
        expect(mapResult.base, equals('Map')); // underscore removed
        expect(mapResult.types.length, equals(2));
        expect(mapResult.types[0].base, equals('String'));
        expect(mapResult.types[1].base, equals('int'));

        final setResult = GenericTypeParser.resolveGenericType('_Set<String>');
        expect(setResult.base, equals('Set')); // underscore removed
        expect(setResult.types.length, equals(1));
        expect(setResult.types[0].base, equals('String'));
      });

      test('should handle nested generic types recursively', () {
        final result = GenericTypeParser.resolveGenericType('List<Map<String, int>>');
        expect(result.base, equals('List'));
        expect(result.types.length, equals(1));
        expect(result.types[0].base, equals('Map'));
        expect(result.types[0].types.length, equals(2));
        expect(result.types[0].types[0].base, equals('String'));
        expect(result.types[0].types[1].base, equals('int'));
        expect(result.typeString, equals('List<Map<String, int>>'));
      });

      test('should handle non-generic types', () {
        final result = GenericTypeParser.resolveGenericType('String');
        expect(result.base, equals('String'));
        expect(result.types, equals([]));
        expect(result.typeString, equals('String'));
      });

      test('should handle empty generic parameters', () {
        final result = GenericTypeParser.resolveGenericType('List<>');
        expect(result.base, equals('List'));
        expect(result.types, equals([]));
        expect(result.typeString, equals('List<>'));
      });

      test('should handle deeply nested structures', () {
        final result = GenericTypeParser.resolveGenericType('List<List<Map<int, String>>>');
        expect(result.base, equals('List'));
        expect(result.types.length, equals(1));
        
        // First nested List
        final innerList = result.types[0];
        expect(innerList.base, equals('List'));
        expect(innerList.types.length, equals(1));
        
        // Map inside the inner List
        final map = innerList.types[0];
        expect(map.base, equals('Map'));
        expect(map.types.length, equals(2));
        expect(map.types[0].base, equals('int'));
        expect(map.types[1].base, equals('String'));
      });
    });
  });

  group('GenericParsingResult', () {
    test('should create instance with all properties', () {
      final stringResult = GenericTypeParsingResult('String', 'String', []);
      final result = GenericTypeParsingResult('List', 'List<String>', [stringResult]);
      
      expect(result.base, equals('List'));
      expect(result.types.length, equals(1));
      expect(result.types[0].base, equals('String'));
      expect(result.typeString, equals('List<String>'));
    });

    test('should handle empty generic types list', () {
      final result = GenericTypeParsingResult('String', 'String', []);
      
      expect(result.base, equals('String'));
      expect(result.types, equals([]));
      expect(result.typeString, equals('String'));
    });

    test('should handle multiple generic types', () {
      final stringResult = GenericTypeParsingResult('String', 'String', []);
      final intResult = GenericTypeParsingResult('int', 'int', []);
      final result = GenericTypeParsingResult('Map', 'Map<String, int>', [stringResult, intResult]);
      
      expect(result.base, equals('Map'));
      expect(result.types.length, equals(2));
      expect(result.types[0].base, equals('String'));
      expect(result.types[1].base, equals('int'));
      expect(result.typeString, equals('Map<String, int>'));
    });
  });

  group('Integration tests', () {
    test('should handle real-world generic type parsing scenarios', () {
      // Test common Flutter/Dart generic types
      final listResult = GenericTypeParser.resolveGenericType('List<Widget>');
      expect(listResult.base, equals('List'));
      expect(listResult.types.length, equals(1));
      expect(listResult.types[0].base, equals('Widget'));

      final mapResult = GenericTypeParser.resolveGenericType('Map<String, dynamic>');
      expect(mapResult.base, equals('Map'));
      expect(mapResult.types.length, equals(2));
      expect(mapResult.types[0].base, equals('String'));
      expect(mapResult.types[1].base, equals('dynamic'));

      final futureResult = GenericTypeParser.resolveGenericType('Future<List<String>>');
      expect(futureResult.base, equals('Future'));
      expect(futureResult.types.length, equals(1));
      expect(futureResult.types[0].base, equals('List'));
      expect(futureResult.types[0].types.length, equals(1));
      expect(futureResult.types[0].types[0].base, equals('String'));
    });

    test('should handle edge cases gracefully', () {
      // Malformed inputs should not crash
      expect(() => GenericTypeParser.resolveGenericType('List<String'), returnsNormally);
      expect(() => GenericTypeParser.resolveGenericType('List>String<'), returnsNormally);
      expect(() => GenericTypeParser.resolveGenericType(''), returnsNormally);
      expect(() => GenericTypeParser.resolveGenericType('<<<>>>'), returnsNormally);
    });

    test('should demonstrate the recursive parsing structure', () {
      // This test shows the exact structure you requested
      final result = GenericTypeParser.resolveGenericType('List<List<Map<int, String>>>');
      
      // Base level: List<List<Map<int, String>>>
      expect(result.base, equals('List'));
      expect(result.typeString, equals('List<List<Map<int, String>>>'));
      expect(result.types.length, equals(1));
      
      // First nested level: List<Map<int, String>>
      final innerList = result.types[0];
      expect(innerList.base, equals('List'));
      expect(innerList.typeString, equals('List<Map<int, String>>'));
      expect(innerList.types.length, equals(1));
      
      // Second nested level: Map<int, String>
      final map = innerList.types[0];
      expect(map.base, equals('Map'));
      expect(map.typeString, equals('Map<int, String>'));
      expect(map.types.length, equals(2));
      
      // Final level: int and String
      expect(map.types[0].base, equals('int'));
      expect(map.types[0].typeString, equals('int'));
      expect(map.types[0].types, equals([]));
      
      expect(map.types[1].base, equals('String'));
      expect(map.types[1].typeString, equals('String'));
      expect(map.types[1].types, equals([]));
    });
  });
}
