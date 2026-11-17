# Worked examples

Made-up companies and example apps. They show the shape of a good answer, not facts about the catalog and not a default proposal: every app, piece and design here is only an example. Build each answer from the user's own use case and the live checks.

## 1. Fits: CRM sync into an invoicing product
**User**: "We're Ledgerly, invoicing software. When a deal closes in our customer's CRM we want to create a draft invoice. Customers use different CRMs."

**Requirement summary**: product = invoicing; job = closed deal → draft invoice; systems = customer's CRM (several) + Ledgerly; direction = read CRM, write Ledgerly; timing = on change; each customer connects their own CRM inside Ledgerly.

**Solution**
| Need | Piece | Set up |
| --- | --- | --- |
| Customers connect their CRM | P10 widget + P4 connections | Widget with the CRM integrations |
| Know when a deal closes | P7 app event trigger | One per CRM that lists the event |
| Same deal shape across CRMs | P9 unified API, crm/opportunity | Read the deal |
| Create the invoice | P5 + P6 workflow | Ledgerly connector, scope `billing` |
| Tell Ledgerly it worked | P8 workflow event | Endpoint + signature check |

Your own checks before answering (not shown to the user): connectors and auth for each CRM, `listConnectorEvents` for the deal event, the unified `get` per provider, that the Ledgerly connector exists, that the endpoint exists.

**Verdict**: Fits. If one CRM has no deal event, that CRM gets a schedule trigger that polls instead; it goes in the table as the way that CRM works, not as a gap.
**Prepare**: a sandbox account per CRM, Ledgerly API docs, a public https endpoint, your own OAuth apps for branding.

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
