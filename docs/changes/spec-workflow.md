# Establish the branch spec workflow

## Goal and scope

Give fresh Codex sessions a clear entry point and split current requirements by feature. The repo-wide documentation change has its own branch because it changes how every subsequent task finds and updates specs.

## Acceptance criteria

- The root AGENTS.md routes a fresh session through SPEC.md, the relevant feature spec, then the matching branch spec when present.
- The main spec is a concise index. The original chronological spec remains available as historical material.
- The instructions distinguish low-risk edits from changes that need an independent branch and spec.
- Feature specs reflect accepted build 30. This branch changes documentation only.
