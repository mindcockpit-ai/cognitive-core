# GitHub App Reviewer — Setup Guide

Set up a GitHub App so the `code-standards-reviewer` agent can post PR reviews as a separate identity, satisfying branch protection review requirements without human intervention.

## Why

- **Solo developers** can't self-approve their own PRs — branch protection blocks it
- **Teams** want agent reviews to appear as a distinct bot identity, not under a developer's name
- **GitHub Apps** are the officially recommended path for machine identities (not personal accounts)

## Prerequisites

- GitHub account with admin access to the target repo(s)
- `openssl`, `jq`, `curl` installed locally
- A GitHub organization (recommended — see Limitations)

## Step 1: Create the GitHub App

1. Go to **GitHub Settings** → **Developer settings** → **GitHub Apps** → **New GitHub App**
2. Fill in:

| Field | Value |
|-------|-------|
| App name | `your-reviewer-app` (must be globally unique) |
| Homepage URL | Your org/project URL |
| Webhook | **Uncheck** "Active" (not needed for token-based auth) |

3. Set **Permissions**:

| Permission | Access | Why |
|------------|--------|-----|
| Pull requests | Read & Write | Post reviews, approve/request changes |
| Contents | Read | Read PR diffs and file contents |
| Issues | Read & Write | Post comments, link reviews to issues |

4. Under **Where can this GitHub App be installed?**, select **Any account** for multi-org use
5. Click **Create GitHub App**
6. Note the **App ID** from the app's settings page

## Step 2: Generate Private Key

1. On the App settings page, scroll to **Private keys**
2. Click **Generate a private key** — a `.pem` file downloads
3. Move it to a secure location:

```bash
mkdir -p ~/.config/github
mv ~/Downloads/your-app-name.*.pem ~/.config/github/reviewer-app.pem
chmod 600 ~/.config/github/reviewer-app.pem
```

## Step 3: Install the App

1. Go to the App's public page: `https://github.com/apps/your-app-name`
2. Click **Install** and select the organization or user account
3. Choose **All repositories** or select specific repos
4. Note the **Installation ID** from the URL: `https://github.com/settings/installations/XXXXXX`

For multiple organizations, repeat the installation and note each Installation ID.

### Finding Installation IDs

```bash
# List all installations (requires the JWT — use the token script)
TOKEN=$(core/utilities/github-app-token.sh)
curl -s -H "Authorization: token $TOKEN" \
  https://api.github.com/installation/repositories | jq '.repositories[].full_name'
```

Or check the URL when viewing each installation in GitHub Settings.

## Step 4: Configure

Create the config file from the template:

```bash
cp cicd/templates/reviewer-app.json.example ~/.config/github/reviewer-app.json
chmod 600 ~/.config/github/reviewer-app.json
```

Edit with your values:

```json
{
    "app_id": "2980894",
    "client_id": "Iv23liXXXXXXXXXXXXXX",
    "app_name": "your-reviewer-app",
    "default_installation_id": "113290372",
    "installations": {
        "your-org": "113290372",
        "your-user": "113291348"
    }
}
```

Enable in `cognitive-core.conf`:

```bash
CC_REVIEWER_APP_ENABLED="true"
CC_REVIEWER_APP_CONFIG="${HOME}/.config/github/reviewer-app.json"
CC_REVIEWER_APP_PEM="${HOME}/.config/github/reviewer-app.pem"
```

## Step 5: Verify

```bash
# Generate a token
TOKEN=$(core/utilities/github-app-token.sh)
echo "Token: ${TOKEN:0:10}..."

# Check which repos the token can access
curl -s -H "Authorization: token $TOKEN" \
  https://api.github.com/installation/repositories | jq '.repositories[].full_name'

# Test posting a PR comment (dry run)
curl -s -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/OWNER/REPO/pulls/1/reviews" | jq '.[] | {user: .user.login, state: .state}'
```

## How It Works

```
┌─────────────┐    JWT (10min)    ┌──────────┐
│ Private Key │ ───────────────→  │ GitHub   │
│ (.pem file) │                   │ API      │
└─────────────┘                   │          │
                                  │ Exchange │
┌─────────────┐  Install Token   │ JWT for  │
│ Agent posts │ ←──────────────  │ token    │
│ PR review   │   (1 hour TTL)   └──────────┘
└─────────────┘
```

1. `github-app-token.sh` creates a JWT signed with the private key
2. Exchanges the JWT for a short-lived installation access token (1h TTL)
3. The agent uses the token to call GitHub API (post review, approve PR)
4. Reviews appear as `your-app-name[bot]` — a separate identity

## Agent Integration

The `code-standards-reviewer` agent uses the token to post PR reviews:

```bash
TOKEN=$(core/utilities/github-app-token.sh)

# Approve
curl -s -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/OWNER/REPO/pulls/PR_NUMBER/reviews" \
  -d '{"event":"APPROVE","body":"All checks pass. Approved by reviewer bot."}'

# Request changes
curl -s -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/OWNER/REPO/pulls/PR_NUMBER/reviews" \
  -d '{"event":"REQUEST_CHANGES","body":"Found blocking issues:\n\n- Issue 1\n- Issue 2"}'
```

## Multi-Organization Setup

The `installations` map in the config JSON supports multiple orgs:

```json
{
    "installations": {
        "acme-corp": "111111111",
        "acme-oss": "222222222"
    }
}
```

Override per invocation:

```bash
# Use a specific installation
github-app-token.sh --installation-id 222222222

# Or the default
github-app-token.sh
```

## Limitations

### Self-Approval Policy

GitHub prevents "self-approval through proxy": if the App owner is the same person/org that opened the PR, the approval **does not satisfy** branch protection review requirements.

| Scenario | Approval Counts? |
|----------|-----------------|
| App owned by **org**, PR by **org member** | Depends on org role |
| App owned by **org**, PR by **external contributor** | Yes |
| App owned by **user**, PR by **same user** | No |
| App owned by **org**, PR by **sole org owner** | No |

**Recommendation**: Transfer App ownership to an organization where the PR author is a member but not the sole owner. For true solo developers, `--admin` bypass on merge is the pragmatic solution.

### Token Lifetime

- JWT: 10 minutes (for the exchange only)
- Installation token: 1 hour (for API calls)
- Tokens are single-use per generation — generate fresh for each review session

## Security

- **Never commit** the PEM file or config JSON to version control
- Set file permissions to `600` (owner read/write only)
- The PEM file is equivalent to a password — treat it accordingly
- Rotate the private key periodically (GitHub App settings → Private keys)
- Installation tokens are scoped to the specific installation's repos only

## New Machine Setup

On a new development machine:

1. Copy `~/.config/github/reviewer-app.pem` from a secure backup
2. Copy `~/.config/github/reviewer-app.json` or create from template
3. Verify: `core/utilities/github-app-token.sh` outputs a token

The token script and agent definitions are in the repo — only the credentials need manual setup.

## Reference Implementation

See the TIMS project for a working example:
- Token script: `bin/utilities/ghAppToken.sh`
- App: `mindcockpit-reviewer` (owned by mindcockpit-ai org)
- Installed on: `wolaschka` (personal) + `mindcockpit-ai` (org)
