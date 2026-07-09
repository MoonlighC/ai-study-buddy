import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'app/supabase_bootstrap.dart';
import 'features/auth/supabase_auth_repository.dart';
import 'features/favorites/supabase_favorite_repository.dart';
import 'features/materials/supabase_material_repository.dart';
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
      favoriteRepository: supabaseClient == null
          ? null
          : SupabaseFavoriteRepository(supabaseClient),
    ),
  );
}
