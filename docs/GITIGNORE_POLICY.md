# Gitignore Policy

cognitive-core enforces a comprehensive `.gitignore` policy during install and update. This prevents secrets, build artifacts, IDE files, and other generated content from leaking into version control.

## How It Works

The policy has two layers:

1. **Base template** (`core/templates/gitignore-base`) — Universal rules applied to every project
2. **Language pack fragment** (`language-packs/<lang>/gitignore`) — Language-specific rules merged based on your `CC_LANGUAGE` setting

Both `install.sh` and `update.sh` run the merge function, which:
- Appends only rules not already present (deduplication via `grep -qxF`)
- Preserves all existing user rules
- Adds a section header marker to prevent duplicate headers on re-runs
- Never removes rules — append-only by design

## Base Template Coverage

### OS Files
- **macOS**: `.DS_Store`, `.Trashes`, `.fseventsd`, `.AppleDouble`, `Icon?`
- **Windows**: `Thumbs.db`, `Desktop.ini`, `$RECYCLE.BIN/`, MSI/CAB artifacts
- **Linux**: `.directory`, `.Trash-*`

### Common Build Output
`build/`, `out/`, `dist/` — applies regardless of language

### IDE / Editor Files (16 IDEs)

| IDE | Key patterns |
|-----|-------------|
| VS Code | `.vscode/` (with whitelist for `settings.json`, `launch.json`, `extensions.json`, `tasks.json`) |
| JetBrains (IntelliJ, WebStorm, PyCharm, GoLand, Rider, CLion, RubyMine, PhpStorm, DataGrip) | `.idea/`, `*.iml`, `cmake-build-*/` |
| Eclipse / STS | `.project`, `.classpath`, `.settings/`, `.sts4-cache/`, `.springBeans` |
| NetBeans | `nbproject/private/`, `nbactions.xml` |
| Visual Studio | `.vs/`, `*.suo`, `*.user` |
| Xcode | `xcuserdata/`, `DerivedData/` |
| Android Studio | `.gradle/`, `local.properties`, `*.apk` |
| Sublime Text | `*.sublime-workspace` |
| Vim / Neovim | `*.swp`, `*.swo`, `tags` |
| Emacs | `\#*\#`, `auto-save-list/`, `.projectile` |
| TextMate | `*.tmproj`, `tmtags` |
| Atom | `.atom/` |
| Notepad++ | `nppBackup/` |
| Kate / KDevelop | `.kdev4/` |
| Fleet | `.fleet/` |
| Zed | `.zed/` |
| Cursor | `.cursor/` |

### Secrets and Credentials
- Environment files: `.env`, `.env.*` (with whitelist for `.env.template`, `.env.tpl`, `.env.example`)
- Cryptographic material: `*.pem`, `*.key`, `*.crt`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore`, `*.truststore`
- Cloud/service credentials: `credentials.json`, `service-account*.json`, `.htpasswd`
- IaC state: `terraform.tfstate`, `.terraform/`, `.aws/credentials`, `.kube/config`, `.netrc`, `vault-token`

### Other
- **Logs**: `*.log`, `logs/`
- **Archives**: `*.zip`, `*.tar.gz`, `*.7z`, `*.iso`, `*.dmg`
- **Temporary**: `tmp/`, `*.tmp`, `*.bak`, `*.orig`
- **Docker runtime**: `docker-compose.override.yml`
- **Test artifacts**: `coverage/`, `htmlcov/`, `test-results/`
- **cognitive-core runtime**: `version.json`, `last-check`, `security.log`

## Language Pack Fragments

Each language pack adds patterns specific to its ecosystem:

| Language Pack | Key additions |
|---------------|--------------|
| **java** | `*.class`, `target/`, Maven/Gradle artifacts, `hs_err_pid*` |
| **spring-boot** | Java + `application-local.*`, `spring-shell.log` |
| **struts-jsp** | Java + JSP `work/` precompile dir |
| **python** | `__pycache__/`, `*.py[cod]`, venvs, mypy/ruff/pytest caches, PDM/uv, Jupyter, Celery |
| **node** | `node_modules/`, `.next/`, `.nuxt/`, `.turbo/`, `.swc/`, `.vercel/`, TypeScript build info |
| **react** | Node + Storybook, Parcel |
| **angular** | Node + `.angular/`, `.sass-cache/` |
| **perl** | `blib/`, `cover_db/`, Carton `local/`, Dist::Zilla `.dzil/` |
| **go** | `bin/`, `vendor/`, `go.work`, compiled binaries |
| **rust** | `target/`, `**/*.rs.bk` (Cargo.lock commented out with guidance — commit for binaries, ignore for libraries) |
| **csharp** | `[Bb]in/`, `[Oo]bj/`, NuGet packages, `artifacts/` |

## Configuration

The gitignore policy is controlled by `CC_LANGUAGE` in your `cognitive-core.conf`:

```bash
CC_LANGUAGE="python"  # Merges base + python fragment
```

No additional configuration is needed. The policy runs automatically on every `install.sh` and `update.sh` execution.

## Testing

The gitignore policy is covered by test suite `15-gitignore-policy.sh` with 138 assertions across 8 test categories:

1. Base template content validation (OS, 16 IDEs, secrets, IaC)
2. All 11 language pack content verification
3. Install integration (merge into `.gitignore`)
4. Deduplication on re-install (no duplicate rules or headers)
5. User rule preservation (existing `.gitignore` kept intact)
6. Correct language pack selection (cross-language isolation)
7. `struts-jsp` install menu wiring
8. Structural checks (`build/`/`out/` in common section, not under IDE)
