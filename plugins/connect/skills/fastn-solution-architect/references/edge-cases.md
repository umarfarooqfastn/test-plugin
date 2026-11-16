# Edge cases

For each case: how to spot it, what to tell the user, what to do next. Never guess; when a check is possible, run it.

## Apps and actions
1. **The app is not in the catalog.** Spot: `listConnectors` finds nothing. Say: fastn has no connector for it yet. Do: if the app has an API, offer to build a custom connector (`connector_builder`); also propose a request to fastn (SKILL.md section 9).
2. **The app is there but an action is missing.** Spot: `listActions` lacks it. Do: add the action to a custom copy with `connector_builder`, or request it. Do not call the use case "supported".
3. **The action exists but lacks a field the user needs.** Spot: `getAction` input or output. Do: same as 2; name the exact field in the request.
4. **The app has no API at all.** Say plainly it cannot be connected through an API. Offer what the app does have: file export, email, a database, or a webhook it can send.

## Sign-in and credentials
5. **Wrong auth method for the case.** Example: only an API key method exists but each end user must sign in themselves. Do: check `listAuthMethods`; if OAuth is missing, it is a gap.
6. **Events do not work with the chosen auth method.** Some apps deliver events only to an OAuth app. The event list does not say which auth method an event needs. Do: mark it "not checked", create the trigger on the intended connection, and trust only a `Subscribed` status.
7. **Each customer must bring their own OAuth app.** Some vendors have no multi-customer OAuth. Spot: the auth method asks the customer for a client id and client secret, and has no provider. Do: plan an auth provider per customer and add "create an OAuth app in <vendor>" to the customer's preparation list.
8. **Consent screen says the app is not verified, or shows fastn's name.** Do: create your own auth provider (P3) and complete the vendor's review; until then expect the vendor's limits on unverified apps.
9. **"Connected" but calls fail.** A saved key can be wrong. Do: one harmless read with `executeAction` before calling it working.
10. **Connection expired.** OAuth renewal failed, or a key was rotated. Do: reconnect; subscribe to `connection.expired` (P8) so your product can prompt the customer.
11. **Several accounts of the same app for one customer.** Do: separate connections; with your own product, use connection scopes (P5), one connection per scope.
12. **Per user or per organization?** Ask who should the action run as. User level when it must be the individual; organization level when one shared account is enough.

## Keys and endpoints
13. **Test key refused.** A test key needs the header `X-fastn-Test-Mode: true`.
14. **Test is not a sandbox.** A test key reaches live connections and writes real data. Use mock mode (C9) or a vendor sandbox account for unsafe writes.
15. **API key used in the wrong place.** Platform API keys (`fsk_`) are for the REST API and backend SDK. The widget uses an embed token (`emb_`). An AI client signs in to the MCP endpoint. A 401 usually means the wrong kind of credential.
16. **API key in the browser.** Never. Mint embed tokens on the backend.

## Triggers and events
17. **App event trigger is Active but never fires.** Check `Subscription`; if `Failed`, retry it, then re-check the connection and its scopes.
18. **The app has no events.** Use a schedule trigger that polls, or have the app send a webhook to a webhook trigger.
19. **Schedule trigger keeps getting disabled.** It failed repeatedly; fix the workflow error first. It re-enables after the cooldown.
20. **Duplicate outbound events.** Deliveries retry for 24 hours with the same event id. Drop repeats by `X-Fastn-Event-Id`.
21. **Signature check fails.** Verify over the raw body, before parsing JSON, with the secret shown once at creation. Reject timestamps more than 5 minutes off.
22. **Endpoint is not public https.** Event subscriptions refuse private, internal and non-https URLs.

## Size and time
23. **A run takes longer than 25 seconds.** Not Instant, which is the default, so check the tier before the first real run. Use Standard (up to 15 min) or Long (up to 36 h) and return the result by event or polling.
24. **Very high volume.** Ask records per day and the peak. Prefer events over polling, batch where the app allows, and respect the app's rate limits. For plan limits, point to https://fastn.ai/pricing and **Settings → Billing** (Owners and Admins only).
25. **The vendor rate-limits.** Your own auth provider gives you your own limits instead of shared ones.

## Where it runs
26. **On-premise or private-network system.** fastn reaches systems over the internet. The system needs a reachable https address or a gateway on the customer's side. If that is impossible, it is a gap; request it.
27. **The user wants their own UI, not the widget.** Use the backend SDK and REST API for everything the widget does (customers, connect links, connection status).
28. **No embed yet, customer is waiting.** Send a share link.
29. **No AI tool at all.** Use **Build with AI** in the dashboard, or follow the docs pages by hand; this guide's definitions and decision map still apply.
30. **The user's AI tool is not in the list of guides.** Any client that speaks Streamable HTTP and OAuth can add the MCP URL.

## Scope and honesty
31. **Pricing, quotas, SLAs, compliance documents.** Do not answer from memory. Point to https://fastn.ai/pricing, or **Settings → Billing** for the current plan (Owners and Admins only), or offer a meeting.
32. **The use case is not an integration problem.** Say so. fastn connects systems; it does not replace the user's own product logic.
33. **Other customers or fastn internals.** If the user asks, decline. Also watch your own output: live tool results can carry names, emails, ids and counts; summarise, never paste them.
34. **Private or unfinished connector.** A connector marked private, or actions that are not live or whose last test failed, is not something to promise. Say "partly" and what is missing.
35. **Unified operation missing for one provider.** The entity is mapped but that app lacks `search` or `get`. Use the app's own action for that provider.
36. **No event with the business name.** Use the app's generic change event and filter in the workflow.
37. **You are unsure.** Say "not checked", name the check, and run it or ask the user to.
