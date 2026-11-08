# Local data and history

- Persist exam configuration, a local teacher profile, paper results and counters across restarts. A saved paper includes the selected key snapshot and final responses. Later key edits do not alter historical scores.
- Assign paper numbers within year/session/grade/subject when the result is saved. Failed saves must leave paper and counter unchanged. Deletions require confirmation; deleting a result does not reuse its number. Exam, grade and subject deletions cover their descendants.
- Browse saved papers by academic year, exam session, grade, subject and exam code. Groups are based on stored papers and show descendant counts. The grading entry point starts at the current scope. Within a code, show all papers newest first and provide details and confirmed single or bulk deletion.
- Profile fields are optional and include display name, school or organization, province/city, ward/commune and email. The address catalog is offline. See [administrative data provenance](../ADMINISTRATIVE-DATA.md).
- JSON backup envelope v1 exports the profile, catalog, results and counters. Restore validates and previews the file before explicit confirmation, then replaces local data atomically. The size limit is 20 MiB. Current data schema is 7 with migration from supported older schemas. Captured photos are excluded from history and backups.
