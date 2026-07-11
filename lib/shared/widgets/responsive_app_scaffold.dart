import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/design_system/effects.dart';
import '../../app/design_system/responsive.dart';
import '../../app/design_system/theme_extensions.dart';
import '../../app/design_system/tokens.dart';
import '../../app/routes.dart';
import 'glass_components.dart';
import 'study_buddy_mark.dart';

class AtmosphericBackground extends StatelessWidget {
  const AtmosphericBackground({this.subjectColor, super.key});

  final Color? subjectColor;

  @override
  Widget build(BuildContext context) {
    final subjectGlow = subjectColor ?? AppColors.atmosphericMint;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFD), Color(0xFFDDE9F8), Color(0xFFF0E7F7)],
            stops: [0, 0.52, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -40,
              child: _Glow(
                color: AppColors.atmosphericBlue,
                size: 430,
                opacity: 0.72,
              ),
            ),
            Positioned(
              bottom: -130,
              left: -80,
              child: _Glow(
                color: AppColors.atmosphericLilac,
                size: 480,
                opacity: 0.68,
              ),
            ),
            Positioned(
              top: 170,
              left: 80,
              child: _Glow(color: subjectGlow, size: 310, opacity: 0.62),
            ),
            Positioned(
              bottom: -100,
              left: 20,
              right: 20,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _Glow(
                  color: AppColors.atmosphericMint,
                  size: 390,
                  opacity: 0.54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.24),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.48, 1],
      ),
    ),
  );
}

enum ResponsiveContentWidth { reading, standard, wide }

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.width = ResponsiveContentWidth.standard,
    this.padding,
    super.key,
  });

  final Widget child;
  final ResponsiveContentWidth width;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = AppResponsive.horizontalPaddingFor(
        constraints.maxWidth,
      );
      final maxWidth = switch (width) {
        ResponsiveContentWidth.reading => AppContentWidths.reading,
        ResponsiveContentWidth.standard => AppContentWidths.standard,
        ResponsiveContentWidth.wide => AppContentWidths.wide,
      };
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            key: const ValueKey('responsive-content-padding'),
            padding:
                padding ??
                EdgeInsets.fromLTRB(
                  horizontal,
                  8,
                  horizontal,
                  AppResponsive.windowClassFor(constraints.maxWidth) ==
                          AppWindowClass.phone
                      ? AppShellMetrics.phoneNavigationScrollClearance +
                            MediaQuery.paddingOf(context).bottom
                      : 32,
                ),
            child: child,
          ),
        ),
      );
    },
  );
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.showSearch = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final bool showSearch;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              key: const ValueKey('app-back-button'),
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            )
          else
            const _AppMark(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (showSearch)
            IconButton(
              key: const ValueKey('top-search-action'),
              tooltip: 'Search',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
              icon: const Icon(Icons.search),
            ),
        ],
      ),
    ),
  );
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 40,
    child: Padding(padding: EdgeInsets.all(2), child: StudyBuddyMark()),
  );
}

class ResponsiveAppScaffold extends StatelessWidget {
  const ResponsiveAppScaffold({
    required this.title,
    required this.body,
    this.subtitle,
    this.activeRoute,
    this.showBack = false,
    this.showNavigation = true,
    this.subjectColor,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final String? activeRoute;
  final bool showBack;
  final bool showNavigation;
  final Color? subjectColor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final windowClass = AppResponsive.windowClassFor(constraints.maxWidth);
      final phone = windowClass == AppWindowClass.phone;
      final extended = windowClass == AppWindowClass.desktop;
      final topBar = AppTopBar(
        title: title,
        subtitle: subtitle,
        showBack: showBack,
      );
      final mediaPadding = MediaQuery.paddingOf(context);
      final railWorkspaceInset = !showNavigation
          ? 0.0
          : extended
          ? AppShellMetrics.extendedRailWorkspaceInset
          : AppShellMetrics.compactRailWorkspaceInset;

      return Stack(
        fit: StackFit.expand,
        children: [
          AtmosphericBackground(subjectColor: subjectColor),
          Scaffold(
            key: const ValueKey('responsive-app-scaffold'),
            backgroundColor: Colors.transparent,
            body: phone
                ? Column(
                    children: [
                      topBar,
                      Expanded(
                        child: !showNavigation
                            ? body
                            : Stack(
                                key: const ValueKey(
                                  'phone-shell-overlay-stack',
                                ),
                                children: [
                                  Positioned.fill(child: body),
                                  Positioned(
                                    left: AppShellMetrics
                                        .phoneNavigationHorizontalInset,
                                    right: AppShellMetrics
                                        .phoneNavigationHorizontalInset,
                                    bottom:
                                        AppShellMetrics
                                            .phoneNavigationBottomInset +
                                        mediaPadding.bottom,
                                    child: GlassNavigationBar(
                                      activeRoute: activeRoute,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  )
                : Stack(
                    key: const ValueKey('desktop-shell-overlay-stack'),
                    children: [
                      Positioned.fill(
                        left: railWorkspaceInset,
                        child: Column(
                          children: [
                            topBar,
                            Expanded(child: body),
                          ],
                        ),
                      ),
                      if (showNavigation)
                        Positioned(
                          left: 16 + mediaPadding.left,
                          top: 16 + mediaPadding.top,
                          child: GlassNavigationRail(
                            activeRoute: activeRoute,
                            extended: extended,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

const _destinations = [
  _Destination('Home', Icons.home_outlined, Icons.home, AppRoutes.dashboard),
  _Destination(
    'Subjects',
    Icons.folder_outlined,
    Icons.folder,
    AppRoutes.subjects,
  ),
  _Destination(
    'Favorites',
    Icons.star_outline,
    Icons.star,
    AppRoutes.favorites,
  ),
  _Destination(
    'Progress',
    Icons.trending_up_outlined,
    Icons.trending_up,
    AppRoutes.progress,
  ),
  _Destination(
    'Settings',
    Icons.settings_outlined,
    Icons.settings,
    AppRoutes.settings,
  ),
];

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({required this.activeRoute, super.key});

  final String? activeRoute;

  @override
  Widget build(BuildContext context) => GlassSurface(
    key: const ValueKey('glass-navigation-bar'),
    depth: GlassDepth.prominent,
    blurSigma: 20,
    tint: context.glassTheme.navigationTint,
    borderRadius: BorderRadius.circular(AppRadii.navigation),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    child: Row(
      children: [
        for (final destination in _destinations)
          Expanded(
            child: _NavigationDestination(
              destination: destination,
              active: activeRoute == destination.route,
              showLabel: true,
            ),
          ),
      ],
    ),
  );
}

class GlassNavigationRail extends StatelessWidget {
  const GlassNavigationRail({
    required this.activeRoute,
    required this.extended,
    super.key,
  });

  final String? activeRoute;
  final bool extended;

  @override
  Widget build(BuildContext context) => GlassSurface(
    key: const ValueKey('glass-navigation-rail'),
    depth: GlassDepth.prominent,
    blurSigma: 20,
    tint: context.glassTheme.navigationTint.withValues(alpha: 0.18),
    borderRadius: BorderRadius.circular(AppRadii.navigation),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
    child: SizedBox(
      width: extended ? 168 : 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final destination in _destinations) ...[
            _NavigationDestination(
              destination: destination,
              active: activeRoute == destination.route,
              showLabel: extended,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    ),
  );
}

class _NavigationDestination extends StatefulWidget {
  const _NavigationDestination({
    required this.destination,
    required this.active,
    required this.showLabel,
  });

  final _Destination destination;
  final bool active;
  final bool showLabel;

  @override
  State<_NavigationDestination> createState() => _NavigationDestinationState();
}

class _NavigationDestinationState extends State<_NavigationDestination> {
  bool _focused = false;
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'Navigation ${widget.destination.label}',
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualEffects = AppVisualEffects.of(context);
    final duration = visualEffects.reducedMotion
        ? Duration.zero
        : AppMotion.stateChange;
    void navigate() {
      if (ModalRoute.of(context)?.settings.name == widget.destination.route) {
        return;
      }
      Navigator.pushReplacementNamed(context, widget.destination.route);
    }

    final item = Semantics(
      button: true,
      selected: widget.active,
      label: widget.destination.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Focus(
          key: ValueKey('nav-${widget.destination.label.toLowerCase()}'),
          focusNode: _focusNode,
          autofocus: widget.active,
          onFocusChange: (focused) {
            if (_focused == focused) return;
            setState(() => _focused = focused);
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              navigate();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.prominent),
              onTap: navigate,
              child: AnimatedContainer(
                duration: duration,
                curve: AppMotion.standardCurve,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  gradient: widget.active
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.glassTheme.highlight.withValues(alpha: 0.2),
                            context.glassTheme.activeLayerTint,
                            context.glassTheme.activeLayerTint.withValues(
                              alpha: 0.1,
                            ),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(AppRadii.prominent),
                  border: _focused
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.showLabel ? 10 : 6,
                  vertical: 7,
                ),
                child: widget.showLabel
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.active
                                ? widget.destination.activeIcon
                                : widget.destination.icon,
                            size: 21,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.destination.label,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ],
                      )
                    : Tooltip(
                        message: widget.destination.label,
                        child: Icon(
                          widget.active
                              ? widget.destination.activeIcon
                              : widget.destination.icon,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    return item;
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon, this.route);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}
