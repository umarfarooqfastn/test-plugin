# Setup guide, piece by piece

Open only the sections for the pieces in the solution. Each ends with a check: do not move on until it passes.
Dashboard paths are as the docs name them (https://docs.fastn.ai). With the fastn MCP connected, the matching skill can do most steps for the user; say which.

## Contents
P1 Customers · P2 Connectors · P3 Auth providers · P4 Connections · P5 Connect your product · P6 Workflows · P7 Triggers · P8 Event subscriptions · P9 Unified APIs · P10 Widget · P11 SDK · P12 Build with AI · P13 Environments · P14 Operate · P15 Settings · C1 MCP endpoint · C2 to C11 fastn Connect

## P1. Customers
1. Decide your customer id: the id the customer already has in your database.
2. Create the customer under **Operate → Customers**, or from the backend with `customer.register({ name })`. A setup link also creates it on first use.
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

## P10. Widget
1. Build it under **Embed → Widget**: which integrations show, what customers may change, how it looks. Save and publish.
2. Mint an embed token per customer on your backend (`references/sdk.md`).
3. Mount it: iframe, SDK, or send a share link for a pilot.
4. Before going live: your own OAuth app (P3), `https://api.fastn.dev` allowed in your CSP `frame-src`, test as a real customer.
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
