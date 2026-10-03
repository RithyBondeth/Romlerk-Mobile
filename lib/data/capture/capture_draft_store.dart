import 'dart:convert';
import '../../application/capture_controller.dart';
import '../../local_ai/capabilities.dart';
import '../../domain/drafts/task_draft.dart';
import '../../domain/entities/recurrence_rule.dart';
import '../../domain/enums.dart';
import '../local/app_database.dart';

/// A review is saved locally, but never becomes a task until confirmed.
class CaptureDraftStore {
  CaptureDraftStore(this.db);
  final AppDatabase db;
  static const key = 'capture_draft_v1';

  Future<CaptureState?> read() async {
    final row = await (db.select(
      db.settingRows,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : decode(row.value);
  }

  Future<void> write(CaptureState state) async {
    if (state.input.isEmpty && state.drafts.isEmpty) return clear();
    await db
        .into(db.settingRows)
        .insertOnConflictUpdate(SettingRow(key: key, value: encode(state)));
  }

  Future<void> clear() =>
      (db.delete(db.settingRows)..where((t) => t.key.equals(key))).go();

  static String encode(CaptureState state) => jsonEncode({
    'input': state.input,
    'provider': state.provider.name,
    'degradedFrom': state.degradedFrom,
    'nativeRequestId': state.nativeRequestId,
    'drafts': state.drafts
        .map(
          (d) => {
            'id': d.id,
            'title': d.title,
            'notes': d.notes,
            'startAt': d.startAt?.toIso8601String(),
            'dueAt': d.dueAt?.toIso8601String(),
            'reminderAt': d.reminderAt?.toIso8601String(),
            'recurrence': d.recurrence?.toJson(),
            'priority': d.priority.wire,
            'durationMinutes': d.durationMinutes,
            'tags': d.tags,
            'sourceText': d.sourceText,
            'durationIsEstimate': d.durationIsEstimate,
            'ambiguities': d.ambiguities
                .map(
                  (a) => {
                    'field': a.field.name,
                    'reason': a.reason,
                    'code': a.code,
                    'sourceSpan': a.sourceSpan,
                    'alternatives': a.alternatives
                        .map(
                          (v) => {
                            'label': v.label,
                            'code': v.code,
                            'dateTime': v.dateTime?.toIso8601String(),
                          },
                        )
                        .toList(),
                  },
                )
                .toList(),
            'warnings': d.warnings
                .map(
                  (w) => {
                    'code': w.code,
                    'message': w.message,
                    'field': w.field?.name,
                    'sourceSpan': w.sourceSpan,
                  },
                )
                .toList(),
            'confidence': {
              for (final e in d.confidenceByField.entries) e.key.name: e.value,
            },
          },
        )
        .toList(),
  });

  static CaptureState decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    DateTime? date(dynamic v) => v == null ? null : DateTime.parse(v as String);
    final drafts = (json['drafts'] as List).map((v) {
      final d = v as Map<String, dynamic>;
      return TaskDraft(
        id: d['id'] as String,
        title: d['title'] as String,
        notes: d['notes'] as String?,
        startAt: date(d['startAt']),
        dueAt: date(d['dueAt']),
        reminderAt: date(d['reminderAt']),
        recurrence: d['recurrence'] == null
            ? null
            : RecurrenceRule.fromJson(d['recurrence'] as Map<String, dynamic>),
        priority: TaskPriority.values.firstWhere(
          (p) => p.wire == d['priority'],
        ),
        durationMinutes: d['durationMinutes'] as int?,
        tags: (d['tags'] as List).cast<String>(),
        sourceText: d['sourceText'] as String?,
        durationIsEstimate: d['durationIsEstimate'] as bool,
        ambiguities: (d['ambiguities'] as List)
            .map(
              (a) => DraftAmbiguity(
                field: DraftField.values.byName(a['field'] as String),
                reason: a['reason'] as String,
                code: a['code'] as String?,
                sourceSpan: a['sourceSpan'] as String?,
                alternatives: (a['alternatives'] as List)
                    .map(
                      (v) => DraftAlternative(
                        label: v['label'] as String,
                        code: v['code'] as String?,
                        dateTime: date(v['dateTime']),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
        warnings: (d['warnings'] as List)
            .map(
              (w) => DraftWarning(
                code: w['code'] as String,
                message: w['message'] as String,
                field: w['field'] == null
                    ? null
                    : DraftField.values.byName(w['field'] as String),
                sourceSpan: w['sourceSpan'] as String?,
              ),
            )
            .toList(),
        confidenceByField: (d['confidence'] as Map<String, dynamic>).map(
          (k, v) =>
              MapEntry(DraftField.values.byName(k), (v as num).toDouble()),
        ),
      );
    }).toList();
    return CaptureState(
      input: json['input'] as String,
      provider: AiProvider.values.byName(json['provider'] as String),
      degradedFrom: json['degradedFrom'] as String?,
      nativeRequestId: json['nativeRequestId'] as String?,
      drafts: drafts,
      stage: drafts.isEmpty ? CaptureStage.idle : CaptureStage.reviewing,
    );
  }

  static bool valid(String value) {
    try {
      decode(value);
      return true;
    } on Object {
      return false;
    }
  }
}
