# 2.5.1 stabilization checklist

## Automated
- Campaign, UI-resource and connected-road regression tests run in CI.
- Android export is built and APK signature is verified in CI.
- Connected-road rewards are integrated into the actual travel reward multiplier and map forecast.
- Travel modifiers reset at the start of each run to prevent cross-run accumulation.
- Counterattack resolution keeps the original route origin before campaign arrival mutates location.

## Device-only
- Physical Android smoke test remains required because the Linux headless renderer cannot validate touch input, GPU output, haptics or real APK startup on hardware.
- Balance tuning remains telemetry-driven and should use several real device runs before changing economy constants.

## Visual
- Headless CI validates resource presence. Pixel-level map/HUD golden images should be captured on one canonical Android profile when hardware validation is performed.
