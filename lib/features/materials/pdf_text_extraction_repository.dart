import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/material.dart';
import '../auth/auth_models.dart';
import 'material_row_mapper.dart';

const noSelectablePdfTextMessage =
    'No selectable text was found. Scanned PDFs will be supported in the OCR phase.';

class PdfTextExtractionResult {
  const PdfTextExtractionResult({required this.material, this.errorMessage});

  final StudyMaterial material;
  final String? errorMessage;
  bool get succeeded => errorMessage == null;
}

abstract class PdfTextExtractionRepository {
  Future<PdfTextExtractionResult> extractPdfText({
    required AuthUser user,
    required String materialId,
  });
}

class PdfTextExtractionException implements Exception {
  const PdfTextExtractionException(this.message);
  final String message;
}

abstract class PdfTextExtractionDataSource {
  Future<Object?> invoke(String materialId);
}

class SupabasePdfTextExtractionDataSource
    implements PdfTextExtractionDataSource {
  const SupabasePdfTextExtractionDataSource(this._client);
  final supabase.SupabaseClient _client;

  @override
  Future<Object?> invoke(String materialId) async {
    final response = await _client.functions.invoke(
      'extract-pdf-text',
      body: <String, String>{'material_id': materialId},
    );
    return response.data;
  }
}

class SupabasePdfTextExtractionRepository
    implements PdfTextExtractionRepository {
  const SupabasePdfTextExtractionRepository(this._dataSource);
  final PdfTextExtractionDataSource _dataSource;

  @override
  Future<PdfTextExtractionResult> extractPdfText({
    required AuthUser user,
    required String materialId,
  }) async {
    try {
      final raw = await _dataSource.invoke(materialId);
      if (raw is! Map) throw const PdfTextExtractionException(_genericError);
      final data = Map<String, dynamic>.from(raw);
      final materialRaw = data['material'];
      if (materialRaw is! Map) {
        throw const PdfTextExtractionException(_genericError);
      }
      final material = mapMaterialRow(Map<String, dynamic>.from(materialRaw));
      final errorRaw = data['error'];
      final error = errorRaw is Map
          ? _safeMessage(Map<String, dynamic>.from(errorRaw)['message'])
          : null;
      return PdfTextExtractionResult(
        material: material,
        errorMessage: data['ok'] == true ? null : error ?? _genericError,
      );
    } on PdfTextExtractionException {
      rethrow;
    } catch (_) {
      throw const PdfTextExtractionException(_genericError);
    }
  }

  static const _genericError = 'Could not extract text. Try again.';

  String? _safeMessage(Object? value) {
    if (value == noSelectablePdfTextMessage) {
      return noSelectablePdfTextMessage;
    }
    if (value == 'The uploaded file is not a valid PDF.') {
      return value as String;
    }
    if (value == 'Could not read the uploaded PDF.') {
      return value as String;
    }
    return null;
  }
}

class MockPdfTextExtractionRepository implements PdfTextExtractionRepository {
  const MockPdfTextExtractionRepository();

  @override
  Future<PdfTextExtractionResult> extractPdfText({
    required AuthUser user,
    required String materialId,
  }) async {
    final material = StudyMaterial(
      id: materialId,
      subjectId: 'biology',
      title: 'Mock PDF',
      kind: MaterialKind.pdf,
      content:
          'Deterministic extracted PDF text for mock mode. It contains enough detail for summaries, flashcards, quizzes, and a study session.',
      createdLabel: 'Just now',
      sourceKind: MaterialSourceKind.upload,
      storageBucket: 'study-materials',
      storagePath: '${user.id}/$materialId/mock.pdf',
      mimeType: 'application/pdf',
      fileSizeBytes: 1024,
      processingStatus: MaterialProcessingStatus.ready,
      pdfExtraction: PdfExtractionMetadata(
        extractedAt: DateTime.utc(2026, 1, 1),
        characterCount: 132,
        pageCount: 2,
        extractionVersion: 'pdf-text-v1',
      ),
    );
    return PdfTextExtractionResult(material: material);
  }
}

class EmptyPdfTextExtractionRepository implements PdfTextExtractionRepository {
  const EmptyPdfTextExtractionRepository();

  @override
  Future<PdfTextExtractionResult> extractPdfText({
    required AuthUser user,
    required String materialId,
  }) {
    throw const PdfTextExtractionException(
      'PDF text extraction is not configured.',
    );
  }
}
