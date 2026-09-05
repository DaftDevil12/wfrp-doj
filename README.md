# wfrp-doj

*by wfrp @rick*

A DOJ duty + courtroom resource for **RedM** running the **VORP** framework, with NUI menus styled as period-correct 1899 legal documents.

## Features

- **`/dutybook`** opens a leather-bound DOJ Duty Book
  - Sign in / sign out (toggle duty)
  - Live roster of everyone on duty
  - Boss grades see a "Kick" button on roster entries to force others off duty
- **`/judge`** drops a "Strike Gavel" prompt at the judge (canJudge grades only, inside a courtroom)
  - Pressing the prompt plays the gavel for everyone inside the courtroom; the prompt is removed if the judge steps more than 2.0m from the spot
- **Courthouse blip + NPC** — interacting with the clerk opens the Duty Book
- **On-duty HUD** showing rank and elapsed time
- **Configurable grades** with per-grade salary, boss flag, and judge flag
- **Wages bank in the Duty Book** — salary accrues while on duty, pays out in one lump on sign-off, and survives crashes (held wages are paid on next login)
- **Lawyer alerts** — a register of lawyers (by character, no DOJ job needed) who receive `/lawyeralert` requests from any player and review them in `/lawyermenu`, with a one-click map "Locate"
- **Lawyer billing & ledger** — lawyers issue bills with `/lawyerbill` (player id, amount, reason); the recipient accepts (paid on the spot, even into debt) or denies. Collected funds bank in the lawyer's **ledger** — a separate menu opened from a world prompt — to withdraw later
- **Discord webhook logging** for duty changes, kicks, and all lawyer activity (hires, fires, bills, ledger)

## Requirements

- RedM server with the **VORP** framework
- `vorp_core` must start before this resource
- `oxmysql` (already a VORP dependency) — the lawyer register is stored in MySQL

## Install

1. Drop the `wfrp-doj` folder into your `resources/` directory.
2. Add `ensure wfrp-doj` to `server.cfg` (after `vorp_core`).
3. Register the `doj` job in your VORP jobs table with grades matching `Config.Grades` (0-5 by default).
4. **Download the gavel sound:** visit <https://www.myinstants.com/en/instant/gavel-1-78972/>, click *Download MP3*, save the file into `wfrp-doj/ui/sounds/` and rename it to `gavel.mp3`. (If you skip this, the resource still works — it falls back to a synthesized gavel sound.)
5. Edit `config.lua`:
   - Set `Config.Courthouse.blip.coords` and `Config.Courthouse.npc.coords` to your courthouse.
   - Set `Config.Courtrooms` with each courtroom's center coord and radius.
   - Adjust grade labels / salaries / `isBoss` / `canJudge` flags.
   - Optionally fill in Discord webhook URLs.

## Commands

| Command              | Who         | Does                                              |
|----------------------|-------------|---------------------------------------------------|
| `/dutybook`          | Any DOJ     | Duty Book (toggle duty, view + kick roster)       |
| `/judge`             | `canJudge`  | Drops a Strike-Gavel prompt at you (must be in a courtroom)  |
| `/lawyeralert [msg]` | Anyone      | Request a lawyer; sends your name, message + location |
| `/lawyermenu`        | Lawyers     | List recent lawyer alerts; "Locate" drops a map blip |
| `/lawyerbill`        | Lawyers     | Open the bill form (issue a bill to a player)      |
| `/lawyerhire [id]`   | DOJ bosses  | Register online player `[id]` as a lawyer         |
| `/lawyerfire [id]`   | DOJ bosses  | Remove a lawyer (online server id, or character id) |

The courthouse NPC also opens the Duty Book on interact. All command names are configurable (`Config.Commands`, `Config.Lawyers`). `/lawyerbill` opens the **bill form**; the **ledger** is a separate menu opened from a world prompt at `Config.Lawyers.menuLocations`.

## Permissions

Two per-grade flags in `Config.Grades`:

| Flag        | Grants                                              |
|-------------|-----------------------------------------------------|
| `isBoss`    | Can kick others off duty via the Duty Book roster   |
| `canJudge`  | Can open `/judge` and strike the gavel              |

By default: DA / Judge / Chief Justice are bosses; Judge / Chief Justice can judge.

Lawyers are a **separate register**, not a grade. DOJ **bosses** (and the server console) hire/dismiss them with `/lawyerhire` / `/lawyerfire`. On-duty DOJ members also count as lawyers while `Config.Lawyers.includeOnDutyDoj` is `true`.

## Notes

- `/judge` drops a "Strike Gavel" world prompt at the judge's position (no NUI). It only appears for `canJudge` grades inside a `Config.Courtrooms` zone, and is removed if they move more than 2.0m from where they ran `/judge`. The gavel only plays for players inside that courtroom. The server re-checks duty + `canJudge` before broadcasting.
- The gavel uses `ui/sounds/gavel.mp3` if present. If missing, the NUI falls back to a synthesized gavel via the Web Audio API — no broken sound, just a different one.
- To use a different file format, edit `GAVEL_URL` near the top of `ui/app.js` (e.g. `'sounds/gavel.ogg'`).
- The Duty Book is laid out as an open two-page spread: left page is your own status and sign-in button, right page is the live roster.
- **Wages accrue into the duty book** while on duty (recorded every `Config.SalaryInterval` minutes) and are paid into the player's wallet in one lump only when they go **off duty**. Payout uses `character.addCurrency(0, amount)` (cash) — change the first arg for gold (1) or rol (2).
- If a player **crashes or disconnects while on duty**, their held wages stay in the book (persisted to `pending_pay.json`) and are paid out automatically the next time their character loads in. The same settle-up runs for connected players if the resource itself is restarted, so earned pay is never lost to a restart.
- Held wages are shown live on the Duty Book's left page.
- Fractional per-minute salaries are supported; held balances are rounded to the nearest cent.
- If a player disconnects while on duty, an off-duty webhook log is written and the roster updates for everyone watching.
- **Discord logging:** set the webhook URLs in `Config.Webhooks` — `duty`, `kick`, and `lawyer`. The `lawyer` channel receives hires, fires, bills (issued / paid / denied / expired), and ledger withdrawals, each as a colour-coded embed. Any URL left empty is silently skipped.
- **Lawyers** receive each `/lawyeralert` as an on-screen objective notification, and can open `/lawyermenu` to review the most recent `Config.Lawyers.maxStoredAlerts` alerts (sender, message, time). Clicking **Locate** drops a temporary map blip where the caller sent it from (lasts `Config.Lawyers.locateBlipTime` seconds).
- The lawyer register is stored in the MySQL table **`doj_lawyers`** (created automatically on start, keyed by character id). If a legacy `lawyers.json` is found it is imported once, backed up to `lawyers.json.bak`, then no longer used. `/lawyeralert` has a per-player cooldown (`Config.Lawyers.alertCooldown`); the recent-alert list is kept in memory.
- **Billing & ledger are two separate menus.** `/lawyerbill` opens the **bill form** (player id, amount, reason); the recipient gets an accept/deny prompt and, on accept, is charged immediately via `removeCurrency` — **even into negative cash, by design**. Collected funds bank in the billing lawyer's **ledger** — a separate NUI opened from the world prompt at `Config.Lawyers.menuLocations` (lawyers only), backed by the MySQL table `doj_lawyer_ledger` (keyed by character id) — from which they may **withdraw to their wallet but never deposit**. `Config.Lawyers.maxBill` caps a single bill (0 = no limit); unanswered bills expire after `billTimeout` seconds.

## File layout

```
wfrp-doj/
├── fxmanifest.lua
├── config.lua
├── README.md
├── pending_pay.json    (auto-generated — held wages; safe to delete when empty)
├── sql/
│   └── doj_lawyers.sql (reference schema for both lawyer tables; auto-create on start)
├── locales/en.lua
├── shared/utils.lua
├── client/
│   ├── main.lua        state + notify
│   ├── duty.lua        blip + NPC + prompt
│   ├── hud.lua         on-duty HUD
│   ├── courtroom.lua   zone detection + broadcast receivers
│   ├── nui.lua         commands + NUI callbacks
│   └── lawyer.lua      /lawyeralert + /lawyermenu + locate blip
├── server/
│   ├── main.lua        duty state, requests, kick, gavel, salary
│   ├── webhooks.lua    Discord logging
│   └── lawyer.lua      lawyer register + alert broadcasting
└── ui/
    ├── index.html      Judge / Duty Book / Lawyer menu
    ├── style.css       1899 legal-document aesthetic
    ├── app.js          menu controllers + Lua bridge + gavel audio
    └── sounds/
        ├── README.txt   how to install the gavel sound
        └── gavel.mp3    (you provide this)
```
