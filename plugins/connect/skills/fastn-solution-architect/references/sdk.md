# SDK guide

Two different packages. Do not mix them up.

| Package | Runs | Needs | For |
| --- | --- | --- | --- |
| `@fastn-ai/sdk` (Node.js 20+, TypeScript types) and `fastn-ai` (Python, same client) | Your backend | Your API key (`fsk_…`) | Customers, connecting apps, records, app actions, events |
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

### Connect an app
```typescript
const link = await customer.connect("hubspot", { redirectUrl: "https://app.example.com/connected" });
// send link.url to the customer
```
`connect(app)` finds your widget for that app and returns a one-time hosted link. `404 WIDGET_NOT_FOUND`: no widget offers that app, build one first. `409 WIDGET_AMBIGUOUS`: pass `widgetId`. To show the widget inside your app instead, mint an embed token (below).

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

### Events to your backend
```typescript
const hook = await fastn.webhooks.create({
  url: "https://api.example.com/fastn/events",
  eventTypes: ["connection.connected", "connection.expired", "setup_link.completed"],
});
// hook.secret (whsec_…) is shown once: store it now
```
Verify each request with `parseEvent` from the SDK before trusting the body. Reply `200` first, do the work after. Match the customer on `tenantRef` (your id). `connector.event`, `unified.event` and `workflow.event` are sent only when listed, and the first two need an app event trigger.

### Safe retries
- Pass `idempotencyKey` on record writes; the same key returns the first answer instead of acting twice. Same key with a different body: `422 IDEMPOTENCY_KEY_REUSED`.
- The SDK retries reads, and writes that carry an idempotency key, on `429`, `502`, `503`, `504` and network errors. Other writes are never retried.
- Pass `correlationId` and look it up later with `customer.callLog(correlationId)`.

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
`pip install fastn-ai`; `from fastn.platform import FastnClient`; `fastn.customer(ref)` gives the same per-customer object. Method names follow the Node.js SDK; check the package's own reference for exact spelling.
