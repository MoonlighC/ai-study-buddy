import 'package:flutter/material.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    required this.children,
    this.padding,
    this.maxWidth = 640,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding:
                    padding ??
                    EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      24,
                    ),
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }
}
