import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/subject.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../../shared/widgets/section_card.dart';

class SubjectDetailScreen extends StatelessWidget {
  const SubjectDetailScreen({required this.subject, super.key});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final materials = AppStateScope.watch(context).materialsFor(subject.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name),
        actions: const [AppTopActions()],
      ),
      body: AppPage(
        children: [
          _SubjectHeader(subject: subject),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Study actions',
            subtitle: 'Use local mock content for this subject.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.addMaterial,
                    arguments: subject,
                  ),
                  icon: const Icon(Icons.post_add_outlined),
                  label: const Text('Add pasted text'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.studySessionResult,
                    arguments: subject,
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Create study session'),
                ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.article_outlined,
            title: 'Materials',
            child: Column(
              children: [
                for (final material in materials)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(material.title),
                    subtitle: Text('${material.createdLabel} - pasted text'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.materialDetail,
                      arguments: material,
                    ),
                  ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.hourglass_empty_outlined,
            title: 'Coming later',
            subtitle: 'Visible placeholders only; no upload is performed.',
            child: const Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.image_outlined),
                  title: Text('Photo upload placeholder'),
                  subtitle: Text('Later: storage plus OCR pipeline'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('PDF upload placeholder'),
                  subtitle: Text('Later: storage plus extraction'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Color(subject.colorValue).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Color(subject.colorValue),
              child: Text(
                subject.name.characters.first,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(subject.description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
