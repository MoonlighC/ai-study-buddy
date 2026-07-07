import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

Future<SupabaseClient?> bootstrapSupabase(AppConfig config) async {
  if (config.backendMode != AppBackendMode.supabase) {
    return null;
  }

  if (!config.hasSupabaseConfig) {
    debugPrint(
      'Supabase backend mode requested, but required public config is missing. '
      'Continuing in mock mode.',
    );
    return null;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );
  return Supabase.instance.client;
}
