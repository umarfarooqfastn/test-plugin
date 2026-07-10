#!/usr/bin/env bash
# SessionStart hook: deterministic, mandatory loading of the fastn gateway skill.
#
# WHY THIS EXISTS
# An MCP server cannot force a client to load anything. The `initialize` instructions
# field is truncated in Claude Code (anthropics/claude-code#43474) and not read at all in
# Claude Desktop (#43749), and a skill only auto-activates on the model's judged relevance
# - so the gateway's usage rules were not reliably in context before the gateway tools were
# used.
#
# WHAT THIS DOES
# Injects the fastn skill body into context at the START of the session, before the first
# prompt and before any tool call. SessionStart fires on startup / resume / clear / compact,
# so the rules load ONCE per session and are RE-INJECTED after a compaction (which would
# otherwise drop them) - never on every tool call. Single source of truth: it reads the same
# SKILL.md the plugin ships, so there is nothing to keep in sync.
set -euo pipefail

# ${CLAUDE_PLUGIN_ROOT} is set when running as an installed plugin; fall back to the
# script's own location so it also works under `claude --plugin-dir ./connect`.
root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
skill="${root}/skills/gateway/SKILL.md"
[ -f "$skill" ] || exit 0

# Strip the leading YAML frontmatter (--- ... ---) and inject the instruction body only.
# A `---` inside the body (markdown rule) is preserved.
body="$(awk 'fence>=2 {print; next} /^---[[:space:]]*$/ {fence++}' "$skill")"
[ -n "$body" ] || body="$(cat "$skill")"  # no frontmatter -> use the whole file

# SessionStart adds stdout to Claude's context. A short lead line makes the rules
# unambiguous; the body is the plugin skill verbatim.
printf '# fastn gateway - mandatory usage rules (auto-loaded; follow these before using any fastn gateway tool)\n\n%s\n' "$body"
exit 0
