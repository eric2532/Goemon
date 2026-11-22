# Aoi — original pipe adventurer

An original Goemon-inspired character, presented as eight-direction animated
sprites alongside the recovered Cross Gate cast. Stable ID 41 / save key `aoi`.
The name is a working name; this is not a recovered Cross Gate character.

The editable model and export instructions are in
`assets/blender/characters/aoi/README.md`. The user selected sprites rather than
a live 3D character. The existing Goemon rig and animation assets are used only
for offline authoring; gameplay uses the existing shared Cross Gate model,
combat controller, local native queries and pooled ally presentation.

The red jacket, ochre trim, blue hair, ivory wraps and long brass/wood pipe
follow the approved concept. The authored pipe is 3.8 m, four times its .95 m
short ruler, with the same grip and thickness. Standing body scale is 83 pixels,
matching Kaz's scale. The atlas uses a shared 128-color palette and a subtle
one-pixel silhouette rim. It retains all seven action clocks from Kaz and adds
eight guard clips for the existing jump presentation.

LMB/RMB use Kaz's existing two-contact attack, reach and damage. The existing
Kaz spell defaults, combo, evade and shared skills remain available. Body
poses are newly rendered artwork; no original recovered pixels are overwritten.
Footsteps and landings reuse Goemon's prepared shared sounds; saved recordings,
gain and mute stay under this character's own stable ID.

The baked manifest records the source master, clock and render hashes. Never
edit packed atlas pages directly. Reports and gameplay captures live under
`build/Other Files/Asset Toolkit/Aoi/`. No app export is part of this change.
