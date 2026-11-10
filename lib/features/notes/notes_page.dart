import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/illustrated_content.dart';
import '../../core/design/app_theme.dart';
import '../../core/widgets/settings_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/task_list_loading.dart';
import '../../core/widgets/page_header.dart';
import '../../domain/entities/note.dart';
import 'note_detail_page.dart';
import '../../l10n/l10n.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        tooltip: context.l10n.noteNewTitle,
        label: Text(context.l10n.noteNewTitle),
        icon: const Icon(LucideIcons.plus),
        onPressed: () async {
          final newNote = Note(
            id: const Uuid().v4(),
            title: context.l10n.noteNewTitle,
            content: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          try {
            await ref.read(noteRepositoryProvider).saveNote(newNote);
            if (context.mounted) NoteDetailPage.open(context, newNote.id);
          } on Object {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(context.l10n.editFailed)));
            }
          }
        },
      ),
      body: notesAsync.when(
        loading: () => const TaskListLoading(),
        error: (error, _) => EmptyState(
          icon: LucideIcons.triangleAlert,
          headline: context.l10n.notesLoadFailed,
          body: context.l10n.notesLoadFailedBody,
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return CustomScrollView(
              slivers: <Widget>[
                SliverPageHeader(
                  title: context.l10n.notes,
                  trailing: const SettingsButton(),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: LucideIcons.fileText,
                    illustration: 'sitting-reading',
                    headline: context.l10n.notesEmptyTitle,
                    body: context.l10n.notesEmptyBody,
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: <Widget>[
              SliverPageHeader(
                title: context.l10n.notes,
                trailing: const SettingsButton(),
              ),
              SliverToBoxAdapter(
                child: IllustratedBanner(
                  illustration: 'sitting-reading',
                  title: context.l10n.notesIllustrationTitle,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final note = notes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: Material(
                        color: context.semantics.raised,
                        borderRadius: Corners.card,
                        child: InkWell(
                          borderRadius: Corners.card,
                          onTap: () => NoteDetailPage.open(context, note.id),
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      LucideIcons.fileText,
                                      size: 18,
                                      color: context.colors.primary,
                                    ),
                                    const SizedBox(width: Insets.sm),
                                    Expanded(
                                      child: Text(
                                        ref
                                            .watch(formattingProvider)
                                            .dayMonth(note.updatedAt),
                                        style: context.texts.bodySmall,
                                      ),
                                    ),
                                    Icon(
                                      LucideIcons.arrowUpRight,
                                      size: 16,
                                      color: context.semantics.muted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: Insets.md),
                                Text(
                                  note.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.titleMedium,
                                ),
                                if (note.content.isNotEmpty) ...[
                                  const SizedBox(height: Insets.sm),
                                  Text(
                                    note.content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.texts.bodyMedium?.copyWith(
                                      color: context.semantics.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: notes.length),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: Insets.bottomClearance),
              ),
            ],
          );
        },
      ),
    );
  }
}
