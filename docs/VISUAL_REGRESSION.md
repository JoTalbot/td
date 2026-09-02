# Visual regression plan

CI currently protects the UI structurally by checking critical scripts and assets. Pixel-perfect screenshots are intentionally not generated on the Linux headless runner because the dummy renderer is not representative of Android output.

For device validation, capture two canonical screens:

- map screen at the default zoom;
- combat HUD during an active wave.

Compare them manually or with an Android screenshot-diff tool on the same device profile. Keep screenshots out of the source tree unless a review explicitly requires checked-in golden images.
