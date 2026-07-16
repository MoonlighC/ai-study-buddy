import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() async {
    migration = (await File(
      'supabase/migrations/010_material_analysis_processing.sql',
    ).readAsString()).toLowerCase();
  });

  test('migration is additive and preserves legacy material metadata', () {
    expect(
      migration,
      contains('add column if not exists summary_payload jsonb'),
    );
    expect(migration, contains('summary_schema_version integer'));
    expect(migration, contains('summary_processing_mode text'));
    expect(migration, isNot(contains('drop column')));
    expect(migration, isNot(contains("metadata = '{}'")));
    expect(migration, isNot(contains('delete from public.materials')));
    expect(migration, isNot(contains('update public.materials set metadata')));
  });

  test('processing tables use composite ownership and deletion cascades', () {
    for (final table in [
      'material_processing_jobs',
      'material_processing_pages',
      'material_processing_batches',
      'material_processing_attempts',
      'material_processing_retry_authorizations',
    ]) {
      expect(migration, contains('create table public.$table'));
      expect(
        migration,
        contains('alter table public.$table enable row level security'),
      );
      expect(
        migration,
        contains('alter table public.$table force row level security'),
      );
      expect(
        migration,
        contains(
          'revoke all on table public.$table from public, anon, authenticated, service_role',
        ),
      );
    }
    expect(
      RegExp(
        r'foreign key \([^)]*user_id[^)]*\)[\s\S]{0,100}on delete cascade',
      ).allMatches(migration).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('clients cannot write trusted processing state', () {
    expect(
      migration,
      isNot(
        contains(
          'grant insert on table public.material_processing_jobs to authenticated',
        ),
      ),
    );
    expect(
      migration,
      isNot(
        contains(
          'grant update on table public.material_processing_pages to authenticated',
        ),
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.get_material_analysis_status(uuid) to authenticated',
      ),
    );
    expect(migration, contains('m.user_id=auth.uid()'));
  });

  test('C1 and C2 internal RPCs are service-only', () {
    for (final function in [
      'create_material_processing_job_internal',
      'claim_material_processing_batch_internal',
      'mark_material_processing_batch_submitted_internal',
      'mark_material_processing_dispatch_unknown_internal',
      'mark_material_processing_response_known_internal',
      'complete_material_processing_batch_internal',
      'fail_material_processing_batch_internal',
      'recover_expired_material_processing_batch_internal',
      'request_material_processing_retry_internal',
      'finalize_material_processing_job_internal',
      'load_material_analysis_source_internal',
      'prepare_material_analysis_internal',
      'claim_next_material_analysis_operation_internal',
      'submit_material_analysis_operation_internal',
      'record_material_analysis_response_internal',
      'complete_material_analysis_operation_internal',
      'fail_material_analysis_operation_internal',
      'complete_material_analysis_cleanup_internal',
    ]) {
      expect(migration, contains('function public.$function'));
    }
    expect(
      migration,
      contains('p_material_id uuid,p_user_id uuid'),
      reason:
          'C2 receives only the server-derived verified principal internally',
    );
    expect(
      migration,
      contains('revoke all on function %s from public, anon, authenticated'),
    );
    expect(migration, contains('grant execute on function %s to service_role'));
  });

  test('definers and transition functions use fixed search paths', () {
    expect(
      RegExp(
        r'security definer[\s\S]{0,80}set search_path = pg_catalog, public',
      ).allMatches(migration).length,
      greaterThanOrEqualTo(11),
    );
    for (final trigger in ['job', 'page', 'batch']) {
      expect(migration, contains('enforce_material_processing_${trigger}_row'));
    }
    expect(migration, contains('terminal_batch_immutable'));
    expect(migration, contains('page_attempt_budget_exhausted'));
    expect(migration, contains('owner to material_analysis_executor'));
    expect(migration, contains('nologin nosuperuser noinherit nobypassrls'));
  });

  test(
    'batch checks enforce bounded text, visual, recovery, and reductions',
    () {
      expect(
        migration,
        contains(
          "operation = 'page_visual' and cardinality(page_numbers) <= 5",
        ),
      );
      expect(
        migration,
        contains("operation = 'page_recovery' and max_attempts = 1"),
      );
      expect(migration, contains('cardinality(p_pages) between 1 and 10'));
    },
  );

  test('batch claim persists a token and later mutations prove it', () {
    expect(migration, contains('v_token uuid := gen_random_uuid()'));
    expect(migration, contains('active_lease_token=v_token'));
    expect(migration, contains('b.lease_token=p_lease_token'));
    expect(migration, contains('j.active_lease_token=p_lease_token'));
    expect(
      migration,
      contains('active_lease_token=null,active_lease_expires_at=null'),
    );
  });

  test(
    'service role has RPC-only processing authority and attempts are durable',
    () {
      expect(
        migration,
        contains(
          'revoke all on table public.material_processing_attempts from public, anon, authenticated, service_role',
        ),
      );
      expect(migration, contains('predecessor_attempt_id uuid'));
      expect(migration, contains('idempotency_key text not null unique'));
      expect(migration, contains('authorize_material_analysis_retry'));
      expect(migration, contains('pg_advisory_xact_lock'));
      expect(migration, contains('generate_series(1,p_page_count)'));
    },
  );
}
