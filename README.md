# Liteyear Retro FX

**15 GPU video effects for OBS Studio. One folder. No separate plugin installer.**

Add one Lua script to OBS, then use the effects from the normal **Filters** menu.
Stack VHS, CRT, glitch, bloom, Matrix rain and more on a camera, video, group or scene.

[**Download the latest release**](https://github.com/liteyear/obs-retro-fx/releases/latest)
· [Setup guide](docs/START-HERE.html)
· [Validation details](docs/TEST-REPORT.md)

## Install

1. Download **Liteyear-Retro-FX-1.0.0.zip** from Releases and unzip it.
2. Move the whole **Liteyear-Retro-FX** folder somewhere permanent, such as Documents.
3. In OBS, open **Tools → Scripts**, click **+**, and select **liteyear-retro-fx.lua**.
4. Close Scripts. Right-click a camera, video, group or scene → **Filters** → **+**
   under Effect Filters → choose any **Liteyear FX** effect.

Keep `assets` beside the Lua file. OBS remembers the script and filters after restarting.
Use the **Scripts** tab; no Python setup is required. You can also build the
release ZIP from this repository using `python3 tools/build.py`.

## Effects

| Effect | What it does |
| --- | --- |
| Chromatic Aberration | Offset RGB channels manually or simulate lens fringing |
| Frame Skip | Hold frames for a lower-frame-rate look |
| Interlace | Combine alternating fields from current and previous frames |
| Posterize | Reduce color levels or apply a two-color gradient |
| Dither | Bayer 2/4/8 patterns and Hilbert noise, in color or monochrome |
| CRT | 24 phosphor masks, curvature, vignette, rounded corners and glow |
| NTSC | Signal tuning, luma bands, chroma bleed, dot crawl and picture controls |
| Cathode Boot | CRT collapse and boot, with manual or built-in animation |
| Matrix Rain | Four character sets, source colors, rain speed and glow |
| Retro Codec | RPZA-style block compression, dithering and temporal artifacts |
| VHS | Jitter, tape wrinkles, pop lines and head-switching noise |
| Bloom | Highlight glow with luminance or RGB-channel thresholds |
| Scanlines | Animated sine, square, smoothstep and triangular lines |
| Digital Glitch | Procedural displaced blocks and RGB drift |
| Analog Glitch | Continuous wave distortion, interference and color drift |

Add multiple filters to combine effects. Filter order changes the result.
Turn individual effects on and off with their eye icons.

## Controls and recovery

In **Tools → Scripts**, select **liteyear-retro-fx.lua**:

- **Bypass every Liteyear FX filter** restores the original picture without deleting settings.
- **Check all 15 effects** checks default shader compilation and required Matrix font loading.
- **Reload effects** recompiles the effects and resets their frame buffers.

Detected shader or texture failures bypass the affected filter and write details to the OBS log.
For Matrix Rain, first check that the `assets` folder has not been moved.

Cathode Boot starts at **0%**, which keeps the normal picture visible. Move the
progress slider to see the collapse, or choose a built-in animation.

## Compatibility

- **macOS:** the original personal build was confirmed working by a Mac mini user.
  The exact chip, macOS version and OBS version were not recorded.
- **Linux:** automated rendering and lifecycle tests pass using real libobs 30.0.2,
  LuaJIT and OpenGL, including all effect types and exposed dropdown selections.
- **Windows:** not tested yet. This release is primarily for Mac users.

OBS must include Lua scripting support. No native binary, old Retro Effects plugin,
Node server, browser source, API key or network connection is needed to run the effects.

The pixels are processed on the GPU. Multiple filters still add GPU work; performance
depends on your source resolution, effect stack, hardware and encoder load. Glow uses
a quarter-resolution separable blur; Retro Codec uses a reduced-resolution codec pass.
SDR video is the current target. HDR and a multi-hour soak test remain unverified.

## About this adaptation

This project adapts [FiniteSingularity's OBS Retro Effects](https://github.com/FiniteSingularity/obs-retro-effects)
into an independent Lua filter package. Most effects use the original GPU shaders.
Digital Glitch uses procedural GPU blocks, and glow uses a fixed-cost separable blur.

All 15 effect categories are included with streamlined controls. Original plugin
presets/settings are not imported. Posterize supports original colors and a two-color
gradient; source/scene palette sampling and custom font atlases are not exposed.

If replacing another effects package, disable its filters using their eye icons
while trying these. There is no need to delete your scenes or uninstall it.

## Development

```sh
python3 tools/build.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

The builder uses Python's standard library and includes editable source in each ZIP.
See [DEVELOPMENT.md](docs/DEVELOPMENT.md) for the real-OBS Linux integration harness.

## License and credits

GPL-2.0. Original engines by **FiniteSingularity and contributors**; Lua adaptation
and packaging by **Liteyear Design**. Original shader notices and font assets are
retained. See [CREDITS.md](CREDITS.md) and [LICENSE](LICENSE).
