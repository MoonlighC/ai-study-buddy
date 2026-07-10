import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
