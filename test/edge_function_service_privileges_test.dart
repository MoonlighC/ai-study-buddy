import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String diagnosticSelectorMigration;
  late String diagnosticCleanupMigration;
  late String recoveryFingerprintMigration;
  late String noWorkTerminalizationMigration;
  late String terminalReconciliationMigration;

  setUpAll(() async {
    migration = _normalize(
      await File(
        'supabase/migrations/009_edge_function_service_privileges.sql',
      ).readAsString(),
    );
    diagnosticSelectorMigration = _normalize(
      await File(
        'supabase/migrations/013_material_analysis_diagnostic_target_selection.sql',
      ).readAsString(),
    );
    diagnosticCleanupMigration = _normalize(
      await File(
        'supabase/migrations/014_material_analysis_diagnostic_cleanup.sql',
      ).readAsString(),
    );
    recoveryFingerprintMigration = _normalize(
      await File(
        'supabase/migrations/015_material_analysis_recovery_fingerprints.sql',
      ).readAsString(),
    );
    noWorkTerminalizationMigration = _normalize(
      await File(
        'supabase/migrations/016_material_analysis_no_work_terminalization.sql',
      ).readAsString(),
    );
    terminalReconciliationMigration = _normalize(
      await File(
        'supabase/migrations/018_material_analysis_terminal_reconciliation.sql',
      ).readAsString(),
    );
  });

  test('terminal reconciliation remains service-role-only', () {
    expect(
      terminalReconciliationMigration,
      contains(
        'revoke all on function public.terminalize_material_analysis_operation_internal(uuid,uuid,text) from public,anon,authenticated',
      ),
    );
    expect(
      terminalReconciliationMigration,
      contains(
        'grant execute on function public.terminalize_material_analysis_operation_internal(uuid,uuid,text) to service_role',
      ),
    );
    expect(
      terminalReconciliationMigration,
      isNot(
        contains(
          'grant execute on function public.terminalize_material_analysis_operation_internal(uuid,uuid,text) to authenticated',
        ),
      ),
    );
  });

  test('recovery fingerprint claim remains service-role-only', () {
    expect(
      recoveryFingerprintMigration,
      contains(
        'revoke all on function public.claim_next_material_analysis_operation_internal(uuid) from public,anon,authenticated',
      ),
    );
    expect(
      recoveryFingerprintMigration,
      contains(
        'grant execute on function public.claim_next_material_analysis_operation_internal(uuid) to service_role',
      ),
    );
    expect(
      recoveryFingerprintMigration,
      isNot(
        contains(
          'grant execute on function public.claim_next_material_analysis_operation_internal(uuid) to authenticated',
        ),
      ),
    );
  });

  test('no-work terminalization claim remains service-role-only', () {
    expect(
      noWorkTerminalizationMigration,
      contains(
        'revoke all on function public.claim_next_material_analysis_operation_internal(uuid) from public,anon,authenticated',
      ),
    );
    expect(
      noWorkTerminalizationMigration,
      contains(
        'grant execute on function public.claim_next_material_analysis_operation_internal(uuid) to service_role',
      ),
    );
    expect(
      noWorkTerminalizationMigration,
      isNot(
        contains(
          'grant execute on function public.claim_next_material_analysis_operation_internal(uuid) to authenticated',
        ),
      ),
    );
  });

  test('service role receives exact trusted PostgREST writes', () {
    expect(migration, contains('grant usage on schema public to service_role'));
    expect(
      migration,
      contains('grant select on table public.materials to service_role'),
    );
    expect(
      migration,
      contains(
        'grant update (summary, content_text, processing_status, metadata) on table public.materials to service_role',
      ),
    );
    expect(
      migration,
      contains('grant select on table public.flashcards to service_role'),
    );
    expect(migration, contains('on table public.flashcards to service_role'));
    expect(
      migration,
      contains('grant select on table public.quizzes to service_role'),
    );
    expect(migration, contains('on table public.quizzes to service_role'));
    expect(
      migration,
      contains('grant delete on table public.quizzes to service_role'),
    );
    expect(
      migration,
      contains('grant select on table public.quiz_questions to service_role'),
    );
    expect(
      migration,
      contains('on table public.quiz_questions to service_role'),
    );
  });

  test('trusted grants are column-scoped and never broad/default grants', () {
    expect(migration, isNot(contains('grant all')));
    expect(migration, isNot(contains('all tables')));
    expect(migration, isNot(contains('default privileges')));
    expect(migration, isNot(contains('all sequences')));
    expect(migration, isNot(contains('grant insert on table')));
    expect(
      migration,
      isNot(contains('subject_deletion_operations to service_role')),
    );
    expect(
      migration,
      isNot(contains('account_deletion_operations to service_role')),
    );
  });

  test('clients receive no generated write or trusted helper authority', () {
    for (final table in ['flashcards', 'quizzes', 'quiz_questions']) {
      expect(
        migration,
        isNot(contains('on table public.$table to authenticated')),
      );
      expect(migration, isNot(contains('on table public.$table to anon')));
    }
    for (final helper in [
      'begin_material_deletion_internal',
      'mark_material_storage_cleanup_internal',
      'finalize_material_deletion_internal',
      'begin_subject_deletion_internal',
      'mark_subject_deletion_internal',
      'finalize_subject_deletion_internal',
      'begin_account_deletion_internal',
      'mark_account_deletion_internal',
    ]) {
      expect(migration, contains('function public.$helper'));
    }
    expect(migration, contains('from public, anon, authenticated'));
    expect(migration, isNot(contains('to authenticated;')));
    expect(migration, isNot(contains('to anon;')));
  });

  test('RLS is retained for trusted-write and operation tables', () {
    for (final table in [
      'materials',
      'flashcards',
      'quizzes',
      'quiz_questions',
      'subject_deletion_operations',
      'account_deletion_operations',
    ]) {
      expect(
        migration,
        contains('alter table public.$table enable row level security'),
      );
    }
  });

  test('function sources match the migration privilege matrix', () async {
    final summary = await File(
      'supabase/functions/generate-summary/index.ts',
    ).readAsString();
    final flashcards = await File(
      'supabase/functions/generate-flashcards/index.ts',
    ).readAsString();
    final quiz = await File(
      'supabase/functions/generate-quiz/index.ts',
    ).readAsString();

    expect(summary, contains('.update({ summary: input.summary })'));
    expect(flashcards, contains('.from("flashcards")'));
    expect(flashcards, contains('complete_flashcard_generation_internal'));
    final phaseA = await File(
      'supabase/migrations/025_study_generation_source_flashcards.sql',
    ).readAsString();
    expect(phaseA, contains('insert into public.flashcards'));
    expect(quiz, contains('.from("quizzes")'));
    expect(quiz, contains('.from("quiz_questions")'));
    expect(quiz, contains('.delete()'));
  });

  test('temporary diagnostic selector is no-argument and fail-closed', () {
    expect(
      diagnosticSelectorMigration,
      contains('select_material_analysis_diagnostic_target_internal()'),
    );
    expect(
      diagnosticSelectorMigration,
      contains("coalesce(pg_catalog.cardinality(v_targets), 0) <> 1"),
    );
    for (final invariant in [
      "b.operation = 'final_summary'",
      "b.status = 'failed'",
      "b.failure_code = 'non_retryable'",
      "j.page_count = 1",
      "j.processing_mode = 'recommended'",
      "page.route = 'visual'",
      "reduction.operation = 'reduction'",
      "visual.operation = 'page_visual'",
      "b.cleanup_state = 'not_required'",
      'b.diagnostic_code is null',
      "count(*)",
      ') = 3',
    ]) {
      expect(diagnosticSelectorMigration, contains(invariant));
    }
    expect(
      diagnosticSelectorMigration,
      contains('grant execute on function %s to service_role'),
    );
    expect(
      diagnosticSelectorMigration,
      isNot(contains('page.active_batch_id')),
    );
    expect(
      diagnosticSelectorMigration,
      contains('from public, anon, authenticated, service_role'),
    );
    expect(
      diagnosticSelectorMigration,
      contains('material_analysis_diagnostic_correlations'),
    );
    expect(
      diagnosticSelectorMigration,
      contains(
        "new.source_hash <> '9c4df300f7bff18e8522322f3973b36bdc3186122af01ffdbc5852669b40f46a'",
      ),
    );
    expect(diagnosticSelectorMigration, isNot(contains('m.title')));
    expect(diagnosticSelectorMigration, isNot(contains('domain_profile')));
    expect(diagnosticSelectorMigration, isNot(contains('p_batch_id uuid')));
    for (final relationKey in [
      'visual_attempt.job_id = b.job_id',
      'visual_attempt.material_id = b.material_id',
      'visual_attempt.user_id = b.user_id',
      'reduction_attempt.job_id = b.job_id',
      'reduction_attempt.material_id = b.material_id',
      'reduction_attempt.user_id = b.user_id',
      'final_attempt.job_id = b.job_id',
      'final_attempt.material_id = b.material_id',
      'final_attempt.user_id = b.user_id',
    ]) {
      expect(diagnosticSelectorMigration, contains(relationKey));
    }
  });

  test('temporary correlation table is inaccessible to user roles', () {
    expect(
      diagnosticSelectorMigration,
      contains(
        'revoke all on table public.material_analysis_diagnostic_correlations from public, anon, authenticated, service_role',
      ),
    );
    expect(diagnosticSelectorMigration, contains('enable row level security'));
    expect(diagnosticSelectorMigration, contains('force row level security'));
    expect(
      diagnosticSelectorMigration,
      isNot(contains('grant insert on table')),
    );
    expect(
      diagnosticSelectorMigration,
      isNot(contains('grant update on table')),
    );
  });

  test('cleanup migration removes all temporary capabilities', () {
    for (final capability in [
      'attach_material_analysis_diagnostic_final_batch',
      'attach_material_analysis_diagnostic_job',
      'record_correlated_material_analysis_diagnostic_internal',
      'select_material_analysis_diagnostic_target_internal',
      'attach_material_analysis_diagnostic_final_batch_internal',
      'attach_material_analysis_diagnostic_job_internal',
      'material_analysis_diagnostic_correlations',
    ]) {
      expect(diagnosticCleanupMigration, contains(capability));
    }
    expect(diagnosticCleanupMigration, contains('drop trigger if exists'));
    expect(diagnosticCleanupMigration, contains('drop function if exists'));
    expect(diagnosticCleanupMigration, contains('drop table if exists'));
  });
}

String _normalize(String value) => value
    .replaceAll(RegExp(r'--[^\n]*'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();
