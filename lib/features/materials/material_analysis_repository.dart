import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../auth/auth_models.dart';
import 'structured_summary.dart';

enum AnalysisProcessingMode { recommended, economy }

enum AnalysisState {
  awaitingConfirmation,
  processing,
  reconciliationRequired,
  userRetryRequired,
  completed,
  completedWithWarnings,
  failed,
}

enum AnalysisPublicStage {
  preparingDocument,
  analyzingPages,
  recognizingFormulasAndDiagrams,
  combiningResults,
  creatingSummary,
}

enum AnalysisErrorCode {
  unauthenticated,
  unauthorized,
  unavailable,
  documentTooLarge,
  invalidDocument,
  unsupportedSource,
  corruptDocument,
  invalidRequest,
  confirmationRequired,
  statusNotFound,
  rateLimited,
  serviceUnavailable,
  requestFailed,
  invalidResponse,
  network,
}

enum AnalysisDocumentGate { automatic, confirmation, rejected }

AnalysisDocumentGate analysisDocumentGate(int pageCount) {
  if (pageCount >= 101) return AnalysisDocumentGate.rejected;
  if (pageCount >= 21) return AnalysisDocumentGate.confirmation;
  return AnalysisDocumentGate.automatic;
}

class MaterialAnalysisStatus {
  const MaterialAnalysisStatus({
    required this.materialId,
    required this.processingMode,
    required this.state,
    required this.publicStage,
    required this.pageCount,
    required this.completedPages,
    required this.confirmationRequired,
    required this.canRetry,
    required this.retryAfterSeconds,
    required this.warnings,
    required this.summarySchemaVersion,
    required this.summary,
    required this.structuredSummaryMalformed,
    this.safeErrorCode,
  });
  final String materialId;
  final AnalysisProcessingMode processingMode;
  final AnalysisState state;
  final AnalysisPublicStage publicStage;
  final int pageCount, completedPages;
  final bool confirmationRequired, canRetry;
  final int? retryAfterSeconds, summarySchemaVersion;
  final List<AnalysisWarning> warnings;
  final StructuredSummary? summary;
  final bool structuredSummaryMalformed;
  final String? safeErrorCode;
  bool get isTerminal => {
    AnalysisState.awaitingConfirmation,
    AnalysisState.userRetryRequired,
    AnalysisState.completed,
    AnalysisState.completedWithWarnings,
    AnalysisState.failed,
  }.contains(state);
}

class MaterialAnalysisException implements Exception {
  const MaterialAnalysisException(this.code);
  final AnalysisErrorCode code;
}

abstract class MaterialAnalysisRepository {
  Future<MaterialAnalysisStatus> prepare({
    required AuthUser user,
    required String materialId,
    required AnalysisProcessingMode mode,
    required bool confirmLargeDocument,
  });
  Future<MaterialAnalysisStatus> advance({
    required AuthUser user,
    required String materialId,
  });
  Future<MaterialAnalysisStatus> retry({
    required AuthUser user,
    required String materialId,
  });
  Future<MaterialAnalysisStatus> fetchStatus({
    required AuthUser user,
    required String materialId,
  });
}

abstract class MaterialAnalysisDataSource {
  Future<Object?> invoke(String function, Map<String, Object?> body);
  Future<Object?> fetchStatus(String materialId);
}

class SupabaseMaterialAnalysisDataSource implements MaterialAnalysisDataSource {
  const SupabaseMaterialAnalysisDataSource(this.client);
  final supabase.SupabaseClient client;
  @override
  Future<Object?> invoke(String f, Map<String, Object?> b) async =>
      (await client.functions.invoke(f, body: b)).data;
  @override
  Future<Object?> fetchStatus(String id) =>
      client.rpc('get_material_analysis_status', params: {'p_material_id': id});
}

class SupabaseMaterialAnalysisRepository implements MaterialAnalysisRepository {
  const SupabaseMaterialAnalysisRepository(this.source);
  final MaterialAnalysisDataSource source;
  @override
  Future<MaterialAnalysisStatus> prepare({
    required AuthUser user,
    required String materialId,
    required AnalysisProcessingMode mode,
    required bool confirmLargeDocument,
  }) => _call('prepare-material-analysis', user, materialId, {
    'processing_mode': mode.name,
    'confirm_large_document': confirmLargeDocument,
  });
  @override
  Future<MaterialAnalysisStatus> advance({
    required AuthUser user,
    required String materialId,
  }) => _call('advance-material-analysis', user, materialId, {});
  @override
  Future<MaterialAnalysisStatus> retry({
    required AuthUser user,
    required String materialId,
  }) => _call('retry-material-analysis', user, materialId, {});
  @override
  Future<MaterialAnalysisStatus> fetchStatus({
    required AuthUser user,
    required String materialId,
  }) async {
    _auth(user, materialId);
    try {
      var r = await source.fetchStatus(materialId);
      if (r is List && r.isEmpty) {
        throw const MaterialAnalysisException(AnalysisErrorCode.statusNotFound);
      }
      if (r is List && r.length == 1) r = r.single;
      return decodeMaterialAnalysisStatus(r, expectedMaterialId: materialId);
    } on MaterialAnalysisException {
      rethrow;
    } catch (_) {
      throw const MaterialAnalysisException(AnalysisErrorCode.network);
    }
  }

  Future<MaterialAnalysisStatus> _call(
    String f,
    AuthUser u,
    String id,
    Map<String, Object?> extra,
  ) async {
    _auth(u, id);
    try {
      return decodeMaterialAnalysisStatus(
        await source.invoke(f, {'material_id': id, ...extra}),
        expectedMaterialId: id,
      );
    } on MaterialAnalysisException {
      rethrow;
    } on supabase.FunctionException catch (e) {
      throw MaterialAnalysisException(_functionErrorCode(e));
    } catch (_) {
      throw const MaterialAnalysisException(AnalysisErrorCode.network);
    }
  }

  void _auth(AuthUser u, String id) {
    if (u.id.isEmpty || !_uuid.hasMatch(id)) {
      throw const MaterialAnalysisException(AnalysisErrorCode.unauthenticated);
    }
  }
}

class EmptyMaterialAnalysisRepository implements MaterialAnalysisRepository {
  const EmptyMaterialAnalysisRepository();
  Future<MaterialAnalysisStatus> _n() =>
      throw const MaterialAnalysisException(AnalysisErrorCode.unavailable);
  @override
  Future<MaterialAnalysisStatus> advance({
    required AuthUser user,
    required String materialId,
  }) => _n();
  @override
  Future<MaterialAnalysisStatus> fetchStatus({
    required AuthUser user,
    required String materialId,
  }) => _n();
  @override
  Future<MaterialAnalysisStatus> prepare({
    required AuthUser user,
    required String materialId,
    required AnalysisProcessingMode mode,
    required bool confirmLargeDocument,
  }) => _n();
  @override
  Future<MaterialAnalysisStatus> retry({
    required AuthUser user,
    required String materialId,
  }) => _n();
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
MaterialAnalysisStatus decodeMaterialAnalysisStatus(
  Object? v, {
  required String expectedMaterialId,
}) {
  if (v is! Map) {
    throw const MaterialAnalysisException(AnalysisErrorCode.invalidResponse);
  }
  late final Map<String, Object?> m;
  try {
    m = Map<String, Object?>.from(v);
  } catch (_) {
    throw const MaterialAnalysisException(AnalysisErrorCode.invalidResponse);
  }
  final requiredKeys = {
    'material_id',
    'processing_mode',
    'state',
    'public_stage',
    'page_count',
    'completed_pages',
    'confirmation_required',
    'can_retry',
    'retry_after_seconds',
    'warnings',
    'summary_schema_version',
    'summary_payload',
  };
  final allowedKeys = {...requiredKeys, 'safe_error_code', 'active_operation'};
  if (!m.keys.toSet().containsAll(requiredKeys) ||
      !allowedKeys.containsAll(m.keys) ||
      m['material_id'] != expectedMaterialId ||
      !_uuid.hasMatch(expectedMaterialId)) {
    throw const MaterialAnalysisException(AnalysisErrorCode.invalidResponse);
  }
  try {
    final mode = switch (m['processing_mode']) {
          'recommended' => AnalysisProcessingMode.recommended,
          'economy' => AnalysisProcessingMode.economy,
          _ => throw const FormatException(),
        },
        state = switch (m['state']) {
          'awaiting_confirmation' => AnalysisState.awaitingConfirmation,
          'processing' => AnalysisState.processing,
          'reconciliation_required' => AnalysisState.reconciliationRequired,
          'user_retry_required' => AnalysisState.userRetryRequired,
          'completed' => AnalysisState.completed,
          'completed_with_warnings' => AnalysisState.completedWithWarnings,
          'failed' => AnalysisState.failed,
          _ => throw const FormatException(),
        },
        rawStage = switch (m['public_stage']) {
          'preparing_document' => AnalysisPublicStage.preparingDocument,
          'analyzing_pages' => AnalysisPublicStage.analyzingPages,
          'recognizing_formulas_and_diagrams' =>
            AnalysisPublicStage.recognizingFormulasAndDiagrams,
          'creating_summary' => AnalysisPublicStage.creatingSummary,
          _ => throw const FormatException(),
        };
    final activeOperation = m['active_operation'];
    if (activeOperation != null &&
        (activeOperation is! String ||
            !const {
              'page_text',
              'page_visual',
              'page_recovery',
              'reduction',
              'final_summary',
            }.contains(activeOperation))) {
      throw const FormatException();
    }
    final stage =
        rawStage == AnalysisPublicStage.creatingSummary &&
            activeOperation == 'reduction'
        ? AnalysisPublicStage.combiningResults
        : rawStage;
    final safeErrorCode = m['safe_error_code'];
    if (safeErrorCode != null &&
        (safeErrorCode is! String ||
            safeErrorCode.length > 64 ||
            !RegExp(r'^[a-z0-9_]+$').hasMatch(safeErrorCode))) {
      throw const FormatException();
    }
    final p = m['page_count'],
        c = m['completed_pages'],
        r = m['retry_after_seconds'],
        s = m['summary_schema_version'];
    if (p is! int ||
        p < 1 ||
        p > 100 ||
        c is! int ||
        c < 0 ||
        c > p ||
        m['confirmation_required'] is! bool ||
        m['can_retry'] is! bool ||
        (r != null && (r is! int || r < 0 || r > 900)) ||
        (s != null && (s is! int || s < 1))) {
      throw const FormatException();
    }
    final wr = m['warnings'];
    if (wr is! List || wr.length > 100) throw const FormatException();
    final d = const StructuredSummaryDecoder(),
        warnings = wr.map((e) => d.decodeWarning(e, p)).toList(growable: false);
    StructuredSummary? summary;
    if (m['summary_payload'] != null) {
      if (s is! int) throw const StructuredSummaryFormatException();
      summary = d.decode(m['summary_payload'], schemaVersion: s, pageCount: p);
    }
    if ({
          AnalysisState.completed,
          AnalysisState.completedWithWarnings,
        }.contains(state) &&
        summary == null) {
      throw const StructuredSummaryFormatException();
    }
    return MaterialAnalysisStatus(
      materialId: expectedMaterialId,
      processingMode: mode,
      state: state,
      publicStage: stage,
      pageCount: p,
      completedPages: c,
      confirmationRequired: m['confirmation_required'] as bool,
      canRetry: m['can_retry'] as bool,
      retryAfterSeconds: r as int?,
      warnings: warnings,
      summarySchemaVersion: s as int?,
      summary: summary,
      structuredSummaryMalformed: false,
      safeErrorCode: safeErrorCode as String?,
    );
  } catch (_) {
    throw const MaterialAnalysisException(AnalysisErrorCode.invalidResponse);
  }
}

AnalysisErrorCode _functionErrorCode(supabase.FunctionException exception) {
  final status = exception.status;
  final code = _safePublicErrorCode(exception.details);
  if (status == 401) return AnalysisErrorCode.unauthenticated;
  if (status == 403) return AnalysisErrorCode.unauthorized;
  if (status == 404) return AnalysisErrorCode.unavailable;
  if (status == 429) return AnalysisErrorCode.rateLimited;
  if (status == 500 && code == 'request_failed') {
    return AnalysisErrorCode.requestFailed;
  }
  if (status == 500 || status == 502 || status == 503 || status == 504) {
    return AnalysisErrorCode.serviceUnavailable;
  }
  if (status == 422) {
    return switch (code) {
      'document_too_large' => AnalysisErrorCode.documentTooLarge,
      'unsupported_source' => AnalysisErrorCode.unsupportedSource,
      'corrupt_document' => AnalysisErrorCode.corruptDocument,
      'confirmation_required' => AnalysisErrorCode.confirmationRequired,
      'invalid_request' => AnalysisErrorCode.invalidRequest,
      _ => AnalysisErrorCode.invalidDocument,
    };
  }
  if (status == 400) return AnalysisErrorCode.invalidRequest;
  if (status == 409 && code == 'confirmation_required') {
    return AnalysisErrorCode.confirmationRequired;
  }
  return AnalysisErrorCode.network;
}

String? _safePublicErrorCode(Object? details) {
  if (details is! Map || details.keys.any((key) => key is! String)) return null;
  final value = details['code'];
  if (value is! String ||
      value.length > 64 ||
      !RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
    return null;
  }
  return value;
}
