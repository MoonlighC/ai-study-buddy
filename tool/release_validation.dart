// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const releaseEnvironments = {'local', 'staging', 'production'};
const signingFields = {
  'keystorePath',
  'keyAlias',
  'storePassword',
  'keyPassword',
};

class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppVersion {
  const AppVersion(this.semantic, this.build);
  final String semantic;
  final int build;

  static AppVersion parse(String value) {
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)\+([1-9]\d*)$',
    ).firstMatch(value.trim());
    if (match == null)
      throw const ValidationException(
        'version: expected MAJOR.MINOR.PATCH+positive BUILD',
      );
    return AppVersion(
      '${match[1]}.${match[2]}.${match[3]}',
      int.parse(match[4]!),
    );
  }
}

void validateTag(AppVersion version, String tag) {
  final match = RegExp(
    r'^v(\d+\.\d+\.\d+)(?:-rc\.([1-9]\d*))?$',
  ).firstMatch(tag);
  if (match == null || match[1] != version.semantic) {
    throw const ValidationException(
      'tag: does not match the pubspec semantic version',
    );
  }
}

class SigningConfiguration {
  const SigningConfiguration({required this.source, required this.values});
  final String source;
  final Map<String, String> values;

  static SigningConfiguration parse({
    required Map<String, String> local,
    required Map<String, String> environment,
    String? selectedSource,
  }) {
    final source = selectedSource ?? (local.isNotEmpty ? 'local' : 'ci');
    if (source != 'local' && source != 'ci') {
      throw const ValidationException('signing source: expected local or ci');
    }
    final raw = source == 'local'
        ? {
            'keystorePath': local['storeFile'] ?? '',
            'keyAlias': local['keyAlias'] ?? '',
            'storePassword': local['storePassword'] ?? '',
            'keyPassword': local['keyPassword'] ?? '',
          }
        : {
            'keystorePath': environment['ANDROID_KEYSTORE_PATH'] ?? '',
            'keyAlias': environment['ANDROID_KEY_ALIAS'] ?? '',
            'storePassword': environment['ANDROID_STORE_PASSWORD'] ?? '',
            'keyPassword': environment['ANDROID_KEY_PASSWORD'] ?? '',
          };
    final missing =
        raw.entries
            .where((e) => e.value.trim().isEmpty)
            .map((e) => e.key)
            .toList()
          ..sort();
    if (missing.isNotEmpty) {
      throw ValidationException(
        'signing configuration: missing ${missing.join(', ')}',
      );
    }
    return SigningConfiguration(source: source, values: Map.unmodifiable(raw));
  }
}

void validateProductionConfiguration(Map<String, String> values) {
  final environment = values['APP_ENV'] ?? '';
  if (!releaseEnvironments.contains(environment)) {
    throw const ValidationException('APP_ENV: unknown environment');
  }
  if (environment != 'production')
    throw const ValidationException('APP_ENV: production is required');
  if (values['APP_BACKEND_MODE'] != 'supabase') {
    throw const ValidationException('APP_BACKEND_MODE: supabase is required');
  }
  final uri = Uri.tryParse(values['SUPABASE_URL'] ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.host.contains('example')) {
    throw const ValidationException(
      'SUPABASE_URL: valid public HTTPS configuration is required',
    );
  }
  final key = values['SUPABASE_ANON_KEY'] ?? '';
  final lower = key.toLowerCase();
  if (key.trim().isEmpty ||
      lower.contains('placeholder') ||
      lower.startsWith('sb_secret_') ||
      lower.contains('service_role')) {
    throw const ValidationException(
      'SUPABASE_ANON_KEY: valid public client configuration is required',
    );
  }
}

void validateStagingBetaConfiguration(
  Map<String, String> values, {
  required String expectedProjectRef,
  String? productionProjectRef,
}) {
  if (expectedProjectRef.trim().isEmpty) {
    throw const ValidationException('expected project ref: required');
  }
  if (values['APP_ENV'] != 'staging') {
    throw const ValidationException('APP_ENV: staging is required');
  }
  if (values['APP_BACKEND_MODE'] != 'supabase') {
    throw const ValidationException('APP_BACKEND_MODE: supabase is required');
  }
  final uri = Uri.tryParse(values['SUPABASE_URL'] ?? '');
  final host = uri?.host.toLowerCase() ?? '';
  if (uri == null || uri.scheme != 'https' || host.isEmpty) {
    throw const ValidationException(
      'SUPABASE_URL: public HTTPS URL is required',
    );
  }
  if (host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.contains('placeholder') ||
      host.contains('example')) {
    throw const ValidationException(
      'SUPABASE_URL: public staging host is required',
    );
  }
  if (!host.split('.').contains(expectedProjectRef.toLowerCase())) {
    throw const ValidationException(
      'SUPABASE_URL: expected staging project ref is required',
    );
  }
  final productionRef = productionProjectRef?.trim().toLowerCase();
  if (productionRef != null &&
      productionRef.isNotEmpty &&
      host.contains(productionRef)) {
    throw const ValidationException(
      'SUPABASE_URL: production project ref is forbidden',
    );
  }
  final key = values['SUPABASE_ANON_KEY']?.trim() ?? '';
  final lower = key.toLowerCase();
  if (key.isEmpty ||
      lower.contains('placeholder') ||
      lower.contains('example') ||
      lower.startsWith('sb_secret_') ||
      lower.contains('service_role')) {
    throw const ValidationException(
      'SUPABASE_ANON_KEY: public client key is required',
    );
  }
}

enum BuildNumberState { reserved, distributed }

class BuildNumberRecord {
  const BuildNumberRecord(this.number, this.state);
  final int number;
  final BuildNumberState state;
}

void validateBuildNumberLedger(List<BuildNumberRecord> records) {
  final seen = <int>{};
  var previous = 0;
  for (final record in records) {
    if (record.number <= 0 ||
        !seen.add(record.number) ||
        record.number <= previous) {
      throw const ValidationException(
        'build ledger: numbers must be positive, unique, and increasing',
      );
    }
    previous = record.number;
  }
}

void validateNewBuildNumber(int number, List<BuildNumberRecord> records) {
  validateBuildNumberLedger(records);
  if (number <= 0 ||
      records.any((record) => record.number == number) ||
      (records.isNotEmpty && number <= records.last.number)) {
    throw const ValidationException(
      'build number: must be new and greater than the ledger',
    );
  }
}

void validateReservedBuildNumber(int number, List<BuildNumberRecord> records) {
  validateBuildNumberLedger(records);
  final matches = records.where((record) => record.number == number).toList();
  if (matches.length != 1 ||
      matches.single.state != BuildNumberState.reserved) {
    throw const ValidationException(
      'build number: must have one reserved record',
    );
  }
}

String normalizeSha256Fingerprint(String value) {
  final normalized = value.replaceAll(':', '').trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw const ValidationException('signer fingerprint: expected SHA-256');
  }
  return normalized;
}

void validateSignerFingerprint(String actual, String expected) {
  if (normalizeSha256Fingerprint(actual) !=
      normalizeSha256Fingerprint(expected)) {
    throw const ValidationException('signer fingerprint: mismatch');
  }
}

void validateAndroidArtifactMetadata({
  required String packageId,
  required String versionName,
  required int versionCode,
  required bool debugSigned,
  required String signerSha256,
  required String expectedSignerSha256,
}) {
  if (packageId != 'com.moonlightc.aistudybuddy') {
    throw const ValidationException('Android artifact: package ID mismatch');
  }
  if (versionName != '1.0.0' || versionCode <= 0) {
    throw const ValidationException('Android artifact: version mismatch');
  }
  if (debugSigned)
    throw const ValidationException(
      'Android artifact: debug signing forbidden',
    );
  validateSignerFingerprint(signerSha256, expectedSignerSha256);
}

String artifactName({
  required AppVersion version,
  required String environment,
  required String platform,
}) {
  if (!releaseEnvironments.contains(environment))
    throw const ValidationException('artifact environment: unknown');
  const suffixes = {
    'android-aab': 'android.aab',
    'android-apk': 'android.apk',
    'web': 'web.zip',
    'windows-x64': 'windows-x64.zip',
  };
  final suffix = suffixes[platform];
  if (suffix == null)
    throw const ValidationException('artifact platform: unknown or missing');
  final result =
      'AI-Study-Buddy-${version.semantic}+${version.build}-$environment-$suffix';
  validateArtifactFilename(result, expectedEnvironment: environment);
  return result;
}

void validateArtifactFilename(
  String value, {
  required String expectedEnvironment,
}) {
  if (value.contains('..') ||
      value.contains('/') ||
      value.contains('\\') ||
      value.contains('://')) {
    throw const ValidationException('artifact name: unsafe path or URL');
  }
  if (!RegExp(r'^[A-Za-z0-9.+-]+$').hasMatch(value))
    throw const ValidationException('artifact name: unsafe characters');
  final lower = value.toLowerCase();
  if (RegExp(r'(token|password|secret|apikey|api-key|key=)').hasMatch(lower)) {
    throw const ValidationException('artifact name: credential-like fragment');
  }
  for (final environment in releaseEnvironments) {
    if (lower.contains('-$environment-') &&
        environment != expectedEnvironment) {
      throw const ValidationException(
        'artifact name: environment label mismatch',
      );
    }
  }
}

Map<String, Object?> buildManifest({
  required String gitCommit,
  required AppVersion version,
  required String? rcLabel,
  required String environment,
  required String backendMode,
  required String platform,
  required String architecture,
  required DateTime timestamp,
  required String flutterVersion,
  required String dartVersion,
  required String artifactFilename,
  required int artifactSize,
  required String sha256,
  required String signingStatus,
  String? signerCertificateSha256,
  required List<String> migrationRevisions,
}) {
  final revisions = [...migrationRevisions]..sort();
  return <String, Object?>{
    'schemaVersion': 1,
    'gitCommit': gitCommit,
    'semanticVersion': version.semantic,
    'buildNumber': version.build,
    'rcLabel': rcLabel,
    'environment': environment,
    'backendMode': backendMode,
    'platform': platform,
    'architecture': architecture,
    'buildTimestampUtc': timestamp.toUtc().toIso8601String(),
    'flutterVersion': flutterVersion,
    'dartVersion': dartVersion,
    'artifactFilename': artifactFilename,
    'artifactSize': artifactSize,
    'sha256': sha256.toLowerCase(),
    'signingStatus': signingStatus,
    if (signerCertificateSha256 != null)
      'signerCertificateSha256': normalizeSha256Fingerprint(
        signerCertificateSha256,
      ),
    'migrationRevisions': revisions,
  };
}

String canonicalJson(Map<String, Object?> value) =>
    const JsonEncoder.withIndent('  ').convert(value);

List<String> validatePackageInput(String platform, Directory root) {
  final required = platform == 'web'
      ? [
          'index.html',
          'flutter_bootstrap.js',
          'assets',
          'manifest.json',
          'icons',
        ]
      : platform == 'windows-x64'
      ? ['ai_study_buddy.exe', 'flutter_windows.dll', 'data']
      : throw const ValidationException('package input: unsupported platform');
  final missing = required
      .where(
        (path) =>
            !File('${root.path}${Platform.pathSeparator}$path').existsSync() &&
            !Directory(
              '${root.path}${Platform.pathSeparator}$path',
            ).existsSync(),
      )
      .toList();
  if (missing.isNotEmpty)
    throw ValidationException('package input: missing ${missing.join(', ')}');
  if (platform == 'windows-x64') {
    final dlls = root.listSync().whereType<File>().where(
      (f) => f.path.toLowerCase().endsWith('.dll'),
    );
    if (dlls.isEmpty)
      throw const ValidationException('package input: missing runtime DLLs');
  }
  return required;
}

class SecretFinding {
  const SecretFinding(this.path, this.rule);
  final String path;
  final String rule;
  @override
  String toString() => '$path: $rule [REDACTED]';
}

List<SecretFinding> scanSecrets(Map<String, String> files) {
  final findings = <SecretFinding>[];
  final paths = files.keys.toList()..sort();
  for (final path in paths) {
    final normalizedPath = path.replaceAll('\\', '/');
    final lowerPath = normalizedPath.toLowerCase();
    if (RegExp(
      r'(^|/)(key|signing)\.properties$|\.(jks|keystore|p12|mobileprovision)$',
    ).hasMatch(lowerPath)) {
      findings.add(SecretFinding(path, 'credential-file'));
      continue;
    }
    final content = files[path]!;
    if (content.contains('FAKE_TEST_FIXTURE') || lowerPath.endsWith('.md'))
      continue;
    const privateKeyMarker =
        '-----BEGIN '
        'PRIVATE KEY-----';
    const rsaPrivateKeyMarker =
        '-----BEGIN RSA '
        'PRIVATE KEY-----';
    if (content.contains(privateKeyMarker) ||
        content.contains(rsaPrivateKeyMarker)) {
      findings.add(SecretFinding(path, 'private-key'));
    }
    if (RegExp(
      r'(service_role|OPENAI_API_KEY)\s*[:=]\s*["\x27]?(?!\$|%|\{)[A-Za-z0-9_.-]{24,}',
      caseSensitive: false,
    ).hasMatch(content)) {
      findings.add(SecretFinding(path, 'server-credential'));
    }
    if (RegExp(
      r'(token|password|secret)\s*[:=]\s*["\x27][A-Za-z0-9_./+=-]{24,}["\x27]',
      caseSensitive: false,
    ).hasMatch(content)) {
      findings.add(SecretFinding(path, 'credential-value'));
    }
  }
  return findings;
}

String sha256Bytes(List<int> input) {
  final bytes = Uint8List.fromList(input);
  final bitLength = bytes.length * 8;
  final paddedLength = ((bytes.length + 9 + 63) ~/ 64) * 64;
  final data = Uint8List(paddedLength)..setRange(0, bytes.length, bytes);
  data[bytes.length] = 0x80;
  final bd = ByteData.sublistView(data);
  bd.setUint32(paddedLength - 4, bitLength, Endian.big);
  final h = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  int rr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xffffffff;
  for (var offset = 0; offset < data.length; offset += 64) {
    final w = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++)
      w[i] = bd.getUint32(offset + i * 4, Endian.big);
    for (var i = 16; i < 64; i++) {
      final s0 = rr(w[i - 15], 7) ^ rr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 = rr(w[i - 2], 17) ^ rr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h[0],
        b = h[1],
        c = h[2],
        d = h[3],
        e = h[4],
        f = h[5],
        g = h[6],
        hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rr(e, 6) ^ rr(e, 11) ^ rr(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = rr(a, 2) ^ rr(a, 13) ^ rr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    final v = [a, b, c, d, e, f, g, hh];
    for (var i = 0; i < 8; i++) h[i] = (h[i] + v[i]) & 0xffffffff;
  }
  return h.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}

String sha256File(File file) => sha256Bytes(file.readAsBytesSync());

String combinedChecksums(Map<String, String> hashes) {
  final names = hashes.keys.toList()..sort();
  return names
          .map((name) => '${hashes[name]!.toLowerCase()}  $name')
          .join('\n') +
      '\n';
}
