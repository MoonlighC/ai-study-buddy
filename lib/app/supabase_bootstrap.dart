import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

Future<SupabaseClient?> bootstrapSupabase(AppConfig config) async {
  if (!config.shouldInitializeSupabase) return null;

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );
  return Supabase.instance.client;
}
