import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/material.dart';
import '../../core/models/study_session.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../../shared/widgets/section_card.dart';

class MaterialDetailScreen extends StatelessWidget {
  const MaterialDetailScreen({required this.material, super.key});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final freshMaterial = state.materialById(material.id) ?? material;
    final subject = state.subjectFor(freshMaterial.subjectId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material'),
        actions: const [AppTopActions()],
      ),
      body: AppPage(
        children: [
          Text(
            freshMaterial.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${freshMaterial.createdLabel} - pasted text',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.article_outlined,
            title: 'Pasted text',
            child: Text(
              freshMaterial.content.isEmpty
                  ? 'No pasted text available for this material.'
                  : freshMaterial.content,
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              AppStateScope.read(context).createStudySession(
                subject: subject,
                confidence: LectureConfidence.mostly,
                materialId: freshMaterial.id,
              );
              Navigator.pushNamed(
                context,
                AppRoutes.studySessionResult,
                arguments: subject,
              );
            },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Create study session'),
          ),
          const SizedBox(height: 8),
          Text(
            'Real AI generation from this material will be connected later.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
