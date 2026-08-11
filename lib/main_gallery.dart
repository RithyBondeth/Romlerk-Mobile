// TEMPORARY preview harness — not part of the app.
//
// Renders the four empty states side by side so the illustrations can be
// judged without emptying a real database. Run with:
//   flutter run -t lib/main_gallery.dart
// Delete this file once the artwork is settled.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'core/design/app_theme.dart';
import 'core/widgets/empty_state.dart';

void main() => runApp(const _Gallery());

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: PageView(
            children: const <Widget>[
              EmptyState(
                icon: LucideIcons.sun,
                illustration: 'chilling',
                headline: 'Nothing due today',
                body: 'Anything you capture with a date for today will show '
                    'up here.',
              ),
              EmptyState(
                icon: LucideIcons.calendarDays,
                illustration: 'strolling',
                headline: 'Nothing scheduled ahead',
                body: 'Tasks with a date after today will be grouped here by '
                    'day.',
              ),
              EmptyState(
                icon: LucideIcons.inbox,
                illustration: 'unboxing',
                headline: 'Inbox is clear',
                body: 'Anything you capture without a date waits here until '
                    'you decide when to do it.',
              ),
              EmptyState(
                icon: LucideIcons.search,
                illustration: 'reading',
                headline: 'Search your tasks',
                body: 'Everything is stored on this device, so search works '
                    'offline.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
