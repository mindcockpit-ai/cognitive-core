# Release Strategy

## Version Bump Rules

| Commit Type | Version Bump | Changelog Section |
|------------|-------------|-------------------|
| `fix`, `perf` | **Patch** (x.y.Z) | Bug Fixes / Performance |
| `refactor`, `style`, `test` | **Patch** (x.y.Z) | Code Refactoring / Styles / Tests |
| `feat` | **Minor** (x.Y.0) | Features |
| `feat!`, `BREAKING CHANGE` | **Major** (X.0.0) | Breaking Changes |
| `docs`, `chore`, `ci`, `build` | **None** | Hidden (no code impact) |

## Release Process

1. **Commits accumulate** on `main` via squash-merged PRs
2. **release-please** opens a Release PR with computed version + CHANGELOG
3. **Human reviews** the CHANGELOG and version bump
4. **Human merges** the Release PR — this is the deployment decision gate
5. GitHub Actions creates the tag and GitHub Release

## Models

### Framework (cognitive-core)
- **Batched releases**: accumulate changes, review CHANGELOG, release when ready
- Version reflects cumulative changes since last release
- Release cadence: when meaningful changes warrant a new version

### Applications (TIMS, netsavehtml)
- **Per-deployment releases**: merge release PR after each deploy
- Version tracks each deployment
- Release cadence: after each successful deployment

## Governance

- LLM agents must NOT merge release PRs without explicit human approval
- The Release PR is the single decision point for version bumps
- CHANGELOG must be reviewed before merging — it becomes the public record
- Squash merges ensure one commit = one PR = one changelog entry
