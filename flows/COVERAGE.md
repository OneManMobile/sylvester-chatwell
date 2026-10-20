# What the setup actually covers

Status of every test in the `*.qa.flow` files, as of 2026-10-20.

Two questions per test:
- **Built?** Is the behaviour implemented: tools in `bin/`, instructions in `BOT.md` / `skills/`.
- **Proven?** What has actually been run. Levels: **stub** = scripts run against fake nemlig/Telegram;
  **docker** = install and render in clean Linux containers; **live (other runtime)** = the same tools
  and skills used for real by Andreas' own Sylvester (OpenClaw, then Grok Build CLI) with a real nemlig
  account; **Grok Bot** = run in the Grok Bot app as a new user would.

**Nothing has been run in the Grok Bot app yet.** Every "Grok Bot" cell is open until someone walks the
flows there. Grok Bot behaviour itself (following BOT.md, saving skills, Take over, routines) is only
known from xAI's docs.

| Flow → test | Built? | Proven? | Open risk |
|---|---|---|---|
| **setup** · Buy Premium + install app | n/a (xAI) | — | Legacy Privacy Mode blocks Grok Bot (hit by Andreas) |
| setup · Create Bot, point at repo | yes | docker (install + doctor, x64/arm64, root/non-root) | Bot may not follow BOT.md fully; skill-saving wording untested |
| setup · Setup fails | yes (BOT.md) | — | |
| setup · Computer recreated → reinstall | yes | docker (re-run install) | |
| setup · "opdater dig" | yes (BOT.md) | — | |
| **connect-nemlig** · Happy path | yes (`bin/nemlig-login`) | stub (mac + Linux) | **Can the Bot's browser open `http://127.0.0.1:…` on its own computer?** Can a phone user type in Take over? |
| connect-nemlig · Wrong password / 5 attempts | yes | stub | |
| connect-nemlig · Password pasted in chat | yes (rules) | — | |
| connect-nemlig · Skip nemlig | yes (skills) | — | |
| connect-nemlig · Expiry, remembered | yes (`nemlig-keepalive`) | stub | |
| connect-nemlig · Expiry, not remembered | yes | stub (exit 3) | |
| connect-nemlig · Password changed | yes | stub (exit 1) | |
| **household-preferences** · Interview / "standard" | yes (onboarding skill) | — | |
| household-preferences · Later preference / feedback | yes (skills) | live (other runtime) | |
| household-preferences · Remembered across conversations | yes (files) | live (other runtime) | |
| **meal-plan-and-basket** · Plan on offers → card | yes | live (other runtime); cards: docker + mac renders | |
| meal-plan · Swap a day | yes | live (other runtime) | |
| meal-plan · Plan without nemlig | yes | — | |
| meal-plan · Fill basket + proof + link | yes | live (other runtime) | nemlig's private API can change at any time |
| meal-plan · Existing items kept | yes ("never remove lines the user put there") | — | |
| meal-plan · Unavailable product → substitute named | yes | — | |
| meal-plan · Asked to order/pay | yes (no command exists + rules) | — | |
| meal-plan · Delivery slot | yes (patched CLI) | live (other runtime) | |
| meal-plan · Saturday routine | yes (offered in BOT.md) | — | Grok Bot routine creation untested |
| **recipe-card** · Planned day / English / ad-hoc | yes | docker + mac renders (da + en) | Realistic cooking times depend on the model (the example card was wrong twice before review) |
| recipe-card · Render fails → text fallback | partial (says what failed; text fallback only spelled out for meal plans) | — | |
| **family-chat-telegram** · Connect token (Take over page) | yes (`bin/telegram-connect`) | stub | same 127.0.0.1 risk as nemlig |
| family-chat · Instant, event-driven answers | **no** | — | **Current build polls Telegram from a 5-minute schedule. That is wrong for a chat.** Needs: Grok Bot webhook-triggered routine + a small relay (Telegram can't send the routine's Bearer key) |
| family-chat · Owner/partner/child approval, roles | yes (`bin/telegram allow/deny`, telegram skill) | stub | |
| family-chat · Strangers ignored | yes | stub | |
| family-chat · Group: answers only when addressed | yes (skill + BotFather privacy mode) | stub | |
| family-chat · Child can't fill basket | yes (skill rule) | — | Rule-based, not enforced by tooling |
| family-chat · Photos / voice | yes | stub | |
| family-chat · Weekly plan to group | yes (BOT.md) | — | |
| family-chat · Remove person / switch off | yes | stub (deny) | |
| **guardrails** · Never orders | yes (no tool can) | by construction | |
| guardrails · Secrets never shown | yes (rules, files mode 600, forms) | stub | |
| guardrails · Proof before done | yes (rules) | live (other runtime) | |
| guardrails · Injected instructions ignored | yes (rules) | — | Rule-based only |

## The three gaps that matter

1. **Telegram must be event-driven.** Replace the 5-minute poll with: Telegram webhook → relay →
   Grok Bot routine webhook (one run per message) → reply. Decide the relay (free Cloudflare Worker is
   the simplest always-on option) before building.
2. **One real run in the Grok Bot app.** Walk `setup`, `connect-nemlig`, `household-preferences`,
   `meal-plan-and-basket` and `recipe-card` once with a real account. The 127.0.0.1 login page is the
   biggest unknown.
3. **Recipe quality.** Cooking times and methods come from the model. A recipe check belongs in the
   recipe-cards skill (realistic times, method sanity) and in this flow.
