# Installing the fastn Connect plugin on GitHub Copilot CLI

The fastn Connect plugin connects Copilot CLI to the fastn gateway: one governed
MCP endpoint that serves fastn's library of integration skills and every app your
organization has connected.

## Prerequisites

- GitHub Copilot CLI v1.0.70 or later (`copilot --version`; update with `copilot update`)
- A fastn account for the gateway OAuth step

## Install (recommended: marketplace flow)

```
copilot plugin marketplace add fastn-ai/fastn-claude-plugins
copilot plugin install connect@fastn
```

Expected output:

```
Marketplace "fastn" added successfully.
Plugin "connect" installed successfully. Installed 1 skill.
```

### Alternative: direct install

```
copilot plugin install fastn-ai/fastn-claude-plugins
```

Both flows install the same plugin: the gateway skill, a session-start hook that
loads the fastn usage rules into every session, and the fastn gateway MCP server.

## Authenticate the gateway

Start a session and run the OAuth flow once:

```
copilot
```

Then inside the session:

```
/mcp auth fastn
```

A browser window opens to sign in to fastn. After it completes, the gateway
tools are available in the session.

## Verify

Inside a Copilot session:

- `/mcp` should list the `fastn` server under Plugins, pointing at `https://mcp.fastn.dev`
- Ask: `do you see the fastn gateway mandatory usage rules?` and the agent should confirm and quote them
- `/skills info gateway` shows the bundled gateway skill
- Ask: `list the fastn skills` — the agent should call the `fastn-skill` tool with `{}` and return the published slugs and versions

## Skills served by the gateway

The bundled `gateway` skill is only the entry point. The integration skills
themselves (connector builder, integration builder, and whatever else your
organization has published) are served dynamically by the gateway and installed
on demand.

Discovery and install run through a single MCP tool literally named `skill`
(`fastn-skill` in Copilot CLI). The agent calls `skill {}` to list what is
published, then downloads the skill's signed zip and unzips it into
`.claude/skills/<slug>/` — the one directory both Copilot CLI and Claude Code
discover. Run `/skills reload` afterwards, then `/skills info <slug>`.

Each installed skill is stamped with `<!-- fastn skill: <slug> v<N> -->`. The
session-start hook scans the skills directories for those tags and reports the
installed versions into every session, so the agent can compare them against the
published versions with one `skill {"slugs": [...]}` call and reinstall anything
stale before it runs.

## Update

```
copilot plugin update connect
```

## Uninstall

```
copilot plugin uninstall connect
copilot plugin marketplace remove fastn
```

## Troubleshooting

- `No plugin.json found in repository`: your Copilot CLI is outdated or the
  marketplace was not added first. Run `copilot update`, then use the
  marketplace flow above.
- MCP tools missing in a session: run `/mcp` and check the `fastn` server
  status; re-run `/mcp auth fastn` if it shows "needs authentication".
- Skills the agent installs from the gateway land in `.claude/skills/<name>/`
  (project) or `~/.copilot/skills/<name>/` (personal). Run `/skills reload`
  then `/skills info <name>` if one does not appear.
