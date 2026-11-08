# SiroMix repository instructions

1. Read [SPEC.md](SPEC.md) before planning or editing.
2. Follow its index to the current feature spec for the requested work. Read only the relevant feature and template notes.
3. Check the current branch and working tree. On a change branch, also read its matching spec in [docs/changes](docs/changes/README.md). Archived decisions provide history only.
4. Classify the change by scope and risk. For a localized, low-risk change, use the current branch and update the relevant existing spec if a documented detail changes. No separate change spec is needed.
5. For an independently reviewable change with several decisions, cross-feature effects, or meaningful regression risk, briefly state the reason and use one branch and one change spec. Name the branch `codex/<slug>` and the spec `docs/changes/<slug>.md`. Reuse the branch and spec when continuing existing work. Base new independent branches on the agreed baseline; preserve pending work.
6. Verify against the feature spec and the change's acceptance criteria. Update the current feature spec if product behavior changes. Keep specs in English and user-facing UI in Vietnamese.
