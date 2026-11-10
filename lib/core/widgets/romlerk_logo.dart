import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// The approved full-color doodle mark. Keep ink visible in dark themes.
class RomlerkLogo extends StatelessWidget {
  const RomlerkLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        color: RomlerkColors.paper,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Image.asset(
        'assets/branding/romlerk-logo.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}
