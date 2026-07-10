import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/weak_topic.dart';
import '../auth/auth_models.dart';

abstract class WeakTopicRepository {
  Future<List<CumulativeWeakTopic>> loadWeakTopics(AuthUser user);
}

class WeakTopicRepositoryException implements Exception {
  const WeakTopicRepositoryException(this.message);

  final String message;
}

class MockWeakTopicRepository implements WeakTopicRepository {
  const MockWeakTopicRepository();

  @override
  Future<List<CumulativeWeakTopic>> loadWeakTopics(AuthUser user) async {
    return const [];
  }
}

class EmptyWeakTopicRepository implements WeakTopicRepository {
  const EmptyWeakTopicRepository();

  @override
  Future<List<CumulativeWeakTopic>> loadWeakTopics(AuthUser user) async {
    return const [];
  }
}

class SupabaseWeakTopicRepository implements WeakTopicRepository {
  const SupabaseWeakTopicRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<CumulativeWeakTopic>> loadWeakTopics(AuthUser user) async {
    try {
      final rows = await _client
          .from('weak_topics')
          .select(
            'id,subject_id,topic,topic_key,miss_count,last_seen_at,source',
          )
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .neq('topic_key', '')
          .order('miss_count', ascending: false)
          .order('last_seen_at', ascending: false);
      return [for (final row in rows) _mapWeakTopic(row)];
    } catch (_) {
      throw const WeakTopicRepositoryException(
        'Could not sync cumulative weak topics.',
      );
    }
  }

  CumulativeWeakTopic _mapWeakTopic(Map<String, dynamic> row) {
    final source = row['source'];
    return CumulativeWeakTopic(
      id: _stringValue(row['id']),
      subjectId: _stringValue(row['subject_id']),
      topic: _stringValue(row['topic']),
      topicKey: _stringValue(row['topic_key']),
      missCount: _intValue(row['miss_count']),
      lastSeenAt:
          DateTime.tryParse(row['last_seen_at']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      source: source is Map<String, dynamic> ? Map.of(source) : const {},
    );
  }

  String _stringValue(Object? value) => value is String ? value : '';

  int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
