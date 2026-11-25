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
| `OfferPopup` | 1 | `Starter` / `Upsell` / `Trial` | `Shown` / `Pressed` | The Starter Pack and "can't afford it" cards: shown, then its buy button pressed. Bought shows as `PurchaseBought` with where `Starter` / `Upsell`. |
| `PlayerJoined` | players in the server | players bucket (`1`, `2`, `3-4`, `5-8`, `9+`) | | How full servers are when players arrive. Sent once the client reports its device (or after `ReadyWaitSeconds`). |
| `PlayerLeft` | session minutes | players bucket at leave | minutes bucket (`0-2`, `2-5`, `5-15`, `15-30`, `30-60`, `60+`) | Do players in near-empty servers quit fast? Compare minutes buckets across player buckets. |
| `LeftWhile` | session minutes | `Driving` / `Menu` / `Idle` / `Wrecked` / `OnFoot` | minutes bucket | What players were doing when they quit. `Wrecked`: another player's car flung them in the last `WreckedSeconds`; `Menu`: a menu or card was open; `Idle`: no input for `IdleSeconds`; `Driving`: in their car's driver seat (tracked while they play, and still counted if they were stood up within `SeatGraceSeconds`, since leaving removes the car before the leave is logged). |
| `LoadTime` | seconds | seconds bucket (`0-5`, `5-10`, `10-20`, `20-40`, `40+`) | `Ready` / `Timeout` | Load time per device: from client start to spawn-ready (the loading cover's ready check). `Timeout`: the cover gave up waiting. |
| `FirstVehicleBought` | total minutes played | vehicle id | total minutes bucket (`0-10`, `10-30`, `30-60`, `60-120`, `120-240`, `240+`) | The money curve: how long until players afford their first car beyond the starter, and which car it is. Logged on the first car bought with game money; cars from the Roadster pass or the Starter Pack don't count as bought. Minutes count all sessions (saved as `playSeconds` in the profile from this release on). |
| `TutorialSkipped` | 1 | step skipped (`Smash`, `Garage`, `Goal`, `Buy`, `Event`; the hits step has no SKIP; `EventTimeout` when the event step ended itself after `EventWait`) | seconds on the step (`10-20`, `20-40`, `40-60`, `60+`; `0-10` only if the server's step clock started late) | Tells skipping from quitting: every tutorial step left without finishing it (SKIP press, shown after `SkipAfter` = 10 s, or the event step's timeout). Skipped steps are not funnel steps. |
| `TutorialOffer` | 1 (`RewardPaid`: the bonus paid) | `Shown` / `Accepted` / `Declined` / `Restarted` / `RewardPaid` | `First` (first join) / `Again` (the join after one "No thanks") / `Button` (the menu strip's TUTORIAL tab) | The first-join tutorial offer (added 2026-11-24): how many new players take the tutorial, how many come back to it, and how many finish it for the bonus (`FinishBonus` in `Config/Onboarding`). `Restarted` is a TUTORIAL tab press; `RewardPaid`'s field 02 is how that run started (`First` when it started in an earlier session). Players who were part way through the tutorial before this release are treated as having said yes; players who had finished it never see the offer. |
| `TutorialTour` | 1 | page reached: `Open`, `Car`, `Upgrades`, `Paint`, `Decals`, `NextCar`, `Done` (`Config/Onboarding` TourPages) | | The garage tour step (after the smash step): where players drop out of it, once per page per session. `Done` ends the step. |
| `LeftOwning` | session minutes | cars owned (`1`, `2`, `3`, `4-5`, `6-8`, `9+`, the starter included) | minutes bucket | Retention against car progress: logged with `PlayerLeft` and `LeftWhile` at every leave (`PlayerLeft` has no free field for it). |
| `CarOwned` | total minutes played | vehicle id | cars owned now (a number, the starter included) | Car progression: every car that comes to a player (bought with cash, the Roadster pass, a Starter Pack car), with the play time it took. |
| `NextCarProgress` | total minutes played | vehicle id (the cheapest car not owned yet, the Roadster included) | `25` / `50` / `75` / `100` (percent of its full price in cash) | How far players get toward their next car, and how long it takes. Each step once per car per player (saved as `progress` in the profile); a jump past several steps logs each one. |
| `RoadsterTrial` | 1 | `Offered` / `Started` / `Ended` / `Converted` | end reason for `Ended`: `Time` / `Left` / `Bought` | The Roadster free trial (`Config/Trial`): the garage showed the FREE TRIAL button (once per session, only when a trial was really available), the player started one, it ended (time up, left the game, or bought the car mid-trial), and `Converted` when the Roadster pass or the car was bought within `ConvertSeconds` (7 days) of a trial start (`trialAt` in the profile). The end card's pass button is `OfferPopup` with field 01 `Trial`. |
| `GoalClaimed` | 1 | goal kind (`Hits`, `Earn`, `Drive`, ...) | `Hourly` / `Daily` | Which goals players finish. |
| `ChallengeDone` | 1 | challenge id (`Config/Challenges`: `CarHits`, `Spin`, `WeekHits`, ...) | `Daily` / `Weekly` | Which daily and weekly challenges players finish, and how many come back for them. |
| `ChestOpened` | cash it paid | `Daily` / `Weekly` | `Paint:<id>` (a chest-only paint, `Config/Paints`) or `Cash` | What challenge chests give out. |
| `EventSeen` | 1 | event key (`Config/Events`) | tier (`Quick`, `Contest`, `Big`) | Players in the server when a live event started. |
| `EventEnded` | players who took part | event key | `Won` (crate claimed, truck cracked, boss beaten, giant toppled) / `Time` (ran out) | Logged once per event run, on one player in the server. How often each event is won and how many join in. |
| `EventPaid` | amount | event key | `Prize` (contest place), `Share` (Boss Truck pot split by damage), `Jackpot` (Money Truck cracked), `Cash` (a spilled bundle grabbed), `Crate` (Cash Drop) | Event money per player, per event and kind. Compare with hit pay to size `Config/Events` `PayScale`. |
| `EventJoined` | 1 | event key | | Players who took part (a hit, smash or stunt while it was live), once per event run. With `EventSeen`: the join rate per event. |
| `Teleported` | 1 | area key (`Config/Teleport` Places: `City`, `SunnyVale`, `OakHollow`, `Seaside`, `StuntPark`, `Motocross`) | `Car` / `OnFoot` | Teleports from the city map's rings, once per teleport. Which areas players jump to, and whether they bring their car. Refused teleports (cooldown, riding, by the event) are not logged. |

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

Since 2026-11-24 the tutorial runs spawn, hits, smash, a garage tour (no funnel step of its own: see
`TutorialTour`), first goal, event, then the buy step last, after the finish bonus. So step 9 (Joined an event)
now comes before step 8 (First vehicle bought) for new players; the numbers are unchanged. A player who says
"No thanks" to the offer has the tutorial ended without step 10.

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
- Tutorial offer: `TutorialOffer` Shown -> Accepted / Declined by field 02, then RewardPaid; compare
  `LeftOwning` and `PlayerLeft` minutes for players before and after the release.
- Garage tour drop-off: `TutorialTour` count per field 01, in page order.
- Tutorial skips: skips per step = `TutorialSkipped` by field 01, compared with the funnel's drop at that step
  (a big drop with few skips means players quit there; with many skips they move on without finishing).
- Roadster trial: `RoadsterTrial` Offered -> Started -> Ended (Time) -> Converted; day-1 return of trial players
  shows as a second `Started` a day later.
- Car progression: `CarOwned` by field 02 (how many cars) with the value (minutes); `LeftOwning` by field 01 for
  where in the car ladder players quit; `NextCarProgress` by field 01 and 02 for how far they get toward each car.
