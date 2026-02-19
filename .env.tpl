# cognitive-core — secret references (op:// format)
# Works with both macOS Keychain (free) and 1Password (auto-detected)
#
# Usage:
#   secrets-run -- bash tests/run-all.sh --json
#
# First time — store your secrets:
#   secrets-store Development/GitHub-PAT multivac-pat
#
# Upgrade to 1Password later — same file, zero changes needed.

MULTIVAC_PAT=op://Development/GitHub-PAT/multivac-pat
