# Illustrated Kazi authoring masters

The user explicitly selected the illustrated preview as the target across all
animations. `identity-master.png` is that approved concept; `identity-long-blade.png`
retains the requested longer, slim curved sword. `revisions/long-blade/masters/A-D.png`
are the editable PNG sprite sheets for most actions. Running uses the corrected
foot-contact sheets in `revisions/run-contact/masters/3-D.png`, with exact prompts
in their sidecars and the side-view stride measurement in
`revisions/run-contact/stride-calibration.json`. `jobs.json` selects the current
56 masters. The first illustrated
version remains in `masters/`. Never silently regenerate or
overwrite an existing master. Keep the original recovered sprites and their
motion/audio manifests in `assets/characters/crossgate/kazi/` unchanged.

`jobs.json` records the redraw recipe, frame grid, source sheet and target for
every action/direction. Per-master JSON sidecars retain exact later built-in
ImageGen submissions and references; `historical-generations.json` identifies
13 earlier pilot/idle submissions whose verbatim prompts were not retained.
The long-blade revision has an exact submission sidecar for each master, including
safe-margin/background corrections. Source sheets and development
captures live under `build/Other Files/Cross Gate 102488/HD Preview/`.

Use `python3 tools/prepare_crossgate_kazi_hd.py prepare` to recreate reference
sheets without modifying masters or the active recipe (`source-jobs.json` holds
the regenerated source recipe). Use `bake --pilot` to stage available sheets
for visual review. A normal `bake` refuses an incomplete 56-clip set and writes
the runtime derivatives to `assets/characters/crossgate/kazi_hd/`. Never edit
those atlas derivatives. Correct a saved master, then rebake.

The baker registers body size/feet offline and excludes thin blades from body
measurements. All directions share the same stance-height ruler: 166 prepared
pixels standing/walking and 148 running. Never use head/hair or silhouette width
to set scale: profile views and flowing hair change width without changing the
character's size. Keep one scale for the entire clip so bends retain their motion.
Per-row head registration removes generated
sheet baseline drift while retaining movement within each row. It retains every animation frame and
original source timing/sound cues, packs shared textures and records master
and derivative hashes. Portraits derive from the approved concept; update its
fixed head crop if the identity master's framing changes. Review identity,
handedness, loop seams, head/foot stability, all eight
directions, effects and death/reaction poses. Refresh imports and test actual
turning at identical animation phase, camera and distance; check all eight
directions together against the shared body ruler, not just the runtime size constant.
Refresh imports and test actual
movement/attacks, cancellation, shared skills, five native allies, repeated
use/resource growth and a rendered normal-army workload before activation.
Do not change combat timing, damage, counts, terrain, art quality or native
ownership to make the new presentation pass. No app export unless requested.
