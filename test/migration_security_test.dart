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
}
