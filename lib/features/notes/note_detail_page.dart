import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../application/providers.dart';
import '../../application/editing/autosave_controller.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/design_tokens.dart';
import '../../core/widgets/illustrated_content.dart';
import '../../core/widgets/autosave_status.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../l10n/l10n.dart';

class NoteDetailPage extends ConsumerStatefulWidget {
  const NoteDetailPage({required this.noteId, super.key});
  final String noteId;
  static Future<void> open(BuildContext context, String noteId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => NoteDetailPage(noteId: noteId)),
      );
  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage>
    with WidgetsBindingObserver {
  Note? _note;
  Object? _loadError;
  bool _loading = true;
  bool _leaving = false;
  bool _allowPop = false;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late final NoteRepository _repository;
  late final AutosaveController _autosave;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(noteRepositoryProvider);
    _autosave = AutosaveController(_saveNote)..addListener(_updated);
    WidgetsBinding.instance.addObserver(this);
    _loadNote();
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNote() async {
    try {
      final note = await _repository.getNoteById(widget.noteId);
      if (!mounted) return;
      _note = note;
      _titleController.text = note?.title ?? '';
      _contentController.text = note?.content ?? '';
      _loadError = null;
    } on Object catch (error) {
      _loadError = error;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveNote() async {
    final current = _note;
    if (current == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty || title.length > 500) {
      throw const FormatException('Invalid title');
    }
    // Snapshot both fields before awaiting, so edits during a write queue up.
    final updated = current.copyWith(
      title: title,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );
    await _repository.saveNote(updated);
    _note = updated;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_autosave.flush());
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final saved = await _autosave.flush();
    _leaving = false;
    if (!mounted || !saved) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave.removeListener(_updated);
    _autosave.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteNoteQuestion),
        content: Text(context.l10n.cannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Flush before stopping. Failed writes do not prevent an explicit delete.
    await _autosave.stop();
    try {
      await _repository.deleteNote(widget.noteId);
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    } on Object {
      _autosave.resume();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.editFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_autosave.dirty && !_autosave.saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_leave());
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: _leave,
        ),
        actions: [
          if (_note != null)
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 19),
              tooltip: context.l10n.deleteNote,
              onPressed: _deleteNote,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null || _note == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadError != null
                        ? context.l10n.notesLoadFailed
                        : context.l10n.detailGone,
                  ),
                  if (_loadError != null)
                    TextButton(
                      onPressed: _loadNote,
                      child: Text(context.l10n.autosaveRetry),
                    ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.gutter,
                vertical: Insets.md,
              ),
              children: [
                IllustratedContent(
                  illustration: 'sitting-reading',
                  artSize: 72,
                  child: AutosaveStatus(controller: _autosave),
                ),
                TextField(
                  key: const ValueKey('note-title'),
                  controller: _titleController,
                  maxLength: 500,
                  onChanged: (_) => _autosave.changed(),
                  onSubmitted: (_) => _autosave.flush(),
                  style: context.texts.headlineSmall,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: context.l10n.noteTitleHint,
                    labelText: context.l10n.noteTitleHint,
                    errorText: _titleController.text.trim().isEmpty
                        ? context.l10n.editTitleRequired
                        : null,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                TextField(
                  key: const ValueKey('note-content'),
                  controller: _contentController,
                  maxLines: null,
                  minLines: 12,
                  style: context.texts.bodyLarge,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _autosave.changed(),
                  decoration: InputDecoration(
                    hintText: context.l10n.noteBodyHint,
                    contentPadding: const EdgeInsets.all(Insets.xl),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
    ),
  );
}
