#!/usr/bin/env bash
# Install the Graphify skill for OpenCode and its Python CLI.
#
# Downloads skills/graphify/skill.md from the official Graphify-Labs/graphify
# repository, adapts it for OpenCode, and writes it to the OpenCode global
# skills directory. If the graphify CLI is missing, installs the graphifyy
# package from PyPI with pip --user. Nothing is vendored or re-hosted by this
# project.

set -euo pipefail

REPO="Graphify-Labs/graphify"
NAME="graphify"
CLI_PACKAGE="graphifyy"
REF="${GRAPHIFY_REF:-main}"
SKILLS_DIR="${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
FORCE=0
SKIP_CLI=0
if [[ "${GRAPHIFY_FORCE:-0}" == "1" ]]; then
    FORCE=1
fi
if [[ "${GRAPHIFY_SKIP_CLI:-0}" == "1" ]]; then
    SKIP_CLI=1
fi

usage() {
    cat <<EOF
Usage: install.sh [options]

Options:
  --dir PATH      OpenCode skills root (default: ~/.config/opencode/skills)
  --ref REF       Branch, tag, or commit of the upstream repo (default: main)
  --force         Replace an existing installation
  --skip-cli      Do not install or check the graphify Python CLI
  -h, --help      Show this help

Environment:
  OPENCODE_SKILLS_DIR   Same as --dir
  GRAPHIFY_REF          Same as --ref
  GRAPHIFY_FORCE=1      Same as --force
  GRAPHIFY_SKIP_CLI=1   Same as --skip-cli
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            [[ $# -ge 2 ]] || { echo "Missing value for --dir" >&2; exit 1; }
            SKILLS_DIR="$2"
            shift 2
            ;;
        --ref)
            [[ $# -ge 2 ]] || { echo "Missing value for --ref" >&2; exit 1; }
            REF="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --skip-cli)
            SKIP_CLI=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

for cmd in curl tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is required but was not found in PATH." >&2
        exit 1
    fi
done

TARGET="$SKILLS_DIR/$NAME"
if [[ "$(basename "$TARGET")" != "$NAME" ]]; then
    echo "Refusing to install to an unexpected path: $TARGET" >&2
    exit 1
fi

if [[ -d "$TARGET" ]]; then
    if [[ "$FORCE" -ne 1 ]]; then
        echo "!!  $NAME is already installed at:"
        echo "    $TARGET"
        echo "    Re-run with --force to update it."
        exit 0
    fi
    echo "==> Removing the existing installation"
    rm -rf -- "$TARGET"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/graphify.XXXXXX")"
cleanup() {
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

URL="https://codeload.github.com/$REPO/tar.gz/$REF"
ARCHIVE="$TMP_DIR/skill.tar.gz"

echo "==> Downloading $URL"
curl -fsSL "$URL" -o "$ARCHIVE"

echo "==> Extracting"
tar -xzf "$ARCHIVE" -C "$TMP_DIR"

SKILL_MD=""
while IFS= read -r candidate; do
    case "$candidate" in
        */skills/graphify/*) ;;
        *) continue ;;
    esac
    if grep -Eq "^name:[[:space:]]*$NAME[[:space:]]*$" "$candidate"; then
        SKILL_MD="$candidate"
        break
    fi
done < <(find "$TMP_DIR" -type f -iname "skill.md")

if [[ -z "$SKILL_MD" ]]; then
    echo "Error: could not find skills/graphify/skill.md in the downloaded archive." >&2
    echo "The upstream layout may have changed." >&2
    exit 1
fi

if ! grep -Eq "^description:[[:space:]]*[^[:space:]]" "$SKILL_MD"; then
    echo "Error: the upstream skill.md has no description, so OpenCode will not list the skill." >&2
    exit 1
fi

# Drop the YAML frontmatter and the original top heading, then rewrite the
# command form for OpenCode. The pipeline itself is agent-driven; only the
# invocation syntax changes.
awk '
    BEGIN { frontmatter = 0; body = 0 }
    NR == 1 && $0 == "---" { frontmatter = 1; next }
    frontmatter == 1 && $0 == "---" { frontmatter = 2; next }
    frontmatter == 2 {
        if (!body && $0 ~ /^#[ \t]*\/?graphify[ \t]*$/) { body = 1; next }
        print
    }
' "$SKILL_MD" > "$TMP_DIR/skill.body"

{
    cat <<'HEADER'
---
name: graphify
description: Turn any folder of code, docs, papers, or images into a knowledge graph with graph.html, graph.json, and GRAPH_REPORT.md. Use when the user asks to graph a folder, understand a codebase, or explore a research corpus.
---

# graphify

OpenCode adaptation. In OpenCode invoke this skill with @graphify or by asking to graph a folder; the CLI command is `graphify` (no leading slash).

Notes for OpenCode: the pipeline below runs inside your OpenCode session. Use the task tool where the upstream text says Agent tool, and on Windows use `python` where it says `python3`. Claude-specific integration sections are kept for reference only.

HEADER

    sed \
        -e 's|/graphify|graphify|g' \
        -e 's/Claude vision/model vision/g' \
        -e 's/Claude alone/an LLM alone/g' \
        -e 's/(Claude, costs tokens)/(the model, costs tokens)/g' \
        -e 's/via Claude/via the model/g' \
        -e 's/here in Claude/here in OpenCode/g' \
        -e 's/Agent tool/task tool/g' \
        -e '/./,$!d' \
        "$TMP_DIR/skill.body"

    cat <<'FOOTER'

---

Upstream skill: https://github.com/Graphify-Labs/graphify/blob/main/skills/graphify/skill.md
MIT-declared upstream (main branch). This OpenCode adaptation is unofficial.
FOOTER
} > "$TMP_DIR/SKILL.md"

if ! grep -Eq "^name:[[:space:]]*$NAME[[:space:]]*$" "$TMP_DIR/SKILL.md"; then
    echo "Error: the adapted SKILL.md has an unexpected 'name' field." >&2
    exit 1
fi

if ! grep -Eq "^description:[[:space:]]*[^[:space:]]" "$TMP_DIR/SKILL.md"; then
    echo "Error: the adapted SKILL.md has no description." >&2
    exit 1
fi

if ! grep -q "OpenCode adaptation" "$TMP_DIR/SKILL.md"; then
    echo "Error: the adapted SKILL.md is missing the OpenCode adaptation note." >&2
    exit 1
fi

if grep -Eq "^[[:space:]]*/graphify([[:space:]]|$)" "$TMP_DIR/SKILL.md"; then
    echo "Error: the adapted SKILL.md still contains a slash invocation." >&2
    exit 1
fi

echo "==> Installing to $TARGET"
mkdir -p -- "$SKILLS_DIR" "$TARGET"
cp -- "$TMP_DIR/SKILL.md" "$TARGET/SKILL.md"

if [[ ! -f "$TARGET/SKILL.md" ]]; then
    echo "Error: installation is incomplete: SKILL.md was not written." >&2
    exit 1
fi

echo "OK  Installed $TARGET/SKILL.md"

if [[ "$SKIP_CLI" -ne 1 ]]; then
    PYTHON=""
    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1; then
            PYTHON="$candidate"
            break
        fi
    done

    CLI_FOUND=0
    if command -v graphify >/dev/null 2>&1; then
        CLI_FOUND=1
        echo "OK  graphify CLI found: $(command -v graphify)"
    elif [[ -n "$PYTHON" ]] && "$PYTHON" -c "import graphify" >/dev/null 2>&1; then
        CLI_FOUND=1
        echo "OK  graphify is installed as a Python module, but the console script is not on PATH."
    fi

    if [[ "$CLI_FOUND" -ne 1 ]]; then
        if [[ -z "$PYTHON" ]]; then
            echo "!!  Python was not found. The skill is installed, but the graphify CLI is missing."
            echo "    Install Python 3.10+ and run: python3 -m pip install --user $CLI_PACKAGE"
        else
            echo "==> Installing the graphify CLI ($CLI_PACKAGE)"
            if "$PYTHON" -m pip install --user "$CLI_PACKAGE"; then
                echo "OK  Installed the graphify CLI with pip."
            else
                echo "!!  pip could not install $CLI_PACKAGE. The skill is still installed."
                echo "    Install the CLI manually: $PYTHON -m pip install --user $CLI_PACKAGE"
            fi
            SCRIPTS_DIR="$("$PYTHON" -c 'import sysconfig; print(sysconfig.get_path("scripts", scheme="posix_user"))' 2>/dev/null || true)"
            if [[ -n "$SCRIPTS_DIR" ]]; then
                echo "    Add the Python user bin folder to PATH if 'graphify' is not recognized:"
                echo "      $SCRIPTS_DIR"
            fi
        fi
    fi
fi

cat <<EOF

Start a new OpenCode session and invoke the skill:
  @graphify .                          # graph the current folder
  @graphify ./src --mode deep          # deeper INFERRED edges
  @graphify query "what connects auth to the database?"

The CLI command is 'graphify' when installed (no leading slash).
Source and license: https://github.com/$REPO
EOF
