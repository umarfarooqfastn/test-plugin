# Setup guide, piece by piece

Open only the sections for the pieces in the solution. Each ends with a check: do not move on until it passes.
Dashboard paths are as the docs name them (https://docs.fastn.ai). With the fastn MCP connected, the matching skill can do most steps for the user; say which.

## Contents
P1 Customers · P2 Connectors · P3 Auth providers · P4 Connections · P5 Connect your product · P6 Workflows · P7 Triggers · P8 Event subscriptions · P9 Unified APIs · P10 Widget · P11 SDK · P12 Build with AI · P13 Environments · P14 Operate · P15 Settings · C1 MCP endpoint · C2 to C11 fastn Connect

## P1. Customers
1. Decide your customer id: the id the customer already has in your database.
2. Create the customer under **Operate → Customers**, or from the backend with `customer.register({ name })`. A setup link also creates it on first use.
3. Or over REST from your backend: `POST https://api.fastn.dev/api/v1/orgs` with `{ "name": "...", "orgId": "<your id>" }` and your API key. Register the customer before you mint its first embed token, or mint with `createIfMissing` (see `sdk.md`).
Check: the customer shows in the list with your id.

## P2. Connectors
1. Open **Integrations → Connectors** and find the app.
2. Open it and read its actions. Confirm each action the use case needs.
3. Missing app or action: build it with the `connector_builder` skill, or propose a request.
Check: every needed action is listed, and one read ran successfully.

## P3. Auth providers (your own OAuth app)
Do this for production branding, your own rate limits, or when the connector has no shared app.
1. Create an OAuth app in the vendor's developer console. Use the redirect URL fastn shows in the provider form.
2. In the connector's **Auth** tab choose **View providers** and add a provider with the client id and secret.
3. Mark it preferred.
Check: the connect dialog shows your app, and the consent screen shows your name.

## P4. Connections
1. For your own systems: connect once, platform-wide.
2. For customer data: the customer connects, through the widget, a share link or a setup link.
3. Choose organization level or user level per integration.
Check: the connection is live under **Operate → Connections**, and one harmless read works. A saved key can be wrong.

## P5. Connect your product
Needs an Owner or Admin; other roles cannot save it.
1. Open **Build → Connect your product → API connector**.
2. Pick the connector for your own product. Not in the catalog: build it first with `connector_builder`.
3. Add connection scopes that name a capability (`inventory`, `billing`), not one per customer.
4. On the **Webhooks** tab, add where fastn should call your product back (see P8).
Check: the connector is listed with its scopes. Without this no integration goes live.

## P6. Workflows
1. Describe the job in plain words to **Build with AI** or to your AI tool with the `integration_builder` skill.
2. Pick the execution tier: Instant only if a caller waits; otherwise Standard; Long for runs over 15 minutes.
3. Test with real inputs in `test`. Remember test reaches real connections.
4. Publish. Promote to `live` when it passes.
Check: one run with real data finished and the result is right in the target app. Use `workflow_verifier`.

## P7. Triggers
Open **Integrations → Triggers → Add trigger**.
- **Webhook**: create it, copy the URL, give it to the sender, send one test POST. Turn on the dead letter queue if losing an event is not acceptable.
- **Schedule**: set the interval and the workflow. Watch the Failures column; repeated failures disable it until the cooldown passes.
- **App event**: name, connector, connection, event, at least one route (workflow). Connector and connection cannot be changed later. A live connection must exist first.
Check: for an app event, the **Subscription** column reads `Subscribed`. Then cause the event once in the app and see a run.

## P8. Event subscriptions (fastn calls your product)
1. Build a public https endpoint.
2. Register it: **Connect your product → Webhooks**, or `POST /v1/event-subscriptions`, or `fastn.webhooks.create(...)` in the SDK. Pick the event types.
3. Store the signing secret; it is shown once.
4. Verify every request over the raw body, reject timestamps more than 5 minutes off, and drop repeats by event id.
Check: send a test event and see a verified `200` from your endpoint.

## P9. Unified APIs
1. Open **Integrations → Unified APIs** and find the category and entity.
2. Confirm each provider you need is mapped for that entity and operation.
3. Call it from the SDK (`customer.records(...)`) or REST. Hand over to the `unified_api` skill for setup.
Check: the same call returns a record from two different providers.

## API keys
Open **Embed → API keys and MCP → API keys → Create key**.
1. Name it after its job. Mode: **Test** for development (calls need `X-fastn-Test-Mode: true`), **Live** for production (also pick the environment).
2. Permissions: the **Embed backend** preset fits a backend that registers customers and mints embed tokens. That key should reach **every customer**; a key limited to some customers is refused for those calls.
3. A key you hand to one of your customers: custom permissions with only what they need, reach **only that customer**, and a resource scope if it should call one workflow. Never give a customer a key that reaches every customer.
4. Optional: allowed IP addresses, a rate limit per minute, an expiry.
5. Optional: **caller identity verification (HMAC)**. Modes: Off, Monitor only, Enforce. See P10 step 3.
6. Copy the key: it is shown once. Store it in your backend's secret store. To replace a leaked key, create a new one, switch over, then revoke the old one.
7. Calling a workflow with a key: `POST https://api.fastn.dev/api/v1/workflows/<workflow id>/execute` with `Authorization: Bearer <key>`, `Content-Type: application/json` and body `{ "input": { ... } }`. A test key also needs `X-fastn-Test-Mode: true`. The workflow's **API** tab shows the exact call to copy.
Check: one call with the key returns `200`, and a call for a customer it may not reach is refused.

## P10. Widget
First do **Connect your product** (P5): no integration goes live for customers without it.
1. Build it under **Embed → Widget**: which integrations show, what customers may change, how it looks. Save and publish; customers see only what is published.
2. Register the customer (P1) and create the backend key (API keys, above).
3. Optional, recommended: identity verification. Turn it on for the key; the signing secret is shown once and never goes to the browser. On every customer call send `x-org-id`, `x-user-id` and `x-identity-hmac` = hex HMAC-SHA256 of `<orgId>\n<userId>` with that secret. In Enforce mode a missing or wrong hash is refused.
4. Mint one embed token per customer, per session, on your backend (`references/sdk.md`). Send `userId`. Tokens last 8 hours; the SDK refreshes them, up to 7 days per session. At the cap the widget posts `fastn:session-expired` to the page: mint a new token.
5. Mount it, simplest first:
   - iframe: `<iframe src="https://api.fastn.dev/api/v1/embed/iframe?token=..." allow="clipboard-write" style="width:100%;height:600px;border:none"></iframe>`
   - React or script tag from `@fastn-ai/embed`, or your own UI with the headless hooks: register your page's origin on the key that mints the tokens, or the browser blocks it.
   - No code yet: a share link from **Embed → Widget → Embed**, with an expiry. Treat it as a secret.
6. If you send setup links with `redirectUrl`, register those addresses first (`sdk.md`); others are refused with `400 SETUP_LINK_REDIRECT_NOT_ALLOWED`.
7. Before going live: your own OAuth app (P3), `https://api.fastn.dev` in your CSP `frame-src`, and test with the widget builder's customer preview, then as a real customer.
Check: signed in as a test customer, you see only that customer's connections and can connect one app end to end.

## P11. SDK
See `references/sdk.md`.
Check: `fastn.me()` returns your org and the expected environment.

## P12. Build with AI
Open the **Build with AI** row in the sidebar, describe the integration, review the diff, accept.
Check: same as P6.

## P13. Environments
1. Build and test in `test`. 2. Publish to create a version. 3. Promote the version to `live`. 4. If the environment requires review, approve the pull request it opens.
Check: the live environment runs the version you tested.

## P14. Operate
1. Look at executions and traces after the first real runs.
2. Create an alert for failures a customer would otherwise report first.
Check: a forced failure raises the alert.

## P15. Settings
Add the people who will build (Developer or above) and operate. Put values workflows need in secrets, never in code.
Check: each person can do their job and nothing more.

## C1. MCP endpoint
- Your team: **Connect AI tools** in the top bar, or **Embed → API keys and MCP → MCP server**. Add `https://mcp.fastn.dev/fastn-workspace` to the AI client and sign in.
- Your customer's AI client (needs the customer from P1 and an embed token from P10 first): create a customer MCP URL with `POST /api/v1/embed/mcp-connect-codes`, authorized with that customer's embed token (minted with a `userId`). Show the returned URL to the customer.
Check: the client lists fastn tools, and `whoami` shows the right workspace or customer.

## C2 to C11. fastn Connect
These are set up in the fastn Connect app, one page each: **Tools** (apps and tools, read or write), **Connect** (each person's accounts), **Policies** (who may call what, hidden fields), **Agents** and **Access** (non-human clients and their keys), **Skills**, **Monitor**, **Audit**, **Team**, **Settings**.
Order that works: connect the apps → set policies before giving an agent access → create the agent with the narrowest access → run one task and read it in Monitor.
Check: the agent can do its job, a blocked call is refused, and the run shows in Monitor.
