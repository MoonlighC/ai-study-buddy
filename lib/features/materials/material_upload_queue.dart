import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/material.dart';
import '../auth/auth_models.dart';
import 'material_upload.dart';
import 'material_upload_repository.dart';

enum MaterialUploadQueueStatus { queued, uploading, processing, ready, failed }

enum MaterialUploadRetryStage { upload, materialCreation, extraction }

enum MaterialUploadQueueErrorCode {
  invalidFile,
  unsupportedFile,
  emptyFile,
  fileTooLarge,
  sessionExpired,
  sessionChanged,
  uploadFailed,
  materialCreationFailed,
  processingFailed,
  processingConsentRequired,
  authorizationDenied,
  storageNotFound,
  networkFailure,
  invalidMetadata,
}

@immutable
class MaterialUploadQueueItem {
  const MaterialUploadQueueItem({
    required this.queueId,
    required this.fileName,
    required this.fileSizeBytes,
    required this.subjectId,
    required this.kind,
    required this.status,
    required this.attemptCount,
    this.authoritativeMaterialId,
    this.progress,
    this.errorCode,
    this.retryStage,
  });

  final String queueId;
  final String fileName;
  final int fileSizeBytes;
  final String subjectId;
  final MaterialKind kind;
  final String? authoritativeMaterialId;
  final MaterialUploadQueueStatus status;
  final double? progress;
  final MaterialUploadQueueErrorCode? errorCode;
  final MaterialUploadRetryStage? retryStage;
  final int attemptCount;

  MaterialUploadQueueItem copyWith({
    String? authoritativeMaterialId,
    MaterialUploadQueueStatus? status,
    double? progress,
    bool clearProgress = false,
    MaterialUploadQueueErrorCode? errorCode,
    bool clearError = false,
    MaterialUploadRetryStage? retryStage,
    bool clearRetryStage = false,
    int? attemptCount,
  }) {
    return MaterialUploadQueueItem(
      queueId: queueId,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      subjectId: subjectId,
      kind: kind,
      authoritativeMaterialId:
          authoritativeMaterialId ?? this.authoritativeMaterialId,
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      retryStage: clearRetryStage ? null : (retryStage ?? this.retryStage),
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }
}

class MaterialQueueProcessingResult {
  const MaterialQueueProcessingResult({
    required this.material,
    required this.succeeded,
    this.consentRequired = false,
  });

  final StudyMaterial material;
  final bool succeeded;
  final bool consentRequired;
}

typedef MaterialQueueProcessor =
    Future<MaterialQueueProcessingResult> Function(
      AuthUser user,
      StudyMaterial material,
      MaterialQueueWorkGuard guard,
    );

class MaterialQueueWorkGuard {
  const MaterialQueueWorkGuard._(
    this._controller,
    this.queueId,
    this.userId,
    this.generation,
  );

  final MaterialUploadQueueController _controller;
  final String queueId;
  final String userId;
  final int generation;

  bool get isCurrent => _controller._isWorkCurrent(this);
  bool get isSessionCurrent => _controller._isSessionCurrent(this);
}

class MaterialUploadQueueController extends ChangeNotifier {
  factory MaterialUploadQueueController({
    required MaterialUploadRepository repository,
    required String Function() queueIdGenerator,
    required String Function() materialIdGenerator,
    required MaterialQueueProcessor processMaterial,
    required void Function(StudyMaterial material) onMaterialChanged,
    int maxWorkers = 2,
  }) => MaterialUploadQueueController._(
    repository,
    queueIdGenerator,
    materialIdGenerator,
    processMaterial,
    onMaterialChanged,
    maxWorkers.clamp(1, 2),
  );

  MaterialUploadQueueController._(
    this._repository,
    this._queueIdGenerator,
    this._materialIdGenerator,
    this._processMaterial,
    this._onMaterialChanged,
    this.maxWorkers,
  );

  final MaterialUploadRepository _repository;
  final String Function() _queueIdGenerator;
  final String Function() _materialIdGenerator;
  final MaterialQueueProcessor _processMaterial;
  final void Function(StudyMaterial material) _onMaterialChanged;
  final int maxWorkers;

  final List<MaterialUploadQueueItem> _items = [];
  final Map<String, _PendingQueuePayload> _payloads = {};
  final Set<String> _acceptedBatchTokens = {};
  int _activeWorkers = 0;
  int _sessionGeneration = 0;
  bool _schedulePending = false;
  bool _disposed = false;
  String? _sessionUserId;

  List<MaterialUploadQueueItem> get items => List.unmodifiable(_items);
  int get activeWorkers => _activeWorkers;

  bool enqueueBatch({
    required AuthUser user,
    required String subjectId,
    required MaterialKind kind,
    required MaterialFilePickerBatch batch,
  }) {
    bindSession(user.id);
    if (batch.errorCode != null ||
        !_acceptedBatchTokens.add(batch.batchToken)) {
      return false;
    }
    var added = false;
    for (final result in batch.results) {
      if (!result.isValid) continue;
      final queueId = _queueIdGenerator();
      final file = result.file;
      _items.add(
        MaterialUploadQueueItem(
          queueId: queueId,
          fileName: file.name,
          fileSizeBytes: file.reportedSizeBytes,
          subjectId: subjectId,
          kind: kind,
          status: MaterialUploadQueueStatus.queued,
          attemptCount: 0,
        ),
      );
      _payloads[queueId] = _PendingQueuePayload(
        user: user,
        subjectId: subjectId,
        kind: kind,
        file: file,
        plannedMaterialId: _materialIdGenerator(),
      );
      added = true;
    }
    if (added) {
      notifyListeners();
      _schedule();
    }
    return added;
  }

  bool retry(String queueId) {
    final index = _indexOf(queueId);
    if (index < 0 ||
        _items[index].status != MaterialUploadQueueStatus.failed ||
        !_payloads.containsKey(queueId)) {
      return false;
    }
    _items[index] = _items[index].copyWith(
      status: MaterialUploadQueueStatus.queued,
      clearProgress: true,
      clearError: true,
      clearRetryStage: true,
    );
    notifyListeners();
    _schedule();
    return true;
  }

  void acceptAuthoritativeMaterial(StudyMaterial material) {
    for (var index = 0; index < _items.length; index += 1) {
      final item = _items[index];
      if (item.authoritativeMaterialId != material.id) continue;
      if (material.processingStatus == MaterialProcessingStatus.ready &&
          material.hasContentText) {
        _items[index] = item.copyWith(
          status: MaterialUploadQueueStatus.ready,
          clearProgress: true,
          clearError: true,
          clearRetryStage: true,
        );
        _payloads.remove(item.queueId);
        notifyListeners();
      }
      return;
    }
  }

  void clearForSessionChange() {
    _sessionUserId = null;
    _sessionGeneration += 1;
    _items.clear();
    _payloads.clear();
    _acceptedBatchTokens.clear();
    notifyListeners();
  }

  void bindSession(String? userId) {
    if (_sessionUserId == userId) return;
    _sessionUserId = userId;
    _sessionGeneration += 1;
    _items.clear();
    _payloads.clear();
    _acceptedBatchTokens.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration += 1;
    _items.clear();
    _payloads.clear();
    _acceptedBatchTokens.clear();
    super.dispose();
  }

  void _schedule() {
    if (_disposed || _schedulePending) return;
    _schedulePending = true;
    scheduleMicrotask(() {
      _schedulePending = false;
      if (_disposed) return;
      while (_activeWorkers < maxWorkers) {
        final index = _items.indexWhere(
          (item) => item.status == MaterialUploadQueueStatus.queued,
        );
        if (index < 0) break;
        final queueId = _items[index].queueId;
        final payload = _payloads[queueId];
        if (payload == null) {
          _fail(
            queueId,
            MaterialUploadQueueErrorCode.processingFailed,
            MaterialUploadRetryStage.extraction,
          );
          continue;
        }
        _activeWorkers += 1;
        final generation = _sessionGeneration;
        unawaited(
          _run(queueId, payload, generation).whenComplete(() {
            _activeWorkers -= 1;
            _schedule();
          }),
        );
      }
    });
  }

  Future<void> _run(
    String queueId,
    _PendingQueuePayload payload,
    int generation,
  ) async {
    final guard = MaterialQueueWorkGuard._(
      this,
      queueId,
      payload.user.id,
      generation,
    );
    final index = _indexOf(queueId);
    if (index < 0 || !guard.isCurrent) return;
    _items[index] = _items[index].copyWith(
      status: MaterialUploadQueueStatus.uploading,
      clearProgress: true,
      clearError: true,
      clearRetryStage: true,
      attemptCount: _items[index].attemptCount + 1,
    );
    notifyListeners();

    StudyMaterial material;
    try {
      material = payload.file == null && payload.material != null
          ? payload.material!
          : await _uploadActivePayload(queueId, payload, guard);
    } on MaterialUploadValidationException catch (error) {
      if (generation != _sessionGeneration) return;
      _fail(
        queueId,
        _queueCodeForValidation(error.code),
        MaterialUploadRetryStage.upload,
      );
      return;
    } on MaterialUploadException catch (error) {
      if (generation != _sessionGeneration) return;
      _fail(
        queueId,
        _queueCodeForUpload(error.code),
        error.stage == MaterialUploadFailureStage.materialCreation
            ? MaterialUploadRetryStage.materialCreation
            : MaterialUploadRetryStage.upload,
      );
      return;
    } catch (_) {
      if (generation != _sessionGeneration) return;
      _fail(
        queueId,
        MaterialUploadQueueErrorCode.uploadFailed,
        MaterialUploadRetryStage.upload,
      );
      return;
    }
    if (generation != _sessionGeneration) return;

    _onMaterialChanged(material);
    _setAuthoritative(queueId, material.id);
    final currentPayload = _payloads[queueId];
    if (currentPayload != null) {
      _payloads[queueId] = currentPayload.withoutFile(material);
    }
    if (material.processingStatus == MaterialProcessingStatus.ready &&
        material.hasContentText) {
      _markReady(queueId);
      return;
    }

    _updateStatus(queueId, MaterialUploadQueueStatus.processing);
    try {
      final result = await _processMaterial(payload.user, material, guard);
      if (!guard.isCurrent) return;
      _onMaterialChanged(result.material);
      if (result.succeeded) {
        _markReady(queueId);
      } else {
        _fail(
          queueId,
          result.consentRequired
              ? MaterialUploadQueueErrorCode.processingConsentRequired
              : MaterialUploadQueueErrorCode.processingFailed,
          MaterialUploadRetryStage.extraction,
        );
      }
    } catch (_) {
      if (generation != _sessionGeneration) return;
      _fail(
        queueId,
        MaterialUploadQueueErrorCode.processingFailed,
        MaterialUploadRetryStage.extraction,
      );
    }
  }

  Future<StudyMaterial> _uploadActivePayload(
    String queueId,
    _PendingQueuePayload payload,
    MaterialQueueWorkGuard guard,
  ) async {
    if (payload.file == null) {
      throw const MaterialUploadException(
        'The material could not be resumed.',
        stage: MaterialUploadFailureStage.materialCreation,
        code: MaterialUploadErrorCode.materialCreationFailed,
      );
    }
    final request = await prepareMaterialUpload(
      selectedFile: payload.file!,
      expectedKind: payload.kind,
      materialId: payload.plannedMaterialId,
      subjectId: payload.subjectId,
    );
    if (!guard.isCurrent) throw const _QueueWorkInvalidated();
    return _repository.uploadMaterial(
      expectedUser: payload.user,
      request: request,
      onProgress: (progress) {
        if (!guard.isCurrent) return;
        final index = _indexOf(queueId);
        if (index < 0) return;
        _items[index] = _items[index].copyWith(
          progress: progress,
          clearProgress: progress == null,
        );
        notifyListeners();
      },
    );
  }

  void _setAuthoritative(String queueId, String materialId) {
    final index = _indexOf(queueId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      authoritativeMaterialId: materialId,
      clearProgress: true,
    );
    notifyListeners();
  }

  void _updateStatus(String queueId, MaterialUploadQueueStatus status) {
    final index = _indexOf(queueId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(status: status, clearProgress: true);
    notifyListeners();
  }

  void _markReady(String queueId) {
    final index = _indexOf(queueId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      status: MaterialUploadQueueStatus.ready,
      clearProgress: true,
      clearError: true,
      clearRetryStage: true,
    );
    _payloads.remove(queueId);
    notifyListeners();
  }

  void _fail(
    String queueId,
    MaterialUploadQueueErrorCode code,
    MaterialUploadRetryStage retryStage,
  ) {
    final index = _indexOf(queueId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      status: MaterialUploadQueueStatus.failed,
      clearProgress: true,
      errorCode: code,
      retryStage: retryStage,
    );
    notifyListeners();
  }

  int _indexOf(String queueId) =>
      _items.indexWhere((item) => item.queueId == queueId);

  bool _isWorkCurrent(MaterialQueueWorkGuard guard) {
    if (!_isSessionCurrent(guard) || !_payloads.containsKey(guard.queueId)) {
      return false;
    }
    final index = _indexOf(guard.queueId);
    if (index < 0) return false;
    return _items[index].status == MaterialUploadQueueStatus.queued ||
        _items[index].status == MaterialUploadQueueStatus.uploading ||
        _items[index].status == MaterialUploadQueueStatus.processing;
  }

  bool _isSessionCurrent(MaterialQueueWorkGuard guard) =>
      !_disposed &&
      guard.generation == _sessionGeneration &&
      guard.userId == _sessionUserId;
}

class _QueueWorkInvalidated implements Exception {
  const _QueueWorkInvalidated();
}

class _PendingQueuePayload {
  const _PendingQueuePayload({
    required this.user,
    required this.subjectId,
    required this.kind,
    required this.plannedMaterialId,
    this.file,
    this.material,
  });

  final AuthUser user;
  final String subjectId;
  final MaterialKind kind;
  final String plannedMaterialId;
  final SelectedMaterialFile? file;
  final StudyMaterial? material;

  _PendingQueuePayload withoutFile(StudyMaterial authoritativeMaterial) =>
      _PendingQueuePayload(
        user: user,
        subjectId: subjectId,
        kind: kind,
        plannedMaterialId: plannedMaterialId,
        material: authoritativeMaterial,
      );
}

MaterialUploadQueueErrorCode _queueCodeForValidation(
  MaterialFileValidationCode code,
) => switch (code) {
  MaterialFileValidationCode.unsupportedFile =>
    MaterialUploadQueueErrorCode.unsupportedFile,
  MaterialFileValidationCode.emptyFile =>
    MaterialUploadQueueErrorCode.emptyFile,
  MaterialFileValidationCode.fileTooLarge =>
    MaterialUploadQueueErrorCode.fileTooLarge,
  MaterialFileValidationCode.invalidFile =>
    MaterialUploadQueueErrorCode.invalidFile,
};

MaterialUploadQueueErrorCode _queueCodeForUpload(
  MaterialUploadErrorCode code,
) => switch (code) {
  MaterialUploadErrorCode.sessionExpired =>
    MaterialUploadQueueErrorCode.sessionExpired,
  MaterialUploadErrorCode.sessionChanged =>
    MaterialUploadQueueErrorCode.sessionChanged,
  MaterialUploadErrorCode.materialCreationFailed =>
    MaterialUploadQueueErrorCode.materialCreationFailed,
  MaterialUploadErrorCode.invalidReconciliation =>
    MaterialUploadQueueErrorCode.materialCreationFailed,
  MaterialUploadErrorCode.storageNotFound =>
    MaterialUploadQueueErrorCode.storageNotFound,
  MaterialUploadErrorCode.authorizationDenied =>
    MaterialUploadQueueErrorCode.authorizationDenied,
  MaterialUploadErrorCode.networkFailure =>
    MaterialUploadQueueErrorCode.networkFailure,
  MaterialUploadErrorCode.invalidMetadata =>
    MaterialUploadQueueErrorCode.invalidMetadata,
  MaterialUploadErrorCode.uploadFailed =>
    MaterialUploadQueueErrorCode.uploadFailed,
};
