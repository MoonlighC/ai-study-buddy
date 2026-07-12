import 'package:ai_study_buddy/features/generation/generation_function_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  test('classifies FunctionException statuses and known safe details', () {
    expect(classify(401).code, GenerationFailureCode.authenticationRequired);
    expect(classify(404).code, GenerationFailureCode.materialUnavailable);
    expect(classify(429).code, GenerationFailureCode.aiRateOrQuota);
    expect(
      classify(500, {'code': 'openai_auth_failed'}).code,
      GenerationFailureCode.openAiAuthFailed,
    );
    expect(
      classify(500, {'error': 'response_parse_failed'}).code,
      GenerationFailureCode.responseParseFailed,
    );
  });

  test(
    'malformed and raw backend details use generic localized-safe message',
    () {
      for (final details in [
        null,
        'raw provider body',
        {'error': 'SQL: secret'},
        {'code': 'x' * 100},
      ]) {
        final failure = classify(500, details);
        expect(failure.code, GenerationFailureCode.generic);
        expect(failure.message, 'Could not generate summary. Try again.');
        expect(failure.message, isNot(contains('secret')));
      }
    },
  );
}

GenerationFunctionFailure classify(int status, [Object? details]) =>
    classifyGenerationFunctionException(
      'generate-summary',
      supabase.FunctionException(status: status, details: details),
      'Could not generate summary. Try again.',
    );
