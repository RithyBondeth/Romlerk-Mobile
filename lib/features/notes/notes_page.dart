import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final newNote = Note(
            id: const Uuid().v4(),
            title: context.l10n.noteNewTitle,
            content: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          ref.read(noteRepositoryProvider).saveNote(newNote);
          NoteDetailPage.open(context, newNote.id);
        },
        child: const Icon(LucideIcons.plus),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: LucideIcons.triangleAlert,
          headline: context.l10n.notesLoadFailed,
          body: context.l10n.notesLoadFailedBody,
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return CustomScrollView(
              slivers: <Widget>[
                SliverPageHeader(title: context.l10n.notes),
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
              SliverPageHeader(title: context.l10n.notes),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final note = notes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: Insets.sm),
                        child: ListTile(
                          title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => NoteDetailPage.open(context, note.id),
                        ),
                      );
                    },
                    childCount: notes.length,
                  ),
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
