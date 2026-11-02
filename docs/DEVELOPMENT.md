# Development

Build the OBS-ready folder and public ZIP with Python 3 (standard library only):

```sh
python3 tools/build.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

Outputs: `package/Liteyear-Retro-FX/`, `dist/Liteyear-Retro-FX-1.0.0.zip` and
`dist/SHA256SUMS.txt`. The ZIP includes editable source. Its timestamps and file
ordering are fixed so repeated builds of the same source produce identical ZIPs.

`src/runtime.lua` contains filter hosting and controls; `src/custom.effect`
contains the helper shaders. Original shaders are in `src/upstream-shaders`.
The builder expands includes and embeds shader text in the generated Lua script.

## Linux integration test

The integration harness needs libobs, OBS's Lua scripting library, Xvfb, a C
compiler and X11 development headers. On an Ubuntu development machine, install
`libobs-dev`, `obs-studio`, `xvfb` and `libx11-dev`, then compile:

```sh
cc -std=gnu11 -rdynamic tests/render_harness.c $(pkg-config --cflags libobs) \
  -lobs -lobs-scripting -lX11 -lxcb -lm -ldl -o tests/render_harness
python3 tests/run_integration.py
```

The runner uses installed system libraries or `LITEYEAR_OBS_PREFIX` for an
extracted Linux runtime. OBS's libobs data directory must remain discoverable.
The test uses display 97 and exits nonzero on a failed render or lifecycle check.
Ordinary users do not need any development tools to run the effects.

Keep the `liteyear_retro_*_v1` filter IDs stable in future public releases so
saved scenes continue to load. Newer builds must preserve existing setting IDs
and values or implement an explicit migration.

Upstream source: https://github.com/FiniteSingularity/obs-retro-effects
Snapshot: `0e25d8e0e04a0dee10e6e53ccb09e083f45072c1` (1.1.1).
GPL-2.0; retain shader attribution comments.
