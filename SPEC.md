# SiroMix product specification

SiroMix helps teachers configure answer keys, scan paper sheets, review uncertain marks and save grades. The accepted Android checkpoint is version **1.0.0+30**. The app works offline with local storage and no sign-in. iOS, Play publication, cloud synchronization, question shuffling and Excel export are deferred.

## Current feature specs

| Area | Start here |
| --- | --- |
| Exam hierarchy, keys, scores and review | [Exam configuration and grading](docs/specs/grading.md) |
| Camera flow, NTL, QM2025 and OMR | [Scanning](docs/specs/scanning.md) |
| Saved papers, profile, data lifecycle and backup | [Local data](docs/specs/local-data.md) |
| Home, navigation and visual conventions | [Interface](docs/specs/interface.md) |

## Development workflow

Read this file, the relevant feature spec, and the matching branch spec when present. [AGENTS.md](AGENTS.md) defines the repo workflow. Small, low-risk changes use the current branch and update the existing spec as needed. Changes that need independent review use one branch and one [change spec](docs/changes/README.md). A feature spec describes current product behavior; a change spec records the scope and acceptance criteria for one delivery.

Use Flutter analysis and relevant regression tests. Use phone testing for camera interactions. Keep student photos and signing material outside tracked files and published artifacts.

See [development checkpoints](docs/DEVELOPMENT.md) and [README](README.md) for build instructions. The [original chronological spec](docs/archive/product-spec-through-build-27.md) preserves previous decisions, including superseded behavior. Current feature specs govern ongoing work.
