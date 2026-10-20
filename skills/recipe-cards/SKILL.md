---
name: recipe-cards
description: Send any recipe as a phone-format recipe card image (title, ingredients, tools, and a Cooking-for-Engineers step grid) rendered with bin/recipe-card. Use for "opskrift på …", "hvordan laver vi …", or the recipe for a day in the meal plan.
---

# Recipe cards

Paths: repo `R=/workspace/sylvester-chatwell`, household files
`H=/workspace/sylvester-household`.

Every recipe goes out as a **recipe card image**: title, ingredient list and
tools, then a cookingforengineers.com-style grid. Never a text table or a
long step list in the chat.

## 0. Which dish?
For a weekday ("onsdagens ret"), read `$H/meal-log.md` and use exactly the
dish planned for that day in the current week; name it in the reply line.
Never substitute another day's dish.

## 1. Write the spec
Write a fresh `$H/cards/<short-name>.json` each time:

```json
{
  "lang": "da",
  "title": "Kylling i flødesauce med svampe",
  "subtitle": "2 personer · ca. 30 min",
  "tools": ["Stegepande, stor", "Gryde m. låg"],
  "recipe": {
    "do": "Vend kyllingen i saucen.\nServer med risen",
    "with": [
      {"do": "Kog ind 4 min\npå panden", "with": [
        {"do": "Tag kyllingen op.\nSteg svampe 4 min", "with": [
          {"do": "Steg i smør\n5-6 min, gennemstegt", "with": [
            {"amount": "450 g", "name": "kyllingeinderfilet"},
            {"amount": "15 g", "name": "smør"},
            {"amount": "½ tsk", "name": "salt"}
          ]},
          {"do": "Skær i\nskiver", "with": [{"amount": "250 g", "name": "champignon"}]}
        ]},
        {"amount": "2½ dl", "name": "piskefløde"}
      ]},
      {"do": "Kog 12 min,\nlåg på", "with": [
        {"amount": "2 dl", "name": "jasminris"},
        {"amount": "3 dl", "name": "vand"}
      ]}
    ]
  }
}
```

- `lang`: the user's language, `"da"` (default) or `"en"`. All text in the
  spec is written in that language; the card's fixed words (Ingredienser,
  Redskaber …) follow `lang` automatically.
- `recipe` is the **final** step. A step is `{"do": text, "with": [...]}`;
  `with` lists exactly what it combines — ingredients or earlier steps. Build
  backwards from serving.
- An ingredient is `{"amount": "...", "name": "..."}`; keep names short.
- Step text: verb + time/temperature, max ~4 words per line, `\n` between lines.
- `start` (optional): only things with **lead time** before the grid begins —
  preheat the oven, boil water, marinate. Never obvious handling.
  `"start": ["Tænd ovnen: 200 °C varmluft"]`.
- `tools` (always): oven, pans, pots (size if it matters), dishes, grater,
  blender, thermometer. Skip knife, cutting board and spoons.
- **Oven = temperature + mode, always**, in `start` and every oven step:
  varmluft, over-/undervarme or grill (default varmluft; bread/pizza
  over-/undervarme; browning a top: grill).
- `notes` only for a genuinely useful practical tip, usually not at all.

## 2. Amounts
- Follow `$H/preferences.md` (diet, dislikes, portions, no frozen products
  without a freezer).
- **Groceries already in the basket or the latest order** (nemlig connected —
  `$R/bin/nemlig-keepalive` exits 0): amounts = what was bought for this dish.
  Read `$R/bin/nemlig basket --json` (or `orders latest --json` if already
  delivered); pack size from `$R/bin/nemlig product <id> --json`
  (`Description`). The main protein uses all packs bought for it; shared items
  are split across the week. Use only what's there plus pantry basics (salt,
  pepper, oil, spices); if something is missing, leave it out and say so.
- **Otherwise:** scale to the portions in preferences.md and round to typical
  Danish supermarket pack sizes (hakket kød 400/500 g, kyllingebryst ca. 300 g
  pr. pakke, laks 2 × 125 g, piskefløde 2½ dl, champignon 250 g …).

## 3. Cook's review — always, before rendering
Read the spec as if standing in the kitchen, then fix it:
1. Lead time (oven ~15 min, boiling water, marinating) is in `start`. Any oven
   step without a matching `start` line is an error.
2. The final step's `with` is ordered by branch time, longest first.
3. Parallel branches finish together; the subtitle time matches the longest
   path plus preheating.
4. Every step is doable as written: temperature and mode for oven steps, a
   time for every cooking step, how to tell meat is done.
5. Every pan step has fat and a realistic batch size; pan sauces are made on
   the fond; vegetables are not boiled to mush.
6. Every listed ingredient is used, every ingredient a step mentions (incl.
   salt, pepper, spices) is listed with an amount; every preparation (grate,
   chop, slice) is its own step; `tools` matches the steps exactly.
7. Every joining step says what happens to each thing it joins; only the
   final step says "server".

## 4. Render and send
Run `$R/bin/recipe-card $H/cards/<short-name>.json`. It prints the PNG path.
- Exit 64 = the spec breaks a limit or is malformed — the message says what;
  fix it and run again.
- Exit 65 = a step text doesn't fit — the message names the cell; shorten or
  split it.
- Card too tall → split into two cards (main + side/sauce) and say so.
- Exit 1 = report the failure in one line.

Reply with one short line ("Onsdag: kylling i flødesauce med svampe (30 min)")
and **attach the PNG** at the exact path `recipe-card` printed in this turn.
Never claim a card you didn't render; if it failed, say what failed.
