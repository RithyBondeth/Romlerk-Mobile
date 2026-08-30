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
            title: 'New Note',
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
        error: (error, _) => const EmptyState(
          icon: LucideIcons.triangleAlert,
          headline: 'Failed to load notes',
          body: 'There was an error loading your notes.',
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return const CustomScrollView(
              slivers: <Widget>[
                SliverPageHeader(title: 'Notes'),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: LucideIcons.fileText,
                    illustration: 'sitting-reading',
                    headline: 'No notes yet',
                    body: 'Tap the + button to create a note.',
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: <Widget>[
              const SliverPageHeader(title: 'Notes'),
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
