# Dragon and Wind Cave summit source candidates

The existing map owner registers 22 complete, gated layouts for 15568–15590.
Map 15577 retains its existing server catalog and six NPCs. Do not add another
owner for it. The branch is not ready for normal travel or regional signoff.

`tools/prepare_sokia_dragon_summit.py` owns this catalog, eight source groups,
seven encounter pools and the 43 new source actor records. Reuse the East,
Wind Tower, Desert Temple and source-server graphic catalogs at setup. Of
1,887 used original graphics, only 20 belong to this supplement. Shared pages,
original files, pixel origins, footprints, recorded map tuples and flags stay
intact. Never edit generated caches by hand.

The fixed layouts preserve 103,175 cells and recover 42,803 unrecorded cells.
Eight recorded castle markers 13996/13997 differ from pinned server zero; retain
the client markers. The selected 20 directed branch ports match the pinned
primary table. Two downhill returns remain unavailable because target 15551 is
not registered. Its original source file has now been recovered separately in
`dragon-entrance-references.json`. Map 15571 has no resolved inbound source link
in the inspected graph; do not invent one.

All 72 generated floors remain required: configs 108/109 have 19 each,
110/111 have 9 each, and 309 has 16. Their raw definitions, source templates,
entry/terminal coordinates, pools and configured level intervals remain in
`encounters.json`. Fixed-map pool fixtures do not recover their layouts,
original distribution, per-floor curves or natural traversal.

Use the shared East/native army for every party. Jete 100452 uses published
East skin 166, reusing original:2719/Sokia skin 16. Preserve the existing 256
species prefix when appending the two branch species. Keep fixed altar levels
2–58 separate from the castle configurations' 67–71 intervals, retain source
enemy IDs even when appearances are shared, and preserve Wind God's mandatory
body and two Sylph members. Original probability/count distributions, AI,
formation, result modes and repeat/loss/escape rules remain unverified.

Piano 5648 has graphic 0 and type Event. It uses the existing transparent manual
F anchor and original program. Do not create a visible piano actor or automatic
trigger. Its scenery is already in the source map. Native self-reachability is
insufficient for F station selection: require the original walk bit too. The
source-blocked 17644 markers must not become walkable to repair a test.

Source profession, item capacity and appearance/disguise predicates stay guarded
when unavailable. Original Window_21396/21461 handlers remain unresolved. Source
dialogue padding currently hides some original words; shared presentation and
BImage binding patches are pending the agreed one-writer window. Preserve other
chats' common renderer work. Scenery is not approved: gold walls, back faces,
generic rock forms, Dark Window gaps and cropped fight views remain visible.

Evidence, original-art composites, exact missing-map/asset/rule ledgers and
reproduction commands are under
`build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit/`.
No app export is part of this iteration.
