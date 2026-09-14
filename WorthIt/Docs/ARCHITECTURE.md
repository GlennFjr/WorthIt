# WorthIt Architecture

## Product model

Blizzard Auction House favorites are the source of truth. WorthIt adds analysis, not another item-management workflow.

## Data flow

1. `SearchForFavorites` requests the favorites summary.
2. Browse results provide item keys, minimum prices, and quantities.
3. WorthIt synchronizes the favorite index.
4. Observations are deduplicated and retained locally.
5. Normal AH browsing can add passive observations for existing favorites.
6. The analytics engine produces robust price statistics and confidence-weighted signals.
7. The dashboard renders market ranking and per-item analytics.

## Storage

Each favorite stores:

- full Auction House item key
- item ID and item name
- last price
- last quantity
- last seen timestamp
- timestamped observations

Observation history is limited to 30 days and 400 observations per favorite.

## Analytics

The 7-day median is the primary fair-value estimator because it is less sensitive to extreme listings than the arithmetic mean.

Median absolute deviation measures robust dispersion. The signal threshold expands for historically volatile markets.

The Analytics view also reports:

- arithmetic mean
- low and high
- quartiles and IQR
- MAD
- sample standard deviation
- coefficient of variation
- empirical current-price percentile
- robust z-score
- observation span

Confidence combines recent sample count with time coverage. A large number of observations collected in a short burst does not immediately become high confidence.

## Visualization

The price chart is drawn with WoW-native line objects. It plots recorded observations directly and overlays the 7-day median as a reference line. Up to 120 evenly selected observations are rendered to bound UI work while preserving the time-series shape.

## Auction House safety

WorthIt does not use per-item active search scans. The only active query path is the favorites summary request.

There is no recurring polling timer. Timers are used only for event debounce, initial AH-session sync, and timeout handling.
