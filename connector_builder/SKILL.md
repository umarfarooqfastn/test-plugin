---
name: connector_builder
description: >-
  Production knowledge base for building and debugging fastn connectors through the fastn Connector MCP. Covers REST, GraphQL, MCP-protocol, FTP/FTPS/SFTP, DB, gRPC, and AWS Lambda connectors; every auth strategy (OAuth2/OAuth1, API key, Basic/Digest, Bearer, JWT, AWS SigV4, INPUT, NO_AUTH); action input/output contracts and bodyTemplate rules; webhook configs and subscription code; plus platform bugs and provider-specific quirks from 20+ production connectors. Use whenever creating, editing, testing, or debugging a fastn connector, auth method, action, or webhook — e.g. "build a Stripe/Salesforce/HubSpot connector", "add an action to a connector", "wire up OAuth/API-key/AWS auth", "register a webhook", "the webhook won't subscribe", or "fix the inputContract/outputContract".
---

<!-- fastn skill: connector_builder v1 -->

> Step 0 - version sync (do this FIRST, every run): this file is tagged `<!-- fastn skill: connector_builder v1 -->`. Call `skill {"slugs": ["connector_builder"]}` on your fastn gateway and compare. If the published version differs, reinstall from the fresh `downloadUrl` before doing anything else.

# connector-builder

## About fastn (product context)

fastn is the **embedded integration layer for SaaS - the "Zapier for SaaS."** A SaaS company embeds fastn once, and its own customers configure their integrations with no engineering and no per-account code. fastn automatically handles auth, data mapping, business logic, retries, idempotency, batching, throttling, rate limits, and observability. For SaaS agents, an MCP gateway gives the same unified, governed, audited tool access inside customers' systems of record (Salesforce, NetSuite, ServiceNow). Vision: become the default embedded integration platform for SaaS.

The platform surface these skills cover:
- **Connectors** across REST, GraphQL, MCP-protocol, FTP/FTPS/SFTP, DB, gRPC, and AWS Lambda, with OAuth2/OAuth1, API key, Basic/Digest, Bearer, JWT, AWS SigV4, INPUT, and NO_AUTH auth.
- **Triggers**: inbound webhooks, app-native connector events, and schedulers (cron + rate).
- **Workflows**: sandboxed JS (instant/standard/long tiers) against live connectors, with state, DB, files, and fetch.
- **Integrations/sync**: one-way and bidirectional sync with field mapping, type transforms, and external-ID mapping.

The fastn build pair: use **integration-builder** to plan an integration and build the running workflows, and **connector-builder** (this skill) to build or debug a connector. This skill is the connector layer. When integration-builder hits a missing connector, action, event, or connection mid-flow, this skill fills the gap — build and verify the missing piece (or establish the connection), then return to the integration flow where it left off.

---

You are an expert fastn connector builder. This skill encodes every platform rule, gotcha, and pattern discovered across 20+ production connectors. Apply this knowledge proactively — do not learn these lessons again the hard way.

---

## 1. Action Input Contract Rules

### GET actions
- Query params belong in `inputContract` only. fastn auto-appends all inputContract fields as query params on GET.
- Do NOT also set them in `httpConfig.queryParams` — optional empty ones will break the request.
- get-by-id: many APIs use a query param (`?ID=`, `?id=`), not a path segment. Check the spec.

### `inputContract.required` drives cascading dependency auto-detection
For list actions that depend on a parent resource (e.g. `listRepos` requires `org`, `listBranches` requires `owner` + `repo`), the `inputContract.required` array **must accurately declare every required parameter**. The probe pipeline's `detectFieldLookups()` inspects each lookup action's `inputContract.required` — if a required param name-matches another probed field, it stamps `optionsLookupParams` on the `ProbeField`. This flows through `propose_configuration` as `sourceFieldLookupParams` / `targetFieldLookupParams` in the enrichment output, and becomes `paramDeps` on the final config's `EnrichSpec` when the user accepts the proposal. Inaccurate `required` arrays → broken cascading dropdowns in the dashboard UI.

### Auto-pagination is the dashboard default
The dashboard's `useEnrichOptions` hook auto-paginates all enrich dropdown calls by default: it sends `per_page=100` and fetches successive pages (page=1,2,3...) until a page returns fewer than 100 items, capped at 20 pages (2000 items max). This means list actions like `listOrgRepos` on an org with 1000+ repos will load ALL repos without special handling. Connector list actions do NOT need pagination-specific logic for dashboard dropdowns — just return the standard page of results and the dashboard handles the rest. To opt out, set `autoPaginate: false` on the `EnrichSpec` (rarely needed).

### POST / PUT / PATCH write actions
- Always use `bodyType: "json"` with a **field-by-field** `bodyTemplate` JSON literal.
- One typed/titled/described inputContract property per field. Use `enum` where the API documents allowed values.
- Quote strings and dates: `"name":"{{input.name}}"`. Leave numbers, booleans, arrays, objects **bare**: `"count":{{input.count}}`, `"lines":{{input.lines}}`.
- All templated fields **must be `required`** — an unfilled `{{input.x}}` placeholder renders as empty → invalid JSON (`"field": ,`).
- **NEVER** ship a single opaque `body` string input with `bodyType:raw` + `{{input.body}}`. This is an anti-pattern: the programmatic `fastn.connector.<slug>.<action>()` resolver can't pass it and it is not descriptive.

### DELETE / POST / PUT query params
- These methods do NOT auto-append query params. Set explicit `httpConfig.queryParams` when needed.

### Optional fields
- Only put required+always-sent fields inline in bodyTemplate. Document optional extras but don't template them — empty optional placeholders → invalid JSON.

---

## 2. bodyTemplate Special Cases

### Raw JSON array body
When an endpoint requires a raw JSON array (not an object), the embedded-var trick fails — a bare `{{input.items}}` at root unwraps single elements.
**Fix:** accept the array as a `type: string` input, set `bodyType: "raw"`, `bodyTemplate: "{{input.items}}"`, and have the caller pass e.g. `["id1","id2"]` as a string. It emits verbatim.

### Body is a raw JSON object (passthrough)
Don't pass a whole-object var at root. Build field-by-field.

### NO-bodyTemplate auto-body (for SQL, source code, HTML with newlines/quotes)
A `"{{input.query}}"` bodyTemplate substitutes literally — raw newlines → `400 Bad control character in string literal`.
**Fix:** set `bodyType: "json"` and **omit bodyTemplate entirely**. fastn JSON-serializes the inputContract as the body with proper escaping, and excludes any fields already used in the URL template (`{{input.projectRef}}`).
To remove an existing bodyTemplate via `update_action`, you must pass `bodyTemplate: null` explicitly — omitted keys inside `httpConfig` are preserved.

### No-arg RPC endpoints (Dropbox-style)
fastn sends no body if nothing is provided and its relay errors. **Fix:** set `bodyType: "raw"` + `body: "null"`.

### GraphQL
- Each action = single POST to the GraphQL endpoint. `bodyType: "json"`.
- Declare GraphQL vars in the query (`query($id:String!){...$id...}`) and reference them in a `variables` object.
- Only reference **required** fields in the bodyTemplate so JSON is always valid.
- String placeholders quoted (`"id":"{{input.id}}"`); numbers/booleans/arrays bare.
- Watch GraphQL scalar types from introspection (e.g. `Float` vs `Int`, enum vs String).
- Probe via `probe_endpoint` with a small introspection chunk first (responses truncate at ~4000 chars).

---

## 3. Auth Rules

### Credential auto-injection is field-name based (not auth-type based)
- Field literally named **`username`** + **`password`** → fastn auto-injects `Authorization: Basic` — works even on INPUT auth type.
- Field literally named **`token`** → fastn auto-injects `Authorization: Bearer {token}` — **OVERRIDES per-action Authorization headers**.
- **Critical:** NEVER name a credential field `token` if actions also set their own `Authorization` header — the auto-inject clobbers them → 401. Rename to `apiKey`, `accessToken`, etc.

### Multi-field credential forms → INPUT type
- `API_KEY` auth type renders only a fixed single "API key" field in the fastn UI and silently drops extra inputContract fields.
- `BASIC` auth type renders only username/password — drops `instance`, `subdomain`, `storeHash`, etc.
- Any connector needing extra credential fields (instance URL, account ID, store hash) **must use INPUT type**. Basic/Bearer auto-injection still fires from field names.

### `{{auth.token}}` vs `{{auth.accessToken}}` in URLs
- In httpConfig **headers**: `{{auth.token}}` works fine.
- In httpConfig **url / path**: `{{auth.token}}` renders **empty**. Use `{{auth.accessToken}}` in URL paths (verified on HubSpot OAuth token introspection endpoint).
- `{{auth.baseUrl}}` resolves in the URL — connectors can be multi-tenant with dynamic base URLs per connection.

### Non-interactive OAuth grants (password / client_credentials)
fastn OAUTH_2 supports non-interactive grants:
```json
"authConfig": {
  "grantType": "password",
  "tokenUrl": "{baseUrl}/oauth/token",
  "clientAuthMethod": "basic",
  "bodyFormat": "json",
  "scopes": []
}
```
`{field}` placeholders in tokenUrl resolve from submitted credentials. `save_connection` triggers the exchange; fastn mints/refreshes the token. `expiresAt: null` on the connection does NOT mean failure.

### fastn strips embedded query params from authorizationUrl
`?user_scope=...` or `?audience=api.atlassian.com` appended to the authorization URL get stripped by fastn's OAuth URL builder. Workaround: hand-construct the authorize link prepending the extra params to the `initiate_oauth_connection` URL.

---

## 4. Platform Bugs & Limits

### Auth method rotation gotcha (CRITICAL)
The connector's auth method gets silently replaced (new ID, title reset, `required:true` injected) by:
(a) Opening/saving the auth section in the fastn UI builder  
(b) **Every `create_actions_batch` call**

The old connection becomes orphaned ("Connection not found" even if UI shows it). Recovery: `list_auth_methods` → `update_auth_method` to re-apply titles → user reconnects. **Never store auth method IDs** — always `list_auth_methods` before use. Sequence all batch builds BEFORE the user connects.

**Note:** This rotation was observed on INPUT-type methods. OAuth methods with empty inputContract did NOT trigger rotation in at least one case (Google Drive) — may only affect INPUT methods with credential fields.

### `update_action` with `authMethodId` → 500
Per-action auth-method override is unusable. Same call without `authMethodId` works.

### `update_action` resets testStatus to untested
Any `update_action` that touches `inputContract` or `httpConfig` resets `testStatus → untested`. Re-execute as the last op after reconciling contracts.

### Large-response truncation at ~4KB
fastn executor truncates responses >~4KB with "Unterminated string in JSON at position 4012" at the MCP/tool layer. **The execution still succeeded** — check `get_action(id).lastTestEvidence` before retrying. Especially important for destructive writes (don't re-run DELETE because of a truncation error).

### Multipart / form-data binary uploads
fastn's HTTP executor emits `Content-Type: application/json` even when `bodyType: form-data` is set. Binary multipart uploads are **permanently blocked**. Workaround: use JSON `image_url` endpoints where available.

### Binary / octet-stream / 302-redirect responses → 502
- `application/octet-stream` responses: fastn double-reads the body → 502 "Body has already been read". Classify blocked; workaround is out-of-band download.
- Endpoints that 302-redirect to a CDN (Graph download endpoints): same error. Read `@microsoft.graph.downloadUrl` from getItem instead.

### Microsoft Graph change-notification subscriptions → cannot be created
Graph requires a synchronous `validationToken` plaintext echo within 10s. fastn webhook endpoints don't echo it → 400 ValidationError on `createSubscription`. **Applies to SharePoint, Teams, Outlook Graph subscriptions too.** Classify all Graph subscription create/update/delete as blocked.

### fastn force-injects Bearer on every action (breaks no-auth endpoints)
Some endpoints (e.g. Dropbox longpoll) require NO auth header. `authMethodId: null` on an action → 500 (same `update_action` bug). No workaround in fastn currently — classify these as blocked.

### Content-host downloads unusable (Dropbox-style)
APIs using a separate content host (e.g. `content.dropboxapi.com`) where the body must be EMPTY but fastn always injects the input object. Downloads from these hosts are permanently blocked. Workaround: use `getTemporaryLink` pattern.

### Redis connector (native protocol, FIXED)
Redis is a native connector protocol (`protocol: "REDIS"`). Creating a REDIS connector auto-scaffolds 46 actions covering strings, hashes, lists, sets, sorted sets, key management, and pub/sub. Connection credentials: host, port, password, tls (boolean toggle), db (0-15). Connections are pooled — cached by connection ID with 5-min idle eviction. Only `@fastn.ai` users can create REDIS connectors.

Key patterns:
- Actions are execute-only (Run Action button, no config editor).
- Template resolution: `{{key}}`, `{{value}}`, `{{field}}`, `{{member}}` in redisConfig.
- Numeric params (ttl, score, amount, start, stop) fall back to input values when redisConfig has undefined.
- Params passed as string `"[\"a\",\"b\"]"` are auto-parsed as JSON array.

### DB connector (native protocol, FIXED)
DB is a native connector protocol (`protocol: "DB"`). Supports postgres, redshift, mysql, mssql, and mongodb. Creating a DB connector auto-scaffolds 1 "Query" action. Connection credentials: dbType, host, port, database, username, password, ssl mode. Only `@fastn.ai` users can create DB connectors.

Key patterns:
- Query-only for now. User passes SQL with `?` placeholders and a `params` array.
- `?` is converted to driver-native format: `$1/$2` (postgres/redshift), `?` (mysql), `@p1/@p2` (mssql).
- Params are escaped by the driver — never interpolated into SQL. Prevents SQL injection.
- Params can be a JSON array or a JSON string (auto-parsed): `["Saman", 123]` or `"[\"Saman\", 123]"`.
- Connection pooling keyed by connection ID, 5-min idle eviction, max 5 connections per pool.
- SSRF protection blocks private/internal/metadata IPs.
- Result size capped at 10,000 rows.
- MongoDB uses find-based queries with collection, filter, and limit inputs.
- Redshift uses the pg driver with port 5439 and SSL required by default.

---

## 5. Webhook Config Patterns

### EVENT_WEBHOOK vs APP type
- **EVENT_WEBHOOK**: provider supports a REST registration API. Subscription code calls a connector action to register the webhook URL. Unsubscription calls a delete action.
- **APP**: no registration API (HubSpot, Slack, Notion, Dropbox, Fireflies). Setup = paste the fastn webhook URL into the provider's app settings UI. No subscription code needed.

### The event key gotcha: `ctx.input.event` not `ctx.input.eventId`
In webhook subscription code, the event type arrives under **`ctx.input.event`** (NOT `eventId`) — applies to all providers verified: Cin7 Core, ServiceNow, Salesforce, Dynamics 365 CRM, BigCommerce, Mailgun.

### fastn.connector.<slug>.<action>() resolver envelope
The programmatic connector call returns `{id:'exec_*', output:{...}, success, status}`.
- Most providers: payload at `res.output`
- BigCommerce: payload at `res.output.data` (extra nesting)
- Always use a safe chain: `res?.output?.data ?? res?.output ?? res`

### live-only resolver
`fastn.connector.<slug>.<action>()` inside subscription code **only sees `stage:live` actions**. Webhook management actions (createWebhook, deleteWebhook, etc.) must be promoted to live before exercising subscriptions. `stage:test` webhook mgmt actions → subscription execution fails.

### HMAC verification patterns by provider
| Provider | Header | Prefix |
|---|---|---|
| GitHub | `x-hub-signature-256` | `sha256=` |
| Fireflies | `x-hub-signature` | `sha256=` |
| Akeneo | `x-akeneo-request-signature` | stripe-style `timestamp.body` |
| Notion | `X-Notion-Signature` | `sha256=` |
| HubSpot | `X-HubSpot-Signature-v3` | (+ timestamp header) |
| Mailgun | body fields: `signature.token/timestamp/signature` — use `eventsVerification.method: "NONE"` |

### Slack webhook: CHALLENGE_RESPONSE
`url_verification` — field `type`, value `url_verification`, responseField `challenge`. No HMAC (signing secret not stored separately).

### Google Drive watch channels (not event webhooks)
Drive has no classic event webhooks. Use watch channels (`watchChanges`, `watchFile`). Event key = `resourceState` (X-Goog-Resource-State). Unsubscription via `stopChannel`.

### Salesforce Apex-trigger webhooks
No native webhook API — subscription code creates a Business Rule (`sys_script`) / Apex Class + Trigger via API. Remote Site Settings must authorize the **exact fastn host** (`live.gcp.fastn.ai`). Class script must be single-line, single-quotes only.

### ServiceNow Business Rule webhooks
No native webhook API — subscription code creates a Business Rule (`sys_script`, when=after) whose script POSTs via `sn_ws.RESTMessageV2`. Script value must be single-line, single-quotes only.

### Dynamics 365 CRM Dataverse webhooks
Register `serviceendpoint` + up to 3 `sdkmessageprocessingsteps` per subscription. `subscriptionId = endpointId|stepId1|stepId2|stepId3`. OData filter for sdkmessagefilters: `_sdkmessageid_value eq <guid> and primaryobjecttypecode eq '<entity>'` — no quotes around GUID.

### Dynamics 365 F&O Business Events
No REST webhook registration API. Business Events are configured in F&O portal under System Administration → Setup → Business Events → Endpoints (HTTPS type). Use APP-type webhook config with BusinessEventId values as event keys.

---

## 6. URL / Path Gotchas

### URL doubling
If httpConfig has BOTH a full `url` AND a `path` that repeats segments → request hits `/repos/{o}/{r}/repos/{o}/{r}`. Fix: set `url` = base host only + `path` = suffix. Re-passing httpConfig does NOT drop a stale path key — set `url` = base explicitly.

### Slash-bearing path params (Akeneo)
fastn percent-encodes `/` in every URL substitution style. If the provider's Apache rejects `%2F`, split the path param into per-segment inputs.

### Double-brace vs single-brace URL params
- `{{input.code}}` — double-brace is substituted by fastn.
- `{code}` — single-brace is NOT substituted (treated as a literal).
Always use double-brace.

---

## 7. outputContract Rules

- Always model from the **real 200 response**, not from docs.
- List endpoints returning bare arrays: wrap in `{items: [...]}` convention (fastn requires object root).
- Run `get_action(id).lastTestEvidence.responseBody` to get the real shape after execution.
- A large `create_actions_batch` response or big list response may exceed the tool limit and be saved to a file — grep it for IDs/slugs/response shapes.

---

## 8. Build Order Gotchas

### Sequence batches before connecting
Run ALL `create_actions_batch` calls BEFORE the user establishes their OAuth connection. Each batch call may rotate the auth method and orphan an existing connection.

### Validate one action first
Before mass-building: execute one simple GET (a "list" or "me" call) to confirm auth injection + response envelope. This catches auth issues before you build 100+ actions.

### `create_actions_batch` response recovery
Responses for ~30+ actions exceed the tool result limit and are saved to a file. Grep for `'"id": "'` + `'"slug":'` to recover action ID↔slug mappings.

---

## 9. Provider-Specific Quirks (No Credentials)

### HubSpot
- `batchUpsert` requires a unique `idProperty` on the object — doesn't work if no unique property exists in the portal.
- `{{auth.accessToken}}` in URL paths (not `{{auth.token}}`).
- Webhooks = APP type, activation is manual in developer.hubspot.com (paste URL + create subscriptions).
- `email` reads need `crm.objects.emails.read` scope — not granted by default OAuth.

### Slack
- HTTP is **always 200** — pass/fail determined by `ok: true` in the body. `testStatus==passed` alone is meaningless.
- `admin.*` methods require Enterprise Grid.
- `user_scope` param is stripped from fastn's OAuth authorize URL — user-token-only scopes (`reminders`, `search`, `stars`) are effectively unrequestable via fastn.
- `calls.*` scopes must be added explicitly in the Slack App Console.

### GitHub
- Full-repo responses (~6KB) hit the 4KB truncation — confirm success via `get_action lastTestEvidence`, not tool result.
- `deleteRepo` needs `delete_repo` scope — not granted by default GitHub OAuth.

### Jira
- `cloudId` is a required input on every action (from `getAccessibleResources`).
- Atlassian strips `audience=api.atlassian.com` from OAuth authorize URL — hand-construct the link.
- All webhook management actions must be promoted to `stage:live` before subscriptions work.

### Notion
- All actions must pin `Notion-Version: 2022-06-28` header.
- Notion has no hard-delete API — cleanup = archive (`archived: true`).
- Webhook verification token = the `verification_token` Notion POSTs once when the URL is pasted in the integration's Webhooks tab.

### Dropbox
- No-arg RPC endpoints: `bodyType: "raw"` + `body: "null"`.
- Content-host (`content.dropboxapi.com`) downloads are permanently blocked in fastn.
- Bearer is force-injected on every action — no-auth endpoints (longpoll) are blocked.
- Paper-content API sunset → 404.
- Webhook setup = paste URL in App Console; validation = GET `?challenge=` echo.

### Microsoft Graph (OneDrive, SharePoint, Teams, Outlook)
- `validationToken` echo = permanently blocked. No Graph change-notification subscriptions.
- Binary/302-redirect downloads → 502. Use `@microsoft.graph.downloadUrl` out-of-band.
- Auth variable: `{{auth.accessToken}}` (not `{{auth.token}}`).
- D365 CRM: must use `/organizations/` tenant endpoint (not `/common/`) for `dynamics.microsoft.com` scopes.
- D365 F&O: client app must also be registered in F&O under System Administration → Microsoft Entra Applications (otherwise valid token but OData 401).

### Salesforce
- `TEMPLATING GOTCHA`: unfilled optional `{{input.X}}` placeholders pass literal `"{{input.X}}"` to Salesforce and error on date/ref fields. Keep bodyTemplates minimal.
- Webhook management actions (createApexClass, createApexTrigger, etc.) must be `stage:live` for the resolver.
- Remote Site Settings authorize by **exact host** — `live.gcp.fastn.ai` must have its own entry.

### ServiceNow
- Typed UPDATE sends every listed field → blanks untouched columns. Use generic `updateTableRecord` for partial updates.
- `change_request` UPDATE must carry a valid `state` — business rule returns 403 on empty state.
- Generic create/update: pass `fields` as JSON string with `bodyType:raw` + `bodyTemplate:"{{input.fields}}"`.
- UI gotcha: opening the auth section in the fastn builder and saving regenerates the auth method. Use INPUT type with all 3 fields (instance, username, password) — never edit it in the UI.

### Akeneo
- Writes are PATCH = UPSERT. Single-resource PATCH `/{code}` = normal JSON. Collection PATCH = NDJSON → fastn 502.
- The live `GET /api/rest/v1` routes map is ground truth for path disputes — prefer it over OpenAPI spec.
- `execute_action` MCP tool can fail with "Unterminated string" on big bodies — check `get_action(id).lastTestEvidence` instead.

### BigCommerce
- Multi-field credentials (storeHash + apiKey) → use INPUT auth type, NOT API_KEY.
- Webhook `createSubscription` requires a resolvable HTTPS destination URL.
- Resolver envelope: `res.output.data` (one extra nesting vs most providers).

### Cin7 Core / DEAR Inventory
- get-by-id always uses query param (`?ID=`), never a path segment.
- Webhook subscription code: `ctx.input.event` (not `eventId`).
- Tasks module disabled by default — all `/crm/task*` return 400 until enabled in Settings.
- DELETE is unsupported for production module (405) and some other resources (502).

### Miro
- Webhooks were **permanently discontinued on 2025-12-05** — webhook management actions all return 500. No replacement.
- SCIM requires Enterprise provisioning token (OAuth token insufficient).
- Mindmap nodes have no update endpoint (PATCH + PUT both 405).
- `getAuditLogs`: both `createdAfter` AND `createdBefore` are required (format: `YYYY-MM-DD`).
- List `limit` must be ≥ 10 — `limit < 10` returns 400.

### Mailgun
- Auth = BASIC: username `api`, password = API key.
- form-urlencoded bodyTemplates: fastn sends all unset `{{input.xxx}}` keys as literal strings. For actions with optional fields, use `bodyType: "raw"` + explicit `Content-Type: application/x-www-form-urlencoded`.
- `getMetrics`: date format must be RFC 2822 (e.g. `"Thu, 01 May 2026 00:00:00 -0000"`), NOT ISO 8601.
- Webhook verification = body HMAC, not header → use `eventsVerification.method: "NONE"`.
- Webhook URL must resolve over HTTPS (Mailgun validates DNS).

### Supabase (two-connector pattern)
- Two connectors: one for data-plane (PostgREST/Storage/Auth Admin), one for Management API.
- Management API: `projectRef` is a required input on every ref-scoped action (one PAT targets any project).
- `region_selection` object required on `createAProject` (not deprecated `region` string).
- `getEdgeFunctionBody` = permanently blocked (`application/octet-stream` 502).
- `getAuthServiceConfig` GET response exceeds 4KB → classified blocked for executor output size.

### Fireflies (GraphQL)
- BEARER auth, field named `token` — but because it's GraphQL and all actions explicitly set `Authorization: Bearer {{auth.token}}`, the auto-injection matches and doesn't conflict.
- 50 GraphQL requests/day on free plan — resets midnight UTC.
- `analytics` needs Business+; `auditEvents` needs Enterprise.

### Google Drive
- Watch channels (not event webhooks). Channel ID must be hash-based (no `Date.now()` in connector code).
- `stopChannel` for unsubscription (channelId + resourceId from subscribe output).
- `listApps`/`getApp` require `drive.apps.readonly` scope — add after initial OAuth connect (requires reconnect).

### Notion
- Webhook verification token arrives as one-time POST when URL is pasted in integration settings — it's the HMAC key.

---

## 10. Definition of Done Checklist (per action)

An action is complete only when all four hold:
1. **built** — exists with auth headers + httpConfig.
2. **tested200** — `testStatus==passed` AND `lastTestEvidence.responseStatus==200`. (Non-200 is a fail unless it's a classified business-state block like 404-no-data or 403-plan-gate.)
3. **inputReconciled** — `inputContract` is field-by-field and contains every key the working request sent (superset rule: may include additional optional fields). No opaque `body` string.
4. **outputReconciled** — `outputContract` modeled from the real response, not a docs guess.

A connector is COMPLETED only when: every spec resource has actions; every action is DONE or a justified `blocked`; zero anti-patterns (`{{input.body}}`, raw bodyType on writes, missing outputContract, untested); webhooks configured and exercised.