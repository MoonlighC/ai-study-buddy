import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_data.dart';

class SubjectDetailScreen extends StatelessWidget {
  const SubjectDetailScreen({required this.subject, super.key});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final materials = MockData.materials
        .where((material) => material.subjectId == subject.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(subject.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SubjectHeader(subject: subject),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.addMaterial,
              arguments: subject,
            ),
            icon: const Icon(Icons.post_add_outlined),
            label: const Text('Add pasted text'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.studySessionResult,
              arguments: subject,
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Create study session'),
          ),
          const SizedBox(height: 24),
          Text('Materials', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final material in materials)
            Card(
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(material.title),
                subtitle: Text('${material.createdLabel} - pasted text'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.studySessionResult,
                  arguments: subject,
                ),
              ),
            ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Photo upload placeholder'),
            subtitle: const Text('Later: Supabase Storage plus OCR pipeline'),
            enabled: false,
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF upload placeholder'),
            subtitle: const Text('Later: Supabase Storage plus extraction'),
            enabled: false,
          ),
        ],
      ),
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
