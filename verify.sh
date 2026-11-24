#!/usr/bin/env bash
# Check that the Graphify skill and its CLI are installed for OpenCode.
#
# Validates SKILL.md (name, description, OpenCode adaptation) and probes the
# graphify CLI. Recent graphifyy releases support `graphify --version`; older
# ones do not, so the verifier falls back to `graphify --help` and the
# installed package metadata.

set -euo pipefail

NAME="graphify"
SKILLS_DIR="${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
REQUIRE_CLI=0

usage() {
    cat <<EOF
Usage: verify.sh [options] [SKILLS_DIR]

Options:
  --dir PATH       OpenCode skills root (default: ~/.config/opencode/skills)
  --require-cli    Exit non-zero when the graphify CLI is missing
  -h, --help       Show this help

Environment:
  OPENCODE_SKILLS_DIR   Same as --dir
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            [[ $# -ge 2 ]] || { echo "Missing value for --dir" >&2; exit 1; }
            SKILLS_DIR="$2"
            shift 2
            ;;
        --require-cli)
            REQUIRE_CLI=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ "$1" == -* ]]; then
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
            fi
            SKILLS_DIR="$1"
            shift
            ;;
    esac
done

TARGET="$SKILLS_DIR/$NAME"
SKILL_FILE="$TARGET/SKILL.md"

if [[ ! -f "$SKILL_FILE" ]]; then
    echo "FAIL  $NAME is not installed at $TARGET"
    echo "      Run install.sh first."
    exit 1
fi

if ! grep -Eq "^name:[[:space:]]*$NAME[[:space:]]*$" "$SKILL_FILE"; then
    echo "FAIL  SKILL.md has an unexpected 'name' field."
    exit 1
fi

if ! grep -Eq "^description:[[:space:]]*[^[:space:]]" "$SKILL_FILE"; then
    echo "FAIL  SKILL.md has no description, so OpenCode will not list the skill."
    exit 1
fi

if ! grep -q "OpenCode adaptation" "$SKILL_FILE"; then
    echo "FAIL  SKILL.md is missing the OpenCode adaptation note."
    exit 1
fi

if ! grep -q "@graphify" "$SKILL_FILE"; then
    echo "FAIL  SKILL.md does not document the @graphify invocation."
    exit 1
fi

if grep -Eq "^[[:space:]]*/graphify([[:space:]]|$)" "$SKILL_FILE"; then
    echo "FAIL  SKILL.md still contains a slash invocation (/graphify)."
    exit 1
fi

FILE_COUNT="$(find "$TARGET" -type f | wc -l | tr -d ' ')"
echo "OK  $NAME is installed at $TARGET ($FILE_COUNT files)."

PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
        PYTHON="$candidate"
        break
    fi
done

PKG_VERSION=""
if [[ -n "$PYTHON" ]]; then
    PKG_VERSION="$("$PYTHON" -c 'import importlib.metadata as m; print(m.version("graphifyy"))' 2>/dev/null || true)"
fi

CLI=""
if command -v graphify >/dev/null 2>&1; then
    if OUT="$(graphify --version 2>/dev/null)" && [[ -n "$OUT" ]]; then
        CLI="$(printf '%s\n' "$OUT" | head -n 1)"
    elif graphify --help >/dev/null 2>&1; then
        if [[ -n "$PKG_VERSION" ]]; then
            CLI="graphify (graphifyy $PKG_VERSION; no --version output)"
        else
            CLI="graphify (version output not supported)"
        fi
    fi
fi

if [[ -z "$CLI" && -n "$PYTHON" ]]; then
    if OUT="$("$PYTHON" -m graphify --version 2>/dev/null)" && [[ -n "$OUT" ]]; then
        CLI="$(printf '%s\n' "$OUT" | head -n 1) (python -m graphify)"
    elif "$PYTHON" -m graphify --help >/dev/null 2>&1; then
        if [[ -n "$PKG_VERSION" ]]; then
            CLI="graphifyy $PKG_VERSION (python -m graphify)"
        else
            CLI="python -m graphify (version output not supported)"
        fi
    fi
fi

if [[ -n "$CLI" ]]; then
    echo "OK  graphify CLI: $CLI"
elif [[ "$REQUIRE_CLI" -eq 1 ]]; then
    echo "FAIL  The graphify CLI was not found."
    echo "      Install it with: python3 -m pip install --user graphifyy"
    exit 1
else
    echo "WARN The graphify CLI was not found. The skill is installed and will prompt you if needed."
    echo "      Install it with: python3 -m pip install --user graphifyy"
fi
