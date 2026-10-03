# Editing and full backups

Task titles and notes, and standalone note titles and bodies, save after 400 ms
without typing. Writes are serialized: edits made during a save are written
next. Leaving an editor or backgrounding the app flushes pending changes.
A failed save keeps the text in the editor, shows Retry, and prevents normal
back navigation until it succeeds. An empty title needs correction before saving.
Force-stopping the process before a write completes can still lose pending text.

Task detail supports adding, changing, and removing start/due dates, reminders,
recurrence, duration, and tags, plus priority, completion, and text editing.
Reminders are independent of the due date. Moving a reminder replaces its
existing notification; removing it cancels the notification. Autosave does not
prompt for notification permission. Recurrence needs a start or due date;
intervals, weekly weekdays, count limits, and end dates are editable.

Settings → Data → Create full backup shares a JSON file through the system share
sheet. Restore full backup opens a native file picker, checks the file, previews
task/note counts and backup date, and asks before replacing local data.

Full backups preserve tasks, standalone notes, tags and links, recurrence rules
and progress, reminders, preferences, daily plans, diagnostic audit records, and the OS backup
preference. They exclude cached widgets, model downloads, and OS notification
handles. Restored future reminders are scheduled on the current device using its
permissions; blocked or failed scheduling is reported. No permission prompt is
shown during restore. Widgets are refreshed using restored privacy preferences.

Format version 2 includes `application: Romlerk`, `format: full-backup`,
`version: 2`, `databaseVersion: 2`, UTC creation time, `backupEnabled`, and all eight
canonical database tables in `data`. Dates are ISO 8601 UTC instants. Files are
limited to 20 MB and 100,000 records per table. Unknown versions, malformed
records, duplicate primary keys, invalid enums, and broken references are rejected
before existing data or notifications change. Replacement is one database
transaction; failed insertion rolls back. Existing task-only JSON/CSV exports
are still available and cannot be used for full restore.

Backups contain readable user data. Store the shared file somewhere private.

Legacy format version 1 backups remain supported. The restored OS backup
preference takes effect on the next app launch if the database must move.
