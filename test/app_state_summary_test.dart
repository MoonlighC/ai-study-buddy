import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/generation/summary_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    id: 'user-1',
    email: 'learner@example.test',
    displayName: 'Learner One',
  );

  group('AppState summary generation', () {
    test('mock summary generation updates local material summary', () async {
      final state = AppState(
        summaryRepository: _FakeSummaryRepository(
          summary: 'A concise mock summary.',
        ),
      );

      final generated = await state.generateSummaryFor(null, 'bio-lecture-1');

      expect(generated, isTrue);
      expect(
        state.materialById('bio-lecture-1')?.summary,
        'A concise mock summary.',
      );
      expect(state.isGeneratingSummary, isFalse);
      expect(state.summaryGenerationErrorMessage, isNull);
    });

    test(
      'supabase summary repository is called with user and material id',
      () async {
        final summaryRepository = _FakeSummaryRepository(
          summary: 'Cloud summary.',
        );
        final state = AppState(
          config: _supabaseConfig(),
          materialRepository: _FakeMaterialRepository(
            loadedMaterials: const [_material],
          ),
          summaryRepository: summaryRepository,
        );
        await state.loadMaterialsFor(user);

        final generated = await state.generateSummaryFor(user, 'material-1');

        expect(generated, isTrue);
        expect(summaryRepository.generatedUsers, [user]);
        expect(summaryRepository.generatedMaterialIds, ['material-1']);
        expect(state.materialById('material-1')?.summary, 'Cloud summary.');
      },
    );

    test('too-short material blocks summary generation safely', () async {
      final summaryRepository = _FakeSummaryRepository();
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [
            StudyMaterial(
              id: 'short-material',
              subjectId: 'subject-1',
              title: 'Short note',
              kind: MaterialKind.pastedText,
              content: 'Test',
              createdLabel: 'Synced',
            ),
          ],
        ),
        summaryRepository: summaryRepository,
      );
      await state.loadMaterialsFor(user);

      final generated = await state.generateSummaryFor(user, 'short-material');

      expect(generated, isFalse);
      expect(summaryRepository.generatedMaterialIds, isEmpty);
      expect(
        state.summaryGenerationErrorMessage,
        AppState.summaryTooShortMessage,
      );
    });

    test('valid material still generates after quality guard', () async {
      final summaryRepository = _FakeSummaryRepository(
        summary: 'Valid guarded summary.',
      );
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        summaryRepository: summaryRepository,
      );
      await state.loadMaterialsFor(user);

      final generated = await state.generateSummaryFor(user, 'material-1');

      expect(generated, isTrue);
      expect(summaryRepository.generatedMaterialIds, ['material-1']);
      expect(state.materialById('material-1')?.summary, 'Valid guarded summary.');
    });

    test('unauthenticated supabase summary generation fails safely', () async {
      final summaryRepository = _FakeSummaryRepository();
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [_material],
        ),
        summaryRepository: summaryRepository,
      );
      await state.loadMaterialsFor(user);

      final generated = await state.generateSummaryFor(null, 'material-1');

      expect(generated, isFalse);
      expect(summaryRepository.generatedMaterialIds, isEmpty);
      expect(
        state.summaryGenerationErrorMessage,
        'Could not generate summary. Try again.',
      );
    });

    test('failure preserves existing summary and stores safe error', () async {
      final state = AppState(
        config: _supabaseConfig(),
        materialRepository: _FakeMaterialRepository(
          loadedMaterials: const [
            StudyMaterial(
              id: 'material-1',
              subjectId: 'subject-1',
              title: 'Cloud notes',
              kind: MaterialKind.pastedText,
              content: _validMaterialContent,
              createdLabel: 'Synced',
              summary: 'Existing summary.',
            ),
          ],
        ),
        summaryRepository: _FakeSummaryRepository(throwOnGenerate: true),
      );
      await state.loadMaterialsFor(user);

      final generated = await state.generateSummaryFor(user, 'material-1');

      expect(generated, isFalse);
      expect(state.materialById('material-1')?.summary, 'Existing summary.');
      expect(
        state.summaryGenerationErrorMessage,
        'Could not generate summary. Try again.',
      );
    });
  });
}

const _material = StudyMaterial(
  id: 'material-1',
  subjectId: 'subject-1',
  title: 'Cloud notes',
  kind: MaterialKind.pastedText,
  content: _validMaterialContent,
  createdLabel: 'Synced',
);

const _validMaterialContent =
    'Synced lecture text with enough detail to generate a focused study summary. It explains the core idea, supporting evidence, and one point to review.';

AppConfig _supabaseConfig() {
  return AppConfig.fromValues(
    backendModeValue: 'supabase',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'sb_publishable_test-client-key',
  );
}

class _FakeSummaryRepository implements SummaryRepository {
  _FakeSummaryRepository({
    this.summary = 'Generated summary.',
    this.throwOnGenerate = false,
  });

  final String summary;
  final bool throwOnGenerate;
  final List<AuthUser> generatedUsers = [];
  final List<String> generatedMaterialIds = [];

  @override
  Future<String> generateSummary({
    required AuthUser user,
    required String materialId,
  }) async {
    generatedUsers.add(user);
    generatedMaterialIds.add(materialId);
    if (throwOnGenerate) {
      throw const SummaryRepositoryException(
        'Could not generate summary. Try again.',
      );
    }
    return summary;
  }
}

class _FakeMaterialRepository implements MaterialRepository {
  _FakeMaterialRepository({this.loadedMaterials = const []});

  final List<StudyMaterial> loadedMaterials;

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    return List<StudyMaterial>.of(loadedMaterials);
  }

  @override
  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  }) async {
    return StudyMaterial(
      id: 'created-1',
      subjectId: subjectId,
      title: title,
      kind: MaterialKind.pastedText,
      content: content,
      createdLabel: 'Just now',
    );
  }
}
