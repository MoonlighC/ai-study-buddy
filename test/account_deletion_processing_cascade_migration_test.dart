import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() async {
    migration = (await File(
      'supabase/migrations/019_account_deletion_processing_cascade.sql',
    ).readAsString()).toLowerCase();
  });

  test('delete cascades do not refresh a processing job being deleted', () {
    expect(migration, contains("if tg_op = 'delete' then"));
    expect(migration, contains('return old;'));
    expect(migration, contains('where id = new.job_id'));
  });

  test('migration preserves processing privilege boundaries', () {
    expect(migration, contains("alter function %s owner to postgres"));
    expect(
      migration,
      contains(
        'revoke all on function %s from public, anon, authenticated, service_role',
      ),
    );
    expect(migration, isNot(contains('grant ')));
    expect(migration, isNot(contains('security definer')));
    expect(migration, isNot(contains('alter table')));
  });
}
