# The partner's own iframes — configs and custom pages

Two kinds, both named, versioned and per partner, both returning a `url` and a ready `iframe` tag:

- **Config** — fastn's own screens, restyled. Use it when the request fits the fields below (colours, corners, fonts, logo, title, hidden sections, start screen, layout). Cheapest, and it keeps fastn's screens.
- **Custom page** — a whole UI of the partner's own: their layout, their components, their copy, built on fastn's UI library and hosted by fastn. Use it when the request is beyond what a config sets ("a banner with our logo above a grid of the apps", "only show the HubSpot and Shopify cards side by side", "look like our product"). See CUSTOM PAGES at the end.

If unsure, ask in one line which they want, recommending a config when it covers the request.

## Configs

A partner (the SaaS company) can save how its embedded integrations hub looks as a named **iframe config**: title, logo, theme tokens, which sections show, the screen it opens on, and view options. Every page that loads the config picks up a change on its next load, with no redeploy on the partner's side. Each save is a new version; nothing is ever overwritten.

Use this when the partner asks to change how the hub LOOKS or what it SHOWS: "make it our orange", "rounder corners", "hide insights", "open on the apps list", "put our logo on it", "give me a link to our styled hub". It is not for an integration's behaviour (that is the workflow / config / widget) and not for one widget card's styling inside the Widget Builder.

## Who can use it

Applies to configs and pages alike. Only the partner's own account (owner, admin, developer). A customer inside the embed (`whoami` → `actingAsTenant: true`) has none: the tools answer 403 `EMBED_IFRAME_CONFIG_PARTNER_ONLY` / `EMBED_IFRAME_PAGE_PARTNER_ONLY`. Tell such a caller, in plain words, that the look of the hub is set by their provider. Do not try to work around it.

If the tools are missing from your tool list, the feature is not deployed on this environment yet; say so rather than inventing another way. A 503 `EMBED_IFRAME_CONFIG_STORAGE_UNAVAILABLE` / `EMBED_IFRAME_PAGE_STORAGE_UNAVAILABLE` means storage is not set up on this deployment: report it, do not retry. A 502 `..._STORAGE_ERROR` is a passing storage fault: retry once.

## Tools

| Tool | Use |
|---|---|
| `fastnPlatform__listEmbedIframeConfigs` | Start here: the partner's configs, each with `id`, `name`, `version`, `url`, `iframe`, `snippet` |
| `fastnPlatform__getEmbedIframeConfig` | One config's current document and version |
| `fastnPlatform__createEmbedIframeConfig` | New config (`name` unique per partner, case-insensitive), saved as version 1 |
| `fastnPlatform__updateEmbedIframeConfig` | Change it (merge), rename it, or replace the whole document |
| `fastnPlatform__resetEmbedIframeConfig` | Back to the hub's defaults, as a new version |
| `fastnPlatform__listEmbedIframeConfigVersions` | History, newest first, with notes |
| `fastnPlatform__restoreEmbedIframeConfigVersion` | Undo: copies an old version forward as the newest |
| `fastnPlatform__deleteEmbedIframeConfig` | Deletes the config and every version. Cannot be undone: confirm first, and prefer reset |

## The document

Every field is optional; `{}` is the hub's defaults. Unknown keys are refused (400), so a typo fails loudly.

- `title` (string), `logoUrl` (https only)
- `theme` — colours as CSS strings: `primary`, `primaryForeground`, `background`, `foreground`, `card`, `muted`, `mutedForeground`, `border`; `fontFamily`, `letterSpacing` strings. NUMBERS in px: `fontSize` 8-32, `radius`, `buttonRadius`, `inputRadius` 0-64. `fontWeight` 100-900. `shadowStrength` none / sm / md / lg. Theme text may not contain `< > { } ;`.
- `sections` — show (true) or hide (false), e.g. `{ "insights": false, "ai_chat": false }`
- `view` — the start screen: `hub`, `apps`, `insights`, `alerts`, `installations`, ... (a per-app view also needs `widgetId`)
- `viewOptions` — string map, e.g. `{ "appLayout": "tabs", "installationsLayout": "cards" }`

## How to change one

1. `listEmbedIframeConfigs`. One config: use it. Several: ask which (by name). None: offer to create one, and name it after the product or surface ("Product X Connect").
2. `getEmbedIframeConfig` and note its `version`.
3. Translate the request into the SMALLEST patch: send only what changes. `updateEmbedIframeConfig { id, config: { theme: { primary: "#ea580c" } }, baseVersion: <version you read>, note: "<what the user asked, in their words>" }`. Everything else stays as it was. `null` removes a field, or one key inside `theme` / `sections` / `viewOptions`.
   - Turn colour names into a concrete hex and say which one you picked. "Rounder" is a number (e.g. radius 8 → 16), not a word.
   - Use `replace: true` only when the user asks to start from scratch: it makes your `config` the whole document.
4. A 409 `EMBED_IFRAME_CONFIG_STALE` means someone else saved first. Read it again, reapply the user's change to the new version, and save. Never retry blindly with the old `baseVersion` removed.
5. Report what changed (the fields, before → after), the new version number, and the `url` / `iframe` / `snippet` from the response. The URL does not change when the config changes, so a page already using it needs nothing.

"Undo that" → `listEmbedIframeConfigVersions`, then `restoreEmbedIframeConfigVersion` with the version before yours. "Back to default" → `resetEmbedIframeConfig`.

## Using it on a page

- SDK: `createFastnEmbed({ baseUrl, getToken, configId: "eic_..." })` (the `snippet` field has the full call).
- Plain iframe: the `iframe` field is a ready tag; the partner replaces `EMBED_TOKEN` with an embed token their backend mints per customer, or swaps `&token=EMBED_TOKEN` for `&share=<share link id>`. The config id itself is not a credential and grants nothing.
- Anything the page passes itself (`theme`, `view`, ...) wins over the saved config, key by key. If a user says a change "did not show", check whether their page passes that option itself.
- A config only applies to frames opened with that partner's own tokens or share links.

## CUSTOM PAGES

A page is ONE HTML document, at most 512 KB, hosted by fastn at `/v1/embed/pages/<id>` and opened like the hub (`?share=<share link>` or `?token=<embed token>`, only the partner's own). Before the page's markup fastn injects the frame's session and its UI library as the global `FastnUI`. There is no build step and no JSX: write components with `h` (React.createElement).

`FastnUI` has:
- React: `h`, `Fragment`, `React` (hooks via `React.useState` etc.)
- `mount(selector, () => h(App), { theme, title, sections })` — renders inside the session and the partner's hub theme. Call it once.
- Headless hooks, each returning `{ data, isLoading, error, refetch }`: `useWidgets`, `useWidget`, `useConnectors`, `useConnections`, `useInstallations`, `useWorkflows`, `useWorkflowExecutions`, `useWidgetInsights`, `useHubSettings`, `useConnect` (start a connection), and more.
- Ready-made screens to compose: `ConnectHub` (the whole hub), `AppGrid` / `AppCards` / `AppCard`, `AppPage`, `InsightsView`, `AlertsPanel`, `WorkflowsPanel`, `ActivityPanel`, `InstallationsTable`, `ConnectDialog`, plus primitives (buttons, badges, modals, tabs).

Tools:

| Tool | Use |
|---|---|
| `fastnPlatform__listEmbedIframePages` | The partner's pages, each with `url` and `iframe` |
| `fastnPlatform__createEmbedIframePage` | New page. Omit `html` to start from fastn's default page (the hub on the library), then edit it |
| `fastnPlatform__getEmbedIframePage` | The current `html` and `version` |
| `fastnPlatform__updateEmbedIframePage` | `html` (whole page) OR `edits: [{ find, replace }]` (each `find` must match exactly once), plus `baseVersion` |
| `fastnPlatform__resetEmbedIframePage` | Back to fastn's default page, as a new version |
| `fastnPlatform__listEmbedIframePageVersions` / `fastnPlatform__restoreEmbedIframePageVersion` | History and undo |
| `fastnPlatform__deleteEmbedIframePage` | Deletes it and every version; frames using it then show "not found". Confirm first, prefer reset |

Procedure:
1. `listEmbedIframePages`; if none fits, `createEmbedIframePage` without `html` and build from the default page (it already works, so start from a running page).
2. `getEmbedIframePage`, note `version`.
3. Small change → `edits` with enough surrounding text that each `find` is unique (copy it exactly from the page you read). Large rework → `html`. Always pass `baseVersion`. On `EMBED_IFRAME_PAGE_EDIT_NO_MATCH` read the page again and fix the `find`; on 409 `EMBED_IFRAME_PAGE_STALE` read again and reapply.
4. Report what changed, the version, and the `url` / `iframe` tag. The URL never changes, so frames already using it update on their next load.

Rules the page runs under (the server enforces them; code that breaks them simply fails in the browser):
- Scripts and styles only from fastn plus inline `<script>` / `<style>`. No CDN libraries, no external stylesheets except Google Fonts.
- Network calls only to the fastn API (the hooks do this). It cannot send data to any other host.
- It cannot navigate the partner's top-level page; links to other sites must use `target="_blank"`.
- It runs sandboxed in its own opaque origin: `document.cookie`, `localStorage` and `sessionStorage` throw, and it cannot read into frames of fastn pages. Keep state in React (`React.useState`), never in browser storage.
- Never put a token, key or secret in the page: the session is injected per load.
- A page shows real customer data only through the hooks, scoped to the session's customer. Never hard-code records.