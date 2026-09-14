# WorthIt

WorthIt is a Retail World of Warcraft Auction House analytics addon built around Blizzard favorites.

## Version 2.1.0

WorthIt tracks only items you favorite in Blizzard's Auction House. There is no separate watchlist, item-ID workflow, or background scanner.

### Market view

- Favorites summary refresh
- Current minimum price
- 7-day median fair value
- 24h-vs-7d median movement
- Confidence-weighted market signals
- Opportunity ranking
- Market Brief
- Query diagnostics
- Passive captures from normal AH browsing

### Analytics view

Click any favorite to open its analytics page.

- Native price-over-time chart
- 24-hour, 7-day, and 30-day chart ranges
- 7-day median and arithmetic mean
- 7-day low and high
- Interquartile range
- Median absolute deviation
- Coefficient of variation
- Current-price percentile
- Robust z-score
- Observation count and time span
- Latest observed market quantity

The chart uses recorded observations only. WorthIt does not interpolate or create missing price points.

## Auction House behavior

WorthIt uses `C_AuctionHouse.SearchForFavorites` for active refreshes and reads the returned browse summaries. It does not use `C_AuctionHouse.SendSearchQuery` and does not poll the Auction House in the background.

Opening the Auction House triggers one favorites refresh for that AH session. Favorite-change events may trigger a debounced refresh. Manual refreshes have a cooldown and respect Blizzard's throttle readiness signal.

## Commands

- `/worthit` or `/wit` — open or close WorthIt
- `/worthit refresh` — refresh Blizzard favorites
- `/worthit stats` — print data and query diagnostics
- `/worthit reset CONFIRM` — clear local WorthIt history

## Storage

WorthIt stores data locally in `WorthItDB` using SavedVariables.

- 30-day retention
- 400 observations maximum per favorite
- Duplicate observations suppressed within five minutes
- No external service
- No cloud database

## Install

Place the `WorthIt` folder at:

`World of Warcraft/_retail_/Interface/AddOns/WorthIt`

The final path should contain:

`WorthIt/WorthIt.toc`

Restart WoW after installing or replacing addon files.

## Test

Enable Lua errors:

`/console scriptErrors 1`

Then reload:

`/reload`

Favorite several items in Blizzard's Auction House, open the AH, and run `/worthit`.

See `Docs/TESTING.md` for the full checklist.
