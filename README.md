# fastn Connect

Build and run integrations on the fastn platform, straight from Claude or GitHub Copilot. fastn is the embedded integration layer for SaaS: with the **`connect`** plugin installed, Claude can create connectors, plan syncs, author and test workflows, build embedded widgets, and run your organization's governed, multi-tenant automations - across every app your customers connect. The same integrations power **both your product's own features and the AI agents it runs for customers**, each with governed, audited access.

It does this by connecting Claude to fastn through one **governed MCP gateway** that **dynamically serves fastn's full, growing library of skills**. Installing the plugin does two things:

1. **Registers fastn as an MCP server** - Claude connects directly, and fastn handles authentication, identity, and policy itself. No manual MCP setup.
2. **Loads the usage skill** - persistent instructions that tell Claude how to discover (`list_skills`) and use that library.

The library **loads on demand** - there are many skills, and new capabilities appear automatically as fastn publishes them, with nothing to reinstall. That is what makes a small plugin do a lot.

No local tools, no scripts, no runtime dependency: a manifest, an MCP registration, and a skill. It works in **Claude Code**, in **Claude Cowork** (installed plugins live at the account level and reload every session), and in **GitHub Copilot CLI** (the same manifests, skill, hook, and MCP registration load from the same files - the session-start hook emits a JSON payload both tools understand, so both receive identical context).

## What you get

fastn is the embedded integration layer for SaaS. Through the gateway, and with no further setup after install, the agent can:

- **discover** what fastn can do right now via `list_skills` (the library loads on demand from the gateway - there are many skills, and new ones appear automatically),
- **build and release integrations**: create connectors, plan syncs, author and test workflows, and build embedded widgets - all through the gateway's skills,
- **run governed, multi-tenant automations** end to end - powering both your product's features and the AI agents it runs for customers, with identity, policy, and redaction applied automatically,
- **give your product's AI agents safe, governed access** to every connected system - every call scoped, audited, and policy-checked at the gateway,
- **call any connected app's tools**, namespaced as `app__action` (for example `slack__send_message`),
- get a connect link when a needed account isn't connected yet, and hand it to the user,
- file corrections back to a skill owner via `capture_feedback`.

Because the plugin installs at the account/app level, the gateway connection and its usage skill are **reused across every session** - which is why this is a plugin, not a one-off skill upload.

## Layout

```
.claude-plugin/marketplace.json       the marketplace manifest (lists the plugin; read by
                                      Claude Code and Copilot CLI)
plugin.json                           root plugin manifest so `copilot plugin install
                                      fastn-ai/fastn-claude-plugins` works without the
                                      marketplace step; points at the files below
hooks/hooks.json                      hook wiring for the root manifest (repo-root layout)
plugins/connect/
  .claude-plugin/plugin.json          the plugin manifest
  .mcp.json                           registers the fastn gateway MCP server
  hooks/hooks.json                    loads the usage skill at session start
  hooks/load-gateway-skill.sh         the session-start loader (emits JSON that both
                                      Claude Code and Copilot CLI inject as context)
  skills/gateway/SKILL.md             the fastn usage skill
```

Keep `plugin.json` and `plugins/connect/.claude-plugin/plugin.json` in sync (same name, version, and metadata) - they are the same plugin seen through two install entry points.

## Configuration: the gateway endpoint

`plugins/connect/.mcp.json` points at the fastn gateway:

```json
{ "fastn": { "type": "http", "url": "https://connect.fastn.dev/mcp" } }
```

Set `url` to the endpoint your organization should hit (your org's gateway, or the default production endpoint) before distributing. This is the only configuration.

## Install

**Claude Code**

```
/plugin marketplace add fastn-ai/fastn-claude-plugins   # or a local path to this folder
/plugin install connect@fastn
/reload-plugins                                         # skill + MCP register at session start
/mcp                                                    # confirm the fastn gateway is connected
```

**Claude Cowork (Claude Desktop)**

Open the **Cowork** tab -> **Customize** -> add this marketplace (from GitHub) or **upload the plugin**, then install `connect`. Restart the session so it loads. fastn then appears in the connector list, and the usage skill auto-triggers on integration, connector, and automation tasks.

**GitHub Copilot CLI**

```
copilot plugin marketplace add fastn-ai/fastn-claude-plugins
copilot plugin install connect@fastn
```

Then start `copilot` and run `/mcp auth fastn` to authenticate the fastn gateway (it uses OAuth; the skill and session-start rules load immediately, the gateway tools appear after auth).

Installing straight from the repository also works, because the repo root carries a `plugin.json` pointing at the same plugin files - but Copilot marks direct installs as deprecated, so prefer the marketplace flow above:

```
copilot plugin install fastn-ai/fastn-claude-plugins
```

## License

MIT - see [LICENSE](LICENSE).
