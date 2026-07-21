import 'dart:typed_data';

import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/original_material_repository.dart';
import 'package:ai_study_buddy/features/materials/material_upload.dart';
import 'package:ai_study_buddy/features/materials/supabase_original_material_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const _user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'student@example.test',
  displayName: 'Student',
);
const _materialId = '22222222-2222-4222-8222-222222222222';

void main() {
  test(
    'authenticated owner uses direct bytes without public or signed URLs',
    () async {
      final bytes = Uint8List.fromList('%PDF-1.7'.codeUnits);
      final source = _FakeSource(bytes: bytes);
      final result = await SupabaseOriginalMaterialRepository(source).load(
        expectedUser: _user,
        materialId: _materialId,
        expectedKind: MaterialKind.pdf,
      );
      expect(result, isA<OriginalMaterialSuccess>());
      final success = result as OriginalMaterialSuccess;
      expect(success.handle.useBytes((loaded) => loaded), same(bytes));
      expect(source.downloads, 1);
      expect(result.toString(), isNot(contains('http')));
      expect(result.toString(), isNot(contains('token')));
    },
  );

  test(
    'successful empty lookup is distinct from authorization failure',
    () async {
      final absent =
          await SupabaseOriginalMaterialRepository(_FakeSource(row: null)).load(
            expectedUser: _user,
            materialId: _materialId,
            expectedKind: MaterialKind.pdf,
          );
      expect(
        (absent as OriginalMaterialFailure).code,
        OriginalMaterialFailureCode.materialUnavailable,
      );

      final denied =
          await SupabaseOriginalMaterialRepository(
            _FakeSource(
              findError: const supabase.PostgrestException(
                message: 'denied',
                code: '42501',
              ),
            ),
          ).load(
            expectedUser: _user,
            materialId: _materialId,
            expectedKind: MaterialKind.pdf,
          );
      expect(
        (denied as OriginalMaterialFailure).code,
        OriginalMaterialFailureCode.authorizationDenied,
      );
    },
  );

  test('expired session and transport failures remain distinct', () async {
    final expired =
        await SupabaseOriginalMaterialRepository(
          _FakeSource(currentUserId: null),
        ).load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.pdf,
        );
    expect(
      (expired as OriginalMaterialFailure).code,
      OriginalMaterialFailureCode.sessionExpired,
    );
    final network =
        await SupabaseOriginalMaterialRepository(
          _FakeSource(findError: StateError('offline')),
        ).load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.pdf,
        );
    expect(
      (network as OriginalMaterialFailure).code,
      OriginalMaterialFailureCode.networkFailure,
    );
  });

  test('metadata and actual byte ceilings are both enforced', () async {
    final metadataLarge =
        await SupabaseOriginalMaterialRepository(
          _FakeSource(fileSize: maxPdfUploadBytes + 1),
        ).load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.pdf,
        );
    expect(
      (metadataLarge as OriginalMaterialFailure).code,
      OriginalMaterialFailureCode.previewTooLarge,
    );

    final actualLarge =
        await SupabaseOriginalMaterialRepository(
          _FakeSource(
            bytes: Uint8List(maxPdfUploadBytes + 1)
              ..setRange(0, 5, '%PDF-'.codeUnits),
            fileSize: 8,
            objectSize: 8,
          ),
        ).load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.pdf,
        );
    expect(
      (actualLarge as OriginalMaterialFailure).code,
      OriginalMaterialFailureCode.previewTooLarge,
    );
  });

  test('wrong kind and invalid exact path fail before download', () async {
    final source = _FakeSource(path: '${_user.id}/different/notes.pdf');
    final invalidPath = await SupabaseOriginalMaterialRepository(source).load(
      expectedUser: _user,
      materialId: _materialId,
      expectedKind: MaterialKind.pdf,
    );
    expect(
      (invalidPath as OriginalMaterialFailure).code,
      OriginalMaterialFailureCode.invalidMetadata,
    );
    expect(source.downloads, 0);

    final mismatch = await SupabaseOriginalMaterialRepository(_FakeSource())
        .load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.image,
        );
    expect(
      (mismatch as OriginalMaterialFailure).code,
      OriginalMaterialFailureCode.wrongSourceType,
    );
  });

  test('object MIME must be present normalized and exact', () async {
    for (final mime in <String?>[
      null,
      '',
      'application/octet-stream',
      'image/png',
      'Application/PDF',
    ]) {
      final result =
          await SupabaseOriginalMaterialRepository(
            _FakeSource(objectMime: mime),
          ).load(
            expectedUser: _user,
            materialId: _materialId,
            expectedKind: MaterialKind.pdf,
          );
      expect(
        (result as OriginalMaterialFailure).code,
        OriginalMaterialFailureCode.invalidMetadata,
        reason: '$mime',
      );
    }
    final valid =
        await SupabaseOriginalMaterialRepository(
          _FakeSource(objectMime: 'application/pdf'),
        ).load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.pdf,
        );
    expect(valid, isA<OriginalMaterialSuccess>());
  });

  test('missing object and signature mismatch fail safely', () async {
    final missing =
        await SupabaseOriginalMaterialRepository(
          _FakeSource(objectPresent: false),
        ).load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.pdf,
        );
    expect(
      (missing as OriginalMaterialFailure).code,
      OriginalMaterialFailureCode.objectNotFound,
    );

    final mismatch =
        await SupabaseOriginalMaterialRepository(
          _FakeSource(bytes: Uint8List.fromList('not-pdf!'.codeUnits)),
        ).load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.pdf,
        );
    expect(
      (mismatch as OriginalMaterialFailure).code,
      OriginalMaterialFailureCode.invalidMetadata,
    );
  });

  test(
    'Storage authorization and transport failures remain distinct',
    () async {
      final denied =
          await SupabaseOriginalMaterialRepository(
            _FakeSource(
              objectError: const supabase.StorageException(
                'denied',
                statusCode: '403',
              ),
            ),
          ).load(
            expectedUser: _user,
            materialId: _materialId,
            expectedKind: MaterialKind.pdf,
          );
      expect(
        (denied as OriginalMaterialFailure).code,
        OriginalMaterialFailureCode.authorizationDenied,
      );

      final network =
          await SupabaseOriginalMaterialRepository(
            _FakeSource(objectError: StateError('offline')),
          ).load(
            expectedUser: _user,
            materialId: _materialId,
            expectedKind: MaterialKind.pdf,
          );
      expect(
        (network as OriginalMaterialFailure).code,
        OriginalMaterialFailureCode.networkFailure,
      );
    },
  );

  test(
    'encoded and Unicode path variants are rejected before Storage',
    () async {
      for (final filename in [
        'notes%2Fescape.pdf',
        'notes%252Fescape.pdf',
        'notes∕escape.pdf',
        'notes／escape.pdf',
        'notes＼escape.pdf',
        'notes.png',
      ]) {
        final source = _FakeSource(path: '${_user.id}/$_materialId/$filename');
        final result = await SupabaseOriginalMaterialRepository(source).load(
          expectedUser: _user,
          materialId: _materialId,
          expectedKind: MaterialKind.pdf,
        );
        expect(
          (result as OriginalMaterialFailure).code,
          OriginalMaterialFailureCode.invalidMetadata,
          reason: filename,
        );
        expect(source.downloads, 0);
      }
    },
  );
}

class _FakeSource implements OriginalMaterialDataSource {
  _FakeSource({
    this.currentUserId = '11111111-1111-4111-8111-111111111111',
    this.row = const {},
    this.findError,
    Uint8List? bytes,
    this.fileSize = 8,
    int? objectSize,
    this.objectMime = 'application/pdf',
    this.objectPresent = true,
    this.objectError,
    this.path =
        '11111111-1111-4111-8111-111111111111/'
        '22222222-2222-4222-8222-222222222222/notes.pdf',
  }) : bytes = bytes ?? Uint8List.fromList('%PDF-1.7'.codeUnits),
       objectSize = objectSize ?? fileSize;

  @override
  final String? currentUserId;
  final Map<String, dynamic>? row;
  final Object? findError;
  final Uint8List bytes;
  final int fileSize;
  final int objectSize;
  final String? objectMime;
  final bool objectPresent;
  final Object? objectError;
  final String path;
  int downloads = 0;

  @override
  Future<Map<String, dynamic>?> findMaterial({
    required String materialId,
    required String userId,
  }) async {
    if (findError != null) throw findError!;
    if (row == null) return null;
    return {
      'id': _materialId,
      'subject_id': 'biology',
      'title': 'notes.pdf',
      'kind': 'pdf',
      'source_kind': 'upload',
      'storage_bucket': 'study-materials',
      'storage_path': path,
      'mime_type': 'application/pdf',
      'file_size_bytes': fileSize,
      'processing_status': 'ready',
      ...row!,
    };
  }

  @override
  Future<OriginalStorageObjectMetadata?> findObject({
    required String bucket,
    required String path,
  }) async {
    if (objectError != null) throw objectError!;
    if (!objectPresent) return null;
    return OriginalStorageObjectMetadata(
      sizeBytes: objectSize,
      mimeType: objectMime,
    );
  }

  @override
  Future<Uint8List> download({
    required String bucket,
    required String path,
  }) async {
    downloads += 1;
    return bytes;
  }
}
