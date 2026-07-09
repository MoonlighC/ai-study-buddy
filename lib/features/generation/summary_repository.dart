import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../auth/auth_models.dart';

abstract class SummaryRepository {
  Future<String> generateSummary({
    required AuthUser user,
    required String materialId,
  });
}

class SummaryRepositoryException implements Exception {
  const SummaryRepositoryException(this.message);

  final String message;
}

const summaryTooShortMessage =
    'Add more lecture text before generating a summary.';

class MockSummaryRepository implements SummaryRepository {
  const MockSummaryRepository();

  @override
  Future<String> generateSummary({
    required AuthUser user,
    required String materialId,
  }) async {
    return 'Mock summary: this pasted material highlights the main idea, the key supporting detail, and one point to review next.';
  }
}

class SupabaseSummaryRepository implements SummaryRepository {
  const SupabaseSummaryRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<String> generateSummary({
    required AuthUser user,
    required String materialId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'generate-summary',
        body: <String, String>{'material_id': materialId},
      );
      final data = response.data;
      final summary = data['summary'];
      final error = data['error'];
      if (error == summaryTooShortMessage) {
        throw const SummaryRepositoryException(summaryTooShortMessage);
      }
      if (summary is! String || summary.trim().isEmpty) {
        throw const SummaryRepositoryException(
          'Could not generate summary. Try again.',
        );
      }
      return summary.trim();
    } on SummaryRepositoryException {
      rethrow;
    } catch (_) {
      throw const SummaryRepositoryException(
        'Could not generate summary. Try again.',
      );
    }
  }
}

class EmptySummaryRepository implements SummaryRepository {
  const EmptySummaryRepository();

  @override
  Future<String> generateSummary({
    required AuthUser user,
    required String materialId,
  }) async {
    throw const SummaryRepositoryException(
      'Summary generation is not configured.',
    );
  }
}
