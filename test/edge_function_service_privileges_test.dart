import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() async {
    migration = _normalize(
      await File(
        'supabase/migrations/009_edge_function_service_privileges.sql',
      ).readAsString(),
    );
  });

  test('service role receives exact trusted PostgREST writes', () {
    expect(migration, contains('grant usage on schema public to service_role'));
    expect(migration, contains('grant select on table public.materials to service_role'));
    expect(
      migration,
      contains(
        'grant update (summary, content_text, processing_status, metadata) on table public.materials to service_role',
      ),
    );
    expect(migration, contains('grant select on table public.flashcards to service_role'));
    expect(migration, contains('on table public.flashcards to service_role'));
    expect(migration, contains('grant select on table public.quizzes to service_role'));
    expect(migration, contains('on table public.quizzes to service_role'));
    expect(migration, contains('grant delete on table public.quizzes to service_role'));
    expect(migration, contains('grant select on table public.quiz_questions to service_role'));
    expect(migration, contains('on table public.quiz_questions to service_role'));
  });

  test('trusted grants are column-scoped and never broad/default grants', () {
    expect(migration, isNot(contains('grant all')));
    expect(migration, isNot(contains('all tables')));
    expect(migration, isNot(contains('default privileges')));
    expect(migration, isNot(contains('all sequences')));
    expect(migration, isNot(contains('grant insert on table')));
    expect(migration, isNot(contains('subject_deletion_operations to service_role')));
    expect(migration, isNot(contains('account_deletion_operations to service_role')));
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

    expect(summary, contains('.update({ summary })'));
    expect(flashcards, contains('.from("flashcards")'));
    expect(flashcards, contains('.insert(rows)'));
    expect(quiz, contains('.from("quizzes")'));
    expect(quiz, contains('.from("quiz_questions")'));
    expect(quiz, contains('.delete()'));
  });
}

String _normalize(String value) => value
    .replaceAll(RegExp(r'--[^\n]*'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();
