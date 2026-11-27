# East region native sprites

Prepared by `tools/prepare_east_region_population.py --pack`, using the existing
`recover_habaru_encounter.recover` importer and immutable prepared banks. Original
archives, approved prior banks and saved companion identities are preserved.

`species.json` is the source-key/order/height provenance for `motions.json`.
Existing variants keep their slots; later additions append. Copied prepared
variants record `prepared_from` bank/skin so the existing fitted native body can
be reused. New source body heights use Kazi's original 84-pixel standing body as
a reference; hidden 3D depth remains inferred. `variant_heights` supplies the
relative height for rendering and native body setup. This is not visual approval.

The combined frame table references immutable indexed atlas pages through
`atlas_paths`. Source frames, origins, duration, palette colours and source
contacts are retained. `page_size` verifies consistent page dimensions;
`skin_pages` lists the pages needed for each variant. Reuse the existing lazy
Hound page preparation at map setup, with all possible map species selected.
Do not load assets during an encounter, attack, hit or per-unit frame update.

Attack timelines have a 42-value stride (duration, count, up to 20 event pairs).
New extended source cues use 10000+ID for source-marked contacts and 20000+ID
for audio-only cues, preserving original timing and audio identity. Copied
legacy timelines keep their existing opcodes and receive only zero padding.
The existing native army owns movement, target choice, exact combat, pooling
and presentation; this bank introduces no simulation or targeting owner.

`assets/maps/falan/east_region/native-preparation-blockers.json` retains any
unsupported source action/contact contracts. Unmarked source contact timing
must not be invented to enable a creature. Regenerate through the preparer;
do not edit the generated palette, frame buffer or atlas pages by hand.

The focused Python checks verify mixed-bank pixels, action ordering, timeline
padding, global/per-skin audio maps and source gate/window data. Gameplay,
contact/body preservation, repeated native reuse and rendered fixed-camera
review belong to the route integration checks through Play Goemon. Offline
preparation does not establish smooth gameplay or original turn-based AI parity.

The Wind Tower additions occupy skins161–165:101211,101214,101212,101213and101630.
Their existing Sokia/University/Venoa source pages are referenced, not repacked.
`tools/prepare_sokia_wind_tower.py --native-bank --output PATH` stages the initial
append and rejects an already-published addition. The stage preserves all prior
indices, frames, timing, audio, palette pixels and source records. Its native
page indexer accepts an explicit staged folder; source body records retain their
original ownership when another prepared bank later exposes the same appearance.

`test_wind_native_bank.py` checks2336original-exact frames/anchors/durations,
copied timelines/audio and the161variant prefix. The published166variant bank
passes672native kit/reuse checks. Evidence and previous derived cache files are
under `Sokia Venoa Coverage/Wind Tower/Native bank/` in Asset Toolkit. Wind maps,
original source-party combat, GPU appearance and event gates remain separate
review work. The native body resolver reuses the existing Venoa profile; no new
enemy controller or renderer is introduced.


## Dragon/Summit Jete append

Jete100452uses skin166, copied from the original:2719 Sokia skin16cache through
`tools/prepare_sokia_dragon_summit.py --stage-native-bank PATH`. The canonical
bank now has167variants. All166earlier variants, source frame rows, timelines,
metadata, audio and palette pixels remain exact; atlas paths/pages are reused.
Four hundred frames across56clips match original RGBA, anchors and duration.

`test_dragon_native_bank.py` preserves the166variant cache baseline and verifies
the added original frames/contact/audio. Both staged and published kits pass676
native acceptance/reuse checks. A source-party fixture passes52rendered checks,
35native contacts, three legal camera views and24motion samples. The correct
original Jete and coherent poses are visible; the first near-camera study clips
and the wider view begins partly behind Temple stone. This is bounded body
review, not all-facing, original Dragon scenery, quest-trigger or performance
approval. Evidence and the preserved derived-cache baseline are under
`Sokia Venoa Coverage/Dragon Summit/Native bank/` in Asset Toolkit. Do not edit
generated rows or source pages by hand; retain the existing owner and pools.
