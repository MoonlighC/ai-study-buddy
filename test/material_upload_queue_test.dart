import 'dart:async';
import 'dart:typed_data';

import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_upload.dart';
import 'package:ai_study_buddy/features/materials/material_analysis_repository.dart';
import 'package:ai_study_buddy/features/materials/material_upload_queue.dart';
import 'package:ai_study_buddy/features/materials/material_upload_repository.dart';
import 'package:ai_study_buddy/features/materials/pdf_text_extraction_repository.dart';
import 'package:ai_study_buddy/features/materials/image_text_extraction_repository.dart';
import 'package:ai_study_buddy/features/materials/structured_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'student@example.test',
  displayName: 'Student',
);

void main() {
  test(
    'mixed selection uploads valid file and records two skipped files',
    () async {
      var queueCounter = 0;
      var materialCounter = 0;
      var rejectedReads = 0;
      final repository = MockMaterialUploadRepository();
      final queue = MaterialUploadQueueController(
        repository: repository,
        queueIdGenerator: () => 'queue-${++queueCounter}',
        materialIdGenerator: () => 'material-${++materialCounter}',
        processMaterial: (user, material, guard) async =>
            MaterialQueueProcessingResult(
              material: material.copyWith(
                content: 'Extracted',
                processingStatus: MaterialProcessingStatus.ready,
              ),
              succeeded: true,
            ),
        onMaterialChanged: (_) {},
      );
      final oversized = [
        for (final name in ['large-a.pdf', 'large-b.pdf'])
          SelectedMaterialFile(
            name: name,
            reportedSizeBytes: maxPdfUploadBytes + 1,
            readBytes: () async {
              rejectedReads += 1;
              return Uint8List(0);
            },
          ),
      ];
      final batch = validateMaterialFileBatch(
        batchToken: 'mixed',
        files: [
          SelectedMaterialFile(
            name: 'valid.pdf',
            reportedSizeBytes: 8,
            readBytes: () async => Uint8List.fromList('%PDF-1.7'.codeUnits),
          ),
          ...oversized,
        ],
        expectedKind: MaterialKind.pdf,
      );

      expect(
        queue.enqueueBatch(
          user: _user,
          subjectId: 'biology',
          kind: MaterialKind.pdf,
          batch: batch,
        ),
        isTrue,
      );
      await _waitFor(() => queue.uploadedCount == 1);

      expect(repository.uploadedMaterials, hasLength(1));
      expect(repository.uploadedMaterials.single.title, 'valid.pdf');
      expect(rejectedReads, 0);
      expect(queue.uploadedCount, 1);
      expect(queue.skippedCount, 2);
      expect(queue.failedCount, 0);
      expect(
        queue.items.where(
          (item) => item.status == MaterialUploadQueueStatus.skipped,
        ),
        hasLength(2),
      );
      expect(
        queue.items
            .where((item) => item.status == MaterialUploadQueueStatus.skipped)
            .every((item) => item.authoritativeMaterialId == null),
        isTrue,
      );
    },
  );

  test(
    'queue uses at most two workers and preserves FIFO completion',
    () async {
      final repository = _ControlledRepository();
      var queueCounter = 0;
      var materialCounter = 0;
      final queue = MaterialUploadQueueController(
        repository: repository,
        queueIdGenerator: () => 'queue-${++queueCounter}',
        materialIdGenerator: () => 'material-${++materialCounter}',
        processMaterial: (user, material, guard) async =>
            MaterialQueueProcessingResult(
              material: material.copyWith(
                content: 'Extracted study content',
                processingStatus: MaterialProcessingStatus.ready,
              ),
              succeeded: true,
            ),
        onMaterialChanged: (_) {},
      );
      final files = List.generate(
        4,
        (index) => SelectedMaterialFile(
          name: 'notes-$index.pdf',
          reportedSizeBytes: 8,
          readBytes: () async => Uint8List.fromList('%PDF-1.7'.codeUnits),
        ),
      );
      final batch = validateMaterialFileBatch(
        batchToken: 'batch',
        files: files,
        expectedKind: MaterialKind.pdf,
      );

      expect(
        queue.enqueueBatch(
          user: _user,
          subjectId: 'biology',
          kind: MaterialKind.pdf,
          batch: batch,
        ),
        isTrue,
      );
      expect(
        queue.enqueueBatch(
          user: _user,
          subjectId: 'biology',
          kind: MaterialKind.pdf,
          batch: batch,
        ),
        isFalse,
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.maximumActive, 2);
      expect(repository.requests.map((request) => request.title), [
        'notes-0.pdf',
        'notes-1.pdf',
      ]);

      repository.releaseNext();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repository.requests[2].title, 'notes-2.pdf');
      repository.autoRelease = true;
      repository.releaseAll();
      await _waitFor(
        () => queue.items.every(
          (item) => item.status == MaterialUploadQueueStatus.completed,
        ),
      );
      expect(queue.items.map((item) => item.fileName), [
        'notes-0.pdf',
        'notes-1.pdf',
        'notes-2.pdf',
        'notes-3.pdf',
      ]);
    },
  );

  test(
    'processing retry reuses authoritative material without rereading',
    () async {
      var reads = 0;
      var processingAttempts = 0;
      final repository = MockMaterialUploadRepository();
      final queue = MaterialUploadQueueController(
        repository: repository,
        queueIdGenerator: () => 'queue',
        materialIdGenerator: () => 'fixed-material',
        processMaterial: (user, material, guard) async {
          processingAttempts += 1;
          return MaterialQueueProcessingResult(
            material: processingAttempts == 1
                ? material.copyWith(
                    processingStatus: MaterialProcessingStatus.failed,
                  )
                : material.copyWith(
                    content: 'Ready content',
                    processingStatus: MaterialProcessingStatus.ready,
                  ),
            succeeded: processingAttempts > 1,
          );
        },
        onMaterialChanged: (_) {},
      );
      final batch = validateMaterialFileBatch(
        batchToken: 'batch',
        files: [
          SelectedMaterialFile(
            name: 'notes.pdf',
            reportedSizeBytes: 8,
            readBytes: () async {
              reads += 1;
              return Uint8List.fromList('%PDF-1.7'.codeUnits);
            },
          ),
        ],
        expectedKind: MaterialKind.pdf,
      );
      queue.enqueueBatch(
        user: _user,
        subjectId: 'biology',
        kind: MaterialKind.pdf,
        batch: batch,
      );
      await _waitFor(
        () => queue.items.single.status == MaterialUploadQueueStatus.failed,
      );
      expect(reads, 1);
      expect(repository.uploadedMaterials, hasLength(1));
      expect(queue.retry('queue'), isTrue);
      expect(queue.retry('queue'), isFalse);
      await _waitFor(
        () => queue.items.single.status == MaterialUploadQueueStatus.completed,
      );
      expect(reads, 1);
      expect(repository.uploadedMaterials, hasLength(1));
      expect(queue.items.single.authoritativeMaterialId, 'fixed-material');
    },
  );

  test(
    'analysis start stays processing until authoritative summary completion',
    () async {
      final queue = MaterialUploadQueueController(
        repository: MockMaterialUploadRepository(),
        queueIdGenerator: () => 'queue-analysis',
        materialIdGenerator: () => 'material-analysis',
        processMaterial: (user, material, guard) async =>
            MaterialQueueProcessingResult(material: material, succeeded: true),
        onMaterialChanged: (_) {},
      );
      queue.enqueueBatch(
        user: _user,
        subjectId: 'biology',
        kind: MaterialKind.pdf,
        batch: _pdfBatch('authoritative', 1),
      );
      await _waitFor(
        () => queue.items.single.status == MaterialUploadQueueStatus.processing,
      );
      expect(queue.uploadedCount, 0);

      queue.acceptAnalysisStatus(
        'material-analysis',
        _analysisStatus(AnalysisState.completed, summary: _summary),
      );

      expect(queue.items.single.status, MaterialUploadQueueStatus.completed);
      expect(queue.uploadedCount, 1);
    },
  );

  test('terminal failed analysis has no false retry action', () async {
    final queue = MaterialUploadQueueController(
      repository: MockMaterialUploadRepository(),
      queueIdGenerator: () => 'queue-failed',
      materialIdGenerator: () => 'material-failed',
      processMaterial: (user, material, guard) async =>
          MaterialQueueProcessingResult(material: material, succeeded: true),
      onMaterialChanged: (_) {},
    );
    queue.enqueueBatch(
      user: _user,
      subjectId: 'biology',
      kind: MaterialKind.pdf,
      batch: _pdfBatch('failed', 1),
    );
    await _waitFor(
      () => queue.items.single.status == MaterialUploadQueueStatus.processing,
    );
    queue.acceptAnalysisStatus(
      'material-failed',
      _analysisStatus(AnalysisState.failed),
    );

    expect(queue.items.single.status, MaterialUploadQueueStatus.failed);
    expect(queue.canRetry('queue-failed'), isFalse);
    expect(queue.retry('queue-failed'), isFalse);
  });

  test('user-retry-required exposes one real authoritative retry', () async {
    var retries = 0;
    late final MaterialUploadQueueController queue;
    queue = MaterialUploadQueueController(
      repository: MockMaterialUploadRepository(),
      queueIdGenerator: () => 'queue-retry',
      materialIdGenerator: () => 'material-analysis',
      processMaterial: (user, material, guard) async =>
          MaterialQueueProcessingResult(material: material, succeeded: true),
      retryMaterialAnalysis: (user, materialId) async {
        retries += 1;
        queue.acceptAnalysisStatus(
          materialId,
          _analysisStatus(AnalysisState.completed, summary: _summary),
        );
        return true;
      },
      onMaterialChanged: (_) {},
    );
    queue.enqueueBatch(
      user: _user,
      subjectId: 'biology',
      kind: MaterialKind.pdf,
      batch: _pdfBatch('retry-required', 1),
    );
    await _waitFor(
      () => queue.items.single.status == MaterialUploadQueueStatus.processing,
    );
    queue.acceptAnalysisStatus(
      'material-analysis',
      _analysisStatus(AnalysisState.userRetryRequired),
    );

    expect(queue.canRetry('queue-retry'), isTrue);
    expect(queue.retry('queue-retry'), isTrue);
    expect(queue.retry('queue-retry'), isFalse);
    await _waitFor(() => queue.uploadedCount == 1);
    expect(retries, 1);
  });

  test('deleted material mapping and queue row are pruned', () async {
    final queue = MaterialUploadQueueController(
      repository: MockMaterialUploadRepository(),
      queueIdGenerator: () => 'queue-deleted',
      materialIdGenerator: () => 'material-deleted',
      processMaterial: (user, material, guard) async =>
          MaterialQueueProcessingResult(
            material: material.copyWith(
              content: 'Ready',
              processingStatus: MaterialProcessingStatus.ready,
            ),
            succeeded: true,
          ),
      onMaterialChanged: (_) {},
    );
    queue.enqueueBatch(
      user: _user,
      subjectId: 'biology',
      kind: MaterialKind.pdf,
      batch: _pdfBatch('deleted', 1),
    );
    await _waitFor(() => queue.uploadedCount == 1);

    expect(queue.pruneStaleAuthoritativeRows(const {}), ['material-deleted']);
    expect(queue.items, isEmpty);
  });

  test('session clear drops queued state and ignores stale work', () async {
    final repository = _ControlledRepository();
    final queue = MaterialUploadQueueController(
      repository: repository,
      queueIdGenerator: () => 'queue',
      materialIdGenerator: () => 'material',
      processMaterial: (user, material, guard) async =>
          MaterialQueueProcessingResult(material: material, succeeded: false),
      onMaterialChanged: (_) {},
    );
    queue.enqueueBatch(
      user: _user,
      subjectId: 'biology',
      kind: MaterialKind.pdf,
      batch: validateMaterialFileBatch(
        batchToken: 'batch',
        files: [
          SelectedMaterialFile(
            name: 'notes.pdf',
            reportedSizeBytes: 8,
            readBytes: () async => Uint8List.fromList('%PDF-1.7'.codeUnits),
          ),
        ],
        expectedKind: MaterialKind.pdf,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    queue.clearForSessionChange();
    repository.releaseAll();
    await Future<void>.delayed(Duration.zero);
    expect(queue.items, isEmpty);
  });

  test('inactive queue entries do not read bytes', () async {
    final repository = _ControlledRepository();
    final reads = List<int>.filled(4, 0);
    var queueId = 0;
    final queue = MaterialUploadQueueController(
      repository: repository,
      queueIdGenerator: () => 'queue-${++queueId}',
      materialIdGenerator: () => 'material-$queueId',
      processMaterial: (user, material, guard) async =>
          MaterialQueueProcessingResult(material: material, succeeded: false),
      onMaterialChanged: (_) {},
    );
    queue.enqueueBatch(
      user: _user,
      subjectId: 'biology',
      kind: MaterialKind.pdf,
      batch: validateMaterialFileBatch(
        batchToken: 'lazy',
        files: [
          for (var index = 0; index < reads.length; index += 1)
            SelectedMaterialFile(
              name: 'notes-$index.pdf',
              reportedSizeBytes: 8,
              readBytes: () async {
                reads[index] += 1;
                return Uint8List.fromList('%PDF-1.7'.codeUnits);
              },
            ),
        ],
        expectedKind: MaterialKind.pdf,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(reads, [1, 1, 0, 0]);
    repository.autoRelease = true;
    repository.releaseAll();
    await _waitFor(() => repository.requests.length == 4);
    expect(reads, [1, 1, 1, 1]);
  });

  test('logout invalidates two uploads and stale progress callbacks', () async {
    final repository = _ControlledRepository();
    var changed = 0;
    var queueId = 0;
    final queue = MaterialUploadQueueController(
      repository: repository,
      queueIdGenerator: () => 'queue-${++queueId}',
      materialIdGenerator: () => 'material-$queueId',
      processMaterial: (user, material, guard) async =>
          MaterialQueueProcessingResult(
            material: material.copyWith(
              content: 'Ready content',
              processingStatus: MaterialProcessingStatus.ready,
            ),
            succeeded: true,
          ),
      onMaterialChanged: (_) => changed += 1,
    );
    queue.enqueueBatch(
      user: _user,
      subjectId: 'biology',
      kind: MaterialKind.pdf,
      batch: _pdfBatch('logout', 2),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.active, 2);
    queue.clearForSessionChange();
    repository.emitProgress(0.75);
    repository.releaseAll();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(queue.items, isEmpty);
    expect(changed, 0);
  });

  test('session replacement cannot receive stale upload results', () async {
    const nextUser = AuthUser(
      id: '33333333-3333-4333-8333-333333333333',
      email: 'next@example.test',
    );
    final repository = _ControlledRepository();
    final changed = <StudyMaterial>[];
    var queueId = 0;
    final queue = MaterialUploadQueueController(
      repository: repository,
      queueIdGenerator: () => 'queue-${++queueId}',
      materialIdGenerator: () => 'material-$queueId',
      processMaterial: (user, material, guard) async =>
          MaterialQueueProcessingResult(
            material: material.copyWith(
              content: 'Ready content',
              processingStatus: MaterialProcessingStatus.ready,
            ),
            succeeded: true,
          ),
      onMaterialChanged: changed.add,
    );
    queue.enqueueBatch(
      user: _user,
      subjectId: 'biology',
      kind: MaterialKind.pdf,
      batch: _pdfBatch('old', 2),
    );
    await Future<void>.delayed(Duration.zero);
    queue.bindSession(nextUser.id);
    queue.enqueueBatch(
      user: nextUser,
      subjectId: 'biology',
      kind: MaterialKind.pdf,
      batch: _pdfBatch('new', 1),
    );
    repository.autoRelease = true;
    repository.releaseAll();
    await _waitFor(
      () => queue.items.single.status == MaterialUploadQueueStatus.completed,
    );
    expect(
      changed.where((material) => material.title.startsWith('old')),
      isEmpty,
    );
    expect(queue.items.single.fileName, 'new-0.pdf');
  });

  for (final kind in [MaterialKind.pdf, MaterialKind.image]) {
    for (final succeeds in [true, false]) {
      test(
        'stale ${kind.name} ${succeeds ? 'success' : 'failure'} after logout is ignored',
        () async {
          final extraction = _BlockingExtraction(kind: kind);
          final state = AppState(
            config: const AppConfig(
              backendMode: AppBackendMode.supabase,
              supabaseUrl: 'https://example.supabase.co',
              supabaseAnonKey: 'sb_publishable_test-client-key',
            ),
            materialUploadRepository: MockMaterialUploadRepository(),
            pdfTextExtractionRepository: extraction,
            imageTextExtractionRepository: extraction,
            materialIdGenerator: () => '22222222-2222-4222-8222-222222222222',
          );
          state.enqueueMaterialBatch(
            _user,
            subjectId: 'biology',
            kind: kind,
            batch: kind == MaterialKind.pdf
                ? _pdfBatch('stale', 1)
                : _imageBatch('stale'),
          );
          await _waitFor(() => extraction.called);
          state.clearSyncedWorkspaceForSignOut();
          extraction.complete(succeeds: succeeds);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          expect(state.materials, isEmpty);
          expect(state.materialUploadQueue.items, isEmpty);
          expect(
            kind == MaterialKind.pdf
                ? state.pdfExtractionErrorFor(
                    '22222222-2222-4222-8222-222222222222',
                  )
                : state.imageExtractionErrorFor(
                    '22222222-2222-4222-8222-222222222222',
                  ),
            isNull,
          );
        },
      );
    }
  }

  test(
    'stale extraction success cannot modify a replacement user state',
    () async {
      const nextUser = AuthUser(
        id: '33333333-3333-4333-8333-333333333333',
        email: 'next@example.test',
      );
      final extraction = _BlockingExtraction(kind: MaterialKind.pdf);
      final state = AppState(
        config: const AppConfig(
          backendMode: AppBackendMode.supabase,
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'sb_publishable_test-client-key',
        ),
        materialUploadRepository: MockMaterialUploadRepository(),
        pdfTextExtractionRepository: extraction,
        materialIdGenerator: () => '22222222-2222-4222-8222-222222222222',
      );
      state.enqueueMaterialBatch(
        _user,
        subjectId: 'biology',
        kind: MaterialKind.pdf,
        batch: _pdfBatch('replacement', 1),
      );
      await _waitFor(() => extraction.called);
      await state.loadSyncedWorkspaceFor(nextUser);
      extraction.complete(succeeds: true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(state.materials, isEmpty);
      expect(state.materialUploadQueue.items, isEmpty);
      expect(
        state.pdfExtractionErrorFor('22222222-2222-4222-8222-222222222222'),
        isNull,
      );
    },
  );
}

MaterialAnalysisStatus _analysisStatus(
  AnalysisState state, {
  StructuredSummary? summary,
}) => MaterialAnalysisStatus(
  materialId: state == AnalysisState.failed
      ? 'material-failed'
      : 'material-analysis',
  processingMode: AnalysisProcessingMode.recommended,
  state: state,
  publicStage: AnalysisPublicStage.creatingSummary,
  pageCount: 1,
  completedPages: state == AnalysisState.completed ? 1 : 0,
  confirmationRequired: false,
  canRetry: state == AnalysisState.userRetryRequired,
  retryAfterSeconds: null,
  warnings: const [],
  summarySchemaVersion: summary == null ? null : 1,
  summary: summary,
  structuredSummaryMalformed: false,
);

const _summary = StructuredSummary(
  schemaVersion: 1,
  language: 'en',
  sections: [
    StructuredSection(
      id: 'summary',
      title: 'Summary',
      blocks: [
        ProseBlock(
          markdown: 'Grounded summary.',
          display: SummaryDisplay.block,
        ),
      ],
      sourcePages: [1],
      confidence: 1,
    ),
  ],
  keyConcepts: [],
  equations: [],
  warnings: [],
  partialExtraction: PartialExtraction(
    isPartial: false,
    analyzedPages: [1],
    partialPages: [],
    missingPages: [],
    pageModes: [PageMode(page: 1, mode: PageModeKind.text)],
  ),
);

MaterialFilePickerBatch _pdfBatch(String token, int count) =>
    validateMaterialFileBatch(
      batchToken: token,
      files: [
        for (var index = 0; index < count; index += 1)
          SelectedMaterialFile(
            name: '$token-$index.pdf',
            reportedSizeBytes: 8,
            readBytes: () async => Uint8List.fromList('%PDF-1.7'.codeUnits),
          ),
      ],
      expectedKind: MaterialKind.pdf,
    );

MaterialFilePickerBatch _imageBatch(String token) => validateMaterialFileBatch(
  batchToken: token,
  files: [
    SelectedMaterialFile(
      name: '$token.png',
      reportedSizeBytes: 8,
      readBytes: () async => Uint8List.fromList(const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]),
    ),
  ],
  expectedKind: MaterialKind.image,
);

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 100 && !condition(); index += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

class _ControlledRepository implements MaterialUploadRepository {
  final List<MaterialUploadRequest> requests = [];
  final List<Completer<void>> _completers = [];
  final List<void Function(double? progress)?> _progressCallbacks = [];
  int active = 0;
  int maximumActive = 0;
  bool autoRelease = false;

  void releaseNext() =>
      _completers.firstWhere((item) => !item.isCompleted).complete();

  void releaseAll() {
    for (final completer in _completers) {
      if (!completer.isCompleted) completer.complete();
    }
  }

  void emitProgress(double? progress) {
    for (final callback in _progressCallbacks) {
      callback?.call(progress);
    }
  }

  @override
  Future<StudyMaterial> uploadMaterial({
    required AuthUser expectedUser,
    required MaterialUploadRequest request,
    void Function(double? progress)? onProgress,
  }) async {
    requests.add(request);
    _progressCallbacks.add(onProgress);
    active += 1;
    maximumActive = maximumActive < active ? active : maximumActive;
    final completer = Completer<void>();
    _completers.add(completer);
    if (autoRelease) completer.complete();
    await completer.future;
    active -= 1;
    return StudyMaterial(
      id: request.materialId,
      subjectId: request.subjectId,
      title: request.title,
      kind: request.kind,
      content: '',
      createdLabel: 'Now',
      sourceKind: MaterialSourceKind.upload,
      processingStatus: MaterialProcessingStatus.pending,
    );
  }
}

class _BlockingExtraction
    implements PdfTextExtractionRepository, ImageTextExtractionRepository {
  _BlockingExtraction({required this.kind});

  final MaterialKind kind;
  final Completer<PdfTextExtractionResult> _pdf = Completer();
  final Completer<ImageTextExtractionResult> _image = Completer();
  bool called = false;
  String? materialId;

  StudyMaterial _material(bool succeeds) => StudyMaterial(
    id: materialId!,
    subjectId: 'biology',
    title: kind == MaterialKind.pdf ? 'stale-0.pdf' : 'stale.png',
    kind: kind,
    content: succeeds ? 'authoritative extracted content' : '',
    createdLabel: 'Now',
    sourceKind: MaterialSourceKind.upload,
    storageBucket: kind == MaterialKind.pdf
        ? 'study-materials'
        : 'study-images',
    storagePath:
        '${_user.id}/$materialId/${kind == MaterialKind.pdf ? 'stale-0.pdf' : 'stale.png'}',
    mimeType: kind == MaterialKind.pdf ? 'application/pdf' : 'image/png',
    fileSizeBytes: 8,
    processingStatus: succeeds
        ? MaterialProcessingStatus.ready
        : MaterialProcessingStatus.failed,
  );

  void complete({required bool succeeds}) {
    if (kind == MaterialKind.pdf) {
      _pdf.complete(
        PdfTextExtractionResult(
          material: _material(succeeds),
          errorMessage: succeeds ? null : 'Could not extract text. Try again.',
        ),
      );
    } else {
      _image.complete(
        ImageTextExtractionResult(
          material: _material(succeeds),
          errorMessage: succeeds
              ? null
              : 'Could not extract image text. Try again.',
        ),
      );
    }
  }

  @override
  Future<PdfTextExtractionResult> extractPdfText({
    required AuthUser user,
    required String materialId,
  }) {
    called = true;
    this.materialId = materialId;
    return _pdf.future;
  }

  @override
  Future<ImageTextExtractionResult> extractImageText({
    required AuthUser user,
    required String materialId,
  }) {
    called = true;
    this.materialId = materialId;
    return _image.future;
  }
}
