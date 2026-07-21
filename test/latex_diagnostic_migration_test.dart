import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String diagnostic, cleanup;

  setUpAll(() async {
    diagnostic = (await File(
      'supabase/migrations/022_material_analysis_latex_diagnostic.sql',
    ).readAsString()).toLowerCase();
    cleanup = (await File(
      'supabase/migrations/023_material_analysis_latex_diagnostic_cleanup.sql',
    ).readAsString()).toLowerCase();
  });

  test('selector is no-argument exact-target and one-shot', () {
    expect(
      diagnostic,
      contains('claim_material_analysis_latex_diagnostic_internal()'),
    );
    expect(diagnostic, contains("extensions.digest(b.id::text,'sha256')"));
    expect(diagnostic, contains('where singleton and claimed_at is null'));
    expect(diagnostic, contains('latex_diagnostic_unavailable'));
    expect(diagnostic, isNot(contains('p_batch_id')));
    expect(diagnostic, isNot(contains('p_material_id')));
    expect(diagnostic, isNot(contains('p_user_id')));
  });

  test('diagnostic data and privileges are content-free and service-only', () {
    for (final forbidden in [
      'summary_text',
      'latex_value',
      'document_content',
      'storage_path',
      'response_id uuid',
    ]) {
      expect(diagnostic, isNot(contains(forbidden)));
    }
    expect(
      diagnostic,
      contains(
        'revoke all on table public.material_analysis_latex_diagnostics',
      ),
    );
    expect(
      diagnostic,
      contains('from public, anon, authenticated, service_role'),
    );
    expect(
      diagnostic,
      contains(
        'grant select on table public.material_analysis_latex_diagnostics to service_role',
      ),
    );
    expect(diagnostic, contains('security definer'));
    expect(diagnostic, contains('set search_path = pg_catalog, public'));
  });

  test('cleanup removes every temporary object and no normal state', () {
    for (final object in [
      'material_analysis_latex_diagnostics',
      'record_material_analysis_latex_diagnostic_internal',
      'claim_material_analysis_latex_diagnostic_internal',
      'material_analysis_latex_diagnostic_valid',
    ]) {
      expect(cleanup, contains('drop'));
      expect(cleanup, contains(object));
    }
    expect(cleanup, isNot(contains('material_processing_jobs')));
    expect(cleanup, isNot(contains('material_processing_batches')));
    expect(cleanup, isNot(contains('materials')));
  });
}
