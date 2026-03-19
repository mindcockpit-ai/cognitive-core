# Releasing cognitive-core

## Automated Releases (release-please)

Releases are automated via [release-please](https://github.com/googleapis/release-please).

### How it works

1. Push commits with conventional format (`feat:`, `fix:`, `docs:`)
2. release-please opens a PR bumping `version.txt` and updating `CHANGELOG.md`
3. Merge the PR → GitHub Release is created automatically

### Version bumps

| Commit type | Version bump |
|-------------|-------------|
| `feat:` | Minor (0.x.0) |
| `fix:` | Patch (0.0.x) |
| `feat!:` or `BREAKING CHANGE:` | Major (x.0.0) |
| `docs:`, `chore:`, `ci:` | No bump (hidden in changelog) |

### Manual release (if needed)

```bash
# Update version
echo "1.2.0" > version.txt

# Tag and push
git add version.txt CHANGELOG.md
git commit -m "chore: release v1.2.0"
git tag -a v1.2.0 -m "v1.2.0"
git push && git push origin v1.2.0

# Create GitHub release
gh release create v1.2.0 --title "v1.2.0" --notes-from-tag
```

### Pre-release checklist

- [ ] `bash tests/run-all.sh` — all 13 suites green
- [ ] `git status` — clean working tree
- [ ] Review CHANGELOG.md entries
- [ ] Update multivac42.ai after release (auto-update workflow or manual)

### Files involved

| File | Purpose |
|------|---------|
| `version.txt` | Single source of truth for version |
| `.release-please-manifest.json` | release-please state |
| `release-please-config.json` | release-please configuration |
| `.github/workflows/release-please.yml` | Automation workflow |
| `CHANGELOG.md` | Generated changelog |
