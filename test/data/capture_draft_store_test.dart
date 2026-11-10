import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/capture_controller.dart';
import 'package:romlerk_mobile/application/providers.dart';
import 'package:romlerk_mobile/data/capture/capture_draft_store.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/domain/drafts/task_draft.dart';
import 'package:romlerk_mobile/domain/entities/recurrence_rule.dart';
import 'package:romlerk_mobile/domain/enums.dart';

class FailingStore extends CaptureDraftStore {
  FailingStore(super.db);
  bool failing = true;
  @override
  Future<void> write(CaptureState state) async {
    if (failing) throw StateError('Disk unavailable');
    await super.write(state);
  }
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'review edits, ambiguities and Khmer text survive controller recreation',
    () async {
      final first = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      final controller = first.read(captureControllerProvider.notifier);
      final date = DateTime(2030, 2, 3, 9);
      controller.recover(
        CaptureState(
          input: 'ហៅ ដារ៉ា ថ្ងៃស្អែក',
          nativeRequestId: 'share-1',
          drafts: [
            TaskDraft(
              id: 'draft-1',
              title: 'Edited title',
              notes: 'Keep this note',
              startAt: date,
              dueAt: date,
              reminderAt: date,
              recurrence: const RecurrenceRule(
                frequency: RecurrenceFrequency.weekly,
                byWeekday: [2],
              ),
              priority: TaskPriority.high,
              durationMinutes: 45,
              durationIsEstimate: true,
              tags: ['work'],
              sourceText: 'ដារ៉ា',
              ambiguities: [
                DraftAmbiguity(
                  field: DraftField.dueAt,
                  reason: 'Choose time',
                  code: 'MERIDIEM',
                  sourceSpan: '9',
                  alternatives: [
                    DraftAlternative(label: 'Morning', dateTime: date),
                  ],
                ),
              ],
              warnings: const [
                DraftWarning(
                  code: 'TIME_APPROXIMATE',
                  message: 'Approximate',
                  field: DraftField.dueAt,
                  sourceSpan: 'morning',
                ),
              ],
              confidenceByField: const {DraftField.title: 0.8},
            ),
          ],
        ),
      );
      expect(await controller.autosave.flush(), isTrue);
      final expected = CaptureDraftStore.encode(controller.snapshot);
      first.dispose();
      final second = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(second.dispose);
      final recovered = second.read(captureControllerProvider.notifier);
      await recovered.load();
      expect(recovered.snapshot.stage, CaptureStage.reviewing);
      expect(CaptureDraftStore.encode(recovered.snapshot), expected);
      expect(await db.select(db.taskRows).get(), isEmpty);
      await recovered.reset();
      expect(await CaptureDraftStore(db).read(), isNull);
    },
  );

  test(
    'failed writes retain current text and retry writes the latest revision',
    () async {
      final store = FailingStore(db);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          captureDraftStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);
      controller.updateInput('First revision');
      expect(await controller.autosave.flush(), isFalse);
      controller.updateInput('Latest revision');
      expect(controller.snapshot.input, 'Latest revision');
      expect(controller.autosave.dirty, isTrue);
      store.failing = false;
      expect(await controller.autosave.flush(), isTrue);
      expect((await store.read())!.input, 'Latest revision');
    },
  );

  test('interrupted parsing recovers as editable input', () async {
    final store = CaptureDraftStore(db);
    await store.write(
      const CaptureState(
        input: 'Call Dara',
        stage: CaptureStage.parsing,
        requestId: 'in-flight',
      ),
    );
    final recovered = (await store.read())!;
    expect(recovered.stage, CaptureStage.idle);
    expect(recovered.requestId, isNull);
    expect(recovered.input, 'Call Dara');
    expect(CaptureDraftStore.valid('{broken'), isFalse);
  });
}
