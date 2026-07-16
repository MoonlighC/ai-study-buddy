import 'package:file_picker/file_picker.dart';

import '../../core/models/material.dart';
import '../../core/utils/uuid.dart';
import 'material_upload.dart';

abstract class MaterialFilePicker {
  Future<SelectedMaterialFile?> pick(MaterialKind kind);
}

abstract class MultiMaterialFilePicker implements MaterialFilePicker {
  Future<MaterialFilePickerBatch?> pickMultiple(MaterialKind kind) async {
    final file = await pick(kind);
    if (file == null) return null;
    return validateMaterialFileBatch(
      batchToken: newUuidV4(),
      files: [file],
      expectedKind: kind,
    );
  }
}

class PlatformMaterialFilePicker implements MultiMaterialFilePicker {
  const PlatformMaterialFilePicker();

  @override
  Future<SelectedMaterialFile?> pick(MaterialKind kind) async {
    final files = await _pickFiles(kind, allowMultiple: false);
    return files?.singleOrNull;
  }

  @override
  Future<MaterialFilePickerBatch?> pickMultiple(MaterialKind kind) async {
    final files = await _pickFiles(kind, allowMultiple: true);
    if (files == null) return null;
    return validateMaterialFileBatch(
      batchToken: newUuidV4(),
      files: files,
      expectedKind: kind,
    );
  }

  Future<List<SelectedMaterialFile>?> _pickFiles(
    MaterialKind kind, {
    required bool allowMultiple,
  }) async {
    final extensions = kind == MaterialKind.pdf
        ? const ['pdf']
        : const ['png', 'jpg', 'jpeg', 'webp'];
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: allowMultiple,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return [
      for (final file in result.files)
        SelectedMaterialFile(
          name: file.name,
          reportedSizeBytes: file.size,
          readBytes: file.xFile.readAsBytes,
        ),
    ];
  }
}
