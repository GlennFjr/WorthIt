local ADDON_NAME, WI = ...

WI.name = ADDON_NAME
WI.version = "2.1.0"
WI.schemaVersion = 3
WI.modules = WI.modules or {}

WI.constants = {
    MAX_OBSERVATIONS_PER_FAVORITE = 400,
    RETENTION_SECONDS = 30 * 24 * 60 * 60,
    MIN_SAMPLE_INTERVAL = 5 * 60,
    FAVORITES_SYNC_COOLDOWN_SECONDS = 10,
    FAVORITES_SYNC_TIMEOUT_SECONDS = 6,
    FAVORITES_EVENT_DEBOUNCE_SECONDS = 0.75,
}

WI.colors = {
    good = { 0.25, 0.85, 0.35 },
    normal = { 0.95, 0.82, 0.25 },
    high = { 1.00, 0.48, 0.25 },
    muted = { 0.70, 0.70, 0.70 },
    white = { 1.00, 1.00, 1.00 },
}
