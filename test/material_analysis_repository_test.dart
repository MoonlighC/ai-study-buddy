import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_analysis_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const id = '22222222-2222-4222-8222-222222222222';
const user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'a@example.test',
);
void main() {
  test('prepare sends only strict public request values', () async {
    final source = _Source(_status());
    final repo = SupabaseMaterialAnalysisRepository(source);
    await repo.prepare(
      user: user,
      materialId: id,
      mode: AnalysisProcessingMode.economy,
      confirmLargeDocument: true,
    );
    expect(source.function, 'prepare-material-analysis');
    expect(source.body, {
      'material_id': id,
      'processing_mode': 'economy',
      'confirm_large_document': true,
    });
  });
  test(
    'Analyze again creates a new generation without an upload body',
    () async {
      final source = _Source(_status());
      final repo = SupabaseMaterialAnalysisRepository(source);
      await repo.analyzeAgain(
        user: user,
        materialId: id,
        mode: AnalysisProcessingMode.recommended,
      );
      expect(source.function, 'prepare-material-analysis');
      expect(source.body, {
        'material_id': id,
        'processing_mode': 'recommended',
        'confirm_large_document': false,
        'analyze_again': true,
      });
      expect(source.body!.keys, isNot(contains('storage_path')));
    },
  );
  test(
    'terminal Edge failure refreshes authoritative safe error for UI copy',
    () async {
      final immediate = _status()
        ..['state'] = 'failed'
        ..['public_stage'] = 'creating_summary'
        ..['completed_pages'] = 1
        ..['can_analyze_again'] = true;
      final authoritative = _statusRpcV2()
        ..['state'] = 'failed'
        ..['public_stage'] = 'creating_summary'
        ..['completed_pages'] = 1
        ..['can_analyze_again'] = true
        ..['safe_error_code'] = 'structured_output_invalid';
      final source = _Source(immediate, statusResult: authoritative);

      final status = await SupabaseMaterialAnalysisRepository(
        source,
      ).advance(user: user, materialId: id);

      expect(source.statusId, id);
      expect(status.safeErrorCode, 'structured_output_invalid');
      expect(status.canAnalyzeAgain, isTrue);
    },
  );
  test(
    'terminal Edge failure remains usable when authoritative refresh is offline',
    () async {
      final immediate = _status()
        ..['state'] = 'failed'
        ..['public_stage'] = 'creating_summary'
        ..['completed_pages'] = 1
        ..['can_analyze_again'] = true;
      final status = await SupabaseMaterialAnalysisRepository(
        _StatusThrowingSource(
          immediate,
          const MaterialAnalysisException(AnalysisErrorCode.network),
        ),
      ).advance(user: user, materialId: id);
      expect(status.state, AnalysisState.failed);
      expect(status.safeErrorCode, isNull);
      expect(status.canAnalyzeAgain, isTrue);
    },
  );
  test('advance retry and status use exact material id only', () async {
    final source = _Source(_status(), statusResult: _statusRpcV2());
    final repo = SupabaseMaterialAnalysisRepository(source);
    await repo.advance(user: user, materialId: id);
    expect(source.body, {'material_id': id});
    await repo.retry(user: user, materialId: id);
    expect(source.body, {'material_id': id});
    await repo.fetchStatus(user: user, materialId: id);
    expect(source.statusId, id);
  });
  test('new client uses the v2 RPC when migration 031 is present', () async {
    final source = _RolloutSource(
      v2Result: _statusRpcV2()..['can_analyze_again'] = true,
    );
    final status = await SupabaseMaterialAnalysisRepository(
      source,
    ).fetchStatus(user: user, materialId: id);
    expect(status.canAnalyzeAgain, isTrue);
    expect(source.v2Calls, 1);
    expect(source.v1Calls, 0);
  });
  test('new client falls back exactly for a missing v2 RPC', () async {
    final source = _RolloutSource(
      v2Error: const supabase.PostgrestException(
        message:
            'Could not find the function public.get_material_analysis_status_v2',
        code: 'PGRST202',
      ),
      v1Result: _statusRpcV1(),
    );
    final status = await SupabaseMaterialAnalysisRepository(
      source,
    ).fetchStatus(user: user, materialId: id);
    expect(status.canAnalyzeAgain, isFalse);
    expect(source.v2Calls, 1);
    expect(source.v1Calls, 1);
  });
  test('v2 RPC fallback never masks other database errors', () async {
    for (final error in [
      const supabase.PostgrestException(message: 'denied', code: '42501'),
      const supabase.PostgrestException(
        message: 'Could not find a different function',
        code: 'PGRST202',
      ),
    ]) {
      final source = _RolloutSource(v2Error: error, v1Result: _statusRpcV1());
      await expectLater(
        SupabaseMaterialAnalysisRepository(
          source,
        ).fetchStatus(user: user, materialId: id),
        throwsA(
          isA<MaterialAnalysisException>().having(
            (value) => value.code,
            'code',
            AnalysisErrorCode.network,
          ),
        ),
      );
      expect(source.v1Calls, 0);
    }
  });
  test('v1 and v2 decoders reject the other RPC contract', () {
    expect(
      () => decodeMaterialAnalysisStatusV1Rpc(
        _statusRpcV2(),
        expectedMaterialId: id,
      ),
      throwsA(isA<MaterialAnalysisException>()),
    );
    expect(
      () => decodeMaterialAnalysisStatusV2Rpc(
        _statusRpcV1(),
        expectedMaterialId: id,
      ),
      throwsA(isA<MaterialAnalysisException>()),
    );
  });
  test('malformed public status is a safe typed error', () async {
    final source = _Source({'detail': 'secret'});
    final repo = SupabaseMaterialAnalysisRepository(source);
    expect(
      () => repo.advance(user: user, materialId: id),
      throwsA(
        isA<MaterialAnalysisException>().having(
          (e) => e.code,
          'code',
          AnalysisErrorCode.invalidResponse,
        ),
      ),
    );
  });
  test('extra missing and non-integer public fields reject exactly', () {
    final extra = _status()..['job_id'] = 'secret';
    final missing = _status()..remove('can_retry');
    final doublePage = _status()..['page_count'] = 1.0;
    final stringProgress = _status()..['completed_pages'] = '0';
    for (final value in [extra, missing, doublePage, stringProgress]) {
      expect(
        () => decodeMaterialAnalysisStatus(value, expectedMaterialId: id),
        throwsA(
          isA<MaterialAnalysisException>().having(
            (error) => error.code,
            'code',
            AnalysisErrorCode.invalidResponse,
          ),
        ),
      );
    }
  });
  test('completed states require a valid structured summary', () {
    for (final state in ['completed', 'completed_with_warnings']) {
      final value = _status()
        ..['state'] = state
        ..['completed_pages'] = 1;
      expect(
        () => decodeMaterialAnalysisStatus(value, expectedMaterialId: id),
        throwsA(isA<MaterialAnalysisException>()),
      );
      value['summary_schema_version'] = 1;
      value['summary_payload'] = _summary();
      expect(
        decodeMaterialAnalysisStatus(value, expectedMaterialId: id).summary,
        isNotNull,
      );
    }
  });
  test('nullable summary combinations match the C2 public contract', () {
    for (final state in [
      'awaiting_confirmation',
      'processing',
      'reconciliation_required',
      'user_retry_required',
      'failed',
    ]) {
      final withoutSummary = _status()..['state'] = state;
      expect(
        () => decodeMaterialAnalysisStatus(
          withoutSummary,
          expectedMaterialId: id,
        ),
        returnsNormally,
      );
      final withVersionOnly = _status()
        ..['state'] = state
        ..['summary_schema_version'] = 1;
      expect(
        () => decodeMaterialAnalysisStatus(
          withVersionOnly,
          expectedMaterialId: id,
        ),
        returnsNormally,
      );
      final withSummary = _status()
        ..['state'] = state
        ..['summary_schema_version'] = 1
        ..['summary_payload'] = _summary();
      expect(
        decodeMaterialAnalysisStatus(
          withSummary,
          expectedMaterialId: id,
        ).summary,
        isNotNull,
      );
    }
    final missingVersion = _status()..['summary_payload'] = _summary();
    expect(
      () =>
          decodeMaterialAnalysisStatus(missingVersion, expectedMaterialId: id),
      throwsA(isA<MaterialAnalysisException>()),
    );
    final unsupportedVersion = _status()
      ..['summary_schema_version'] = 2
      ..['summary_payload'] = _summary();
    expect(
      () => decodeMaterialAnalysisStatus(
        unsupportedVersion,
        expectedMaterialId: id,
      ),
      throwsA(isA<MaterialAnalysisException>()),
    );
  });
  test(
    'safe failure and active reduction are decoded without internal data',
    () {
      final failed = _statusRpcV2()
        ..['state'] = 'failed'
        ..['safe_error_code'] = 'structured_output_invalid'
        ..['active_operation'] = null;
      expect(
        decodeMaterialAnalysisStatusV2Rpc(
          failed,
          expectedMaterialId: id,
        ).safeErrorCode,
        'structured_output_invalid',
      );

      final reducing = _statusRpcV2()
        ..['public_stage'] = 'creating_summary'
        ..['safe_error_code'] = null
        ..['active_operation'] = 'reduction';
      expect(
        decodeMaterialAnalysisStatusV2Rpc(
          reducing,
          expectedMaterialId: id,
        ).publicStage,
        AnalysisPublicStage.combiningResults,
      );
    },
  );
  test('typed 422 mapping uses only a bounded safe public code', () async {
    final cases = {
      'document_too_large': AnalysisErrorCode.documentTooLarge,
      'corrupt_document': AnalysisErrorCode.corruptDocument,
      'unsupported_source': AnalysisErrorCode.unsupportedSource,
      'unknown_safe_code': AnalysisErrorCode.invalidDocument,
    };
    for (final entry in cases.entries) {
      final repo = SupabaseMaterialAnalysisRepository(
        _ThrowingSource(
          supabase.FunctionException(
            status: 422,
            details: {'code': entry.key, 'error': 'raw backend text'},
          ),
        ),
      );
      await expectLater(
        repo.prepare(
          user: user,
          materialId: id,
          mode: AnalysisProcessingMode.recommended,
          confirmLargeDocument: false,
        ),
        throwsA(
          isA<MaterialAnalysisException>().having(
            (error) => error.code,
            'code',
            entry.value,
          ),
        ),
      );
    }
  });
  test('malformed 422 details never expose raw backend text', () async {
    for (final details in [
      'SQL secret response',
      {'code': 'not safe!'},
      {'code': 'x' * 100},
    ]) {
      final repo = SupabaseMaterialAnalysisRepository(
        _ThrowingSource(
          supabase.FunctionException(status: 422, details: details),
        ),
      );
      await expectLater(
        repo.advance(user: user, materialId: id),
        throwsA(
          isA<MaterialAnalysisException>().having(
            (error) => error.code,
            'code',
            AnalysisErrorCode.invalidDocument,
          ),
        ),
      );
    }
  });
  test(
    'deterministic request_failed 500 is not classified as transient',
    () async {
      final repo = SupabaseMaterialAnalysisRepository(
        _ThrowingSource(
          supabase.FunctionException(
            status: 500,
            details: {'code': 'request_failed'},
          ),
        ),
      );

      await expectLater(
        repo.advance(user: user, materialId: id),
        throwsA(
          isA<MaterialAnalysisException>().having(
            (error) => error.code,
            'code',
            AnalysisErrorCode.requestFailed,
          ),
        ),
      );
    },
  );
  test('exact owner/session and UUID are required', () async {
    final repo = SupabaseMaterialAnalysisRepository(_Source(_status()));
    expect(
      () => repo.advance(
        user: const AuthUser(id: '', email: 'x'),
        materialId: id,
      ),
      throwsA(isA<MaterialAnalysisException>()),
    );
    expect(
      () => repo.advance(user: user, materialId: 'latest'),
      throwsA(isA<MaterialAnalysisException>()),
    );
  });
}

class _Source implements MaterialAnalysisDataSource {
  _Source(this.result, {this.statusResult});
  final Object? result;
  final Object? statusResult;
  String? function, statusId;
  Map<String, Object?>? body;
  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) async {
    this.function = function;
    this.body = body;
    return result;
  }

  @override
  Future<Object?> fetchStatusV2(String materialId) async {
    statusId = materialId;
    return statusResult ?? result;
  }

  @override
  Future<Object?> fetchStatusV1(String materialId) async =>
      throw StateError('unexpected v1 fallback');
}

class _StatusThrowingSource implements MaterialAnalysisDataSource {
  const _StatusThrowingSource(this.result, this.statusError);

  final Object? result;
  final Object statusError;

  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) async =>
      result;

  @override
  Future<Object?> fetchStatusV2(String materialId) => Future.error(statusError);

  @override
  Future<Object?> fetchStatusV1(String materialId) => Future.error(statusError);
}

class _ThrowingSource implements MaterialAnalysisDataSource {
  const _ThrowingSource(this.error);

  final Object error;
  @override
  Future<Object?> fetchStatusV2(String materialId) => Future.error(error);
  @override
  Future<Object?> fetchStatusV1(String materialId) => Future.error(error);
  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) =>
      Future.error(error);
}

class _RolloutSource implements MaterialAnalysisDataSource {
  _RolloutSource({this.v2Result, this.v1Result, this.v2Error});
  final Object? v2Result, v1Result, v2Error;
  int v1Calls = 0, v2Calls = 0;

  @override
  Future<Object?> fetchStatusV2(String materialId) async {
    v2Calls++;
    if (v2Error != null) throw v2Error!;
    return v2Result;
  }

  @override
  Future<Object?> fetchStatusV1(String materialId) async {
    v1Calls++;
    return v1Result;
  }

  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) =>
      throw StateError('unexpected Edge Function call');
}

Map<String, Object?> _status() => {
  'material_id': id,
  'processing_mode': 'recommended',
  'state': 'processing',
  'public_stage': 'analyzing_pages',
  'page_count': 1,
  'completed_pages': 0,
  'confirmation_required': false,
  'can_retry': false,
  'can_analyze_again': false,
  'retry_after_seconds': null,
  'warnings': <Object?>[],
  'summary_schema_version': null,
  'summary_payload': null,
};

Map<String, Object?> _statusRpcV2() => {
  ..._status(),
  'safe_error_code': null,
  'active_operation': null,
};

Map<String, Object?> _statusRpcV1() {
  final value = _statusRpcV2()..remove('can_analyze_again');
  return value;
}

Map<String, Object?> _summary() => {
  'language': 'en',
  'sections': [
    {
      'id': 'section',
      'title': 'Title',
      'blocks': [
        {'kind': 'prose', 'markdown': 'Text', 'display': 'block'},
      ],
      'source_pages': [1],
      'confidence': 1,
    },
  ],
  'key_concepts': <Object?>[],
  'equations': <Object?>[],
  'warnings': <Object?>[],
  'partial_extraction': {
    'is_partial': false,
    'analyzed_pages': [1],
    'partial_pages': <int>[],
    'missing_pages': <int>[],
    'page_modes': [
      {'page': 1, 'mode': 'text'},
    ],
  },
};
