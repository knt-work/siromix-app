# Browse saved papers by exam hierarchy

## Scope

Replace the flat entry view in Sổ chấm bài with drill-down navigation. See the current [local data](../specs/local-data.md), [grading](../specs/grading.md), and [interface](../specs/interface.md) specs. The proposed design is pending wireframe approval.

## Proposed acceptance criteria

- Open Sổ chấm bài at academic years and drill down through exam session, grade, subject, and exam code in that order.
- Build groups from saved papers and show the number of descendant papers. Older saved results remain reachable using their stored paths and codes.
- Show the selected path and let users return one level or jump to an ancestor.
- At the exam code level, list matching papers newest first. Search by candidate or paper number within the code. Keep paper details and confirmation for single and bulk deletion available.
- Show an empty state for a new history and when the last paper in a selected code is deleted.
- Use Vietnamese labels and the shared SiroMix visual styles.
