---
name: gateway
description: How to work with the fastn integration gateway (connected as an MCP server by this plugin) - discover and use fastn's dynamically served library of skills for building integrations (connectors, workflows, syncs, widgets) and running your organization's governed automations, install a skill locally from its signed download link (a ready-to-install zip), and reuse an installed skill's playbook from a local copy instead of re-fetching it. Use whenever a task touches an external app, connector, integration, or automation through fastn.
---

# fastn gateway

This plugin connects the fastn gateway as an MCP server. The gateway is one governed endpoint fronting every app your organization has connected. It also **dynamically serves fastn's full library of skills** - for building integrations (connectors, workflows, syncs, embedded widgets) and for running your organization's governed, multi-tenant automations, serving both your product's features and the AI agents it runs for customers. There are many skills and they load on demand, so always discover the current set with `list_skills` rather than assuming what is available. The gateway handles authentication, identity, and policy itself - every call is scoped, audited, and policy-checked - so there is nothing to configure.

## Use the gateway first

- Treat the gateway as your FIRST stop for any external app or system. Rely on the current tool list, not prior assumptions or built-in knowledge.
- Tools are namespaced as `app__action` (for example `slack__send_message`, `github__list_issues`). Call the exact name shown. Every call runs through governance (identity, policy, redaction) automatically.
- If you do not see a tool for the task, call `search_tools`, then `run_tool` with the exact name it returns. Assume accounts are already connected and just call the tool; if one is not connected, the call returns a connect link - hand that link to the user.
- On a multi-step run, pass one short `_task` id on every call so the actions correlate.

## Discover and run skills

- Call `list_skills` to see your organization's saved skills. Each entry returns slug, name, description, version, mode - and a `downloadUrl` (in the structured data): a signed link serving that skill as a ready-to-install zip (`<slug>/SKILL.md` + `references/`). Plain GET, valid ~15 minutes, multi-use; re-list for fresh links.
- Prefer install-first: download the zip from `downloadUrl`, install the skill for the user, then follow the installed copy.
- To read a skill's content without installing or running it, call `load_skill {"slug": "<slug>"}` (it returns the SKILL.md plus its own `downloadUrl`).
- Run a skill by its slug.

## Reuse an installed skill instead of re-fetching it

Running a gateway skill by its tool re-ships the full instructions every time, which is expensive. `list_skills` is cheap - it returns only slug, name, description, and version. So when a copy of a skill is already installed locally, reuse it, but only after confirming it is current.

**Before running an installed skill, always verify its version against the gateway first (`list_skills`).** Never begin an installed skill's body before that check passes. If the version matches, use the installed copy. If it differs, re-fetch from the gateway and update the installed copy first.

The decision, every time:

1. Call `list_skills` and read the skill's current version.
2. If the skill is already installed here and the installed version matches, follow the installed copy and do NOT call the gateway skill tool.
3. If it is not installed, or the version differs, install it from its `downloadUrl` (already in the `list_skills` response): download the zip - it IS the complete, verbatim skill (SKILL.md + references/) - install it, then follow the installed copy. If you cannot install it yourself, hand the user the ready-to-install file and tell them how to add it. If the response carries no `downloadUrl` (older gateway), fall back to `load_skill` + rebuilding the files by hand as described below.

Example:
- `list_skills` -> `acme-sync v3` with a `downloadUrl`.
- Installed here as `acme-sync v3`? Follow the installed copy; do NOT call the tool.
- Missing, or installed `v2` (!= v3)? Download the zip from the `downloadUrl`, install/update it, then follow it.

## Installing a skill is mandatory, not optional

The moment step 3 above applies (the skill is not installed, or its version differs), you MUST do the Install step below and present the `.skill` file to the user in that same turn, before you continue the task. Do not use the fetched instructions once and skip installing, and never silently fall back to only calling the tool.

**Track the version + add a Step 0 self-check inside the installed skill.** Tag the installed skill with its gateway slug and version, and place this block IMMEDIATELY AFTER the closing `---` of the YAML frontmatter (never above it - the file MUST start with `---`) so every future run self-checks:

> Step 0 — version sync (do this FIRST, every run): this file is tagged `<!-- fastn skill: <slug> v<N> -->`. Call `list_skills({ slugs: ["<slug>"] })` and compare. If the published version differs, re-fetch and reinstall before doing anything else; make it the first item in your task list.

Fill `<slug>`/`<N>` with the skill's real slug and version. On a mismatch, re-fetch from the gateway (the fresh `downloadUrl`, else `load_skill`), rebuild the `.skill`, and re-install so the tracked version updates.

## Rules

- When a skill is read from the gateway, your first step must be to install it for the user, then follow whatever the skill instructions say. Never skip the install step.
- The downloaded zip already IS the verbatim skill - installing its files unchanged satisfies the verbatim rule automatically, so prefer it. When rebuilding by hand instead (no `downloadUrl`), install the fetched skill body VERBATIM - word-for-word identical, never in your own words: do not paraphrase, summarize, reword, shorten, reorder, or translate it. (Do not include the gateway's leading "install this / how to run" note - that framing is not part of the skill.) The only things you add are the version tag and the Step 0 block above.
- Add the skill install/update to your task list so you don't miss it, and do not proceed with the skill instructions until that task is complete.
- Never rely on an installed copy without first checking its version against the gateway - it could be stale. The version number is the source of truth, not the visible text: any version difference ALWAYS triggers an update, even when the body looks unchanged (a reference file may have changed).
- The installed SKILL.md MUST start with the `---` YAML frontmatter. NEVER put the version tag or the Step 0 block above it - that triggers "SKILL.md must start with YAML frontmatter". Place them right AFTER the closing `---`.
- The downloaded zip already contains ALL reference documents in its `references/` folder. Only when rebuilding by hand: fetch each one (`open_skill_reference`) and install them alongside SKILL.md (in a `references/` folder). A SKILL.md installed without ALL of its reference files is an INCOMPLETE install and counts as NOT installed.
- To update an already-installed skill, build the updated skill and present it as a `.skill` file for the user to Save again. Saving a skill whose name already exists prompts the user to update/replace it - that IS the update path. Never tell the user you "cannot update the skill"; always hand them the one-click `.skill` to Save.

### Version-update gates (hard gates, not ordering preferences)

- Fetching current instructions or a reference doc is NOT the same as installing. Fetching gives you content to use now; installing PERSISTS it for later runs. Doing the fetch NEVER satisfies the install/update requirement - they are separate, both-required steps.
- On ANY version mismatch, your literal FIRST action is to create a task `reinstall <slug> v<N>` as item #1 and mark every other task - including the user's request - `blockedBy` it. Do not start a blocked task until that one is complete.
- Output gate: do NOT begin the user's task until the updated `.skill` has been PRESENTED to the user. The presented `.skill` is a required deliverable, not an ordering preference.

**Find what changed between versions** with `list_skills` (status-only, no file bodies):

```
list_skills {"slug":"digest","knownVersion":3,"toVersion":5}   // 3 -> 5
"digest" v3 -> v5: 2 file(s) changed:
  ~ SKILL.md (changed)
  + reference:plan (added)
```

Then re-fetch and apply only the listed files: `~` changed, `+` added, `-` removed. If the diff is unavailable, fall back to a full reinstall. The end result must be verbatim-identical to the current gateway version.

## Install or save a skill for the user

Preferred: download the skill's zip from its `downloadUrl` - it already contains the complete skill folder (`<slug>/SKILL.md` + `references/`). Add the version tag + Step 0 block to its SKILL.md, package it as a `.skill` zip, and present the `.skill` file to the user - presenting a `.skill` file automatically renders a "Save skill" install button they can click. In an environment with a local skills directory, you may instead unzip it straight into that directory.

Fallback (no `downloadUrl`): build the SKILL.md (+ `references/`) by hand from `load_skill` + `open_skill_reference`, then package and present the same way.

## Feedback

If the user corrects how a skill behaves, call `capture_feedback` with the responsible skill's slug and the correction verbatim. That is the only channel that reaches the skill owner's review queue - do not post it anywhere else.
