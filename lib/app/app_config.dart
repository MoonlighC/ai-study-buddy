import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AppEnvironment { local, staging, production }

enum AppBackendMode { mock, supabase }

class AppConfigException implements Exception {
  const AppConfigException(this.field, this.reason);

  final String field;
  final String reason;

  @override
  String toString() => 'Invalid application configuration: $field $reason.';
}

class AppConfig {
  const AppConfig({
    this.environment = AppEnvironment.local,
    required this.backendMode,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromEnvironment() => AppConfig.fromValues(
    environmentValue: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'local',
    ),
    backendModeValue: const String.fromEnvironment(
      'APP_BACKEND_MODE',
      defaultValue: 'mock',
    ),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    releaseMode: kReleaseMode,
  );

  factory AppConfig.fromValues({
    String environmentValue = 'local',
    String backendModeValue = 'mock',
    String supabaseUrl = '',
    String supabaseAnonKey = '',
    bool releaseMode = false,
  }) {
    final environment = switch (environmentValue) {
      'local' => AppEnvironment.local,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw const AppConfigException('APP_ENV', 'is unknown'),
    };
    final backendMode = switch (backendModeValue) {
      'mock' => AppBackendMode.mock,
      'supabase' => AppBackendMode.supabase,
      _ => throw const AppConfigException('APP_BACKEND_MODE', 'is unknown'),
    };

    if (backendMode == AppBackendMode.mock &&
        (environment != AppEnvironment.local || releaseMode)) {
      throw const AppConfigException(
        'APP_BACKEND_MODE',
        'cannot be mock for this build',
      );
    }

    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    if (backendMode == AppBackendMode.supabase) {
      _validateSupabaseUrl(url);
      _validatePublicKey(key);
    }

    return AppConfig(
      environment: environment,
      backendMode: backendMode,
      supabaseUrl: url,
      supabaseAnonKey: key,
    );
  }

  final AppEnvironment environment;
  final AppBackendMode backendMode;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get shouldInitializeSupabase => backendMode == AppBackendMode.supabase;

  // Retained for callers that distinguish repository behavior by backend.
  AppBackendMode get effectiveBackendMode => backendMode;

  static void _validateSupabaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (value.isEmpty) {
      throw const AppConfigException('SUPABASE_URL', 'is required');
    }
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AppConfigException('SUPABASE_URL', 'is malformed');
    }
    if (uri.scheme != 'https') {
      throw const AppConfigException('SUPABASE_URL', 'must use HTTPS');
    }
    final host = uri.host.toLowerCase();
    final normalized = value.toLowerCase();
    final isIpv6Loopback = host == '::1' || host == '[::1]';
    final isDevelopmentHost =
        host == 'localhost' ||
        host == '127.0.0.1' ||
        isIpv6Loopback ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.test') ||
        host.endsWith('.invalid');
    final isPlaceholder =
        normalized.contains('your-project') ||
        normalized.contains('placeholder') ||
        normalized.contains('example.com');
    if (isDevelopmentHost || isPlaceholder) {
      throw const AppConfigException('SUPABASE_URL', 'is not allowed');
    }
  }

  static void _validatePublicKey(String value) {
    final normalized = value.toLowerCase();
    if (value.isEmpty) {
      throw const AppConfigException('SUPABASE_ANON_KEY', 'is required');
    }
    if (normalized.contains('placeholder') ||
        normalized.contains('your-') ||
        normalized.contains('example')) {
      throw const AppConfigException('SUPABASE_ANON_KEY', 'is a placeholder');
    }
    if (normalized.startsWith('sb_secret_') ||
        normalized.contains('service_role') ||
        _jwtRole(value) == 'service_role') {
      throw const AppConfigException(
        'SUPABASE_ANON_KEY',
        'is not a public client key',
      );
    }
  }

  static String? _jwtRole(String value) {
    final parts = value.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload);
      return json is Map<String, dynamic> ? json['role'] as String? : null;
    } on Object {
      return null;
    }
  }
}
