# Android smoke test

## CI

The GitHub Actions pipeline verifies resource import, headless startup, campaign regressions, UI resource presence, and APK export/signature.

## Physical device

Run on a real Android device after installing the CI APK:

1. Launch the app from the launcher.
2. Confirm the main map appears without a crash.
3. Select a discovered city and open the route sheet.
4. Start a short route and verify touch placement of an initial weapon.
5. Pause/resume the run and change sound/effects settings.
6. Complete or abandon the run and confirm return to the map.
7. Reopen the app and verify campaign/meta progress survives restart.
8. Exercise pinch/drag map controls and showroom drag/pinch.
9. Capture one screenshot of the map and one of the HUD for visual review.

Record device model, Android version, APK commit SHA, result, and any logcat errors in the release test notes.

## Acceptance

- No crash during the flow above.
- No blocking UI/input defect.
- APK installs and launches.
- Save data survives process restart.
- Map and HUD remain legible in portrait mode and around system gesture insets.
