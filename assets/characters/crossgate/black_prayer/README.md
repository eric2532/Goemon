# Original Black Prayer encounter sprites

`tools/recover_habaru_encounter.py --ruby` prepares this atlas from the sibling
Magic Power client archive. Preserve these original frames, palette, anchors,
clip lengths, sound cues and table data. To verify without replacing live files,
run `python3 tests/forest-shrine/test_black_prayer_source.py`; it rebuilds into a
temporary toolkit folder and compares every prepared PNG, animation table and
manifest with the live preparation.

Native skin 0 is Ruby 100654 (`original:1184`), skin 1 is Bloody Blade 101600
(`original:1328`), skin 2 is Ghost 101121 (`original:1248`). Ruby's runtime attack
slot uses original spell action 7; do not replace it with guessed sword poses.
The original sound samples are reused through the shared Cross Gate audio paths.

The palace uses one Ruby, five Blades and four Ghosts at archived formation
stations. Black Prayer's six generated floors reuse only skins 1/2 through the
same native army sprite batch. Those floors must keep `ruby_boss=false` so a
patrol cannot acquire Ruby's special spell behavior. Native bodies, damage,
death and targeting remain in the existing shared owner; maze kill slots are
separate from the palace party's reward ledger.

The current game retains its real-time balance, prepared sprite scale and
fourteen-spell repertoire. Exact original turn-based scheduling/probabilities,
resistance and absolute spell math remain unrecovered; see
`docs/black-prayer-recovery.md` for the real-time adaptations.

`tools/recover_ruby_spells.py` prepares `spells/manifest.json` and the missing
level-five Heal sheet 110087, the six original typed ward contacts and Confusion
cube 110163. Seven earlier clips reuse existing preparations by hash; matching
audio is also reused where present. No copied actor atlas is introduced. Use
`--check` to compare source sheets, cue times, sounds and matched server records.
Keep source tables, frames, anchors and cue timings intact. The ward flashes play
on native contacts rather than as persistent prototype rectangles; Confusion
loops its native cube for the current state. Holy Shield contact 110098 replaces
the last persistent prototype shield. Its four source frames are sized against
Ruby's original 85-pixel standing body; sounds 131/132 follow the archived native
contact branch. Native buff duration/reduction stay unchanged. Contact anchoring,
random jitter and turn scheduling are still fitted/unrecovered respectively. Runtime spell
textures/materials are prepared once on boss-floor setup, not in cast/hit loops.


Holy Shield's source branch proof is `assets/references/black_prayer/holy-shield-factory.json`;
run `test_ruby_holy_source.py` to re-execute its six ordinary/special/no-guard and
sound-endpoint cases. Preserve the distinction between ordinary guard 110000 and
Special Guard 110098. Runtime emitters use the existing RUBY_WARD_BLOCK payload;
production compact-event coverage must include these contacts too.
