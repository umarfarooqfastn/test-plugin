#!/usr/bin/env bash
# fastn agent skills - one-line installer.
#
#   curl -fsSL https://raw.githubusercontent.com/umarfarooqfastn/test-plugin/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- integration_builder
#   curl -fsSL .../install.sh | bash -s -- --agent codex --global all
#
# Downloads skill folders straight from the repo and drops them into the skills
# directory your agent actually scans. No git, no plugin system, no clone.

set -euo pipefail

RAW="https://raw.githubusercontent.com/umarfarooqfastn/test-plugin/main"
ALL_SKILLS="gateway integration_builder connector_builder unified_api workflow_verifier"

AGENT=""
SCOPE="project"
DEST=""
WANTED=""

usage() {
  cat <<'EOF'
fastn agent skills installer

Usage:
  install.sh [options] [skill ...]

Skills (default: all):
  gateway              Operating manual for the fastn gateway. Start here.
  integration_builder  Plan/map/build/verify fastn integrations and workflows.
  connector_builder    Build and debug fastn connectors, auth, actions, webhooks.
  unified_api          Configure and use the fastn Unified API.
  workflow_verifier    Verify a workflow end to end with runtime evidence.

Options:
  --agent <name>   claude-code | codex | cursor | windsurf | gemini | copilot |
                   claude-ai | auto   (default: auto-detect)
  --global         Install for all projects (~/...) instead of this project
  --dir <path>     Install into an explicit directory, overriding --agent
  --list           Print available skills and exit
  -h, --help       Show this help

Examples:
  install.sh                                  # all skills, auto-detected agent
  install.sh gateway integration_builder      # just these two
  install.sh --agent codex --global all       # ~/.agents/skills
  install.sh --agent claude-ai                # build .skill files to upload
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="${2:-}"; shift 2 ;;
    --agent=*) AGENT="${1#*=}"; shift ;;
    --global|--user) SCOPE="global"; shift ;;
    --project) SCOPE="project"; shift ;;
    --dir) DEST="${2:-}"; shift 2 ;;
    --dir=*) DEST="${1#*=}"; shift ;;
    --list) echo "$ALL_SKILLS" | tr ' ' '\n'; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    all) WANTED="$ALL_SKILLS"; shift ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) WANTED="${WANTED} $1"; shift ;;
  esac
done

[ -n "${WANTED// /}" ] || WANTED="$ALL_SKILLS"

for s in $WANTED; do
  case " $ALL_SKILLS " in
    *" $s "*) ;;
    *) echo "unknown skill: $s (try --list)" >&2; exit 2 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "required command not found: $1" >&2; exit 1; }; }
need curl
need unzip

# ---- pick the destination -----------------------------------------------
detect_agent() {
  if [ -n "${CLAUDE_CODE:-}${CLAUDECODE:-}" ]; then echo claude-code; return; fi
  if [ -d .claude ];          then echo claude-code; return; fi
  if [ -d .agents ];          then echo codex;       return; fi
  if [ -d .cursor ];          then echo cursor;      return; fi
  if [ -d .windsurf ];        then echo windsurf;    return; fi
  if [ -d .gemini ];          then echo gemini;      return; fi
  if [ -d "$HOME/.claude" ];  then echo claude-code; return; fi
  echo codex
}

if [ -z "$AGENT" ] || [ "$AGENT" = auto ]; then
  AGENT="$(detect_agent)"
  echo "detected agent: $AGENT (override with --agent)"
fi

if [ -z "$DEST" ]; then
  case "$AGENT" in
    claude-code)        [ "$SCOPE" = global ] && DEST="$HOME/.claude/skills"   || DEST=".claude/skills" ;;
    cursor)             [ "$SCOPE" = global ] && DEST="$HOME/.agents/skills"   || DEST=".agents/skills" ;;
    windsurf)           [ "$SCOPE" = global ] && DEST="$HOME/.agents/skills"   || DEST=".agents/skills" ;;
    gemini)             [ "$SCOPE" = global ] && DEST="$HOME/.agents/skills"   || DEST=".agents/skills" ;;
    copilot)            [ "$SCOPE" = global ] && DEST="$HOME/.copilot/skills"  || DEST=".agents/skills" ;;
    # account-based clients have no skills directory; stage bundles to upload
    claude-ai|claude-desktop|cowork) DEST="./fastn-skills" ;;
    codex|agents|*)     [ "$SCOPE" = global ] && DEST="$HOME/.agents/skills"   || DEST=".agents/skills" ;;
  esac
fi

# ---- claude.ai / Desktop / Cowork: no skills directory, build .skill files
if [ "$AGENT" = "claude-ai" ] || [ "$AGENT" = "claude-desktop" ] || [ "$AGENT" = "cowork" ]; then
  OUT="${DEST:-./fastn-skills}"
  mkdir -p "$OUT"
  for s in $WANTED; do
    curl -fsSL "$RAW/dist/$s.skill" -o "$OUT/$s.skill"
    unzip -l "$OUT/$s.skill" >/dev/null || { echo "corrupt bundle: $s" >&2; exit 1; }
    echo "  $OUT/$s.skill"
  done
  cat <<EOF

Done. These clients store skills in your account, not on disk.
Upload each .skill file at:  Customize > Skills > Add
(Settings > Capabilities > Code Execution must be on.)
EOF
  exit 0
fi

# ---- everything else: unzip straight into the skills directory ----------
mkdir -p "$DEST"
if ! touch "$DEST/.fastn-probe" 2>/dev/null; then
  echo "cannot write to $DEST" >&2
  echo "retry with --global, or --dir <writable path>" >&2
  exit 1
fi
rm -f "$DEST/.fastn-probe"

echo "installing into $DEST"
for s in $WANTED; do
  curl -fsSL "$RAW/dist/$s.zip" -o "$DEST/$s.zip"
  unzip -oq "$DEST/$s.zip" -d "$DEST"
  rm -f "$DEST/$s.zip" 2>/dev/null || true
  if [ ! -f "$DEST/$s/SKILL.md" ]; then
    echo "install failed for $s (no SKILL.md)" >&2
    exit 1
  fi
  refs=""
  if [ -d "$DEST/$s/references" ]; then
    refs=" + $(ls "$DEST/$s/references" | wc -l | tr -d ' ') references"
  fi
  echo "  $s$refs"
done

cat <<EOF

Done. Installed to $DEST

Next:
  - Claude Code picks these up live; others may need a restart if the
    directory did not exist before.
  - Copilot CLI / Gemini CLI: run /skills reload
  - Start with the gateway skill, then let it route you to the rest.
EOF
