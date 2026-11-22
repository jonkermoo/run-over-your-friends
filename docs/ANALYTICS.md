# Analytics

Everything the game sends to Roblox analytics (Creator Hub > your experience > Analytics). The code is
`src/server/Analytics.luau` (server), `src/client/Track.luau` (client facts sent on Net `Track`),
`src/shared/Rules/Analytics.luau` (pure rules, tested in `tests/analytics.luau`) and
`src/shared/Config/Analytics.luau` (buckets, rate limit, idle and wreck seconds).

Rules the events follow:

- Event names are fixed, and every field value comes from a small fixed set (ids from Config, or a bucket).
  No user ids, names or free text. The client can only send values from the lists in `Config/Analytics`;
  the server checks each one and rate-limits `Track` (`TrackBurst`, `TrackPerSecond`).
- Custom field 01 and 02 differ per event (below). **Custom field 03 is always the device**:
  `Phone`, `Tablet`, `PC`, `Console` or `Unknown` (Unknown until the client reports, or if it never does).
- In Studio every custom event is also printed to the output as `[analytics] Name value=... f1=... f2=...`.
- Analytics calls are wrapped in `pcall`; a failure only warns.

Item names in the purchase events: `Product:<key>` (Robux products in `Config/Products`: `Cash1`..`Cash4`,
`Starter`, `StarterDeal`), `Pass:<name>` (game passes in `Config/Economy`: `Roadster`, `DoubleMoney`, `VIP`),
`Car:<vehicle id>` (vehicles bought with game money, `Config/Vehicles`), `Section:<DEALS|MONEY|PASSES|FREE>`
(store sections scrolled into view).

"Where" (field 02 on purchases) is what led to the purchase: `Store`, `Garage` (the last sheet opened),
`Starter` (the Starter Pack card's VIEW OFFER), `Upsell` (the "can't afford it" card), or `Other`.

## Custom events

| Event | Value | Field 01 | Field 02 | Answers |
|---|---|---|---|---|
| `StoreOpened` | 1 | `Store` / `Garage` | | How many players open the store and the garage, per device. |
| `ItemViewed` | 1 | `Car:<id>` or `Section:<name>` | `Store` / `Garage` | Which cars and store sections players look at (once per item per session). |
| `PurchasePrompted` | 1 | item | where | How often a Robux purchase prompt is shown, per item and where it came from. |
| `PurchaseBought` | 1 (cars: price) | item | where | What gets bought. Robux items from the prompt's answer (`PromptProductPurchaseFinished`, `PromptGamePassPurchaseFinished`); cars when bought with game money. |
| `PurchaseCancelled` | 1 | item | where | Prompts closed without buying: the drop-off at the last step, per item. |
| `OfferPopup` | 1 | `Starter` / `Upsell` | `Shown` / `Pressed` | The Starter Pack and "can't afford it" cards: shown, then its buy button pressed. Bought shows as `PurchaseBought` with where `Starter` / `Upsell`. |
| `PlayerJoined` | players in the server | players bucket (`1`, `2`, `3-4`, `5-8`, `9+`) | | How full servers are when players arrive. Sent once the client reports its device (or after `ReadyWaitSeconds`). |
| `PlayerLeft` | session minutes | players bucket at leave | minutes bucket (`0-2`, `2-5`, `5-15`, `15-30`, `30-60`, `60+`) | Do players in near-empty servers quit fast? Compare minutes buckets across player buckets. |
| `LeftWhile` | session minutes | `Driving` / `Menu` / `Idle` / `Wrecked` / `OnFoot` | minutes bucket | What players were doing when they quit. `Wrecked`: another player's car flung them in the last `WreckedSeconds`; `Menu`: a menu or card was open; `Idle`: no input for `IdleSeconds`. |
| `LoadTime` | seconds | seconds bucket (`0-5`, `5-10`, `10-20`, `20-40`, `40+`) | `Ready` / `Timeout` | Load time per device: from client start to spawn-ready (the loading cover's ready check). `Timeout`: the cover gave up waiting. |
| `FirstVehicleBought` | total minutes played | vehicle id | total minutes bucket (`0-10`, `10-30`, `30-60`, `60-120`, `120-240`, `240+`) | The money curve: how long until players afford their first car beyond the starter, and which car it is. Logged on the first car bought with game money; cars from the Roadster pass or the Starter Pack don't count as bought. Minutes count all sessions (saved as `playSeconds` in the profile from this release on). |
| `GoalClaimed` | 1 | goal kind (`Hits`, `Earn`, `Drive`, ...) | `Hourly` / `Daily` | Which goals players finish. |
| `ChallengeDone` | 1 | challenge id (`Config/Challenges`: `CarHits`, `Spin`, `WeekHits`, ...) | `Daily` / `Weekly` | Which daily and weekly challenges players finish, and how many come back for them. |
| `ChestOpened` | cash it paid | `Daily` / `Weekly` | `Paint:<id>` (a chest-only paint, `Config/Paints`) or `Cash` | What challenge chests give out. |
| `EventSeen` | 1 | event key (`Config/Events`) | | Players in the server when a live event started. |
| `EventJoined` | 1 | event key | | Players who took part (a hit, smash or stunt while it was live), once per event run. With `EventSeen`: the join rate per event. |

Older custom events (kept): `VehicleSpawned` (field 01: vehicle id), `Demolished`, `GiantToppled`.

## Onboarding funnel (`LogOnboardingFunnelStepEvent`)

Steps in order: 1 Joined, 2 Spawned a car, 3 First hit, 4 First rampage, 5 Took a ramp, 6 Smashed a building,
7 Claimed a goal, 8 First vehicle bought, 9 Joined an event, 10 Tutorial done. Step numbers never change: the
dashboard names each number from the events it has seen, so a renumbering mixes the steps up.

The tutorial's ramp step was removed on 2026-11-20; since then step 5 is logged together with step 4, so the
funnel stays continuous and step 5's completion means nothing. The release of 2026-11-20 renumbered the steps
(5 Smashed a building ... 9 Tutorial done) until the old numbers came back on 2026-11-21, so the dashboard's
funnel for players who joined in between is mixed up. The same release made the goal step a short goal of its
own (a few hits, then a CLAIM pop-up that claims itself after a few seconds) instead of opening the GOALS sheet.

Steps 5, 6 and 8 are logged by `src/server/Onboarding.luau` when the tutorial passes that step (also when it
was done before the step came up); a step the player skips is not logged. Answers: where new players drop out
of the first session.

## Economy events (`LogEconomyEvent`)

Currency `Money`. Sources: play earnings (batched per minute, `Gameplay`), goal and tutorial rewards, packs
(`IAP`, sku = product key), the Roadster pass, group, invite and server-goal rewards, challenge chests (`TimedReward`, sku `DailyChest` /
`WeeklyChest`). Sinks: vehicles (sku =
vehicle id) and paints. Answers: where money comes from and goes to (Creator Hub's Economy page).

## Reading it in Creator Hub

- Purchase drop-off: `StoreOpened` -> `ItemViewed` -> `PurchasePrompted` -> `PurchaseBought` /
  `PurchaseCancelled`, filtered by field 01 (item) and field 03 (device).
- Starter Pack: `OfferPopup` (Starter, Shown) -> (Starter, Pressed) -> `PurchaseBought` with field 02 `Starter`.
- Empty-server churn: `PlayerLeft` broken down by field 01 (players) and field 02 (minutes).
- Quit points: `LeftWhile` by field 01.
- Phone load time: `LoadTime` by field 03 = `Phone`, field 01 buckets.
