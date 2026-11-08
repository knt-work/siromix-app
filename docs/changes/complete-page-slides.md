# Complete page slide coverage

The initial slide transition covered pushed routes. Home, the grading hierarchy and the history hierarchy also change views within a route. This change covers those view boundaries while preserving existing navigation and back handling.

## Acceptance criteria

- Opening grading from Home and moving deeper into grading or history slides the destination in from the right. Going back to a shallower level or Home slides the destination in from the left.
- Switching from grading to its results view and back uses the same transition. Changes within a view, including filters and editing controls, do not trigger a page slide.
- Slides travel the full view width over 300 ms. Both route and in-place slides keep the app's opaque light background in the exposed area throughout the transition.
- Profile, About, the key editor, top-level history and saved-paper details retain their route slides. Scan setup, the camera, review opened from the camera, dialogs and bottom sheets retain their existing transitions.
- Verify slide direction in widget tests, then run Flutter analysis and the full regression suite.

## Verification

Flutter analysis reported no issues and all 134 tests passed. Widget tests checked both directions on Home and in history, forward navigation through each grading level, and the direct switch into scan setup. They also verified that the light background covers the viewport halfway through the slide into grading and while opening and closing About.
