# Cape cave source contracts

`tools/prepare_sokia_cape_dungeons.py` owns the pinned contracts in
`dungeon_specs.gd` and `encounters.json`. Run with `--check` for read-only
reproduction. Full source bytes, hashes, excluded script lines and primary
schema pins are retained under `assets/references/crossgate_sokia/` and in
`build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Cape caves/source-contracts.json`.

Config305 uses `cape_descent` floors7305000–7305009, from15525(23,5) to15526(8,7).
Config306 uses `cape_ascent` floors7306000–7306009, from15526(91,7) to15530(16,21).
Each branch has exactly ten floors. Membership and relative weights come from
encounter15005→groups15018/15019/15020 and15006→15021/15022/15023. Source level
intervals are43–47 and47–51. The reference editor's floor-level formula is
retained with that qualification; original server execution is unverified.

The existing seeded room graph generates these floors. Original random-floor
snapshots and the original generation algorithm are unavailable, so the layout
is an adaptation. Dimensions, ground/stair serials, directed endpoints and raw
configuration fields are retained. Config306's exit-in17954 differs from the
client-known15530 marker17955; the client tile stays unchanged. The reference
generator's terminal enterInfo/exitInfo bug is documented rather than copied.

The reference generator selects five/six boxes across the whole ten-floor
branch. The existing exploration-loot owner receives a seeded allocation from
adapted open cells. Original box positions and refresh timing remain unknown.
Native movement timing, uniform1–8 party count, real-time formation and combat
are existing adaptations, separate from source group/level/weight fidelity.

Princess5243 starts encounter12019→group12097. Lorens5305 starts12020→12098,
including the mandatory boss plus two of each soldier variant. Their source
F interactions reuse guarded events and the existing University/native battle
owner. Princess script lines1–29 are a narrow runtime projection; the malformed
unbound tail31–35 remains archived with its reason for exclusion. Shared event
parsing remains strict.

Production source-quest items already use an unbounded dictionary. Only this
princess's zero/nonzero ItemSpace predicates receive a truthful nonzero result;
original inventory slot limits remain unmodeled. Pure unknown/full contexts
retain their blocker/denial. The item18599→18600 branch is tested locally, but
natural 18599 acquisition remains unverified. The access supplement now contains
source-complete layouts and actors for 15524/15528/15529, gated pending scenery
review, plus 15517/15520 from the distinct config 300 chain. Full natural access
through these maps and NPC 5240/5241/5242 remains required work. This package does not complete natural
quest access or the regional goal.

`tools/prepare_sokia_cape_art.py` owns `rock.json/png`. Fixed15525 reuses138
exact client wall anchors, the existing original-cliff profile builder and
existing gorge paint. Continuous source footprints leave the measured princess
body clear without a shader cut or new physical opening. The unseen3D surfaces
are fitted interpretations. Generated walls reuse an opaque original13080
family patch; config wall fields25–29 are zero, so this family choice is an
explicit adjacent-source inference. Raw planes, gates, collision and navigation
stay authoritative.

The original two Cape field NPCs retain measured body-foot metadata through the
existing billboard owner. Princess original2975's map idle has foot184 in a
190px crop with raw origin(-120,-141); fitting foot184 changes the vertical
billboard offset by43px, preserving her source cell, pixels, scale and archived
origin. Lorens's corresponding correction is−1px. New access NPCs reuse the
existing source-NPC body's foot measurement and retain their raw source origins
separately. Native battle-frame origins
and their independent contact/foot convention stay unchanged.

Focused fixtures are `sokia_cape_dungeon_contract_test.gd` (all20 floors) and
`sokia_cape_review.gd` (direct groups, native contacts, source gates, cleanup and
fixed63° normal-camera views). Evidence belongs in the Cape caves directory.
Camera stations are direct fixture placements in the same source walk-bit component;
they are not a recorded normal-input traversal or FPS/smoothness measurement.

Cape battle state is scoped to the current game and seed. A fresh explicit
source trigger after completion replaces only that Cape completion/death ledger;
an unfinished fight resumes surviving members after leaving and reentry. New
adventures already clear the shared ledgers; same-seed resets also discard old
Cape specifications. Original server repeat/cooldown scheduling is unverified.
Other regions retain their existing completion rules.

A rendered first-floor check exposed Metal fence failures during synchronous
`mesh.surface_get_arrays()` floor batching, leaving the floor absent. The
existing `forest_coastal_mesh.finish` now optionally retains the original CPU
arrays as resource-owned metadata; only the generic original floor/water/flat
panel builder enables it. OriginalMaps reuses those immutable arrays. Source
positions and UVs match exactly; committed GPU normals have a1.5259e−5 packing
round-trip difference from the original CPU normals. No global ID cache or
per-frame work is added. `original_ground_arrays_test.gd` checks the retained
geometry and repeated resource reuse. The failed first-floor captures remain
in the Cape evidence directory under `Before CPU arrays/`.

The pinned full server15525_usi supplies additional layout context: ten wall
objects absent from the client cache, mostly to the west. Release/recording
reconciliation and active completion of those cells remain required source
work. This checkpoint preserves client-known tiles and does not claim that
additional server-wall coverage is restored.

The final focused rendered checkpoint passes135assertions with14nonblank
normal63° views and six ordinary native generations. Both source gate fights
produce contacts from every member at their actualFtrigger cell. EightMetal
fence diagnostics remain qualified. The first normal capture was black; its
rejected frame is retained and the second bounded attempt supplies the final
image. Source ground is now visible. The full field-princess view is clear;
the nearbyFview crops her head at the preserved size. The farther Lorens
view remains partly occluded by the source corner, so it is not independent
full-party art signoff. Original-trigger contacts and the preserved source
composition are separate evidence. See `checkpoint.json` for exact paths and
setup/resource observations; the broader regional goal remains active.
