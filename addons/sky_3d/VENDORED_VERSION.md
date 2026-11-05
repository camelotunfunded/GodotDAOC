# Sky3D vendored dependency

- Upstream: https://github.com/TokisanGames/Sky3D
- Release: `v2.1.0`
- Source commit: `6e151bc3d941906643443b3751a1df545a08feda`
- Vendored: 2026-08-31
- License: MIT; bundled third-party sky assets keep their upstream attribution files.

DAoC integration is isolated in `res://src/daoc/environment/DaocSky3DAdapter.gd`.
Godot 4.6 screen-space fog is disabled by that adapter because of the known
Sky3D/Godot 4.6 fog regression; native Godot environment fog remains active.

Three upstream scripts (`Sky3D.gd`, `SkyDome.gd`, `TimeOfDay.gd`) use explicit
preloads for their sibling classes in this vendored copy. This makes command-line
tests deterministic before the Godot editor has generated its global class cache;
the runtime behaviour is unchanged.

`TimeOfDay.gd` carries one behavioural addition (2026-09-18, P1-90):
`simple_arc_tilt`, applied in `CelestialMode.SIMPLE` only. Upstream's simple
arc passes through the zenith at noon; the tilt leans the sun and opposite moon
arc away from it so noon shadows have a direction. 0 (the default) is upstream
behaviour. `SkyMaterial.gdshader` also carries the DAoC-only `daoc_*` uniforms
and cloud/celestial functions, which upstream does not have.
