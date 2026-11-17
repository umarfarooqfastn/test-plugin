# Arrange a call with a person at fastn

## When to offer it yourself
Do not wait to be asked. Offer a call, once, in one line, when any of these is true:
- The user asks for a person, a demo, a call, support or sales.
- The same step has failed twice after you followed `setup.md`, or the user says it still does not work.
- The verdict is "does not fit" or "partly fits" and the gap blocks their launch (a missing connector, action, event or piece).
- The answer needs something only fastn can decide or do: pricing, a contract or security review, a custom plan or limit, a change on fastn's side, a bug in fastn.
- You have answered "not checked" or "I cannot confirm this" on the point that matters most to them.
- The user sounds stuck, frustrated or under a deadline.
- The request is outside what the public docs cover.
Say why you are offering: "This needs a person at fastn because …. Shall I request a call for you?" If they say no, carry on and do not push it again.

## What a call request needs
Keep it short: fastn's team reads it as one small message. The user tells you two things only: **what the issue is** and **what they need from fastn**. Everything else you fill in yourself. Never invent a value.

**Who they are comes from fastn, not from the user.** Call `whoami` on the fastn gateway and take `name` from `user.displayName`, `email` from `user.email` and `company` from `org.name`. Do not ask the user to type their name, email or company. If the gateway is not connected you cannot know who they are: do not send a request, use the email fallback at the end of this file.

| Field | What it is | Needed |
| --- | --- | --- |
| `name` | From `whoami`: `user.displayName` | yes, never ask |
| `email` | From `whoami`: `user.email` | yes, never ask |
| `company` | From `whoami`: `org.name` | yes, never ask |
| `category` | Exactly one of `missing_connector`, `missing_feature`, `setup_help`, `bug`, `pricing`, `other`. You pick it from the conversation; do not ask the user to choose | yes |
| `issue` | The problem in one sentence, in their words (at most 240 characters) | yes |
| `connector_needed` | The app they need that is missing or incomplete | when the category is `missing_connector`, or an app is the blocker |
| `feature_needed` | The fastn feature, action or event they need | when something fastn does not do today is the blocker |
| `stuck_at` | The piece or step where they are stuck (for example "Connect your product") | when they are stuck on a step |
| `use_case` | What they are building, one line | if known |
| `urgency` | `high` only if they named a deadline or a blocked launch, else `normal` | optional |
| `source`, `mode` | `fastn-solution-architect`, and `live` or `definitions` | always |

Do not ask for meeting times: fastn replies by email to agree a time. Plain text only: no links, no secrets, no customer data, no passwords or keys. Leave a field out when you have nothing real for it.

## Before sending
1. Show the user the request and ask: "Send this to fastn?" Send only after a clear yes. Tell them it goes with the name and email of their fastn account, so fastn can reply.
2. Check it yourself: the five required fields are filled, `category` is one of the six values, and the email looks valid. The tool answers "accepted" to anything, even a request that is later dropped, so a bad request fails silently.

## Send it
Call the fastn gateway tool **Request a call with fastn** (`fastnPlatform__requestCallWithFastn`, in the Fastn Workspace app) with the fields above. There is no address to call yourself and no key to handle: the request goes through the user's own fastn connection.
- The answer has `status: "accepted"`: tell the user the request was sent and that a person at fastn will reply by email. Do not promise a response time and do not say a meeting is booked.
- The tool is not in your tool list, the gateway is not connected, or the call fails: do not retry more than once. Give the user the same text (category, issue, what they need) to send themselves by email to **support@fastn.ai**, or through **Help (?) → Contact support** in the fastn dashboard.
- Send one request per conversation. If details change, tell the user to reply to fastn's email.

# Log a ticket with fastn

A ticket tells the fastn team that something is missing or wanted. Unlike a call, you send it yourself, without asking the user first, the moment you find a real hole (SKILL.md section 9) or the user asks for something new. The user is then told in one line.

Call the fastn gateway tool **Log a ticket with fastn** (`fastnPlatform__logTicketWithFastn`, in the Fastn Workspace app).

| Field | What it is | Needed |
| --- | --- | --- |
| `type` | Always `ticket` | yes |
| `name`, `email`, `company` | From `whoami`, exactly as for a call. Never ask the user | yes |
| `category` | `missing_connector` (the app is not in the catalog), `missing_feature` (a missing action, event, sign-in method or fastn feature, or a new feature the user asks for), `bug`, or `other` | yes |
| `issue` | What is missing or wanted and what it blocks, one sentence, at most 240 characters | yes |
| `connector_needed` | The app, when an app is involved | when it applies |
| `feature_needed` | The action, event, sign-in method or feature | when it applies |
| `use_case` | What the user is building, one line | if known |
| `alternative` | The other route you are building for now, at most 200 characters | if there is one |
| `urgency` | `high` only when it blocks their launch or they named a deadline | optional |
| `source` | `fastn-solution-architect` | always |

Plain text only: no links, no secrets, no customer data, no passwords or keys. The ticket carries the name and email of the user's fastn account so fastn can reply; say so in the same line that tells them it was logged. The tool answers `status: "accepted"` to anything, so check the six required fields yourself before sending. If the gateway is not connected you cannot send a ticket: tell the user what is missing and point them to **Help (?) → Contact support**.
