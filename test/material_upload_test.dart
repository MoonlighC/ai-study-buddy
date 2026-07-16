import 'dart:async';
import 'dart:typed_data';

import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_upload.dart';
import 'package:ai_study_buddy/features/materials/material_upload_repository.dart';
import 'package:ai_study_buddy/features/materials/supabase_material_upload_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'student@example.test',
  displayName: 'Student',
);
const materialId = '22222222-2222-4222-8222-222222222222';

void main() {
  group('material upload validation', () {
    final accepted = <String, Uint8List>{
      'notes.pdf': Uint8List.fromList('%PDF-1.7'.codeUnits),
      'diagram.png': Uint8List.fromList(const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]),
      'photo.jpg': Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0x00]),
      'photo.jpeg': Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0x00]),
      'scan.webp': Uint8List.fromList('RIFF0000WEBP'.codeUnits),
    };

    for (final entry in accepted.entries) {
      test('accepts ${entry.key}', () async {
        final kind = entry.key.endsWith('.pdf')
            ? MaterialKind.pdf
            : MaterialKind.image;
        final request = await prepareMaterialUpload(
          selectedFile: _selected(entry.key, entry.value),
          expectedKind: kind,
          materialId: materialId,
          subjectId: 'subject',
        );
        expect(request.fileSizeBytes, entry.value.length);
        expect(request.mimeType, isNotEmpty);
      });
    }

    test('rejects unsupported extension before reading bytes', () async {
      var reads = 0;
      final file = SelectedMaterialFile(
        name: 'notes.txt',
        reportedSizeBytes: 20,
        readBytes: () async {
          reads += 1;
          return Uint8List(20);
        },
      );
      await expectLater(
        prepareMaterialUpload(
          selectedFile: file,
          expectedKind: MaterialKind.pdf,
          materialId: materialId,
          subjectId: 'subject',
        ),
        throwsA(isA<MaterialUploadValidationException>()),
      );
      expect(reads, 0);
    });

    test('rejects reported oversize before reading bytes', () async {
      var reads = 0;
      final file = SelectedMaterialFile(
        name: 'notes.pdf',
        reportedSizeBytes: maxPdfUploadBytes + 1,
        readBytes: () async {
          reads += 1;
          return Uint8List(1);
        },
      );
      await expectLater(
        prepareMaterialUpload(
          selectedFile: file,
          expectedKind: MaterialKind.pdf,
          materialId: materialId,
          subjectId: 'subject',
        ),
        throwsA(isA<MaterialUploadValidationException>()),
      );
      expect(reads, 0);
    });

    test('rejects actual oversize and mismatched signature', () async {
      await expectLater(
        prepareMaterialUpload(
          selectedFile: SelectedMaterialFile(
            name: 'large.png',
            reportedSizeBytes: 8,
            readBytes: () async => Uint8List(maxImageUploadBytes + 1),
          ),
          expectedKind: MaterialKind.image,
          materialId: materialId,
          subjectId: 'subject',
        ),
        throwsA(isA<MaterialUploadValidationException>()),
      );
      await expectLater(
        prepareMaterialUpload(
          selectedFile: _selected(
            'fake.pdf',
            Uint8List.fromList('not a pdf'.codeUnits),
          ),
          expectedKind: MaterialKind.pdf,
          materialId: materialId,
          subjectId: 'subject',
        ),
        throwsA(isA<MaterialUploadValidationException>()),
      );
    });

    test('sanitizes user-controlled folders and filename characters', () {
      expect(
        sanitizeUploadFilename(
          r'..\unsafe folder/../../My report (final).PDF',
          fallbackExtension: 'pdf',
        ),
        'My_report_final.pdf',
      );
    });

    test('canonical path rejects encoded traversal and separator variants', () {
      const unsafe = [
        'notes%2Fescape.pdf',
        'notes%5Cescape.pdf',
        '%2e%2e.pdf',
        'notes%252Fescape.pdf',
        'notes%255Cescape.pdf',
        'notes∕escape.pdf',
        'notes⁄escape.pdf',
        'notes／escape.pdf',
        'notes⧵escape.pdf',
        'notes＼escape.pdf',
        'notes\tescape.pdf',
        'notes\nescape.pdf',
        'notes\u0000escape.pdf',
        '.hidden.pdf',
        ' notes.pdf',
        'notes..pdf',
      ];
      for (final filename in unsafe) {
        expect(
          isCanonicalMaterialObjectPath(
            path: '${user.id}/$materialId/$filename',
            userId: user.id,
            materialId: materialId,
            kind: MaterialKind.pdf,
            mimeType: 'application/pdf',
          ),
          isFalse,
          reason: filename,
        );
      }
    });

    test('canonical filename requires kind extension and MIME agreement', () {
      expect(
        isCanonicalMaterialFilename(
          filename: 'notes.png',
          kind: MaterialKind.pdf,
          mimeType: 'application/pdf',
        ),
        isFalse,
      );
      expect(
        isCanonicalMaterialFilename(
          filename: 'notes.pdf',
          kind: MaterialKind.pdf,
          mimeType: 'image/png',
        ),
        isFalse,
      );
      for (final value in <(String, MaterialKind, String)>[
        ('notes.pdf', MaterialKind.pdf, 'application/pdf'),
        ('photo.jpg', MaterialKind.image, 'image/jpeg'),
        ('photo.jpeg', MaterialKind.image, 'image/jpeg'),
        ('diagram.png', MaterialKind.image, 'image/png'),
        ('scan.webp', MaterialKind.image, 'image/webp'),
      ]) {
        expect(
          isCanonicalMaterialFilename(
            filename: value.$1,
            kind: value.$2,
            mimeType: value.$3,
          ),
          isTrue,
          reason: value.$1,
        );
      }
    });

    test(
      'uppercase extensions canonicalize and empty files fail safely',
      () async {
        final upper = await prepareMaterialUpload(
          selectedFile: _selected(
            'NOTES.PDF',
            Uint8List.fromList('%PDF-1.7'.codeUnits),
          ),
          expectedKind: MaterialKind.pdf,
          materialId: materialId,
          subjectId: 'subject',
        );
        expect(upper.objectFilename, 'NOTES.pdf');
        expect(
          isCanonicalMaterialFilename(
            filename: upper.objectFilename,
            kind: upper.kind,
            mimeType: upper.mimeType,
          ),
          isTrue,
        );
        await expectLater(
          prepareMaterialUpload(
            selectedFile: SelectedMaterialFile(
              name: 'empty.pdf',
              reportedSizeBytes: 0,
              readBytes: () async => Uint8List(0),
            ),
            expectedKind: MaterialKind.pdf,
            materialId: materialId,
            subjectId: 'subject',
          ),
          throwsA(
            isA<MaterialUploadValidationException>().having(
              (error) => error.code,
              'code',
              MaterialFileValidationCode.emptyFile,
            ),
          ),
        );
      },
    );
  });

  group('Supabase upload orchestration', () {
    test(
      'uses authenticated owner, PDF bucket, path, and row fields',
      () async {
        final source = _FakeUploadDataSource(currentUserId: user.id);
        final repository = SupabaseMaterialUploadRepository(source);
        final material = await repository.uploadMaterial(
          expectedUser: user,
          request: _request(MaterialKind.pdf, 'application/pdf'),
        );

        expect(source.uploadedBucket, 'study-materials');
        expect(source.uploadedPath, '${user.id}/$materialId/notes.pdf');
        expect(source.inserted!['user_id'], user.id);
        expect(source.inserted!['content_text'], isNull);
        expect(source.inserted!['summary'], isNull);
        expect(source.inserted!['processing_status'], 'pending');
        expect(material.processingStatus, MaterialProcessingStatus.pending);
      },
    );

    test('maps canonical image bucket and MIME', () async {
      final source = _FakeUploadDataSource(currentUserId: user.id);
      await SupabaseMaterialUploadRepository(source).uploadMaterial(
        expectedUser: user,
        request: _request(MaterialKind.image, 'image/webp'),
      );
      expect(source.uploadedBucket, 'study-images');
      expect(source.inserted!['mime_type'], 'image/webp');
      expect(source.inserted!['kind'], 'image');
    });

    test('rejects missing or mismatched session before upload', () async {
      for (final currentUserId in <String?>[null, 'different-user']) {
        final source = _FakeUploadDataSource(currentUserId: currentUserId);
        await expectLater(
          SupabaseMaterialUploadRepository(source).uploadMaterial(
            expectedUser: user,
            request: _request(MaterialKind.pdf, 'application/pdf'),
          ),
          throwsA(isA<MaterialUploadException>()),
        );
        expect(source.uploadedPath, isNull);
      }
    });

    test('storage failure performs no insert', () async {
      final source = _FakeUploadDataSource(
        currentUserId: user.id,
        failUpload: true,
      );
      await expectLater(
        SupabaseMaterialUploadRepository(source).uploadMaterial(
          expectedUser: user,
          request: _request(MaterialKind.pdf, 'application/pdf'),
        ),
        throwsA(isA<MaterialUploadException>()),
      );
      expect(source.inserted, isNull);
      expect(source.removedPath, isNull);
    });

    test('row failure cleans up and cleanup failure preserves error', () async {
      for (final failCleanup in [false, true]) {
        final source = _FakeUploadDataSource(
          currentUserId: user.id,
          failInsert: true,
          failCleanup: failCleanup,
        );
        await expectLater(
          SupabaseMaterialUploadRepository(source).uploadMaterial(
            expectedUser: user,
            request: _request(MaterialKind.pdf, 'application/pdf'),
          ),
          throwsA(
            isA<MaterialUploadException>().having(
              (error) => error.message,
              'message',
              contains('could not be saved'),
            ),
          ),
        );
        expect(source.removedPath, '${user.id}/$materialId/notes.pdf');
      }
    });

    test(
      'exact orphan object resumes material creation without re-upload',
      () async {
        final source = _ReconciliationUploadDataSource(
          object: _exactPdfObject(),
        );
        final material = await SupabaseMaterialUploadRepository(source)
            .uploadMaterial(
              expectedUser: user,
              request: _request(MaterialKind.pdf, 'application/pdf'),
            );

        expect(material.id, materialId);
        expect(source.uploadCalls, 0);
        expect(source.insertCalls, 1);
      },
    );

    test(
      'matching filename at a different path is never authoritative',
      () async {
        final source = _ReconciliationUploadDataSource(
          object: MaterialUploadObjectMetadata(
            bucket: 'study-materials',
            path: '${user.id}/different-material/notes.pdf',
            fileName: 'notes.pdf',
            sizeBytes: 8,
            mimeType: 'application/pdf',
            contentSignature: 'pdf-v1',
          ),
        );

        await expectLater(
          SupabaseMaterialUploadRepository(source).uploadMaterial(
            expectedUser: user,
            request: _request(MaterialKind.pdf, 'application/pdf'),
          ),
          throwsA(
            isA<MaterialUploadException>().having(
              (error) => error.code,
              'code',
              MaterialUploadErrorCode.invalidMetadata,
            ),
          ),
        );
        expect(source.uploadCalls, 0);
        expect(source.insertCalls, 0);
      },
    );

    test(
      'ambiguous upload response reconciles object and creates row',
      () async {
        final source = _ReconciliationUploadDataSource(
          failUploadAfterStoring: true,
        );
        final material = await SupabaseMaterialUploadRepository(source)
            .uploadMaterial(
              expectedUser: user,
              request: _request(MaterialKind.pdf, 'application/pdf'),
            );

        expect(material.id, materialId);
        expect(source.uploadCalls, 1);
        expect(source.insertCalls, 1);
      },
    );

    test(
      'exact existing row and object succeeds without another create',
      () async {
        final source = _ReconciliationUploadDataSource(
          initialRow: _exactPdfRow(),
          object: _exactPdfObject(),
        );
        final material = await SupabaseMaterialUploadRepository(source)
            .uploadMaterial(
              expectedUser: user,
              request: _request(MaterialKind.pdf, 'application/pdf'),
            );
        expect(material.id, materialId);
        expect(source.uploadCalls, 0);
        expect(source.insertCalls, 0);
        expect(source.removeCalls, 0);
      },
    );

    test('existing row requires an exact canonical object', () async {
      final cases = <String, MaterialUploadObjectMetadata?>{
        'missing': null,
        'wrong path': MaterialUploadObjectMetadata(
          bucket: 'study-materials',
          path: '${user.id}/different/notes.pdf',
          fileName: 'notes.pdf',
          sizeBytes: 8,
          mimeType: 'application/pdf',
          contentSignature: 'pdf-v1',
        ),
        'wrong filename': MaterialUploadObjectMetadata(
          bucket: 'study-materials',
          path: '${user.id}/$materialId/other.pdf',
          fileName: 'other.pdf',
          sizeBytes: 8,
          mimeType: 'application/pdf',
          contentSignature: 'pdf-v1',
        ),
        'wrong mime': MaterialUploadObjectMetadata(
          bucket: 'study-materials',
          path: '${user.id}/$materialId/notes.pdf',
          fileName: 'notes.pdf',
          sizeBytes: 8,
          mimeType: 'application/octet-stream',
          contentSignature: 'pdf-v1',
        ),
        'wrong size': MaterialUploadObjectMetadata(
          bucket: 'study-materials',
          path: '${user.id}/$materialId/notes.pdf',
          fileName: 'notes.pdf',
          sizeBytes: 9,
          mimeType: 'application/pdf',
          contentSignature: 'pdf-v1',
        ),
        'wrong signature': MaterialUploadObjectMetadata(
          bucket: 'study-materials',
          path: '${user.id}/$materialId/notes.pdf',
          fileName: 'notes.pdf',
          sizeBytes: 8,
          mimeType: 'application/pdf',
          contentSignature: 'png-v1',
        ),
      };
      for (final entry in cases.entries) {
        final source = _ReconciliationUploadDataSource(
          initialRow: _exactPdfRow(),
          object: entry.value,
        );
        await expectLater(
          SupabaseMaterialUploadRepository(source).uploadMaterial(
            expectedUser: user,
            request: _request(MaterialKind.pdf, 'application/pdf'),
          ),
          throwsA(
            isA<MaterialUploadException>().having(
              (error) => error.code,
              entry.key,
              entry.value == null
                  ? MaterialUploadErrorCode.storageNotFound
                  : MaterialUploadErrorCode.invalidMetadata,
            ),
          ),
        );
        expect(source.uploadCalls, 0, reason: entry.key);
        expect(source.insertCalls, 0, reason: entry.key);
      }
    });

    test('existing row rejects wrong canonical row bucket and path', () async {
      for (final row in [
        _exactPdfRow(storageBucket: 'study-images'),
        _exactPdfRow(storagePath: '${user.id}/different/notes.pdf'),
        _exactPdfRow(storagePath: '${user.id}/$materialId/other.pdf'),
      ]) {
        final source = _ReconciliationUploadDataSource(
          initialRow: row,
          object: _exactPdfObject(),
        );
        await expectLater(
          SupabaseMaterialUploadRepository(source).uploadMaterial(
            expectedUser: user,
            request: _request(MaterialKind.pdf, 'application/pdf'),
          ),
          throwsA(isA<MaterialUploadException>()),
        );
        expect(source.uploadCalls, 0);
        expect(source.insertCalls, 0);
      }
    });

    test(
      'Storage authorization, absence, and network errors stay typed',
      () async {
        final cases = <Object, MaterialUploadErrorCode>{
          const supabase.StorageException('unauthenticated', statusCode: '401'):
              MaterialUploadErrorCode.sessionExpired,
          const supabase.StorageException('forbidden', statusCode: '403'):
              MaterialUploadErrorCode.authorizationDenied,
          const supabase.StorageException('missing', statusCode: '404'):
              MaterialUploadErrorCode.storageNotFound,
          StateError('offline'): MaterialUploadErrorCode.networkFailure,
        };
        for (final entry in cases.entries) {
          final source = _ReconciliationUploadDataSource(
            initialRow: _exactPdfRow(),
            objectError: entry.key,
          );
          await expectLater(
            SupabaseMaterialUploadRepository(source).uploadMaterial(
              expectedUser: user,
              request: _request(MaterialKind.pdf, 'application/pdf'),
            ),
            throwsA(
              isA<MaterialUploadException>().having(
                (error) => error.code,
                'code',
                entry.value,
              ),
            ),
          );
        }
      },
    );

    test(
      'ambiguous row creation reconciles exact row without cleanup',
      () async {
        final source = _ReconciliationUploadDataSource(
          object: _exactPdfObject(),
          failInsertAfterStoring: true,
        );
        final material = await SupabaseMaterialUploadRepository(source)
            .uploadMaterial(
              expectedUser: user,
              request: _request(MaterialKind.pdf, 'application/pdf'),
            );
        expect(material.id, materialId);
        expect(source.insertCalls, 1);
        expect(source.removeCalls, 0);
      },
    );

    test('malformed authoritative row fails closed', () async {
      final source = _ReconciliationUploadDataSource(
        initialRow: {'id': materialId},
        object: _exactPdfObject(),
      );
      await expectLater(
        SupabaseMaterialUploadRepository(source).uploadMaterial(
          expectedUser: user,
          request: _request(MaterialKind.pdf, 'application/pdf'),
        ),
        throwsA(
          isA<MaterialUploadException>().having(
            (error) => error.code,
            'code',
            MaterialUploadErrorCode.invalidReconciliation,
          ),
        ),
      );
    });
  });

  test(
    'AppState prevents duplicate upload and updates only after success',
    () async {
      final repository = _BlockingUploadRepository();
      final state = AppState(
        materialUploadRepository: repository,
        materialIdGenerator: () => materialId,
      );
      final file = _selected(
        'notes.pdf',
        Uint8List.fromList('%PDF-1.7'.codeUnits),
      );
      final first = state.uploadMaterialFor(
        user,
        subjectId: 'biology',
        kind: MaterialKind.pdf,
        selectedFile: file,
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.isUploadingMaterial, isTrue);
      expect(
        await state.uploadMaterialFor(
          user,
          subjectId: 'biology',
          kind: MaterialKind.pdf,
          selectedFile: file,
        ),
        isFalse,
      );
      repository.complete();
      expect(await first, isTrue);
      expect(state.materialById(materialId), isNotNull);
    },
  );

  test('Supabase mode starts without mock uploads', () {
    final state = AppState(
      config: const AppConfig(
        backendMode: AppBackendMode.supabase,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'sb_publishable_test-client-key',
      ),
    );
    expect(state.materials, isEmpty);
  });

  test(
    'AppState upload failure preserves materials and exposes safe error',
    () async {
      final state = AppState(
        materialUploadRepository: const _FailingUploadRepository(),
        materialIdGenerator: () => materialId,
      );
      final before = state.materials.map((material) => material.id).toList();
      final uploaded = await state.uploadMaterialFor(
        user,
        subjectId: 'biology',
        kind: MaterialKind.pdf,
        selectedFile: _selected(
          'notes.pdf',
          Uint8List.fromList('%PDF-1.7'.codeUnits),
        ),
      );
      expect(uploaded, isFalse);
      expect(state.materials.map((material) => material.id), before);
      expect(state.uploadError, 'Could not upload the selected file.');
      expect(state.isUploadingMaterial, isFalse);
    },
  );
}

SelectedMaterialFile _selected(String name, Uint8List bytes) {
  return SelectedMaterialFile(
    name: name,
    reportedSizeBytes: bytes.length,
    readBytes: () async => bytes,
  );
}

MaterialUploadRequest _request(MaterialKind kind, String mime) {
  return MaterialUploadRequest(
    materialId: materialId,
    subjectId: 'biology',
    title: kind == MaterialKind.pdf ? 'notes.pdf' : 'notes.webp',
    objectFilename: kind == MaterialKind.pdf ? 'notes.pdf' : 'notes.webp',
    kind: kind,
    mimeType: mime,
    bytes: Uint8List.fromList(
      kind == MaterialKind.pdf
          ? '%PDF-1.7'.codeUnits
          : 'RIFF0000WEBP'.codeUnits,
    ),
  );
}

class _FakeUploadDataSource implements MaterialUploadDataSource {
  _FakeUploadDataSource({
    required this.currentUserId,
    this.failUpload = false,
    this.failInsert = false,
    this.failCleanup = false,
  });

  @override
  final String? currentUserId;
  final bool failUpload;
  final bool failInsert;
  final bool failCleanup;
  String? uploadedBucket;
  String? uploadedPath;
  Map<String, Object?>? inserted;
  String? removedPath;

  @override
  Future<void> uploadObject({
    required String bucket,
    required String path,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    uploadedBucket = bucket;
    uploadedPath = path;
    if (failUpload) throw StateError('upload failed');
  }

  @override
  Future<Map<String, dynamic>> insertMaterial(
    Map<String, Object?> values,
  ) async {
    inserted = values;
    if (failInsert) throw StateError('insert failed');
    return <String, dynamic>{...values, 'created_at': '2026-07-10T00:00:00Z'};
  }

  @override
  Future<void> removeObject({
    required String bucket,
    required String path,
  }) async {
    removedPath = path;
    if (failCleanup) throw StateError('cleanup failed');
  }
}

MaterialUploadObjectMetadata _exactPdfObject() => MaterialUploadObjectMetadata(
  bucket: 'study-materials',
  path: '${user.id}/$materialId/notes.pdf',
  fileName: 'notes.pdf',
  sizeBytes: 8,
  mimeType: 'application/pdf',
  contentSignature: 'pdf-v1',
);

Map<String, dynamic> _exactPdfRow({
  String storageBucket = 'study-materials',
  String? storagePath,
}) => <String, dynamic>{
  'id': materialId,
  'user_id': user.id,
  'subject_id': 'biology',
  'title': 'notes.pdf',
  'kind': 'pdf',
  'source_kind': 'upload',
  'content_text': null,
  'storage_bucket': storageBucket,
  'storage_path': storagePath ?? '${user.id}/$materialId/notes.pdf',
  'mime_type': 'application/pdf',
  'file_size_bytes': 8,
  'processing_status': 'pending',
  'created_at': '2026-07-10T00:00:00Z',
};

class _ReconciliationUploadDataSource
    implements
        MaterialUploadDataSource,
        MaterialUploadReconciliationDataSource {
  _ReconciliationUploadDataSource({
    this.object,
    Map<String, dynamic>? initialRow,
    this.objectError,
    this.failUploadAfterStoring = false,
    this.failInsertAfterStoring = false,
  }) : row = initialRow;

  @override
  String? get currentUserId => user.id;

  MaterialUploadObjectMetadata? object;
  Map<String, dynamic>? row;
  final Object? objectError;
  final bool failUploadAfterStoring;
  final bool failInsertAfterStoring;
  int uploadCalls = 0;
  int insertCalls = 0;
  int removeCalls = 0;

  @override
  Future<Map<String, dynamic>?> findMaterial({
    required String materialId,
    required String userId,
  }) async => row;

  @override
  Future<MaterialUploadObjectMetadata?> findObject({
    required String bucket,
    required String path,
  }) async {
    if (objectError != null) throw objectError!;
    return object;
  }

  @override
  Future<void> uploadObject({
    required String bucket,
    required String path,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    uploadCalls += 1;
    object = MaterialUploadObjectMetadata(
      bucket: bucket,
      path: path,
      fileName: 'notes.pdf',
      sizeBytes: bytes.lengthInBytes,
      mimeType: mimeType,
      contentSignature: 'pdf-v1',
    );
    if (failUploadAfterStoring) throw StateError('ambiguous upload');
  }

  @override
  Future<Map<String, dynamic>> insertMaterial(
    Map<String, Object?> values,
  ) async {
    insertCalls += 1;
    row = <String, dynamic>{...values, 'created_at': '2026-07-10T00:00:00Z'};
    if (failInsertAfterStoring) throw StateError('ambiguous insert');
    return row!;
  }

  @override
  Future<void> removeObject({
    required String bucket,
    required String path,
  }) async {
    removeCalls += 1;
    object = null;
  }
}

class _BlockingUploadRepository implements MaterialUploadRepository {
  final completer = Completer<void>();

  void complete() => completer.complete();

  @override
  Future<StudyMaterial> uploadMaterial({
    required AuthUser expectedUser,
    required MaterialUploadRequest request,
    void Function(double? progress)? onProgress,
  }) async {
    await completer.future;
    return StudyMaterial(
      id: request.materialId,
      subjectId: request.subjectId,
      title: request.title,
      kind: request.kind,
      content: '',
      createdLabel: 'Just now',
      sourceKind: MaterialSourceKind.upload,
      processingStatus: MaterialProcessingStatus.pending,
    );
  }
}

class _FailingUploadRepository implements MaterialUploadRepository {
  const _FailingUploadRepository();

  @override
  Future<StudyMaterial> uploadMaterial({
    required AuthUser expectedUser,
    required MaterialUploadRequest request,
    void Function(double? progress)? onProgress,
  }) {
    throw const MaterialUploadException('Could not upload the selected file.');
  }
}
