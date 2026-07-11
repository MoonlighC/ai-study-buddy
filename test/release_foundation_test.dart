import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

({int width, int height}) pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.sublist(1, 4), [0x50, 0x4e, 0x47]);
  final data = ByteData.sublistView(bytes);
  return (width: data.getUint32(16), height: data.getUint32(20));
}

void main() {
  test('platform identity is consistent and Dart package is unchanged', () {
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle, contains('namespace = "com.moonlightc.aistudybuddy"'));
    expect(gradle, contains('applicationId = "com.moonlightc.aistudybuddy"'));
    expect(
      read('android/app/src/main/AndroidManifest.xml'),
      contains('android:label="AI Study Buddy"'),
    );
    final xcode = read('ios/Runner.xcodeproj/project.pbxproj');
    expect(xcode, contains('com.moonlightc.aistudybuddy;'));
    expect(xcode, contains('com.moonlightc.aistudybuddy.RunnerTests;'));
    expect(
      read('ios/Runner/Info.plist'),
      contains('<string>AI Study Buddy</string>'),
    );
    expect(read('web/index.html'), contains('<title>AI Study Buddy</title>'));
    expect(jsonDecode(read('web/manifest.json'))['name'], 'AI Study Buddy');
    expect(read('windows/runner/main.cpp'), contains('L"AI Study Buddy"'));
    expect(
      read('windows/runner/Runner.rc'),
      contains('"ProductName", "AI Study Buddy"'),
    );
    expect(read('pubspec.yaml'), contains('name: ai_study_buddy'));
  });

  test('required raster assets have exact dimensions', () {
    final android = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in android.entries) {
      expect(
        pngSize('android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png'),
        (width: entry.value, height: entry.value),
      );
    }
    for (final size in [192, 512]) {
      expect(pngSize('web/icons/Icon-$size.png'), (width: size, height: size));
      expect(pngSize('web/icons/Icon-maskable-$size.png'), (
        width: size,
        height: size,
      ));
    }
    expect(pngSize('web/icons/apple-touch-icon.png'), (
      width: 180,
      height: 180,
    ));
    expect(
      pngSize(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      ),
      (width: 1024, height: 1024),
    );
  });

  test('iOS marketing artwork is fully opaque', () async {
    final bytes = File(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    ).readAsBytesSync();
    final image = await ui
        .instantiateImageCodec(bytes)
        .then((codec) => codec.getNextFrame().then((frame) => frame.image));
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(rgba, isNotNull);
    for (var offset = 3; offset < rgba!.lengthInBytes; offset += 4) {
      expect(rgba.getUint8(offset), 255);
    }
  });

  test('Windows icon declares all required sizes', () {
    final bytes = File(
      'windows/runner/resources/app_icon.ico',
    ).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    final count = data.getUint16(4, Endian.little);
    final sizes = <int>{};
    for (var index = 0; index < count; index++) {
      final width = bytes[6 + index * 16];
      sizes.add(width == 0 ? 256 : width);
    }
    expect(sizes, containsAll(<int>[16, 20, 24, 32, 40, 48, 64, 128, 256]));
  });

  test('version maps from pubspec to platform build variables', () {
    final match = RegExp(
      r'^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$',
      multiLine: true,
    ).firstMatch(read('pubspec.yaml'));
    expect(match, isNotNull);
    expect(match!.group(0), contains('1.0.0+1'));
    expect(int.parse(match.group(4)!), greaterThan(0));
    expect(
      read('android/app/build.gradle.kts'),
      contains('versionCode = flutter.versionCode'),
    );
    expect(
      read('android/app/build.gradle.kts'),
      contains('versionName = flutter.versionName'),
    );
    expect(read('ios/Runner/Info.plist'), contains(r'$(FLUTTER_BUILD_NAME)'));
    expect(read('ios/Runner/Info.plist'), contains(r'$(FLUTTER_BUILD_NUMBER)'));
    expect(read('windows/runner/Runner.rc'), contains('FLUTTER_VERSION_BUILD'));
  });

  test('tracked files do not contain common real-secret shapes', () {
    final result = Process.runSync('git', [
      '-c',
      'safe.directory=${Directory.current.path.replaceAll('\\', '/')}',
      'ls-files',
    ]);
    expect(result.exitCode, 0);
    final paths = (result.stdout as String)
        .split(RegExp(r'\r?\n'))
        .where((path) => path.isNotEmpty);
    final patterns = <RegExp>[
      RegExp(r'sk-[A-Za-z0-9_-]{20,}'),
      RegExp(r'sb_secret_[A-Za-z0-9_-]{20,}'),
      RegExp(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    ];
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      String content;
      try {
        content = file.readAsStringSync();
      } on FileSystemException {
        continue;
      }
      for (final pattern in patterns) {
        expect(content, isNot(matches(pattern)), reason: path);
      }
    }
  });
}
