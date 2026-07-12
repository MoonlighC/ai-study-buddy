import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 12.1 deletion migration', () {
    late String migration;
    setUpAll(
      () => migration = File(
        'supabase/migrations/007_subject_account_deletion.sql',
      ).readAsStringSync().toLowerCase(),
    );
    test('operation state is RLS protected and service-only', () {
      expect(
        migration,
        contains('create table public.subject_deletion_operations'),
      );
      expect(
        migration,
        contains('create table public.account_deletion_operations'),
      );
      expect(migration, contains('enable row level security'));
      expect(
        migration,
        contains(
          'revoke all on public.subject_deletion_operations from public, anon, authenticated',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.begin_account_deletion_internal(uuid) to service_role',
        ),
      );
    });
    test('protects lifecycle fields and uses fixed definer search paths', () {
      expect(
        migration,
        contains('revoke update on public.subjects from authenticated'),
      );
      expect(
        migration,
        contains(
          'grant update (name, description, color_value, icon_name, sort_order)',
        ),
      );
      expect(
        RegExp(
          r'security definer set search_path = pg_catalog, public',
        ).allMatches(migration).length,
        greaterThanOrEqualTo(5),
      );
    });
    test(
      'has idempotency, bounded counters, stale indexes, and auth cascade',
      () {
        expect(migration, contains('unique (user_id, subject_id)'));
        expect(
          migration,
          contains(
            'user_id uuid not null unique references auth.users(id) on delete cascade',
          ),
        );
        expect(migration, contains('objects_found between 0 and 1000000'));
        expect(migration, contains('subject_deletion_operations_stale_idx'));
        expect(migration, contains('account_deletion_operations_stale_idx'));
      },
    );
  });
  test('material processing migration revokes update only', () async {
    final migration = await File(
      'supabase/migrations/005_material_processing_authority.sql',
    ).readAsString();
    final normalized = migration.toLowerCase();
    expect(normalized, contains('revoke update on table public.materials'));
    expect(normalized, contains('from public, anon, authenticated'));
    expect(
      normalized,
      contains('drop policy if exists "users can update own materials"'),
    );
    expect(normalized, isNot(contains('revoke select')));
    expect(normalized, isNot(contains('revoke insert')));
    expect(normalized, isNot(contains('revoke delete')));
  });

  test('service role credential is absent from Flutter source', () async {
    final files = Directory('lib').listSync(recursive: true).whereType<File>();
    for (final file in files) {
      expect(
        await file.readAsString(),
        isNot(contains('SUPABASE_SERVICE_ROLE_KEY')),
      );
    }
  });

  test('AI functions accept only manual text or ready uploaded PDF', () async {
    for (final paths in [
      ['supabase/functions/generate-summary/index.ts'],
      [
        'supabase/functions/generate-flashcards/index.ts',
        'supabase/functions/generate-flashcards/handler.ts',
      ],
      ['supabase/functions/generate-quiz/index.ts'],
    ]) {
      final source = (await Future.wait(
        paths.map((path) => File(path).readAsString()),
      )).join('\n');
      expect(source, contains('material.kind === "pasted_text"'));
      expect(source, contains('material.source_kind === "manual"'));
      expect(source, contains('material.kind === "pdf"'));
      expect(source, contains('material.source_kind === "upload"'));
      expect(source, contains('material.processing_status === "ready"'));
    }
    final summary = await File(
      'supabase/functions/generate-summary/index.ts',
    ).readAsString();
    expect(summary, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(summary, contains('.update({ summary })'));
    expect(summary, contains('.select("id")'));
    expect(summary, contains('updatedMaterials.length !== 1'));
    expect(summary, isNot(contains('processing_status: "processing"')));
    expect(summary, isNot(contains('processing_status: "failed"')));
    expect(summary, isNot(contains('.update({ content_text')));
  });

  test('PDF summaries use expanded source-aware instructions', () async {
    final source = await File(
      'supabase/functions/generate-summary/summary_prompt.ts',
    ).readAsString();

    expect(source, contains('conciseSummaryOutputTokens = 220'));
    expect(source, contains('pdfStudySummaryOutputTokens = 1_400'));
    expect(source, contains('4 to 6 sentences'));
    expect(source, contains('roughly 400 to 700 words'));
    expect(source, contains('Important formulas or relationships'));
    expect(source, contains('Do not reconstruct unreadable formulas'));
    expect(source, contains('Preserve the language of the material'));
    expect(source, contains('supplied portion of extracted PDF or image text'));
    expect(source, contains('Do not reconstruct unreadable formulas'));
    expect(source, contains('missing diagram content'));
  });

  test('quiz attempt RPC is the only authenticated mutation path', () async {
    final migration = await File(
      'supabase/migrations/003_quiz_attempt_weak_topics_rpc.sql',
    ).readAsString();
    final normalized = migration.toLowerCase();

    expect(normalized, contains('security definer'));
    expect(normalized, isNot(contains('security invoker')));
    expect(normalized, contains('owner to postgres'));
    expect(normalized, isNot(contains('p_completed_at')));
    expect(
      normalized,
      contains('revoke insert, update, delete on table public.quiz_attempts'),
    );
    expect(
      normalized,
      contains('revoke insert, update, delete on table public.weak_topics'),
    );
    expect(
      normalized,
      contains('grant select on table public.quiz_attempts to authenticated'),
    );
    expect(
      normalized,
      contains('grant select on table public.weak_topics to authenticated'),
    );
    expect(
      normalized,
      contains('revoke insert, update, delete on table public.quizzes'),
    );
    expect(
      normalized,
      contains('revoke insert, update, delete on table public.quiz_questions'),
    );
    expect(
      normalized,
      contains('grant select on table public.quizzes to authenticated'),
    );
    expect(
      normalized,
      contains('grant select on table public.quiz_questions to authenticated'),
    );
    expect(normalized, contains("interval '24 hours'"));
    expect(normalized, contains('question.options ?'));
    expect(
      normalized,
      isNot(contains('grant select, insert on table public.quiz_attempts')),
    );
    expect(
      normalized,
      isNot(
        contains('grant select, insert, update on table public.weak_topics'),
      ),
    );
  });

  test(
    'Flutter repositories expose RPC save and read-only weak topics',
    () async {
      final quizRepository = await File(
        'lib/features/quizzes/quiz_repository.dart',
      ).readAsString();
      final weakTopicRepository = await File(
        'lib/features/progress/weak_topic_repository.dart',
      ).readAsString();

      expect(quizRepository, contains("'save_quiz_attempt_with_weak_topics'"));
      expect(
        RegExp(
          r"from\('quiz_attempts'\)[\s\S]{0,160}\.insert\(",
        ).hasMatch(quizRepository),
        isFalse,
      );
      for (final table in ['quizzes', 'quiz_questions']) {
        expect(
          RegExp(
            "from\\('$table'\\)[\\s\\S]{0,180}\\.(insert|update|delete)\\(",
          ).hasMatch(quizRepository),
          isFalse,
        );
      }
      expect(weakTopicRepository, isNot(contains('.insert(')));
      expect(weakTopicRepository, isNot(contains('.update(')));
      expect(weakTopicRepository, isNot(contains('.delete(')));
    },
  );

  test('quiz generation writes only through its trusted server client', () async {
    final edgeFunction = await File(
      'supabase/functions/generate-quiz/index.ts',
    ).readAsString();

    expect(edgeFunction, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(edgeFunction, contains('materialOwnerId !== user.id'));
    expect(edgeFunction, contains('const trustedWriteClient = createClient'));
    expect(
      RegExp(
        r'trustedWriteClient[\s\S]{0,120}\.from\("quizzes"\)[\s\S]{0,80}\.insert\(',
      ).hasMatch(edgeFunction),
      isTrue,
    );
    expect(
      RegExp(
        r'trustedWriteClient[\s\S]{0,160}\.from\("quiz_questions"\)[\s\S]{0,80}\.insert\(',
      ).hasMatch(edgeFunction),
      isTrue,
    );
    expect(edgeFunction, isNot(contains('service_role_key_value')));
  });

  test(
    'material upload migration keeps buckets private and user-owned',
    () async {
      final migration = await File(
        'supabase/migrations/004_material_upload_storage.sql',
      ).readAsString();
      final normalized = migration.toLowerCase();

      expect(normalized, contains("id = 'study-materials'"));
      expect(normalized, contains("id = 'study-images'"));
      expect(normalized, isNot(contains('insert into storage.buckets')));
      expect(normalized, isNot(contains('delete from storage.buckets')));
      expect(normalized, contains('set public = false'));
      expect(normalized, contains('file_size_limit = 10485760'));
      expect(normalized, contains('file_size_limit = 8388608'));
      expect(normalized, contains('drop policy if exists'));
      expect(normalized, contains('on storage.objects for insert'));
      expect(normalized, contains('on storage.objects for select'));
      expect(normalized, contains('on storage.objects for delete'));
      expect(normalized, isNot(contains('on storage.objects for update')));
      expect(
        normalized,
        contains("(storage.foldername(name))[1] = (select auth.uid())::text"),
      );
      expect(
        'coalesce(array_length(storage.foldername(name), 1), 0) = 2'
            .allMatches(normalized)
            .length,
        3,
      );
      const uuidPathCheck =
          r"(storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'";
      expect(uuidPathCheck.allMatches(normalized).length, 3);
      expect(
        "btrim(storage.filename(name)) <> ''".allMatches(normalized).length,
        3,
      );
      expect(normalized, contains('constraint materials_upload_shape'));
      expect(normalized, contains("source_kind <> 'upload'"));
      expect(normalized, contains('content_text is null'));
      expect(normalized, contains('summary is null'));
      expect(normalized, contains("processing_status = 'pending'"));
      expect(normalized, contains('user_id = (select auth.uid())'));
      expect(
        normalized,
        contains("split_part(storage_path, '/', 2) = id::text"),
      );
    },
  );

  test('Phase 9D lifecycle migration is narrowly authorized', () async {
    final source = await File(
      'supabase/migrations/006_material_lifecycle.sql',
    ).readAsString();
    final normalized = source.toLowerCase();
    expect(normalized, contains('revoke delete on table public.materials'));
    expect(normalized, contains('from public, anon, authenticated'));
    expect(
      normalized,
      contains('drop policy if exists "users can delete own materials"'),
    );
    expect(
      normalized,
      isNot(contains('grant update on table public.materials')),
    );
    expect(
      normalized,
      isNot(contains('grant delete on table public.materials')),
    );
    for (final function in [
      'begin_material_deletion_internal',
      'mark_material_storage_cleanup_internal',
      'finalize_material_deletion_internal',
      'inspect_material_recovery',
      'recover_stale_material',
    ]) {
      expect(normalized, contains('function public.$function'));
    }
    expect(
      'security definer'.allMatches(normalized).length,
      greaterThanOrEqualTo(5),
    );
    expect(
      'set search_path = pg_catalog, public'.allMatches(normalized).length,
      greaterThanOrEqualTo(5),
    );
    expect(normalized, contains('auth.uid()'));
    expect(normalized, contains("interval '15 minutes'"));
    for (final signature in [
      'begin_material_deletion_internal(uuid, uuid)',
      'mark_material_storage_cleanup_internal(uuid, uuid, text, text)',
      'finalize_material_deletion_internal(uuid, uuid)',
    ]) {
      expect(
        normalized,
        contains(
          'revoke all on function public.$signature from public, anon, authenticated',
        ),
      );
      expect(
        normalized,
        contains('grant execute on function public.$signature to service_role'),
      );
      expect(
        normalized,
        isNot(
          contains(
            'grant execute on function public.$signature to authenticated',
          ),
        ),
      );
    }
    expect(
      normalized,
      contains('create policy "users can read own active materials"'),
    );
    expect(
      normalized,
      contains('user_id = (select auth.uid()) and deleted_at is null'),
    );
    expect(normalized, contains(r"~ '^[0-9]+$'"));
    expect(normalized, contains('p_user_id uuid'));
    expect(normalized, contains('user_id = p_user_id'));
    expect(normalized, isNot(contains('execute immediate')));
  });

  test(
    'delete-material verifies JWT before service-role coordination',
    () async {
      final source = await File(
        'supabase/functions/delete-material/index.ts',
      ).readAsString();
      expect(source, contains(r'Authorization: `Bearer ${jwt}`'));
      expect(source, contains('SUPABASE_ANON_KEY'));
      expect(source, contains('SUPABASE_SERVICE_ROLE_KEY'));
      expect(source, contains('if (userId) trustedClient = createClient'));
      expect(source, contains('begin_material_deletion_internal'));
      expect(source, contains('mark_material_storage_cleanup_internal'));
      expect(source, contains('finalize_material_deletion_internal'));
      expect(source, contains('p_user_id: userId'));
    },
  );

  test('storage policy preflight covers unknown permissive policies', () async {
    for (final migrationName in [
      '001_initial_schema.sql',
      '002_subject_color_value_bigint.sql',
      '003_quiz_attempt_weak_topics_rpc.sql',
    ]) {
      final earlierMigration = await File(
        'supabase/migrations/$migrationName',
      ).readAsString();
      expect(
        earlierMigration.toLowerCase(),
        isNot(contains('on storage.objects')),
      );
    }

    final setup = (await File(
      'supabase/README.md',
    ).readAsString()).toLowerCase();
    expect(setup, contains('from pg_policies'));
    expect(setup, contains("schemaname = 'storage'"));
    expect(setup, contains("tablename = 'objects'"));
    expect(setup, contains('permissive rls policies combine with `or`'));
    expect(setup, contains('drop it by its exact policy name'));
    expect(setup, contains('do not blindly'));
  });
}
