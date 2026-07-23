import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/030_study_generation_response_reconciliation.sql',
  ).readAsStringSync();
  final flashcards = File(
    'supabase/functions/generate-flashcards/index.ts',
  ).readAsStringSync();
  final quiz = File(
    'supabase/functions/generate-quiz/index.ts',
  ).readAsStringSync();
  final shared = File(
    'supabase/functions/_shared/study_generation_reconciliation.ts',
  ).readAsStringSync();

  test(
    'migration 030 is forward-only and keeps provider identity service-only',
    () {
      expect(migration, contains('add column provider_response_identity text'));
      expect(migration, contains('add column reconciliation_token uuid'));
      expect(
        migration,
        contains(
          'revoke all on table public.study_generation_operations\n'
          'from public, anon, authenticated',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.get_my_usage_status()\n'
          'to authenticated',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.set_unlimited_tester(uuid, boolean)\n'
          'to service_role',
        ),
      );
      expect(
        migration,
        contains('revoke update(is_unlimited_tester) on table public.profiles'),
      );
      expect(migration, isNot(contains('service_role_key')));
      expect(migration, isNot(contains('email like')));
    },
  );

  test('generation bundles use one POST path and GET-only reconciliation', () {
    for (final source in [flashcards, quiz]) {
      expect(
        RegExp(r'providerRequest\(\s*"POST"').allMatches(source),
        hasLength(1),
      );
      expect(
        RegExp(r'providerRequest\(\s*"GET"').allMatches(source),
        hasLength(1),
      );
      expect(source, contains('executeStudyGeneration'));
      expect(source, contains('record_study_generation_response_internal'));
      expect(
        source,
        contains('claim_study_generation_reconciliation_internal'),
      );
    }
    expect(shared, contains('reconcileStudyGeneration'));
    expect(
      RegExp(r'await deps\.submitProvider\(\)').allMatches(shared),
      hasLength(1),
    );
  });

  test('tester bypass is trusted and per-request maximum remains enforced', () {
    expect(
      migration,
      contains('select coalesce(p.is_unlimited_tester, false)'),
    );
    expect(migration, contains('p_quantity < 1 or p_quantity > 30'));
    expect(migration, contains('if not v_unlimited and p_feature'));
    expect(
      migration,
      contains(
        "'account_policy',\n"
        "      case when v_unlimited then 'unlimited_tester'",
      ),
    );
  });
}
