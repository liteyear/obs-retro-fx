# Validation — 1.0.0

## Mac user test

The personal build on which this public release is based was reported to work
successfully on a Mac mini. The report was received on November 1, 2026. Exact
chip, macOS version and OBS version were not collected. This is user validation
of that setup, not a compatibility claim for every Mac or OBS release.

The public version changes branding, filter IDs, version strings and documentation.
Effect implementations, controls and default values match the personal build.

## Automated engine tests

- Ubuntu 24.04; real libobs and OBS scripting library **30.0.2**.
- Actual LuaJIT/SWIG bindings and OBS OpenGL renderer, not a mocked OBS API.
- Mesa llvmpipe, OpenGL 4.5, headless X server, shader compilation and pixel readback.
- A 320 × 180 gradient/checker source with partially transparent edges, resized
  to 400 × 224. These images validate behavior, not full-resolution performance.

| Check | Result |
| --- | --- |
| Script registers all 15 filters | Pass |
| All 15 default effect types render | Pass |
| Bayer 2/4/8 and Hilbert dither | Pass |
| All 25 CRT selections, including no phosphor mask | Pass |
| Every other exposed dropdown, including all four Matrix fonts | Pass |
| Frame Skip holds output when input changes | Pass |
| Every effect handles source resolution changes | Pass |
| Two filters stacked on one source | Pass |
| Source-setting JSON round trip | Pass |
| Reload with existing filters attached | Pass |
| Bypass restores the exact baseline pixel sum | Pass |
| Check all 15 effects button | 15/15 pass |
| Reload effects button | Pass |
| Filter removal, source destruction, script unload and OBS shutdown | Pass |

Both the original build and the public build completed the integration harness
with `FAILURES 0`. The public run used its independent filter IDs and checked
the diagnostic and reload buttons through OBS's native property callbacks.

## Limits

- Windows has not been tested.
- Full-resolution GPU/CPU load alongside Ableton or a live encoder is unmeasured.
- HDR and extended color spaces are unverified; ordinary SDR is the target.
- No multi-hour soak test has been completed. Shader clocks are bounded in code.
- Original Retro Effects and personal-build scene settings are not migrated.
