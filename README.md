# fastn Connect

Test copy of fastn-ai/fastn-claude-plugins PR #11. Install from this repository with `/plugin marketplace add umarfarooqfastn/test-plugin`, then `/plugin install connect@fastn` and `/reload-plugins`. Remove the real `fastn` marketplace first if you added it; both use the same name.

Build and run integrations on the fastn platform, straight from Claude or GitHub Copilot. fastn is the embedded integration layer for SaaS: with the **`connect`** plugin installed, Claude can create connectors, plan syncs, author and test workflows, build embedded widgets, and run your organization's governed, multi-tenant automations - across every app your customers connect. The same integrations power **both your product's own features and the AI agents it runs for customers**, each with governed, audited access.

It does this by connecting Claude to fastn through one **governed MCP gateway** that **dynamically serves fastn's full, growing library of skills**. Installing the plugin does two things:

1. **Registers fastn as an MCP server** - Claude connects directly, and fastn handles authentication, identity, and policy itself. No manual MCP setup.
2. **Loads the usage skill** - persistent instructions that tell Claude how to discover that library (the gateway's `skill` tool), install a skill locally, and keep the local copy in sync with the published version.

The library **loads on demand** - there are many skills, and new capabilities appear automatically as fastn publishes them, with nothing to reinstall. That is what makes a small plugin do a lot.

No local tools, no scripts, no runtime dependency: a manifest, an MCP registration, and a skill. It works in **Claude Code**, in **Claude Cowork** (installed plugins live at the account level and reload every session), and in **GitHub Copilot CLI** (the same manifests, skill, hook, and MCP registration load from the same files - the session-start hook emits a JSON payload both tools understand, so both receive identical context).

## What you get

fastn is the embedded integration layer for SaaS. Through the gateway, and with no further setup after install, the agent can:

- **discover** what fastn can do right now by calling the gateway's `skill` tool with `{}` (the library loads on demand - there are many skills, and new ones appear automatically),
- **install a skill locally** from its signed zip and **keep it current** - every install is stamped with its published version, and the session-start hook reports the installed versions so a stale copy gets refreshed before it runs,
- **build and release integrations**: create connectors, plan syncs, author and test workflows, and build embedded widgets - all through the gateway's skills,
- **run governed, multi-tenant automations** end to end - powering both your product's features and the AI agents it runs for customers, with identity, policy, and redaction applied automatically,
- **give your product's AI agents safe, governed access** to every connected system - every call scoped, audited, and policy-checked at the gateway,
- **call any connected app's tools**, namespaced as `app__action` (for example `slack__send_message`),
- get a connect link when a needed account isn't connected yet, and hand it to the user,
- **plan before you build**: the bundled `fastn-solution-architect` skill turns a use case into a checked fastn solution (which pieces fit, what does not, and the setup steps) and works even before the gateway is connected,
- file corrections back to a skill owner via `feedback`.

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
  hooks/load-gateway-skill.sh         the session-start loader: injects the usage skill plus
                                      an inventory of already-installed fastn skills and their
                                      versions (emits JSON that both Claude Code and Copilot
                                      CLI inject as context)
  skills/gateway/SKILL.md             the fastn usage skill
  commands/plan.md                    the /connect:plan command
  skills/<slug>/                      the published fastn skills, bundled (fastn_onboarding,
                                      integration_builder, connector_builder, unified_api,
                                      workflow_verifier), each SKILL.md + its references/
  skills/fastn-solution-architect/    plans an integration: asks about the use case, maps each need
                                      to the right fastn piece, checks the live workspace when the
                                      gateway is connected, and guides the setup (SKILL.md +
                                      references/: setup, sdk, edge-cases, examples, meeting)
```

Keep `plugin.json` and `plugins/connect/.claude-plugin/plugin.json` in sync (same name, version, and metadata) - they are the same plugin seen through two install entry points.

## Skills in this plugin

| Skill | What it is for |
|---|---|
| `gateway` | The gateway's operating manual: which fastn skill a task needs, how to install it, and how to keep it current. Loaded at session start. It is the published gateway skill, copied as is. |
| `fastn-solution-architect` | Plan an integration before building it. Ask "does fastn fit my use case?" or "which fastn feature should I use for X?". It asks a few questions, says what fits and what does not, and walks through the setup. With the gateway connected it checks the live workspace; without it, it works from its built-in definitions and marks answers "not checked". |

| `fastn_onboarding` | Guides a SaaS team through fastn's 4-step setup. |
| `integration_builder` | Plans, maps, builds, tests and ships integrations: syncs, triggers, webhooks, events and the widget. |
| `connector_builder` | Builds, tests and debugs connectors, actions, auth methods and events. |
| `unified_api` | Sets up and uses the unified API across providers. |
| `workflow_verifier` | Proves a workflow, trigger or widget works end to end, with a report. |

The six fastn skills other than `fastn-solution-architect` are the versions the gateway publishes, copied as is and stamped with their version (`<!-- fastn skill: <slug> v<N> -->`), so they work offline and before sign-in. The gateway stays the source of truth: when it publishes a newer version, the `gateway` skill's version check finds it and installs the newer copy. To refresh the bundled copies, download each skill's zip from the gateway's `skill` tool and unzip it over `plugins/connect/skills/`.

There is also one command: `/connect:plan <use case>` starts the `fastn-solution-architect` skill on a use case.

## Configuration: the gateway endpoint

`plugins/connect/.mcp.json` points at the fastn gateway:

```json
{ "fastn": { "type": "http", "url": "https://mcp.fastn.dev" } }
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

**Other AI tools (Codex, Cursor, GitHub Copilot in the CLI and IDEs, the Claude apps)**

The `fastn-solution-architect` skill is a standard Agent Skills folder, so the same folder works in
these tools too: copy `plugins/connect/skills/fastn-solution-architect/` into the folder your tool reads
(for Codex, Cursor and Copilot CLI that is `~/.agents/skills/`), then add the fastn MCP server.
Step-by-step instructions per tool are in [docs/install-other-agents.md](docs/install-other-agents.md).

## License

MIT - see [LICENSE](LICENSE).
