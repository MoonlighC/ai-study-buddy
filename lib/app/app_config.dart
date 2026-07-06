enum AppBackendMode { mock, supabase }

class AppConfig {
  const AppConfig({
    required this.backendMode,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromEnvironment() {
    return AppConfig.fromValues(
      backendModeValue: const String.fromEnvironment(
        'APP_BACKEND_MODE',
        defaultValue: 'mock',
      ),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  factory AppConfig.fromValues({
    String backendModeValue = 'mock',
    String supabaseUrl = '',
    String supabaseAnonKey = '',
  }) {
    return AppConfig(
      backendMode: backendModeValue == 'supabase'
          ? AppBackendMode.supabase
          : AppBackendMode.mock,
      supabaseUrl: supabaseUrl.trim(),
      supabaseAnonKey: supabaseAnonKey.trim(),
    );
  }

  final AppBackendMode backendMode;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabaseConfig {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  bool get shouldInitializeSupabase {
    return backendMode == AppBackendMode.supabase && hasSupabaseConfig;
  }
}
