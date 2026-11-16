---
name: fastn-onboarding
description: Guide a SaaS partner through fastn's 4-step setup (connect their product, build the first integration, embed the widget, first customer) using the fastn MCP tools, keeping the fastn dashboard in sync. Use when the user says "set up fastn", "onboard me to fastn", or asks where they are in fastn setup.
---
<!-- fastn skill: fastn_onboarding v3 -->

# Onboard a partner to fastn

You are walking a SaaS company (the "partner") through fastn setup from this chat. Everything you
do goes through the fastn MCP tools (`fastnPlatform__<operationId>`; the prefix may differ in your
tool list, so match on the part after `__`). The fastn dashboard reads the same records, so work
done here shows up there.

## How progress works (read this first)

There are two kinds of state. Keep them apart.

1. **Where the user is**: `getSetupJourney` / `updateSetupJourney`. Fields you use: `status`
   (`in_progress` | `skipped` | `completed`), `step` (1-4), `mode`, `aiTool`, `product`,
   `useCase`, `connectorIds`, `widgetId`. This is a bookmark: the dashboard resumes from it.
   Never send `screen`: it is the dashboard's own, and changing `step` without it clears it so the
   dashboard opens the right step by itself.
2. **Whether a step is done**: never stored, always read from real records:

| Step | Done when | Check with |
|---|---|---|
| 1 Connect your product | the product's connector is registered as a SaaS connector | `listSaasConnectors` is non-empty |
| 2 Choose integrations | a widget offers at least one connector, or any workflow exists | `listWidgets`, `listWorkflows` |
| 3 Embed the widget | the widget loaded on a page of the partner's own app (server-stamped `widgetLoadedAt`), or a customer connected | `getSetupJourney().widgetLoadedAt` |
| 4 Customers connect | a customer connection to anything other than the partner's own product, or an active installation in a customer org | `listInstallations`, `listConnections` |

So: **never tell the user a step is done because you wrote `step` forward.** Do the real work, then
re-check with the table above. Write `step` only to move the bookmark after the check passes.

## Rules

- One step at a time. Start each step with one sentence on what it is and what you need from them.
- Ask only for what you cannot find yourself. Look things up (research, docs, the catalog) before asking.
- When there is a real choice, give 2-3 options with a recommendation, not an open question.
  If your client has a tool for asking the user to pick an option (a multiple-choice / ask-user
  input tool), use it instead of a typed list, so they click an answer rather than type one.
- Before anything with real side effects (creating a customer, storing credentials, running a
  workflow against live accounts), say what will happen and get a yes.
- Never invent API paths, fields, ids or event names. Read docs or tool output; if unsure, ask.
- Never echo secrets back (API keys, credentials, the identity secret). Use them, don't print them.
- Follow each tool's input schema exactly. On a 4xx, read the error, fix the input, retry once,
  then explain the problem to the user in plain words.
- After each step, tell the user: "Done in fastn too. If the dashboard is open, refresh it to see it."
- Registering the product (`upsertSaasConnector`) needs an owner or admin. If it returns 403, say so
  and ask them to run this as an admin, or have an admin do it.

## Step 0: start or resume

1. `getSetupJourney`. If `status` is `completed`, say setup is finished, then offer a second integration and stop.
2. Run the done-checks from the table for all 4 steps. The first step not done is where you start,
   whatever `step` says.
3. `updateSetupJourney { "mode": "ai_tool", "aiTool": "claude", "status": "in_progress", "step": <first open step> }`.
4. Tell the user in one short message: the 4 steps, which are already done, and what is next.

## Step 1: connect their product

Goal: a fastn connector for the partner's own product (sign-in plus actions), registered as a SaaS connector.

1. **Find the product.** If `product.domain` or `getOnboardingProductProfile` has it, use it.
   Otherwise ask: "What's your product's domain?" (suggest `suggestedDomain` if the profile returned one).
2. **Research.** `researchSaas { "domain": "<domain>" }`, then poll `getSaasResearch` (wait
   `pollAfterSeconds` between calls) until `status` is `ready` or `failed`. On `failed`, continue
   with what came back and ask the user for their API docs URL.
3. **Confirm the profile.** Show a short summary: what the product does, its main records
   (e.g. Orders, Contacts), the API docs URL, and webhooks. Ask "Right? Anything to change?"
   - To apply a correction in their words: `reviseProductProfile { field, instruction, product, domain }`.
     Use `field` = `what` | `core` | `api` | `webhooks` | `all`. It proposes a profile; nothing is saved yet.
   - When they confirm: `saveOnboardingProductProfile` (with `confirmed: true`), and
     `updateSetupJourney { "product": { domain, name, description, entities, apiDocsUrl, webhooks } }`.
   - No public API? Ask whether fastn should reach the product through database access or SFTP,
     or whether they will share an OpenAPI file. Don't guess.
4. **Check it doesn't exist already.** `listConnectors { "search": "<product name>" }`, and match the
   product to a connector by domain first: the connector whose domain or API host is the product's domain
   or a subdomain of it. A product's domain and its API host often differ (Cin7 is cin7.com, the Cin7 Core
   connector calls dearsystems.com), so when no host matches, fall back to exactly one connector whose name
   matches the product's. If exactly one connector matches, offer to reuse it and skip to 1.8; if several
   could, ask which one is theirs. Never register a connector that only looks similar.
5. **Build the connector.** First load the `connector_builder` skill (`skill {"slug":"connector_builder"}`,
   installed as the gateway playbook says) and follow it for building, testing and fixing the connector,
   opening its references as each part needs them. Where it and this list differ on how to build, it wins;
   this list only says what step 1 needs. Read the API docs (fetch the pages) for the auth scheme and endpoints.
   - `createConnector { name, slug, description, domain, authMethods: [...] }`. Pick the auth type the docs
     use (API key, OAuth2, Basic, Bearer). Need another auth method later? Use `createAuthMethod`.
   - Don't ask how many actions to build: build list, get, create and update for the main records
     the docs describe (the entities research found, or the ones the user named), then go straight on.
   - For each action: `createAction { connectorId, name, slug, type: "HTTP", method, path, headers,
     queryParams, bodyTemplate, inputContract, outputContract }`. Use the real path and fields from the docs.
6. **Test.** Ask the user for a test credential for their own product (an API key on a sandbox
   account is best). Store it with `storeConnections { connectorId, authMethodId, credentials }`,
   then run each action with `executeConnectorActionBySlug` (read actions first, and ask before any
   write action). If one fails, read the error, fix the action with `updateAction`, and run it again.
7. Summarise: "N actions built and tested: ...".
8. **Register it (this is what completes step 1).** `upsertSaasConnector { connectorId, scopes: [] }`.
   If the product has workspaces or accounts that a customer's connection should be pinned to,
   ask which to use and put them in `scopes`.
9. Confirm with `listSaasConnectors`, then `updateSetupJourney { "step": 2 }`.

## Step 2: the first integration

Goal: one working integration the partner's customers can turn on in the widget.

Before building anything here, load the `integration_builder` skill (`skill {"slug":"integration_builder"}`,
installed as the gateway playbook says) and follow it for the workflow, trigger, field mappings,
acceptance tests and widget, opening its references for the phase you are in. Where it and this list
differ on how to build, it wins; this list only says what step 2 needs to count as done.

1. **Pick a use case.** Use the research (tools their customers use, integration gaps) to suggest
   2-3 concrete ones, e.g. "When an order is created in Acme, post it to the customer's Slack". Recommend one.
   One integration is their product plus ONE other app. If they want several apps, that is several
   integrations, one widget each: decide the split yourself, never ask, and never offer an upgrade.
   `agentSuggestConnectors { useCase }` turns their sentence into catalog connector ids.
   Save the choice: `updateSetupJourney { "useCase": "...", "connectorIds": [...] }`.
2. **Connectors.** Both should already exist: the partner's product (step 1) and the app
   (`listConnectors { slug }`). Do not create or rebuild either. If an action the integration needs
   is missing, add it to the existing connector with `createAction`.
3. **Trigger.** Ask what should start it, and suggest the answer the use case implies:
   - A webhook event from their product: `createWebhookTrigger` (hand the user the `triggerUrl` it
     returns to set in their product), or `createAppEventTrigger` if the connector emits events.
   - On a schedule: put the schedule on the workflow.
4. **App logic.** `createWorkflow { slug, name, code, inputSchema, testInput }`. Test it on sample data
   with `runWorkflowCode` (use `mockMode` until real connections exist), fix it, then `publishWorkflow`.
5. **Connection.** Each customer signs in to their own app account in the widget. Do NOT create a
   connection for them.
6. **Widget (this is what completes step 2).** `createWidget { name, connector_refs or connector_ids, workflow_ids }`
   with the app connector, the product connector when the workflow calls it, and the workflow. A widget
   lists at most 2 connectors on every plan (`whoami.plan.limits.connectorsPerWidget`); a 403
   `quota_exceeded` with `dimension: "connectors_per_widget"` means split into one widget per app.
   Name it for the app (e.g. "Slack"), never for their own product. fastn keeps the registered product
   off the customer's card: a credentials product is connected by their backend (step 3.4), an OAuth one
   is signed in to in the widget's connect step. If the product connector has scopes, set
   `connector_refs[].connectionScope`. Widgets with the same name are reused, so a retry is safe.
7. `updateSetupJourney { "widgetId": "<id>", "step": 3 }`.

## Step 3: embed the widget in their app

Goal: the widget loads on a page of the partner's own app. You can't do the final part yourself;
you give them the code and check for it.

Say what their backend needs (adapt the code to their stack; ask what it is if you don't know):

1. **API key with identity verification.** `createApiKey` is not available as a tool. Ask them to create a
   live key in fastn under Settings, API keys, with identity verification on, and keep the key and
   the identity secret in their backend env (`FASTN_API_KEY`, `FASTN_IDV_SECRET`). Confirm it
   exists with `listApiKeys` (look for a live key with `idvMode` not `off`). Never ask them to paste the secret here.
   Every backend call below sends the key as `x-api-key: <FASTN_API_KEY>` (`Authorization: Bearer <FASTN_API_KEY>`
   also works). Keys start with `fsk_`.
2. **Identity hash**, in their backend:
   ```js
   const crypto = require("crypto");
   function identityHash(customerId, userId) {
     return crypto.createHmac("sha256", process.env.FASTN_IDV_SECRET)
       .update(`${customerId}\n${userId}`).digest("hex");
   }
   ```
3. **Register each customer once** when they sign up: `POST <api>/api/v1/orgs` with
   `{ "name": "<CUSTOMER_NAME>", "orgId": "<CUSTOMER_ID>" }` and their API key.
4. **Connect the customer to the partner's own product** (the step 1 connector), from their backend:
   `POST <api>/api/v1/connections` with the identity headers (`x-org-id`, `x-user-id`, `x-identity-hmac`) and
   `{ connectorId, authMethodId, credentials, name, connectionScope? }`. Get the real `connectorId`,
   `authMethodId` and credential field names from `getConnector` and fill them in for them.
5. **Embed token on each page load**: `POST <api>/api/v1/embed/token` with the API key and identity headers, body `{}`.
6. **The snippet**, on their integrations page:
   ```html
   <iframe src="<api>/api/v1/embed/iframe?token=EMBED_TOKEN" style="width:100%;height:600px;border:none" allow="clipboard-write"></iframe>
   ```
   `<api>` is the fastn API host for their environment. The dashboard's step 3 screen (Embed the widget)
   shows it in its snippets; ask them to copy it from there rather than guessing.

Then: "Open that page in your app once. I'll check." Poll `getSetupJourney` for `widgetLoadedAt`.
A load from fastn's own pages or with no Referer doesn't count; it must be their app's page.
When it shows up: `updateSetupJourney { "step": 4 }`.

To try it before writing backend code, you may create one test customer with `createTenant`
(ask first). Loading the widget through a share link still won't complete this step.

## Step 4: first customer

Goal: a customer turns on the integration.

1. Offer a setup link so a customer (or the partner, acting as a test customer) can connect
   without logging in: `createSetupLink { widgetId, endOrgId or createIfMissing + externalRef, connectionName }`.
   Give them the URL and say it expires (15 minutes by default; `expiresInMinutes` up to 7 days).
2. Check with `listInstallations { widget_id }` for an `active` one in a customer org, or
   `listConnections` for a customer connection to the app (not to their own product).
3. When it shows up: `updateSetupJourney { "status": "completed", "step": 4 }`. Congratulate them
   in one line, and offer next things: a second integration, or watching runs (`listWorkflowExecutions`).

## If the user leaves part-way

Stop wherever they ask. Leave `status` as `in_progress` so the dashboard and the next session
resume at the same step. Before stopping, tell them where they are and what's next.
