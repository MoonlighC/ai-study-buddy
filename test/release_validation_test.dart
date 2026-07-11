import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/release_validation.dart';

void main() {
  group('signing configuration', () {
    const fakeLocal = {
      'storeFile': 'FAKE_TEST_FIXTURE/outside-repo.jks',
      'keyAlias': 'FAKE_TEST_FIXTURE_ALIAS',
      'storePassword': 'FAKE_TEST_FIXTURE_PASSWORD',
      'keyPassword': 'FAKE_TEST_FIXTURE_PASSWORD',
    };
    const fakeCi = {
      'ANDROID_KEYSTORE_PATH': 'FAKE_TEST_FIXTURE/temp.jks',
      'ANDROID_KEY_ALIAS': 'FAKE_TEST_FIXTURE_ALIAS',
      'ANDROID_STORE_PASSWORD': 'FAKE_TEST_FIXTURE_PASSWORD',
      'ANDROID_KEY_PASSWORD': 'FAKE_TEST_FIXTURE_PASSWORD',
    };

    test('accepts complete local and CI sources', () {
      expect(
        SigningConfiguration.parse(
          local: fakeLocal,
          environment: const {},
        ).source,
        'local',
      );
      expect(
        SigningConfiguration.parse(local: const {}, environment: fakeCi).source,
        'ci',
      );
    });

    test('explicit CI source does not merge local values', () {
      expect(
        () => SigningConfiguration.parse(
          local: fakeLocal,
          environment: const {},
          selectedSource: 'ci',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('partial values report field names without values', () {
      try {
        SigningConfiguration.parse(
          local: const {'keyAlias': 'FAKE_TEST_FIXTURE_ALIAS'},
          environment: const {},
        );
        fail('expected failure');
      } on ValidationException catch (error) {
        expect(error.message, contains('keystorePath'));
        expect(error.message, contains('storePassword'));
        expect(error.message, isNot(contains('FAKE_TEST_FIXTURE_ALIAS')));
      }
    });
  });

  test('production configuration requirements are enforced', () {
    expect(
      () => validateProductionConfiguration(const {'APP_ENV': 'staging'}),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => validateProductionConfiguration(const {
        'APP_ENV': 'production',
        'APP_BACKEND_MODE': 'supabase',
        'SUPABASE_URL': 'https://fixture.supabase.co',
        'SUPABASE_ANON_KEY': 'FAKE_TEST_FIXTURE_PUBLIC_CLIENT_KEY',
      }),
      returnsNormally,
    );
  });

  test('version and final or RC tags must agree', () {
    final version = AppVersion.parse('1.0.0+1');
    expect(() => validateTag(version, 'v1.0.0'), returnsNormally);
    expect(() => validateTag(version, 'v1.0.0-rc.1'), returnsNormally);
    expect(
      () => validateTag(version, 'v1.0.1'),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => AppVersion.parse('1.0.0+0'),
      throwsA(isA<ValidationException>()),
    );
  });

  test('artifact names are validated', () {
    final version = AppVersion.parse('1.0.0+1');
    expect(
      artifactName(
        version: version,
        environment: 'production',
        platform: 'android-aab',
      ),
      'AI-Study-Buddy-1.0.0+1-production-android.aab',
    );
    expect(
      () => artifactName(
        version: version,
        environment: 'unknown',
        platform: 'web',
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => validateArtifactFilename(
        '../token-secret.zip',
        expectedEnvironment: 'production',
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => validateArtifactFilename(
        'AI-Study-Buddy-1.0.0+1-staging-web.zip',
        expectedEnvironment: 'production',
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('manifest is deterministic and excludes sensitive fields', () {
    final manifest = buildManifest(
      gitCommit: 'abc123',
      version: AppVersion.parse('1.0.0+1'),
      rcLabel: 'rc.1',
      environment: 'production',
      backendMode: 'supabase',
      platform: 'web',
      architecture: '',
      timestamp: DateTime.utc(2026, 7, 11, 12),
      flutterVersion: '3.44.4',
      dartVersion: '3.12.2',
      artifactFilename: 'fixture.zip',
      artifactSize: 7,
      sha256: 'ABC',
      signingStatus: 'unsigned',
      migrationRevisions: const ['002.sql', '001.sql'],
    );
    expect(manifest['buildTimestampUtc'], '2026-07-11T12:00:00.000Z');
    expect(manifest['migrationRevisions'], ['001.sql', '002.sql']);
    final json = canonicalJson(manifest);
    for (final forbidden in [
      'SUPABASE_URL',
      'keyAlias',
      'password',
      'keystorePath',
    ]) {
      expect(json, isNot(contains(forbidden)));
    }
  });

  test('SHA-256 and combined checksum output match known values', () {
    expect(
      sha256Bytes(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      combinedChecksums(const {'b.zip': 'BB', 'a.zip': 'AA'}),
      'aa  a.zip\nbb  b.zip\n',
    );
  });

  test('secret scanner distinguishes findings and allowed fixtures', () {
    final findings = scanSecrets(const {
      'lib/bad.txt': 'token="abcdefghijklmnopqrstuvwxyz123456"',
      'docs/allowed.md': 'OPENAI_API_KEY is an environment variable',
      'test/fake.txt':
          'FAKE_TEST_FIXTURE token="abcdefghijklmnopqrstuvwxyz123456"',
    });
    expect(findings, hasLength(1));
    expect(findings.single.toString(), contains('[REDACTED]'));
    expect(
      findings.single.toString(),
      isNot(contains('abcdefghijklmnopqrstuvwxyz')),
    );
  });

  test('Android release structure is secure and has no debug fallback', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(gradle, contains('com.moonlightc.aistudybuddy'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('package input validation requires runtime structure', () {
    final root = Directory.systemTemp.createTempSync('release-fixture-');
    addTearDown(() => root.deleteSync(recursive: true));
    expect(
      () => validatePackageInput('web', root),
      throwsA(isA<ValidationException>()),
    );
    for (final path in [
      'index.html',
      'flutter_bootstrap.js',
      'manifest.json',
    ]) {
      File(
        '${root.path}${Platform.pathSeparator}$path',
      ).writeAsStringSync('FAKE_TEST_FIXTURE');
    }
    Directory('${root.path}${Platform.pathSeparator}assets').createSync();
    Directory('${root.path}${Platform.pathSeparator}icons').createSync();
    expect(validatePackageInput('web', root), isNotEmpty);
  });
}
