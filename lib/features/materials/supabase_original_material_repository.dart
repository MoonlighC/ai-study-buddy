import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/models/material.dart';
import '../auth/auth_models.dart';
import 'material_row_mapper.dart';
import 'original_material_repository.dart';

class OriginalStorageObjectMetadata {
  const OriginalStorageObjectMetadata({required this.sizeBytes, this.mimeType});

  final int sizeBytes;
  final String? mimeType;
}

abstract class OriginalMaterialDataSource {
  String? get currentUserId;

  Future<Map<String, dynamic>?> findMaterial({
    required String materialId,
    required String userId,
  });

  Future<OriginalStorageObjectMetadata?> findObject({
    required String bucket,
    required String path,
  });

  Future<Uint8List> download({required String bucket, required String path});
}

class SupabaseOriginalMaterialDataSource implements OriginalMaterialDataSource {
  const SupabaseOriginalMaterialDataSource(this._client);

  final supabase.SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<Map<String, dynamic>?> findMaterial({
    required String materialId,
    required String userId,
  }) => _client
      .from('materials')
      .select(materialSelectColumns)
      .eq('id', materialId)
      .eq('user_id', userId)
      .filter('deleted_at', 'is', null)
      .maybeSingle();

  @override
  Future<OriginalStorageObjectMetadata?> findObject({
    required String bucket,
    required String path,
  }) async {
    final segments = path.split('/');
    if (segments.length != 3) return null;
    final filename = segments[2];
    final objects = await _client.storage
        .from(bucket)
        .list(
          path: '${segments[0]}/${segments[1]}',
          searchOptions: supabase.SearchOptions(search: filename, limit: 100),
        );
    for (final object in objects) {
      if (object.name != filename) continue;
      final metadata = object.metadata;
      final size = metadata?['size'];
      if (size is! num) return null;
      final mime = metadata?['mimetype'] ?? metadata?['contentType'];
      return OriginalStorageObjectMetadata(
        sizeBytes: size.toInt(),
        mimeType: mime is String ? mime : null,
      );
    }
    return null;
  }

  @override
  Future<Uint8List> download({required String bucket, required String path}) =>
      _client.storage.from(bucket).download(path);
}

class SupabaseOriginalMaterialRepository implements OriginalMaterialRepository {
  const SupabaseOriginalMaterialRepository(this._dataSource);

  final OriginalMaterialDataSource _dataSource;

  @override
  Future<OriginalMaterialLoadResult> load({
    required AuthUser expectedUser,
    required String materialId,
    required MaterialKind expectedKind,
  }) async {
    final currentUserId = _dataSource.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.sessionExpired,
      );
    }
    if (currentUserId != expectedUser.id) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.authorizationDenied,
      );
    }

    Map<String, dynamic>? row;
    try {
      row = await _dataSource.findMaterial(
        materialId: materialId,
        userId: currentUserId,
      );
    } catch (error) {
      return OriginalMaterialFailure(_failureCodeFor(error));
    }
    if (row == null) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.materialUnavailable,
      );
    }
    StudyMaterial material;
    try {
      material = mapMaterialRow(row);
    } catch (_) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.invalidMetadata,
      );
    }
    if (material.id != materialId || material.kind != expectedKind) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.wrongSourceType,
      );
    }
    if (!hasValidOriginalMetadata(material, currentUserId)) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.invalidMetadata,
      );
    }

    final limit = previewByteLimit(expectedKind);
    if (material.fileSizeBytes! > limit) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.previewTooLarge,
      );
    }
    OriginalStorageObjectMetadata? object;
    try {
      object = await _dataSource.findObject(
        bucket: material.storageBucket!,
        path: material.storagePath!,
      );
    } catch (error) {
      return OriginalMaterialFailure(_failureCodeFor(error));
    }
    if (object == null) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.objectNotFound,
      );
    }
    if (object.sizeBytes > limit) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.previewTooLarge,
      );
    }
    final objectMime = object.mimeType;
    if (object.sizeBytes != material.fileSizeBytes ||
        objectMime == null ||
        objectMime.isEmpty ||
        objectMime != objectMime.trim().toLowerCase() ||
        objectMime == 'application/octet-stream' ||
        objectMime != material.mimeType) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.invalidMetadata,
      );
    }

    Uint8List bytes;
    try {
      bytes = await _dataSource.download(
        bucket: material.storageBucket!,
        path: material.storagePath!,
      );
    } catch (error) {
      final code = _failureCodeFor(error);
      return OriginalMaterialFailure(code);
    }
    if (bytes.lengthInBytes > limit) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.previewTooLarge,
      );
    }
    if (bytes.lengthInBytes != material.fileSizeBytes ||
        !hasExpectedOriginalSignature(
          expectedKind,
          material.mimeType!,
          bytes,
        )) {
      return const OriginalMaterialFailure(
        OriginalMaterialFailureCode.invalidMetadata,
      );
    }
    return OriginalMaterialSuccess.fromTrustedBytes(
      kind: expectedKind,
      bytes: bytes,
    );
  }
}

OriginalMaterialFailureCode _failureCodeFor(Object error) {
  if (error is supabase.AuthException) {
    return OriginalMaterialFailureCode.sessionExpired;
  }
  if (error is supabase.StorageException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 401) return OriginalMaterialFailureCode.sessionExpired;
    if (status == 403) return OriginalMaterialFailureCode.authorizationDenied;
    if (status == 404) return OriginalMaterialFailureCode.objectNotFound;
  }
  if (error is supabase.PostgrestException) {
    if (const {'42501', 'PGRST301'}.contains(error.code)) {
      return OriginalMaterialFailureCode.authorizationDenied;
    }
  }
  return OriginalMaterialFailureCode.networkFailure;
}
