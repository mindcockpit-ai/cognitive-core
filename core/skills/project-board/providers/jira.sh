#!/bin/bash
# shellcheck disable=SC2034
# =============================================================================
# jira.sh — Jira Cloud/Data Center provider for project-board skill
#
# Implements the project-board provider interface using Jira REST API v3.
# Supports both Jira Cloud (Atlassian) and Jira Data Center (on-prem).
#
# Prerequisites: curl, jq (or python3 fallback)
# Config: CC_JIRA_URL, CC_JIRA_PROJECT, CC_JIRA_EMAIL, CC_JIRA_TOKEN
#
# Auth: Basic Auth (email:api_token) for Cloud, Bearer token for Data Center.
#       Set CC_JIRA_AUTH_TYPE="bearer" for Data Center.
#
# Usage: ./jira.sh <group> <command> [args...]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_provider-lib.sh
source "$SCRIPT_DIR/../_provider-lib.sh"

# ---- Configuration ----

_jira_require_config() {
    local missing=()
    [[ -z "${CC_JIRA_URL:-}" ]] && missing+=("CC_JIRA_URL")
    [[ -z "${CC_JIRA_PROJECT:-}" ]] && missing+=("CC_JIRA_PROJECT")
    [[ -z "${CC_JIRA_TOKEN:-}" ]] && missing+=("CC_JIRA_TOKEN")
    if [[ ${#missing[@]} -gt 0 ]]; then
        _pb_die "Missing Jira config: ${missing[*]}. Set in cognitive-core.conf"
    fi
}

# ---- HTTP helpers ----

_jira_auth_header() {
    if [[ "${CC_JIRA_AUTH_TYPE:-basic}" == "bearer" ]]; then
        echo "Authorization: Bearer ${CC_JIRA_TOKEN}"
    else
        local encoded
        encoded=$(printf '%s:%s' "${CC_JIRA_EMAIL:-}" "$CC_JIRA_TOKEN" | base64)
        echo "Authorization: Basic ${encoded}"
    fi
}

_jira_api() {
    local method="$1" endpoint="$2"
    shift 2
    local url="${CC_JIRA_URL}/rest/api/3${endpoint}"
    local auth
    auth=$(_jira_auth_header)

    local response http_code
    response=$(curl -s -w "\n%{http_code}" \
        -X "$method" \
        -H "$auth" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "$@" \
        "$url")

    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 400 ]]; then
        _pb_error "Jira API error ($http_code): $body"
        return 1
    fi
    echo "$body"
}

_jira_agile_api() {
    local method="$1" endpoint="$2"
    shift 2
    local url="${CC_JIRA_URL}/rest/agile/1.0${endpoint}"
    local auth
    auth=$(_jira_auth_header)

    curl -s \
        -X "$method" \
        -H "$auth" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        "$@" \
        "$url"
}

# ---- Markdown + Wiki Markup to ADF conversion ----
# Converts markdown AND Jira wiki markup to Atlassian Document Format (ADF).
# Supports: ## and h1. headings, **bold** and *wiki bold*, _italic_ and {{monospace}},
# `code`, - [ ] tasks, - and * bullet lists, {code:lang} blocks,
# ||table|| headers, [text|url] links, ---- horizontal rules, paragraphs.
# NOT supported: # ordered lists (ambiguous with markdown headings), -strikethrough-.
# Wiki patterns take precedence over Markdown where they conflict.
# Plain text without markup is wrapped in a single paragraph (backward compatible).
# No strikethrough (-text-) — false-positive rate on hyphenated words is unacceptable.

_jira_md_to_adf() {
    local text="$1"
    python3 -c "
import json, sys, re, uuid

def local_id():
    return uuid.uuid4().hex[:12]

# --- Code block extraction (BEFORE any inline processing) ---
CODE_BLOCKS = []

def extract_code_blocks(text):
    '''Extract {code:lang}...{code} and \`\`\`lang...\`\`\` blocks, replace with placeholders.'''
    result = text
    # Wiki code blocks: {code:lang}...{code} or {code}...{code}
    # Use non-greedy match with explicit non-brace chars to avoid ReDoS
    for m in reversed(list(re.finditer(r'\{code(?::([^}]*))?\}(.*?)\{code\}', result, re.DOTALL))):
        lang = m.group(1) or ''
        code_text = m.group(2)
        idx = len(CODE_BLOCKS)
        CODE_BLOCKS.append((lang, code_text))
        result = result[:m.start()] + '\\x00CODEBLOCK' + str(idx) + '\\x00' + result[m.end():]
    # Markdown fenced code blocks: \`\`\`lang ... \`\`\`
    for m in reversed(list(re.finditer(r'\`\`\`([^\\n]*)\\n(.*?)\`\`\`', result, re.DOTALL))):
        lang = m.group(1).strip()
        code_text = m.group(2)
        idx = len(CODE_BLOCKS)
        CODE_BLOCKS.append((lang, code_text))
        result = result[:m.start()] + '\\x00CODEBLOCK' + str(idx) + '\\x00' + result[m.end():]
    return result

def parse_inline(text):
    '''Parse inline wiki markup and markdown into ADF marks.
    Order: wiki monospace {{}} > wiki bold * > markdown bold ** > wiki italic _ >
           markdown italic * > markdown code \` > wiki links [text|url]
    No strikethrough — hyphenated words must pass through unmangled.'''
    nodes = []
    # Combined pattern for all inline marks (no nested quantifiers)
    pattern = r'(\{\{[^}]+\}\}|\*\*[^*]+\*\*|\*[^*]+\*|_[^_]+_|\`[^\`]+\`|\[[^\]]+\])'
    parts = re.split(pattern, text)
    for part in parts:
        if not part:
            continue
        # Wiki monospace: {{text}}
        if part.startswith('{{') and part.endswith('}}'):
            nodes.append({'type': 'text', 'text': part[2:-2], 'marks': [{'type': 'code'}]})
        # Markdown bold: **text**
        elif part.startswith('**') and part.endswith('**'):
            nodes.append({'type': 'text', 'text': part[2:-2], 'marks': [{'type': 'strong'}]})
        # Wiki/Markdown bold: *text* (only if not at word boundary with other *)
        elif part.startswith('*') and part.endswith('*') and not part.startswith('**'):
            nodes.append({'type': 'text', 'text': part[1:-1], 'marks': [{'type': 'strong'}]})
        # Wiki italic: _text_
        elif part.startswith('_') and part.endswith('_'):
            nodes.append({'type': 'text', 'text': part[1:-1], 'marks': [{'type': 'em'}]})
        # Markdown inline code: \`text\`
        elif part.startswith('\`') and part.endswith('\`'):
            nodes.append({'type': 'text', 'text': part[1:-1], 'marks': [{'type': 'code'}]})
        # Wiki link: [text|url] or [url]
        elif part.startswith('[') and part.endswith(']'):
            inner = part[1:-1]
            if '|' in inner:
                link_text, url = inner.split('|', 1)
            else:
                link_text = inner
                url = inner
            # Defense-in-depth: neutralize javascript:/data: URIs (XSS on Jira DC)
            if not url.strip().startswith(('http://', 'https://', 'mailto:', '#', '/')):
                url = '#'
            nodes.append({'type': 'text', 'text': link_text, 'marks': [{'type': 'link', 'attrs': {'href': url}}]})
        else:
            nodes.append({'type': 'text', 'text': part})
    return nodes if nodes else [{'type': 'text', 'text': text}]

text = sys.stdin.read()

# Step 1: Extract code blocks before line processing
text = extract_code_blocks(text)

lines = text.split('\\n')
content = []
i = 0

while i < len(lines):
    line = lines[i]

    # Code block placeholder — restore as codeBlock node
    m = re.match(r'^\\x00CODEBLOCK(\d+)\\x00$', line.strip())
    if m:
        idx = int(m.group(1))
        lang, code_text = CODE_BLOCKS[idx]
        node = {'type': 'codeBlock', 'content': [{'type': 'text', 'text': code_text}]}
        if lang:
            node['attrs'] = {'language': lang}
        content.append(node)
        i += 1
        continue

    # Wiki heading: h1. through h6.
    m = re.match(r'^h([1-6])\.\s+(.*)', line)
    if m:
        level = int(m.group(1))
        content.append({
            'type': 'heading',
            'attrs': {'level': level},
            'content': parse_inline(m.group(2))
        })
        i += 1
        continue

    # Markdown heading: ## or ###
    m = re.match(r'^(#{1,6})\s+(.*)', line)
    if m:
        level = len(m.group(1))
        content.append({
            'type': 'heading',
            'attrs': {'level': level},
            'content': parse_inline(m.group(2))
        })
        i += 1
        continue

    # Horizontal rule: ---- (4+ dashes on own line)
    if re.match(r'^-{4,}\s*$', line):
        content.append({'type': 'rule'})
        i += 1
        continue

    # Wiki table: ||Header|| or |Cell| rows
    if re.match(r'^(\|\||\|)[^|]', line):
        rows = []
        while i < len(lines) and re.match(r'^(\|\||\|)[^|]', lines[i]):
            row_line = lines[i]
            is_header = row_line.startswith('||')
            if is_header:
                # Split ||H1||H2|| — use || as delimiter, drop empty first/last
                cells_raw = row_line.split('||')
                cells_raw = [c for c in cells_raw if c is not None]
                # Remove leading/trailing empty strings from split
                if cells_raw and cells_raw[0] == '':
                    cells_raw = cells_raw[1:]
                if cells_raw and cells_raw[-1] == '':
                    cells_raw = cells_raw[:-1]
                cell_type = 'tableHeader'
            else:
                # Split |C1|C2| — use | as delimiter, drop empty first/last
                cells_raw = row_line.split('|')
                if cells_raw and cells_raw[0] == '':
                    cells_raw = cells_raw[1:]
                if cells_raw and cells_raw[-1] == '':
                    cells_raw = cells_raw[:-1]
                cell_type = 'tableCell'
            cells = []
            for cell_text in cells_raw:
                cell_content = parse_inline(cell_text.strip()) if cell_text.strip() else [{'type': 'text', 'text': ''}]
                cells.append({
                    'type': cell_type,
                    'content': [{'type': 'paragraph', 'content': cell_content}]
                })
            if cells:
                rows.append({'type': 'tableRow', 'content': cells})
            i += 1
        if rows:
            content.append({'type': 'table', 'content': rows})
        continue

    # Task item: - [ ] or - [x]
    m = re.match(r'^[\s]*-\s*\[([ xX])\]\s*(.*)', line)
    if m:
        tasks = []
        while i < len(lines):
            tm = re.match(r'^[\s]*-\s*\[([ xX])\]\s*(.*)', lines[i])
            if not tm:
                break
            state = 'DONE' if tm.group(1).lower() == 'x' else 'TODO'
            tasks.append({
                'type': 'taskItem',
                'attrs': {'localId': local_id(), 'state': state},
                'content': parse_inline(tm.group(2))
            })
            i += 1
        content.append({
            'type': 'taskList',
            'attrs': {'localId': local_id()},
            'content': tasks
        })
        continue

    # Bullet list item: - text or * text (markdown and wiki)
    m = re.match(r'^[\s]*[-*]\s+(.*)', line)
    if m:
        items = []
        while i < len(lines):
            bm = re.match(r'^[\s]*[-*]\s+(.*)', lines[i])
            if not bm:
                break
            items.append({
                'type': 'listItem',
                'content': [{'type': 'paragraph', 'content': parse_inline(bm.group(1))}]
            })
            i += 1
        content.append({'type': 'bulletList', 'content': items})
        continue

    # Empty line — skip
    if not line.strip():
        i += 1
        continue

    # Regular paragraph
    content.append({
        'type': 'paragraph',
        'content': parse_inline(line)
    })
    i += 1

# Fallback: if no markup detected, wrap entire text as single paragraph
if not content:
    content = [{'type': 'paragraph', 'content': [{'type': 'text', 'text': text.strip()}]}]

doc = {'type': 'doc', 'version': 1, 'content': content}
print(json.dumps(doc))
" <<< "$text"
}

# ---- Status Mapping ----
# Maps cognitive-core canonical status keys to Jira status names.
# Override via CC_JIRA_STATUS_MAP in cognitive-core.conf.
# Format: "roadmap=To Do|backlog=Backlog|todo=Selected|progress=In Progress|testing=In Review|done=Done|canceled=Canceled"

_jira_status_name() {
    local key="$1"
    local map="${CC_JIRA_STATUS_MAP:-roadmap=Roadmap|backlog=Backlog|todo=To Do|progress=In Progress|testing=In Review|done=Done|canceled=Canceled}"

    local pair
    IFS='|' read -ra pairs <<< "$map"
    for pair in "${pairs[@]}"; do
        local k="${pair%%=*}"
        local v="${pair#*=}"
        if [[ "$k" == "$key" ]]; then
            echo "$v"
            return 0
        fi
    done
    echo "$key"
}

# ---- Priority Mapping ----

_jira_priority_name() {
    local key="$1"
    case "$key" in
        p0-critical|p0) echo "Highest" ;;
        p1-high|p1)     echo "High" ;;
        p2-medium|p2)   echo "Medium" ;;
        p3-low|p3)      echo "Low" ;;
        *)              echo "Medium" ;;
    esac
}

# ---- Input validation ----

_jira_validate_key() {
    local key="$1"
    if [[ ! "$key" =~ ^[A-Za-z][A-Za-z0-9_]+-[0-9]+$ ]]; then
        _pb_die "Invalid Jira issue key format: $key (expected PROJECT-123)"
    fi
}

# ---- URL helpers ----

_jira_issue_url() { echo "${CC_JIRA_URL}/browse/$1"; }

# ---- Transition helpers ----

_jira_get_transitions() {
    local issue_key="$1"
    _jira_api GET "/issue/${issue_key}/transitions"
}

_jira_do_transition() {
    local issue_key="$1" target_status="$2"

    local transitions
    transitions=$(_jira_get_transitions "$issue_key") || return 1

    local transition_id _jira_transition_stderr
    _jira_transition_stderr=$(mktemp)
    transition_id=$(echo "$transitions" | _CC_TARGET="$target_status" python3 -c "
import json, sys, os
data = json.load(sys.stdin)
target = os.environ['_CC_TARGET']
for t in data.get('transitions', []):
    if t['to']['name'].lower() == target.lower():
        print(t['id'])
        sys.exit(0)
available = [t['to']['name'] for t in data.get('transitions', [])]
print('Available: ' + ', '.join(available), file=sys.stderr)
sys.exit(1)
" 2>"$_jira_transition_stderr") || {
        local avail
        avail=$(cat "$_jira_transition_stderr" 2>/dev/null)
        rm -f "$_jira_transition_stderr"
        _pb_die "No transition to '$target_status' from current status. ${avail}"
    }
    rm -f "$_jira_transition_stderr"

    _jira_api POST "/issue/${issue_key}/transitions" \
        -d "{\"transition\":{\"id\":\"$transition_id\"}}" >/dev/null
}

# =============================================================================
# ISSUE COMMANDS
# =============================================================================

pb_issue_list() {
    local priority="" area="" state="open"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --priority) priority="$2"; shift 2 ;;
            --area)     area="$2"; shift 2 ;;
            --state)    state="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    local jql="project = ${CC_JIRA_PROJECT}"
    if [[ "$state" == "open" ]]; then
        jql+=" AND statusCategory != Done"
    elif [[ "$state" == "closed" ]]; then
        jql+=" AND statusCategory = Done"
    fi
    if [[ -n "$priority" ]]; then
        local jira_priority
        jira_priority=$(_jira_priority_name "$priority")
        jql+=" AND priority = \"$jira_priority\""
    fi
    if [[ -n "$area" ]]; then
        jql+=" AND labels = \"area:$area\""
    fi
    jql+=" ORDER BY priority ASC, created DESC"

    _jira_api GET "/search/jql?jql=$(_CC_JQL="$jql" python3 -c "import urllib.parse,os; print(urllib.parse.quote(os.environ['_CC_JQL']))")&fields=summary,status,priority,assignee,labels&maxResults=50"
}

pb_issue_create() {
    local title="" labels="" body="" assignee=""
    title="${1:-}"; shift 2>/dev/null || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --labels)   labels="$2"; shift 2 ;;
            --body)     body="$2"; shift 2 ;;
            --assignee) assignee="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    [[ -z "$title" ]] && _pb_die "Title required"

    # Build labels array
    local labels_json="[]"
    if [[ -n "$labels" ]]; then
        labels_json=$(echo "$labels" | python3 -c "
import sys, json
labels = [l.strip() for l in sys.stdin.read().split(',')]
print(json.dumps(labels))
")
    fi

    # Build description in ADF format (with markdown-to-ADF conversion)
    local description_json="null"
    if [[ -n "$body" ]]; then
        description_json=$(_jira_md_to_adf "$body")
    fi

    local payload
    payload=$(_CC_PROJECT="$CC_JIRA_PROJECT" _CC_TITLE="$title" _CC_ASSIGNEE="$assignee" _CC_LABELS="$labels_json" _CC_DESC="$description_json" python3 -c "
import json, os
data = {
    'fields': {
        'project': {'key': os.environ['_CC_PROJECT']},
        'summary': os.environ['_CC_TITLE'],
        'issuetype': {'name': 'Task'},
        'labels': json.loads(os.environ['_CC_LABELS'])
    }
}
desc_raw = os.environ['_CC_DESC']
if desc_raw != 'null':
    data['fields']['description'] = json.loads(desc_raw)
assignee = os.environ['_CC_ASSIGNEE']
if assignee:
    data['fields']['assignee'] = {'accountId': assignee}
print(json.dumps(data))
")

    local result
    result=$(_jira_api POST "/issue" -d "$payload") || return 1

    local issue_key
    issue_key=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['key'])")
    local issue_id
    issue_id=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

    echo "{\"key\":\"$issue_key\",\"id\":\"$issue_id\",\"url\":\"$(_jira_issue_url "$issue_key")\"}"
}

pb_issue_close() {
    local issue_key="${1:?Issue key required}"
    shift
    local comment=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --comment) comment="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    if [[ -n "$comment" ]]; then
        pb_issue_comment "$issue_key" "$comment"
    fi

    _jira_do_transition "$issue_key" "$(_jira_status_name "done")"
    _pb_success "Issue $issue_key closed"
}

pb_issue_reopen() {
    local issue_key="${1:?Issue key required}"
    _jira_do_transition "$issue_key" "$(_jira_status_name "todo")"
    _pb_success "Issue $issue_key reopened"
}

pb_issue_view() {
    local issue_key="${1:?Issue key required}"
    shift
    local fields="summary,status,priority,assignee,labels,description,comment"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) fields="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    local url
    url=$(_jira_issue_url "$issue_key")
    _jira_api GET "/issue/${issue_key}?fields=${fields}" | _CC_URL="$url" python3 -c "
import json, sys, os
data = json.load(sys.stdin)
data['url'] = os.environ['_CC_URL']
json.dump(data, sys.stdout, indent=2)
"
}

pb_issue_comment() {
    local issue_key="${1:?Issue key required}"
    local body="${2:?Comment body required}"

    local adf_doc
    adf_doc=$(_jira_md_to_adf "$body")

    local payload
    payload=$(python3 -c "
import json, sys
adf = json.loads(sys.stdin.read())
print(json.dumps({'body': adf}))
" <<< "$adf_doc")

    _jira_api POST "/issue/${issue_key}/comment" -d "$payload" >/dev/null
    _pb_success "Comment added to $issue_key"
}

pb_issue_assign() {
    local issue_key="${1:?Issue key required}"
    local user="${2:?Username or account ID required}"

    # Try accountId first (Jira Cloud), fall back to name
    _jira_api PUT "/issue/${issue_key}/assignee" \
        -d "{\"accountId\":\"$user\"}" 2>/dev/null || \
    _jira_api PUT "/issue/${issue_key}/assignee" \
        -d "{\"name\":\"$user\"}" 2>/dev/null || \
        _pb_die "Could not assign $user to $issue_key"

    _pb_success "Assigned $user to $issue_key"
}

# =============================================================================
# BOARD COMMANDS
# =============================================================================

pb_board_summary() {
    local jql="project = ${CC_JIRA_PROJECT} AND statusCategory != Done"
    local result
    result=$(_jira_api GET "/search/jql?jql=$(_CC_JQL="$jql" python3 -c "import urllib.parse,os; print(urllib.parse.quote(os.environ['_CC_JQL']))")&fields=status&maxResults=200")

    echo "$result" | python3 -c "
import json, sys
from collections import Counter
data = json.load(sys.stdin)
counts = Counter(
    issue['fields']['status']['name']
    for issue in data.get('issues', [])
)
result = {
    'url': '${CC_JIRA_URL}/jira/software/projects/${CC_JIRA_PROJECT}/board',
    'columns': dict(sorted(counts.items())),
    'total': data.get('total', 0)
}
json.dump(result, sys.stdout, indent=2)
"
}

pb_board_status() {
    local issue_key="${1:?Issue key required}"
    local result
    result=$(_jira_api GET "/issue/${issue_key}?fields=status,assignee")

    echo "$result" | _CC_BASE_URL="${CC_JIRA_URL}" python3 -c "
import json, sys, os
data = json.load(sys.stdin)
base_url = os.environ['_CC_BASE_URL']
key = data['key']
json.dump({
    'key': key,
    'status': data['fields']['status']['name'],
    'status_category': data['fields']['status']['statusCategory']['name'],
    'assignee': data['fields'].get('assignee', {}).get('displayName', 'Unassigned'),
    'url': f'{base_url}/browse/{key}'
}, sys.stdout, indent=2)
"
}

pb_board_move() {
    local issue_key="${1:?Issue key required}"
    local status_key="${2:?Status key required}"

    local target_status
    target_status=$(_jira_status_name "$status_key")

    _jira_do_transition "$issue_key" "$target_status"
    _pb_success "Issue $issue_key moved to $target_status"
}

pb_board_add() {
    # In Jira, issues are automatically on the board when they belong to the project.
    # This is a no-op for Jira, but we return success for interface compatibility.
    local issue_key="${1:?Issue key required}"
    _pb_success "Issue $issue_key is on the board (Jira: automatic)"
}

pb_board_approve() {
    local issue_key="${1:?Issue key required}"
    shift
    local comment=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --comment) comment="$2"; shift 2 ;;
            *)         shift ;;
        esac
    done

    # Verify issue is in testing status
    local result current_status
    result=$(_jira_api GET "/issue/${issue_key}?fields=status,comment")
    current_status=$(echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['fields']['status']['name'])
" 2>/dev/null)

    local testing_status
    testing_status=$(_jira_status_name "testing")
    if [[ "$current_status" != "$testing_status" ]]; then
        _pb_die "Cannot approve $issue_key — current status is '$current_status', expected '$testing_status'"
    fi

    # Verify evidence exists (at least one comment)
    local comment_count
    comment_count=$(echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(len(data['fields'].get('comment', {}).get('comments', [])))
" 2>/dev/null)

    if [[ "$comment_count" -eq 0 ]]; then
        _pb_die "Cannot approve $issue_key — no verification evidence found (0 comments)"
    fi

    # Set approved label atomically before transitioning (CI checks this label)
    _jira_api PUT "/issue/${issue_key}" \
        -d '{"update":{"labels":[{"add":"approved"}]}}' >/dev/null 2>&1 || true

    # Add approval comment and transition to Done
    local approval_comment="Approved."
    [[ -n "$comment" ]] && approval_comment="Approved: ${comment}"
    pb_issue_comment "$issue_key" "$approval_comment"
    _jira_do_transition "$issue_key" "$(_jira_status_name "done")"

    _pb_success "Issue $issue_key approved and moved to Done"
}

# =============================================================================
# SPRINT COMMANDS
# =============================================================================

pb_sprint_list() {
    if [[ -z "${CC_JIRA_BOARD_ID:-}" ]]; then
        _pb_die "CC_JIRA_BOARD_ID required for sprint operations. Find it: ${CC_JIRA_URL}/rest/agile/1.0/board?projectKeyOrId=${CC_JIRA_PROJECT}"
    fi

    local state="active,future"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all) state="active,future,closed"; shift ;;
            *)     shift ;;
        esac
    done

    _jira_agile_api GET "/board/${CC_JIRA_BOARD_ID}/sprint?state=${state}"
}

pb_sprint_assign() {
    local sprint_name="${1:?Sprint name required}"
    shift
    [[ $# -eq 0 ]] && _pb_die "At least one issue key required"

    if [[ -z "${CC_JIRA_BOARD_ID:-}" ]]; then
        _pb_die "CC_JIRA_BOARD_ID required for sprint operations"
    fi

    # Find sprint ID by name
    local sprints
    sprints=$(pb_sprint_list --all)
    local sprint_id
    sprint_id=$(echo "$sprints" | _CC_SPRINT="$sprint_name" python3 -c "
import json, sys, os
data = json.load(sys.stdin)
target = os.environ['_CC_SPRINT']
for s in data.get('values', []):
    if s['name'] == target:
        print(s['id'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null) || _pb_die "Sprint '$sprint_name' not found"

    # Move issues to sprint
    local issue_keys=()
    for key in "$@"; do
        issue_keys+=("\"$key\"")
    done
    local keys_json
    keys_json=$(IFS=,; echo "[${issue_keys[*]}]")

    _jira_agile_api POST "/sprint/${sprint_id}/issue" \
        -d "{\"issues\":$keys_json}" >/dev/null

    _pb_success "Assigned ${#issue_keys[@]} issues to sprint '$sprint_name'"
}

# =============================================================================
# BRANCH COMMANDS (Git-level, not Jira-specific)
# =============================================================================

pb_branch_create() {
    local issue_key="${1:?Issue key required}"
    local branch_type="${2:-feature}"
    local slug="${3:-}"
    local base="${CC_BRANCH_BASE:-main}"

    local branch_name="${branch_type}/${issue_key}-${slug}"

    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        echo "{\"branch\":\"$branch_name\",\"created\":false,\"message\":\"Branch already exists\"}"
        return 0
    fi

    git checkout -b "$branch_name" "$base" 2>/dev/null
    echo "{\"branch\":\"$branch_name\",\"created\":true,\"base\":\"$base\"}"
}

pb_branch_list() {
    local issue_key="${1:?Issue key required}"
    git branch --list "*${issue_key}*" 2>/dev/null | sed 's/^[* ]*//' || echo "[]"
}

# =============================================================================
# PROVIDER INFO
# =============================================================================

pb_provider_info() {
    cat <<JSON
{
    "provider": "jira",
    "name": "Jira Cloud/Data Center",
    "url": "${CC_JIRA_URL:-}",
    "project": "${CC_JIRA_PROJECT:-}",
    "auth_type": "${CC_JIRA_AUTH_TYPE:-basic}",
    "board_url": "${CC_JIRA_URL:-}/jira/software/projects/${CC_JIRA_PROJECT:-}/board",
    "capabilities": ["issues", "board", "sprints", "labels"],
    "cli": "curl"
}
JSON
}

# =============================================================================
# MAIN
# =============================================================================

_pb_load_config
_jira_require_config
_pb_validate_provider
_pb_route "$@"
