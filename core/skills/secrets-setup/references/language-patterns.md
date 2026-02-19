# Secret Patterns by Language

Used by `secrets-setup scan` — loaded based on `CC_LANGUAGE` from `cognitive-core.conf`.

## Universal Patterns (always active)

| Pattern | Description |
|---------|-------------|
| `AKIA[0-9A-Z]{16}` | AWS access key ID |
| `-----BEGIN.*PRIVATE.*KEY-----` | PEM private key |
| `ghp_[a-zA-Z0-9]{36}` | GitHub personal access token |
| `gho_[a-zA-Z0-9]{36}` | GitHub OAuth token |
| `glpat-[a-zA-Z0-9\-]{20}` | GitLab personal access token |
| `sk-[a-zA-Z0-9]{48}` | OpenAI / Stripe secret key |
| `ops_[a-zA-Z0-9]{43}` | 1Password service account token |
| `xox[bpors]-[a-zA-Z0-9-]+` | Slack token |

## Python (`CC_LANGUAGE=python`)

| Pattern | Context | File types |
|---------|---------|------------|
| `os\.environ\["[A-Z_]+"\]\s*=\s*"[^"]+"` | Hardcoded env var assignment | `*.py` |
| `SECRET_KEY\s*=\s*["'][^"']+["']` | Django secret key | `settings.py`, `*.py` |
| `dotenv_values\|load_dotenv` | python-dotenv usage (verify .env gitignored) | `*.py` |
| `boto3.*aws_access_key_id\s*=` | Hardcoded AWS credentials in boto3 | `*.py` |

**Config files to check:** `settings.py`, `config.py`, `.flaskenv`, `pyproject.toml`

## Node.js (`CC_LANGUAGE=node`)

| Pattern | Context | File types |
|---------|---------|------------|
| `process\.env\.[A-Z_]+=` | Direct env assignment | `*.js`, `*.ts` |
| `NEXT_PUBLIC_` | Next.js public env vars (intentionally exposed, but audit) | `*.env*` |
| `VITE_` | Vite public env vars (intentionally exposed, but audit) | `*.env*` |
| `createClient\(["'][^"']+["']` | Hardcoded Supabase/API URLs with keys | `*.ts`, `*.js` |

**Config files to check:** `.env.local`, `.env.development`, `.env.production`, `next.config.*`, `nuxt.config.*`

## Java (`CC_LANGUAGE=java`)

| Pattern | Context | File types |
|---------|---------|------------|
| `spring\.datasource\.password\s*=\s*[^$]` | Hardcoded DB password (not placeholder) | `*.properties`, `*.yml` |
| `@Value\("\$\{[^}]+\}"\)` | Spring property injection (check for defaults) | `*.java` |
| `BasicCredentialsProvider` | Hardcoded credentials in HTTP client | `*.java` |
| `jdbc:.*password=` | JDBC URL with embedded password | `*.properties`, `*.xml` |

**Config files to check:** `application.properties`, `application.yml`, `application-*.yml`, `pom.xml` (for profile-specific secrets)

## Perl (`CC_LANGUAGE=perl`)

| Pattern | Context | File types |
|---------|---------|------------|
| `\$ENV\{["'][A-Z_]+["']\}\s*\|\|?\s*["'][^"']+["']` | Env var with hardcoded fallback | `*.pl`, `*.pm` |
| `password\s*=>\s*["'][^"']+["']` | Hardcoded password in config hash | `*.pl`, `*.pm`, `*.yml` |
| `dsn\s*=>.*password` | DBI connection with embedded password | `*.pl`, `*.pm` |
| `set\s+["']?secret["']?\s*=>` | Dancer2 session secret | `config.yml` |

**Config files to check:** `config.yml`, `environments/*.yml`, `*.conf`

## Go (`CC_LANGUAGE=go`)

| Pattern | Context | File types |
|---------|---------|------------|
| `os\.Getenv\(".*"\)` | Env var usage (verify not hardcoded fallback) | `*.go` |
| `password\s*:?=\s*"[^"]+"` | Hardcoded password in string literal | `*.go` |
| `godotenv\.Load` | dotenv usage (verify .env gitignored) | `*.go` |
| `apiKey\s*:?=\s*"` | Hardcoded API key | `*.go` |

**Config files to check:** `.env`, `config.yaml`, `config.toml`

## Rust (`CC_LANGUAGE=rust`)

| Pattern | Context | File types |
|---------|---------|------------|
| `env::var\(".*"\)\.unwrap_or\("` | Env var with hardcoded fallback | `*.rs` |
| `password.*=.*"[^"]+"` | Hardcoded password | `*.rs`, `*.toml` |
| `dotenvy::dotenv` | dotenv usage (verify .env gitignored) | `*.rs` |
| `Authorization.*Bearer\s+[a-zA-Z0-9]` | Hardcoded bearer token | `*.rs` |

**Config files to check:** `.env`, `Rocket.toml`, `config.toml`

## C# (`CC_LANGUAGE=csharp`)

| Pattern | Context | File types |
|---------|---------|------------|
| `"ConnectionStrings".*"Server=` | Connection string with server/password | `appsettings*.json` |
| `Configuration\["[^"]+"\]\s*=\s*"` | Hardcoded config override | `*.cs` |
| `Password=[^;{]+;` | Password in connection string | `*.json`, `*.config` |
| `AddUserSecrets` | User secrets configured (good — verify it's used) | `*.cs`, `*.csproj` |

**Config files to check:** `appsettings.json`, `appsettings.*.json`, `web.config`, `*.csproj`
