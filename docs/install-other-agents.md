# Using the fastn-solution-architect skill in other AI tools

The skill is one folder: `plugins/connect/skills/fastn-solution-architect/` (`SKILL.md` plus `references/`).
It follows the open Agent Skills format (a folder with a `SKILL.md` that has `name` and `description`),
so every tool below reads the same folder. Nothing is copied or rewritten per tool: you put the
folder where the tool looks for skills, and add the fastn MCP server so the skill can check your
live workspace.

The skill works without the MCP server too. It then answers from its built-in definitions and
marks live facts "not checked".

## 1. Get the folder

```
git clone https://github.com/fastn-ai/fastn-claude-plugins.git
cd fastn-claude-plugins
SKILL=plugins/connect/skills/fastn-solution-architect
```

## 2. Put it where your tool looks

Codex, Cursor and Copilot CLI all read the shared `.agents/skills/` folder, so one copy there covers all three:

```
mkdir -p ~/.agents/skills
cp -R "$SKILL" ~/.agents/skills/
```

For one project only, use `<project>/.agents/skills/` instead of `~/.agents/skills/`.

| Tool | Skill folder it reads (personal / project) | Source |
|---|---|---|
| Claude Code | `~/.claude/skills/` / `.claude/skills/`, or install the `connect` plugin (see the README) | [Claude Code skills](https://code.claude.com/docs/en/skills) |
| Claude apps (claude.ai, Desktop) | Upload a ZIP of the folder: **Customize > Skills > + > Create skill > Upload a skill**. Code execution ("Create and edit files") must be on. | [Using skills in Claude](https://support.claude.com/en/articles/12512180-using-skills-in-claude) |
| OpenAI Codex (CLI, IDE extension, app) | `~/.agents/skills/` / `.agents/skills/` | [Codex skills](https://learn.chatgpt.com/docs/build-skills) |
| Cursor (editor and CLI agent) | `~/.agents/skills/` or `~/.cursor/skills/` / `.agents/skills/` or `.cursor/skills/` (it also reads `.claude/skills/`) | [Cursor skills](https://cursor.com/docs/skills) |
| GitHub Copilot CLI | `~/.copilot/skills/` or `~/.agents/skills/` / `.github/skills/`, `.claude/skills/` or `.agents/skills/`. Or `copilot skill add <folder>`. | [Copilot CLI: add skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills) |
| GitHub Copilot agent mode in VS Code, Visual Studio, JetBrains | VS Code: `~/.copilot/skills/` / `.github/skills/`. Support depends on the IDE version. | [About agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills), [VS Code agent skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills) |

For Claude Code, copy to `~/.claude/skills/` instead (`cp -R "$SKILL" ~/.claude/skills/`).
For Copilot in VS Code, copy to `~/.copilot/skills/`.
For the Claude apps, make the ZIP with the folder at its top level (`zip -r fastn-solution-architect.zip fastn-solution-architect` from `plugins/connect/skills/`).

## 3. Add the fastn MCP server

The skill asks you to add `https://mcp.fastn.dev/fastn-workspace` and sign in (OAuth, no API key;
the Developer role or above).

**Claude Code**: `claude mcp add --transport http fastn https://mcp.fastn.dev/fastn-workspace`, then
`/mcp` to sign in. The `connect` plugin registers the gateway for you.

**Claude apps**: **Customize > Connectors > + Add > Add custom connector** (Team and Enterprise: an
Owner adds it under **Organization settings > Connectors**), with the URL above.
[Custom connectors](https://support.claude.com/en/articles/11175166-getting-started-with-custom-connectors-using-remote-mcp)

**Codex**:

```
codex mcp add fastn --url https://mcp.fastn.dev/fastn-workspace
codex mcp login fastn
```

or in `~/.codex/config.toml`:

```toml
[mcp_servers.fastn]
url = "https://mcp.fastn.dev/fastn-workspace"
```

[Codex MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)

**Cursor**: `~/.cursor/mcp.json` (or `.cursor/mcp.json` in a project). Cursor runs the OAuth sign-in.

```json
{ "mcpServers": { "fastn": { "url": "https://mcp.fastn.dev/fastn-workspace" } } }
```

[Cursor MCP](https://cursor.com/docs/context/mcp)

**Copilot CLI**: `copilot mcp add --transport http fastn https://mcp.fastn.dev/fastn-workspace`, or
`/mcp add` inside a session, or `~/.copilot/mcp-config.json`:

```json
{ "mcpServers": { "fastn": { "type": "http", "url": "https://mcp.fastn.dev/fastn-workspace", "tools": ["*"] } } }
```

Your organization's Copilot policy must allow third-party MCP servers.
[Copilot CLI MCP](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)

**Copilot in VS Code**: **Chat: Open Customizations > MCP Servers > Add Server > HTTP**, with the URL above, or
`.vscode/mcp.json`:

```json
{ "servers": { "fastn": { "type": "http", "url": "https://mcp.fastn.dev/fastn-workspace" } } }
```

[VS Code MCP configuration](https://code.visualstudio.com/docs/agents/reference/mcp-configuration)

## 4. Try it

Ask: "We have a platform that gets news based on keywords and sends email to users. I want to use
fastn to send those notifications to Salesforce, Zoho, HubSpot, Asana. How can I set it up?"

The skill should load, open with a one-line yes, show **How it would work**, and ask its questions
with choices. If it does not load, check that the folder name is exactly `fastn-solution-architect`
(several tools require the folder name to match the skill's `name`), then restart the tool.

## Keeping it current

The folder in this repository is the only copy. To update, `git pull` and copy the folder again.
