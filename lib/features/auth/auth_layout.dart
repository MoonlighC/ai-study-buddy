import 'package:flutter/material.dart';

import '../../app/design_system/responsive.dart';
import '../../app/design_system/tokens.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/study_buddy_mark.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    required this.title,
    required this.subtitle,
    required this.form,
    this.formKey,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Key? formKey;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final available = constraints.maxWidth;
            final split = available >= 980 && scale <= 1.45;
            final padding = AppResponsive.horizontalPaddingFor(available);

            return SingleChildScrollView(
              key: const ValueKey('auth-scroll-view'),
              padding: EdgeInsets.fromLTRB(
                padding,
                AppSpacing.xl,
                padding,
                AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - AppSpacing.huge).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: split
                        ? Row(
                            key: const ValueKey('auth-split-layout'),
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(child: _BrandPanel()),
                              const SizedBox(width: AppSpacing.xxxl),
                              Expanded(
                                child: _FormPanel(
                                  title: title,
                                  subtitle: subtitle,
                                  form: form,
                                  formKey: formKey,
                                ),
                              ),
                            ],
                          )
                        : ConstrainedBox(
                            key: const ValueKey('auth-single-layout'),
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: _FormPanel(
                              title: title,
                              subtitle: subtitle,
                              form: form,
                              formKey: formKey,
                              showCompactBrand: true,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StudyBuddyMark(size: 64),
        const SizedBox(height: AppSpacing.xl),
        Text('AI Study Buddy', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Turn lecture material into focused study sessions, one clear step at a time.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.title,
    required this.subtitle,
    required this.form,
    this.formKey,
    this.showCompactBrand = false,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Key? formKey;
  final bool showCompactBrand;

  @override
  Widget build(BuildContext context) => GlassCard(
    key: formKey,
    depth: GlassDepth.prominent,
    reading: true,
    padding: EdgeInsets.all(
      AppResponsive.prominentSurfacePaddingFor(
        MediaQuery.sizeOf(context).width,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCompactBrand) ...[
          Row(
            children: [
              const StudyBuddyMark(size: 48),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'AI Study Buddy',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        form,
      ],
    ),
  );
}
