import 'package:ai_study_buddy/app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('defaults to mock mode without Supabase config', () {
      final config = AppConfig.fromValues();

      expect(config.backendMode, AppBackendMode.mock);
      expect(config.supabaseUrl, isEmpty);
      expect(config.supabaseAnonKey, isEmpty);
      expect(config.hasSupabaseConfig, isFalse);
      expect(config.effectiveBackendMode, AppBackendMode.mock);
      expect(config.shouldInitializeSupabase, isFalse);
    });

    test('uses mock mode unless backend mode is exactly supabase', () {
      final config = AppConfig.fromValues(
        backendModeValue: 'SUPABASE',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'placeholder-anon-key',
      );

      expect(config.backendMode, AppBackendMode.mock);
      expect(config.hasSupabaseConfig, isTrue);
      expect(config.effectiveBackendMode, AppBackendMode.mock);
      expect(config.shouldInitializeSupabase, isFalse);
    });

    test('enables Supabase mode when values are present', () {
      final config = AppConfig.fromValues(
        backendModeValue: 'supabase',
        supabaseUrl: ' https://example.supabase.co ',
        supabaseAnonKey: ' placeholder-anon-key ',
      );

      expect(config.backendMode, AppBackendMode.supabase);
      expect(config.supabaseUrl, 'https://example.supabase.co');
      expect(config.supabaseAnonKey, 'placeholder-anon-key');
      expect(config.hasSupabaseConfig, isTrue);
      expect(config.effectiveBackendMode, AppBackendMode.supabase);
      expect(config.shouldInitializeSupabase, isTrue);
    });

    test('does not initialize Supabase when requested config is missing', () {
      final config = AppConfig.fromValues(backendModeValue: 'supabase');

      expect(config.backendMode, AppBackendMode.supabase);
      expect(config.hasSupabaseConfig, isFalse);
      expect(config.effectiveBackendMode, AppBackendMode.mock);
      expect(config.shouldInitializeSupabase, isFalse);
    });
  });
}
