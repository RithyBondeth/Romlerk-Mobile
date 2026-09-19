import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../domain/entities/note.dart';
import '../../l10n/l10n.dart';

class NoteDetailPage extends ConsumerStatefulWidget {
  const NoteDetailPage({required this.noteId, super.key});

  final String noteId;

  static Future<void> open(BuildContext context, String noteId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteDetailPage(noteId: noteId),
      ),
    );
  }

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  Note? _note;
  late final TextEditingController _titleController = TextEditingController();
  late final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final note = await ref.read(noteRepositoryProvider).getNoteById(widget.noteId);
    if (note != null && mounted) {
      setState(() {
        _note = note;
        _titleController.text = note.title;
        _contentController.text = note.content;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_note == null) return;
    final updatedNote = _note!.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );
    ref.read(noteRepositoryProvider).saveNote(updatedNote);
    setState(() {
      _note = updatedNote;
    });
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteNoteQuestion),
        content: Text(context.l10n.cannotBeUndone),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(noteRepositoryProvider).deleteNote(widget.noteId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 19),
            tooltip: context.l10n.deleteNote,
            onPressed: _deleteNote,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: Insets.md),
        children: <Widget>[
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) _saveNote();
            },
            child: TextField(
              controller: _titleController,
              style: context.texts.headlineSmall,
              decoration: InputDecoration(
                hintText: context.l10n.noteTitleHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) _saveNote();
            },
            child: TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 10,
              decoration: InputDecoration(
                hintText: context.l10n.noteBodyHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
