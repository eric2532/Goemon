ROM GOEMON BLENDER MASTER

goemon.blend is the editable master. It contains 13 original body meshes,
preserved source vertices/triangles/raw S/T UVs, 22 packed texture images and
232 selectable source action IDs. No source body pieces are welded together.

Select ROM_Goemon_Rig, then use Dope Sheet > Action Editor to choose an action:
ROM_00_Idle, ROM_0F_Run, ROM_18_Jump, ROM_19_Fall, ROM_1A_Land,
ROM_68_Pipe_Combo_1, ROM_69_Pipe_Combo_2, ROM_6A_Pipe_Combo_3, and the remaining
named ROM action IDs. Timeline runs at 30 fps; original per-action rates are baked
into key times and retained in the rom_rate custom property.
Quarter-source-frame samples preserve spherical interpolation during fast
turns; fractional poses between baked samples are verified within 1 mm.

The thirteen named bones use the original independent global matrices. Each
body part has one 100% bone binding. Native affine correction modifiers retain
the small shears that ordinary Blender bone channels cannot represent. Keep
these enabled for original motion playback. This is a faithful source base,
with independent part controls, rather than an automatic humanoid/IK rig.

Body textures retain raw source UVs and tile clamp/mirror rules. Face channels
switch to the recovered PIC images through animated rig properties. Blender
previews use nearest texture sampling; the game uses its own N64 three-point
texture shader. Weapon geometry and gameplay are separate from this body base.

master_thief.blend is the approved fitted pilot. Its body/motions are the same ROM
master. Costume and pipe are copied from the existing Master Thief source,
with the headband/coin refitted to the fuller ROM head. Copied materials use
Master Thief's maroon/navy/gold/silver palette. Original source images, original
Master Thief .blend and original Kai .blend remain unchanged.

The playable Master Thief now uses this fitted costume/pipe and the original
body/motion archive. tools/export_rom_master_thief.py exports equipment without
saving over this source. The existing class controller retains guard, crouch,
evade and skill behavior; combat sockets follow the new visible pipe. The body
uses the game's native texture filtering with the copied Master Thief palette.

The hand attachment uses the original ROM grip frame. Native weapon node
0x9002518 attaches to0x9005868 (Forearm_L in the recovered part names), which
occupies the authored class rig's anatomical right-hand side. The saved pilot
and equipment export retain that grip frame. Native pipe strikes use the source
weapon matrix; idle/run carry use its recorded forearm-relative attachment.
The class guard/crouch/evade bridge maps limb names by their anatomical sides.
User direction correction: the custom pipe is turned end for end in that same
hand frame. The hand grips its narrow stem just ahead of the mouthpiece, with
the bowl outward. Keep the facing axis separate from the geometry contact point
when applying class guard and crouch poses.

Rebuild from the repository root:
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_rom_goemon_base.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_rom_goemon_thief.py

Verify saved/reopened assets:
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/verify_rom_goemon_base.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/verify_rom_goemon_base.py -- --pilot

Source hashes and original ROM provenance are recorded in manifest.json.
Development previews and verification reports live in the canonical
build/Other Files/ROM Goemon Blender Base folder.

worker.blend fits the Worker to this same ROM body. The straw hat follows Head,
and Pickaxe_Control uses the original pipe hand (0x9005868) and source weapon
rotation. Its ordinary tool stays a constant size through the source swings.
The runtime shares thirteen rigid body meshes and cached quarter-frame poses
across the workforce; it adds no worker skeletons or AnimationPlayers.
Build with tools/build_rom_goemon_worker.py; verify with
tools/verify_rom_goemon_base.py -- --worker.
