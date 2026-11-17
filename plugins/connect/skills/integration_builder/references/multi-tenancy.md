# MULTI-TENANCY & CONNECTION HANDLING

> Read this whenever a build touches connections, the connector manifest, installations, configs-as-clones, or "ship this to my customers" / widgets. It governs **whose accounts a flow runs against** and **which connection each connector call resolves to**. The single most important decision it drives: **Path A (single-tenant, the developer's own data) vs Path B (multi-tenant, a product shipped to the partner's customers)** — see THE BUILD FLOW below. Pairs with `references/build.md` (widget step) and `references/sandbox.md` (`fastn.config` runtime contract).

The headline rules, before the detail:
1. **Default to SAAS / Path A — but ALWAYS ask, never assume silently** (a tenant caller — `whoami` → `actingAsTenant: true` — is the sole exception: Path A, not asked)**.** Path A is the recommended *default*, not an automatic one: **always put single- vs multi-tenant to the user as an explicit question — never infer it silently, even when the framing looks obvious** — with your recommendation pre-selected as the default (`references/plan.md` Step 4). Only engage the manifest (`fastnPlatform__setWorkflowConnectorScope`) when the confirmed use case is genuinely "ship to customers." For everyday "sync MY X to MY Y" automations the all-SAAS manifest is already correct — **don't touch it.** (The **widget is built either way** — it is NOT Path-B-only; only the manifest tuning is.)
2. **A connector with >1 connection → ASK which to use** (default or other). Single connection → proceed silently. The platform never asks — it silently uses `is_default` — so the agent must prompt.
3. **Pin a non-default connection via the MANIFEST (`fastnPlatform__setWorkflowConnectorScope`), never hardcoded in code.** Code pins are for throwaway probes only.
4. **Make a flow multi-tenant by flipping per-customer connectors to `MULTI_TENANT`; leave shared systems `SAAS`** (mixed scope is fine and common).
5. **Read config with `getByTemplate`, author templates only** (never clones).
6. **Test a multi-tenant flow with a self-install** (`endOrgId` = your own org) + `fastnPlatform__testSavedWorkflow { id, headers: { "x-installation-id": <installationId> } }`; clean up after.
7. **Installations need an existing tenant — the agent cannot create end_orgs.**

---

## 1. Glossary (the concepts these rules move around)

- **SaaS partner / developer org** — the org using fastn to build integrations. Owns the workflows, configs, widgets. Carried as `org_id`.
- **end_org (tenant / customer)** — a customer of the partner who installs a widget. A child org (`orgs.parent_id` = partner, `type='end_org'`). Carried at runtime as `x-end-org-id`. Distinct from the partner's internal account/tenant RBAC.
- **Installation (`inst_*`)** — the per-customer runtime row: "for THIS customer, run THIS target with THESE connections and THIS config." The thing that makes a per-customer run resolve correctly. (Formerly "tenant binding" — old term, gone.)
- **Connection** — one authenticated account for a connector. Belongs to an org; for customers it's scoped by `end_org_id`. Exactly one is `is_default` per `(connector, end_org, user)` group.
- **Connector manifest** — per-workflow declaration of which connectors/actions it uses and how each resolves (`SAAS` vs `MULTI_TENANT`). Auto-built on save.
- **Config template vs clone** — template = developer's default mapping (`widget_id` set, `end_org_id` null). Clone = per-customer copy (`end_org_id` + `template_config_id` set), created by the embed.
- **Widget (`wgt_*`)** — the shippable unit bundling connectors + workflows + config template + lifecycle hooks + activation mode.

---

## 2. The connector manifest

- **What it is:** a JSON list on each workflow (`workflows.connector_manifest`). One entry per connector the code calls:
  `{ slug, connectorId, scope: "SAAS"|"MULTI_TENANT", connectionId: string|null, actions[], stale? }`
- **How it's created:** automatically on `fastnPlatform__createWorkflow` / `fastnPlatform__updateWorkflow` / `fastnPlatform__editWorkflowCode`. The server regex-scans the code for `fastn.connector.<slug>.<action>(` calls, extracts `{slug, actions}`, and enriches with `scope: "SAAS"` (default) + the pool's default `connectionId`. **The agent never builds it by hand.**
- **What it governs:** at run time the dispatcher reads the manifest to decide which connection each connector call uses.
- **`scope` is the key field:**
  - `SAAS` — the developer's own pooled connection serves every customer (`connectionId` pins which one).
  - `MULTI_TENANT` — each customer uses their own connection, resolved per-customer at run time (`connectionId` is `null`).
- **New connectors default to `SAAS`** — multi-tenant is a deliberate opt-in via `fastnPlatform__setWorkflowConnectorScope`.
- **Editing the manifest is live** — `fastnPlatform__setWorkflowConnectorScope` writes straight to the DB; the next run uses it. No "refresh" needed.
- **`fastnPlatform__refreshWorkflowManifest`** only re-syncs the entry list to the code (adds new connectors, marks removed ones `stale`). Almost never needed, because every save already re-extracts. Reach for it only when code and manifest drift (e.g. code changed outside the normal save path), or when `fastnPlatform__setWorkflowConnectorScope` errors "slug not in manifest."
- **Manifest can hold only ONE `connectionId` per slug** — it can't represent two connections of the same connector (see §4).

---

## 3. Connection resolution — how a connection is chosen at run time

Precedence, **first match wins**:

| # | Condition | Resolves to |
|---|---|---|
| 1 | `{ pinConnectionId }` on the call | that exact connection |
| 2 | `installationId` present (Mode B) | `installation.connections[slug]` |
| 3 | `endOrgId` present, no pin (Mode A) | that customer's `is_default` connection for the connector |
| 4 | manifest `SAAS` | `manifest.connectionId` (pool default/pinned) |
| 5 | nothing (no context, no manifest) | caller org's `is_default` connection (legacy fallback) |

- `is_default` is auto-assigned (first active connection in a group; changeable). Mode A always picks it.
- **`MULTI_TENANT` with no customer context → hard error "must pass x-end-org-id"** (by design — never silently routes to the wrong tenant).
- **`SAAS` connectors bypass the installation's connections map** — they resolve centrally regardless of end-org.

---

## 4. Handling multiple connections of one connector — RULES

- **If a connector has >1 connection, ASK the user which to use** (default or other). Single connection → proceed silently. The platform does not ask — it silently uses `is_default` — so the agent must prompt.
- **Pin the chosen connection on the MANIFEST, not in code** — `fastnPlatform__setWorkflowConnectorScope { scope: "SAAS", connectionId }`. The manifest is changeable without a code edit (same principle as config-over-code). Hardcoding `connectionId` in code works but is opaque and drifts from the manifest.
- **Code-level `connectionId` pins are for throwaway probes / `fastnPlatform__runWorkflowCode` only**, not saved workflows.
- **One connector → multiple connections (e.g. two stores/regions, same logic) can't be expressed in the manifest** (one `connectionId` per slug). Pick by relationship, in this order:
  - **Same logic across N connections → the `MULTI_CONNECTION` installation pattern (default for this case).** Keep ONE tenant-agnostic workflow; flip that connector to `MULTI_TENANT`; create one **installation per connection** with a distinct `slug` and its own `connections` map (`fastnPlatform__createInstallation`), and a widget with `activationMode: "MULTI_CONNECTION"`. The dispatcher resolves the right connection per installation at run time. Scales by **adding installations, not code or workflows** — adding a third store is one more install. (§9, §11.)
  - **Genuinely independent flows → two workflows**, each manifest-pinned to its connection via `fastnPlatform__setWorkflowConnectorScope { scope: "SAAS", connectionId }` (clean when the two never share logic).
  - **Do NOT code-pin `connectionId` in a saved workflow to hit two connections in one run.** A per-call `pinConnectionId` overrides per-customer resolution, and even on a `SAAS` manifest it's opaque and drifts. Code pins are for throwaway `fastnPlatform__runWorkflowCode` probes ONLY (§5). If one run truly must touch two connections, model it as `MULTI_CONNECTION` installs (above), not as code pins.

---

## 5. Per-tool connection behavior

- **`fastnPlatform__runWorkflowCode`** — pre-everything: no workflow, no manifest. A bare call resolves to the caller org's default connection; `MULTI_TENANT` strictness does NOT fire. Override per call with `{ pinConnectionId }`; to run as a tenant or an installation pass `headers: { "x-end-org-id": <endOrgId> }` or `{ "x-installation-id": <installationId> }`. Use for validating actions/mappings.
- **`fastnPlatform__probeConnector` / `fastnPlatform__probeConnectorValues`** — like `fastnPlatform__runWorkflowCode` but generate the code. Accept `connectionId` (pin a specific connection), `endOrgId`, `installationId`.
- **`fastnPlatform__createWorkflow`** — doesn't execute; saves code + auto-extracts the manifest (all `SAAS` by default). No connection used at create time; it sets the policy.
- **`fastnPlatform__testSavedWorkflow`** — uses the manifest (saved workflow). `SAAS` → resolves on its own; `MULTI_TENANT` → must pass `headers` with `x-end-org-id` (Mode A) or `x-installation-id` (Mode B) or it errors. The installation is most faithful (pulls the install's connections map + config clone). `mockMode: true` bypasses connections entirely.
- **`new Fastn({ connectors })` options in sandbox code:** `{ orgId: "managed"|"custom", version }`. Declaring a connector is optional: bare `fastn.connector.X` works for community (owned by the platform's own org) and custom connectors alike. To pin one call to a connection use `{ pinConnectionId }` on the call; to run one connector on two connections, pin each call with its own `pinConnectionId`. Do not choose the connection with a `connectionId` in this config: it is not honoured for a `MULTI_TENANT` connector or over an installation's pin.

---

## 6. THE BUILD FLOW — two paths

**First check who is asking.** If `whoami` returns `actingAsTenant: true`, the caller is a customer working inside a partner's product against their own workspace: it is **Path A, not asked and not discussed** — no manifest talk, no "your customers" framing. The rest of this section applies to a partner's own staff (`actingAsTenant: false`). When that customer wants to change something their provider built, the answer is a fork into their own workspace (`fastnPlatform__forkIntegration`), never an edit of the provider's rows — see STEP 0 in `SKILL.md`.

**For them the agent ALWAYS ASKS — never infers — with a smart recommendation: whose accounts does the flow run against?** Analyze the request, pick the likely path, and put it to the user as an **explicit PLAN business question** (`references/plan.md` Step 4) with your recommendation pre-selected as the default — never decide it silently, even when the framing looks obvious. Default recommendation is **Path A** when there's no "ship to customers / embed / widget" signal; the user still confirms it every time.

### Path A — single-tenant (the developer's own data, internal automation)
*"Sync MY X to MY Y."*
```
probe → fastnPlatform__createWorkflow → fastnPlatform__testSavedWorkflow → bind trigger → fastnPlatform__createWidget
```
- Manifest stays all `SAAS` (= developer's own connections). **The agent ignores the manifest — `fastnPlatform__setWorkflowConnectorScope` is NOT used.** The **widget IS still created** (every build ends with one).
- This is the **default for everyday automations.**

### Path B — multi-tenant (a product shipped to the partner's customers)
*"Let MY CUSTOMERS sync THEIR X to THEIR Y" / "build a widget" / "embed."*
```
probe → fastnPlatform__createWorkflow → fastnPlatform__setWorkflowConnectorScope (MULTI_TENANT) → (self-install test)
      → fastnPlatform__proposeConfiguration → reviewUrl → fastnPlatform__getConfigDraft → configId (= the template)
      → fastnPlatform__createWidget(configId) → publish
```
- **Manifest tuning** (`fastnPlatform__setWorkflowConnectorScope`) is the part that **only happens here** — the widget itself is built in both paths.
- The config is persisted exactly as in Path A — via `fastnPlatform__proposeConfiguration` + browser approval (see `references/mapping.md`). The resulting `configId` **is the template** the embed clones per customer (§10). `fastnPlatform__createConfig` is only the headless direct-save alternative (no review UI) — not part of the normal flow.

> **▎ Rule for the skill:** treat **manifest tuning (`fastnPlatform__setWorkflowConnectorScope`) as Path-B-only** — NOT the widget. Don't touch the manifest for normal automations — all-SAAS is already correct. The widget is the final step of **every** build (`references/build.md` step 8); the only Path-B addition is flipping per-customer connectors to `MULTI_TENANT` before it.

---

## 7. Mixed scope (the common multi-tenant pattern)

Each connector's scope is independent. A typical shape: **shared source = `SAAS`, per-customer target = `MULTI_TENANT`** (e.g. central D365 catalog → each customer's own BigCommerce). One tenant-agnostic workflow; the manifest + installation decide per customer. **The installation's connections map only needs the `MULTI_TENANT` slugs** (SAAS resolves centrally).

---

## 8. Testing a multi-tenant flow (no real customer needed)

A `MULTI_TENANT` flow can't be `fastnPlatform__testSavedWorkflow`'d with no context (errors by design). **Test in layers:**

1. **`fastnPlatform__runWorkflowCode` (+ `connectionId` pin)** → "do the actions/mappings work?" *(no tenant)*
2. **SELF-INSTALL + `fastnPlatform__testSavedWorkflow`** → "does the multi-tenant wiring work?"
3. **`fastnPlatform__testSavedWorkflow` `mockMode`** → "does the logic handle edge cases?" *(no connections)*

**Self-install = the key trick:** `fastnPlatform__createInstallation { endOrgId: <your own org>, connections: { ...your active connections... } }` (allowed in admin/self mode), then `fastnPlatform__testSavedWorkflow { id, headers: { "x-installation-id": <installationId> } }`, then `fastnPlatform__deleteInstallation`. This exercises the real Mode-B path using accounts you already have.

> **▎ Prefer `fastnPlatform__runWorkflowCode` over temporarily flipping the manifest to `SAAS`** — flipping mutates the shipped artifact and tests less.

---

## 9. Installations

- **What `fastnPlatform__createInstallation` does:** writes the per-customer activation row. Required: `targetType` + `targetId` (what it runs), `endOrgId` (which customer), `label`. Optional: `widgetId`, `slug`, `connections`, `configId`, `config`, `status`.
- **It does NOT create the tenant.** It validates `endOrgId` is an existing child org and rejects otherwise. Tenants are created via embed onboarding / org management — **not** workflow-mcp.
- **`widgetId` is optional** — an installation binds to a target, not necessarily a widget. Standalone installs (no widget) are used for testing/explicit provisioning.
- **`connections` is a SLUG-keyed map** `{ connectorSlug: connectionId }` — only `MULTI_TENANT` slugs need entries.
- **`slug`** lets one customer hold multiple installs of the same target (the `MULTI_CONNECTION` case).
- **Two creation paths:** (a) widget publish auto-fan-out (`syncWidgetBindings`) creates one `__default__` install per customer who already has a matching active connection; (b) the embed creates installs when a customer connects/installs (and multiple, with distinct slugs, for `MULTI_CONNECTION`). The manual `fastnPlatform__createInstallation` tool is mainly for testing/provisioning.
- **Read tools:** `fastnPlatform__listInstallations` (filter by widget/endOrg/target) and `fastnPlatform__getInstallation` — also how the agent obtains valid `endOrgId`s.

---

## 10. Configs — template vs clone

- **The agent authors the template only.** The template is the approved config from MAP — persisted via `fastnPlatform__proposeConfiguration → reviewUrl → fastnPlatform__getConfigDraft → configId` (the normal interactive path, see `references/mapping.md`). That `configId` (template = `end_org_id` null) is what the widget binds to. `fastnPlatform__createConfig` is a headless direct-save alternative (takes `{ configuration }` only — no `widgetId`; bind via `fastnPlatform__createWidget(configId)`); reach for it only when you already hold an approved config object and don't need the browser review round-trip.
- **Clones are NOT created by the agent.** The embed's clone-on-configure mints a per-customer clone (`endOrgId` + `templateConfigId`) when a customer first configures, so the template is never edited in place.
- **Workflow code should read config via `fastn.config.getByTemplate(templateId)`** (NOT `.get()`), so it resolves the customer's clone at runtime (installation → its clone; else end-org → its clone; else the template in dev). Single-tenant Path A flows that bind to one developer-owned config can use `.get(configId)`; multi-tenant Path B flows MUST use `getByTemplate` or every customer reads the partner's template instead of their own clone.
- **Read-only clone inspection for debugging:** `fastnPlatform__listConfigs { endOrgId }` / `fastnPlatform__getConfig`.

---

## 11. Widgets (multi-tenant internals)

- **Typed refs (not bare ID arrays):**
  - `connectorRefs [{ connectorId, slug, authMethodId?, deleteOnDeactivate? }]`
  - `workflowRefs [{ workflowId, slug, version }]`
  - `triggerRefs [{ triggerId, type, endUserEditable, editableFields, defaultSettings }]`
- **`connectorRefs.slug` = the keys into each installation's connections map.** Connector scope lives on the workflow **manifest**, NOT on `connectorRefs`.
- **`lifecycleHooks`** — `{ onActivation, onDeactivation, onConfigurationCreated/Change/Delete }`, each → `{ workflowId, version?, enabled }`. Fire on install/uninstall and config changes; can veto or mutate config.
- **`activationMode`** — `SINGLE_ACTIVATION` (one install/customer, what the auto-fan-out creates) vs `MULTI_CONNECTION` (several installs/customer via the embed, distinct slugs).
- **`allowedEndOrgIds`** — `null` = all customers, `[ids]` = restricted, `[]` = hidden.
- **Publishing** (`fastnPlatform__createWidget`/`fastnPlatform__updateWidget` with `workflowRefs`) auto-binds connected customers and returns `sync: { installationsTouched, endOrgsCovered }`.
- **Ownership: `orgId` / `forkedFromWidgetId`.** A tenant sees its provider's widgets beside its own. `orgId` not the caller's org → inherited, read-only; the only way to change it is a fork (`references/forks.md`), which appears as a separate widget with `forkedFromWidgetId` pointing at the original. The tenant's existing installation keeps running the original until they install or switch to the copy.
- **Use `listSaasConnectors` before `fastnPlatform__createWidget`** to find the partner's own product (its registered SaaS connector), not `fastnPlatform__getMyOrgDomain`. Put it on the widget when the flows call it; fastn keeps it off the customer's card. (`references/build.md` step 8.)

---

## 12. Behavior rules to bake in (summary checklist)

1. **Default to SAAS / Path A — always ask, never assume.** Always put single- vs multi-tenant to the user as an explicit question with your recommended path pre-selected as the default (`references/plan.md` Step 4); never infer it silently. Only engage the manifest (`fastnPlatform__setWorkflowConnectorScope`) when the confirmed use case is genuinely "ship to customers." The **widget is built in every case** — it is not Path-B-only.
2. **>1 connection for a connector → ask which to use.** Don't silently take the default.
3. **Pin a non-default connection via the manifest (`fastnPlatform__setWorkflowConnectorScope`), not hardcoded in code.** Code pins are for throwaway probes only.
4. **Make a flow multi-tenant by flipping per-customer connectors to `MULTI_TENANT`;** leave shared systems `SAAS` (mixed scope is fine).
5. **Read config with `getByTemplate`, author templates only** (never clones).
6. **Test multi-tenant flows with a self-install** (`endOrgId` = your org) + `fastnPlatform__testSavedWorkflow { id, headers: { "x-installation-id": <installationId> } }`; clean up after.
7. **Installations need an existing tenant** — the agent can't create end_orgs.
8. **Don't tune the manifest for single-tenant automations** — all-SAAS is already correct.
9. **A tenant never edits its provider's integration — it forks it.** `orgId` not the caller's → `fastnPlatform__forkIntegration`, then change the copy (`references/forks.md`). Never report the 403/404 of an in-place edit as "cannot be done".