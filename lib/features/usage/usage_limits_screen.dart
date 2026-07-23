import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../features/auth/auth_controller.dart';
import '../../l10n/l10n_extensions.dart';
import '../../l10n/localized_formatters.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import 'usage_status_repository.dart';

class UsageLimitsScreen extends StatefulWidget {
  const UsageLimitsScreen({super.key});

  @override
  State<UsageLimitsScreen> createState() => _UsageLimitsScreenState();
}

class _UsageLimitsScreenState extends State<UsageLimitsScreen> {
  Future<UsageStatus>? _load;
  String? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AuthScope.read(context).user;
    if (user?.id == _userId && _load != null) return;
    _userId = user?.id;
    _load = user == null
        ? Future<UsageStatus>.error(const UsageStatusRepositoryException())
        : AppStateScope.read(
            context,
          ).usageStatusRepository.loadUsageStatus(user);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ResponsiveAppScaffold(
      title: l10n.usageTitle,
      activeRoute: AppRoutes.usage,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: FutureBuilder<UsageStatus>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final status = snapshot.data;
            if (status == null) {
              return ErrorRetryState(
                message: l10n.usageUnavailableTitle,
                supportingText: l10n.usageUnavailableMessage,
                onRetry: _reload,
              );
            }
            return _UsageStatusView(status: status);
          },
        ),
      ),
    );
  }

  void _reload() {
    final user = AuthScope.read(context).user;
    setState(() {
      _load = user == null
          ? Future<UsageStatus>.error(const UsageStatusRepositoryException())
          : AppStateScope.read(
              context,
            ).usageStatusRepository.loadUsageStatus(user);
    });
  }
}

class _UsageStatusView extends StatelessWidget {
  const _UsageStatusView({required this.status});

  final UsageStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final costFormat = NumberFormat('0.00####', l10n.localeName);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassSurface(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.isUnlimitedTester
                      ? l10n.usageTesterTitle
                      : l10n.usageStandardTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (status.isUnlimitedTester) ...[
                  const SizedBox(height: 8),
                  Text(l10n.usageTesterMessage),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _UsageRow(
            icon: Icons.style_outlined,
            label: l10n.usageFlashcards,
            value: status.flashcardsDailyLimit == null
                ? l10n.usageCountToday(status.flashcardsUsedToday)
                : l10n.usageCountOfLimit(
                    status.flashcardsUsedToday,
                    status.flashcardsDailyLimit!,
                  ),
          ),
          const SizedBox(height: 12),
          _UsageRow(
            icon: Icons.quiz_outlined,
            label: l10n.usageQuizQuestions,
            value: status.quizQuestionsDailyLimit == null
                ? l10n.usageCountToday(status.quizQuestionsUsedToday)
                : l10n.usageCountOfLimit(
                    status.quizQuestionsUsedToday,
                    status.quizQuestionsDailyLimit!,
                  ),
          ),
          const SizedBox(height: 12),
          _UsageRow(
            icon: Icons.payments_outlined,
            label: l10n.usageEstimatedCost,
            value: status.estimatedCostDailyLimit == null
                ? l10n.usageCostToday(
                    costFormat.format(status.estimatedCostUsedToday),
                  )
                : l10n.usageCostOfLimit(
                    costFormat.format(status.estimatedCostUsedToday),
                    costFormat.format(status.estimatedCostDailyLimit),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.usageActiveReservations(status.activeReservations),
            key: const ValueKey('usage-active-reservations'),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.usageResetAt(
              LocalizedFormatters.dateTime(l10n, status.resetAt),
            ),
            key: const ValueKey('usage-reset-at'),
          ),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => GlassSurface(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
