import 'dart:async';

import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_lifecycle_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const user = AuthUser(
  id: 'user',
  email: 'student@example.test',
  displayName: 'Student',
);
const material = StudyMaterial(
  id: 'material',
  subjectId: 'biology',
  title: 'Notes',
  kind: MaterialKind.pastedText,
  content: 'Long enough notes for lifecycle testing.',
  createdLabel: 'Today',
);

void main() {
  test('successful deletion removes visible material', () async {
    final lifecycle = _Lifecycle();
    final state = AppState(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [material],
      ),
      materialLifecycleRepository: lifecycle,
    );
    await state.loadMaterialsFor(user);
    expect(await state.deleteMaterialFor(user, material.id), isTrue);
    expect(state.materialById(material.id), isNull);
    expect(lifecycle.deleteCalls, 1);
  });

  test('duplicate deletion is prevented while request is active', () async {
    final gate = Completer<void>();
    final lifecycle = _Lifecycle(gate: gate);
    final state = AppState(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [material],
      ),
      materialLifecycleRepository: lifecycle,
    );
    await state.loadMaterialsFor(user);
    final first = state.deleteMaterialFor(user, material.id);
    expect(state.isDeletingMaterial(material.id), isTrue);
    expect(await state.deleteMaterialFor(user, material.id), isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(lifecycle.deleteCalls, 1);
  });

  test('failure preserves local material and exposes safe error', () async {
    final state = AppState(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [material],
      ),
      materialLifecycleRepository: _Lifecycle(fail: true),
    );
    await state.loadMaterialsFor(user);
    expect(await state.deleteMaterialFor(user, material.id), isFalse);
    expect(state.materialById(material.id), isNotNull);
    expect(
      state.materialLifecycleErrorFor(material.id),
      'Could not delete the material. Try again.',
    );
  });

  test('lost response reconciles absent material as success', () async {
    final state = AppState(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [material],
      ),
      materialLifecycleRepository: _Lifecycle(
        fail: true,
        existsAfterFailure: false,
      ),
    );
    await state.loadMaterialsFor(user);

    expect(await state.deleteMaterialFor(user, material.id), isTrue);
    expect(state.materialById(material.id), isNull);
    expect(state.materialLifecycleErrorFor(material.id), isNull);
  });
}

class _Lifecycle implements MaterialLifecycleRepository {
  _Lifecycle({this.gate, this.fail = false, this.existsAfterFailure});
  final Completer<void>? gate;
  final bool fail;
  final bool? existsAfterFailure;
  int deleteCalls = 0;
  @override
  Future<void> deleteMaterial({
    required AuthUser user,
    required String materialId,
  }) async {
    deleteCalls++;
    if (gate != null) {
      await gate!.future;
    }
    if (fail) {
      throw const MaterialLifecycleException(
        'Could not delete the material. Try again.',
      );
    }
  }

  @override
  Future<MaterialRecoveryEligibility> inspectRecovery({
    required AuthUser user,
    required String materialId,
  }) async => const MaterialRecoveryEligibility(eligible: false);
  @override
  Future<void> recover({
    required AuthUser user,
    required String materialId,
    required String processor,
  }) async {}

  @override
  Future<bool?> materialExists({
    required AuthUser user,
    required String materialId,
  }) async => existsAfterFailure ?? (fail ? true : null);
}
