# Sokia and Venoa pinned event evidence

These472 scripts and the original `dungeonconf.txt` preserve bytes from
`linv2/Crossgate_Docker` commit `dd8690ed3df11e4eb5a038a54079a8f40d8e93b3`.
`references.json` records the exact source URL, commit, SHA-256 and Git blob
identity for each file. Existing SHA-pinned copies were reused before fetching
missing scripts from that same primary source. Tina reference files remain
unchanged. Do not hand-edit the preserved inputs or rewrite hashes to approve
different content.

`git-tree-pins.json` now checks all473 files against expected blobs from the
pinned Git tree. Five older copies were UTF8 transcodes of the original GB18030
text; they have been replaced with exact raw Git bytes. Their decoded text was
identical. The old copies/metadata remain under `Source events/Before raw-byte
repair/`, with the correction recorded in `raw-byte-repair.json`. This is an
explicit reference-byte correction, not approval of a changed authored asset or
a rewritten preservation baseline. Recovery rejects those transcoded copies
even when an old local SHA record agrees with them.

The graph also includes51 dynamic NPC templates referenced by dungeon config
fields101–116, with27 additional fight declarations. Every slot and refresh
operand remains present, including repeated IDs. Their source777 marker is not
a geographic floor ID. The reference reader parses these fields but comments
out dynamic NPC creation, so original placement/count/refresh execution remains
unverified; runtime placement adaptations must be labeled separately.

The scoped forward graph starts with the 65 maps in the initial Sokia/Venoa
coverage inventory, then follows original-candidate fixed ports, event warps,
NPC warp alternatives, declared post-fight transfers and dungeon endpoints.
Referenced script names are recovered recursively. Other named regional owners,
Falan city/interiors and map IDs at or above 30000 remain explicit boundaries
requiring source/release review. These boundaries do not reduce the user's
required restoration scope or certify those destinations as complete.

Generated evidence and the recovery script live under
`build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Source events/`.
`source-graph.json` retains raw NPC rows, conditional source groups, explicit
directed transfers, dungeon rows and lexical command context. `REPORT.md`
explains the current evidence and conflicts. This extractor does not execute
event conditions, item consumption, battle rules or original maze generation.

This is pinned CGMSV corroboration, not an authenticated matching BlueCG server
release. Several named NPC fight references disagree with the same commit's
group identities, including Ruby and Falken. Resolve those conflicts before
publishing any rule as restored. Preserve existing verified fight owners until
matching source evidence establishes a replacement. Original comments can
already contain mojibake; bytes and ASCII commands are preserved.
