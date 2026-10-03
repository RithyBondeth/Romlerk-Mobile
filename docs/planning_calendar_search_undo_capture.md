# Planning, calendar export, search, undo and system capture

Daily plans save selected task IDs and each recurring task's occurrence index
under a date-scoped key in the canonical settings table. Reopening the planner
restores selections, including a deliberately empty plan. The Today card shows
completed/planned counts; advancing a recurring task counts that day's occurrence
as complete. All active tasks can be selected, including Inbox tasks. Deleted
tasks stop contributing to visible counts; restoring them with Undo brings them
back. Plans are included in full backups and removed by Erase all data.

Search includes standalone note titles and bodies, with SQL filtering and literal
handling of wildcard characters. Notes have a separate result section and open
the note editor. Status, priority, date and tag filters apply to tasks; notes match
the text query only.

Calendar export previews the task's start/end, title and notes, then shares a
real `.ics` file through the system share sheet. It exports one occurrence, uses
UTC instants and CRLF content lines, escapes text, and folds long Unicode lines
at 75 UTF-8 octets. Later edits are not automatically synchronized to the calendar.
Import/open options depend on the calendar apps installed on the device.

Completion/reopening and deletion offer Undo for eight seconds. Undo restores
full task snapshots, including tags, recurrence progress and reminders, or the
last persisted standalone note. It rejects expired actions, existing conflicting
items and later task edits. Erasure and full restore invalidate undo actions;
undo cannot resurrect data from before those operations. Undo asks for no new
notification permission. Restored reminders still depend on current OS permission.

System entry points route into the existing capture review screen. They do not
parse or silently save tasks in the background, and app lock blocks consumption
and keyboard display until access is granted.

- Android: launcher long-press Quick capture shortcut, widget capture button,
  incoming text shares, and `romlerk://capture?text=...` links. Requests queue
  locally and survive process recreation.
- iOS: launcher Quick capture action, widget capture link, and Capture a task
  App Intent in Shortcuts/Siri. The optional Text parameter can take shortcut
  input. A native share extension accepts text or one URL, queues it locally,
  and dismisses; open Romlerk to review it. Extensions do not force-launch the
  host app through unsupported APIs.

The native inbox limits each request to 12,000 characters and holds up to 100
requests. Shares are excluded from OS backup and cleared during erasure/restore.
A request is removed when the app hands it to the capture sheet; closing that
sheet discards the unsaved review. Full backups cover canonical saved data,
not pending shares. The new producer uses full-backup format version 2; legacy
version 1 files still restore.

Before store release, check real-device cold/warm launch entry points, app lock,
multiple queued shares, share extension language, ICS import into the target
calendar, and the signed extension's App Group provisioning.
