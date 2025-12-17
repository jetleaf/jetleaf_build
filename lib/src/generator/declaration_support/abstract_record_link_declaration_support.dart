import 'dart:mirrors' as mirrors;

import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../declaration/declaration.dart';
import 'abstract_function_link_declaration_support.dart';

/// {@template abstract_record_link_declaration_support}
/// Abstract base class providing **record-type link generation support**
/// for the JetLeaf linking and runtime reflection system.
///
/// `AbstractRecordLinkDeclarationSupport` extends
/// [AbstractFunctionLinkDeclarationSupport] with specialized logic for
/// resolving, normalizing, and materializing **Dart record type declarations**
/// (`Record`) from analyzer metadata and runtime mirrors.
///
/// ## Responsibilities
/// This class is responsible for:
/// - Detecting whether a given type truly represents a Dart record.
/// - Translating analyzer [RecordType] instances into canonical
///   [RecordLinkDeclaration] objects.
/// - Decomposing records into **named** and **positional** fields while
///   preserving declaration order.
/// - Generating [RecordFieldDeclaration] instances with accurate
///   nullability, position, and type-argument information.
/// - Resolving runtime and static type identities for record fields.
///
/// ## Analyzer-Driven Resolution
/// Record link generation is primarily **analyzer-based**, relying on:
/// - [RecordType], [RecordTypeField], and related analyzer structures
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
abstract class AbstractRecordLinkDeclarationSupport extends AbstractFunctionLinkDeclarationSupport {
  /// {@macro abstract_record_link_declaration_support}
  AbstractRecordLinkDeclarationSupport({required super.mirrorSystem, required super.forceLoadedMirrors, required super.configuration, required super.packages});

  @override
  Future<RecordLinkDeclaration?> generateRecordLinkDeclaration(mirrors.TypeMirror mirror, Package package, String libraryUri, DartType dartType) async {
    if (_determineAndReturnRecordType(dartType) case final recordDartType?) {
      final recordName = mirrors.MirrorSystem.getName(mirror.simpleName);
      final type = mirror.reflectedType; // We can do this because isReallyARecord makes sure that this function is only called when there is a reflected type - Record
      final namedFields = recordDartType.namedFields;
      final positionalFields = recordDartType.positionalFields;

      final fields = <RecordFieldDeclaration>[];

      for (final field in namedFields) {
        fields.add(await _generateField(field, package, libraryUri));
      }

      for (int position = 0; position < positionalFields.length; position++) {
        final field = positionalFields[position];
        fields.add(await _generateField(field, package, libraryUri, position));
      }

      return StandardRecordLinkDeclaration(
        name: recordDartType.getDisplayString(),
        type: type,
        pointerType: type,
        qualifiedName: buildQualifiedName(recordName, libraryUri),
        isPublic: !mirror.isPrivate,
        isSynthetic: false,
        dartType: recordDartType,
        isNullable: recordDartType.nullabilitySuffix == NullabilitySuffix.question,
        canonicalUri: mirror.location?.sourceUri ?? Uri.parse(libraryUri),
        referenceUri: mirror.location?.sourceUri ?? Uri.parse(libraryUri),
        fields: fields,
      );
    } else {
      return null;
    }
  }

  /// Determines whether the provided [DartType] represents a **record type**
  /// and returns the corresponding analyzer [RecordType] if found.
  ///
  /// This method performs a **recursive unwrapping strategy** to handle cases
  /// where records are nested inside function return types. In particular:
  /// - If [type] is a [RecordType], it is returned directly.
  /// - If [type] is a [FunctionType], its return type is inspected recursively.
  /// - All other types are treated as non-records.
  ///
  /// This allows the record-link generation pipeline to transparently support
  /// higher-order functions that return records without duplicating logic.
  ///
  /// ### Parameters
  /// - [type] — The analyzer [DartType] to inspect.
  ///
  /// ### Returns
  /// The resolved [RecordType] if the type (or its return type) is a record;
  /// otherwise, `null`.
  RecordType? _determineAndReturnRecordType(DartType type) {
    if (type case RecordType type) {
      return type;
    }

    if (type case FunctionType type) {
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
  /// - [package] — The package context used for type resolution.
  /// - [libraryUri] — The URI of the declaring library.
  /// - [position] — Optional positional index for positional record fields.
  ///
  /// ### Returns
  /// A [Future] that completes with a fully populated
  /// [RecordFieldDeclaration] describing the record field.
  Future<RecordFieldDeclaration> _generateField(RecordTypeField field, Package package, String libraryUri, [int? position]) async {
    final fieldType = await findRuntimeTypeFromDartType(field.type, libraryUri, package);
    final fieldMirror = mirrors.reflectType(fieldType);
    final fieldClassName = mirrors.MirrorSystem.getName(fieldMirror.simpleName);
    final uri = fieldMirror.location?.sourceUri.toString() ?? libraryUri;

    final link = await getLinkDeclaration(fieldMirror, package, uri, field.type);
    List<LinkDeclaration> arguments = [];

    if (field.type case InterfaceType dartType) {
      final typeArgs = dartType.typeArguments;
      List<mirrors.TypeMirror> typeArguments = [];

      for (final arg in typeArgs) {
        typeArguments.add(await _getMirror(arg, package, libraryUri));
      }

      arguments = await extractTypeArgumentAsLinks(typeArguments, typeArgs, package, libraryUri);
    }

    return StandardRecordFieldDeclaration(
      name: field is RecordTypeNamedField ? field.name : "Unnamed",
      isPublic: true,
      isSynthetic: false,
      type: fieldType,
      position: position ?? -1,
      isNullable: field.type.nullabilitySuffix == NullabilitySuffix.question,
      pointerType: fieldType,
      qualifiedName: buildQualifiedName(fieldClassName, uri),
      dartType: field.type,
      fieldType: field,
      fieldLink: StandardLinkDeclaration(
        name: link.getName(),
        type: link.getType(),
        pointerType: link.getPointerType(),
        typeArguments: arguments,
        qualifiedName: link.getPointerQualifiedName(),
        canonicalUri: link.getCanonicalUri(),
        referenceUri: link.getReferenceUri(),
        variance: link.getVariance(),
        upperBound: link.getUpperBound(),
        dartType: link.getDartType(),
        isPublic: link.getIsPublic(),
        isSynthetic: link.getIsSynthetic(),
      )
    );
  }

  /// Resolves a runtime [mirrors.TypeMirror] from an analyzer [DartType].
  ///
  /// This helper bridges the analyzer and reflection worlds by:
  /// - Resolving the concrete runtime [Type] associated with [dartType]
  /// - Reflecting that runtime type into a [mirrors.TypeMirror]
  ///
  /// It is primarily used during record-field processing to enable
  /// reflection-based extraction of type metadata that is not available
  /// directly from analyzer structures.
  ///
  /// ### Parameters
  /// - [dartType] — The analyzer type to resolve.
  /// - [package] — The package context used for lookup.
  /// - [libraryUri] — The URI of the declaring library.
  ///
  /// ### Returns
  /// A [Future] that completes with the corresponding [mirrors.TypeMirror].
  Future<mirrors.TypeMirror> _getMirror(DartType dartType, Package package, String libraryUri) async {
    final type = await findRuntimeTypeFromDartType(dartType, libraryUri, package);
    return mirrors.reflectType(type);
  }
}