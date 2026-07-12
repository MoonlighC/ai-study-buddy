import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

enum GenerationFailureCode {
  authenticationRequired,
  materialUnavailable,
  aiRateOrQuota,
  openAiAuthFailed,
  openAiAccessDenied,
  openAiRequestInvalid,
  openAiUnavailable,
  responseParseFailed,
  databaseWriteFailed,
  generic,
}

class GenerationFunctionFailure {
  const GenerationFunctionFailure(this.code, this.message);
  final GenerationFailureCode code;
  final String message;
}

GenerationFunctionFailure classifyGenerationFunctionException(
  String functionName,
  supabase.FunctionException exception,
  String genericMessage,
) {
  final safeCode = _safeDetailCode(exception.details);
  final code = switch (exception.status) {
    401 => GenerationFailureCode.authenticationRequired,
    404 => GenerationFailureCode.materialUnavailable,
    429 => GenerationFailureCode.aiRateOrQuota,
    500 => _knownServerCode(safeCode),
    _ => GenerationFailureCode.generic,
  };
  if (kDebugMode) {
    debugPrint(
      '$functionName status=${exception.status} code=${safeCode ?? 'unknown'}',
    );
  }
  final message = switch (code) {
    GenerationFailureCode.materialUnavailable => 'Material unavailable.',
    _ => genericMessage,
  };
  return GenerationFunctionFailure(code, message);
}

String? _safeDetailCode(Object? details) {
  if (details is! Map) return null;
  for (final key in const ['code', 'error']) {
    final value = details[key];
    if (value is String) {
      final bounded = value.trim();
      if (bounded.length <= 64 && RegExp(r'^[a-z0-9_]+$').hasMatch(bounded)) {
        return bounded;
      }
    }
  }
  return null;
}

GenerationFailureCode _knownServerCode(String? code) => switch (code) {
  'openai_auth_failed' => GenerationFailureCode.openAiAuthFailed,
  'openai_access_denied' => GenerationFailureCode.openAiAccessDenied,
  'openai_request_invalid' => GenerationFailureCode.openAiRequestInvalid,
  'openai_rate_or_quota' => GenerationFailureCode.aiRateOrQuota,
  'openai_unavailable' => GenerationFailureCode.openAiUnavailable,
  'response_parse_failed' => GenerationFailureCode.responseParseFailed,
  'database_write_failed' ||
  'flashcard_insert_failed' ||
  'quiz_insert_failed' ||
  'quiz_questions_insert_failed' ||
  'material_update_failed' => GenerationFailureCode.databaseWriteFailed,
  _ => GenerationFailureCode.generic,
};
