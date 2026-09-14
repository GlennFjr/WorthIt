# Changelog

## 2.1.0

- Added native price-over-time charts with 24H, 7D, and 30D ranges.
- Added a dedicated Analytics view for each Blizzard favorite.
- Added median, mean, low/high, IQR, MAD, coefficient of variation, percentile, robust z-score, sample span, and quantity metrics.
- Added 24-hour trend to the Market table.
- Added confidence and freshness summary metrics to Market Brief.
- Added row click-through, alternating row treatment, and clearer visual hierarchy.
- Kept the single favorites-summary query model with no background polling or per-item scan queue.

## 2.0.0

### Product simplification

- Blizzard Auction House favorites are now the only tracked items.
- Removed manual pins, watch commands, item IDs, item links, drag-and-drop entry, and remove controls.
- Removed the per-item refresh queue.

### Market intelligence

- Favorite summary results now update current price and quantity in one query.
- Added a Market Brief with strongest buy and high-price signals.
- Added 24-hour trend metrics in row tooltips.
- Added freshness display and stronger query diagnostics.
- Passive observations are limited to existing favorites.

### Engineering

- Favorite histories now use full Auction House item-key identity.
- Added schema 3 migration.
- Added bounded 30-day storage with a 400-observation cap per favorite.
- Kept median fair value, MAD volatility adjustment, confidence scoring, and duplicate suppression.
- Removed `SendSearchQuery` from the addon.
- Refreshes use one `SearchForFavorites` request with cooldown and throttle checks.

## 1.1.0

- Added Blizzard favorite synchronization and easier manual pins.
- Added Escape-key close behavior.
- Added query diagnostics.

## 1.0.0

- Initial WorthIt analytics prototype.
