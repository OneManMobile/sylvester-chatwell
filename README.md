# Sylvester Chatwell 🎩

Sylvester Chatwell is a household butler for Denmark that lives inside
**xAI's Grok Bot**. Point your Bot at this repository and it installs its own
tools on its cloud computer, interviews you about what your household eats,
plans next week's dinners around the current offers on
[nemlig.com](https://www.nemlig.com), fills your nemlig basket with exact
quantities, and sends meal plans and recipes as phone-sized cards. It runs on
your own Grok account with your own nemlig login — there is no server, no
middleman and no extra subscription.

> **Grok Bot:** if you were asked to set yourself up from this repository,
> follow [BOT.md](BOT.md).

## Set it up in 5 steps (+ bonus)

1. **Get Grok Bot.** Buy a Grok Premium subscription ($30/month, includes
   Grok Bot) at https://x.ai/pricing. Then download the **Grok Bot app** from
   https://x.ai/bot (Mac, Windows, Linux — or "Grok Bot" in the App Store /
   Google Play) and sign in with the same account. The app is where you chat
   with your butler.
2. **Create your butler.** In the app choose **Create your own**, name the Bot
   *Sylvester*, and send:
   > Set yourself up from https://github.com/OneManMobile/sylvester-chatwell — follow BOT.md

   He installs his own tools on his cloud computer. The first time takes a
   few minutes.
3. **Connect nemlig.com.** When setup is done he asks for your nemlig e-mail
   (or write *"Connect nemlig"*) and opens a login page on his computer. Tap
   **Take over**, type your nemlig password on the page, tap **Log in**, then
   **I'm done**. He never sees the password, and it never goes in the chat.
4. **Tell him how you eat.** He asks a few short questions: who's eating, diet
   and allergies, weekly staples, pizza night? (Busy? Answer *"standard"*.)
5. **Ask for next week's meal plan.** For example: *"Make next week's meal
   plan and fill my nemlig basket."* He sends the plan as a card, fills the
   basket and shows you the item list and total. He never places the order —
   you check the basket and tap **Bestil** (Order) on nemlig.com yourself.

**BONUS:** ask for a recipe card for one of the days, e.g. *"Recipe card for
Tuesday."*

## What you get

<p align="center">
  <img src="examples/en/meal-plan.png" alt="Meal-plan card" width="320">
  <img src="examples/en/recipe.png" alt="Recipe card" width="320">
</p>

Danish versions of the same cards, plus a shareable five-step setup card in
both languages, are in [`examples/da/`](examples/da) and
[`examples/en/`](examples/en).

**It can**
- Plan the week's dinners around nemlig.com's current offers, your diet,
  allergies, fixed nights and weekly staples — and avoid repeating itself.
- Fill the nemlig.com basket with exact quantities (whole packs, offers first,
  products you bought before), then show the item list and total as proof.
- Send meal plans, recipes (ingredients, tools and a Cooking-for-Engineers
  step grid) and an optional week overview as images in the chat.
- Remember preferences and feedback ("not so spicy", "make that again") in
  files on your Bot's computer.
- Run on a schedule if you want — e.g. a meal plan every Saturday at 09:00
  (Grok Bot routines; only created when you say yes).
- Reserve a delivery slot when you ask for it.

**It can't / won't**
- Place or pay an order. You always tap **Bestil** on nemlig.com yourself.
- Change your basket without being asked.
- Shop anywhere other than nemlig.com.

## Safety and privacy

- **Never orders.** The tooling has no command to place an order; the Bot is
  also instructed never to try.
- **Your password stays with you and your own Bot computer — never in the
  chat.** You type it yourself on a login page (`bin/nemlig-login`) that runs
  on the Bot's computer; the page hands it straight to the nemlig.com login
  prompt. It is never logged or shown to the model.
  - Without *"Remember me"* only a session cookie is kept (in
    `/workspace/.sylvester/nemlig-cli`, readable only by your account). When
    nemlig.com ends the session after a while, Sylvester opens the page again.
  - With *"Remember me"* the password is stored in a file in that folder, so
    he can log in again by himself — convenient, but it then sits in plain
    text on that computer.
  - Alternative: Grok Bot secrets `NEMLIG_EMAIL` / `NEMLIG_PASSWORD`, if your
    Bot offers them (fully documented for Team Bots only).

  Details in [BOT.md](BOT.md#4-connect-nemligcom-the-user-types-the-password-not-you).
- **The nemlig.com integration is unofficial.** It uses the community
  [Nemlig.com-CLI](https://github.com/tobiasdosdal/Nemlig.com-CLI), which talks
  to the same web API as the website. nemlig.com can change that at any time,
  and then it can break until the CLI is updated. Not affiliated with
  nemlig.com or xAI.
- Household data (preferences, meal log, cards) lives in
  `/workspace/sylvester-household` on your Bot's computer and nowhere else.

## Costs

Grok Premium, which includes Grok Bot: **$30/month** (see
https://x.ai/pricing). Nothing else — this project is free, and the groceries
are whatever you decide to order.

## Languages

Sylvester writes in your language: Danish by default, English when you write
in English or ask for it. The cards come in Danish (`"lang": "da"`) and English
(`"lang": "en"`) — headings, weekday and month names, hyphenation. Product
names stay as nemlig.com spells them.

## Repository layout

```
README.md            this file
BOT.md               the instructions the Grok Bot follows to set itself up
install.sh           idempotent installer (everything goes into .venv/ and .deps/)
bin/doctor           quick health check; tells you to run ./install.sh if needed
bin/recipe-card      renders card specs (JSON) to PNG with headless Chrome
bin/nemlig           the nemlig.com CLI (Nemlig.com-CLI + patches)
bin/nemlig-keepalive checks / renews the nemlig.com login (exit 0/1/3/4)
bin/nemlig-login     one-page login form the user fills in after "Take over"
skills/              Grok Bot skills: onboarding, nemlig-household, recipe-cards, family-week
templates/           household files copied to /workspace/sylvester-household
nemlig-cli-patches/  patches applied to Nemlig.com-CLI (offers list, slot changes)
fonts/               OFL fonts used by the cards
examples/en/         English example cards: meal plan, recipe, setup steps (spec + PNG)
examples/da/         the same examples in Danish
```

## For developers: install and test by hand

Linux (x64/arm64) or macOS, no root needed:

```sh
git clone https://github.com/OneManMobile/sylvester-chatwell
cd sylvester-chatwell
./install.sh                        # uv + Python venv, Node 20+, nemlig CLI, headless Chromium (Linux)
bin/doctor                          # checks everything, incl. the nemlig login
bin/recipe-card examples/en/recipe.json   # → examples/en/recipe.png
bin/nemlig --help
bin/nemlig-login --email you@example.com --foreground   # open the printed URL and log in
```

`install.sh` uses apt only when you are root or have passwordless sudo and
something is missing; otherwise it downloads everything in user space
(including Chromium's libraries via `apt-get download` on Debian/Ubuntu). On
macOS it uses your installed Google Chrome. Paths can be overridden with
`SYLVESTER_STATE` (login dir parent), `SYLVESTER_HOUSEHOLD` and
`RECIPE_CARD_CHROME`.

## Credits

- [Nemlig.com-CLI](https://github.com/tobiasdosdal/Nemlig.com-CLI) by
  tobiasdosdal (MIT) — the nemlig.com integration; this repo adds two small
  patches.
- Fonts in `fonts/` are licensed under the SIL Open Font License (see the
  `OFL.txt` next to each font).
- Card layout inspired by [Cooking For Engineers](https://www.cookingforengineers.com).

## License

MIT — see [LICENSE](LICENSE).
