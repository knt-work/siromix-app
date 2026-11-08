# Browse saved papers by exam hierarchy

## Scope

Replace the flat entry view in Sổ chấm bài with drill-down navigation. See the current [local data](../specs/local-data.md), [grading](../specs/grading.md), and [interface](../specs/interface.md) specs. The approved wireframe shows the exam hierarchy and omits search.

## Acceptance criteria

- Open Sổ chấm bài from Home at academic years and drill down through exam session, grade, subject, and exam code in that order. From the grading workflow, start at the current scope.
- Build groups from saved papers and show the number of descendant papers. Older saved results remain reachable using their stored paths and codes.
- Show the selected path and let users return one level or jump to an ancestor.
- At the exam code level, list all papers for the selected code newest first, without a search field. Keep paper details and confirmation for single and bulk deletion available.
- Show an empty state for a new history and when the last paper in a selected code is deleted.
- Use Vietnamese labels and the shared SiroMix visual styles.

## Verification

- Flutter analysis reported no issues. All 134 Flutter tests passed.
- Widget coverage exercises the Home entry point, all five levels, ancestor navigation, code isolation, newest-first order, paper details and confirmed deletion. It also verifies the empty state after deleting the last paper and selection behavior on failed writes.
