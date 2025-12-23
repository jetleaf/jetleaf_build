import 'dart:mirrors' as mirrors;

import '../declaration/declaration.dart';
import 'abstract_function_declaration_support.dart';
import 'abstract_material_library_analyzer_support.dart';

/// {@template abstract_record_link_declaration_support}
/// Abstract base class providing **record-type link generation support**
/// for the JetLeaf linking and runtime reflection system.
///
/// `AbstractRecordDeclarationSupport` extends
/// [AbstractFunctionDeclarationSupport] with specialized logic for
/// resolving, normalizing, and materializing **Dart record type declarations**
/// (`Record`) from analyzer metadata and runtime mirrors.
///
/// ## Responsibilities
/// This class is responsible for:
/// - Detecting whether a given type truly represents a Dart record.
/// - Translating analyzer [AnalyzedRecordTypeAnnotation] instances into canonical
///   [RecordDeclaration] objects.
/// - Decomposing records into **named** and **positional** fields while
///   preserving declaration order.
/// - Generating [RecordFieldDeclaration] instances with accurate
///   nullability, position, and type-argument information.
/// - Resolving runtime and static type identities for record fields.
///
/// ## Analyzer-Driven Resolution
/// Record link generation is primarily **analyzer-based**, relying on:
/// - [AnalyzedRecordTypeAnnotation], [RecordTypeField], and related analyzer structures
/// - Analyzer nullability metadata for both records and individual fields
///
/// Runtime mirrors are used opportunistically for:
/// - Runtime type discovery
/// - Canonical URI and qualified-name resolution
///
/// ## Design Notes
/// - This class assumes that record detection has already been validated
///   before generation begins.
/// - Field-level link generation reuses the shared type-link infrastructure
///   to ensure consistency with classes, functions, and generics.
/// - The implementation is designed to safely support nested, generic,
///   and nullable record types without introducing resolution cycles.
///
/// This class forms the **record-type counterpart** to function-type linking
/// within JetLeaf’s type-aware runtime linking pipeline, enabling precise
/// structural modeling of Dart records across build-time and runtime systems.
/// {@endtemplate}
abstract class AbstractRecordDeclarationSupport extends AbstractFunctionDeclarationSupport {
  /// {@macro abstract_record_link_declaration_support}
  AbstractRecordDeclarationSupport();

  @override
  RecordDeclaration? generateRecordDeclaration(mirrors.TypeMirror mirror, String libraryUri, AnalyzedTypeAnnotation dartType) {
    if (_determineAndReturnRecordType(dartType) case final recordDartType?) {
      final recordName = mirrors.MirrorSystem.getName(mirror.simpleName);
      final type = mirror.reflectedType; // We can do this because isReallyARecord makes sure that this function is only called when there is a reflected type - Record
      final namedFields = recordDartType.namedFields;
      final positionalFields = recordDartType.positionalFields;

      final fields = <RecordFieldDeclaration>[];

      for (final field in namedFields?.fields ?? []) {
        fields.add(_generateField(field, libraryUri));
      }

      for (int position = 0; position < positionalFields.length; position++) {
        final field = positionalFields[position];
        fields.add(_generateField(field, libraryUri, position));
      }

      final uri = findRealClassUriFromMirror(mirror) ?? Uri.parse(libraryUri);

      return StandardRecordDeclaration(
        name: recordDartType.toString(),
        type: type,
        pointerType: type,
        library: getLibrary(libraryUri),
        qualifiedName: buildQualifiedName(recordName, libraryUri),
        isPublic: !mirror.isPrivate,
        isSynthetic: false,
        isNullable: checkTypeAnnotationNullable(recordDartType),
        canonicalUri: uri,
        referenceUri: uri,
        recordFields: fields,
      );
    } else {
      return null;
    }
  }

  /// Determines whether the provided [AnalyzedTypeAnnotation] represents a **record type**
  /// and returns the corresponding analyzer [AnalyzedRecordTypeAnnotation] if found.
  ///
  /// This method performs a **recursive unwrapping strategy** to handle cases
  /// where records are nested inside function return types. In particular:
  /// - If [type] is a [AnalyzedRecordTypeAnnotation], it is returned directly.
  /// - If [type] is a [FunctionType], its return type is inspected recursively.
  /// - All other types are treated as non-records.
  ///
  /// This allows the record-link generation pipeline to transparently support
  /// higher-order functions that return records without duplicating logic.
  ///
  /// ### Parameters
  /// - [type] — The analyzer [AnalyzedTypeAnnotation] to inspect.
  ///
  /// ### Returns
  /// The resolved [AnalyzedRecordTypeAnnotation] if the type (or its return type) is a record;
  /// otherwise, `null`.
  AnalyzedRecordTypeAnnotation? _determineAndReturnRecordType(AnalyzedTypeAnnotation? type) {
    if (type case AnalyzedRecordTypeAnnotation type?) {
      return type;
    }

    if (type case AnalyzedGenericFunctionTypeAnnotation type) {
      return _determineAndReturnRecordType(type.returnType);
    }

    return null;
  }

  /// Generates a fully materialized [RecordFieldDeclaration] for a single
  /// record field.
  ///
  /// This method resolves both **runtime** and **static** metadata for the
  /// given [RecordTypeField], ensuring that each field:
  /// - Has an accurate runtime [Type]
  /// - Preserves analyzer-derived nullability and field shape
  /// - Correctly resolves and attaches generic type arguments
  /// - Produces a stable, canonical [LinkDeclaration] for downstream use
  ///
  /// Both **named** and **positional** record fields are supported. Positional
  /// fields are assigned an explicit [position] index, while named fields
  /// derive their identity from the analyzer field name.
  ///
  /// ### Parameters
  /// - [field] — The analyzer record field to materialize.
  /// - [libraryUri] — The URI of the declaring library.
  /// - [position] — Optional positional index for positional record fields.
  ///
  /// ### Returns
  /// A [Future] that completes with a fully populated
  /// [RecordFieldDeclaration] describing the record field.
  RecordFieldDeclaration _generateField(AnalyzedRecordTypeAnnotationField field, String libraryUri, [int? position]) {
    final fieldType = findRuntimeTypeFromDartType(field.type, libraryUri);
    final fieldMirror = mirrors.reflectType(fieldType);
    final uri = fieldMirror.location?.sourceUri.toString() ?? libraryUri;

    final link = getLinkDeclaration(fieldMirror, uri, field.type);
    List<LinkDeclaration> arguments = [];

    if (field.type case AnalyzedNamedType dartType) {
      final typeArgs = dartType.typeArguments?.arguments ?? <AnalyzedTypeAnnotation>[];
      List<mirrors.TypeMirror> typeArguments = [];

      for (final arg in typeArgs) {
        typeArguments.add(getMirroredTypeAnnotation(arg, libraryUri));
      }

      arguments = extractTypeArgumentAsLinks(typeArguments, typeArgs, libraryUri);
    }

    return StandardRecordFieldDeclaration(
      name: field is AnalyzedRecordTypeAnnotationNamedField ? field.name.toString() : field.name?.toString() ?? "Unnamed",
      isPublic: true,
      isSynthetic: false,
      type: fieldType,
      position: position ?? -1,
      sourceLocation: Uri.parse(uri),
      isNullable: checkTypeAnnotationNullable(field.type),
      isNamed: field is AnalyzedRecordTypeAnnotationNamedField,
      linkDeclaration: StandardLinkDeclaration(
        name: link.getName(),
        type: link.getType(),
        pointerType: link.getPointerType(),
        typeArguments: arguments,
        qualifiedName: link.getPointerQualifiedName(),
        canonicalUri: link.getCanonicalUri(),
        referenceUri: link.getReferenceUri(),
        isPublic: link.getIsPublic(),
        isSynthetic: link.getIsSynthetic(),
      )
    );
  }
}