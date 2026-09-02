# Visual regression plan

CI currently protects the UI structurally by checking critical scripts and assets. Pixel-perfect screenshots are intentionally not generated on the Linux headless runner because the dummy renderer is not representative of Android output.

## Canonical visual markers

Use the same portrait Android profile as the release target: **720×1280**, portrait orientation.

Capture two canonical states and compare them against the previous approved capture:

### Map marker

- default map zoom and initial camera position;
- campaign location and available destination controls are visible;
- route/front information is readable without clipping;
- when the selected route belongs to a connected network, the forecast contains the `СЕТЬ +N%` reward marker;
- no duplicate route/network marker appears after returning to the map.

### Combat HUD marker

- active wave counter is visible;
- truck HP and scrap counters remain inside the safe UI margins;
- weapon/upgrade controls remain reachable in portrait mode;
- boss/road-event announcements do not permanently cover the core HUD;
- the HUD returns to the same baseline layout after a run completes.

These markers are the stable review checklist for visual regressions. Pixel-perfect screenshots remain a device-only check because the Linux headless renderer is not representative of Android output.

## Device validation

Capture one map screenshot at default zoom and one combat-HUD screenshot during an active wave. Compare them manually or with an Android screenshot-diff tool on the same device profile. Keep screenshots out of the source tree unless a review explicitly requires checked-in golden images.
