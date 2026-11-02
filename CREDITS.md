# Liteyear Retro FX 1.0.0

Based on **OBS Retro Effects 1.1.1**, by FiniteSingularity and its contributors:
https://github.com/FiniteSingularity/obs-retro-effects

Upstream snapshot: `0e25d8e0e04a0dee10e6e53ccb09e083f45072c1`.

Original upstream license: GNU General Public License version 2. The complete
license is included in `LICENSE`. Retain the original shader comments and
attribution when redistributing this adaptation. Embedded shader code retains
its upstream author notices. This is an independent adaptation.

Upstream credits retained in the shaders include Millennium Cyborg (RPZA),
hunterk/libretro (public-domain phosphor mask weights), and the referenced
noise, dithering and analog glitch shader authors. See the corresponding
shader source comments for the original references.

Changes in this adaptation, November 2026:

- Replaced the native C plugin host with an OBS Lua filter host.
- Exposed 15 separately stackable filters with stable source IDs.
- Embedded shader text to avoid shader path and installer dependencies.
- Added input validation, resize handling, initial-frame history fallback,
  bounded shader clocks, detected-failure bypass, diagnostics and reload.
- Implemented procedural GPU block generation for Digital Glitch.
- Implemented a fixed-cost, quarter-resolution separable bloom blur.
- Added Cathode Boot animation without an external animation plugin.
- Simplified control sets; original plugin settings/presets are not imported.
- Bundled Matrix glyph textures and a short setup guide.

No dependency on the old Retro Effects plugin, Python, Node, a local server,
an API key, a network service or a browser source. OBS supplies LuaJIT and
the graphics APIs. The included Source directory contains the editable
runtime, shaders and build script.
