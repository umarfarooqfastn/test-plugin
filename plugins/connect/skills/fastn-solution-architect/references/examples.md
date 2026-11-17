# Worked examples

Made-up companies and example apps. They show the shape of a good answer, not facts about the catalog and not a default proposal: every app, piece and design here is only an example. Build each answer from the user's own use case and the live checks.

## 1. Fits: CRM sync into an invoicing product
**User**: "We're Ledgerly, invoicing software. When a deal closes in our customer's CRM we want to create a draft invoice. Customers use different CRMs."

**What you learned from the questions**: each customer connects their own CRM inside Ledgerly; it should happen when the deal closes; several CRMs.

**Answer**

Yes, fastn is a great fit for this. The CRMs your customers use are in the catalog, and the deal data is covered by one unified API.

How it would work:
1. **Widget.** Each customer connects their own CRM inside Ledgerly.
2. **App event trigger.** fastn hears when a deal closes in that CRM. A CRM with no deal event gets a schedule trigger that checks for closed deals instead.
3. **Unified API.** The workflow reads the deal in one shape (`crm` → `opportunity`), whatever the CRM.
4. **Workflow.** It creates the draft invoice through the Ledgerly connector.
5. **Event to your product (optional).** fastn tells Ledgerly the invoice was created.

Things to know:
- Ledgerly needs its own connector on fastn, so its invoice action can be called.
- With your own OAuth apps, the CRM sign-in screens carry your brand.

What to have ready: a sandbox account per CRM, Ledgerly API docs, a public https endpoint.

Say **build it** and I will set this up in your workspace, or tell me what to change.

Your own checks before answering (not shown to the user): connectors and auth for each CRM, `listConnectorEvents` for the deal event, the unified `get` per provider, that the Ledgerly connector exists.

## 2. Fits with a gap: app not in the catalog
**User**: "We need to push orders into Shipwell-X, a regional courier."
`listConnectors` finds nothing. Say so. Ask whether Shipwell-X has an API and docs. If yes: build a custom connector (`connector_builder`), continue the design with it marked "to build", and log a ticket with fastn so it gets added to the catalog. If no API: not possible through an API; offer what the courier does accept.

## 3. Better served by a simpler piece
**User**: "Build a workflow that fetches a contact from the customer's CRM when our support agent opens a ticket."
One read, caller waits. No workflow needed: a unified API read (`customer.records({category:"crm", entity:"contact"})`) from the backend. Check which operations each CRM supports first: one may offer `search`, another only `get` by id. Where the operation is missing, use that app's own action with `customer.runAction(...)`. Say why: less to build, nothing to deploy.

## 4. AI agent use case
**User**: "Our customers want to use Claude with their data in our product and their ticketing app (for example Jira)."
C1 customer MCP URL behind a "Connect Claude" button, P5 so your product's actions are tools, P4 user-level connections to that app, C4 policies for write actions. Check: the embed token carries the user id; the customer's client lists only their tools.

## 5. Does not fit today
**User**: "We need to read from a mainframe on the customer's private network, no internet access allowed."
fastn reaches systems over the internet. Without a reachable https address or a gateway on the customer's side this does not fit today. Say it plainly, name the workaround (the customer exposes a secured endpoint or pushes files or webhooks out), and log a ticket with fastn for the need.
