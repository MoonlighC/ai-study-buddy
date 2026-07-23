import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../auth/auth_models.dart';

enum UsageAccountPolicy { standard, unlimitedTester }

class UsageStatus {
  const UsageStatus({
    required this.accountPolicy,
    required this.flashcardsUsedToday,
    required this.flashcardsDailyLimit,
    required this.quizQuestionsUsedToday,
    required this.quizQuestionsDailyLimit,
    required this.estimatedCostUsedToday,
    required this.estimatedCostDailyLimit,
    required this.activeReservations,
    required this.resetAt,
  });

  final UsageAccountPolicy accountPolicy;
  final int flashcardsUsedToday;
  final int? flashcardsDailyLimit;
  final int quizQuestionsUsedToday;
  final int? quizQuestionsDailyLimit;
  final double estimatedCostUsedToday;
  final double? estimatedCostDailyLimit;
  final int activeReservations;
  final DateTime resetAt;

  bool get isUnlimitedTester =>
      accountPolicy == UsageAccountPolicy.unlimitedTester;
}

abstract class UsageStatusRepository {
  Future<UsageStatus> loadUsageStatus(AuthUser user);
}

class SupabaseUsageStatusRepository implements UsageStatusRepository {
  const SupabaseUsageStatusRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<UsageStatus> loadUsageStatus(AuthUser user) async {
    try {
      final response = await _client.rpc('get_my_usage_status');
      final row = response is List && response.length == 1
          ? response.single
          : response;
      if (row is! Map) throw const UsageStatusRepositoryException();
      return _mapUsageStatus(Map<String, dynamic>.from(row));
    } catch (error) {
      if (error is UsageStatusRepositoryException) rethrow;
      throw const UsageStatusRepositoryException();
    }
  }

  UsageStatus _mapUsageStatus(Map<String, dynamic> row) {
    final policy = switch (row['account_policy']) {
      'standard' => UsageAccountPolicy.standard,
      'unlimited_tester' => UsageAccountPolicy.unlimitedTester,
      _ => null,
    };
    final flashcardsUsed = _nonnegativeInt(row['flashcards_used_today']);
    final quizUsed = _nonnegativeInt(row['quiz_questions_used_today']);
    final costUsed = _nonnegativeDouble(row['estimated_cost_used_today']);
    final active = _nonnegativeInt(row['active_reservations']);
    final flashcardsLimit = _nullableNonnegativeInt(
      row['flashcards_daily_limit'],
    );
    final quizLimit = _nullableNonnegativeInt(
      row['quiz_questions_daily_limit'],
    );
    final costLimit = _nullableNonnegativeDouble(
      row['estimated_cost_daily_limit'],
    );
    final resetAt = DateTime.tryParse('${row['reset_at']}')?.toLocal();
    if (policy == null ||
        flashcardsUsed == null ||
        quizUsed == null ||
        costUsed == null ||
        active == null ||
        resetAt == null ||
        policy == UsageAccountPolicy.standard &&
            (flashcardsLimit == null ||
                quizLimit == null ||
                costLimit == null) ||
        policy == UsageAccountPolicy.unlimitedTester &&
            (flashcardsLimit != null ||
                quizLimit != null ||
                costLimit != null)) {
      throw const UsageStatusRepositoryException();
    }
    return UsageStatus(
      accountPolicy: policy,
      flashcardsUsedToday: flashcardsUsed,
      flashcardsDailyLimit: flashcardsLimit,
      quizQuestionsUsedToday: quizUsed,
      quizQuestionsDailyLimit: quizLimit,
      estimatedCostUsedToday: costUsed,
      estimatedCostDailyLimit: costLimit,
      activeReservations: active,
      resetAt: resetAt,
    );
  }

  int? _nonnegativeInt(Object? value) {
    final parsed = value is int
        ? value
        : value is num
        ? value.toInt()
        : null;
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  int? _nullableNonnegativeInt(Object? value) =>
      value == null ? null : _nonnegativeInt(value);

  double? _nonnegativeDouble(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }

  double? _nullableNonnegativeDouble(Object? value) =>
      value == null ? null : _nonnegativeDouble(value);
}

class MockUsageStatusRepository implements UsageStatusRepository {
  const MockUsageStatusRepository();

  @override
  Future<UsageStatus> loadUsageStatus(AuthUser user) async {
    final now = DateTime.now();
    return UsageStatus(
      accountPolicy: UsageAccountPolicy.standard,
      flashcardsUsedToday: 0,
      flashcardsDailyLimit: 120,
      quizQuestionsUsedToday: 0,
      quizQuestionsDailyLimit: 80,
      estimatedCostUsedToday: 0,
      estimatedCostDailyLimit: 0.25,
      activeReservations: 0,
      resetAt: DateTime(now.year, now.month, now.day + 1),
    );
  }
}

class EmptyUsageStatusRepository implements UsageStatusRepository {
  const EmptyUsageStatusRepository();

  @override
  Future<UsageStatus> loadUsageStatus(AuthUser user) {
    throw const UsageStatusRepositoryException();
  }
}

class UsageStatusRepositoryException implements Exception {
  const UsageStatusRepositoryException();
}
