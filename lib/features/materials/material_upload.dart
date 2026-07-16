import 'dart:typed_data';

import '../../core/models/material.dart';

const int maxPdfUploadBytes = 10 * 1024 * 1024;
const int maxImageUploadBytes = 8 * 1024 * 1024;
const int maxMaterialFilesPerBatch = 20;

enum MaterialFileValidationCode {
  unsupportedFile,
  invalidFile,
  emptyFile,
  fileTooLarge,
}

enum MaterialFileBatchErrorCode { tooManyFiles }

class MaterialFileSelectionResult {
  const MaterialFileSelectionResult.valid(this.file) : errorCode = null;

  const MaterialFileSelectionResult.invalid(this.file, this.errorCode);

  final SelectedMaterialFile file;
  final MaterialFileValidationCode? errorCode;

  bool get isValid => errorCode == null;
}

class MaterialFilePickerBatch {
  const MaterialFilePickerBatch({
    required this.batchToken,
    required this.results,
    this.errorCode,
  });

  final String batchToken;
  final List<MaterialFileSelectionResult> results;
  final MaterialFileBatchErrorCode? errorCode;

  List<SelectedMaterialFile> get validFiles => [
    for (final result in results)
      if (result.isValid) result.file,
  ];
}

class SelectedMaterialFile {
  const SelectedMaterialFile({
    required this.name,
    required this.reportedSizeBytes,
    required this.readBytes,
  });

  final String name;
  final int reportedSizeBytes;
  final Future<Uint8List> Function() readBytes;
}

class MaterialUploadRequest {
  const MaterialUploadRequest({
    required this.materialId,
    required this.subjectId,
    required this.title,
    required this.objectFilename,
    required this.kind,
    required this.mimeType,
    required this.bytes,
  });

  final String materialId;
  final String subjectId;
  final String title;
  final String objectFilename;
  final MaterialKind kind;
  final String mimeType;
  final Uint8List bytes;

  int get fileSizeBytes => bytes.lengthInBytes;
  String get bucket =>
      kind == MaterialKind.pdf ? 'study-materials' : 'study-images';
}

class MaterialUploadValidationException implements Exception {
  const MaterialUploadValidationException(
    this.message, {
    this.code = MaterialFileValidationCode.invalidFile,
  });

  final String message;
  final MaterialFileValidationCode code;
}

MaterialFilePickerBatch validateMaterialFileBatch({
  required String batchToken,
  required List<SelectedMaterialFile> files,
  required MaterialKind expectedKind,
}) {
  if (files.length > maxMaterialFilesPerBatch) {
    return MaterialFilePickerBatch(
      batchToken: batchToken,
      results: const [],
      errorCode: MaterialFileBatchErrorCode.tooManyFiles,
    );
  }
  return MaterialFilePickerBatch(
    batchToken: batchToken,
    results: [
      for (final file in files)
        tryValidateMaterialUploadSelection(file, expectedKind),
    ],
  );
}

MaterialFileSelectionResult tryValidateMaterialUploadSelection(
  SelectedMaterialFile file,
  MaterialKind expectedKind,
) {
  try {
    validateMaterialUploadSelection(file, expectedKind);
    return MaterialFileSelectionResult.valid(file);
  } on MaterialUploadValidationException catch (error) {
    return MaterialFileSelectionResult.invalid(file, error.code);
  }
}

Future<MaterialUploadRequest> prepareMaterialUpload({
  required SelectedMaterialFile selectedFile,
  required MaterialKind expectedKind,
  required String materialId,
  required String subjectId,
}) async {
  validateMaterialUploadSelection(selectedFile, expectedKind);
  final extension = _extensionFor(selectedFile.name);

  final bytes = await selectedFile.readBytes();
  _validateSize(bytes.lengthInBytes, expectedKind);
  final mimeType = _validatedMimeType(extension, bytes, expectedKind);
  final objectFilename = sanitizeUploadFilename(
    selectedFile.name,
    fallbackExtension: extension,
  );
  return MaterialUploadRequest(
    materialId: materialId,
    subjectId: subjectId,
    title: _displayFilename(selectedFile.name, objectFilename),
    objectFilename: objectFilename,
    kind: expectedKind,
    mimeType: mimeType,
    bytes: bytes,
  );
}

void validateMaterialUploadSelection(
  SelectedMaterialFile selectedFile,
  MaterialKind expectedKind,
) {
  final extension = _extensionFor(selectedFile.name);
  _validateExtension(extension, expectedKind);
  _validateSize(selectedFile.reportedSizeBytes, expectedKind);
}

String sanitizeUploadFilename(
  String value, {
  required String fallbackExtension,
}) {
  final basename = value.replaceAll('\\', '/').split('/').last.trim();
  final dotIndex = basename.lastIndexOf('.');
  final rawStem = dotIndex > 0 ? basename.substring(0, dotIndex) : basename;
  var stem = rawStem
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[_\.]+|[_\.]+$'), '');
  if (stem.isEmpty) stem = 'material';
  if (stem.length > 100) stem = stem.substring(0, 100);
  return '$stem.${fallbackExtension.toLowerCase()}';
}

bool isCanonicalMaterialFilename({
  required String filename,
  required MaterialKind kind,
  required String mimeType,
}) {
  if (_containsUnsafePathText(filename) || filename.trim() != filename) {
    return false;
  }
  final match = RegExp(
    r'^([A-Za-z0-9-][A-Za-z0-9_-]{0,99})\.(pdf|png|jpg|jpeg|webp)$',
  ).firstMatch(filename);
  if (match == null) return false;
  final extension = match.group(2)!;
  final normalizedMime = mimeType.trim().toLowerCase();
  if (normalizedMime != mimeType || normalizedMime.isEmpty) return false;
  return switch (kind) {
    MaterialKind.pdf =>
      extension == 'pdf' && normalizedMime == 'application/pdf',
    MaterialKind.image => switch (extension) {
      'png' => normalizedMime == 'image/png',
      'jpg' || 'jpeg' => normalizedMime == 'image/jpeg',
      'webp' => normalizedMime == 'image/webp',
      _ => false,
    },
    MaterialKind.pastedText => false,
  };
}

bool isCanonicalMaterialObjectPath({
  required String path,
  required String userId,
  required String materialId,
  required MaterialKind kind,
  required String mimeType,
  String? expectedFilename,
}) {
  if (path.trim() != path ||
      path.contains('//') ||
      _containsUnsafePathText(path)) {
    return false;
  }
  final segments = path.split('/');
  if (segments.length != 3 ||
      segments[0] != userId ||
      segments[1] != materialId) {
    return false;
  }
  final filename = segments[2];
  if (expectedFilename != null && filename != expectedFilename) return false;
  return isCanonicalMaterialFilename(
    filename: filename,
    kind: kind,
    mimeType: mimeType,
  );
}

bool _containsUnsafePathText(String value) {
  if (value.isEmpty ||
      value.contains('..') ||
      value.contains('\\') ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(value) ||
      RegExp(r'[\u2044\u2215\u29F5\uFF0F\uFF3C\uFE68]').hasMatch(value)) {
    return true;
  }
  if (!value.contains('%')) return false;
  var decoded = value;
  for (var pass = 0; pass < 2; pass += 1) {
    try {
      final next = Uri.decodeComponent(decoded);
      if (next != decoded) return true;
      decoded = next;
    } on FormatException {
      return true;
    }
  }
  return true;
}

String _displayFilename(String value, String fallback) {
  final basename = value.replaceAll('\\', '/').split('/').last.trim();
  return basename.isEmpty ? fallback : basename;
}

String _extensionFor(String filename) {
  final basename = filename.replaceAll('\\', '/').split('/').last;
  final dotIndex = basename.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == basename.length - 1) return '';
  return basename.substring(dotIndex + 1).toLowerCase();
}

void _validateExtension(String extension, MaterialKind kind) {
  final valid = switch (kind) {
    MaterialKind.pdf => extension == 'pdf',
    MaterialKind.image => const {
      'png',
      'jpg',
      'jpeg',
      'webp',
    }.contains(extension),
    MaterialKind.pastedText => false,
  };
  if (!valid) {
    throw const MaterialUploadValidationException(
      'Choose a supported PDF, PNG, JPG, JPEG, or WEBP file.',
      code: MaterialFileValidationCode.unsupportedFile,
    );
  }
}

void _validateSize(int bytes, MaterialKind kind) {
  final limit = kind == MaterialKind.pdf
      ? maxPdfUploadBytes
      : maxImageUploadBytes;
  if (bytes < 1) {
    throw const MaterialUploadValidationException(
      'The selected file is empty.',
      code: MaterialFileValidationCode.emptyFile,
    );
  }
  if (bytes > limit) {
    throw MaterialUploadValidationException(
      'The selected file exceeds $limit bytes.',
      code: MaterialFileValidationCode.fileTooLarge,
    );
  }
}

String _validatedMimeType(
  String extension,
  Uint8List bytes,
  MaterialKind kind,
) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  if (kind == MaterialKind.pdf &&
      startsWith(const [0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return 'application/pdf';
  }
  if (extension == 'png' &&
      startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if ((extension == 'jpg' || extension == 'jpeg') &&
      startsWith(const [0xFF, 0xD8, 0xFF])) {
    return 'image/jpeg';
  }
  if (extension == 'webp' &&
      bytes.length >= 12 &&
      startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  throw const MaterialUploadValidationException(
    'The file contents do not match the selected file type.',
  );
}
