# SDK guide

Two different packages. Do not mix them up.

| Package | Runs | Needs | For |
| --- | --- | --- | --- |
| `@fastn-ai/sdk` (Node.js 20+, TypeScript types) and `fastn-ai` (Python 3.8+, same features, Python-style names) | Your backend | Your API key (`fsk_…`) | Customers, connecting apps, records, app actions, events |
| `@fastn-ai/embed` | The browser | An embed token (`emb_…`) minted by your backend | Showing the connect widget inside your app |

The API key is a password. It stays in the backend's secret store and never reaches a browser.
Full reference: https://docs.fastn.ai (Reference → SDK). Read it for exact fields; the catalog is live data.

## Backend SDK

### Client
```typescript
import { FastnClient } from "@fastn-ai/sdk";
export const fastn = new FastnClient({ apiKey: process.env.FASTN_API_KEY! });
const customer = fastn.customer("acme_customer_42"); // YOUR id for the customer
```
Create one client at start-up and reuse it. `fastn.me()` shows who the key is (role, org, environment). Default base URL `https://api.fastn.dev`, timeout 60s, 2 retries.

### Customers
You name each customer with your own id and use it everywhere. A setup link creates the customer on first use; `customer.register({ name })` sets the name yourself. Also `customer.find()`, `customer.get()`, `customer.update(...)`.

### Connect an app (setup links)
```typescript
const link = await customer.connect("hubspot", {
  label: "Customer name shown on the page",
  connectionName: "Main account",
  expiresInMinutes: 10080,            // default and maximum: 7 days
  redirectUrl: "https://app.example.com/connected",  // must be registered first
  metadata: { flowId: "f_1" },        // returned on setup_link.completed, up to 4 KB
  allowAdditionalConnection: false,   // true lets the customer add a second account of the same app
});
// link.setupId (stp_...), link.url (send it), link.status, link.expiresAt
```
- `connect(app)` finds your widget for that app and returns a hosted link. It works once and expires. Check or cancel it with `customer.links.get(setupId)` and `customer.links.cancel(setupId)`.
- Register redirect addresses once: `fastn.orgs.updateOrgConfig({ id, setupLinkRedirectUrls: [...] })` replaces the whole list. An address not on it: `400 SETUP_LINK_REDIRECT_NOT_ALLOWED`.
- `404 WIDGET_NOT_FOUND`: no widget offers that app, build one first. `409 WIDGET_AMBIGUOUS`: pass `widgetId`.
- When the customer finishes, `connection.connected` (with the account id) and `setup_link.completed` (with your metadata) arrive on your webhook, both with `tenantRef` = your customer id.
- To show the widget inside your app instead, mint an embed token (below).

### Accounts and offboarding
- `customer.connections()` lists the customer's accounts (id, name, connector, status). Keep the account id: it pins a call to one account (`connectionId`) and disconnects it.
- `customer.disconnect(accountId)` removes one account (you receive `connection.revoked`).
- `customer.update({ status: "suspended" })` pauses a customer; `customer.remove()` suspends and deletes it, with its accounts and data. Deleting needs the customer suspended first.
- App changes as events: `customer.watch("hubspot", [...events])` after the app is connected; `customer.watchableEvents(app)` lists what it offers; `customer.unwatch(app)` stops it. Some apps need the customer's own account number.

### Unified records
```typescript
const contacts = customer.records({ category: "crm", entity: "contact" });
await contacts.create({ first_name: "Jane", email: "jane@example.com" }, { idempotencyKey: "signup_9f2" });
```
`create`, `get`, `list`, `search`, `update`, `delete`. Change only `provider` to use another app. Read the catalog with `fastn.unified.listUnifiedCategories()` instead of hard-coding it. Typed helpers exist for calendars and CRMs (`customer.calendar`, `customer.crm`).

Errors to plan for: `404 NO_CONNECTED_PROVIDER` (send a setup link), `409 PROVIDER_AMBIGUOUS` (pass `provider`), `404 OPERATION_NOT_SUPPORTED` (that app cannot do it; check `providers()`), two accounts of one app (pass `connectionId`).

### An app's own action
Use when the unified shape lacks a field or operation.
```typescript
const actions = await fastn.connectors.listConnectorActionsBySlug({ connector: "hubspot" });
const schema = await fastn.connectors.getConnectorActionSchema({ connector: "hubspot", action: "getContact" });
const r = await customer.runAction({ connector: "hubspot", action: "getContact", input: { contactId: "123" } });
```
`action` is the slug, not the display name. The call runs with that customer's own connection.
An error from the app does not throw: `runAction` returns normally with `data.success: false`, the app's `data.status` and `data.error`. Always check `data.success`. It throws `FastnApiError` only when fastn cannot run the action at all (for example an unknown action slug).

### Events to your backend
```typescript
const hook = await fastn.webhooks.create({
  url: "https://api.example.com/fastn/events",
  eventTypes: ["connection.connected", "connection.expired", "setup_link.completed"],
});
// hook.secret (whsec_…) is shown once: store it now
```
Verify each request with `parseEvent` from the SDK before trusting the body. Reply `200` first, do the work after. Match the customer on `tenantRef` (your id). `connector.event`, `unified.event` and `workflow.event` are sent only when listed, and the first two need an app event trigger.
A retry carries `X-Fastn-Redelivery: true`. Retries back off for up to 24 hours, then the delivery is marked dead. Manage the webhook with `fastn.webhooks.test(id)`, `deliveries(id)`, `replay(deliveryId)`, `rotateSecret(id)` (the old secret stops at once), `list`, `get`, `update`, `delete`.

### Answers, errors and retries
- A record answer is `{ id, provider, data, warnings? }`; a page is `{ records, hasMore, nextCursor }`; a delete is `{ id, provider, deleted: true }`. `warnings` names fields the app did not take.
- Record fields are snake_case (`start_time`); options are camelCase (`idempotencyKey`). Dates are ISO 8601 with an offset.
- Pass `idempotencyKey` on every write (create, update, delete). The same key within 24 hours returns the first answer; the same key with a different body: `422 IDEMPOTENCY_KEY_REUSED`. `409 IDEMPOTENCY_IN_PROGRESS`: the first run is still going; wait and resend with the same key.
- The SDK retries reads, and writes that carry a key, on `429` (after `Retry-After`), `502`, `503`, `504` and network errors. It never retries other 4xx. An error from the app itself (5xx): resend yourself with the same key.
- A failed call throws `FastnApiError` (status, code, message, details). A call that got no answer throws `FastnNetworkError`.
- Codes to plan for: `404 NO_CONNECTED_PROVIDER` (send a setup link), `409 PROVIDER_AMBIGUOUS` (pass `provider`), `404 UNIFIED_CONNECTION_NOT_FOUND` (wrong or removed `connectionId`; never falls back), `400 UNIFIED_VALIDATION_FAILED` (a required field is missing; nothing reached the app), `404 OPERATION_NOT_SUPPORTED`.
- A record you just created can take a few seconds to appear in a search. Key creates on what must be unique (an email or phone), not on the request.
- Override per call: `{ retries, timeoutMs }`. Pass `correlationId` and read it back with `customer.callLog(correlationId)`.

### Anything else
Every API operation is on the client by area (`fastn.orgs`, `fastn.connections`, `fastn.connectors`, `fastn.unified`, `fastn.events`, `fastn.embed`, `fastn.workflows`), or by name with `fastn.call(operationId, input)`. `paginate()` walks lists.

## Embed token (backend) and widget (browser)

Mint one token per customer, per session, on your backend:
```http
POST https://api.fastn.dev/api/v1/embed/token
Authorization: Bearer <API key>
x-org-id: <your customer id>
Content-Type: application/json

{ "userId": "user_123" }
```
Read `response.data.token`. It lasts 8 hours. Always send `userId`; without it nothing carries over between sessions. `x-org-id` names a customer, never your own org.

Then show the widget, simplest first:
- **Iframe**: one tag, `src="https://api.fastn.dev/api/v1/embed/iframe?token=…"`.
- **React**: `FastnHub`, `FastnHubModal`, `FastnConnectCard` from `@fastn-ai/embed/react`, with a `getToken` function that calls your backend route.
- **Script tag**: a hosted bundle for Vue, Svelte, Rails or plain HTML.
- **Your own UI**: hooks from `@fastn-ai/embed/headless/react`; your page's origin must be registered.

Copy the exact snippet from **Embed → Widget → Embed** in the dashboard. Before going live read "Embedding in production" in the docs: per-customer tokens, your own OAuth app for branding, `https://api.fastn.dev` in your CSP `frame-src`, publish then test as a real customer.

## Python
```python
# pip install "fastn-ai>=0.5.1"   (Python 3.8+)
import os
from fastn.platform import FastnClient

fastn = FastnClient(api_key=os.environ["FASTN_API_KEY"])   # timeout= in seconds, retries=
customer = fastn.customer("acme_customer_42")
token = customer.embed_token({"userId": "user_123"})["data"]["token"]   # answers are the raw body: read ["data"]
```
- Synchronous: no `await`. One client per process; call `fastn.close()` on shutdown. Do not name your own file `fastn.py`.
- Methods are snake_case, not the Node.js names: `customer.embed_token({...})`, `customer.call_log(id)`, `customer.run_action(connector, action, input)`, `customer.records(category, entity, provider=...)`.
- Options are keyword arguments: `idempotency_key=`, `correlation_id=`, `retries=`, `timeout=`.
- Events: `parse_event(secret, headers, raw_body)` raises `ValueError` on a bad signature; `verify_event_signature(...)` returns True or False. Pass the raw body bytes (Flask: `request.get_data()`; FastAPI: `await request.body()`).
- `embed_token` and `connect` create the customer if it does not exist yet, so they work before `register()`.
- Errors: `from fastn.platform import FastnApiError, FastnNetworkError`. `FastnApiError` has status, code, message, details, request_id.
- Retries: the client retries reads, and only the writes fastn de-duplicates (unified record writes and workflow execute) when they carry `idempotency_key=`. Other writes are never retried, key or not.
- For anything not listed here, read the package's own docstrings: the public docs show Node.js first.
