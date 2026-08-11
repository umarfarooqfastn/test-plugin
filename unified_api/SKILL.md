---
name: unified_api
description: >-
  Configure and use the fastn Unified API through the fastn Workflow MCP — a platform-global catalog of categories (crm, ecommerce, ...) with canonical entities (contact, customer, order) that execute across whichever providers each org has connected (HubSpot, Dynamics 365, BigCommerce, Cin7, ...). Covers browsing the catalog, curating it as platform_admin (categories, entities, per-connector mappings with operations/fieldMappings/enrichActions/conditions), verifying with test and query tools, the multi-provider fan-out list shape and cursors, calling fastn.unified from workflow code, attaching a unified entity to a widget (unifiedRefs/unifiedEntityIds, auto connector merge), per-provider widget config forms, and the flat config.unifiedValues shape. Use when asked to create a unified API, add a category/entity, map a connector into a unified entity, call the unified API from a workflow or widget, add a config form to a unified widget, or to debug UNIFIED_* errors, wrong fields, or empty unified data.
---

<!-- fastn skill: unified_api v2 -->

> Step 0 - version sync (do this FIRST, every run): this file is tagged `<!-- fastn skill: unified_api v2 -->`. Call `skill {"slugs": ["unified_api"]}` on your fastn gateway and compare. If the published version differs, reinstall from the fresh `downloadUrl` before doing anything else.

# unified-api

## How to run
## What the Unified API is

One canonical surface per business entity — `GET /api/v1/unified/crm/contact` — that works across whichever provider the CALLING org has connected. The catalog is **platform-global**: `platform_admin` curates it once (owned by the `org_platform` sentinel org); every org reads and executes it against their own connections. Two orgs calling the same endpoint get data from their own HubSpot/Cin7 accounts.

```
unified_category  (crm, ecommerce, ...)            ─ platform_admin curates
  └─ unified_entity  (contact, customer, ...)      ─ canonical labeled field schema
       └─ unified_connector_mapping (per provider) ─ action bindings + field maps
                                                     + enrich actions + conditions
Execution: caller's org → ACTIVE connections decide which providers serve the call
```

**Who can do what:** every role reads the catalog and executes (GETs need `unified.read`; create needs `unified.execute`; viewer is read-only). Catalog **writes** require a platform_admin session operating in the Platform account — API-key MCP sessions resolve to developer/admin and will **403 on every save/delete tool**; curate via a platform_admin session or the dashboard at `/admin/unified-catalog`.

---

## MCP tools

| Tool | What it does |
|---|---|
| `list_unified_categories` | Catalog discovery: categories with their entities. Call first. |
| `list_unified_entities` | Entities (admin view, mapping counts); optional `category` filter. |
| `get_unified_entity` | One entity (ue_*) + canonical schema + every connector mapping. |
| `list_unified_providers` | Per entity: mapped providers with the CALLER's connection state. |
| `query_unified` | Runtime list/get through the caller's connections. |
| `create_unified_record` | Runtime create from a canonical body. |
| `save_unified_category` / `save_unified_entity` / `save_unified_mapping` | Catalog curation (platform_admin only). |
| `delete_unified_category` / `delete_unified_entity` / `delete_unified_mapping` | Catalog removal (platform_admin only). |
| `test_unified_entity` | Run the real engine against the caller's own connections with remoteData — verify a mapping before shipping. |

## Curating the catalog (platform_admin)

Order: category → entity → one mapping per connector → test.

1. `save_unified_category { slug: "crm", name: "CRM" }`
2. `save_unified_entity { categoryId, slug: "contact", name: "Contact", schema: { email: { type: "string", label: "Email", required: true }, first_name: { type: "string", label: "First name" } } }` — canonical fields are flat, snake_case, and every field carries a human `label` (the config editor renders them).
3. **PROBE BEFORE MAPPING.** Execute the connector action once (`run_code` / `execute_action`) and read the real output — `recordsPath`, `cursorPath`, `remoteIdPath`, and every `connectorField` dot-path must match reality, not the docs. Real examples:
   - HubSpot `listContacts` → `{ results: [{ id, properties: { email } }], paging: { next: { after } } }` → `recordsPath: "results"`, `cursorPath: "paging.next.after"`, `paramMap: { cursor: "after", pageSize: "limit" }`, fields under `properties.*`.
   - Cin7 Core `listCustomers` → `{ Total, Page, CustomerList: [{ ID, Name, Contacts: [...] }] }` → `recordsPath: "CustomerList"`, `remoteIdPath: "ID"`, `paramMap: { pageSize: "Limit" }`, **no cursorPath** (page-number pagination has no token — nextCursor stays null).
   - BigCommerce `listCustomersV2` → bare array at root → `recordsPath: ""`.
4. `save_unified_mapping`:

```jsonc
{
  "entityId": "ue_...",
  "connectorSlug": "hubspot",
  "operations": {
    "list":   { "actionSlug": "listContacts", "paramMap": { "cursor": "after", "pageSize": "limit" },
                "recordsPath": "results", "cursorPath": "paging.next.after", "remoteIdPath": "id" },
    "get":    { "actionSlug": "getContact", "paramMap": { "id": "contactId" }, "recordsPath": "", "remoteIdPath": "id" },
    "create": { "actionSlug": "createContact", "recordsPath": "", "remoteIdPath": "id",
                "staticInput": { /* fixed required defaults, e.g. Cin7's Status/Currency/TaxRule */ } }
  },
  "fieldMappings": [
    { "connectorField": "properties.email", "connectorLabel": "Email",
      "canonicalField": "email", "canonicalLabel": "Email" },
    { "connectorField": "Contacts.0.Email", "connectorLabel": "Default Contact Email",
      "canonicalField": "email", "canonicalLabel": "Email", "direction": "toCanonical" }
  ],
  "enrichActions": [
    { "id": "enrich_source_fields",  "connector": "hubspot", "action": "listContacts",
      "params": { "limit": 1 }, "labelKey": "label", "valueKey": "name" },
    { "id": "enrich_target_fields",  "connector": "hubspot", "action": "listContacts",
      "params": { "limit": 1 }, "labelKey": "label", "valueKey": "name" },
    { "id": "enrich_source_records", "connector": "hubspot", "action": "listContacts",
      "params": { "limit": 5 }, "labelKey": "label", "valueKey": "name" }
  ],
  "conditions": [ { "field": "archived", "operator": "equals", "value": "false", "label": "Not archived" } ]
}
```

   - `direction: "toCanonical"` = read-only mapping (nested paths like `Contacts.0.Email` read fine but are excluded from create payloads — the engine cannot build arrays).
   - `valueMappings` translate enum values both ways (reversed automatically for create).
   - **enrichActions and conditions are stored metadata, not executed by the runtime** — the config editor uses them for field dropdowns and sample records when the entity is attached to a widget; store all three variants per connector so the entity works as either side of a derived config.
5. `test_unified_entity { entityId, op: "list", provider: "hubspot", params: { pageSize: 2 } }` — returns mapped records with `remoteData`; fix paths until canonical fields are populated. Then `query_unified` as the real caller.

## Calling it (runtime)

REST (API key `Bearer fsk_...`) or the matching `query_unified` / `create_unified_record` tools:

- `GET /api/v1/unified/categories` — discovery.
- `GET /api/v1/unified/:category/:entity/providers` — which providers the caller has connected (drive "Connect X" buttons from this).
- `GET /api/v1/unified/:category/:entity?page_size=50` — **no `provider` + no `cursor` fans out over ALL connected providers in parallel** and returns `{ data: { <slug>: { records, nextCursor, error? } }, providers: [...] }` with per-provider error isolation. With `?provider=` or a `cursor` (cursors are pinned to the provider that minted them): `{ records, nextCursor, provider, warnings? }`.
- `GET .../:id` and `POST ...` (canonical body; unknown fields rejected) resolve exactly one provider — `409 UNIFIED_MULTIPLE_PROVIDERS` means pass `?provider=`.
- Widget configuration values (see "Per-entity configuration forms") merge into the provider action input when the call carries an `x-installation-id` header or an explicit `?widget_id=` param — a bare call gets none.
- Records are always canonical: `{ id, provider, data: { email, ... }, remoteData? }`.
- Errors: `{ error, code }` — `UNIFIED_UNSUPPORTED_ENTITY`/`UNIFIED_NO_CONNECTED_PROVIDER` (404), `UNIFIED_UNSUPPORTED_OPERATION` (404), `UNIFIED_MULTIPLE_PROVIDERS` (409), `UNIFIED_CURSOR_INVALID` (400), `UNIFIED_VALIDATION_FAILED` (400), `UNIFIED_PROVIDER_AUTH_FAILED` (401), `UNIFIED_PROVIDER_RATE_LIMITED` (429), `UNIFIED_PROVIDER_ERROR` (502).

## In workflow code — fastn.unified

**Unified-FIRST rule:** when a unified entity covers the data (check `list_unified_categories`), call `fastn.unified.*` instead of per-provider `fastn.connector.*` — mappings stay editable in the catalog without code changes, and one workflow serves every provider.

```js
export default async function (ctx) {
  // Single provider + cursor pagination
  const page = await fastn.unified.crm.contact.list({ provider: "hubspot", pageSize: 100, cursor: ctx.input.cursor });
  // page = { records: [{ id, provider, data: {...} }], nextCursor, provider, warnings? }

  // Multi-provider fan-out (no provider arg) → slug-keyed map, same as REST
  const byProvider = await fastn.unified.crm.customer.list({ pageSize: 5 });
  // { bigcommerce: { records, nextCursor }, dynamics365Fo: { records, nextCursor, error? }, ... }

  // Get / create (single provider; pass provider when several are connected)
  const one = await fastn.unified.crm.contact.get("93763152725", { provider: "hubspot" });
  const created = await fastn.unified.crm.contact.create({ email: "a@x.com", first_name: "Ada" }, { provider: "hubspot" });
  return { page, byProvider, one, created };
}
```

Failures throw with the `UNIFIED_*` code in the message — branch with `err.message.includes("UNIFIED_MULTIPLE_PROVIDERS")` etc.

Widget configuration values merge into every call's action input when the run is installation-pinned (widget-dispatched runs / `x-installation-id` on the test call — installation overrides win over widget defaults), or pass `{ widgetId: "wgt_..." }` in the call opts to use a widget's template defaults explicitly:

```js
const msgs = await fastn.unified.communication.message.list({ provider: "slack", widgetId: ctx.input.widgetId });
// slack list action ran with the widget's configured channelId merged into its input
```

## In widgets — attach a unified entity

**When a unified entity covers the data, the widget IS the unified entity — not separate app connectors.** If the entity a use case moves is covered by a unified catalog entity across the connectors involved (`list_unified_categories` → `list_unified_entities`, matching the connectors' slugs in the entity's mappings), create the widget as UNIFIED by attaching that entity — do NOT wire the providers as separate `connectorIds`, and NEVER create one widget per provider. The attach auto-merges the mapped connectors into the manifest, so nothing is lost by not listing them. Fall back to a plain APP widget only when no unified entity covers the data.

**One unified entity per widget.** The dashboard's "Add Integrations" → "Unified" tab enforces this (searchable single-select: one category, one entity — picking another replaces the choice; providers are then narrowed per entity and each picked provider gets a Configure button for its config form). The API still accepts arrays for compatibility, but attach exactly one entity per widget: configuration values are stored per provider (see below), so two entities sharing a provider on one widget would collide.

`create_widget` / `update_widget` accept **`unifiedRefs`** (typed: `{ entityId, connectorSlugs?, configForm? }`) or the simple **`unifiedEntityIds`** (ue_* from `list_unified_entities`) — pass one, not both. A widget can be unified-only; attaching a unified entity makes **`widget.type = "UNIFIED"`** (`APP` otherwise — derived server-side on every write, never client-set). Attaching an entity does two things server-side:

1. **Connector merge** — the SELECTED mapped connectors (all enabled mappings when `connectorSlugs` is omitted) join the widget's connector manifest, so the embed connect flow prompts customers to connect them.
2. **Config template snapshot** — the catalog mappings become the widget's config template (one `source: <connector> → target: unified <category>/<entity>` ConfigEntity per provider, with mappings, enrich actions, and conditions in the config editor's shape). Installations clone it per customer through the normal `fork_from_widget_id` machinery; an existing template is never overwritten.

Do NOT also pass `configId` when relying on the snapshot — the snapshot IS the template. **Mappings stay editorial:** per-customer edits to the snapshotted mappings do not change unified runtime behavior — `/api/v1/unified/*` and `fastn.unified.*` always execute the platform catalog mappings. Configuration VALUES are the exception (next section): they DO feed runtime execution.

## Per-entity configuration forms (configForm)

A widget owner can define a configuration form per attached entity, per provider — e.g. a Slack `channelId` the list-messages action needs:

```jsonc
// unifiedRefs element in create_widget / update_widget
{
  "entityId": "ue_...",
  "connectorSlugs": ["slack"],
  "configForm": {
    "slack": [                                    // keys must be within connectorSlugs
      { "key": "channelId", "label": "Channel", "type": "select", "required": true,
        "optionsCode": "const r = await fastn.connector.slack.listConversationsList({});\nreturn (r.output.channels ?? []).map(c => ({ value: c.id, label: c.name }));" },
      { "key": "prefix", "label": "Message prefix", "type": "text" }
    ]
  }
}
```

- `key` is the connector **action input field** the value feeds at runtime (`^[a-zA-Z][a-zA-Z0-9_.]*$`, max 64). `type`: `text | select | multiSelect`; select types REQUIRE `optionsCode`.
- `optionsCode` is workflow-sandbox JS — plain statements ending in `return [...]` (no `export default` wrapper), full `fastn.*` access, executed against the CALLER's connections, must return `[{ value, label }]` (max 500). Sibling field values arrive as `ctx.input` for cascading selects. **Verify a snippet before saving it:** `POST /api/v1/unified-config/options-preview { code, params? }` (developer/admin/owner/platform_admin only) → `{ data: { options, durationMs } }`, 502 `UNIFIED_OPTIONS_FAILED` on error.
- On `update_widget`, a ref with `configForm` omitted PRESERVES the stored form; `configForm: {}` clears it. A form keyed to a provider outside the selection is a 400.
- Rendering a form loads options via `POST /api/v1/widgets/:id/unified-config/options { entityId, connectorSlug, fieldKey, params? }` — executes the snippet STORED on the widget (end_user-safe: clients can never send code; end_user callers also cannot override `endOrgId`/`installationId`). 400 `UNIFIED_CONFIG_UNKNOWN_FIELD` for a missing/text field.

### Values and where they live

`config.unifiedValues = { [connectorSlug]: { [fieldKey]: value } }` (string, or string[] for multiSelect) — keyed by provider directly, no entity level, because a widget carries a single unified entity. Configs saved before this flattening nested the map under the entity id (`{ [entityId]: { [connectorSlug]: ... } }`); the runtime still reads that legacy shape (the entity's own nested block wins per slug) and the dashboard/embed editors unwrap it on load and re-save flat. Write the flat shape everywhere:

- **Partner defaults** — on the widget's template config row; edited in the dashboard's Integration Configuration modal (UNIFIED widgets render ONLY this form — no mapping tabs) or via `PUT /api/v1/configs/:id`.
- **Per-customer overrides** — the installation's inline config; end users write through `PUT /api/v1/installations/:id/unified-values { unifiedValues }` (end_user-callable, deep-merged, preserves other inline keys). The embed renders the form and chains it after connect when required fields are unset.

### Runtime merge

At execution the resolved values for the provider are merged into the connector action input OVER the mapping's `staticInput` (paramMap cursor/pageSize/id keys still win). Resolution needs a widget identity:

- Installation pin — `x-installation-id` header on `/api/v1/unified/*`, or the run's tenant context in `fastn.unified` → installation overrides win per field over the widget defaults.
- Explicit widget — `?widget_id=` query param, or `opts.widgetId` in `fastn.unified` calls → template defaults only.
- Neither → NO values (deliberate: several widgets can attach the same entity). Resolution failures degrade to no values; they never break the call.

## Debugging

| Symptom | Check |
|---|---|
| Empty `records` but provider has data | `recordsPath` wrong — `test_unified_entity` with `includeRemoteData`/remoteData and re-probe the raw action output. |
| Canonical fields null | `connectorField` dot-paths don't match the raw record (case matters: Cin7 uses `Name`, HubSpot nests under `properties`). |
| `nextCursor` always null | Provider has no cursor token (page-number APIs like Cin7) — expected; or `cursorPath` wrong. |
| 409 `UNIFIED_MULTIPLE_PROVIDERS` | Several providers connected — pass `provider` (list fan-out never 409s). |
| 404 `UNIFIED_NO_CONNECTED_PROVIDER` | No ACTIVE connection for any mapped connector in the caller's org — `list_unified_providers` shows which; connect via the normal flows. |
| 403 on save/delete tools | Session isn't platform_admin in the Platform account — expected for API keys; use the admin UI. |
| Create 400 `UNIFIED_VALIDATION_FAILED` | Body has unknown/mistyped canonical fields, or required fields missing. |
| 502 `UNIFIED_OPTIONS_FAILED` | The options snippet threw, timed out (30s), or didn't return an array — reproduce with `POST /api/v1/unified-config/options-preview` and read the error. |
| 400 `UNIFIED_CONFIG_UNKNOWN_FIELD` | No select/multiSelect field with that key on that entity+provider in `widget.unified_refs[].configForm` — `get_widget` shows what's stored. |
| Configured value not reaching the provider call | The unified call carries no widget identity — pin an installation (`x-installation-id` / widget-dispatched run) or pass `?widget_id=` / `opts.widgetId`. Also confirm the field `key` matches the action's input field name and the value is saved under `config.unifiedValues[slug]` (flat, provider-keyed — the old `[entityId][slug]` nesting is legacy-read only). |
| Widget shows mapping tabs instead of the config form | `widget.type` is APP — it has no unified refs; attach entities via `unifiedRefs` (type becomes UNIFIED automatically). |