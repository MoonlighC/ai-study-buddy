import 'dart:convert';

import 'package:ai_study_buddy/app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validUrl = 'https://study-buddy.supabase.co';
  const validKey = 'sb_publishable_public-client-key';

  AppConfig supabase({
    String environment = 'local',
    String url = validUrl,
    String key = validKey,
    bool release = false,
  }) => AppConfig.fromValues(
    environmentValue: environment,
    backendModeValue: 'supabase',
    supabaseUrl: url,
    supabaseAnonKey: key,
    releaseMode: release,
  );

  test('local mock is the development default', () {
    final config = AppConfig.fromValues();
    expect(config.environment, AppEnvironment.local);
    expect(config.backendMode, AppBackendMode.mock);
    expect(config.shouldInitializeSupabase, isFalse);
  });

  for (final environment in ['local', 'staging', 'production']) {
    test('$environment accepts valid Supabase configuration', () {
      expect(
        supabase(environment: environment).shouldInitializeSupabase,
        isTrue,
      );
    });
  }

  test('unknown environment is rejected', () {
    expect(
      () => AppConfig.fromValues(environmentValue: 'preview'),
      throwsA(isA<AppConfigException>()),
    );
  });

  test('unknown backend is rejected', () {
    expect(
      () => AppConfig.fromValues(backendModeValue: 'SUPABASE'),
      throwsA(isA<AppConfigException>()),
    );
  });

  for (final environment in ['staging', 'production']) {
    test('$environment rejects mock', () {
      expect(
        () => AppConfig.fromValues(environmentValue: environment),
        throwsA(isA<AppConfigException>()),
      );
    });
  }

  test('release mode rejects mock in every environment', () {
    expect(
      () => AppConfig.fromValues(releaseMode: true),
      throwsA(isA<AppConfigException>()),
    );
  });

  final badUrls = <String, String>{
    'missing': '',
    'malformed': 'not a url',
    'non-HTTPS': 'http://study-buddy.supabase.co',
    'localhost': 'https://localhost:54321',
    'IPv4 loopback': 'https://127.0.0.1',
    'IPv6 loopback': 'https://[::1]',
    'placeholder': 'https://YOUR-PROJECT.supabase.co',
    'development host': 'https://backend.local',
  };
  for (final entry in badUrls.entries) {
    test('rejects ${entry.key} URL', () {
      expect(
        () => supabase(url: entry.value),
        throwsA(isA<AppConfigException>()),
      );
    });
  }

  for (final key in ['', 'YOUR-PUBLISHABLE-KEY', 'placeholder-anon-key']) {
    test('rejects empty or placeholder public key', () {
      expect(() => supabase(key: key), throwsA(isA<AppConfigException>()));
    });
  }

  test('rejects obvious secret key', () {
    expect(
      () => supabase(key: 'sb_secret_server-only'),
      throwsA(isA<AppConfigException>()),
    );
  });

  test('rejects legacy service-role JWT', () {
    final payload = base64Url.encode(utf8.encode('{"role":"service_role"}'));
    expect(
      () => supabase(key: 'header.$payload.signature'),
      throwsA(isA<AppConfigException>()),
    );
  });

  test('configuration errors never contain supplied values', () {
    const supplied = 'sb_secret_do-not-print-this';
    try {
      supabase(key: supplied);
      fail('Expected configuration failure');
    } on AppConfigException catch (error) {
      expect(error.toString(), isNot(contains(supplied)));
      expect(error.toString(), contains('SUPABASE_ANON_KEY'));
    }
  });
}
