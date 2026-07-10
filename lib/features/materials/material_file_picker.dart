import 'package:file_picker/file_picker.dart';

import '../../core/models/material.dart';
import 'material_upload.dart';

abstract class MaterialFilePicker {
  Future<SelectedMaterialFile?> pick(MaterialKind kind);
}

class PlatformMaterialFilePicker implements MaterialFilePicker {
  const PlatformMaterialFilePicker();

  @override
  Future<SelectedMaterialFile?> pick(MaterialKind kind) async {
    final extensions = kind == MaterialKind.pdf
        ? const ['pdf']
        : const ['png', 'jpg', 'jpeg', 'webp'];
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final xFile = file.xFile;
    return SelectedMaterialFile(
      name: file.name,
      reportedSizeBytes: file.size,
      readBytes: xFile.readAsBytes,
    );
  }
}
