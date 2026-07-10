import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'app/supabase_bootstrap.dart';
import 'features/auth/supabase_auth_repository.dart';
import 'features/favorites/supabase_favorite_repository.dart';
import 'features/flashcards/flashcard_repository.dart';
import 'features/generation/summary_repository.dart';
import 'features/materials/supabase_material_repository.dart';
import 'features/materials/supabase_material_upload_repository.dart';
import 'features/materials/pdf_text_extraction_repository.dart';
import 'features/quizzes/quiz_repository.dart';
import 'features/progress/weak_topic_repository.dart';
import 'features/subjects/supabase_subject_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final supabaseClient = await bootstrapSupabase(config);
  runApp(
    StudyBuddyApp(
      config: config,
      authRepository: supabaseClient == null
          ? null
          : SupabaseAuthRepository(supabaseClient),
      profileRepository: supabaseClient == null
          ? null
          : SupabaseProfileRepository(supabaseClient),
      subjectRepository: supabaseClient == null
          ? null
          : SupabaseSubjectRepository(supabaseClient),
      materialRepository: supabaseClient == null
          ? null
          : SupabaseMaterialRepository(supabaseClient),
      materialUploadRepository: supabaseClient == null
          ? null
          : SupabaseMaterialUploadRepository(
              SupabaseMaterialUploadDataSource(supabaseClient),
            ),
      pdfTextExtractionRepository: supabaseClient == null
          ? null
          : SupabasePdfTextExtractionRepository(
              SupabasePdfTextExtractionDataSource(supabaseClient),
            ),
      favoriteRepository: supabaseClient == null
          ? null
          : SupabaseFavoriteRepository(supabaseClient),
      flashcardRepository: supabaseClient == null
          ? null
          : SupabaseFlashcardRepository(supabaseClient),
      summaryRepository: supabaseClient == null
          ? null
          : SupabaseSummaryRepository(supabaseClient),
      quizRepository: supabaseClient == null
          ? null
          : SupabaseQuizRepository(supabaseClient),
      weakTopicRepository: supabaseClient == null
          ? null
          : SupabaseWeakTopicRepository(supabaseClient),
    ),
  );
}
