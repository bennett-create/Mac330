# Mac330

A work-in-progress Minecraft shaderpack for **Iris / OptiFine**, targeting
**Minecraft 1.17+** and written against GLSL `#version 330`. It started from
Bálint's `Base-330` template and is being built up into a MacOS first physically
-motivated lighting pipeline.

> ⚠️ **Heavily in development.** This is an experimental, fast-moving project —
> currently `v0.0.1` on the `dev` branch. Features are incomplete, defaults are
> still being tuned, and things *will* break, look wrong, or change without
> notice between commits. Not meant for "production" use yet: expect bugs and
> visual glitches.

## What it does so far

**Lighting**
- **Physically-based lighting** — sun, sky, moon, and block light are driven by
  approximate real-world illuminance (lux) values rather than arbitrary
  constants.
- **Time-of-day color temperature** — sunlight shifts along a Kelvin curve over
  the day (warm sunrise → neutral midday → warm sunset), converted to RGB.
- **Screen-space global illumination (SSGI)** — single-bounce indirect light
  with color bleeding, plus sun/sky/block-light bounce and ambient occlusion,
  via Vogel-disk ray marching.
- **Subsurface scattering** for light transmission through thin surfaces.

**Shadows**
- Soft **PCF shadows** with Vogel-disk filtering, shadow-map distortion, and
  slope/normal/depth biasing.
- Optional **pixelated shadow** mode that snaps shadows to a block-aligned grid
  for a stylized look.

**Sky & atmosphere**
- **Analytic atmospheric sky** with Rayleigh + Mie scattering, horizon
  extinction, a configurable haze term, twilight tinting, and rendered sun &
  moon discs.

**Camera / post-processing**
- **Auto-exposure / eye adaptation** — log-luminance metering with separate
  light- and dark-adaptation speeds and center weighting.
- **Scotopic (low-light) vision** — Purkinje-style desaturation and blue shift
  in very dark scenes.
- **Physically-based bloom** (multi-mip).
- **Tonemapping** — ACES by default, Reinhard-Jodie available.

Almost all of the above is exposed as toggles and sliders in the in-game shader
options screen — see `shaders/shaders.properties` and
`shaders/lib/settings.glsl`.

## Versioning

See `CHANGELOG.md`. `MAJOR.MINOR.PATCH`:
- **patch** (`0.0.x`) — tweaks and fixes; just counts up
- **minor** (`0.x.0`) — an actual new feature
- **major** (`x.0.0`) — first build that feels ready for a real release

Currently `0.0.1`: early scaffolding of the lighting pipeline.

## Built with AI assistance

This pack is developed with the help of AI coding tools — **Anthropic's Claude
Code** and **OpenAI's Codex**. They're used to write, refactor, and tune shader
code; all output is reviewed and integrated by me.

## Credits & license

- Base template: **Bálint** (`Base-330`, `#version 330`, MC 1.17+).
- Pixel locked lighting inspired by Complimentary Shaders by EminGT
- Licensed under the terms in `LICENSE`.
