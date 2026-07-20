// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:io';
import 'release_validation.dart';

void main(List<String> args) {
  try {
    Directory.current = _repositoryRoot();
    if (args.isEmpty) throw const ValidationException('command: required');
    final command = args.first;
    final options = _options(args.skip(1));
    switch (command) {
      case 'version':
        final v = _pubspecVersion();
        stdout.writeln('version=${v.semantic}+${v.build}');
      case 'tag':
        validateTag(_pubspecVersion(), _required(options, 'tag'));
        stdout.writeln('tag: valid');
      case 'artifact-name':
        stdout.writeln(
          artifactName(
            version: _pubspecVersion(),
            environment: _required(options, 'environment'),
            platform: _required(options, 'platform'),
          ),
        );
      case 'production-config':
        validateProductionConfiguration(Platform.environment);
        stdout.writeln('production configuration: valid');
      case 'staging-beta-config':
        validateStagingBetaConfiguration(
          Platform.environment,
          expectedProjectRef: _required(options, 'expected-project-ref'),
          productionProjectRef: options['production-project-ref'],
        );
        stdout.writeln('staging beta configuration: valid');
      case 'signer-fingerprint':
        validateSignerFingerprint(
          _required(options, 'actual'),
          _required(options, 'expected'),
        );
        stdout.writeln('signer fingerprint: valid');
      case 'reserved-build':
        final ledger = jsonDecode(
          File(_required(options, 'ledger')).readAsStringSync(),
        );
        if (ledger is! Map<String, dynamic> || ledger['records'] is! List) {
          throw const ValidationException('build ledger: invalid document');
        }
        final records = (ledger['records'] as List).map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const ValidationException('build ledger: invalid record');
          }
          final state = switch (raw['state']) {
            'reserved' => BuildNumberState.reserved,
            'distributed' => BuildNumberState.distributed,
            _ => throw const ValidationException('build ledger: invalid state'),
          };
          return BuildNumberRecord(raw['buildNumber'] as int, state);
        }).toList();
        validateReservedBuildNumber(
          int.parse(_required(options, 'number')),
          records,
        );
        stdout.writeln('reserved build number: valid');
      case 'signing-presence':
        SigningConfiguration.parse(
          local: options['source'] == 'local'
              ? _localSigningProperties()
              : const {},
          environment: Platform.environment,
          selectedSource: options['source'] ?? 'ci',
        );
        stdout.writeln('signing configuration: structurally complete');
      case 'checksum':
        final file = File(_required(options, 'file'));
        stdout.writeln('${sha256File(file)}  ${file.uri.pathSegments.last}');
      case 'manifest':
        final file = File(_required(options, 'artifact'));
        final v =
            options.containsKey('build-name') ||
                options.containsKey('build-number')
            ? AppVersion.parse(
                '${_required(options, 'build-name')}+${_required(options, 'build-number')}',
              )
            : _pubspecVersion();
        final manifest = buildManifest(
          gitCommit: _required(options, 'commit'),
          version: v,
          rcLabel: options['rc'],
          environment: _required(options, 'environment'),
          backendMode: _required(options, 'backend'),
          platform: _required(options, 'platform'),
          architecture: options['architecture'] ?? '',
          timestamp: DateTime.parse(_required(options, 'timestamp')),
          flutterVersion: _required(options, 'flutter-version'),
          dartVersion: Platform.version.split(' ').first,
          artifactFilename: file.uri.pathSegments.last,
          artifactSize: file.lengthSync(),
          sha256: sha256File(file),
          signingStatus: options['signing-status'] ?? 'unsigned',
          signerCertificateSha256: options['signer-sha256'],
          migrationRevisions: _migrationRevisions(),
        );
        stdout.writeln(canonicalJson(manifest));
      case 'secret-scan':
        final files = <String, String>{};
        for (final path in _trackedFiles()) {
          final f = File(path);
          if (f.existsSync() && f.lengthSync() < 1000000) {
            try {
              files[path.replaceAll('\\', '/')] = f.readAsStringSync();
            } catch (_) {}
          }
        }
        final findings = scanSecrets(files);
        for (final finding in findings) stderr.writeln(finding);
        if (findings.isNotEmpty)
          throw ValidationException(
            'secret scan: ${findings.length} finding(s)',
          );
        stdout.writeln('secret scan: clean');
      case 'template-assets':
        _validateTemplates();
        stdout.writeln('template assets: clean');
      case 'android-structure':
        _validateAndroid();
        stdout.writeln('android structure: valid');
      case 'package-input':
        validatePackageInput(
          _required(options, 'platform'),
          Directory(_required(options, 'path')),
        );
        stdout.writeln('package input: valid');
      case 'metadata':
        _validateMetadata();
        stdout.writeln('metadata: valid');
      default:
        throw ValidationException('command: unknown $command');
    }
  } on ValidationException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  } catch (error) {
    stderr.writeln('validation failed without exposing supplied values');
    exitCode = 2;
  }
}

Map<String, String> _localSigningProperties() {
  final file = File('android/key.properties');
  if (!file.existsSync()) return const {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
      continue;
    }
    final separator = trimmed.indexOf('=');
    values[trimmed.substring(0, separator).trim()] = trimmed
        .substring(separator + 1)
        .trim();
  }
  return values;
}

Directory _repositoryRoot() {
  final script = File.fromUri(Platform.script).absolute;
  final root = script.parent.parent;
  if (!File('${root.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
    throw const ValidationException('repository root: pubspec.yaml not found');
  }
  return root;
}

Map<String, String> _options(Iterable<String> args) {
  final result = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--') || !arg.contains('='))
      throw const ValidationException('arguments: expected --name=value');
    final split = arg.substring(2).split('=');
    result[split.first] = split.skip(1).join('=');
  }
  return result;
}

String _required(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.isEmpty)
    throw ValidationException('$name: required');
  return value;
}

AppVersion _pubspecVersion() {
  final text = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(text);
  if (match == null)
    throw const ValidationException('version: missing from pubspec');
  return AppVersion.parse(match[1]!);
}

List<String> _trackedFiles() {
  final result = Process.runSync('git', [
    '-c',
    'safe.directory=${Directory.current.path.replaceAll('\\', '/')}',
    'ls-files',
  ]);
  if (result.exitCode != 0)
    throw const ValidationException(
      'secret scan: unable to list tracked files',
    );
  return (result.stdout as String)
      .split(RegExp(r'\r?\n'))
      .where((e) => e.isNotEmpty)
      .map((e) => e.replaceAll('\\', '/'))
      .toList()
    ..sort();
}

List<String> _migrationRevisions() {
  final entries =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
  return entries;
}

void _validateMetadata() {
  _pubspecVersion();
  final android = File('android/app/build.gradle.kts').readAsStringSync();
  final ios = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final windows = File('windows/runner/Runner.rc').readAsStringSync();
  if (!android.contains('applicationId = "com.moonlightc.aistudybuddy"') ||
      !ios.contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.moonlightc.aistudybuddy;',
      ) ||
      !windows.contains('FLUTTER_VERSION_BUILD'))
    throw const ValidationException(
      'metadata: platform identity/version mapping mismatch',
    );
}

void _validateTemplates() {
  final files = {
    'pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
    'android/app/build.gradle.kts': File(
      'android/app/build.gradle.kts',
    ).readAsStringSync(),
  };
  final bad = <String>[];
  files.forEach((path, text) {
    if (text.contains('TODO: Specify your own unique Application ID') ||
        text.contains('A new Flutter project.'))
      bad.add(path);
  });
  if (bad.isNotEmpty)
    throw ValidationException(
      'template assets: active template text in ${bad.join(', ')}',
    );
}

void _validateAndroid() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final required = {
    'application ID': 'com.moonlightc.aistudybuddy',
    'INTERNET': 'android.permission.INTERNET',
    'cleartext disabled': 'android:usesCleartextTraffic="false"',
    'backup disabled': 'android:allowBackup="false"',
    'backup rules': 'android:dataExtractionRules="@xml/data_extraction_rules"',
  };
  for (final e in required.entries) {
    if (!gradle.contains(e.value) && !manifest.contains(e.value))
      throw ValidationException('android structure: missing ${e.key}');
  }
  if (gradle.contains('signingConfigs.getByName("debug")'))
    throw const ValidationException(
      'android structure: debug release signing fallback present',
    );
  for (final path in [
    'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_monochrome.png',
    'android/app/src/main/res/values-v31/styles.xml',
  ]) {
    if (!File(path).existsSync())
      throw ValidationException(
        'android structure: missing ${path.split('/').last}',
      );
  }
}
