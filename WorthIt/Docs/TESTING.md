# WorthIt 2.1.0 Test Plan

## Setup

1. Install WorthIt under `_retail_/Interface/AddOns/WorthIt`.
2. Enable Lua errors with `/console scriptErrors 1`.
3. Run `/reload`.
4. Confirm `WorthIt: v2.1.0 loaded...` appears.

## Basic UI

1. Run `/worthit`.
2. Confirm the Market tab opens.
3. Press Escape and confirm WorthIt closes.
4. Reopen and click Analytics.
5. Confirm both tabs switch without Lua errors.

## Favorites

1. Favorite at least three items in Blizzard's Auction House.
2. Open the AH.
3. Confirm WorthIt synchronizes the favorites.
4. Confirm the Market table lists only Blizzard favorites.
5. Add or remove a Blizzard favorite and confirm WorthIt updates after the debounced sync.

## Query safety

1. Run `/worthit stats` and note the current-session query count.
2. Leave the AH open without interacting for several minutes.
3. Run `/worthit stats` again.
4. Confirm the query count does not continually rise.
5. Press Refresh Favorites once and confirm the count rises by one.
6. Immediately press it again and confirm the cooldown blocks another request.
7. Close the AH and confirm manual refresh is unavailable.

## Market analytics

1. Collect several observations across multiple favorites.
2. Confirm current price and 7-day median display.
3. Confirm 24h-vs-7d median movement displays when enough data exists.
4. Confirm low-sample items remain LEARNING or low confidence.
5. Confirm rows are ranked by opportunity score rather than alphabetically.

## Analytics page

1. Click a favorite row.
2. Confirm Analytics opens for that item.
3. Confirm current, median/mean, range, trend, percentile, sample span, IQR, MAD, CV, and robust z-score render.
4. Switch chart ranges between 24H, 7D, and 30D.
5. With fewer than two points in a range, confirm the empty-chart message appears.
6. With two or more points, confirm a gold observed-price line renders.
7. Confirm the gray 7-day median reference line renders.
8. Confirm chart dates and y-axis labels are readable.

## Persistence

1. Collect real data.
2. Run `/reload` and confirm history remains.
3. Log out and back in and confirm history remains.
4. Restart WoW and confirm history remains.

## Reset

1. Run `/worthit reset` and confirm nothing is erased.
2. Run `/worthit reset CONFIRM`.
3. Confirm local history is cleared.
4. Reopen the AH and confirm Blizzard favorites repopulate.
