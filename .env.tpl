# cognitive-core — 1Password secret references
# Usage: op run --env-file=.env.tpl -- <command>
#
# Store these in 1Password vault "Development" (or your preferred vault):
#   - Item: "GitHub-PAT"     → field: multivac-pat
#
# Example:
#   op run --env-file=.env.tpl -- bash tests/run-all.sh --json

MULTIVAC_PAT=op://Development/GitHub-PAT/multivac-pat
