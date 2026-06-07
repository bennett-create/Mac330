# Changelog

## Versioning

`MAJOR.MINOR.PATCH`

- **MAJOR** — bumped when the pack feels ready for a release.
- **MINOR** — bumped for each actual feature.
- **PATCH** — bumped for everything else (tweaks, fixes, small changes); just counts up.

## 0.0.3

- Reorganized the in-game Shader Options into click-through menus (Lighting, Global Illumination, Shadows, Sky & Atmosphere, Materials, Post-processing, Auto Exposure) with nested sub-screens for GI quality, shadow bias tuning, and low-light vision. Previously every option was a single flat list.
- Added `shaders/lang/en_us.lang` with readable option names, screen titles, tooltips, and On/Off labels. Surfaced GI strength/radius/distance/saturation and sun-bounce-shadows options that were not reachable in any menu before.
- Updated defaults from in-game tuning: `ENABLE_GI` 1→0, `PIXELATED_SHADOW_GRID_PHASE` 0.0→0.5, `PLANT_SHADOWS` 0→1, `TONEMAP_EXPOSURE` 2.0→1.0.

## 0.0.2

- Rewrote `readme.md` to document the current pipeline (physical lighting, SSGI, atmospheric sky, soft/pixelated shadows, auto-exposure, bloom, tonemapping), stress the in-development nature, and disclose use of Claude Code and Codex.

## 0.0.1

- Initial commit. Shaderpack based on Bálint's `#version 330` template, with work-in-progress edits to composite passes, gbuffers, lib, and shaders properties.
