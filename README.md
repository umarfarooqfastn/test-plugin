# fastn agent skills

The fastn skill library, mirrored as plain files so any agent can install it in one step — no plugin system, no marketplace, no copy-pasting a skill body word by word.

Every skill is a folder at the repo root containing a `SKILL.md` (plus `references/` where it has them). That is exactly the shape Claude Code, Codex, Cursor, Windsurf, Gemini CLI, and Copilot already scan, so installing is: download the folder, drop it in the skills directory.

## The skills

| Skill | v | What it's for |
|---|---|---|
| [`gateway`](gateway/) | 9 | Operating manual for the fastn gateway. Clears its required first read, routes you to the right skill, keeps installed copies in sync. **Start here.** |
| [`integration_builder`](integration_builder/) | 16 | Plan → map → build → verify fastn integrations and workflows. Syncs, migrations, app-event automations, schedules, webhooks, widgets. Ships 8 reference docs. |
| [`connector_builder`](connector_builder/) | 1 | Build and debug fastn connectors: REST/GraphQL/MCP/FTP/DB/gRPC/Lambda, every auth strategy, action contracts, webhooks. |
| [`unified_api`](unified_api/) | 2 | Configure and call the fastn Unified API — canonical entities that execute across whichever providers an org has connected. |
| [`workflow_verifier`](workflow_verifier/) | 2 | Verify a workflow, trigger, or widget end to end with runtime evidence, and produce a verification report. |

Machine-readable index with direct URLs: [`skills.json`](skills.json).

## Install from chat

Paste this into Claude, Claude Code, Codex, Cursor, or any agent that can run a shell or fetch a URL:

```
Install the fastn skills from https://github.com/umarfarooqfastn/test-plugin
Read https://raw.githubusercontent.com/umarfarooqfastn/test-plugin/main/skills.json,
then download each skill's zip and unzip it into my agent's skills directory.
```

For an agent with no shell, point it at the raw files directly — it can fetch and write them itself:

```
Fetch https://raw.githubusercontent.com/umarfarooqfastn/test-plugin/main/integration_builder/SKILL.md
and save it to .claude/skills/integration_builder/SKILL.md, then do the same for each file
listed under "references" for that skill in skills.json.
```

## Install from the terminal

```bash
# everything, into the directory your agent scans (auto-detected)
curl -fsSL https://raw.githubusercontent.com/umarfarooqfastn/test-plugin/main/install.sh | bash

# just the ones you want
curl -fsSL https://raw.githubusercontent.com/umarfarooqfastn/test-plugin/main/install.sh | bash -s -- gateway integration_builder

# pick the agent and the scope explicitly
curl -fsSL https://raw.githubusercontent.com/umarfarooqfastn/test-plugin/main/install.sh | bash -s -- --agent codex --global all
```

`--agent` accepts `claude-code`, `codex`, `cursor`, `windsurf`, `gemini`, `copilot`, `claude-ai`, or `auto`.
`--global` installs under `~` instead of the current project. `--dir <path>` overrides both. `--help` for the rest.

## Install by hand

Grab a bundle and unzip it into the right directory:

```bash
S=.claude/skills            # see the table below for your agent
mkdir -p "$S"
curl -fsSL https://raw.githubusercontent.com/umarfarooqfastn/test-plugin/main/dist/integration_builder.zip -o /tmp/s.zip
unzip -oq /tmp/s.zip -d "$S"
ls -R "$S/integration_builder"     # must show SKILL.md and references/
```

| Agent | Project directory | Personal directory |
|---|---|---|
| Claude Code | `.claude/skills/` | `~/.claude/skills/` |
| Codex (CLI and desktop) | `.agents/skills/` | `~/.agents/skills/` |
| Cursor | `.agents/skills/` or `.cursor/skills/` | `~/.agents/skills/` |
| Windsurf | `.agents/skills/` or `.windsurf/skills/` | `~/.agents/skills/` |
| Gemini CLI | `.agents/skills/` or `.gemini/skills/` | `~/.agents/skills/` |
| GitHub Copilot | `.agents/skills/` or `.github/skills/` | `~/.copilot/skills/` |
| Anything else | `.agents/skills/` | `~/.agents/skills/` |

`.agents/skills/` is the cross-agent standard and works nearly everywhere — pick it unless your repo already uses a native path. Never unzip with `-j`: it flattens the folder and silently drops every reference file.

Copilot CLI and Gemini CLI need `/skills reload` afterwards. If you created the skills directory just now, restart your agent so it starts watching it.

## Claude.ai, Claude Desktop, Claude Cowork

These store skills in your account rather than on disk, so there is no directory to unzip into. Download the ready-made bundle and upload it:

| Skill | Bundle |
|---|---|
| gateway | [`dist/gateway.skill`](dist/gateway.skill) |
| integration_builder | [`dist/integration_builder.skill`](dist/integration_builder.skill) |
| connector_builder | [`dist/connector_builder.skill`](dist/connector_builder.skill) |
| unified_api | [`dist/unified_api.skill`](dist/unified_api.skill) |
| workflow_verifier | [`dist/workflow_verifier.skill`](dist/workflow_verifier.skill) |

Upload at **Customize → Skills → Add**. Code Execution must be on under **Settings → Capabilities**. Uploading a skill whose name already exists prompts you to replace it — that is also the update path.

## Staying current

These are mirrors. The fastn gateway is the source of truth, and each `SKILL.md` carries a version tag right under its frontmatter:

```
<!-- fastn skill: integration_builder v16 -->
```

To check whether your copy is stale, ask your fastn gateway MCP:

```
skill {"slugs": ["gateway", "integration_builder", "connector_builder", "unified_api", "workflow_verifier"]}
```

Any version difference means reinstall, even when the body looks identical — a reference file may have changed. Re-run the installer to overwrite in place.

## What's in here

```
gateway/SKILL.md
integration_builder/SKILL.md + references/{plan,mapping,build,test-cases,sandbox,workflow-patterns,multi-tenancy,dynamic-config}.md
connector_builder/SKILL.md
unified_api/SKILL.md
workflow_verifier/SKILL.md + references/verify-matrix.md
dist/*.zip     same folders, zipped, for scripted installs
dist/*.skill   same bundles, for claude.ai / Desktop / Cowork upload
skills.json    machine-readable index with direct URLs
install.sh     one-line installer
```

Markdown only. Nothing here executes on install.

Source: the fastn gateway MCP at `connect.fastn.dev`. Bodies are mirrored verbatim; the only addition is the version tag under each frontmatter.
