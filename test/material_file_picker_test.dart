import 'dart:typed_data';

import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/materials/material_file_picker.dart';
import 'package:ai_study_buddy/features/materials/material_upload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single-file picker remains compatible', () async {
    final picker = _SinglePicker(_pdf('one.pdf'));
    final selected = await picker.pick(MaterialKind.pdf);
    expect(selected?.name, 'one.pdf');
    final batch = validateMaterialFileBatch(
      batchToken: 'single',
      files: [selected!],
      expectedKind: MaterialKind.pdf,
    );
    expect(batch.validFiles.single.name, 'one.pdf');
  });

  test('valid siblings survive per-file preflight failures', () {
    final batch = validateMaterialFileBatch(
      batchToken: 'mixed',
      files: [
        _pdf('one.pdf'),
        SelectedMaterialFile(
          name: 'unsupported.txt',
          reportedSizeBytes: 5,
          readBytes: () async => Uint8List(5),
        ),
        _pdf('two.pdf'),
      ],
      expectedKind: MaterialKind.pdf,
    );
    expect(batch.validFiles.map((file) => file.name), ['one.pdf', 'two.pdf']);
    expect(
      batch.results[1].errorCode,
      MaterialFileValidationCode.unsupportedFile,
    );
  });

  test('20 files are accepted and 21 are rejected without truncation', () {
    final accepted = validateMaterialFileBatch(
      batchToken: 'twenty',
      files: List.generate(20, (index) => _pdf('$index.pdf')),
      expectedKind: MaterialKind.pdf,
    );
    expect(accepted.validFiles, hasLength(20));
    final rejected = validateMaterialFileBatch(
      batchToken: 'twenty-one',
      files: List.generate(21, (index) => _pdf('$index.pdf')),
      expectedKind: MaterialKind.pdf,
    );
    expect(rejected.errorCode, MaterialFileBatchErrorCode.tooManyFiles);
    expect(rejected.results, isEmpty);
  });

  test('signature validation reads the active file only once', () async {
    var reads = 0;
    final file = SelectedMaterialFile(
      name: 'spoofed.pdf',
      reportedSizeBytes: 8,
      readBytes: () async {
        reads += 1;
        return Uint8List.fromList('not-pdf!'.codeUnits);
      },
    );
    await expectLater(
      prepareMaterialUpload(
        selectedFile: file,
        expectedKind: MaterialKind.pdf,
        materialId: 'material',
        subjectId: 'subject',
      ),
      throwsA(isA<MaterialUploadValidationException>()),
    );
    expect(reads, 1);
  });
}

SelectedMaterialFile _pdf(String name) {
  final bytes = Uint8List.fromList('%PDF-1.7'.codeUnits);
  return SelectedMaterialFile(
    name: name,
    reportedSizeBytes: bytes.length,
    readBytes: () async => bytes,
  );
}

class _SinglePicker implements MaterialFilePicker {
  _SinglePicker(this.file);

  final SelectedMaterialFile file;

  @override
  Future<SelectedMaterialFile?> pick(MaterialKind kind) async => file;
}
