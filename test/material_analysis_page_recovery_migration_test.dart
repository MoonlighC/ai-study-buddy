import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/033_material_analysis_bounded_page_recovery.sql',
  ).readAsStringSync().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final lifecycle = File(
    'supabase/tests/phase_c_page_recovery_pass.sql',
  ).readAsStringSync().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  test('recovery is terminal-page-only, bounded, and individually durable', () {
    expect(
      migration,
      contains("page.status='missing' or ( page.status='partial'"),
    );
    expect(
      migration,
      contains("(page.result_payload->>'confidence')::numeric<0.5"),
    );
    expect(
      migration,
      contains('create table public.material_processing_page_recoveries'),
    );
    expect(migration, contains('unique(job_id,page_number)'));
    expect(migration, contains('batch_id uuid not null unique'));
    expect(migration, contains('array[v_page.page_number]'));
    expect(migration, contains('array[v_page.page_number],v_fingerprint,1'));
    expect(migration, contains("page.recovery_attempts=0"));
    expect(migration, contains("and material.kind='pdf'"));
    expect(migration, isNot(contains("page.status='completed' or")));
    expect(
      migration,
      isNot(contains("set status='batched', active_batch_id=v_batch_id")),
    );
  });

  test(
    'source existence, blank-page, and ambiguity gates remain fail closed',
    () {
      expect(
        migration,
        contains("page.routing_signals->'source_render_exists'='true'::jsonb"),
      );
      expect(migration, contains("blank_page_conclusive"));
      expect(
        migration,
        contains(
          'from public.material_processing_page_recoveries prior where prior.job_id=page.job_id',
        ),
      );
      expect(migration, contains('page_recovery_provenance_conflict'));
      expect(migration, contains('page_recovery_completion_conflict'));
    },
  );

  test('recovery identity and database authority remain fixed', () {
    expect(migration, contains(':post-page-recovery-v1:'));
    expect(migration, contains('on conflict (job_id,fingerprint) do nothing'));
    expect(migration, contains('terminal_page_recovery_immutable'));
    expect(
      migration,
      contains('create view public.material_processing_effective_pages'),
    );
    expect(migration, contains('security definer'));
    expect(migration, contains('set search_path = pg_catalog, public'));
    expect(
      migration,
      contains(
        'alter function public.prepare_material_analysis_page_recoveries_internal(uuid) owner to postgres',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.prepare_material_analysis_page_recoveries_internal(uuid) to service_role',
      ),
    );
  });

  test('lifecycle fixture proves recovered manifest and duplicate bounds', () {
    expect(
      lifecycle,
      contains("'reduction uses the recovered authoritative manifest'"),
    );
    expect(
      lifecycle,
      contains(
        "'final summary receives recovered pages in the correct categories'",
      ),
    );
    expect(lifecycle, contains('count(distinct idempotency_key)=4'));
    expect(lifecycle, contains('attempt_count>1'));
    expect(
      lifecycle,
      contains("'relaunch does not duplicate recovery batches'"),
    );
    expect(
      lifecycle,
      contains("'initial terminal page rows remain byte-for-byte immutable'"),
    );
    expect(
      lifecycle,
      contains("'a stale request cannot overwrite a terminal recovery result'"),
    );
  });
}
