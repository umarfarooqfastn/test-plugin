#!/usr/bin/env bash
# SessionStart hook: deterministic, mandatory loading of the fastn gateway skill.
#
# WHY THIS EXISTS
# An MCP server cannot force a client to load anything. The `initialize` instructions
# field is truncated in Claude Code (anthropics/claude-code#43474) and not read at all in
# Claude Desktop (#43749), Copilot CLI only includes it for allowlisted servers, and a
# skill only auto-activates on the model's judged relevance - so the gateway's usage
# rules were not reliably in context before the gateway tools were used.
#
# WHAT THIS DOES
# Injects the fastn skill body into context at the START of the session, before the first
# prompt and before any tool call. The hook fires on startup / resume / clear / compact,
# so the rules load ONCE per session and are RE-INJECTED after a compaction (which would
# otherwise drop them) - never on every tool call. Single source of truth: it reads the same
# SKILL.md the plugin ships, so there is nothing to keep in sync.
#
# OUTPUT FORMAT
# One JSON object that both supported clients understand:
# - Claude Code injects hookSpecificOutput.additionalContext (plain stdout would also work
#   there, but Copilot CLI ignores plain stdout, so JSON is the only shared channel).
# - Copilot CLI injects the top-level additionalContext field and ignores hookSpecificOutput.
# Same string in both fields, so both tools receive identical context.
set -euo pipefail

# Resolve paths from this script's own location, NOT from ${CLAUDE_PLUGIN_ROOT}: the plugin
# root differs by install layout (plugins/connect for marketplace installs, the repo root
# for a direct `copilot plugin install fastn-ai/fastn-claude-plugins`), while this script
# always sits next to the skill it loads.
root="$(cd "$(dirname "$0")/.." && pwd)"
skill="${root}/skills/gateway/SKILL.md"
[ -f "$skill" ] || exit 0

# Strip the leading YAML frontmatter (--- ... ---) and inject the instruction body only.
# A `---` inside the body (markdown rule) is preserved.
body="$(awk 'fence>=2 {print; next} /^---[[:space:]]*$/ {fence++}' "$skill")"
[ -n "$body" ] || body="$(cat "$skill")"  # no frontmatter -> use the whole file

# A short lead line makes the rules unambiguous; the body is the plugin skill verbatim.
context="# fastn gateway - mandatory usage rules (auto-loaded; follow these before using any fastn gateway tool)

${body}"

# JSON-encode the context. Backslash, quote, CR, tab, and newline cover every character
# class SKILL.md contains; backslash must be escaped first.
esc=${context//\\/\\\\}
esc=${esc//\"/\\\"}
esc=${esc//$'\r'/}
esc=${esc//$'\t'/\\t}
esc=${esc//$'\n'/\\n}

printf '{"additionalContext":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc" "$esc"
exit 0
