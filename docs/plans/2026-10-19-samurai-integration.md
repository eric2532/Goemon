# Approved Samurai integration

Use the approved Samurai workbench, including the enlarged sharp maroon katana,
two-handed low guard, drawn-weapon run, and five contact poses. Preserve the
original body, painted textures, skeleton, bow, specials, damage clocks and input
cancellation. Remove the runtime scabbard and old draw/sheath choreography.

1. Add a runtime integration regression, run it against the old Samurai.
2. Sample evaluated Blender IK poses and export only the new weapon geometry
   into the original character's runtime GLB. Keep editable workbench read-only.
3. Apply those poses through a Samurai-only motion driver. Retime each contact
   to existing combat contacts; use the real new blade tip for reach and trails.
4. Check idle/run loops, all five contacts, bow, dodge, airborne attacks, range
   scaling, model integrity, selection art, and existing authored hero regressions.
5. Recheck Pirate/Musashi concurrent changes before exporting the latest complete
   painterly source. Stage outside build/, verify, then publish only Goemon.app.

Other work: the completed army agents handled broadphase, formation separation,
and hitch profiling. Pirate integration is active in another chat; Musashi motion
recovery is active in its own worktree. Shared-file edits must be narrow and retain
their changes. No edits to their workbenches or recovered assets.
