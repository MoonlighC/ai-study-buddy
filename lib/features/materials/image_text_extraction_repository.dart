import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/material.dart';
import '../auth/auth_models.dart';
import 'material_row_mapper.dart';

const noReadableImageTextMessage = 'No readable text was found in this image.';

class ImageTextExtractionResult {
  const ImageTextExtractionResult({required this.material, this.errorMessage});
  final StudyMaterial material;
  final String? errorMessage;
  bool get succeeded => errorMessage == null;
}

abstract class ImageTextExtractionRepository {
  Future<ImageTextExtractionResult> extractImageText({
    required AuthUser user,
    required String materialId,
  });
}

class ImageTextExtractionException implements Exception {
  const ImageTextExtractionException(this.message);
  final String message;
}

abstract class ImageTextExtractionDataSource {
  Future<Object?> invoke(String materialId);
}

class SupabaseImageTextExtractionDataSource
    implements ImageTextExtractionDataSource {
  const SupabaseImageTextExtractionDataSource(this._client);
  final supabase.SupabaseClient _client;
  @override
  Future<Object?> invoke(String materialId) async =>
      (await _client.functions.invoke(
        'extract-image-text',
        body: <String, String>{'material_id': materialId},
      )).data;
}

class SupabaseImageTextExtractionRepository
    implements ImageTextExtractionRepository {
  const SupabaseImageTextExtractionRepository(this._source);
  final ImageTextExtractionDataSource _source;
  @override
  Future<ImageTextExtractionResult> extractImageText({
    required AuthUser user,
    required String materialId,
  }) async {
    try {
      final raw = await _source.invoke(materialId);
      if (raw is! Map) throw const ImageTextExtractionException(_generic);
      final data = Map<String, dynamic>.from(raw);
      final row = data['material'];
      if (row is! Map) throw const ImageTextExtractionException(_generic);
      final material = mapMaterialRow(Map<String, dynamic>.from(row));
      final error = data['error'];
      final message = error is Map
          ? _safeMessage(Map<String, dynamic>.from(error)['message'])
          : null;
      return ImageTextExtractionResult(
        material: material,
        errorMessage: data['ok'] == true ? null : message ?? _generic,
      );
    } on ImageTextExtractionException {
      rethrow;
    } catch (_) {
      throw const ImageTextExtractionException(_generic);
    }
  }

  static const _generic = 'Could not extract image text. Try again.';
  String? _safeMessage(Object? value) =>
      const {
        noReadableImageTextMessage,
        'Could not read the uploaded image.',
        'The uploaded file is not a valid supported image.',
      }.contains(value)
      ? value as String
      : null;
}

class MockImageTextExtractionRepository
    implements ImageTextExtractionRepository {
  const MockImageTextExtractionRepository();
  @override
  Future<ImageTextExtractionResult> extractImageText({
    required AuthUser user,
    required String materialId,
  }) async {
    return ImageTextExtractionResult(
      material: StudyMaterial(
        id: materialId,
        subjectId: 'biology',
        title: 'Mock image',
        kind: MaterialKind.image,
        content:
            'Deterministic image OCR text with enough useful study content for summaries, flashcards, quizzes, and focused study sessions.',
        createdLabel: 'Just now',
        sourceKind: MaterialSourceKind.upload,
        storageBucket: 'study-images',
        storagePath: '${user.id}/$materialId/mock.png',
        mimeType: 'image/png',
        fileSizeBytes: 1024,
        processingStatus: MaterialProcessingStatus.ready,
        imageOcr: ImageOcrMetadata(
          extractedAt: DateTime.utc(2026, 1, 1),
          characterCount: 119,
          extractionVersion: 'image-ocr-v1',
          provider: 'mock',
          model: 'mock',
        ),
      ),
    );
  }
}

class EmptyImageTextExtractionRepository
    implements ImageTextExtractionRepository {
  const EmptyImageTextExtractionRepository();
  @override
  Future<ImageTextExtractionResult> extractImageText({
    required AuthUser user,
    required String materialId,
  }) => throw const ImageTextExtractionException(
    'Image text extraction is not configured.',
  );
}
