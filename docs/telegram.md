# Family chat on Telegram (optional)

## Why, and what you get

Sylvester normally lives in the Grok Bot app on one person's phone. With this
optional add-on the whole household can talk to him on **Telegram** — your
partner, older kids, or everyone at once in a family group:

- *"@Sylvester what's for dinner tonight?"* in the family group
- your partner asks for the recipe card for Thursday in a private chat
- a child wishes for tacos next week (he notes it for the next meal plan)
- an adult asks him to add milk to the nemlig basket

He answers by name, remembers each person's likes and dislikes, and sends
cards as pictures. Children can ask and wish, but can't change the basket or
settings. Nobody he doesn't know gets an answer until you approve them.

**The honest part:** Grok Bot has no built-in Telegram connection, so
Sylvester checks Telegram on a schedule (a Grok Bot *routine*, every 5
minutes). Replies arrive within about **5 minutes**, not instantly. Each check
uses a little of your Grok subscription's usage — a shorter time window (say
07:00–22:00) means less usage.

## Set it up (about 5 minutes)

1. **Create a Telegram bot.** In Telegram, open a chat with **@BotFather**
   (the official one, with the blue check), send `/newbot`, pick a display
   name (e.g. *Sylvester*) and a username that ends in `bot` (e.g.
   `smith_family_butler_bot`). BotFather replies with a **token** — a long line
   like `123456789:ABC…`. Copy it, but **don't paste it into the Grok Bot
   chat**.
2. **Tell Sylvester.** In the Grok Bot app write: *"Connect Telegram."* He
   explains the 5-minute delay and opens a small page on his computer.
3. **Paste the token.** Tap **Take over**, paste the token, tap **Connect**,
   then **I'm done**. The page checks it with Telegram and shows your bot's
   name and a `t.me/…` link.
4. **Say hello.** Open that link on your phone and send `/start`. Sylvester
   sees a new person and asks you in the Grok Bot app whether it's you — say
   yes. You're now the *owner*.
5. **Turn on the schedule.** He offers to check Telegram every 5 minutes
   between 07:00 and 22:00. Say yes (or ask for other hours).
6. **Add your family** (below) — and you're done.

## Add your partner and kids

Send them the bot's `t.me/…` link. When they send `/start` (or any message),
Sylvester asks you in the Grok Bot app: *"Mette (id …) wrote to Sylvester on
Telegram — should she have access? Adult or child?"* Answer there.

- **Adult:** everything you can do — meal plans, recipes, filling the basket.
  He still never orders or pays; someone taps **Bestil** on nemlig.com.
- **Child:** recipes, meal plans, cards and wishes — no basket changes, no
  delivery slots, no settings.

Until you approve someone, their messages are kept aside and never answered.

## Add a family group

Add the bot to your family's Telegram group (group → *Add members* → search
the bot's username). Sylvester asks you in the Grok Bot app whether he should
answer there. In the group he only replies when someone mentions him
(`@your_bot`), replies to one of his messages, or clearly asks him something.

Leave BotFather's **privacy mode on** (the default, recommended): the bot then
only sees messages that mention it, replies to it and commands — not the
family's other chatter.

If you have a weekly meal-plan routine, ask Sylvester to post the card in the
family group as well.

## Remove someone

In the Grok Bot app: *"Remove Mette from Telegram."* He stops answering her
(or a group) and ignores further messages. Approvals and removals only count
when they come from you in the Grok Bot app — never from a Telegram message.

## Pause or stop

- **Pause:** pause the Telegram routine in the Grok Bot app (or ask Sylvester
  to). Messages sent meanwhile wait at Telegram for about 24 hours.
- **Stop for good:** delete the routine, and in @BotFather send `/deletebot`
  (or `/revoke` to invalidate the token).

## Privacy

- Messages your family sends to the bot are processed by **your** Grok Bot,
  just like your own chats with Sylvester. Photos and documents they send are
  saved in the household folder on your Bot's computer.
- The bot token is stored **only on your Bot's computer** (a file only that
  account can read). It never goes in the chat or to the model, and there is
  no server or relay in between — your Bot talks directly to Telegram.
- Telegram itself carries the messages (bot chats aren't end-to-end
  encrypted), so treat it like any normal Telegram chat.
