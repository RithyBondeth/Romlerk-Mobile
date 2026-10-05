import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/design_tokens.dart';

/// A quiet layout placeholder; no repeating animation while local data opens.
class TaskListLoading extends StatelessWidget {
  const TaskListLoading({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ListView(
      padding: const EdgeInsets.all(Insets.gutter),
      children: [
        const SizedBox(height: Insets.lg),
        _line(context, 144, 32),
        const SizedBox(height: Insets.md),
        _line(context, 208, 16),
        const SizedBox(height: Insets.xxl),
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.only(bottom: Insets.md),
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              color: context.semantics.raised,
              borderRadius: Corners.card,
            ),
            child: Row(
              children: [
                _line(context, 24, 24),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line(context, i.isEven ? 172 : 136, 16),
                      const SizedBox(height: Insets.md),
                      _line(context, 84, 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _line(BuildContext context, double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.semantics.sunken,
      borderRadius: Corners.chip,
    ),
  );
}
